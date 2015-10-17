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


DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowModifyNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Modifying NBI...");
    NSError *error;
    [self setTargetController:[[NBCTargetController alloc] init]];
    
    [self setWorkflowItem:workflowItem];
    [self setSource:[workflowItem source]];
    [self setTarget:[workflowItem target]];
    [self setModifyBaseSystemComplete:NO];
    [self setModifyNetInstallComplete:NO];
    
    [self setIsNBI:( [[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) ? YES : NO];
    [self setSettingsChanged:[workflowItem userSettingsChanged]];
    
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    
    if ( temporaryNBIURL ) {
        DDLogInfo(@"Updating NBImageInfo.plist...");
        [_delegate updateProgressStatus:@"Updating NBImageInfo.plist..." workflow:self];
        
        // ---------------------------------------------------------------
        //  Apply all settings to NBImageInfo.plist in NBI
        // ---------------------------------------------------------------
        if ( [_targetController applyNBISettings:temporaryNBIURL workflowItem:workflowItem error:&error] ) {
            NSDictionary *userSettings = [workflowItem userSettings];
            NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
            if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                [self modifyNetInstall];
            } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                [self modifyBaseSystem];
            }
        } else {
            DDLogError(@"[ERROR] Error when applying NBImageInfo settings");
            DDLogError(@"%@", error);
            NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }
    } else {
        DDLogError(@"[ERROR] Could not get temporary NBI url from workflowItem");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

- (void)modifyNBISystemImageUtility {
    if ( [self resizeAndMountBaseSystemWithShadow:[_target baseSystemURL] target:_target] ) {
        // ---------------------------------------------------------------
        //  Modify BaseSystem using resources settings for BaseSystem
        // ---------------------------------------------------------------
        [self modifyBaseSystem];
        
    } else {
        DDLogError(@"[ERROR] Error when resizing BaseSystem!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        
    }
} // modifyNBISystemImageUtility

- (void)finalizeWorkflow {
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *baseSystemDiskImageURL = [_target baseSystemURL];
    NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
    
    // ------------------------------------------------------
    //  Convert and rename BaseSystem image from shadow file
    // ------------------------------------------------------
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_delegate updateProgressStatus:@"Converting BaseSystem.dmg and shadow file..." workflow:self];
    });
    
    if ( [_targetController convertBaseSystemFromShadow:_workflowItem error:&error] ) {
        if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            if ( [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                if ( ! [self createSymlinkToSparseimageAtURL:baseSystemDiskImageURL] ) {
                    DDLogError(@"[ERROR] Could not create synmlink for sparseimage");
                    [nc postNotificationName:NBCNotificationWorkflowFailed
                                      object:self
                                    userInfo:nil];
                    return;
                }
            }
        } else {
            baseSystemDiskImageURL = [_target baseSystemURL];
        }
    } else {
        DDLogError(@"[ERROR] Converting BaseSystem from shadow failed!");
        NSDictionary *userInfo = nil;
        if ( error ) {
            DDLogError(@"[ERROR] %@", error);
            userInfo = @{ NBCUserInfoNSErrorKey : error };
        }
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:userInfo];
        return;
    }
    
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        
        // ------------------------------------------------------
        //  Convert and rename NetInstall image from shadow file
        // ------------------------------------------------------
        if ( [_targetController convertNetInstallFromShadow:_workflowItem error:&error] ) {
            if ( ! [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                  object:self
                                userInfo:nil];
                return;
            } else {
                if ( [self createSymlinkToSparseimageAtURL:[_target nbiNetInstallURL]] ) {
                    [baseSystemDiskImageURL setResourceValue:@YES forKey:NSURLIsHiddenKey error:NULL];
                    [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                      object:self
                                    userInfo:nil];
                    return;
                } else {
                    DDLogError(@"[ERROR] Could not create synmlink for sparseimage");
                    [nc postNotificationName:NBCNotificationWorkflowFailed
                                      object:self
                                    userInfo:nil];
                    return;
                }
            }
        } else {
            DDLogError(@"[ERROR] Converting NetIstall from shadow failed!");
            NSDictionary *userInfo = nil;
            if ( error ) {
                DDLogError(@"[ERROR] %@", error);
                userInfo = @{ NBCUserInfoNSErrorKey : error };
            }
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:userInfo];
            return;
        }
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        
        // ------------------------------------------------------
        //  If system image is not r/w rename to dmg
        // ------------------------------------------------------
        if ( ! [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.dmg"];
            
            if ( [[NSFileManager defaultManager] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                  object:self
                                userInfo:nil];
                return;
            } else {
                DDLogError(@"[ERROR] Could not rename BaseSystem to NetInstall");
                NSDictionary *userInfo = nil;
                if ( error ) {
                    DDLogError(@"[ERROR] %@", error);
                    userInfo = @{ NBCUserInfoNSErrorKey : error };
                }
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:userInfo];
                return;
            }
        } else {
            
            // ----------------------------------------------------------------------
            //  If system image IS r/w, create symbolic link from sparseimage -> dmg
            // ----------------------------------------------------------------------
            NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.sparseimage"];
            
            //if ( ! [[NSFileManager defaultManager] removeItemAtURL:baseSystemDiskImageTargetURL error:&error] ) {
            //    NSLog(@"Remove Error: %@", error);
            //}
            
            if ( [[NSFileManager defaultManager] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
                if ( [self createSymlinkToSparseimageAtURL:baseSystemDiskImageTargetURL] ) {
                    [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                      object:self
                                    userInfo:nil];
                    return;
                } else {
                    DDLogError(@"[ERROR] Could not create synmlink for sparseimage");
                    [nc postNotificationName:NBCNotificationWorkflowFailed
                                      object:self
                                    userInfo:nil];
                    return;
                }
            } else {
                DDLogError(@"[ERROR] Could not rename BaseSystem to NetInstall");
                NSDictionary *userInfo = nil;
                if ( error ) {
                    DDLogError(@"[ERROR] %@", error);
                    userInfo = @{ NBCUserInfoNSErrorKey : error };
                }
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:userInfo];
            }
        }
    } else {
        DDLogError(@"[ERROR] Unknown creation tool");
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:nil];
    }
} // finalizeWorkflow

- (BOOL)createSymlinkToSparseimageAtURL:(NSURL *)sparseImageURL {
    BOOL retval = NO;
    
    NSString *sparseImageFolderPath = [[sparseImageURL URLByDeletingLastPathComponent] path];
    NSString *sparseImageName = [[sparseImageURL lastPathComponent] stringByDeletingPathExtension];
    NSString *sparseImagePath = [NSString stringWithFormat:@"%@.sparseimage", sparseImageName];
    NSString *dmgLinkPath = [NSString stringWithFormat:@"%@.dmg", sparseImageName];
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/bin/ln"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-s", sparseImagePath, dmgLinkPath, nil];
    if ( [sparseImageFolderPath length] != 0 ) {
        [newTask setCurrentDirectoryPath:sparseImageFolderPath];
        [newTask setArguments:args];
        [newTask launch];
        [newTask waitUntilExit];
        
        if ( [newTask terminationStatus] == 0 ) {
            retval = YES;
        } else {
            retval = NO;
        }
    } else {
        retval = NO;
    }
    
    return retval;
} // createSymlinkToSparseimageAtURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCInstallerPackageController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)installSuccessful {
    DDLogInfo(@"All packages installed successfuly!");
    
    // -------------------------------------------------------------------------
    //  Copy items to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    [self copyFilesToBaseSystem];
} // installSuccessful

- (void)installFailed:(NSError *)error {
#pragma unused(error)
    DDLogError(@"[ERROR] Install Failed!");
    NSDictionary *userInfo = nil;
    if ( error ) {
        DDLogError(@"[ERROR] %@", error);
        userInfo = @{ NBCUserInfoNSErrorKey : error };
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
} // installFailed

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify NetInstall Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyNetInstall {
    BOOL verified = YES;
    NSError *error;
    
    NSURL *nbiNetInstallURL = [_target nbiNetInstallURL];
    if ( [nbiNetInstallURL checkResourceIsReachableAndReturnError:&error] ) {
        
        // ------------------------------------------------------------------
        //  Attach NetInstall disk image using a shadow image to make it r/w
        // ------------------------------------------------------------------
        if ( [_targetController attachNetInstallDiskImageWithShadowFile:nbiNetInstallURL target:_target error:&error] ) {
            [self->_delegate updateProgressBar:92];
            
            
            // ------------------------------------------------------------------
            //  Remove Packages folder in NetInstall and create an empty folder
            // ------------------------------------------------------------------
            if ( ! _isNBI ) {
                [self removePackagesFolderInNetInstall];
            } else {
                [self copyFilesToNetInstall];
            }
            
        } else {
            DDLogError(@"[ERROR] Attaching NetInstall Failed!");
            DDLogError(@"%@", error);
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Could not get netInstallURL from target!");
        DDLogError(@"[ERROR] %@", error);
        verified = NO;
    }
    
    return verified;
} // modifyNetInstall

- (void)removePackagesFolderInNetInstall {
    NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
    if ( nbiNetInstallVolumeURL ) {
        
        // --------------------------------------
        //  Remove Packages folder in NetInstall
        // --------------------------------------
        NSURL *packagesFolderURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"Packages"];
        if ( [packagesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
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
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                }];
                
            }] removeItemAtURL:packagesFolderURL withReply:^(NSError *error, int terminationStatus) {
                [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                    if ( terminationStatus != 0 ) {
                        DDLogError(@"[ERROR] Delete Packages folder in NetInstall failed!");
                        NSDictionary *userInfo = nil;
                        if ( error ) {
                            DDLogError(@"[ERROR] %@", error);
                            userInfo = @{ NBCUserInfoNSErrorKey : error };
                        }
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                    } else {
                        [self createFoldersInNetInstall];
                    }
                }];
            }];
        } else {
            DDLogInfo(@"Packages folder doesn't exist in NetInstall!");
            [self createFoldersInNetInstall];
        }
    } else {
        DDLogError(@"[ERROR] nbiNetInstallVolumeURL is nil!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // removePackagesFolderInNetInstall

- (void)createFoldersInNetInstall {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
    if ( nbiNetInstallVolumeURL ) {
        NSURL *packagesFolderURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"Packages"];
        if ( ! [packagesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
            
            // ---------------------------------------------
            //  Create Packages/Extras folder in NetInstall
            // ---------------------------------------------
            NSURL *extrasFolderURL = [packagesFolderURL URLByAppendingPathComponent:@"Extras"];
            if ( [fm createDirectoryAtURL:extrasFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                [self->_delegate updateProgressBar:94];
                
                // ---------------------------------------------------------------------
                //  Copy all files to NetInstall using resourcesSettings for NetInstall
                // ---------------------------------------------------------------------
                [self copyFilesToNetInstall];
            } else {
                DDLogError(@"[ERROR] Could not create Packages and Extras folder in NetInstall");
                DDLogError(@"%@", error);
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }
        } else {
            DDLogError(@"[ERROR] Packages folder already exist in NetInstall!");
            DDLogError(@"%@", error);
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        DDLogError(@"[ERROR] nbiNetInstallVolumeURL is nil!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // createFoldersInNetInstall

- (void)copyFilesToNetInstall {
    DDLogInfo(@"Copying files to NetInstall volume...");
    [_delegate updateProgressStatus:@"Copying files to NetInstall..." workflow:self];
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesNetInstallDict = [_target resourcesNetInstallDict];
    NSURL *volumeURL = [_target nbiNetInstallVolumeURL];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self copyFailed:proxyError];
        }];
        
    }] copyResourcesToVolume:volumeURL resourcesDict:resourcesNetInstallDict withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self modifyNBISystemImageUtility];
            } else {
                DDLogError(@"[ERROR] Error while copying resources to NetInstall volume!");
                [self copyFailed:error];
            }
        }];
    }];
} // copyFilesToNetInstall

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify BaseSystem Volume
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target {
    BOOL verified = YES;
    NSError *error;
    
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
    [target setBaseSystemShadowPath:shadowFilePath];
    
    if ( baseSystemURL != nil ) {
        
        // ----------------------------------------
        //  Resize BaseSystem to fit extra content
        // ----------------------------------------
        [_delegate updateProgressStatus:@"Resizing disk image using shadow file..." workflow:self];
        if ( [NBCDiskImageController resizeDiskImageAtURL:baseSystemURL shadowImagePath:shadowFilePath] ) {
            
            // -------------------------------------------------------
            //  Attach BaseSystem and add volume url to target object
            // -------------------------------------------------------
            if ( ! [targetController attachBaseSystemDiskImageWithShadowFile:baseSystemURL target:target error:&error] ) {
                DDLogError(@"[ERROR] Attaching BaseSystem Failed!");
                DDLogError(@"%@", error);
                verified = NO;
            }
        } else {
            DDLogError(@"Resizing BaseSystem failed!");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Could not get nbiBaseSystemURL from target");
        verified = NO;
    }
    
    return verified;
} // resizeAndMountBaseSystemWithShadow:target

- (void)modifyBaseSystem {
    DDLogInfo(@"Modify BaseSystem Volume...");
    [_delegate updateProgressBar:95];
    
    // -------------------------------------------------------------------------
    //  Install packages to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    [self installPackagesToBaseSystem];
} // modifyBaseSystem

- (void)installPackagesToBaseSystem {
    DDLogInfo(@"Installing packages to BaseSystem Volume...");
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    if ( [resourcesBaseSystemDict count] != 0 ) {
        NSArray *packageArray = resourcesBaseSystemDict[NBCWorkflowInstall];
        if ( [packageArray count] != 0 ) {
            NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
            NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
            if ( nbiBaseSystemVolumeURL ) {
                
                // --------------------------------------------------------------------
                //  Loop through and install all packages from resourcesBaseSystemDict
                // --------------------------------------------------------------------
                [installer installPackagesToVolume:nbiBaseSystemVolumeURL packages:packageArray];
            } else {
                DDLogError(@"[ERROR] Could not get BaseSystem volume URL from target!");
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }
        } else {
            DDLogInfo(@"No packages to install!");
            [self copyFilesToBaseSystem];
        }
    } else {
        DDLogInfo(@"No packages to install!");
        [self copyFilesToBaseSystem];
    }
} // installPackagesToBaseSystem

- (void)copyFilesToBaseSystem {
    DDLogInfo(@"Copying files to BaseSystem.dmg volume...");
    [_delegate updateProgressStatus:@"Copying files to BaseSystem.dmg..." workflow:self];
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self copyFailed:proxyError];
        }];
        
    }] copyResourcesToVolume:volumeURL resourcesDict:resourcesBaseSystemDict withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self copyComplete];
            } else {
                [self copyFailed:error];
            }
        }];
    }];
} // copyFilesToBaseSystem

- (BOOL)createVNCPasswordHash:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL {
    BOOL retval = YES;
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.VNCSettings.txt
    // --------------------------------------------------------------
    NSURL *vncSettingsURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    NSString *vncPasswordString = userSettings[NBCSettingsARDPasswordKey];
    if ( [vncPasswordString length] != 0 ) {
        
        // This is NOT secure, should create internal function, but need to work for now to focus on getting screensharing to work first.
        NSTask *newTask =  [[NSTask alloc] init];
        [newTask setLaunchPath:@"/bin/bash"];
        NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-c",
                                [NSString stringWithFormat:@"/bin/echo %@ | perl -we 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack \"C*\", $_; foreach (@k) { printf \"%%02X\", $_ ^ (shift @p || 0) }; print \"\n\"'", vncPasswordString],
                                nil];
        [newTask setArguments:args];
        [newTask setStandardOutput:[NSPipe pipe]];
        
        [newTask launch];
        [newTask waitUntilExit];
        
        NSData *newTaskStandardOutputData = [[[newTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        
        if ( [newTask terminationStatus] == 0 ) {
            NSString *vncPasswordHash = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
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
        } else {
            DDLogError(@"[ERROR] Perl command failed!");
            retval = NO;
        }
    } else {
        DDLogWarn(@"[WARN] Got no VNC password from user Settings");
        retval = NO;
    }
    
    return retval;
} // createVNCPasswordHash:workflowItem:volumeURL

- (void)modifyFilesInBaseSystem {
    DDLogInfo(@"Modifying files on BaseSystem.dmg volume...");
    BOOL verified = YES;
    BOOL shouldAddUsers = NO;
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];
    
    int sourceVersionMinor = (int)[[[_workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        if ( verified ) {
            verified = [_targetController modifyRCInstall:modifyDictArray workflowItem:_workflowItem];
        }
        
        if ( verified && [userSettings[NBCSettingsImagrDisableATS] boolValue] ) {
            verified = [_targetController modifySettingsForImagr:modifyDictArray workflowItem:_workflowItem];
        }
        
        if ( verified && [userSettings[NBCSettingsAddTrustedNetBootServersKey] boolValue] ) {
            verified = [_targetController modifySettingsForTrustedNetBootServers:modifyDictArray workflowItem:_workflowItem];
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
                if ( [self createVNCPasswordHash:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL] ) {
                    shouldAddUsers = YES;
                } else {
                    verified = NO;
                }
            } else {
                verified = NO;
            }
        }
    }
    
    if ( verified ) {
        verified = [_targetController modifySettingsForLanguageAndKeyboardLayout:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified ) {
        verified = [_targetController settingsToRemove:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified ) {
        verified = [_targetController modifySettingsForRCCdrom:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified ) {
        verified = [_targetController modifySettingsForKextd:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsUseVerboseBootKey] boolValue] ) {
        verified = [_targetController modifySettingsForBootPlist:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] && [userSettings[NBCSettingsNetworkTimeServerKey] length] != 0 ) {
        verified = [_targetController modifyNBINTP:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
        verified = [_targetController modifySettingsForSystemKeychain:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsDisableWiFiKey] boolValue] ) {
        verified = [_targetController modifyNBIRemoveWiFi:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
        verified = [_targetController modifyNBIRemoveBluetooth:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsEnableLaunchdLoggingKey] boolValue] ) {
        verified = [_targetController modifySettingsForLaunchdLogging:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified && [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
        verified = [_targetController modifySettingsForConsole:modifyDictArray workflowItem:_workflowItem];
    }
    
    // Need to be last
    if ( verified ) {
        verified = [_targetController modifySettingsAddFolders:modifyDictArray workflowItem:_workflowItem];
    }
    
    if ( verified ) {
        [self modifyBaseSystemFiles:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL shouldAddUsers:shouldAddUsers];
    } else {
        [self modifyFailed];
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
                DDLogError(@"%@", proxyError);
                [self modifyFailed];
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
                    DDLogError(@"%@", error);
                    [self modifyFailed];
                }
            }];
        }];
    } else {
        DDLogError(@"[ERROR] Modify Array is empty!");
        [self modifyFailed];
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
        DDLogError(@"[ERROR] Password for ARD/VNC is empty!");
        [self modifyFailed];
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
                DDLogError(@"%@", proxyError);
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailed];
            }];
            
        }] runTaskWithCommandAtPath:commandURL arguments:createUserVariables currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self modifyComplete];
                } else {
                    DDLogError(@"[ERROR] Creating user failed!");
                    DDLogError(@"%@", error);
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self modifyFailed];
                }
            }];
        }];
    } else if ( [createUserVariables count] != 0 ) {
        DDLogError(@"[ERROR] Variables for createUser script need to be exactly 5!");
        [self modifyFailed];
    } else {
        DDLogError(@"[ERROR] Got no variables for script createUser");
        [self modifyFailed];
    }
} // addUsersToNBI

- (NSArray *)generateUserVariablesForCreateUsers:(NSDictionary *)userSettings {
    DDLogDebug(@"Generating variables for script createUsers.bash...");
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
                                        DDLogInfo(@"[generateKernelCache.bash][INFO] %@", errStr);
                                        
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
    if ( [[_workflowItem userSettings][NBCSettingsDisableWiFiKey] boolValue] || [[_workflowItem userSettings][NBCSettingsDisableBluetoothKey] boolValue] ) {
        [self generateKernelCacheForNBI:_workflowItem];
    } else {
        [self disableSpotlight];
    }
} // modifyComplete

- (void)modifyFailed {
    DDLogError(@"Modifications Failed!");
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
} // modifyFailed

- (void)copyComplete {
    DDLogInfo(@"Copy Complete!");
    [self modifyFilesInBaseSystem];
} // copyComplete

- (void)copyFailed:(NSError *)error {
    DDLogError(@"[ERROR] Copy Failed!");
    if ( error ) {
        DDLogError(@"[ERROR] %@", error);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
} // copyFailed

- (BOOL)modifySettingsForSpotlight:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /.Spotlight-V100/_IndexPolicy.plist
    // --------------------------------------------------------------
    NSURL *spotlightIndexingSettingsURL = [volumeURL URLByAppendingPathComponent:@".Spotlight-V100/_IndexPolicy.plist"];
    NSDictionary *spotlightIndexingSettingsAttributes;
    NSMutableDictionary *spotlightIndexingSettingsDict;
    if ( [spotlightIndexingSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        spotlightIndexingSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:spotlightIndexingSettingsURL];
        spotlightIndexingSettingsAttributes = [fm attributesOfItemAtPath:[spotlightIndexingSettingsURL path] error:&error];
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
    
    return retval;
} // modifySettingsForSpotlight

- (void)disableSpotlight {
    DDLogInfo(@"Disabling Spotlight on NBI...");
    [_delegate updateProgressStatus:@"Disabling Spotlight..." workflow:self];
    //NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *baseSystemPath = [[[_workflowItem target] baseSystemVolumeURL] path];
    NSArray *commandAgruments;
    if ( [baseSystemPath length] != 0 ) {
        commandAgruments = @[ @"-Edi", @"off", baseSystemPath ];
    } else {
        DDLogError(@"[ERROR] baseSystemPath is nil!");
        [self modifyFailed];
    }
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/bin/mdutil"];
    
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
                                        DDLogDebug(@"[mdutil][ERROR] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            DDLogError(@"%@", proxyError);
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self modifyFailed];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:commandAgruments currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self disableSpotlightIndex];
            } else {
                DDLogError(@"[ERROR] Creating user failed!");
                DDLogError(@"%@", error);
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailed];
            }
        }];
    }];
}

- (void)disableSpotlightIndex {
    NSMutableArray *spotlightSettings = [[NSMutableArray alloc] init];
    if ( ! [self modifySettingsForSpotlight:spotlightSettings workflowItem:_workflowItem] ) {
        DDLogError(@"[ERROR] modifySettingsForSpotlight returned nil!");
        [self modifyFailed];
    }
    
    NSURL *volumeURL = [[_workflowItem target] baseSystemVolumeURL];
    
    if ( [spotlightSettings count] != 0 ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                DDLogError(@"%@", proxyError);
                [self modifyFailed];
            }];
            
        }] modifyResourcesOnVolume:volumeURL resourcesDictArray:spotlightSettings withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    [self finalizeWorkflow];
                } else {
                    DDLogError(@"%@", error);
                    [self modifyFailed];
                }
            }];
        }];
    } else {
        DDLogError(@"[ERROR] spotlightSettings is nil!");
        [self modifyFailed];
    }
}

- (void)generateBootCachePlaylist {
    DDLogInfo(@"Generating BootCache.playlist...");
    [_delegate updateProgressStatus:@"Generating BootCache.playlist..." workflow:self];
    //NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *baseSystemPath = [[[_workflowItem target] baseSystemVolumeURL] path];
    NSString *playlistPath = [baseSystemPath stringByAppendingPathComponent:@"var/db/BootCache.playlist"];
    NSArray *commandAgruments;
    if ( [baseSystemPath length] != 0 ) {
        commandAgruments = @[ @"-f", playlistPath, @"generate", baseSystemPath ];
    } else {
        DDLogError(@"[ERROR] baseSystemPath is nil!");
        [self modifyFailed];
    }
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/BootCacheControl"];
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
                                        DDLogError(@"[BootCacheControl][ERROR] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            DDLogError(@"%@", proxyError);
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self modifyFailed];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:commandAgruments currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self finalizeWorkflow];
            } else {
                DDLogError(@"[ERROR] Creating user failed!");
                DDLogError(@"%@", error);
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self modifyFailed];
            }
        }];
    }];
}

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
