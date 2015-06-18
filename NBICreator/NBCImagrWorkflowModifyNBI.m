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
#import "NBCWorkflowProgressViewController.h"

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCTargetController.h"

#import "NBCDisk.h"
#import "NBCDiskImageController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCMessageDelegate.h"

@implementation NBCImagrWorkflowModifyNBI

#pragma mark -
#pragma mark Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    _workflowItem = workflowItem;
    _source = [workflowItem source];
    _target = [workflowItem target];
    _targetController = [[NBCTargetController alloc] init];
    _progressView = [workflowItem progressView];
    _modifyBaseSystemComplete = NO;
    _modifyNetInstallComplete = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self->_progressView textFieldStatusInfo] setStringValue:@"5/5 Adding resources to NBI"];
        [[self->_progressView progressIndicator] setDoubleValue:91];
    });
    
    
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    if ( temporaryNBIURL ) {
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
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // ------------------------------------------------------
    //  Convert and rename BaseSystem image from shadow file
    // ------------------------------------------------------
    if ( ! [_targetController convertBaseSystemFromShadow:_target error:&error] ) {
        NSLog(@"Converting BaseSystem from shadow failed!");
        NSLog(@"Error: %@", error);
        
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    
    NSURL *baseSystemDiskImageURL = [_target baseSystemURL];
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
    NSLog(@"modifyNetInstall");
    BOOL verified = YES;
    NSError *error;
    
    NSURL *nbiNetInstallURL = [_target nbiNetInstallURL];
    if ( nbiNetInstallURL ) {
        // ------------------------------------------------------------------
        //  Attach NetInstall disk image using a shadow image to make it r/w
        // ------------------------------------------------------------------
        if ( [_targetController attachNetInstallDiskImageWithShadowFile:nbiNetInstallURL target:_target error:&error] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self->_progressView progressIndicator] setDoubleValue:92];
            });
            
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
    NSLog(@"replacePackagesFolderInNetInstall");
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[self->_progressView progressIndicator] setDoubleValue:94];
                });
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
    NSLog(@"copyFilesToNetInstall");
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
    NSLog(@"modifyBaseSystem");
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
        if ( [NBCDiskImageController resizeDiskImageAtURL:baseSystemURL shadowImagePath:shadowFilePath] ) {
            NSLog(@"Resize BaseSystem Completed");
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

- (BOOL)modifyBaseSystem {
    NSLog(@"modifyBaseSystem");
    BOOL verified = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self->_progressView progressIndicator] setDoubleValue:95];
    });
    
    // -------------------------------------------------------------------------
    //  Install packages to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    if ( ! [self installPackagesToBaseSystem] ) {
        NSLog(@"Installing packages to BaseSystem failed!");
        
        verified = NO;
    }
    
    // -------------------------------------------------------------------------
    //  Copy items to Base System using info from resourcesBaseSystemDict
    // -------------------------------------------------------------------------
    NSLog(@"Copying Files to BaseSystem!");
    if ( verified ) {
        [self copyFilesToBaseSystem];
    }
    
    
    return verified;
} // modifyBaseSystem

- (BOOL)installPackagesToBaseSystem {
    NSLog(@"installPackagesToBaseSystem");
    BOOL verified = YES;
    NSError *error;
    
    NBCInstallerPackageController *installer = [[NBCInstallerPackageController alloc] initWithDelegate:self];
    
    NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
    if ( nbiBaseSystemVolumeURL ) {
        // --------------------------------------------------------------------
        //  Loop through and install all packages from resourcesBaseSystemDict
        // --------------------------------------------------------------------
        NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
        if ( [resourcesBaseSystemDict count] != 0 ) {
            NSDictionary *installerDict = resourcesBaseSystemDict[NBCWorkflowInstall];
            if ( [installerDict count] != 0 ) {
                NSArray *allPackages = [installerDict allKeys];
                for ( NSString *packageName in allPackages ) {
                    NSDictionary *packageDict = installerDict[packageName];
                    if ( [packageDict count] != 0 ) {
                        NSString *packagePath = packageDict[NBCWorkflowInstallerSourceURL];
                        NSURL *packageURL;
                        if ( [packagePath length] != 0 ) {
                            packageURL = [NSURL fileURLWithPath:packagePath];
                            NSDictionary *packageChoiceChangeXML = packageDict[NBCWorkflowInstallerChoiceChangeXML];
                            
                            if ( ! [installer installPackageOnTargetVolume:nbiBaseSystemVolumeURL packageURL:packageURL choiceChangesXML:packageChoiceChangeXML error:&error] ) {
                                NSLog(@"Installing package %@ failed!", packageName );
                                NSLog(@"Error: %@", error);
                                
                                verified = NO;
                            }
                        } else {
                            NSLog(@"Package path for packate %@ is empty!", packageName );
                            
                            verified = NO;
                        }
                    } else {
                        NSLog(@"Package dict for package: %@ is empty!", packageName );
                        
                        verified = NO;
                    }
                }
            }
        }
    } else {
        NSLog(@"nbiBaseSystemVolumeURL is empty!");
        
        verified = NO;
    }
    return verified;
} // installPackagesToBaseSystem

- (void)updateProgress:(NSString *)message {
    NSLog(@"message=%@", message);
}

- (void)copyFilesToBaseSystem {
    NSLog(@"copyFilesToBaseSystem");
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesBaseSystemDict = [_target resourcesBaseSystemDict];
    NSLog(@"resourcesBaseSystemDict=%@", resourcesBaseSystemDict);
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    NSLog(@"volumeURL=%@", volumeURL);
    
    //NSError *error;
    //[_targetController copyResourcesToVolume:volumeURL resourcesDict:resourcesBaseSystemDict target:_target error:&error];
    
    
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
            
            NSLog(@"terminationStatus=%d", terminationStatus);
            if ( terminationStatus == 0 )
            {
                NSLog(@"CopyComplete!");
                [self copyComplete];
            } else {
                NSLog(@"CopyFailed!");
                NSLog(@"Error: %@", error);
                [self copyFailed];
            }
        }];
    }];
} // copyFilesToBaseSystem

- (void)createVNCPasswordHash:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL shouldAddUsers:(BOOL)shouldAddUsers {
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
        
        [self modifyBaseSystemFiles:modifyDictArray workflowItem:workflowItem volumeURL:volumeURL shouldAddUsers:shouldAddUsers];
    } else {
        NSLog(@"Perl command failed!");
        [self modifyFailed];
    }
}



- (void)modifyFilesInBaseSystem {
    NSLog(@"modifyFilesInBaseSystem");
    BOOL shouldModify = NO;
    BOOL shouldAddUsers = NO;
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *volumeURL = [_target baseSystemVolumeURL];
    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];
    
    [_targetController modifyNBINTP:modifyDictArray workflowItem:_workflowItem];
    
    if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] ) {
        NSLog(@"DisableWifiIsYes!");
        [_targetController modifyNBIRemoveWiFi:modifyDictArray workflowItem:_workflowItem];
        shouldModify = YES;
    }
    
    if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [_targetController modifySettingsAddFolders:modifyDictArray workflowItem:_workflowItem];
        [_targetController modifySettingsForVNC:modifyDictArray workflowItem:_workflowItem];
        shouldModify = YES;
        shouldAddUsers = YES;
        
        [self createVNCPasswordHash:modifyDictArray workflowItem:_workflowItem volumeURL:volumeURL shouldAddUsers:shouldAddUsers];
        
    } else {
        [self modifyComplete];
    }
}

- (void)modifyBaseSystemFiles:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem volumeURL:(NSURL *)volumeURL shouldAddUsers:(BOOL)shouldAddUsers {
    #pragma unused(workflowItem)
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
                
                NSLog(@"terminationStatus=%d", terminationStatus);
                if ( terminationStatus == 0 ) {
                    NSLog(@"CopyComplete!");
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
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSArray *createUserVariables;
    
    NSLog(@"Checking if password is set!");
    NSString *password = userSettings[NBCSettingsARDPasswordKey];
    NSLog(@"password=%@", password);
    if ( [password length] != 0 ) {
        NSLog(@"Yes!");
        createUserVariables = [self generateUserVariablesForCreateUsers:userSettings];
    } else {
        NSLog(@"No!");
    }
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
    NSLog(@"commandURL=%@", commandURL);
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
                    NSLog(@"outStr=%@", outStr);
                    
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
                    NSLog(@"errStr=%@", errStr);
                    
                    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                }];
    
    
    NSLog(@"createUserVariables=%@", createUserVariables);
    
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
                 
                 NSLog(@"terminationStatus=%d", terminationStatus);
                 if ( terminationStatus == 0 ) {
                     [nc removeObserver:stdOutObserver];
                     [nc removeObserver:stdErrObserver];
                     [self modifyComplete];
                 } else {
                     NSLog(@"CopyFailed!");
                     NSLog(@"Error: %@", error);
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
    NSMutableArray *userVariables = [[NSMutableArray alloc] init];
    
    NSString *createUserScriptPath = [[NSBundle mainBundle] pathForResource:@"createUser" ofType:@"bash"];
    NSLog(@"createUserScriptPath=%@", createUserScriptPath);
    if ( [createUserScriptPath length] != 0 ) {
        [userVariables addObject:createUserScriptPath];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get path to script createUser.bash");
        return nil;
    }
    
    // Variable ${1} - nbiVolumePath
    NSString *nbiVolumePath = [[[_workflowItem target] baseSystemVolumeURL] path];
    NSLog(@"nbiVolumePath=%@", nbiVolumePath);
    if ( [nbiVolumePath length] != 0 ) {
        [userVariables addObject:nbiVolumePath];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get nbi volume path");
        return nil;
    }
    
    // Variable ${2} - userShortName
    NSString *userShortName = userSettings[NBCSettingsARDLoginKey];
    NSLog(@"userShortName=%@", userShortName);
    if ( [userShortName length] != 0 ) {
        [userVariables addObject:userShortName];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get user short name");
        return nil;
    }
    
    // Variable ${3} - userPassword
    NSString *userPassword = userSettings[NBCSettingsARDPasswordKey];
    NSLog(@"userPassword=%@", userPassword);
    if ( [ userPassword length] != 0 ) {
        [userVariables addObject:userPassword];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get user password");
        return nil;
    }
    
    // Variable ${4} - userUID
    NSString *userUID = @"599";
    NSLog(@"userUID=%@", userUID);
    if ( [userUID length] != 0 ) { // This is here for future functionality
        [userVariables addObject:userUID];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get user UID");
        return nil;
    }
    
    // Variable ${5} - userGroups
    NSString *userGroups = @"admin";
    NSLog(@"userGroups=%@", userGroups);
    if ( [userGroups length] != 0 ) { // This is here for future functionality
        [userVariables addObject:userGroups];
        NSLog(@"userVariables=%@", userVariables);
    } else {
        NSLog(@"Could not get user groups");
        return nil;
    }
    
    NSLog(@"userVariables=%@", userVariables);
    
    return [userVariables copy];
}

- (void)modifyComplete {
    NSLog(@"Modify Complete!");
    [self finalizeWorkflow];
}

- (void)modifyFailed {
    NSLog(@"Modify Failed!");
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
}

- (void)copyComplete {
    NSLog(@"Copy Complete");
    [self modifyFilesInBaseSystem];
}

- (void)copyFailed {
    NSLog(@"Copy Failed!");
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
}

#pragma mark -
#pragma mark UI Updates
#pragma mark -

- (void)updateProgressBar:(double)value {
    double precentage = (((40 * value)/100) + 80);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self->_progressView progressIndicator] setDoubleValue: precentage];
        [[self->_progressView progressIndicator] setNeedsDisplay:YES];
    });
} // updateProgressBar

@end
