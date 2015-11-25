//
//  NBCWorkflowModifyNBI.m
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

#import "NBCWorkflowModifyNBI.h"
#import "NBCWorkflowItem.h"

#import "NBCError.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCVariables.h"

#import "ServerInformationComputerModelInfo.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperAuthorization.h"
#import "NBCDiskImageController.h"
#import "NBCWorkflowResourcesModify.h"
#import "NBCDiskArbitrationPrivateFunctions.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowModifyNBI

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
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyNBI:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Modifying NBI...");
    
    [self setWorkflowItem:workflowItem];
    [self setWorkflowType:[_workflowItem workflowType]];
    [self setCreationTool:[_workflowItem userSettings][NBCSettingsNBICreationToolKey]];
    
    // Set at what percentage the progress bar should start from ( 10.0 = 10% )
    [self setProgressOffset:60.0];
    
    // Set how many percentages the progress bar should have moved ( 0.1 = 10% )
    [self setProgressPercentage:0.4];
    
    [self setIsNBI:( [[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", ( _isNBI ) ? @"YES" : @"NO" );
    
    [self setUserSettingsChanged:[workflowItem userSettingsChanged] ?: @{}];
    
    NSError *error;
    NSURL *nbiURL;
    if ( _isNBI ) {
        nbiURL = [[workflowItem target] nbiURL];
    } else {
        nbiURL = [workflowItem temporaryNBIURL];
    }
    DDLogDebug(@"[DEBUG] NBI path: %@", [nbiURL path]);
    
    if ( [nbiURL checkResourceIsReachableAndReturnError:&error] ) {
        
        DDLogInfo(@"Updating NBI icon...");
        [_delegate updateProgressStatus:@"Updating NBI icon..." workflow:self];
        [_delegate updateProgressBar:(( 5.0 * _progressPercentage ) + _progressOffset )];
        
        // ---------------------------------------------------------------
        //  Update NBI Icon
        // ---------------------------------------------------------------
        if ( ! [self updateNBIIconForNBIAtURL:nbiURL workflowItem:workflowItem error:&error] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Updating NBI icon failed"] }];
            return;
        }
        
        // ---------------------------------------------------------------
        //  Apply all settings to NBImageInfo.plist in NBI
        // ---------------------------------------------------------------
        if ( ! _isNBI || ( _isNBI && (
                                      [_userSettingsChanged[NBCSettingsNameKey] boolValue] ||
                                      [_userSettingsChanged[NBCSettingsIndexKey] boolValue] ||
                                      [_userSettingsChanged[NBCSettingsProtocolKey] boolValue] ||
                                      [_userSettingsChanged[NBCSettingsEnabledKey] boolValue] ||
                                      [_userSettingsChanged[NBCSettingsDefaultKey] boolValue] ||
                                      [_userSettingsChanged[NBCSettingsDescriptionKey] boolValue]
                                      ) ) ) {
            
            DDLogInfo(@"Updating NBImageInfo.plist...");
            [_delegate updateProgressStatus:@"Updating NBImageInfo.plist..." workflow:self];
            [_delegate updateProgressBar:(( 10.0 * _progressPercentage ) + _progressOffset )];
            
            if ( ! [self updateNBImageInfoForNBIAtURL:nbiURL workflowItem:workflowItem error:&error] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Updating NBImageInfo.plist failed"] }];
                return;
            }
        }
        
        [self modifyVolumeBaseSystem];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NBI doesn't exist at the expected path"] }];
    }
} // modifyNBI

- (BOOL)updateNBIIconForNBIAtURL:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    NSImage *icon = [workflowItem nbiIcon];
    if ( icon ) {
        return [[NSWorkspace sharedWorkspace] setIcon:icon forFile:[nbiURL path] options:0];
    } else {
        *error = [NBCError errorWithDescription:@"No icon to set"];
        return NO;
    }
} // updateNBIIconForNBIAtURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify: NBImageInfo.plist
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)updateNBImageInfoForNBIAtURL:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    
    NSMutableDictionary *nbImageInfoDict = [self nbImageInfoDictForNBIAtURL:nbiURL];
    if ( [nbImageInfoDict count] != 0 ) {
        
        NSMutableDictionary *newNBImageInfoDict = [nbImageInfoDict mutableCopy];
        NSDictionary *userSettings = [workflowItem userSettings];
        NBCSource *source = [workflowItem source];
        id applicationSource = [workflowItem applicationSource];
        
        // ---------------------------------------------------------------
        //  Adding: DisabledSystemIdentifiers
        // ---------------------------------------------------------------
        NSURL *platformSupportURL = [nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
        if ( [platformSupportURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *platformSupportDict = [[NSDictionary alloc] initWithContentsOfURL:platformSupportURL];
            if ( [platformSupportDict count] != 0 ) {
                NSMutableArray *disabledSystemIdentifiers = [[NSMutableArray alloc] initWithArray:newNBImageInfoDict[@"DisabledSystemIdentifiers"] ?: @[]];
                [disabledSystemIdentifiers addObjectsFromArray:platformSupportDict[@"SupportedModelProperties"] ?: @[]];
                NSArray *modelIDsFromBoardIDs = [ServerInformationComputerModelInfo modelPropertiesForBoardIDs:platformSupportDict[@"SupportedBoardIds"] ?: @[]];
                [disabledSystemIdentifiers addObjectsFromArray:modelIDsFromBoardIDs ?: @[]];
                
                newNBImageInfoDict[@"DisabledSystemIdentifiers"] = [[[disabledSystemIdentifiers copy] valueForKeyPath:@"@distinctUnionOfObjects.self"]
                                                                    sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]?: @[];
            }
        }
        
        // ---------------------------------------------------------------
        //  Adding: IsEnabled
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"IsEnabled"] = @([userSettings[NBCSettingsEnabledKey] boolValue]) ?: @NO;
        
        // ---------------------------------------------------------------
        //  Adding: IsDefault
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"IsDefault"] = @([userSettings[NBCSettingsDefaultKey] boolValue]) ?: @NO;
        
        // ---------------------------------------------------------------
        //  Adding: Name
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"Name"] = [NBCVariables expandVariables:userSettings[NBCSettingsNameKey]
                                                             source:source
                                                  applicationSource:applicationSource] ?: @"";
        
        // ---------------------------------------------------------------
        //  Adding: Description
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"Description"] = [NBCVariables expandVariables:userSettings[NBCSettingsDescriptionKey]
                                                                    source:source
                                                         applicationSource:applicationSource] ?: @"";
        
        // ---------------------------------------------------------------
        //  Adding: Index
        // ---------------------------------------------------------------
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        nf.numberStyle = NSNumberFormatterDecimalStyle;
        newNBImageInfoDict[@"Index"] = [nf numberFromString:[NBCVariables expandVariables:userSettings[NBCSettingsIndexKey]
                                                                                   source:source
                                                                        applicationSource:applicationSource] ?: @"1"] ?: @1;
        
        // ---------------------------------------------------------------
        //  Adding: Language
        // ---------------------------------------------------------------
        NSString *language = userSettings[NBCSettingsLanguageKey] ?: @"";
        if ( [language isEqualToString:@"Current"] ) {
            language = @"Default";
        }
        newNBImageInfoDict[@"Language"] = language ?: @"Default";
        
        // ---------------------------------------------------------------
        //  Adding: osVersion
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"osVersion"] = [source expandVariables:@"%OSMAJOR%.%OSMINOR%"] ?: @"10.x";
        
        // ---------------------------------------------------------------
        //  Adding: Type
        // ---------------------------------------------------------------
        newNBImageInfoDict[@"Type"] = userSettings[NBCSettingsProtocolKey] ?: @"HTTP";
        
        // ---------------------------------------------------------------
        //  Write updated NBImageInfo to
        // ---------------------------------------------------------------
        return [newNBImageInfoDict writeToURL:[nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"] atomically:NO];
    } else {
        *error = [NBCError errorWithDescription:@"No NBImageInfo.plist to modify"];
        return NO;
    }
} // updateNBImageInfoForNBIAtURL

- (NSMutableDictionary *)nbImageInfoDictForNBIAtURL:(NSURL *)nbiURL {
    
    DDLogDebug(@"[DEBUG] Getting NBImageInfo.plist...");
    
    NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
    if ( [nbImageInfoURL checkResourceIsReachableAndReturnError:nil] ) {
        return [[NSMutableDictionary alloc] initWithContentsOfURL:nbImageInfoURL];
    } else {
        return [self defaultNBImageInfoDictForNBIAtURL:nbiURL];
    }
} // nbImageInfoDictForNBIAtURL

- (NSMutableDictionary *)defaultNBImageInfoDictForNBIAtURL:(NSURL *)nbiURL {
    
    DDLogDebug(@"[DEBUG] Creating default NBImageInfo.plist...");
    
    NSError *error;
    NSDictionary *platformSupportDict;
    NSArray *disabledSystemIdentifiers;
    
    NSURL *platformSupportURL = [nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
    if ( [platformSupportURL checkResourceIsReachableAndReturnError:&error] ) {
        platformSupportDict = [[NSDictionary alloc] initWithContentsOfURL:platformSupportURL];
        if ( [platformSupportDict count] != 0 ) {
            disabledSystemIdentifiers = platformSupportDict[@"SupportedModelProperties"];
            if ( [disabledSystemIdentifiers count] != 0 ) {
                disabledSystemIdentifiers = [disabledSystemIdentifiers sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            } else {
                DDLogWarn(@"[WARN] DisabledSystemIdentifiers was empty");
            }
        }
    } else {
        DDLogWarn(@"[WARN] %@", [error localizedDescription]);
    }
    
    return [[NSMutableDictionary alloc]
            initWithDictionary:@{
                                 @"Architectures"                   : @[ @"i386" ],
                                 @"BackwardCompatible"              : @NO,
                                 @"BootFile"                        : @"booter",
                                 NBCNBImageInfoDictDescriptionKey   : @"",
                                 @"DisabledSystemIdentifiers"       : disabledSystemIdentifiers ?: @[],
                                 @"EnabledSystemIdentifiers"        : @[],
                                 NBCNBImageInfoDictIndexKey         : @1,
                                 NBCNBImageInfoDictIsDefaultKey     : @NO,
                                 NBCNBImageInfoDictIsEnabledKey     : @YES,
                                 @"IsInstall"                       : @YES,
                                 @"Kind"                            : @1,
                                 NBCNBImageInfoDictLanguageKey      : @"Default",
                                 @"Name"                            : @"",
                                 @"RootPath"                        : @"NetInstall.dmg",
                                 @"SupportsDiskless"                : @NO,
                                 NBCNBImageInfoDictProtocolKey      : @"HTTP",
                                 @"imageType"                       : @"netinstall",
                                 @"osVersion"                       : @"10.x"
                                 }];
} // defaultNBImageInfoDictForNBIAtURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyVolumeBaseSystem {
    [_delegate updateProgressBar:(( 15.0 * _progressPercentage ) + _progressOffset )];
    
    NSDictionary *resourcesBaseSystemDict = [[_workflowItem target] resourcesBaseSystemDict];
    if ( [resourcesBaseSystemDict count] != 0 ) {
        
        DDLogInfo(@"Modify BaseSystem volume...");
        [_delegate updateProgressStatus:@"Modify BaseSystem volume..." workflow:self];
        
        __block NSError *error;
        
        // ------------------------------------------------------------------
        //  Verify that BaseSystem is mounted
        // ------------------------------------------------------------------
        if ( [[[_workflowItem target] baseSystemDisk] isMounted] ) {
            
            DDLogDebug(@"[DEBUG] Target BaseSystem disk image IS mounted");
            
            // ------------------------------------------------------------------
            //  Verify that BaseSystem is mounted using shadow file
            //
            //  +IMPROVEMENT This check is very weak, shoud check with hdiutil
            //
            // ------------------------------------------------------------------
            if ( [[[_workflowItem target] baseSystemShadowPath] length] != 0 ) {
                
                NSURL *baseSystemVolumeURL = [[[_workflowItem target] baseSystemDisk] volumeURL];
                DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
                
                if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                    
                    [self setCurrentVolume:@"BaseSystem"];
                    [self setCurrentVolumeURL:baseSystemVolumeURL];
                    [self setCurrentVolumeResources:resourcesBaseSystemDict];
                    
                    // ---------------------------------------------------------------
                    //  Install Packages
                    // ---------------------------------------------------------------
                    [self installPackagesToVolume];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"BaseSystem disk image reports mounted but can't find volume path"] }];
                }
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"BaseSystem disk image is not mounted with shadow file, this state is not handled yet."] }];
            }
        } else if ( [[[_workflowItem target] nbiNetInstallDisk] isMounted] ) {
            
            DDLogDebug(@"[DEBUG] Target NetInstall disk image IS mounted");
            
            // ------------------------------------------------------------------
            //  Verify that NetInstall is mounted using shadow file
            //
            //  +IMPROVEMENT This check is very weak, shoud check with hdiutil
            //
            // ------------------------------------------------------------------
            if ( [[[_workflowItem target] nbiNetInstallShadowPath] length] != 0 ) {
                
                dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(taskQueue, ^{
                    
                    // ------------------------------------------------------------------
                    //  Resize and mount BaseSystem if shadow path is not set in target
                    // ------------------------------------------------------------------
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DDLogInfo(@"Attaching BaseSystem disk image with shadow...");
                        [self->_delegate updateProgressStatus:@"Attaching BaseSystem disk image with shadow..." workflow:self];
                        [self->_delegate updateProgressBar:(( 20.0 * self->_progressPercentage ) + self->_progressOffset )];
                    });
                    
                    if ( [NBCDiskImageController resizeAndMountBaseSystemWithShadow:[[self->_workflowItem target] baseSystemURL]  target:[self->_workflowItem target] error:&error] ) {
                        
                        NSURL *baseSystemVolumeURL = [[[self->_workflowItem target] baseSystemDisk] volumeURL];
                        DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
                        
                        if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                            
                            [self setCurrentVolume:@"BaseSystem"];
                            [self setCurrentVolumeURL:baseSystemVolumeURL];
                            [self setCurrentVolumeResources:resourcesBaseSystemDict];
                            
                            // ---------------------------------------------------------------
                            //  Install Packages
                            // ---------------------------------------------------------------
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self installPackagesToVolume];
                            });
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem returned yes but can't find volume path"] }];
                            });
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem failed"] }];
                        });
                    }
                });
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NetInstall disk image is not mounted with shadow file, this state is not handled yet."] }];
            }
        } else {
            
            DDLogDebug(@"[DEBUG] Neither target NetInstall or BaseSystem disk images are mounted");
            
            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(taskQueue, ^{
                
                // ------------------------------------------------------------------
                //  Attach and mount NetInstall if shadow path is not set in target
                // ------------------------------------------------------------------
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogInfo(@"Attaching NetInstall disk image with shadow...");
                    [self->_delegate updateProgressStatus:@"Attaching NetInstall disk image with shadow..." workflow:self];
                    [self->_delegate updateProgressBar:(( 20.0 * self->_progressPercentage ) + self->_progressOffset )];
                });
                
                if ( [NBCDiskImageController attachNetInstallDiskImageWithShadowFile:[[self->_workflowItem target] nbiNetInstallURL] target:[self->_workflowItem target]  error:&error] ) {
                    
                    // ------------------------------------------------------------------
                    //  Resize and mount BaseSystem if shadow path is not set in target
                    // ------------------------------------------------------------------
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DDLogInfo(@"Attaching BaseSystem disk image with shadow...");
                        [self->_delegate updateProgressStatus:@"Attaching BaseSystem disk image with shadow..." workflow:self];
                        [self->_delegate updateProgressBar:(( 22.5 * self->_progressPercentage ) + self->_progressOffset )];
                    });
                    
                    if ( [NBCDiskImageController resizeAndMountBaseSystemWithShadow:[[self->_workflowItem target] baseSystemURL]  target:[self->_workflowItem target] error:&error] ) {
                        
                        NSURL *baseSystemVolumeURL = [[[self->_workflowItem target] baseSystemDisk] volumeURL];
                        DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
                        
                        if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                            
                            [self setCurrentVolume:@"BaseSystem"];
                            [self setCurrentVolumeURL:baseSystemVolumeURL];
                            [self setCurrentVolumeResources:resourcesBaseSystemDict];
                            
                            // ---------------------------------------------------------------
                            //  Install Packages
                            // ---------------------------------------------------------------
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self installPackagesToVolume];
                            });
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem returned yes but can't find volume path"] }];
                            });
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem failed"] }];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount NetInstall failed"] }];
                    });
                }
            });
        }
    } else {
        [self modifyVolumeNetInstall];
    }
} // modifyVolumeBaseSystem

- (void)modifyVolumeNetInstall {
    [_delegate updateProgressBar:(( 50.0 * _progressPercentage ) + _progressOffset )];
    
    NSDictionary *resourcesNetInstallDict = [[_workflowItem target] resourcesNetInstallDict];
    if ( [resourcesNetInstallDict count] != 0 ) {
        
        DDLogInfo(@"Modify NetInstall volume...");
        [_delegate updateProgressStatus:@"Modify NetInstall volume..." workflow:self];
        
        __block NSError *error;
        
        // ------------------------------------------------------------------
        //  Verify that NetInstall is mounted
        // ------------------------------------------------------------------
        if ( [[[_workflowItem target] nbiNetInstallDisk] isMounted] ) {
            
            DDLogDebug(@"[DEBUG] Target NetInstall disk image IS mounted");
            
            // ------------------------------------------------------------------
            //  Verify that NetInstall is mounted using shadow file
            //
            //  +IMPROVEMENT This check is very weak, shoud check with hdiutil
            //
            // ------------------------------------------------------------------
            if ( [[[_workflowItem target] nbiNetInstallShadowPath] length] != 0 ) {
                
                NSURL *netInstallVolumeURL = [[_workflowItem target] nbiNetInstallVolumeURL];
                DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);
                
                if ( [netInstallVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                    
                    [self setCurrentVolume:@"NetInstall"];
                    [self setCurrentVolumeURL:netInstallVolumeURL];
                    [self setCurrentVolumeResources:resourcesNetInstallDict];
                    
                    // ------------------------------------------------------------------
                    //  Delete and recreate folder Packages
                    // ------------------------------------------------------------------
                    if ( (
                          [_creationTool isEqualToString:NBCMenuItemNBICreator] ||
                          [_workflowItem workflowType] == kWorkflowTypeImagr ||
                          [_workflowItem workflowType] == kWorkflowTypeCasper
                          ) && (
                                [[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeInstallerApplication] ||
                                [[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeInstallESDDiskImage]
                                ) ) {
                        
                        // ---------------------------------------------------------------
                        //  Remove folder Packages and recreate an empty version
                        // ---------------------------------------------------------------
                        [self removeFolderPackagesInNetInstallVolume:netInstallVolumeURL];
                    } else {
                        
                        // ---------------------------------------------------------------
                        //  Install Packages
                        // ---------------------------------------------------------------
                        [self installPackagesToVolume];
                    }
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NetInstall disk image reports mounted but can't find volume path"] }];
                }
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NetInstall disk image is not mounted with shadow file, this state is not handled yet."] }];
            }
        } else  {
            
            DDLogDebug(@"[DEBUG] Target NetInstall disk image is NOT mounted");
            
            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(taskQueue, ^{
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogInfo(@"Attaching NetInstall disk image with shadow...");
                    [self->_delegate updateProgressStatus:@"Attaching NetInstall disk image with shadow..." workflow:self];
                    [self->_delegate updateProgressBar:(( 55.0 * self->_progressPercentage ) + self->_progressOffset )];
                });
                
                // ------------------------------------------------------------------
                //  Attach and mount NetInstall if shadow path is not set in target
                // ------------------------------------------------------------------
                if ( [NBCDiskImageController attachNetInstallDiskImageWithShadowFile:[[self->_workflowItem target] nbiNetInstallURL] target:[self->_workflowItem target]  error:&error] ) {
                    
                    NSURL *netInstallVolumeURL = [[self->_workflowItem target] nbiNetInstallVolumeURL];
                    DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);
                    
                    if ( [netInstallVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                        
                        [self setCurrentVolume:@"NetInstall"];
                        [self setCurrentVolumeURL:netInstallVolumeURL];
                        [self setCurrentVolumeResources:resourcesNetInstallDict];
                        
                        // ------------------------------------------------------------------
                        //  Delete and recreate folder Packages
                        // ------------------------------------------------------------------
                        if ( (
                              [self->_creationTool isEqualToString:NBCMenuItemNBICreator] ||
                              [self->_workflowItem workflowType] == kWorkflowTypeImagr ||
                              [self->_workflowItem workflowType] == kWorkflowTypeCasper
                              ) && (
                                    [[[self->_workflowItem source] sourceType] isEqualToString:NBCSourceTypeInstallerApplication] ||
                                    [[[self->_workflowItem source] sourceType] isEqualToString:NBCSourceTypeInstallESDDiskImage]
                                    ) ) {
                            
                            // ---------------------------------------------------------------
                            //  Remove folder Packages and recreate an empty version
                            // ---------------------------------------------------------------
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self removeFolderPackagesInNetInstallVolume:netInstallVolumeURL];
                            });
                        } else {
                            
                            // ---------------------------------------------------------------
                            //  Install Packages
                            // ---------------------------------------------------------------
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self installPackagesToVolume];
                            });
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attach NetInstall returned yes but can't find volume path"] }];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount NetInstall failed"] }];
                    });
                }
            });
        }
    } else {
        [self applyModificationsToVolume];
    }
} // modifyVolumeNetInstall

- (void)modifyComplete {
    
    DDLogDebug(@"[DEBUG] Current volume is: %@", _currentVolume);
    
    if ( ! [_currentVolume isEqualToString:@"BaseSystem"] && ! [_currentVolume isEqualToString:@"NetInstall"] ) {
        DDLogDebug(@"[DEBUG] Current volume is unknown, setting current volume to BaseSystem...");
        [self setCurrentVolume:@"BaseSystem"];
    }
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *creationTool = userSettings[NBCSettingsNBICreationToolKey];
    
    if ( [_currentVolume isEqualToString:@"BaseSystem"] ) {
        
        if ( ! _isNBI || (
                          [_userSettingsChanged[NBCSettingsARDLoginKey] boolValue] ||
                          [_userSettingsChanged[NBCSettingsARDPasswordKey] boolValue]
                          ) ) {
            if ( ! _addedUsers && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
                [self addUsers];
                return;
            }
        }
        
        if ( [creationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            [self modifyVolumeNetInstall];
        } else {
            [self applyModificationsToVolume];
        }
    } else if ( [_currentVolume isEqualToString:@"NetInstall"] ) {
        [self applyModificationsToVolume];
    }
} // modifyComplete

- (void)modifyFailedWithError:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Modifying volume failed"] }];
} // modifyFailedWithError

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Finalize Modifications
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)finalizeWorkflow {
    if ( [[[_workflowItem target] baseSystemDisk] isMounted] && [[[_workflowItem target] baseSystemShadowPath] length] != 0 ) {
        [self convertBaseSystemFromShadow];
    } else if ( [[[_workflowItem target] nbiNetInstallDisk] isMounted] && [[[_workflowItem target] nbiNetInstallShadowPath] length] != 0 ) {
        [self convertNetInstallFromShadow];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Convert Disk Image From Shadow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)convertBaseSystemFromShadow {
    
    DDLogInfo(@"Converting BaseSystem disk image and shadow file...");
    [_delegate updateProgressStatus:@"Converting BaseSystem disk image and shadow file..." workflow:self];
    [_delegate updateProgressBar:(( 95.0 * _progressPercentage ) + _progressOffset )];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *error;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSURL *baseSystemDiskImageURL = [[self->_workflowItem target] baseSystemURL];
        DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
        
        NSString *baseSystemShadowPath = [[self->_workflowItem target] baseSystemShadowPath];
        DDLogDebug(@"[DEBUG] BaseSystem disk image shadow path: %@", baseSystemShadowPath);
        
        NSURL *baseSystemVolumeURL = [[self->_workflowItem target] baseSystemVolumeURL];
        DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
        
        if ( [NBCDiskImageController detachDiskImageAtPath:[baseSystemVolumeURL path]] ) {
            
            NSString *diskImageExtension;
            NSString *diskImageFormat;
            if ( [[self->_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                diskImageFormat = NBCDiskImageFormatSparseImage;
                diskImageExtension = @"sparseimage";
            } else {
                diskImageFormat = NBCDiskImageFormatReadOnly;
                diskImageExtension = @"dmg";
            }
            DDLogDebug(@"[DEBUG] BaseSystem converted disk image format: %@", diskImageFormat);
            DDLogDebug(@"[DEBUG] BaseSystem converted disk image extension: %@", diskImageExtension);
            
            NSURL *baseSystemDiskImageConvertedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.%@", [baseSystemDiskImageURL URLByDeletingPathExtension], diskImageFormat, diskImageExtension]];
            DDLogDebug(@"[DEBUG] BaseSystem converted disk image name: %@", [baseSystemDiskImageConvertedURL lastPathComponent]);
            DDLogDebug(@"[DEBUG] BaseSystem converted disk image path: %@", [baseSystemDiskImageConvertedURL path]);
            
            if ( [NBCDiskImageController convertDiskImageAtPath:[baseSystemDiskImageURL path] shadowImagePath:baseSystemShadowPath format:diskImageFormat destinationPath:[baseSystemDiskImageConvertedURL path]] ) {
                
                DDLogDebug(@"[DEBUG] Removing BaseSystem disk image...");
                if ( [fm removeItemAtURL:baseSystemDiskImageURL error:&error] ) {
                    baseSystemDiskImageURL = [[baseSystemDiskImageURL URLByDeletingPathExtension] URLByAppendingPathExtension:diskImageExtension];
                    if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:nil] ) {
                        if ( ! [fm removeItemAtURL:baseSystemDiskImageURL error:&error] ) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                            });
                            return;
                        }
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
                
                DDLogDebug(@"[DEBUG] Renaming converted BaseSystem disk image to %@...", [baseSystemDiskImageURL lastPathComponent]);
                if ( [fm moveItemAtURL:baseSystemDiskImageConvertedURL toURL:baseSystemDiskImageURL error:&error] ) {
                    [[self->_workflowItem target] setBaseSystemURL:baseSystemDiskImageURL];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
                
                DDLogDebug(@"[DEBUG] Removing BaseSystem disk image shadow file: %@", baseSystemShadowPath);
                if ( ! [fm removeItemAtPath:baseSystemShadowPath error:&error] ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
            } else {
                error = [NBCError errorWithDescription:@"Converting BaseSystem disk image failed"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
                });
                return;
            }
        } else {
            error = [NBCError errorWithDescription:@"Detaching BaseSystem disk image failed"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
            });
            return;
        }
        
        
        if ( [[self->_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            if ( [self applyReadWriteSettingsToBaseSystemDiskImage:baseSystemDiskImageURL error:&error] ) {
                if ( [[[self->_workflowItem target] nbiNetInstallDisk] isMounted] ) {
                    if ( [[[self->_workflowItem target] nbiNetInstallShadowPath] length] != 0 ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self convertNetInstallFromShadow];
                        });
                    } else {
                        [[[self->_workflowItem target] nbiNetInstallDisk] unmountWithOptions:kDADiskUnmountOptionDefault];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                    });
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
                });
            }
        } else if ( [self->_creationTool isEqualToString:NBCMenuItemNBICreator] ) {
            DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.dmg...", [baseSystemDiskImageURL lastPathComponent]);
            DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
            
            NSURL *netInstallDiskImageURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.dmg"];
            DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallDiskImageURL path]);
            
            if ( [[[NSFileManager alloc] init] moveItemAtURL:baseSystemDiskImageURL toURL:netInstallDiskImageURL error:&error] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finalizeWorkflow];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finalizeWorkflow];
            });
        }
    });
}

- (BOOL)applyReadWriteSettingsToBaseSystemDiskImage:(NSURL *)baseSystemDiskImageURL error:(NSError **)error {
    
    NSString *creationTool = [_workflowItem userSettings][NBCSettingsNBICreationToolKey];
    
    if ( [creationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        if ( [[_workflowItem userSettings][NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
            DDLogDebug(@"[DEBUG] Creating symlink from BaseSystem.dmg to BaseSystem.sparseimage...");
            return [self createSymlinkToSparseimageAtURL:baseSystemDiskImageURL error:error];
        } else {
            return YES;
        }
    } else if ( [creationTool isEqualToString:NBCMenuItemNBICreator] ) {
        if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteRenameKey] boolValue] ) {
            
            DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.dmg...", [baseSystemDiskImageURL lastPathComponent]);
            DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
            
            NSURL *netInstallDiskImageURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.dmg"];
            DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallDiskImageURL path]);
            
            return [[[NSFileManager alloc] init] moveItemAtURL:baseSystemDiskImageURL toURL:netInstallDiskImageURL error:error];
        } else {
            
            DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.sparseimage...", [baseSystemDiskImageURL lastPathComponent]);
            DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
            
            NSURL *netInstallDiskImageURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.sparseimage"];
            DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallDiskImageURL path]);
            
            if ( [[[NSFileManager alloc] init] moveItemAtURL:baseSystemDiskImageURL toURL:netInstallDiskImageURL error:error] ) {
                DDLogDebug(@"[DEBUG] Creating symlink from NetInstall.dmg to NetInstall.sparseimage...");
                return [self createSymlinkToSparseimageAtURL:netInstallDiskImageURL error:error];
            } else {
                return NO;
            }
        }
    } else {
        *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool: %@", creationTool]];
        return NO;
    }
}

- (void)convertNetInstallFromShadow {
    
    DDLogInfo(@"Converting NetInstall disk image and shadow file...");
    [self->_delegate updateProgressStatus:@"Converting NetInstall disk image and shadow file..." workflow:self];
    [_delegate updateProgressBar:(( 99.0 * _progressPercentage ) + _progressOffset)];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *error;
        NSFileManager *fm = [NSFileManager defaultManager];
        
        NSURL *netInstallDiskImageURL = [[self->_workflowItem target] nbiNetInstallURL];
        DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallDiskImageURL path]);
        
        NSString *netInstallShadowPath = [[self->_workflowItem target] nbiNetInstallShadowPath];
        DDLogDebug(@"[DEBUG] NetInstall disk image shadow path: %@", netInstallShadowPath);
        
        NSURL *netInstallVolumeURL = [[self->_workflowItem target] nbiNetInstallVolumeURL];
        DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);
        
        if ( [NBCDiskImageController detachDiskImageAtPath:[netInstallVolumeURL path]] ) {
            
            NSString *diskImageExtension;
            NSString *diskImageFormat;
            if ( [[self->_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                diskImageFormat = NBCDiskImageFormatSparseImage;
                diskImageExtension = @"sparseimage";
            } else {
                diskImageFormat = NBCDiskImageFormatReadOnly;
                diskImageExtension = @"dmg";
            }
            DDLogDebug(@"[DEBUG] NetInstall converted disk image format: %@", diskImageFormat);
            DDLogDebug(@"[DEBUG] NetInstall converted disk image extension: %@", diskImageExtension);
            
            NSURL *netInstallDiskImageConvertedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.%@", [netInstallDiskImageURL URLByDeletingPathExtension], diskImageFormat, diskImageExtension]];
            DDLogDebug(@"[DEBUG] NetInstall converted disk image name: %@", [netInstallDiskImageConvertedURL lastPathComponent]);
            DDLogDebug(@"[DEBUG] NetInstall converted disk image path: %@", [netInstallDiskImageConvertedURL path]);
            
            if ( [NBCDiskImageController convertDiskImageAtPath:[netInstallDiskImageURL path] shadowImagePath:netInstallShadowPath format:diskImageFormat destinationPath:[netInstallDiskImageConvertedURL path]] ) {
                
                DDLogDebug(@"[DEBUG] Removing NetInstall disk image...");
                if ( [fm removeItemAtURL:netInstallDiskImageURL error:&error] ) {
                    netInstallDiskImageURL = [[netInstallDiskImageURL URLByDeletingPathExtension] URLByAppendingPathExtension:diskImageExtension];
                    if ( [netInstallDiskImageURL checkResourceIsReachableAndReturnError:nil] ) {
                        if ( ! [fm removeItemAtURL:netInstallDiskImageURL error:&error] ) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                            });
                            return;
                        }
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
                
                DDLogDebug(@"[DEBUG] Renaming converted NetInstall disk image to %@...", [netInstallDiskImageURL lastPathComponent]);
                if ( [fm moveItemAtURL:netInstallDiskImageConvertedURL toURL:netInstallDiskImageURL error:&error] ) {
                    [[self->_workflowItem target] setBaseSystemURL:netInstallDiskImageURL];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
                
                DDLogDebug(@"[DEBUG] Removing NetInstall disk image shadow file: %@", netInstallShadowPath);
                if ( ! [fm removeItemAtPath:netInstallShadowPath error:&error] ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                    });
                    return;
                }
            } else {
                error = [NBCError errorWithDescription:@"Converting NetInstall disk image failed"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
                });
                return;
            }
        } else {
            error = [NBCError errorWithDescription:@"Detaching NetInstall disk image failed"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
            });
            return;
        }
        
        if ( [[self->_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            if ( [self applyReadWriteSettingsToNetInstallDiskImage:netInstallDiskImageURL error:&error] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finalizeWorkflow];
            });
        }
    });
}

- (BOOL)applyReadWriteSettingsToNetInstallDiskImage:(NSURL *)netInstallDiskImageURL error:(NSError **)error {
    
    NSString *creationTool = [_workflowItem userSettings][NBCSettingsNBICreationToolKey];
    
    if ( [creationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteRenameKey] boolValue] ) {
            
            DDLogDebug(@"[DEBUG] Renaming NetInstall.sparseimage to NetInstall.dmg...");
            
            NSURL *netInstallFolderURL = [netInstallDiskImageURL URLByDeletingLastPathComponent];
            DDLogDebug(@"[DEBUG] NetInstall disk image folder path: %@", [netInstallFolderURL path]);
            
            NSString *sparseImageName = [[netInstallDiskImageURL lastPathComponent] stringByDeletingPathExtension];
            DDLogDebug(@"[DEBUG] NetInstall disk image name: %@", sparseImageName);
            
            NSURL *sparseImageURL = [netInstallFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sparseimage", sparseImageName]];
            DDLogDebug(@"[DEBUG] NetInstall sparseimage path: %@", [sparseImageURL path]);
            
            NSURL *dmgURL = [netInstallFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.dmg", sparseImageName]];
            DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [dmgURL path]);
            
            return [[[NSFileManager alloc] init] moveItemAtURL:sparseImageURL toURL:dmgURL error:error];
        } else {
            DDLogDebug(@"[DEBUG] Creating symlink from NetInstall.dmg to NetInstall.sparseimage...");
            return [self createSymlinkToSparseimageAtURL:netInstallDiskImageURL error:error];
        }
    } else if ( [creationTool isEqualToString:NBCMenuItemNBICreator] ) {
        *error = [NBCError errorWithDescription:@"NBICreator creation tool shouldn't be here..."];
        return NO;
    } else {
        *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool: %@", creationTool]];
        return NO;
    }
}

- (BOOL)createSymlinkToSparseimageAtURL:(NSURL *)sparseImageURL error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Creating symlink to sparseimage at path: %@", [sparseImageURL path]);
    
    NSURL *sparseImageFolderURL = [sparseImageURL URLByDeletingLastPathComponent];
    NSString *sparseImageName = [[sparseImageURL lastPathComponent] stringByDeletingPathExtension];
    NSString *sparseImagePath = [NSString stringWithFormat:@"%@.sparseimage", sparseImageName];
    NSString *dmgLinkPath = [NSString stringWithFormat:@"%@.dmg", sparseImageName];
    NSURL *dmgLinkURL = [[sparseImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:dmgLinkPath];
    DDLogDebug(@"[DEBUG] Symlink path: %@", [dmgLinkURL path]);
    
    if ( [dmgLinkURL checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [[NSFileManager defaultManager] removeItemAtURL:dmgLinkURL error:error] ) {
            return NO;
        }
    }
    
    if ( [sparseImageFolderURL checkResourceIsReachableAndReturnError:error] ) {
        
        NSTask *lnTask =  [[NSTask alloc] init];
        [lnTask setLaunchPath:@"/bin/ln"];
        [lnTask setCurrentDirectoryPath:[sparseImageFolderURL path]];
        [lnTask setArguments:@[ @"-s", sparseImagePath, dmgLinkPath ]];
        [lnTask setStandardOutput:[NSPipe pipe]];
        [lnTask setStandardError:[NSPipe pipe]];
        [lnTask launch];
        [lnTask waitUntilExit];
        
        NSData *stdOutData = [[[lnTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        
        NSData *stdErrData = [[[lnTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
        
        if ( [lnTask terminationStatus] == 0 ) {
            DDLogDebug(@"[DEBUG] ln command successful!");
            return YES;
        } else {
            DDLogError(@"[ln][stdout] %@", stdOut);
            DDLogError(@"[ln][stderr] %@", stdErr);
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"ln command failed with exit status: %d", [lnTask terminationStatus]]];
            return NO;
        }
    } else {
        return NO;
    }
} // createSymlinkToSparseimageAtURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Install Packages
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)installPackagesToVolume {
    
    [_delegate updateProgressBar:(( 25.0 * _progressPercentage ) + _progressOffset)];
    
    NSArray *packagesArray = _currentVolumeResources[NBCWorkflowInstall];
    if ( [packagesArray count] != 0 ) {
        
        DDLogInfo(@"Installing packages to volume...");
        [_delegate updateProgressStatus:@"Installing packages to volume..." workflow:self];
        
        NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
        [installer setProgressDelegate:_delegate];
        [installer installPackagesToVolume:[[_workflowItem target] baseSystemVolumeURL] packages:packagesArray workflowItem:_workflowItem];
    } else {
        [self copyFilesToVolume];
    }
}

- (void)installSuccessful {
    [self copyFilesToVolume];
} // installSuccessful

- (void)installFailedWithError:(NSError *)error {
#pragma unused(error)
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Installing packages failed"] }];
} // installFailed

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Copy Files To Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)copyFilesToVolume {
    
    [_delegate updateProgressBar:(( 30.0 * _progressPercentage ) + _progressOffset)];
    
    NSArray *copyArray = _currentVolumeResources[NBCWorkflowCopy];
    if ( [copyArray count] != 0 ) {
        
        DDLogInfo(@"Copying files to volume...");
        [_delegate updateProgressStatus:@"Copying files to volume..." workflow:self];
        
        // --------------------------------
        //  Get Authorization
        // --------------------------------
        NSData *authData = [_workflowItem authData];
        if ( ! authData ) {
            authData = [NBCHelperAuthorization authorizeHelper];
            [_workflowItem setAuthData:authData];
        }
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
            if ( ! helperConnection ) {
                NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
                [helperConnector connectToHelper];
                [self->_workflowItem setHelperConnection:[helperConnector connection]];
            }
            [[self->_workflowItem helperConnection] setExportedObject:[self->_workflowItem progressView]];
            [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self copyFailedWithError:proxyError];
                });
            }] copyResourcesToVolume:self->_currentVolumeURL copyArray:copyArray authorization:authData withReply:^(NSError *error, int terminationStatus) {
                if ( terminationStatus == 0 ) {
                    if ( ! self->_isNBI ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self disableSpotlightOnVolume];
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self modifyComplete];
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self copyFailedWithError:error];
                    });
                }
            }];
        });
    } else {
        if ( ! self->_isNBI ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self disableSpotlightOnVolume];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self modifyComplete];
            });
        }
    }
} // copyFilesToVolume

- (void)copyFailedWithError:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Copying files to volume failed"] }];
} // copyFailedWithError

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify Items On Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)removeFolderPackagesInNetInstallVolume:(NSURL *)netInstallVolumeURL {
    
    [_delegate updateProgressBar:(( 60.0 * _progressPercentage ) + _progressOffset)];
    
    NSURL *packagesFolderURL = [netInstallVolumeURL URLByAppendingPathComponent:@"Packages"];
    DDLogDebug(@"[DEBUG] Packages folder path: %@", [packagesFolderURL path]);
    
    if ( [packagesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        
        DDLogInfo(@"Removing folder Packages in NetInstall volume...");
        [_delegate updateProgressStatus:@"Removing folder Packages in NetInstall volume..." workflow:self];
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:[self->_workflowItem progressView]];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self modifyFailedWithError:proxyError];
                });
            }] removeItemsAtPaths:@[ [packagesFolderURL path] ] withReply:^(NSError *error, BOOL success) {
                if ( success ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self createFolderPackagesInNetInstallVolume:packagesFolderURL];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self modifyFailedWithError:error];
                    });
                }
            }];
        });
    } else {
        [self createFolderPackagesInNetInstallVolume:packagesFolderURL];
    }
}

- (void)createFolderPackagesInNetInstallVolume:(NSURL *)packagesFolderURL {
    
    [_delegate updateProgressBar:(( 62.5 * _progressPercentage ) + _progressOffset)];
    
    DDLogInfo(@"Creating empty folder Packages/Extra in NetInstall volume...");
    [_delegate updateProgressStatus:@"Creating empty folder Packages/Extra in NetInstall volume..." workflow:self];
    
    NSError *error;
    
    NSURL *extrasFolderURL = [packagesFolderURL URLByAppendingPathComponent:@"Extras"];
    DDLogDebug(@"[DEBUG] Extras folder path: %@", [extrasFolderURL path]);
    
    if ( [[[NSFileManager alloc] init] createDirectoryAtURL:extrasFolderURL withIntermediateDirectories:YES attributes:@{
                                                                                                                         NSFileOwnerAccountName :      @"root",
                                                                                                                         NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                         NSFilePosixPermissions :      @0777
                                                                                                                         } error:&error] ) {
        
        // ---------------------------------------------------------------
        //  Install Packages
        // ---------------------------------------------------------------
        [self installPackagesToVolume];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating folder Extras failed!"]}];
    }
}

- (void)applyModificationsToVolume {
    
    [_delegate updateProgressBar:(( 85.0 * _progressPercentage ) + _progressOffset)];
    
    NSError *err = nil;
    
    if ( ! _modificationsApplied ) {
        NBCWorkflowResourcesModify *workflowResourcesModify = [[NBCWorkflowResourcesModify alloc] initWithWorkflowItem:_workflowItem];
        NSArray *modificationsArray = [workflowResourcesModify prepareResourcesToModify:&err];
        if ( [modificationsArray count] != 0 ) {
            
            DDLogInfo(@"Applying modifications to volume...");
            [_delegate updateProgressStatus:@"Applying modifications to volume..." workflow:self];
            
            // --------------------------------
            //  Get Authorization
            // --------------------------------
            NSData *authData = [_workflowItem authData];
            if ( ! authData ) {
                [NBCHelperAuthorization authorizeHelper];
                [_workflowItem setAuthData:authData];
            }
            
            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            dispatch_async(taskQueue, ^{
                
                NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
                if ( ! helperConnection ) {
                    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
                    [helperConnector connectToHelper];
                    [self->_workflowItem setHelperConnection:[helperConnector connection]];
                }
                [[self->_workflowItem helperConnection] setExportedObject:[self->_workflowItem progressView]];
                [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
                [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self modifyFailedWithError:proxyError];
                    });
                }] modifyResourcesOnVolume:self->_currentVolumeURL modificationsArray:modificationsArray authorization:authData withReply:^(NSError *error, int terminationStatus) {
                    [self setModificationsApplied:YES];
                    if ( terminationStatus == 0 ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if ( ( ! self->_isNBI && (
                                                      [[self->_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] ||
                                                      [[self->_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue]
                                                      ) ) || ( self->_isNBI && (
                                                                                [self->_userSettingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                                                                [self->_userSettingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                                                                )
                                                              ) ) {
                                [self updateKernelCache];
                            } else {
                                [self finalizeWorkflow];
                            }
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self modifyFailedWithError:error];
                        });
                    }
                }];
            });
        } else {
            if ( ! err ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( ( ! self->_isNBI && (
                                              [[self->_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] ||
                                              [[self->_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue]
                                              ) ) || ( self->_isNBI && (
                                                                        [self->_userSettingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                                                        [self->_userSettingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                                                        )
                                                      ) ) {
                        [self updateKernelCache];
                    } else {
                        [self finalizeWorkflow];
                    }
                });
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Modifying volume %@ failed", _currentVolume ]]}];
            }
        }
    } else {
        DDLogInfo(@"Modifications have already been applied...");
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( ( ! self->_isNBI && (
                                      [[self->_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] ||
                                      [[self->_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue]
                                      ) ) || ( self->_isNBI && (
                                                                [self->_userSettingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                                                [self->_userSettingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                                                )
                                              ) ) {
                [self updateKernelCache];
            } else {
                [self finalizeWorkflow];
            }
        });
    }
} // applyModificationsToVolume

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Disable Spotlight
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)disableSpotlightOnVolume {
    
    DDLogInfo(@"Disabling spotlight on volume...");
    [_delegate updateProgressStatus:@"Disabling spotlight on volume..." workflow:self];
    [_delegate updateProgressBar:(( 35.0 * _progressPercentage ) + _progressOffset)];
    
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:[self->_workflowItem progressView]];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self modifyFailedWithError:proxyError];
            });
        }] disableSpotlightOnVolume:[self->_currentVolumeURL path] authorization:authData withReply:^(NSError *error, int terminationStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( terminationStatus == 0 ) {
                    [self modifyComplete];
                } else {
                    [self modifyFailedWithError:error];
                }
            });
        }];
    });
} // disableSpotlightOnVolume

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Update Kernel Cache
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateKernelCache {
    
    DDLogInfo(@"Generating prelinked kernel and dyld caches...");
    [_delegate updateProgressStatus:@"Generating prelinked kernel and dyld caches..." workflow:self];
    [_delegate updateProgressBar:(( 90.0 * _progressPercentage ) + _progressOffset)];
    
    NSError *err;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // --------------------------------------------------------------------------
    //  Verify path to generateKernelCache script
    // --------------------------------------------------------------------------
    if ( ! [[[NSBundle mainBundle] URLForResource:@"generateKernelCache" withExtension:@"bash" subdirectory:@"Scripts"] checkResourceIsReachableAndReturnError:&err] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : err }];
        return;
    }
    
    NSString *targetVolumePath = [[[_workflowItem target] baseSystemVolumeURL] path];
    NSString *nbiVolumePath = [[_workflowItem temporaryNBIURL] path];
    NSString *minorVersion = [[_workflowItem source] expandVariables:@"%OSMINOR%"];
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:[self->_workflowItem progressView]];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : proxyError }];
            });
        }] updateKernelCache:targetVolumePath nbiVolumePath:nbiVolumePath minorVersion:minorVersion authorization:authData withReply:^(NSError *error, int terminationStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( terminationStatus == 0 ) {
                    [self finalizeWorkflow];
                } else {
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : error }];
                }
            });
        }];
    });
} // updateKernelCache

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Add Users
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addUsers {
    
    DDLogInfo(@"Adding users...");
    [_delegate updateProgressStatus:@"Adding users..." workflow:self];
    [_delegate updateProgressBar:(( 45.0 * _progressPercentage ) + _progressOffset)];
    
    NSError *err = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userSettings = [_workflowItem userSettings];
    
    // --------------------------------------------------------------------------
    //  Verify path to createUser script
    // --------------------------------------------------------------------------
    if ( ! [[[NSBundle mainBundle] URLForResource:@"createUser" withExtension:@"bash" subdirectory:@"Scripts"] checkResourceIsReachableAndReturnError:&err] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : err }];
        return;
    }
    
    NSString *nbiVolumePath = [[[_workflowItem target] baseSystemVolumeURL] path] ?: @"";
    NSString *userShortName = userSettings[NBCSettingsARDLoginKey] ?: @"nbicreator";
    NSString *userPassword = userSettings[NBCSettingsARDPasswordKey] ?: @"nbicreator";
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:[self->_workflowItem progressView]];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : proxyError }];
            });
        }] addUsersToVolumeAtPath:nbiVolumePath userShortName:userShortName userPassword:userPassword authorization:authData withReply:^(NSError *error, int terminationStatus) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( terminationStatus == 0 ) {
                    [self setAddedUsers:YES];
                    [self modifyComplete];
                } else {
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating user failed!"] }];
                }
            });
        }];
    });
} // addUsers

@end
