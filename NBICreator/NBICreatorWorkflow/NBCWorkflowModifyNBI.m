//
//  NBCWorkflowModifyNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-30.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowModifyNBI.h"
#import "NBCWorkflowItem.h"

#import "NBCError.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCVariables.h"

#import "ServerInformationComputerModelInfo.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCDiskImageController.h"
#import "NBCWorkflowResourcesModify.h"

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
    
    NSDictionary *settingsChanged = [workflowItem userSettingsChanged];
    
    NSError *error;
    NSURL *nbiURL;
    if ( _isNBI ) {
        nbiURL = [[workflowItem target] nbiURL];
    } else {
        nbiURL = [workflowItem temporaryNBIURL];
    }
    DDLogDebug(@"[DEBUG] NBI path: %@", [nbiURL path]);
    
    if ( [nbiURL checkResourceIsReachableAndReturnError:&error] ) {
        
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
                                      [settingsChanged[NBCSettingsNameKey] boolValue] ||
                                      [settingsChanged[NBCSettingsIndexKey] boolValue] ||
                                      [settingsChanged[NBCSettingsProtocolKey] boolValue] ||
                                      [settingsChanged[NBCSettingsEnabledKey] boolValue] ||
                                      [settingsChanged[NBCSettingsDefaultKey] boolValue] ||
                                      [settingsChanged[NBCSettingsDescriptionKey] boolValue]
                                      ) ) ) {
            
            DDLogInfo(@"Updating NBImageInfo.plist...");
            if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Updating NBImageInfo.plist..." workflow:self];
            }
            
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
    
    DDLogInfo(@"Updating NBI icon...");
    
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
        
        DDLogDebug(@"[DEBUG] Updating NBImageInfo.plist...");
        
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
    NSDictionary *resourcesBaseSystemDict = [[_workflowItem target] resourcesBaseSystemDict];
    if ( [resourcesBaseSystemDict count] != 0 ) {
        
        DDLogInfo(@"Modify BaseSystem volume...");
        
        NSError *error;
        
        // ------------------------------------------------------------------
        //  Verify that BaseSystem is mounted
        // ------------------------------------------------------------------
        
        //+ IMPROVEMENT Maybe check if mounted using shadow, not just mounted.
        
        NSURL *baseSystemVolumeURL = [[_workflowItem target] baseSystemVolumeURL];
        if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
            
            [self setCurrentVolume:@"BaseSystem"];
            [self setCurrentVolumeURL:baseSystemVolumeURL];
            [self setCurrentVolumeResources:resourcesBaseSystemDict];
            
            // ---------------------------------------------------------------
            //  Install Packages
            // ---------------------------------------------------------------
            [self installPackagesToVolume];
            
        } else if ( [[[_workflowItem target] baseSystemShadowPath] length] != 0 ) {
            
            // ------------------------------------------------------------------
            //  Resize and mount base system if shadow path is not set in target
            // ------------------------------------------------------------------
            if ( [NBCDiskImageController resizeAndMountBaseSystemWithShadow:[[_workflowItem target] baseSystemURL]  target:[_workflowItem target] error:&error] ) {
                
                baseSystemVolumeURL = [[_workflowItem target] baseSystemVolumeURL];
                if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                    
                    [self setCurrentVolume:@"BaseSystem"];
                    [self setCurrentVolumeURL:baseSystemVolumeURL];
                    [self setCurrentVolumeResources:resourcesBaseSystemDict];
                    
                    // ---------------------------------------------------------------
                    //  Install Packages
                    // ---------------------------------------------------------------
                    [self installPackagesToVolume];
                    return;
                }
            }
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem failed"] }];
        } else {
            NSLog(@"JUST MOUNT!?");
            [[_workflowItem target] printAllVariables];
        }
    } else {
        [self modifyVolumeNetInstall];
    }
} // modifyVolumeBaseSystem

- (void)modifyVolumeNetInstall {
    NSDictionary *resourcesNetInstallDict = [[_workflowItem target] resourcesNetInstallDict];
    if ( [resourcesNetInstallDict count] != 0 ) {
        
        DDLogInfo(@"Modify NetInstall volume...");
        
        NSError *error;
        
        // ------------------------------------------------------------------
        //  Verify that NetInstall is mounted
        // ------------------------------------------------------------------
        
        //+ IMPROVEMENT Maybe check if mounted using shadow, not just mounted.
        
        NSURL *netInstallVolumeURL = [[_workflowItem target] nbiNetInstallVolumeURL];
        if ( [netInstallVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
            
            [self setCurrentVolume:@"NetInstall"];
            [self setCurrentVolumeURL:netInstallVolumeURL];
            [self setCurrentVolumeResources:resourcesNetInstallDict];
            
            // ------------------------------------------------------------------
            //  Delete and recreate folder Packages
            // ------------------------------------------------------------------
            if (
                [_creationTool isEqualToString:NBCMenuItemNBICreator]
                && (
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
            NSLog(@"NET INSTALL NOT MOUNTED! FIX HERE");
        }
    } else {
        [self finalizeWorkflow];
    }
} // modifyVolumeNetInstall

- (void)modifyComplete {
    
    DDLogDebug(@"[DEBUG] Current volume is: %@", _currentVolume);
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSDictionary *userSettingsChanged = [_workflowItem userSettingsChanged];
    NSString *creationTool = userSettings[NBCSettingsNBICreationToolKey];
    
    if ( [_currentVolume isEqualToString:@"BaseSystem"] ) {
        
        if ( ( ! _isNBI && ! _updatedKernelCache && (
                                                     [[_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] ||
                                                     [[_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue] )
              ) || ( _isNBI && ! _updatedKernelCache && (
                                                         [userSettingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                                         [userSettingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                                         )
                    ) ) {
            [self updateKernelCache];
            return;
        }
        
        if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 && ! _addedUsers ) {
            [self addUsers];
            return;
        }
        
        if ( [creationTool isEqualToString:NBCMenuItemNBICreator] ) {
            [self finalizeWorkflow];
        } else if ( [creationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            [self modifyVolumeNetInstall];
        }
    } else if ( [_currentVolume isEqualToString:@"NetInstall"] ) {
        [self finalizeWorkflow];
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
    if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
        [self->_delegate updateProgressStatus:@"Converting BaseSystem disk image and shadow file..." workflow:self];
    }
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *baseSystemDiskImageURL = [[_workflowItem target] baseSystemURL];
    DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
    
    NSString *baseSystemShadowPath = [[_workflowItem target] baseSystemShadowPath];
    DDLogDebug(@"[DEBUG] BaseSystem disk image shadow path: %@", baseSystemShadowPath);
    
    NSURL *baseSystemVolumeURL = [[_workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
    
    if ( [NBCDiskImageController detachDiskImageAtPath:[baseSystemVolumeURL path]] ) {
        
        NSString *diskImageExtension;
        NSString *diskImageFormat;
        if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
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
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                        return;
                    }
                }
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
            
            DDLogDebug(@"[DEBUG] Renaming converted BaseSystem disk image to %@...", [baseSystemDiskImageURL lastPathComponent]);
            if ( [fm moveItemAtURL:baseSystemDiskImageConvertedURL toURL:baseSystemDiskImageURL error:&error] ) {
                [[_workflowItem target] setBaseSystemURL:baseSystemDiskImageURL];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
            
            DDLogDebug(@"[DEBUG] Removing BaseSystem disk image shadow file: %@", baseSystemShadowPath);
            if ( ! [fm removeItemAtPath:baseSystemShadowPath error:&error] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
        } else {
            error = [NBCError errorWithDescription:@"Converting BaseSystem disk image failed"];
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error }];
            return;
        }
    } else {
        error = [NBCError errorWithDescription:@"Detaching BaseSystem disk image failed"];
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
        return;
    }
    
    if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
        if ( [self applyReadWriteSettingsToBaseSystemDiskImage:baseSystemDiskImageURL error:&error] ) {
            if ( [_workflowItem userSettings][NBCMenuItemSystemImageUtility] ) {
                [self convertNetInstallFromShadow];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
            }
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error }];
        }
    } else {
        [self finalizeWorkflow];
    }
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
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *netInstallDiskImageURL = [[_workflowItem target] nbiNetInstallURL];
    DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallDiskImageURL path]);
    
    NSString *netInstallShadowPath = [[_workflowItem target] nbiNetInstallShadowPath];
    DDLogDebug(@"[DEBUG] NetInstall disk image shadow path: %@", netInstallShadowPath);
    
    NSURL *netInstallVolumeURL = [[_workflowItem target] nbiNetInstallVolumeURL];
    DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);
    
    if ( [NBCDiskImageController detachDiskImageAtPath:[netInstallVolumeURL path]] ) {
        
        NSString *diskImageExtension;
        NSString *diskImageFormat;
        if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
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
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
                        return;
                    }
                }
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
            
            DDLogDebug(@"[DEBUG] Renaming converted NetInstall disk image to %@...", [netInstallDiskImageURL lastPathComponent]);
            if ( [fm moveItemAtURL:netInstallDiskImageConvertedURL toURL:netInstallDiskImageURL error:&error] ) {
                [[_workflowItem target] setBaseSystemURL:netInstallDiskImageURL];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
            
            DDLogDebug(@"[DEBUG] Removing NetInstall disk image shadow file: %@", netInstallShadowPath);
            if ( ! [fm removeItemAtPath:netInstallShadowPath error:&error] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error }];
                return;
            }
        } else {
            error = [NBCError errorWithDescription:@"Converting NetInstall disk image failed"];
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error }];
            return;
        }
    } else {
        error = [NBCError errorWithDescription:@"Detaching NetInstall disk image failed"];
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error }];
        return;
    }
    
    if ( [[_workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
        if ( [self applyReadWriteSettingsToNetInstallDiskImage:netInstallDiskImageURL error:&error] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error }];
        }
    } else {
        [self finalizeWorkflow];
    }
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
            
            return [[[NSFileManager alloc] init] moveItemAtURL:sparseImageURL toURL:netInstallDiskImageURL error:error];
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
    NSArray *packagesArray = _currentVolumeResources[NBCWorkflowInstall];
    if ( [packagesArray count] != 0 ) {
        
        DDLogInfo(@"Installing packages to volume...");
        [_delegate updateProgressStatus:@"Installing packages to volume..." workflow:self];
        
        NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
        [installer installPackagesToVolume:[[_workflowItem target] baseSystemVolumeURL] packages:packagesArray];
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
    NSArray *copyArray = _currentVolumeResources[NBCWorkflowCopy];
    if ( [copyArray count] != 0 ) {
        
        DDLogInfo(@"Copying files to volume...");
        [_delegate updateProgressStatus:@"Copying files to volume..." workflow:self];
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self copyFailedWithError:proxyError];
            }];
        }] copyResourcesToVolume:_currentVolumeURL copyArray:copyArray withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self applyModificationsToVolume];
                } else {
                    [self copyFailedWithError:error];
                }
            }];
        }];
    } else {
        [self applyModificationsToVolume];
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
    NSURL *packagesFolderURL = [netInstallVolumeURL URLByAppendingPathComponent:@"Packages"];
    DDLogDebug(@"[DEBUG] Packages folder path: %@", [packagesFolderURL path]);
    
    if ( [packagesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogInfo(@"Removing folder Packages in NetInstall volume...");
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self modifyFailedWithError:proxyError];
            }];
        }] removeItemAtURL:packagesFolderURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self createFolderPackagesInNetInstallVolume:packagesFolderURL];
                } else {
                    [self modifyFailedWithError:error];
                }
            }];
        }];
    } else {
        [self createFolderPackagesInNetInstallVolume:packagesFolderURL];
    }
}

- (void)createFolderPackagesInNetInstallVolume:(NSURL *)packagesFolderURL {
    
    DDLogInfo(@"Creating empty folder Packages/Extra in NetInstall volume...");
    
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
    
    NSError *err = nil;
    
    NBCWorkflowResourcesModify *workflowResourcesModify = [[NBCWorkflowResourcesModify alloc] initWithWorkflowItem:_workflowItem];
    NSArray *modificationsArray = [workflowResourcesModify prepareResourcesToModify:&err];
    if ( [modificationsArray count] != 0 ) {
        
        DDLogInfo(@"Applying modifications to volume...");
        [_delegate updateProgressStatus:@"Applying modifications to volume..." workflow:self];
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self modifyFailedWithError:proxyError];
            }];
        }] modifyResourcesOnVolume:_currentVolumeURL modificationsArray:modificationsArray withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self disableSpotlightOnVolume];
                } else {
                    [self modifyFailedWithError:error];
                }
            }];
        }];
    } else {
        if ( ! err ) {
            [self disableSpotlightOnVolume];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Modifying volume %@ failed", _currentVolume ]]}];
        }
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
    
    NSString *command = @"/usr/bin/mdutil";
    NSArray *agruments = @[ @"-Edi", @"off", [_currentVolumeURL path] ];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self modifyFailedWithError:proxyError];
        }];
    }] runTaskWithCommand:command arguments:agruments currentDirectory:nil environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self modifyComplete];
            } else {
                [self modifyFailedWithError:error];
            }
        }];
    }];
    
} // disableSpotlightOnVolume

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Update Kernel Cache
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateKernelCache {
    
    DDLogInfo(@"Generating prelinked kernel and dyld caches...");
    [_delegate updateProgressStatus:@"Generating prelinked kernel and dyld caches..." workflow:self];
    
    NSError *err;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // --------------------------------------------------------------------------
    //  Get path to generateKernelCache script
    // --------------------------------------------------------------------------
    NSURL *generateKernelCacheScriptURL = [[NSBundle mainBundle] URLForResource:@"generateKernelCache" withExtension:@"bash"];
    if ( ! [generateKernelCacheScriptURL checkResourceIsReachableAndReturnError:&err] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : err }];
        return;
    }
    
    NSString *command = [generateKernelCacheScriptURL path];
    NSArray *arguments = @[
                           [[[_workflowItem target] baseSystemVolumeURL] path],
                           [[_workflowItem temporaryNBIURL] path],
                           [[_workflowItem source] expandVariables:@"%OSMINOR%"]
                           ];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : proxyError }];
        }];
    }] runTaskWithCommand:command arguments:arguments currentDirectory:nil environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self setUpdatedKernelCache:YES];
                [self modifyComplete];
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : error }];
            }
        }];
    }];
} // updateKernelCache

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Add Users
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addUsers {
    
    DDLogInfo(@"Adding users...");
    [_delegate updateProgressStatus:@"Adding users..." workflow:self];
    
    NSError *err;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userSettings = [_workflowItem userSettings];
    
    // --------------------------------------------------------------------------
    //  Get path to createUser script
    // --------------------------------------------------------------------------
    NSURL *createUserScriptURL = [[NSBundle mainBundle] URLForResource:@"createUser" withExtension:@"bash"];
    if ( ! [createUserScriptURL checkResourceIsReachableAndReturnError:&err] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : err }];
        return;
    }
    
    NSString *command = [createUserScriptURL path];
    NSArray *arguments = @[
                           [[[_workflowItem target] baseSystemVolumeURL] path] ?: @"",  // Variable ${1} - nbiVolumePath
                           userSettings[NBCSettingsARDLoginKey] ?: @"nbicreator",       // Variable ${2} - userShortName
                           userSettings[NBCSettingsARDPasswordKey] ?: @"nbicreator",    // Variable ${3} - userPassword
                           @"501",                                                      // Variable ${4} - userUID
                           @"admin"                                                     // Variable ${5} - userGroups
                           ];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    [[helperConnector connection] setExportedObject:[_workflowItem progressView]];
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : proxyError }];
        }];
    }] runTaskWithCommand:command arguments:arguments currentDirectory:nil environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self setAddedUsers:YES];
                [self modifyComplete];
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating user failed!"] }];
            }
        }];
    }];
} // addUsers

@end
