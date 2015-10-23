//
//  NBCWorkflowImagrModifyNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowModifyNBI.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowItem.h"
#import "NBCTarget.h"
#import "NBCTargetController.h"
#import "NSString+randomString.h"
#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCTargetController.h"
#import "NBCDisk.h"
#import "NBCDiskImageController.h"
#import "NBCMessageDelegate.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowModifyNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    NSError *error = nil;
    
    DDLogInfo(@"Modifying NBI...");
    
    [self setTargetController:[[NBCTargetController alloc] init]];
    [self setWorkflowItem:workflowItem];
    [self setSource:[workflowItem source]];
    [self setTarget:[workflowItem target]];
    [self setModifyBaseSystemComplete:NO];
    [self setModifyNetInstallComplete:NO];
    [self setIsNBI:( [[[workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", ( _isNBI ) ? @"YES" : @"NO" );
    [self setSettingsChanged:[workflowItem userSettingsChanged]];
    
    NSURL *nbiURL;
    if ( _isNBI ) {
        nbiURL = [[workflowItem target] nbiURL];
    } else {
        nbiURL = [workflowItem temporaryNBIURL];
    }
    DDLogDebug(@"[DEBUG] NBI path: %@", [nbiURL path]);
    
    if ( [nbiURL checkResourceIsReachableAndReturnError:&error] ) {
        
        // ---------------------------------------------------------------
        //  Apply all settings to NBImageInfo.plist in NBI
        // ---------------------------------------------------------------
        if ( ! _isNBI || ( _isNBI && (
                                      [_settingsChanged[NBCSettingsNameKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsIndexKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsProtocolKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsEnabledKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsDefaultKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsDescriptionKey] boolValue]
                                      ) ) ) {
            
            DDLogInfo(@"Updating NBImageInfo.plist...");
            [_delegate updateProgressStatus:@"Updating NBImageInfo.plist..." workflow:self];
            
            if ( ! [_targetController applyNBISettings:nbiURL workflowItem:workflowItem error:&error] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Updating NBImageInfo.plist failed"] }];
                return;
            }
        }
        
        NSDictionary *userSettings = [workflowItem userSettings];
        NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
        if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            [self modifyNetInstall];
        } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
            [self modifyBaseSystem];
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NBI doesn't exist at the expected path"] }];
    }
} // runWorkflow

- (void)modifyNBISystemImageUtility {
    
    NSError *error;
    
    if ( [self resizeAndMountBaseSystemWithShadow:[_target baseSystemURL] target:_target error:&error] ) {
        
        // ---------------------------------------------------------------
        //  Modify BaseSystem using resources settings for BaseSystem
        // ---------------------------------------------------------------
        [self modifyBaseSystem];
        
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resize and mount BaseSystem failed"] }];
    }
} // modifyNBISystemImageUtility

- (void)finalizeWorkflow {
    if ( ! _isNBI || ( _isNBI && [_workflowItem userSettingsChangedRequiresBaseSystem] ) ) {
        [self convertBaseSystem];
    } else {
        [self convertNetInstall];
    }
}

- (void)convertBaseSystem {
    
    DDLogInfo(@"Converting BaseSystem disk image and shadow file...");
    [self->_delegate updateProgressStatus:@"Converting BaseSystem disk image and shadow file..." workflow:self];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *error = nil;
        NSURL *baseSystemDiskImageURL = [self->_target baseSystemURL];
        NSDictionary *userSettings = [self->_workflowItem userSettings];
        
        if ( [self->_targetController convertBaseSystemFromShadow:self->_workflowItem error:&error] ) {
            DDLogDebug(@"[DEBUG] Conversion successful!");
            
            NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
            if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                DDLogDebug(@"[DEBUG] Creation tool is System Image Utility");
                
                if ( [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                    DDLogDebug(@"[DEBUG] Read/Write NetInstall images IS selected");
                    
                    DDLogDebug(@"[DEBUG] Creating symlink from BaseSystem.dmg to BaseSystem.sparseimage...");
                    if ( ! [self createSymlinkToSparseimageAtURL:baseSystemDiskImageURL error:&error] ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating symlink for BaseSystem failed"] }];
                        });
                        return;
                    }
                } else {
                    DDLogDebug(@"[DEBUG] Read/Write NetInstall images is NOT selected");
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self convertNetInstall];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Converting BaseSystem from shadow failed"] }];
                return;
            });
        }
    });
}

- (void)convertNetInstall {
    DDLogInfo(@"Converting NetInstall disk image and shadow file...");
    [self->_delegate updateProgressStatus:@"Converting NetInstall disk image and shadow file..." workflow:self];
    
    __block NSError *error = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
    NSURL *baseSystemDiskImageURL = [_target baseSystemURL];
    
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        DDLogDebug(@"[DEBUG] Creation tool is System Image Utility");
        
        // ------------------------------------------------------
        //  Convert and rename NetInstall image from shadow file
        // ------------------------------------------------------
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            
            if ( [self->_targetController convertNetInstallFromShadow:self->_workflowItem error:&error] ) {
                DDLogDebug(@"[DEBUG] Conversion successful!");
                
                if ( ! [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                    DDLogDebug(@"[DEBUG] Read/Write NetInstall images is NOT selected");
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                          object:self
                                        userInfo:nil];
                    });
                    return;
                } else {
                    DDLogDebug(@"[DEBUG] Read/Write NetInstall images IS selected");
                    
                    if ( [userSettings[NBCSettingsDiskImageReadWriteRenameKey] boolValue] ) {
                        DDLogDebug(@"[DEBUG] Renaming NetInstall.sparseimage to NetInstall.dmg...");
                        NSURL *netInstallFolderURL = [[self->_target nbiNetInstallURL] URLByDeletingLastPathComponent];
                        DDLogDebug(@"[DEBUG] NetInstall disk image folder path: %@", [netInstallFolderURL path]);
                        NSString *sparseImageName = [[[self->_target nbiNetInstallURL] lastPathComponent] stringByDeletingPathExtension];
                        DDLogDebug(@"[DEBUG] NetInstall disk image name: %@", sparseImageName);
                        NSURL *sparseImageURL = [netInstallFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sparseimage", sparseImageName]];
                        DDLogDebug(@"[DEBUG] NetInstall sparseimage path: %@", [sparseImageURL path]);
                        
                        if ( [[[NSFileManager alloc] init] moveItemAtURL:sparseImageURL toURL:[self->_target nbiNetInstallURL] error:&error] ) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                            });
                            return;
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Renaming NetInstall disk image failed"] }];
                            });
                            return;
                        }
                    } else {
                        DDLogDebug(@"[DEBUG] Creating symlink from NetInstall.dmg to NetInstall.sparseimage...");
                        
                        if ( [self createSymlinkToSparseimageAtURL:[self->_target nbiNetInstallURL] error:&error] ) {
                            
                            if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:&error] ) {
                                if ( ! [baseSystemDiskImageURL setResourceValue:@YES forKey:NSURLIsHiddenKey error:&error] ) {
                                    DDLogWarn(@"[WARN] %@", [error localizedDescription]);
                                }
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                        object:self
                                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"BaseSystem disk doesn't exist"] }];
                                });
                                return;
                            }
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                            });
                            return;
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating symlink for NetInstall failed"] }];
                            });
                            return;
                        }
                    }
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Converting NetIstall from shadow failed"] }];
                });
                return;
            }
        });
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        DDLogDebug(@"[DEBUG] Creation tool is NBICreator");
        
        if ( ! [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            DDLogDebug(@"[DEBUG] Read/Write NetInstall images is NOT selected");
            
            DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.dmg...", [baseSystemDiskImageURL lastPathComponent]);
            NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.dmg"];
            if ( [[NSFileManager defaultManager] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                });
                return;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Renaming BaseSystem disk image failed"] }];
                });
                return;
            }
        } else {
            DDLogDebug(@"[DEBUG] Read/Write NetInstall images IS selected");
            
            if ( [userSettings[NBCSettingsDiskImageReadWriteRenameKey] boolValue] ) {
                DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.dmg...", [baseSystemDiskImageURL lastPathComponent]);
                
                NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.dmg"];
                if ( [[[NSFileManager alloc] init] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                    });
                    return;
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating symlink for NetInstall failed"] }];
                    });
                    return;
                }
            } else {
                DDLogDebug(@"[DEBUG] Renaming %@ to NetInstall.sparseimage...", [baseSystemDiskImageURL lastPathComponent]);
                
                NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.sparseimage"];
                if ( [[NSFileManager defaultManager] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
                    DDLogDebug(@"[DEBUG] Creating symlink from NetInstall.dmg to NetInstall.sparseimage...");
                    
                    if ( [self createSymlinkToSparseimageAtURL:baseSystemDiskImageTargetURL error:&error] ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
                        });
                        return;
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating symlink for NetInstall failed"] }];
                        });
                        return;
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Renaming %@ failed", [baseSystemDiskImageURL lastPathComponent]]] }];
                    });
                    return;
                }
            }
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool: %@", nbiCreationTool]] }];
    }
} // convertNetInstall

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
#pragma mark Delegate Methods NBCInstallerPackageController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)installSuccessful {
    DDLogInfo(@"All packages installed successfully!");
    
    // -------------------------------------------------------------------------
    //  Copy items to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    [self copyFilesToBaseSystem];
} // installSuccessful

- (void)installFailed:(NSError *)error {
#pragma unused(error)
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Installing packages failed"] }];
} // installFailed

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify NetInstall Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyNetInstall {
    
    DDLogInfo(@"Modify NetInstall volume...");
    
    NSError *error;
    
    NSURL *nbiNetInstallURL = [_target nbiNetInstallURL];
    if ( [nbiNetInstallURL checkResourceIsReachableAndReturnError:&error] ) {
        
        if ( _isNBI ) {
            [self copyFilesToNetInstall];
        } else {
            
            // ------------------------------------------------------------------
            //  Attach NetInstall disk image using a shadow image to make it r/w
            // ------------------------------------------------------------------
            if ( [_targetController attachNetInstallDiskImageWithShadowFile:nbiNetInstallURL target:_target error:&error] ) {
                [self->_delegate updateProgressBar:92];
                
                
                // ------------------------------------------------------------------
                //  Remove Packages folder in NetInstall and create an empty folder
                // ------------------------------------------------------------------
                
                [self removePackagesFolderInNetInstall];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Attaching NetInstall disk image failed"] }];
            }
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NetInstall disk image path doesn't exist"] }];
    }
} // modifyNetInstall

- (void)removePackagesFolderInNetInstall {
    
    // --------------------------------------
    //  Remove Packages folder in NetInstall
    // --------------------------------------
    NSURL *packagesFolderURL = [[_target nbiNetInstallVolumeURL] URLByAppendingPathComponent:@"Packages"];
    DDLogDebug(@"[DEBUG] NetInstall volume packages folder path: %@", [packagesFolderURL path]);
    if ( [packagesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        
        DDLogInfo(@"Removing folder \"Packages\" from NetInstall volume");
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"Removing folder \"Packages\" from NetInstall volume failed"] }];
            }];
            
        }] removeItemAtURL:packagesFolderURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self createFoldersInNetInstall];
                } else {
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Removing folder \"Packages\" from NetInstall volume failed"] }];
                }
            }];
        }];
    } else {
        DDLogDebug(@"[DEBUG] Packages folder doesn't exist in NetInstall!");
        [self createFoldersInNetInstall];
    }
} // removePackagesFolderInNetInstall

- (void)createFoldersInNetInstall {
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *packagesFolderURL = [[_target nbiNetInstallVolumeURL] URLByAppendingPathComponent:@"Packages"];
    DDLogDebug(@"[DEBUG] NetInstall volume packages folder path: %@", [packagesFolderURL path]);
    
    if ( ! [packagesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        
        // ---------------------------------------------
        //  Create Packages/Extras folder in NetInstall
        // ---------------------------------------------
        NSURL *extrasFolderURL = [packagesFolderURL URLByAppendingPathComponent:@"Extras"];
        DDLogDebug(@"[DEBUG] NetInstall volume extras folder path: %@", [packagesFolderURL path]);
        
        DDLogDebug(@"[DEBUG] Creating folder \"Packages/Extras\" in NetInstall volume...");
        if ( [fm createDirectoryAtURL:extrasFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            [self->_delegate updateProgressBar:94];
            
            // ---------------------------------------------------------------------
            //  Copy all files to NetInstall using resourcesSettings for NetInstall
            // ---------------------------------------------------------------------
            [self copyFilesToNetInstall];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating folder \"Packages\" on NetInstall volume failed"] }];
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Folder \"Packages\" still exists on NetInstall volume"] }];
    }
} // createFoldersInNetInstall

- (void)copyFilesToNetInstall {
    
    DDLogInfo(@"Copying files to NetInstall disk image volume...");
    [_delegate updateProgressStatus:@"Copying files to NetInstall..." workflow:self];
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self copyFailedWithError:proxyError];
        }];
        
    }] copyResourcesToVolume:[_target nbiNetInstallVolumeURL] resourcesDict:[_target resourcesNetInstallDict] withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                if ( ! self->_isNBI || ( self->_isNBI && [self->_workflowItem userSettingsChangedRequiresBaseSystem] ) ) {
                    [self modifyNBISystemImageUtility];
                } else {
                    [self modifyComplete];
                }
            } else {
                [self copyFailedWithError:error];
            }
        }];
    }];
} // copyFilesToNetInstall

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify BaseSystem Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target error:(NSError **)error {
    
    DDLogInfo(@"Resize BaseSystem disk image and mount with shadow file...");
    
    NBCTargetController *targetController;
    if ( _targetController ) {
        targetController = _targetController;
    } else {
        targetController = [[NBCTargetController alloc] init];
    }
    
    // ---------------------------------------------------
    //  Generate a random path for BaseSystem shadow file
    // ---------------------------------------------------
    NSString *shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    DDLogDebug(@"[DEBUG] BaseSystem disk image shadow file path: %@", shadowFilePath);
    [target setBaseSystemShadowPath:shadowFilePath];
    
    if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
        
        // ----------------------------------------
        //  Resize BaseSystem to fit extra content
        // ----------------------------------------
        [_delegate updateProgressStatus:@"Resizing disk image using shadow file..." workflow:self];
        if ( [NBCDiskImageController resizeDiskImageAtURL:baseSystemURL shadowImagePath:shadowFilePath error:error] ) {
            
            // -------------------------------------------------------
            //  Attach BaseSystem and add volume url to target object
            // -------------------------------------------------------
            if ( ! [targetController attachBaseSystemDiskImageWithShadowFile:baseSystemURL target:target error:error] ) {
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }
    
    return YES;
} // resizeAndMountBaseSystemWithShadow:target:error

- (void)modifyBaseSystem {
    
    DDLogInfo(@"Modify BaseSystem volume...");
    [_delegate updateProgressBar:95];
    
    // -------------------------------------------------------------------------
    //  Install packages to BaseSystem disk image volume using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    [self installPackagesToBaseSystem];
} // modifyBaseSystem

- (void)installPackagesToBaseSystem {
    
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    if ( [resourcesBaseSystemDict count] != 0 ) {
        
        NSArray *packageArray = resourcesBaseSystemDict[NBCWorkflowInstall];
        if ( [packageArray count] != 0 ) {
            
            DDLogInfo(@"Installing packages to BaseSystem Volume...");
            [_delegate updateProgressStatus:@"Installing packages to BaseSystem Volume..." workflow:self];
            
            // --------------------------------------------------------------------
            //  Loop through and install all packages from resourcesBaseSystemDict
            // --------------------------------------------------------------------
            NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
            [installer installPackagesToVolume:[_target baseSystemVolumeURL] packages:packageArray];
        } else {
            [self copyFilesToBaseSystem];
        }
    } else {
        [self copyComplete];
    }
} // installPackagesToBaseSystem

- (void)copyFilesToBaseSystem {
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    if ( [resourcesBaseSystemDict count] != 0 ) {
        
        DDLogInfo(@"Copying files to BaseSystem disk image volume...");
        [_delegate updateProgressStatus:@"Copying files to BaseSystem disk image volume..." workflow:self];
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self copyFailedWithError:proxyError];
            }];
            
        }] copyResourcesToVolume:[_target baseSystemVolumeURL] resourcesDict:resourcesBaseSystemDict withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self copyComplete];
                } else {
                    [self copyFailedWithError:error];
                }
            }];
        }];
    } else {
        [self copyComplete];
    }
} // copyFilesToBaseSystem

- (BOOL)createVNCPasswordHash:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL error:(NSError **)error {
    
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.VNCSettings.txt
    // --------------------------------------------------------------
    NSURL *vncSettingsURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    DDLogDebug(@"[DEBUG] com.apple.VNCSettings.txt path: %@", [vncSettingsURL path]);
    
    NSString *vncPasswordString = userSettings[NBCSettingsARDPasswordKey];
    if ( [vncPasswordString length] != 0 ) {
        
        NSTask *perlTask =  [[NSTask alloc] init];
        [perlTask setLaunchPath:@"/bin/bash"];
        NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/bin/echo %@ | perl -we 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack \"C*\", $_; foreach (@k) { printf \"%%02X\", $_ ^ (shift @p || 0) }; print \"\n\"'", vncPasswordString]];
        [perlTask setArguments:args];
        [perlTask setStandardOutput:[NSPipe pipe]];
        [perlTask setStandardError:[NSPipe pipe]];
        [perlTask launch];
        [perlTask waitUntilExit];
        
        NSData *stdOutData = [[[perlTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        
        NSData *stdErrData = [[[perlTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
        
        if ( [perlTask terminationStatus] == 0 ) {
            DDLogDebug(@"[DEBUG] perl command successful!");
            
            NSString *vncPasswordHash = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            NSData *vncSettingsContentData = [vncPasswordHash dataUsingEncoding:NSUTF8StringEncoding];
            
            NSDictionary *vncSettingsAttributes = @{
                                                    NSFileOwnerAccountName : @"root",
                                                    NSFileGroupOwnerAccountName : @"wheel",
                                                    NSFilePosixPermissions : @0644
                                                    };
            
            NSDictionary *modifyVncSettings = @{
                                                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                NBCWorkflowModifyContent : vncSettingsContentData,
                                                NBCWorkflowModifyTargetURL : [vncSettingsURL path],
                                                NBCWorkflowModifyAttributes : vncSettingsAttributes
                                                };
            
            [modifyDictArray addObject:modifyVncSettings];
            return YES;
        } else {
            DDLogError(@"[perl][stdout] %@", stdOut);
            DDLogError(@"[perl][stderr] %@", stdErr);
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"perl command failed with exit status: %d", [perlTask terminationStatus]]];
            return NO;
        }
    } else {
        *error = [NBCError errorWithDescription:@"VNC password was empty!"];
        return NO;
    }
} // createVNCPasswordHash:workflowItem:volumeURL

- (void)modifyFilesInBaseSystem {
    
    NSError *error;
    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];
    BOOL verified = YES;
    BOOL shouldAddUsers = NO;
    int sourceVersionMinor = (int)[[[_workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    
    DDLogInfo(@"Modifying files on BaseSystem disk image volume...");
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    
    
    
    if ( 11 <= sourceVersionMinor ) {
        if ( verified ) {
            verified = [_targetController modifyRCInstall:modifyDictArray workflowItem:_workflowItem];
        }
        
        if ( verified && [userSettings[NBCSettingsImagrDisableATS] boolValue] ) {
            verified = [_targetController modifySettingsForImagr:modifyDictArray workflowItem:_workflowItem];
        }
        
        if ( ! _isNBI || ( _isNBI && (
                                      [_settingsChanged[NBCSettingsAddTrustedNetBootServersKey] boolValue] ||
                                      [_settingsChanged[NBCSettingsTrustedNetBootServersKey] boolValue]
                                      ) ) ) {
            if ( verified && [userSettings[NBCSettingsAddTrustedNetBootServersKey] boolValue] ) {
                verified = [_targetController modifySettingsForTrustedNetBootServers:modifyDictArray workflowItem:_workflowItem];
            }
        }
    }
    
    if ( verified && [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
        verified = [_targetController modifySettingsForDesktopViewer:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( ! _isNBI ) {
        if ( verified && [userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
            verified = [_targetController modifySettingsForMenuBar:modifyDictArray workflowItem:_workflowItem];
        }
        
        if ( verified && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
            if ( [_targetController modifySettingsForVNC:modifyDictArray workflowItem:_workflowItem] ) {
                if ( [self createVNCPasswordHash:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL error:&error] ) {
                    shouldAddUsers = YES;
                } else {
                    verified = NO;
                }
            } else {
                verified = NO;
            }
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsLanguageKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsKeyboardLayoutKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsTimeZoneKey] boolValue]
                                  ) ) ) {
        if ( verified ) {
            verified = [_targetController modifySettingsForLanguageAndKeyboardLayout:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( verified ) {
        verified = [_targetController settingsToRemove:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsCertificatesKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsAddCustomRAMDisksKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsRAMDisksKey] boolValue]
                                  ) ) ) {
        if ( verified ) {
            verified = [_targetController modifySettingsForRCCdrom:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                  ) ) ) {
        if ( verified ) {
            verified = [_targetController modifySettingsForKextd:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsUseVerboseBootKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsUseVerboseBootKey] boolValue] ) {
            verified = [_targetController modifySettingsForBootPlist:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsUseNetworkTimeServerKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsNetworkTimeServerKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] && [userSettings[NBCSettingsNetworkTimeServerKey] length] != 0 ) {
            verified = [_targetController modifyNBINTP:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsCertificatesKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
            verified = [_targetController modifySettingsForSystemKeychain:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableWiFiKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsDisableWiFiKey] boolValue] ) {
            verified = [_targetController modifyNBIRemoveWiFi:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
            verified = [_targetController modifyNBIRemoveBluetooth:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsEnableLaunchdLoggingKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsEnableLaunchdLoggingKey] boolValue] ) {
            verified = [_targetController modifySettingsForLaunchdLogging:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsIncludeConsoleAppKey] boolValue]
                                  ) ) ) {
        if ( verified && [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
            verified = [_targetController modifySettingsForConsole:modifyDictArray workflowItem:_workflowItem];
        }
    }
    
    // Need to be last
    if ( verified ) {
        verified = [_targetController modifySettingsAddFolders:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified ) {
        [self modifyBaseSystemFiles:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL shouldAddUsers:shouldAddUsers];
    } else {
        [self modifyFailedWithError:error];
    }
} // modifyFilesInBaseSystem

- (void)modifyBaseSystemFiles:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL shouldAddUsers:(BOOL)shouldAddUsers {
#pragma unused(workflowItem)
    
    if ( [modifyDictArray count] != 0 ) {
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [self modifyFailedWithError:proxyError];
            }];
            
        }] modifyResourcesOnVolume:volumeURL resourcesDictArray:modifyDictArray withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    if ( shouldAddUsers ) {
                        [self addUsersToNBI];
                    } else {
                        [self modifyComplete];
                    }
                } else {
                    [self modifyFailedWithError:error];
                }
            }];
        }];
    } else if ( _isNBI ) {
        [self modifyComplete];
    } else {
        [self modifyFailedWithError:[NBCError errorWithDescription:@"Modifications array was empty"]];
    }
} // modifyBaseSystemFiles:workflowItem:volumeURL:shouldAddUsers

- (void)addUsersToNBI {
    
    DDLogInfo(@"Adding users to NBI...");
    [_delegate updateProgressStatus:@"Adding user to NBI..." workflow:self];
    
    NSArray *createUserVariables;
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *password = userSettings[NBCSettingsARDPasswordKey];
    if ( [password length] != 0 ) {
        createUserVariables = [self generateUserVariablesForCreateUsers:userSettings];
    } else {
        [self modifyFailedWithError:[NBCError errorWithDescription:@"User password was empty"]];
        return;
    }
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        //NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        //NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogError(@"[createUser.bash][ERROR] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    if ( [createUserVariables count] == 6 ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailedWithError:proxyError];
            }];
            
        }] runTaskWithCommandAtPath:commandURL arguments:createUserVariables currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self modifyComplete];
                } else {
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self modifyFailedWithError:error];
                }
            }];
        }];
    } else if ( [createUserVariables count] != 0 ) {
        [self modifyFailedWithError:[NBCError errorWithDescription:@"Wrong number of variables for script createUser"]];
    } else {
        [self modifyFailedWithError:[NBCError errorWithDescription:@"Variables for script createUser was empty"]];
    }
} // addUsersToNBI

- (NSArray *)generateUserVariablesForCreateUsers:(NSDictionary *)userSettings {
    NSMutableArray *userVariables = [[NSMutableArray alloc] init];
    NSString *createUserScriptPath = [[NSBundle mainBundle] pathForResource:@"createUser" ofType:@"bash"];
    if ( [createUserScriptPath length] != 0 ) {
        [userVariables addObject:createUserScriptPath];
    } else {
        DDLogError(@"[ERROR] Path for script createUser.bash is empty!");
        return nil;
    }
    
    // -----------------------------------------------------------------------------------
    //  Variable ${1} - nbiVolumePath
    // -----------------------------------------------------------------------------------
    NSString *nbiVolumePath = [[[_workflowItem target] baseSystemVolumeURL] path];
    if ( [nbiVolumePath length] != 0 ) {
        [userVariables addObject:nbiVolumePath];
    } else {
        DDLogError(@"[ERROR] Path for BaseSystem.dmg volume is empty!");
        return nil;
    }
    
    // -----------------------------------------------------------------------------------
    //  Variable ${2} - userShortName
    // -----------------------------------------------------------------------------------
    NSString *userShortName = userSettings[NBCSettingsARDLoginKey];
    if ( [userShortName length] != 0 ) {
        [userVariables addObject:userShortName];
    } else {
        DDLogError(@"[ERROR] User short name is empty!");
        return nil;
    }
    
    // -----------------------------------------------------------------------------------
    //  Variable ${3} - userPassword
    // -----------------------------------------------------------------------------------
    NSString *userPassword = userSettings[NBCSettingsARDPasswordKey];
    if ( [ userPassword length] != 0 ) {
        [userVariables addObject:userPassword];
    } else {
        DDLogError(@"[ERROR] User password is empty!");
        return nil;
    }
    
    // -----------------------------------------------------------------------------------
    //  Variable ${4} - userUID
    // -----------------------------------------------------------------------------------
    NSString *userUID = @"599";
    if ( [userUID length] != 0 ) { // This is here for future functionality
        [userVariables addObject:userUID];
    } else {
        DDLogError(@"[ERROR] User UID is empty!");
        return nil;
    }
    
    // -----------------------------------------------------------------------------------
    //  Variable ${5} - userGroups
    // -----------------------------------------------------------------------------------
    NSString *userGroups = @"admin";
    if ( [userGroups length] != 0 ) { // This is here for future functionality
        [userVariables addObject:userGroups];
    } else {
        DDLogError(@"[ERROR] User groups is empty!");
        return nil;
    }
    
    return [userVariables copy];
} // generateUserVariablesForCreateUsers

- (void)generateKernelCacheForNBI:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Generating kernel and dyld caches...");
    [_delegate updateProgressStatus:@"Generating kernel and dyld caches..." workflow:self];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSMutableArray *generateKernelCacheVariables = [[NSMutableArray alloc] init];
    
    // --------------------------------------------------------------------------
    //  Get path to generateKernelCache script
    // --------------------------------------------------------------------------
    NSString *generateKernelCacheScriptPath = [[NSBundle mainBundle] pathForResource:@"generateKernelCache" ofType:@"bash"];
    if ( [generateKernelCacheScriptPath length] != 0 ) {
        [generateKernelCacheVariables addObject:generateKernelCacheScriptPath];
    } else {
        DDLogError(@"[ERROR] generateKernelCache script doesn't exist at path: %@", generateKernelCacheScriptPath);
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    
    [generateKernelCacheVariables addObject:[[[workflowItem target] baseSystemVolumeURL] path]];
    [generateKernelCacheVariables addObject:[[workflowItem temporaryNBIURL] path]];
    
    NSString *osVersionMinor = [[workflowItem source] expandVariables:@"%OSMINOR%"];
    if ( [osVersionMinor length] != 0 ) {
        [generateKernelCacheVariables addObject:osVersionMinor];
    }
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"[generateKernelCache.bash][stdout] %@", outStr);
                                        
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"[generateKernelCache.bash][stderr] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    if ( 3 < [generateKernelCacheVariables count] ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                NSDictionary *userInfo = nil;
                if ( proxyError ) {
                    DDLogError(@"[ERROR] %@", proxyError);
                    userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
                }
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
            }];
            
        }] runTaskWithCommandAtPath:commandURL arguments:generateKernelCacheVariables currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self disableSpotlight];
                } else {
                    NSDictionary *userInfo = nil;
                    if ( error ) {
                        DDLogError(@"[ERROR] %@", error);
                        userInfo = @{ NBCUserInfoNSErrorKey : error };
                    }
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                }
            }];
        }];
    } else {
        DDLogError(@"[ERROR] Variable count to be passed to script is %lu, script requires at least 4", (unsigned long)[generateKernelCacheVariables count]);
    }
}

- (void)modifyComplete {
    
    DDLogInfo(@"Modifications Complete!");
    
    if ( ( ! _isNBI && (
                        [[_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] ||
                        [[_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue] )
          ) || (_isNBI && (
                           [_settingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                           [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                           )
                ) ) {
        [self generateKernelCacheForNBI:_workflowItem];
    } else if ( _isNBI ) {
        [self finalizeWorkflow];
    } else {
        [self disableSpotlight];
    }
} // modifyComplete

- (void)modifyFailedWithError:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Modifying volume failed"] }];
} // modifyFailedWithError

- (void)copyComplete {
    DDLogInfo(@"Copy Complete!");
    [self modifyFilesInBaseSystem];
} // copyComplete

- (void)copyFailedWithError:(NSError *)error {
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Copying files to volume failed"] }];
} // copyFailedWithError

- (void)generateSettingsForSpotlight:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogDebug(@"[DEBUG] Generating settings for spotlight...");
    
    // --------------------------------------------------------------
    //  /.Spotlight-V100/_IndexPolicy.plist
    // --------------------------------------------------------------
    NSURL *spotlightIndexingSettingsURL = [[[workflowItem target] baseSystemVolumeURL] URLByAppendingPathComponent:@".Spotlight-V100/_IndexPolicy.plist"];
    DDLogDebug(@"[DEBUG] _IndexPolicy.plist path: %@", spotlightIndexingSettingsURL);
    NSDictionary *spotlightIndexingSettingsAttributes;
    NSMutableDictionary *spotlightIndexingSettingsDict;
    
    if ( [spotlightIndexingSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        spotlightIndexingSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:spotlightIndexingSettingsURL];
        spotlightIndexingSettingsAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[spotlightIndexingSettingsURL path] error:nil];
    }
    
    if ( [spotlightIndexingSettingsDict count] == 0 ) {
        spotlightIndexingSettingsDict = [[NSMutableDictionary alloc] init];
        spotlightIndexingSettingsAttributes = @{
                                                NSFileOwnerAccountName : @"root",
                                                NSFileGroupOwnerAccountName : @"wheel",
                                                NSFilePosixPermissions : @0600
                                                };
    }
    
    spotlightIndexingSettingsDict[@"Policy"] = @3;
    
    NSDictionary *modifySpotlightIndexingSettings = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                      NBCWorkflowModifyContent : spotlightIndexingSettingsDict,
                                                      NBCWorkflowModifyAttributes : spotlightIndexingSettingsAttributes,
                                                      NBCWorkflowModifyTargetURL : [spotlightIndexingSettingsURL path]
                                                      };
    
    [modifyDictArray addObject:modifySpotlightIndexingSettings];
} // generateSettingsForSpotlight:workflowItem

- (void)disableSpotlight {
    
    DDLogInfo(@"Disabling Spotlight...");
    [_delegate updateProgressStatus:@"Disabling Spotlight..." workflow:self];
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/bin/mdutil"];
    NSArray *commandAgruments = @[ @"-Edi", @"off", [[[_workflowItem target] baseSystemVolumeURL] path] ];
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"[mdutil][stdout] %@", outStr);
                                        
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"[mdutil][stderr] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self modifyFailedWithError:proxyError];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:commandAgruments currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self disableSpotlightIndex];
            } else {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailedWithError:error];
            }
        }];
    }];
}

- (void)disableSpotlightIndex {
    
    DDLogDebug(@"[DEBUG] Disabling spotlight index...");
    
    NSMutableArray *spotlightSettings = [[NSMutableArray alloc] init];
    [self generateSettingsForSpotlight:spotlightSettings workflowItem:_workflowItem];
    
    if ( [spotlightSettings count] != 0 ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [self modifyFailedWithError:proxyError];
            }];
            
        }] modifyResourcesOnVolume:[[_workflowItem target] baseSystemVolumeURL] resourcesDictArray:spotlightSettings withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self finalizeWorkflow];
                } else {
                    [self modifyFailedWithError:error];
                }
            }];
        }];
    } else {
        [self modifyFailedWithError:[NBCError errorWithDescription:@"Generated spotlight settings was empty"]];
    }
}

- (void)generateBootCachePlaylist {
    
    DDLogInfo(@"Generating BootCache.playlist...");
    [_delegate updateProgressStatus:@"Generating BootCache.playlist..." workflow:self];
    
    NSString *baseSystemPath = [[[_workflowItem target] baseSystemVolumeURL] path];
    NSString *playlistPath = [baseSystemPath stringByAppendingPathComponent:@"var/db/BootCache.playlist"];
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/BootCacheControl"];
    NSArray *commandAgruments = @[ @"-f", playlistPath, @"generate", baseSystemPath ];
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogError(@"[BootCacheControl][stdout] %@", outStr);
                                        
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogError(@"[BootCacheControl][stderr] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self modifyFailedWithError:proxyError];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:commandAgruments currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self finalizeWorkflow];
            } else {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailedWithError:error];
            }
        }];
    }];
} // generateBootCachePlaylist

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateProgressBar:(double)value {
    double precentage = (((40 * value)/100) + 80);
    [_delegate updateProgressBar:precentage];
} // updateProgressBar

@end
