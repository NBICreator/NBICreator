//
//  NBCImagrWorkflowNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowNBI.h"
#import "NBCConstants.h"
#import "NBCWorkflowItem.h"

#import "NBCController.h"
#import "NBCWorkflowNBIController.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCDiskImageController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowNBI

#pragma mark -
#pragma mark Run Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Starting workflow create Imagr NBI...");
    _nbiVolumeName = [[workflowItem nbiName] stringByDeletingPathExtension];
    //_progressView = [workflowItem progressView];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Using NBI Creator to create base NBI");
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
            DDLogError(@"[ERROR] Error getting volumeAttributes from InstallESD Volume");
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        DDLogError(@"[ERROR] Path for source BaseSystem.dmg is empty!");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Creating NBI folder...");
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    NSURL *temporaryx86FolderURL = [temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64"];
    if ( temporaryx86FolderURL ) {
        if ( ! [fm createDirectoryAtURL:temporaryx86FolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            DDLogError(@"Could not create NBI folder!");
            DDLogError(@"Error: %@", error);
        }
    }
    DDLogDebug(@"NBI folder path: %@", [temporaryNBIURL path]);
    
    // -------------------------------------------------------------
    //  Copy BaseSystem.dmg to temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Copying BaseSystem.dmg from source to NBI folder...");
    [self setCopyComplete:NO];
    NSURL *baseSystemTargetURL = [temporaryNBIURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
    [self setTemporaryNBIBaseSystemPath:[baseSystemTargetURL path]];
    [[workflowItem target] setBaseSystemURL:baseSystemTargetURL];
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        NSError *blockError;
        if ( ! [fm copyItemAtURL:baseSystemURL toURL:baseSystemTargetURL error:&blockError] ) {
            [self setCopyComplete:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogError(@"Could not copy BaseSystem.dmg to NBI folder!");
                DDLogError(@"Error: %@", blockError);
            });
        } else {
            [self setCopyComplete:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createNBIFilesNBICreator:workflowItem baseSystemTemporaryURL:baseSystemTargetURL];
            });
        }
    });
    
    // --------------------------------------------------------------------------
    //  Loop to check size of BaseSystem.dmg during copy and update progress bar
    // --------------------------------------------------------------------------
    //[[self->_progressView progressIndicator] setDoubleValue:0];
    //[[self->_progressView progressIndicator] setIndeterminate:NO];
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgressBaseSystem:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)createNBIFilesNBICreator:(NBCWorkflowItem *)workflowItem baseSystemTemporaryURL:(NSURL *)baseSystemTemporaryURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Copying NBI specific files...");
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFileManager *fm = [NSFileManager defaultManager];
    NBCImagrWorkflowModifyNBI *modifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    
    BOOL verified = [modifyNBI resizeAndMountBaseSystemWithShadow:baseSystemTemporaryURL target:[workflowItem target]];
    if ( verified ) {
        NSURL *baseSystemTemporaryVolumeURL = [[workflowItem target] baseSystemVolumeURL];
        if ( baseSystemTemporaryVolumeURL ) {
            
            // --------------------------------------------------------------------------
            //  Copy booter
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying booter file...");
            [_delegate updateProgressStatus:@"Copying booter file..." workflow:self];
            NSURL *booterTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/booter"];
            DDLogDebug(@"booterTargetURL=%@", booterTargetURL);
            NSURL *booterSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/boot.efi"];
            DDLogDebug(@"booterSourceURL=%@", booterSourceURL);
            
            if ( ! [fm copyItemAtURL:booterSourceURL toURL:booterTargetURL error:&error] ) {
                DDLogError(@"[ERROR] Could not copy booter file!");
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            } else {
                NSDictionary *booterAttributes = @{ NSFileImmutable : @NO };
                if ( ! [fm setAttributes:booterAttributes ofItemAtPath:[booterTargetURL path] error:&error] ) {
                    DDLogWarn(@"[WARN] Unable to unlock booter file!");
                    DDLogWarn(@"[ERROR] %@", [error localizedDescription]);
                }
            }
            
            // --------------------------------------------------------------------------
            //  Copy PlatformSupport.plist
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying PlatformSupport.plist...");
            [_delegate updateProgressStatus:@"Copying PlatformSupport.plist..." workflow:self];
            NSURL *platformSupportSourceURL;
            NSURL *platformSupportTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
            DDLogDebug(@"platformSupportTargetURL=%@", platformSupportTargetURL);
            if ( [[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
            } else {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/PlatformSupport.plist"];
            }
            DDLogDebug(@"platformSupportSourceURL=%@", platformSupportSourceURL);
            if ( ! [fm copyItemAtURL:platformSupportSourceURL toURL:platformSupportTargetURL error:&error] ) {
                DDLogError(@"[ERROR] Error while copying platform support plist");
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
            
            // --------------------------------------------------------------------------
            //  Copy kernel cache
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying kernel cache files...");
            [_delegate updateProgressStatus:@"Copying kernel cache files..." workflow:self];
            NSURL *kernelCacheTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
            NSURL *kernelCacheSourceURL;
            kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/PrelinkedKernels/prelinkedkernel"];
            if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"];
                if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                    DDLogInfo(@"Found no precompiled kernel cache files!");
                    [self generateKernelCacheForNBI:workflowItem];
                } else {
                    DDLogDebug(@"kernelCacheSourceURL=%@", kernelCacheSourceURL);
                    if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                        [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                    } else {
                        DDLogError(@"[ERROR] Error while copying kernel cache file");
                        DDLogError(@"[ERROR] %@", error);
                    }
                }
            } else {
                DDLogDebug(@"kernelCacheSourceURL=%@", kernelCacheSourceURL);
                if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                    [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                } else {
                    DDLogError(@"[ERROR] Error while copying kernel cache file");
                    DDLogError(@"[ERROR] %@", error);
                }
            }
        } else {
            DDLogError(@"[ERROR] Failed to mount BaseSystem.dmg!");
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        DDLogError(@"Resizing BaseSystem.dmg failed!");
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
}

- (void)generateKernelCacheForNBI:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Generating kernel cache files...");
    [_delegate updateProgressStatus:@"Generating kernel cache files..." workflow:self];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSMutableArray *generateKernelCacheVariables = [[NSMutableArray alloc] init];
    
    // --------------------------------------------------------------------------
    //  Get path to generateKernelCache script
    // --------------------------------------------------------------------------
    NSString *generateKernelCacheScriptPath = [[NSBundle mainBundle] pathForResource:@"generateKernelCache" ofType:@"bash"];
    DDLogDebug(@"generateKernelCacheScriptPath=%@", generateKernelCacheScriptPath);
    if ( [generateKernelCacheScriptPath length] != 0 ) {
        [generateKernelCacheVariables addObject:generateKernelCacheScriptPath];
    } else {
        DDLogError(@"[ERROR] generateKernelCache script doesn't exist at path: %@", generateKernelCacheScriptPath);
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    
    // --------------------------------------------------------------------------
    //  Get path to BaseSystem.dmg volume
    // --------------------------------------------------------------------------
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
    
    
    DDLogDebug(@"generateKernelCacheVariables=%@", generateKernelCacheVariables);
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
    } else {
        DDLogError(@"[ERROR] Variable count to be passed to script is %lu, script requires exactly 4", (unsigned long)[generateKernelCacheVariables count]);
    }
}

- (void)runWorkflowSystemImageUtility:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Using System Image Utitlity to create base NBI");
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
            DDLogError(@"[ERROR] No attributes returned for InstallESD Volume");
            DDLogError(@"[ERROR] %@", err);
        }
    } else {
        DDLogError(@"[ERROR] Volume path for InstallESD.dmg is empty!");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create arguments array for createNetInstall.sh
    // -------------------------------------------------------------
    NSArray *createNetInstallArguments = [nbiController generateScriptArgumentsForCreateNetInstall:workflowItem];
    if ( [createNetInstallArguments count] != 0 ) {
        [workflowItem setScriptArguments:createNetInstallArguments];
    } else {
        DDLogError(@"[ERROR] No arguments returned for createNetInstall.sh!");
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
        DDLogError(@"[ERROR] Path for createCommon.sh is empty!");
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
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
            [_delegate updateProgressStatus:@"Creating disk image..." workflow:self];
            
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
                [self->_delegate updateProgressStatus:@"Preparing the kernel and boot loader for the boot image..." workflow:self];
                //[[self->_progressView textFieldStatusInfo] setStringValue:@"3/5 Preparing the kernel and boot loader for the boot image"];
                [self->_delegate updateProgressBar:85];
                //[[self->_progressView progressIndicator] setDoubleValue:85];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Performing post install cleanup..." workflow:self];
                //[[self->_progressView textFieldStatusInfo] setStringValue:@"4/5 Performing post install cleanup"];
                [self->_delegate updateProgressBar:90];
                //[[self->_progressView progressIndicator] setDoubleValue:90];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
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
                [self->_delegate updateProgressStatus:@"Copying source..." workflow:self];
                [self->_delegate updateProgressBar:precentage];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    // -------------------------------------------------
    //  Get attributes for target BaseSystem.dmg
    // -------------------------------------------------
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_temporaryNBIBaseSystemPath error:&error];
    if ( [fileAttributes count] != 0 ) {
        double fileSize = [fileAttributes[NSFileSize] doubleValue];
        NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)fileSize countStyle:NSByteCountFormatterCountStyleDecimal];
        NSString *fileSizeOriginal = [NSByteCountFormatter stringFromByteCount:(long long)_temporaryNBIBaseSystemSize countStyle:NSByteCountFormatterCountStyleDecimal];
        
        if ( _temporaryNBIBaseSystemSize <= fileSize || _copyComplete == YES ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
            });
            [timer invalidate];
            timer = nil;
        } else {
            double percentage = (((100 * fileSize)/_temporaryNBIBaseSystemSize));
            double percentageSlice = ( percentage * 0.9 );
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                [self->_delegate updateProgressBar:percentageSlice];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));

    if ( value <= 0 ) {
        return;
    }
    
    double precentage = (40 * value)/[@100 doubleValue];
    [self->_delegate updateProgressBar:precentage];
} // updateProgressBar

@end
