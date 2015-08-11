//
//  NBCWorkflowImagrModifyNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowModifyNBI.h"
#import "NBCConstants.h"
#import "NSString+randomString.h"

#import "NBCWorkflowItem.h"
//#import "NBCWorkflowProgressViewController.h"

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCTargetController.h"

#import "NBCDisk.h"
#import "NBCDiskImageController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCMessageDelegate.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowModifyNBI

#pragma mark -
#pragma mark Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Modifying NBI...");
    NSError *error;
    _targetController = [[NBCTargetController alloc] init];
    
    [self setWorkflowItem:workflowItem];
    [self setSource:[workflowItem source]];
    [self setTarget:[workflowItem target]];
    [self setModifyBaseSystemComplete:NO];
    [self setModifyNetInstallComplete:NO];
    
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
                [self modifyNBISystemImageUtility];
            } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                [self modifyBaseSystem];
            }
        } else {
            NSLog(@"Error when applying NBImageInfo settings");
            NSLog(@"Error: %@", error);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        NSLog(@"Could not get temporary NBI url from workflowItem");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

- (void)modifyNBISystemImageUtility {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    // ---------------------------------------------------------------
    //  Modify netInstall using resources settings for NetInstall
    // ---------------------------------------------------------------
    BOOL verified = [self modifyNetInstall];
    if ( verified ) {
        verified = [self resizeAndMountBaseSystemWithShadow:[_target baseSystemURL] target:_target];
        if ( verified ) {
            
            // ---------------------------------------------------------------
            //  Modify BaseSystem using resources settings for BaseSystem
            // ---------------------------------------------------------------
            [self modifyBaseSystem];
            
        } else {
            NSLog(@"Error when resizing BaseSystem");
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            
        }
    } else {
        NSLog(@"Error when modifying NBI NetInstall");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
}

- (void)finalizeWorkflow {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    NSURL *baseSystemDiskImageURL = [_target baseSystemURL];
    
    /*
    [_delegate updateProgressStatus:@"Compacting BaseSystem.dmg..." workflow:self];
    if ( ! [NBCDiskImageController compactDiskImageAtPath:[baseSystemDiskImageURL path] shadowImagePath:baseSystemShadowPath] ) {
        NSLog(@"Compacting BaseSystem failed!");
        NSLog(@"Error: %@", error);
        
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    */
    
    // ------------------------------------------------------
    //  Convert and rename BaseSystem image from shadow file
    // ------------------------------------------------------
    [_delegate updateProgressStatus:@"Converting BaseSystem.dmg and shadow file to sparseimage..." workflow:self];
    if ( ! [_targetController convertBaseSystemFromShadow:_target error:&error] ) {
        NSLog(@"Converting BaseSystem from shadow failed!");
        NSLog(@"Error: %@", error);
        
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [baseSystemDiskImageURL setResourceValue:@YES forKey:NSURLIsHiddenKey error:NULL];
        
        // ------------------------------------------------------
        //  Convert and rename NetInstall image from shadow file
        // ------------------------------------------------------
        if ( [_targetController convertNetInstallFromShadow:_target error:&error] ) {
            [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
        } else {
            NSLog(@"Converting NetIstall from shadow failed!");
            NSLog(@"Error: %@", error);
            
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        NSURL *baseSystemDiskImageTargetURL = [[baseSystemDiskImageURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"NetInstall.sparseimage"];
        if ( [[NSFileManager defaultManager] moveItemAtURL:baseSystemDiskImageURL toURL:baseSystemDiskImageTargetURL error:&error] ) {
            NSTask *newTask =  [[NSTask alloc] init];
            [newTask setLaunchPath:@"/bin/ln"];
            
            NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-s", @"NetInstall.sparseimage", @"NetInstall.dmg", nil];
            
            NSString *nbiFolder = [[_workflowItem temporaryNBIURL] path];
            
            [newTask setCurrentDirectoryPath:nbiFolder];
            [newTask setArguments:args];
            [newTask launch];
            [newTask waitUntilExit];
            
            if ( [newTask terminationStatus] == 0 ) {
                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }
        } else {
            NSLog(@"Could not rename BaseSystem to NetInstall");
            NSLog(@"Error: %@", error);
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        NSLog(@"Unknown creationTool!?");
    }
} // finalizeWorkflow

#pragma mark -
#pragma mark Modify NetInstall Volume
#pragma mark -

- (BOOL)modifyNetInstall {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL verified = YES;
    NSError *error;
    
    NSURL *nbiNetInstallURL = [_target nbiNetInstallURL];
    if ( nbiNetInstallURL ) {
        // ------------------------------------------------------------------
        //  Attach NetInstall disk image using a shadow image to make it r/w
        // ------------------------------------------------------------------
        if ( [_targetController attachNetInstallDiskImageWithShadowFile:nbiNetInstallURL target:_target error:&error] ) {
            //dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate updateProgressBar:92];
            //[[self->_progressView progressIndicator] setDoubleValue:92];
            //});
            
            // ------------------------------------------------------------------
            //  Remove Packages folder in NetInstall and create an empty folder
            // ------------------------------------------------------------------
            if ( [self replacePackagesFolderInNetInstall] ) {
                // ---------------------------------------------------------------------
                //  Copy all files to NetInstall using resourcesSettings for NetInstall
                // ---------------------------------------------------------------------
                if ( ! [self copyFilesToNetInstall] ) {
                    NSLog(@"Error while copying files to NBI NetInstall volume!");
                    verified = NO;
                }
            } else {
                NSLog(@"Could not replace Packages folder in NetInstall");
                verified = NO;
            }
        } else {
            NSLog(@"Attaching NetInstall Failed!");
            NSLog(@"Error: %@", error);
            verified = NO;
        }
    } else {
        NSLog(@"Could not get netInstallURL from target!");
        verified = NO;
    }
    
    return verified;
} // modifyNetInstall

- (BOOL)replacePackagesFolderInNetInstall {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL verified = YES;
    NSError *error;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
    NSLog(@"nbiNetInstallVolumeURL=%@", nbiNetInstallVolumeURL);
    if ( nbiNetInstallVolumeURL ) {
        // --------------------------------------
        //  Remove Packages folder in NetInstall
        // --------------------------------------
        NSURL *packagesFolderURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"Packages"];
        if ( ! [fm removeItemAtURL:packagesFolderURL error:&error] ) {
            NSLog(@"Could not remove Packages folder from NetInstall!");
            NSLog(@"Error: %@", error);
            
            verified = NO;
            return verified;
        }
        
        NSURL *extrasFolderURL = [packagesFolderURL URLByAppendingPathComponent:@"Extras"];
        
        // ---------------------------------------------
        //  Create Packages/Extras folder in NetInstall
        // ---------------------------------------------
        if ( ! [packagesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
            if ( [fm createDirectoryAtURL:extrasFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                [self->_delegate updateProgressBar:94];
                //dispatch_async(dispatch_get_main_queue(), ^{
                //   [[self->_progressView progressIndicator] setDoubleValue:94];
                //});
            } else {
                NSLog(@"Could not create Packages and Extras folder in NetInstall");
                NSLog(@"Error: %@", error);
                
                verified = NO;
            }
        }
    } else {
        NSLog(@"Could not get netInstallVolumeURL form target");
        verified = NO;
    }
    
    return verified;
} // replacePackagesFolderInNetInstall

- (BOOL)copyFilesToNetInstall {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL verified = YES;
    NSError *error;
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesNetInstallDict to NetInstall
    // ---------------------------------------------------------
    NSDictionary *resourcesNetInstallDict = [_target resourcesNetInstallDict];
    NSLog(@"resourcesNetInstallDict=%@", resourcesNetInstallDict);
    NSURL *volumeURL = [_target nbiNetInstallVolumeURL];
    if ( ! [_targetController copyResourcesToVolume:volumeURL resourcesDict:resourcesNetInstallDict target:_target error:&error] ) {
        NSLog(@"Error while copying resources to NetInstall volume!");
        NSLog(@"Error: %@", error);
        verified = NO;
    }
    
    return verified;
} // copyFilesToNetInstall

#pragma mark -
#pragma mark Modify BaseSystem Volume
#pragma mark -

- (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
                NSLog(@"Attachign BaseSystem Failed!");
                NSLog(@"Error: %@", error);
                
                verified = NO;
            }
        } else {
            NSLog(@"Resizing BaseSystem failed!");
            
            verified = NO;
        }
    } else {
        NSLog(@"Could not get nbiBaseSystemURL from target");
        
        verified = NO;
    }
    
    return verified;
}

- (void)modifyBaseSystem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"modifyBaseSystem");
    [_delegate updateProgressBar:95];
    
    // -------------------------------------------------------------------------
    //  Install packages to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    [self installPackagesToBaseSystem];
} // modifyBaseSystem

- (void)installSuccessful {
    NSLog(@"installSuccessful");
    
    // -------------------------------------------------------------------------
    //  Copy items to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    NSLog(@"Copying Files to BaseSystem!");
    [self copyFilesToBaseSystem];
}

- (void)installFailed {
    NSLog(@"Install Failed!");
}

- (void)installPackagesToBaseSystem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"installPackagesToBaseSystem");
    NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
    NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
    if ( nbiBaseSystemVolumeURL ) {
        
        // --------------------------------------------------------------------
        //  Loop through and install all packages from resourcesBaseSystemDict
        // --------------------------------------------------------------------
        NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
        if ( [resourcesBaseSystemDict count] != 0 ) {
            NSArray *packageArray = resourcesBaseSystemDict[NBCWorkflowInstall];
            if ( [packageArray count] != 0 ) {
                [installer installPackagesToVolume:nbiBaseSystemVolumeURL packages:packageArray];
            } else {
            NSLog(@"resourcesBaseSystemDict is empty!");
                [self copyFilesToBaseSystem];
            }
        } else {
            NSLog(@"resourcesBaseSystemDict is nil!");
            [self copyFilesToBaseSystem];
        }
    }
} // installPackagesToBaseSystem

- (void)copyFilesToBaseSystem {
    NSLog(@"copyFilesToBaseSystem");
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    
    //NSError *error;
    //[_targetController copyResourcesToVolume:volumeURL resourcesDict:resourcesBaseSystemDict target:_target error:&error];
    
    [_delegate updateProgressStatus:@"Copying files to BaseSystem.dmg..." workflow:self];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
            // ------------------------------------------------------------------
            NSLog(@"ProxyError? %@", proxyError);
            [self copyFailed];
        }];
        
    }] copyResourcesToVolume:volumeURL resourcesDict:resourcesBaseSystemDict withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self copyComplete];
            } else {
                NSLog(@"CopyFailed!");
                NSLog(@"Error: %@", error);
                [self copyFailed];
            }
        }];
    }];
} // copyFilesToBaseSystem

- (void)createVNCPasswordHash:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *userSettings = [workflowItem userSettings];
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.VNCSettings.txt
    // --------------------------------------------------------------
    NSURL *vncSettingsURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    NSString *vncPasswordString = userSettings[NBCSettingsARDPasswordKey];
    
    
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
    
    NSData *newTaskStandardOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
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
        NSLog(@"Perl command failed!");
        [self modifyFailed];
    }
}

- (void)modifyFilesInBaseSystem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"");
    BOOL shouldModify = NO;
    BOOL shouldAddUsers = NO;
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];
    
    [_targetController modifyNBINTP:modifyDictArray workflowItem:_workflowItem];
    [_targetController modifySettingsForMenuBar:modifyDictArray workflowItem:_workflowItem];
    [_targetController modifySettingsForSystemKeychain:modifyDictArray workflowItem:_workflowItem];
    
    if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] ) {
        [_targetController modifyNBIRemoveWiFi:modifyDictArray workflowItem:_workflowItem];
        shouldModify = YES;
    }
    
    if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [_targetController modifySettingsAddFolders:modifyDictArray workflowItem:_workflowItem];
        [_targetController modifySettingsForVNC:modifyDictArray workflowItem:_workflowItem];
        shouldModify = YES;
        shouldAddUsers = YES;
        
        [self createVNCPasswordHash:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL];
    }
    
    if ( shouldModify ) {
        [self modifyBaseSystemFiles:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL shouldAddUsers:shouldAddUsers];
    } else {
        [self modifyComplete];
    }
}

- (void)modifyBaseSystemFiles:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL shouldAddUsers:(BOOL)shouldAddUsers {
#pragma unused(workflowItem)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( [modifyDictArray count] != 0 ) {
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
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
                    NSLog(@"CopyFailed!");
                    NSLog(@"Error: %@", error);
                    [self modifyFailed];
                }
            }];
        }];
    } else {
        NSLog(@"Modify Array is Empty!");
        [self modifyFailed];
    }
}

- (void)addUsersToNBI {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Adding user to NBI...");
    [_delegate updateProgressStatus:@"Adding user to NBI..." workflow:self];
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSArray *createUserVariables;
    
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
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"%@", outStr);
                                        
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
                                        DDLogError(@"[ERROR] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    if ( [createUserVariables count] == 6 ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
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
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self modifyFailed];
                }
            }];
        }];
    } else if ( [createUserVariables count] != 0 ) {
        NSLog(@"Need to be exactly 5 variables to pass to script!");
    } else {
        NSLog(@"Didn't get any variables!?");
    }
    
}

- (NSArray *)generateUserVariablesForCreateUsers:(NSDictionary *)userSettings {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
}

- (void)modifyComplete {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self finalizeWorkflow];
}

- (void)modifyFailed {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
}

- (void)copyComplete {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self modifyFilesInBaseSystem];
}

- (void)copyFailed {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
}

#pragma mark -
#pragma mark UI Updates
#pragma mark -

- (void)updateProgressBar:(double)value {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    double precentage = (((40 * value)/100) + 80);
    [_delegate updateProgressBar:precentage];
} // updateProgressBar

@end
