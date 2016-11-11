//
//  NBCWorkflowNBI.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "NBCConstants.h"
#import "NBCDiskImageController.h"
#import "NBCError.h"
#import "NBCLog.h"
#import "NBCTarget.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowResources.h"
#import "NBCWorkflowUpdateNBI.h"

@implementation NBCWorkflowUpdateNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
} // initWithDelegate

- (void)updateNBI:(NBCWorkflowItem *)workflowItem {

    [self setWorkflowItem:workflowItem];
    [self setTarget:[workflowItem target]];

    NSError *error = nil;

    // If only changes outside disk images are made, do those directly
    if ([self onlyChangeNBImageInfo:&error]) {
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteUpdateNBI object:self userInfo:nil];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{
                                                                  NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Updating files in NBI folder failed"]
                                                              }];
        }
    } else {
        if ([[[_workflowItem target] baseSystemDisk] isMounted]) {
            DDLogDebug(@"[DEBUG] BaseSystem disk image IS mounted");
            DDLogDebug(@"[DEBUG] Detaching BaseSystem disk image...");

            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(taskQueue, ^{

              if ([NBCDiskImageController detachDiskImageAtPath:[[[self->_workflowItem target] baseSystemVolumeURL] path]]) {
                  if ([[self->_workflowItem userSettings][NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility]) {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        [self prepareSystemImageUtilityNBI:self->_target];
                      });
                  } else {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        [self prepareNBICreatorNBI:self->_target];
                      });
                  }
              } else {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{
                                                                          NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Detaching BaseSystem disk image failed"]
                                                                      }];
                  });
                  return;
              }
            });
        } else {
            if ([[_workflowItem userSettings][NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility]) {
                [self prepareSystemImageUtilityNBI:_target];
            } else {
                [self prepareNBICreatorNBI:_target];
            }
        }
    }
}

- (void)prepareNBICreatorNBI:(NBCTarget *)target {

    [_workflowItem setUserSettingsChangedRequiresBaseSystem:YES];

    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{

      NSError *error;
      if ([NBCDiskImageController attachBaseSystemDiskImageWithShadowFile:[target baseSystemURL] target:target error:&error]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
          });
      } else {
          dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{
                                                                  NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attaching BaseSystem disk image failed"]
                                                              }];
          });
      }
    });
}

- (BOOL)onlyChangeNBImageInfo:(NSError **)error {

    NSDictionary *settingsChanged = [_workflowItem userSettingsChanged];
    NSMutableArray *keysChanged = [[settingsChanged allKeysForObject:@YES] mutableCopy];
    NSMutableArray *keysNBImageInfo = [[NSMutableArray alloc] init];
    NSMutableArray *keysBootPlist = [[NSMutableArray alloc] init];
    for (NSString *key in [keysChanged copy]) {
        if ([key isEqualToString:NBCSettingsProtocolKey] || [key isEqualToString:NBCSettingsIndexKey] || [key isEqualToString:NBCSettingsEnabledKey] || [key isEqualToString:NBCSettingsDefaultKey] ||
            [key isEqualToString:NBCSettingsDescriptionKey]) {
            [keysNBImageInfo addObject:key];
            [keysChanged removeObject:key];
        } else if ([key isEqualToString:NBCSettingsUseVerboseBootKey]) {
            [keysBootPlist addObject:key];
            [keysChanged removeObject:key];
        }
    }

    if ([keysChanged count] == 0) {
        DDLogInfo(@"Only settings in the NBI folder changed...");
        NSDictionary *userSettings = [_workflowItem userSettings];

        if ([keysNBImageInfo count] != 0) {
            DDLogInfo(@"Updating NBImageInfo.plist...");

            NSURL *nbImageInfoURL = [[_workflowItem source] nbImageInfoURL];
            DDLogDebug(@"[DEBUG] NBImageInfo.plist path: %@", [nbImageInfoURL path]);

            if ([nbImageInfoURL checkResourceIsReachableAndReturnError:error]) {
                DDLogDebug(@"[DEBUG] NBImageInfo.plist exists!");

                NSMutableDictionary *nbImageInfoDict = [NSMutableDictionary dictionaryWithContentsOfURL:nbImageInfoURL];
                if ([nbImageInfoDict count] != 0) {

                    NSString *nbImageInfoKey;
                    for (NSString *key in keysNBImageInfo) {
                        if ([key isEqualToString:NBCSettingsProtocolKey]) {
                            nbImageInfoKey = NBCNBImageInfoDictProtocolKey;
                        } else if ([key isEqualToString:NBCSettingsIndexKey]) {
                            nbImageInfoKey = NBCNBImageInfoDictIndexKey;
                        } else if ([key isEqualToString:NBCSettingsEnabledKey]) {
                            nbImageInfoKey = NBCNBImageInfoDictIsEnabledKey;
                        } else if ([key isEqualToString:NBCSettingsDefaultKey]) {
                            nbImageInfoKey = NBCNBImageInfoDictIsDefaultKey;
                        } else if ([key isEqualToString:NBCSettingsDescriptionKey]) {
                            nbImageInfoKey = NBCNBImageInfoDictDescriptionKey;
                        }

                        DDLogDebug(@"[DEBUG] Changing key: %@", nbImageInfoKey);
                        DDLogDebug(@"[DEBUG] Original value: %@", nbImageInfoDict[nbImageInfoKey]);
                        DDLogDebug(@"[DEBUG] New value: %@", userSettings[key]);
                        if ([key isEqualToString:NBCSettingsIndexKey]) {
                            nbImageInfoDict[nbImageInfoKey] = @([userSettings[key] integerValue]);
                        } else {
                            nbImageInfoDict[nbImageInfoKey] = userSettings[key];
                        }
                    }

                    DDLogDebug(@"[DEBUG] Writing updated NBImageInfo.plist...");
                    if (![nbImageInfoDict writeToURL:nbImageInfoURL atomically:YES]) {
                        *error = [NBCError errorWithDescription:@"Writing updated NBImageInfo.plist failed"];
                        return YES;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"NBImageInfo.plist was empty"];
                    return YES;
                }
            } else {
                return YES;
            }
        }

        if ([keysBootPlist count] != 0) {
            DDLogInfo(@"Updating com.apple.Boot.plist...");

            NSURL *bootPlistURL = [[_workflowItem nbiURL] URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
            DDLogDebug(@"[DEBUG] com.apple.Boot.plist path: %@", [bootPlistURL path]);

            NSMutableDictionary *bootPlistDict;
            if ([bootPlistURL checkResourceIsReachableAndReturnError:nil]) {
                DDLogDebug(@"[DEBUG] com.apple.Boot.plist exists!");

                bootPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:bootPlistURL];
                if (!bootPlistDict) {
                    bootPlistDict = [[NSMutableDictionary alloc] init];
                }
            } else {
                bootPlistDict = [[NSMutableDictionary alloc] init];
            }

            if ([userSettings[NBCSettingsUseVerboseBootKey] boolValue]) {
                DDLogDebug(@"[DEBUG] Adding \"-v\" to \"Kernel Flags\"");
                if ([bootPlistDict[@"Kernel Flags"] length] != 0) {
                    NSString *currentKernelFlags = bootPlistDict[@"Kernel Flags"];
                    bootPlistDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ -v", currentKernelFlags];
                } else {
                    bootPlistDict[@"Kernel Flags"] = @"-v";
                }
            } else {
                DDLogDebug(@"[DEBUG] Removing \"-v\" from \"Kernel Flags\"");
                if ([bootPlistDict[@"Kernel Flags"] length] != 0) {
                    NSString *currentKernelFlags = bootPlistDict[@"Kernel Flags"];
                    bootPlistDict[@"Kernel Flags"] = [currentKernelFlags stringByReplacingOccurrencesOfString:@"-v" withString:@""];
                } else {
                    bootPlistDict[@"Kernel Flags"] = @"";
                }
            }

            if (![bootPlistDict writeToURL:bootPlistURL atomically:YES]) {
                *error = [NBCError errorWithDescription:@"Writing updated com.apple.Boot.plist failed"];
                return YES;
            }
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)prepareSystemImageUtilityNBI:(NBCTarget *)target {
    __block NSError *error;

    DDLogDebug(@"[DEBUG] Workflow creation tool is: %@", NBCMenuItemSystemImageUtility);

    if ([[target nbiNetInstallDisk] isWritable]) {
        DDLogDebug(@"[DEBUG] NetInstall disk image is writeable");

        if (![[target nbiNetInstallDisk] isMounted]) {
            DDLogDebug(@"[DEBUG] NetInstall disk image is NOT mounted");

            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(taskQueue, ^{

              NSDictionary *netInstallDiskImageDict;
              NSArray *hdiutilOptions = @[
                  @"-mountRandom",
                  @"/Volumes",
                  @"-nobrowse",
                  @"-noverify",
                  @"-plist",
              ];

              if ([NBCDiskImageController attachDiskImageAndReturnPropertyList:&netInstallDiskImageDict dmgPath:[target nbiNetInstallURL] options:hdiutilOptions error:&error]) {

                  if (netInstallDiskImageDict) {
                      [target setNbiNetInstallDiskImageDict:netInstallDiskImageDict];

                      NSURL *netInstallVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:netInstallDiskImageDict];
                      if ([netInstallVolumeURL checkResourceIsReachableAndReturnError:&error]) {

                          NBCDisk *netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:[target nbiNetInstallURL] imageType:@"InstallESD"];
                          if (netInstallDisk) {
                              [target setNbiNetInstallDisk:netInstallDisk];
                              DDLogDebug(@"[DEBUG] NetInstall disk image volume mounted!");

                              [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
                              DDLogDebug(@"[DEBUG] NetInstall disk image volume bsd identifier: %@", [netInstallDisk BSDName]);

                              [target setNbiNetInstallVolumeURL:netInstallVolumeURL];
                              DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);

                              [netInstallDisk setIsMountedByNBICreator:YES];
                              dispatch_async(dispatch_get_main_queue(), ^{
                                [self prepareSystemImageUtilityNBIBaseSystem:target];
                              });
                          } else {
                              dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{
                                                                                      NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Found no disk object matching disk image volume url"]
                                                                                  }];
                              });
                              return;
                          }
                      } else {
                          dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{
                                                                                  NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NetInstall disk image volume url doesn't exist"]
                                                                              }];
                          });
                          return;
                      }
                  } else {
                      dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{
                                                                              NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Information dictionary returned from hdiutil was empty"]
                                                                          }];
                      });
                      return;
                  }
              } else {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{
                                                                          NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attaching NetInstall disk image failed"]
                                                                      }];
                  });
                  return;
              }
            });
        }
    } else {
        DDLogDebug(@"[DEBUG] NetInstall disk image is NOT writeable");

        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{

          if ([[target nbiNetInstallDisk] isMounted]) {
              DDLogDebug(@"[DEBUG] NetInstall disk image IS mounted");

              DDLogDebug(@"[DEBUG] Detaching NetInstall disk image...");
              if (![NBCDiskImageController detachDiskImageAtPath:[[target nbiNetInstallVolumeURL] path]]) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{
                                                                          NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Detaching NetInstall disk image failed"]
                                                                      }];
                  });
                  return;
              }
          }

          if ([NBCDiskImageController attachNetInstallDiskImageWithShadowFile:[target nbiNetInstallURL] target:target error:&error]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [self prepareSystemImageUtilityNBIBaseSystem:target];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attaching NetInstall disk image failed"]
                                                                  }];
              });
              return;
          }
        });
    }
}

- (void)prepareSystemImageUtilityNBIBaseSystem:(NBCTarget *)target {

    NSDictionary *settingsChanged = [_workflowItem userSettingsChanged];
    if ([settingsChanged[NBCSettingsARDLoginKey] boolValue] || [settingsChanged[NBCSettingsARDPasswordKey] boolValue] || [settingsChanged[NBCSettingsAddCustomRAMDisksKey] boolValue] ||
        [settingsChanged[NBCSettingsRAMDisksKey] boolValue] || [settingsChanged[NBCSettingsDisableBluetoothKey] boolValue] || [settingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
        [settingsChanged[NBCSettingsIncludeConsoleAppKey] boolValue] || [settingsChanged[NBCSettingsIncludeRubyKey] boolValue] || [settingsChanged[NBCSettingsIncludeSystemUIServerKey] boolValue] ||
        [settingsChanged[NBCSettingsKeyboardLayoutID] boolValue] || [settingsChanged[NBCSettingsLanguageKey] boolValue] || [settingsChanged[NBCSettingsUseNetworkTimeServerKey] boolValue] ||
        [settingsChanged[NBCSettingsNetworkTimeServerKey] boolValue] || [settingsChanged[NBCSettingsTimeZoneKey] boolValue]) {

        DDLogDebug(@"[DEBUG] At least one setting that require BaseSystem was changed");
        [_workflowItem setUserSettingsChangedRequiresBaseSystem:YES];

        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{

          NSError *error;
          if ([NBCDiskImageController attachBaseSystemDiskImageWithShadowFile:[target baseSystemURL] target:target error:&error]) {
              dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
              });
          } else {
              dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attaching BaseSystem disk image failed"]
                                                                  }];
              });
          }
        });
    } else {
        DDLogDebug(@"[DEBUG] No settings that require BaseSystem were changed");
        [_workflowItem setUserSettingsChangedRequiresBaseSystem:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
    }
}

@end
