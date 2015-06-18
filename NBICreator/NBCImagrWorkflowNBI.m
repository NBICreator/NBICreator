//
//  NBCImagrWorkflowNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowNBI.h"
#import "NBCConstants.h"

#import "NBCController.h"
#import "NBCWorkflowNBIController.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCDiskImageController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

@implementation NBCImagrWorkflowNBI

#pragma mark -
#pragma mark Run Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    _nbiVolumeName = [[workflowItem nbiName] stringByDeletingPathExtension];
    _progressView = [workflowItem progressView];
    _temporaryNBIPath = [[workflowItem temporaryNBIURL] path];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemSystemImageUtility];
        [self runWorkflowSystemImageUtility:workflowItem];
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemNBICreator];
        [self runWorkflowNBICreator:workflowItem];
    }
}

- (void)runWorkflowNBICreator:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Get used space for BaseSystem.dmg for copy progress bar
    // -------------------------------------------------------------
    NSURL *baseSystemURL = [[workflowItem source] baseSystemURL];
    NSString *baseSystemPath = [baseSystemURL path];
    if ( [baseSystemPath length] != 0 ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:baseSystemPath error:&error];
        if ( [volumeAttributes count] != 0 ) {
            double fileSize = [volumeAttributes[NSFileSize] doubleValue];
            [self setTemporaryNBIBaseSystemSize:fileSize];
        } else {
            NSLog(@"Error getting volumeAttributes from InstallESD Volume");
            NSLog(@"Error: %@", error);
        }
    } else {
        NSLog(@"Error getting installESDVolumePath from source");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create NBI Folder
    // -------------------------------------------------------------
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    NSLog(@"temporaryNBIURL=%@", temporaryNBIURL);
    NSURL *temporaryx86FolderURL = [temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64"];
    NSLog(@"temporaryx86FolderURL=%@", temporaryx86FolderURL);
    if ( temporaryx86FolderURL ) {
        if ( ! [fm createDirectoryAtURL:temporaryx86FolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Error creating temporary NBI Folder");
            NSLog(@"Error: %@", error);
        }
    }
    
    // -------------------------------------------------------------
    //  Copy BaseSystem.dmg to temporary NBI Folder
    // -------------------------------------------------------------
    [self setCopyComplete:NO];
    NSURL *baseSystemTargetURL = [temporaryNBIURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
    NSLog(@"baseSystemTargetURL=%@", baseSystemTargetURL);
    [self setTemporaryNBIBaseSystemPath:[baseSystemTargetURL path]];
    [[workflowItem target] setBaseSystemURL:baseSystemTargetURL];
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        NSError *blockError;
        if ( ! [fm copyItemAtURL:baseSystemURL toURL:baseSystemTargetURL error:&blockError] ) {
            [self setCopyComplete:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"Error copying BaseSystem.dmg to temporaryFolder");
                NSLog(@"Error: %@", blockError);
            });
        } else {
            [self setCopyComplete:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createNBIFilesNBICreator:workflowItem baseSystemTemporaryURL:baseSystemTargetURL];
            });
        }
    });
    
    // ---------------------------------------------------
    //  Loop to check image size and update progress bar
    // ---------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgressBaseSystem:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)createNBIFilesNBICreator:(NBCWorkflowItem *)workflowItem baseSystemTemporaryURL:(NSURL *)baseSystemTemporaryURL {
    NSLog(@"createNBIFilesNBICreator");
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NBCImagrWorkflowModifyNBI *modifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    
    BOOL verified = [modifyNBI resizeAndMountBaseSystemWithShadow:baseSystemTemporaryURL target:[workflowItem target]];
    if ( verified ) {
        NSURL *baseSystemTemporaryVolumeURL = [[workflowItem target] baseSystemVolumeURL];
        NSLog(@"baseSystemTemporaryVolumeURL=%@", baseSystemTemporaryVolumeURL);
        if ( baseSystemTemporaryVolumeURL ) {
            NSURL *booterSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/boot.efi"];
            NSLog(@"booterSourceURL=%@", booterSourceURL);
            NSURL *booterTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/booter"];
            NSLog(@"booterTargetURL=%@", booterTargetURL);
            if ( ! [fm copyItemAtURL:booterSourceURL toURL:booterTargetURL error:&error] ) {
                NSLog(@"Error while copying booter file!");
                NSLog(@"Error: %@", error);
            } else {
                NSDictionary *booterAttributes = @{ NSFileImmutable : @NO };
                if ( ! [fm setAttributes:booterAttributes ofItemAtPath:[booterTargetURL path] error:&error] ) {
                    NSLog(@"Warning! Unable to unlock booter file");
                    NSLog(@"Error: %@", error);
                }
            }
            
            NSURL *platformSupportSourceURL;
            NSLog(@"[[workflowItem source] systemOSVersion]=%@", [[workflowItem source] sourceVersion]);
            if ( [[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
            } else {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/PlatformSupport.plist"];
            }
            NSLog(@"platformSupportSourceURL=%@", platformSupportSourceURL);
            NSURL *platformSupportTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
            NSLog(@"platformSupportTargetURL=%@", platformSupportTargetURL);
            if ( ! [fm copyItemAtURL:platformSupportSourceURL toURL:platformSupportTargetURL error:&error] ) {
                NSLog(@"Error while copying platform support plist");
                NSLog(@"Error: %@", error);
            }
            
            NSURL *kernelCacheTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
            NSURL *kernelCacheSourceURL;
            kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/PrelinkedKernels/prelinkedkernel"];
            if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"];
                if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                    [self generateKernelCacheForNBI:workflowItem];
                } else {
                    if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                        [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                    } else {
                        NSLog(@"Error while copying kernel cache file");
                        NSLog(@"Error: %@", error);
                    }
                }
            } else {
                if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                    [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                } else {
                    NSLog(@"Error while copying kernel cache file");
                    NSLog(@"Error: %@", error);
                }
            }
            
            NSLog(@"kernelCacheSourceURL=%@", kernelCacheSourceURL);
            NSLog(@"kernelCacheTargetURL=%@", kernelCacheTargetURL);
            
            
            
        } else {
            NSLog(@"Could not mount temporary BaseSystem.dmg");
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        NSLog(@"Error while resizing Base System!");
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
}

- (void)generateKernelCacheForNBI:(NBCWorkflowItem *)workflowItem {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSMutableArray *generateKernelCacheVariables = [[NSMutableArray alloc] init];
    
    NSString *generateKernelCacheScriptPath = [[NSBundle mainBundle] pathForResource:@"generateKernelCache" ofType:@"bash"];
    NSLog(@"generateKernelCacheScriptPath=%@", generateKernelCacheScriptPath);
    if ( [generateKernelCacheScriptPath length] != 0 ) {
        [generateKernelCacheVariables addObject:generateKernelCacheScriptPath];
        NSLog(@"generateKernelCacheVariables=%@", generateKernelCacheVariables);
    } else {
        NSLog(@"Could not get path to script generateKernelCache.bash");
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
    
    NSURL *sourceVolumeURL;
    NBCDisk *sourceBaseSystemDisk = [[workflowItem source] baseSystemDisk];
    if ( [sourceBaseSystemDisk isMounted] ) {
        sourceVolumeURL = [[workflowItem source] baseSystemVolumeURL];
    } else {
        NSError *error;
        NSURL *sourceBaseSystemURL = [[workflowItem source] baseSystemURL];
        NSDictionary *systemDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-owners", @"on",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&systemDiskImageDict
                                                                  dmgPath:sourceBaseSystemURL
                                                                  options:hdiutilOptions
                                                                    error:&error] ) {
            if ( systemDiskImageDict ) {
                [[workflowItem source] setSystemDiskImageDict:systemDiskImageDict];
                sourceVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:systemDiskImageDict];
                sourceBaseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:sourceBaseSystemURL
                                                                                  imageType:@"BaseSystem"];
                if ( sourceBaseSystemDisk ) {
                    [[workflowItem source] setSystemDisk:sourceBaseSystemDisk];
                    [[workflowItem source] setSystemVolumeBSDIdentifier:[sourceBaseSystemDisk BSDName]];
                    [sourceBaseSystemDisk setIsMountedByNBICreator:YES];
                } else {
                    NSLog(@"Could not get Disk!");
                }
            } else {
                NSLog(@"Didn't get a dict from hdiutil");
            }
        } else {
            NSLog(@"Attach failed!");
            NSLog(@"Error: %@", error);
        }
    }
    
    if ( sourceVolumeURL ) {
        [generateKernelCacheVariables addObject:[sourceVolumeURL path]];
    }
    
    [generateKernelCacheVariables addObject:_temporaryNBIPath]; //NBI
    
    
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
    
    
    NSLog(@"generateKernelCacheVariables=%@", generateKernelCacheVariables);
    
    if ( [generateKernelCacheVariables count] == 4 ) {
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
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }];
            
        }] runTaskWithCommandAtPath:commandURL arguments:generateKernelCacheVariables currentDirectory:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                NSLog(@"terminationStatus=%d", terminationStatus);
                if ( terminationStatus == 0 ) {
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                } else {
                    NSLog(@"CopyFailed!");
                    NSLog(@"Error: %@", error);
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                }
            }];
        }];
    } else if ( [generateKernelCacheVariables count] != 0 ) {
        NSLog(@"Need to be exactly 4 variables to pass to script!");
    } else {
        NSLog(@"Didn't get any variables!?");
    }
    
}

- (void)runWorkflowSystemImageUtility:(NBCWorkflowItem *)workflowItem {
    NSError *err;
    __unsafe_unretained typeof(self) weakSelf = self;
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
    
    // -------------------------------------------------------------
    //  Get used space on InstallESD source volume for progress bar
    // -------------------------------------------------------------
    NSString *installESDVolumePath = [[[workflowItem source] installESDVolumeURL] path];
    if ( [installESDVolumePath length] != 0 ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:installESDVolumePath error:&err];
        if ( [volumeAttributes count] != 0 ) {
            double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
            double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
            [self setNetInstallVolumeSize:( maxSize - freeSize )];
        } else {
            NSLog(@"Error getting volumeAttributes from InstallESD Volume");
            NSLog(@"Error: %@", err);
        }
    } else {
        NSLog(@"Error getting installESDVolumePath from source");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create arguments array for createNetInstall.sh
    // -------------------------------------------------------------
    NSArray *createNetInstallArguments = [nbiController generateScriptArgumentsForCreateNetInstall:workflowItem];
    if ( [createNetInstallArguments count] != 0 ) {
        [workflowItem setScriptArguments:createNetInstallArguments];
    } else {
        NSLog(@"Error, no argumets for createNetInstall");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create environment variables for createNetInstall.sh
    // -------------------------------------------------------------
    NSDictionary *environmentVariables = [nbiController generateEnvironmentVariablesForCreateNetInstall:workflowItem];
    if ( [environmentVariables count] != 0 ) {
        [workflowItem setScriptEnvironmentVariables:environmentVariables];
    } else {
        // ------------------------------------------------------------------
        //  Using environment variables file instead of passing them to task
        // ------------------------------------------------------------------
        //NSLog(@"Warning, no environment variables dict for createNetInstall");
    }
    
    // -------------------------------------------------------------
    //  Copy required files to NBI folder
    // -------------------------------------------------------------
    NSURL *createCommonURL = [[workflowItem applicationSource] createCommonURL];
    if ( createCommonURL != nil ) {
        if ( ! [self prepareDestinationFolder:[workflowItem temporaryNBIURL] createCommonURL:createCommonURL workflowItem:workflowItem error:&err] ) {
            NSLog(@"Errror preparing destination folder");
            NSLog(@"Error: %@", err);
            return;
        }
    } else {
        NSLog(@"Error getting create Common URL from workflow item");
        return;
    }
    
    // ------------------------------------------
    //  Setup command to run createNetInstall.sh
    // ------------------------------------------
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/sh"];
    
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
                                        [weakSelf updateNetInstallWorkflowStatus:outStr stdErr:nil];
                                        
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
                                        [weakSelf updateNetInstallWorkflowStatus:nil stdErr:errStr];
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------
    //  Connect to helper and run createNetInstall.sh
    // -----------------------------------------------
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
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:createNetInstallArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            if ( terminationStatus == 0 ) {
                // ------------------------------------------------------------------
                //  If task exited successfully, post workflow complete notification
                // ------------------------------------------------------------------
                [self removeTemporaryItems:workflowItem];
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
            } else {
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }
        }];
    }];
} // runWorkflow

#pragma mark -
#pragma mark Pre-/Post Workflow Methods
#pragma mark -

- (BOOL)prepareDestinationFolder:(NSURL *)destinationFolderURL createCommonURL:(NSURL *)createCommonURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    BOOL retval = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // ------------------------------------------------------------------
    //  Create array for temporary items to be deleted at end of workflow
    // ------------------------------------------------------------------
    NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
    if ( ! temporaryItemsNBI ) {
        temporaryItemsNBI = [[NSMutableArray alloc] init];
    }
    
    // ------------------------------------------------------------------
    //  Save URL for NBI NetInstall.dmg
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [destinationFolderURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    // -------------------------------------------------------------------------------------
    //  Copy createCommon.sh to NBI folder for createNetInstall.sh to use when building NBI
    // -------------------------------------------------------------------------------------
    NSURL *createCommonDestinationURL = [destinationFolderURL URLByAppendingPathComponent:@"createCommon.sh"];
    if ( [fileManager isReadableFileAtPath:[createCommonURL path]] ) {
        if ( [fileManager copyItemAtURL:createCommonURL toURL:createCommonDestinationURL error:error] ) {
            [temporaryItemsNBI addObject:createCommonDestinationURL];
            
            retval = YES;
        } else {
            NSLog(@"Error while copying createCommon.sh");
            NSLog(@"Error: %@", *error);
        }
    } else {
        NSLog(@"Could not read createCommon.sh to copy to tmp folder");
    }
    
    [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    
    return retval;
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)removeTemporaryItems:(NBCWorkflowItem *)workflowItem {
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSError *error;
    NSArray *temporaryItemsNBI = [workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ( ! [fileManager removeItemAtURL:temporaryItemURL error:&error] ) {
            NSLog(@"Failed Deleting file: %@", [temporaryItemURL path] );
            NSLog(@"Error: %@", error);
        }
    }
} // removeTemporaryItems

#pragma mark -
#pragma mark Progress Updates
#pragma mark -

- (void)updateNetInstallWorkflowStatus:(NSString *)outStr stdErr:(NSString *)stdErr {
    // -------------------------------------------------------------
    //  Check if string begins with chosen prefix or with PERCENT:
    // -------------------------------------------------------------
    if ( [outStr hasPrefix:NBCWorkflowNetInstallLogPrefix] ) {
        // ----------------------------------------------------------------------------------------------
        //  Check for build steps in output, then try to update UI with a meaningful message or progress
        // ----------------------------------------------------------------------------------------------
        NSString *buildStep = [outStr componentsSeparatedByString:@"_"][2];
        
        // -------------------------------------------------------------
        //  "creatingImage", update progress bar from PERCENT: output
        // -------------------------------------------------------------
        if ( [buildStep isEqualToString:@"creatingImage"] ) {
            [[_progressView textFieldStatusInfo] setStringValue:@"1/5 Creating disk image"];
            
            // --------------------------------------------------------------------------------------
            //  "copyingSource", update progress bar from looping current file size of target volume
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"copyingSource"] ) {
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc addObserver:self selector:@selector(checkDiskVolumeName:) name:DADiskDidAppearNotification object:nil];
            [nc addObserver:self selector:@selector(checkDiskVolumeName:) name:DADiskDidChangeNotification object:nil];
            
            // --------------------------------------------------------------------------------------
            //  "buildingBooter", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"buildingBooter"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setCopyComplete:YES];
                [[self->_progressView textFieldStatusInfo] setStringValue:@"3/5 Preparing the kernel and boot loader for the boot image"];
                [[self->_progressView progressIndicator] setDoubleValue:85];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self->_progressView textFieldStatusInfo] setStringValue:@"4/5 Performing post install cleanup"];
                [[self->_progressView progressIndicator] setDoubleValue:90];
            });
        }
        
        // ---------------------------------------------------------
        //  Read percent value from output and pass to progress bar
        // ---------------------------------------------------------
    } else if ( [outStr containsString:@"PERCENT:"] ) {
        NSString *progressPercentString = [outStr componentsSeparatedByString:@":"][1] ;
        double progressPercent = [progressPercentString doubleValue];
        [self updateProgressBar:progressPercent];
    }
    
    if ( [stdErr length] != 0 ) {
        NSLog(@"stdErr: %@", stdErr);
    }
} // updateNetInstallWorkflowStatus:stdErr

- (void)checkDiskVolumeName:(id)sender {
    // --------------------------------------------------------------------------------
    //  Verify that the volumeName is the expected NBI volume name.
    //  Verify that the disk that's mounting has mounted completely (have a volumeURL)
    // --------------------------------------------------------------------------------
    NBCDisk *disk = [sender object];
    if ( [[disk volumeName] isEqualToString:_nbiVolumeName] ) {
        NSURL *diskVolumeURL = [disk volumeURL];
        if ( diskVolumeURL != nil ) {
            [self setCopyComplete:NO];
            [self setDiskVolumePath:[[disk volumeURL] path]];
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc removeObserver:self name:DADiskDidAppearNotification object:nil];
            [nc removeObserver:self name:DADiskDidChangeNotification object:nil];
            
            [self updateProgressBarCopyNetInstall];
        }
    }
} // checkDiskVolumeName

- (void)updateProgressBarCopyNetInstall {
    // ---------------------------------------------------
    //  Loop to check volume size and update progress bar
    // ---------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgressNetInstall:)
                                   userInfo:nil
                                    repeats:YES];
} // updateProgressBarCopy

-(void)checkCopyProgressNetInstall:(NSTimer *)timer {
    // -------------------------------------------------
    //  Get attributes for volume URL mounted by script
    // -------------------------------------------------
    NSError *error;
    NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:_diskVolumePath error:&error];
    if ( [volumeAttributes count] != 0 ) {
        // -------------------------------------------------
        //  Calculate used size and update progress bar
        // -------------------------------------------------
        double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
        double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
        double volumeCurrentSize = ( maxSize - freeSize );
        
        if ( _netInstallVolumeSize <= volumeCurrentSize || _copyComplete == YES ) {
            [timer invalidate];
            timer = nil;
        } else {
            double precentage = (((40 * volumeCurrentSize)/_netInstallVolumeSize) + 40);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self->_progressView textFieldStatusInfo] setStringValue:@"2/5 Copying source"];
                [[self->_progressView progressIndicator] setDoubleValue:precentage];
                [[self->_progressView progressIndicator] setNeedsDisplay:YES];
            });
        }
    } else {
        [timer invalidate];
        timer = nil;
        
        NSLog(@"Could not get file attributes for volume: %@", _diskVolumePath);
        NSLog(@"Error: %@", error);
    }
} // checkCopyProgressNetInstall

-(void)checkCopyProgressBaseSystem:(NSTimer *)timer {
    // -------------------------------------------------
    //  Get attributes for target BaseSystem.dmg
    // -------------------------------------------------
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_temporaryNBIBaseSystemPath error:&error];
    if ( [fileAttributes count] != 0 ) {
        double fileSize = [fileAttributes[NSFileSize] doubleValue];
        
        if ( _temporaryNBIBaseSystemSize <= fileSize || _copyComplete == YES ) {
            [timer invalidate];
            timer = nil;
        } else {
            double precentage = (((40 * fileSize)/_temporaryNBIBaseSystemSize) + 40);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self->_progressView textFieldStatusInfo] setStringValue:@"2/5 Copying source"];
                [[self->_progressView progressIndicator] setDoubleValue:precentage];
                [[self->_progressView progressIndicator] setNeedsDisplay:YES];
            });
        }
    } else {
        [timer invalidate];
        timer = nil;
        
        NSLog(@"Could not get file attributes for volume: %@", _diskVolumePath);
        NSLog(@"Error: %@", error);
    }
} // checkCopyProgress

- (void)updateProgressBar:(double)value {
    // ---------------------------------------------------
    //  Set progress bar to not be indeterminate if it is
    // ---------------------------------------------------
    if ( [[_progressView progressIndicator] isIndeterminate] ) {
        [[_progressView progressIndicator] setDoubleValue:0.0];
        [[_progressView progressIndicator] setIndeterminate:NO];
    } else if ( value <= 0 ) {
        return;
    }
    
    double precentage = (40 * value)/[@100 doubleValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self->_progressView progressIndicator] setDoubleValue:precentage];
        [[self->_progressView progressIndicator] setNeedsDisplay:YES];
    });
} // updateProgressBar

@end
