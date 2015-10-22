//
//  NBCImagrWorkflowNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowNBI.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowProgressViewController.h"
#import "NBCWorkflowNBIController.h"
#import "NBCImagrWorkflowModifyNBI.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    NSError *error = nil;
    
    // -------------------------------------------------------------
    //  Get temporary NBI build path
    // -------------------------------------------------------------
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    DDLogDebug(@"[DEBUG] Temporary NBI build path: %@", [temporaryNBIURL path]);
    if ( [temporaryNBIURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setTemporaryNBIURL:temporaryNBIURL];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Temporary folder doesn't exist"] }];
        return;
    }
    
    [self setNbiVolumeName:[[workflowItem nbiName] stringByDeletingPathExtension]];
    [self setMessageDelegate:[workflowItem progressView]];
    
    // -------------------------------------------------------------
    //  Start workflow depending on selected creation tool
    // -------------------------------------------------------------
    DDLogInfo(@"Starting workflow Imagr NBI...");
    
    NSString *nbiCreationTool = [workflowItem userSettings][NBCSettingsNBICreationToolKey];
    DDLogDebug(@"[DEBUG] NBI creation tool: %@", nbiCreationTool);
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemSystemImageUtility];
        [self runWorkflowSystemImageUtility:workflowItem];
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemNBICreator];
        [self runWorkflowNBICreator:workflowItem];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown NBI creation tool: %@", nbiCreationTool]] }];
        return;
    }
}

- (void)runWorkflowNBICreator:(NBCWorkflowItem *)workflowItem {
    
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // -------------------------------------------------------------
    //  Get BaseSystem disk image size for copy progress bar
    // -------------------------------------------------------------
    DDLogInfo(@"Getting size of BaseSystem disk image...");
    
    NSURL *baseSystemURL = [[workflowItem source] baseSystemURL];
    DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemURL path]);
    if ( [baseSystemURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[baseSystemURL path] error:&error];
        if ( [volumeAttributes count] != 0 ) {
            double fileSize = [volumeAttributes[NSFileSize] doubleValue];
            DDLogDebug(@"[DEBUG] BaseSystem disk image size: %f", fileSize);
            [self setTemporaryNBIBaseSystemSize:fileSize];
        } else {
            DDLogError(@"[ERROR] No attributes returned for BaseSystem disk image");
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"BaseSystem disk image doesn't exist"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Creating temporary NBI folder...");
    
    NSURL *temporaryNBIx86FolderURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64"];
    DDLogDebug(@"[DEBUG] Temporary NBI x86_64 folder path: %@", [temporaryNBIx86FolderURL path]);
    if ( ! [fm createDirectoryAtURL:temporaryNBIx86FolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Unable to create temporary NBI folders"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Copy BaseSystem disk image to temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Copying BaseSystem disk image from source...");
    
    NSURL *baseSystemTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
    DDLogDebug(@"[DEBUG] BaseSystem disk image target path: %@", [baseSystemTargetURL path]);
    
    [self setCopyComplete:NO];
    [self setTemporaryNBIBaseSystemPath:[baseSystemTargetURL path]];
    [[workflowItem target] setBaseSystemURL:baseSystemTargetURL];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *blockError = nil;
        if ( [fm copyItemAtURL:baseSystemURL toURL:baseSystemTargetURL error:&blockError] ) {
            DDLogDebug(@"[DEBUG] Copy complete!");
            [self setCopyComplete:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createNBIFilesNBICreator:workflowItem baseSystemTemporaryURL:baseSystemTargetURL];
            });
        } else {
            DDLogError(@"[ERROR] Copy failed!");
            [self setCopyComplete:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : blockError ?: [NBCError errorWithDescription:@"BaseSystem disk image copy failed"] }];
                return;
            });
        }
    });
    
    // --------------------------------------------------------------------------
    //  Loop to check size of BaseSystem.dmg during copy and update progress bar
    // --------------------------------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgressBaseSystem:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)createNBIFilesNBICreator:(NBCWorkflowItem *)workflowItem baseSystemTemporaryURL:(NSURL *)baseSystemTemporaryURL {
    
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NBCImagrWorkflowModifyNBI *modifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    
    // --------------------------------------------------------------------------
    //  Resize BaseSystem disk image and mount with shadow file
    // --------------------------------------------------------------------------
    DDLogInfo(@"Resize BaseSystem disk image and mount with shadow file...");
    
    if ( [modifyNBI resizeAndMountBaseSystemWithShadow:baseSystemTemporaryURL target:[workflowItem target]] ) {
        
        NSURL *baseSystemTemporaryVolumeURL = [[workflowItem target] baseSystemVolumeURL];
        DDLogDebug(@"[DEBUG] NBI BaseSystem volume path: %@", [baseSystemTemporaryVolumeURL path]);
        if ( [baseSystemTemporaryVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
            DDLogDebug(@"[DEBUG] NBI BaseSystem volume IS mounted");
            
            // --------------------------------------------------------------------------
            //  Copy booter
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying booter...");
            [_delegate updateProgressStatus:@"Copying booter file..." workflow:self];
            
            NSURL *booterSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/boot.efi"];
            NSURL *booterTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/booter"];
            
            if ( [fm copyItemAtURL:booterSourceURL toURL:booterTargetURL error:&error] ) {
                if ( ! [fm setAttributes:@{ NSFileImmutable : @NO } ofItemAtPath:[booterTargetURL path] error:&error] ) {
                    DDLogWarn(@"[WARN] Unable to unlock booter file!");
                    DDLogWarn(@"[WARN] %@", [error localizedDescription] );
                }
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"booter copy failed"] }];
                return;
            }
            
            // --------------------------------------------------------------------------
            //  Copy PlatformSupport.plist
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying PlatformSupport.plist...");
            [_delegate updateProgressStatus:@"Copying PlatformSupport.plist..." workflow:self];
            
            NSURL *platformSupportSourceURL;
            NSURL *platformSupportTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
            
            if ( [[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
            } else {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/PlatformSupport.plist"];
            }
            
            if ( ! [fm copyItemAtURL:platformSupportSourceURL toURL:platformSupportTargetURL error:&error] ) {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"PlatformSupport.plist copy failed"] }];
                return;
            }
            
            // --------------------------------------------------------------------------
            //  Copy kernelcache
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying kernelcache...");
            [_delegate updateProgressStatus:@"Copying kernel cache files..." workflow:self];
            
            NSURL *kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/PrelinkedKernels/prelinkedkernel"];
            NSURL *kernelCacheTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
            
            if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"];
                
                if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:&error] ) {
                    DDLogError(@"[ERROR] Found no prelinked kernelcache");
                    [nc postNotificationName:NBCNotificationWorkflowFailed
                                      object:self
                                    userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Found no prelinked kernelcache"] }];
                    return;
                }
            }
            
            if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"kenelcache copy failed"] }];
                return;
            }
        } else {
            DDLogDebug(@"[DEBUG] NBI BaseSystem volume is NOT mounted");
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NBI BaseSystem volume not mounted"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Resizing NBI BaseSystem failed"] }];
        return;
    }
} // createNBIFilesNBICreator

- (void)runWorkflowSystemImageUtility:(NBCWorkflowItem *)workflowItem {
    
    NSError *err = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    __unsafe_unretained typeof(self) weakSelf = self;
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
    
    // -------------------------------------------------------------
    //  Get InstallESD  disk image volume size for progress bar
    // -------------------------------------------------------------
    DDLogInfo(@"Getting size of InstallESD disk image volume...");
    
    NSURL *installESDVolumeURL = [[workflowItem source] installESDVolumeURL];
    DDLogDebug(@"[DEBUG] InstallESD disk image volume path: %@", [installESDVolumeURL path]);
    if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:&err] ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[installESDVolumeURL path] error:&err];
        if ( [volumeAttributes count] != 0 ) {
            double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
            DDLogDebug(@"[DEBUG] InstallESD disk image volume size: %f", maxSize);
            double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
            DDLogDebug(@"[DEBUG] InstallESD disk image volume free size: %f", freeSize);
            DDLogDebug(@"[DEBUG] InstallESD disk image volume used size: %f", ( maxSize - freeSize ));
            [self setNetInstallVolumeSize:( maxSize - freeSize )];
        } else {
            DDLogError(@"[ERROR] No attributes returned for InstallESD volume");
            DDLogError(@"[ERROR] %@", [err localizedDescription]);
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"InstallESD disk image is not mounted"] }];
        return;
    }
    
    // ------------------------------------------------------------------
    //  Set temporary NBI NetInstall.dmg path to target
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [_temporaryNBIURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    // -------------------------------------------------------------
    //  Generate script arguments array for createNetInstall.sh
    // -------------------------------------------------------------
    DDLogInfo(@"Generating script arguments for createNetInstall.sh...");
    
    NSArray *createNetInstallArguments = [nbiController generateScriptArgumentsForCreateNetInstall:workflowItem];
    if ( [createNetInstallArguments count] != 0 ) {
        [workflowItem setScriptArguments:createNetInstallArguments];
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Generating script arguments for createNetInstall.sh failed"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create script environment variables for createNetInstall.sh
    // -------------------------------------------------------------
    DDLogInfo(@"Generating script environment variables for createNetInstall.sh...");
    
    NSDictionary *environmentVariables = [nbiController generateEnvironmentVariablesForCreateNetInstall:workflowItem];
    [workflowItem setScriptEnvironmentVariables:environmentVariables ?: @{}]; // This is not used, using environment variables file instead. This will probably be removed.
    
    // -------------------------------------------------------------
    //  Copy required files to NBI folder
    // -------------------------------------------------------------
    DDLogInfo(@"Preparing build folder for createNetInstall.sh...");
    
    NSURL *createCommonURL = [[workflowItem applicationSource] createCommonURL];
    DDLogDebug(@"[DEBUG] Script createCommon.sh path: %@", [createCommonURL path]);
    
    if ( [createCommonURL checkResourceIsReachableAndReturnError:&err] ) {
        if ( ! [self prepareDestinationFolder:_temporaryNBIURL createCommonURL:createCommonURL workflowItem:workflowItem error:&err] ) {
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Preparing build folder for createNetInstall.sh failed"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Script createCommon.sh doesn't exist"] }];
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
    
    [[helperConnector connection] setExportedObject:_messageDelegate];
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCMessageDelegate)]];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"createNetInstall.sh failed"] }];
            
            return;
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
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"createNetInstall.sh failed"] }];
                
                return;
            }
        }];
    }];
} // runWorkflowSystemImageUtility

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Pre-/Post Workflow Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)prepareDestinationFolder:(NSURL *)destinationFolderURL createCommonURL:(NSURL *)createCommonURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // ------------------------------------------------------------------
    //  Create array for temporary items to be deleted at end of workflow
    // ------------------------------------------------------------------
    NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
    if ( ! temporaryItemsNBI ) {
        temporaryItemsNBI = [[NSMutableArray alloc] init];
    }
    
    // -------------------------------------------------------------------------------------
    //  Copy createCommon.sh to NBI folder for createNetInstall.sh to use when building NBI
    // -------------------------------------------------------------------------------------
    NSURL *createCommonDestinationURL = [destinationFolderURL URLByAppendingPathComponent:@"createCommon.sh"];
    if ( [fm isReadableFileAtPath:[createCommonURL path]] ) {
        if ( [fm copyItemAtURL:createCommonURL toURL:createCommonDestinationURL error:error] ) {
            [temporaryItemsNBI addObject:createCommonDestinationURL];
            [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
            return YES;
        } else {
            return NO;
        }
    } else {
        *error = [NBCError errorWithDescription:@"NBICreator doesn't have read permissions for createCommon.sh"];
        return NO;
    }
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)removeTemporaryItems:(NBCWorkflowItem *)workflowItem {
    
    NSError *error;
    
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    DDLogDebug(@"[DEBUG] Deleting temporary items...");
    
    NSArray *temporaryItemsNBI = [workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        DDLogDebug(@"[DEBUG] Deleting temporary item: %@", [temporaryItemURL lastPathComponent]);
        
        if ( ! [[NSFileManager defaultManager] removeItemAtURL:temporaryItemURL error:&error] ) {
            DDLogError(@"[ERROR] Failed Deleting file: %@", [temporaryItemURL path] );
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
} // removeTemporaryItems

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

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
                [self->_delegate updateProgressBar:85];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Performing post install cleanup..." workflow:self];
                [self->_delegate updateProgressBar:90];
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
        DDLogError(@"[ERROR] %@", stdErr);
    }
} // updateNetInstallWorkflowStatus:stdErr

- (void)checkDiskVolumeName:(id)sender {
    
    // --------------------------------------------------------------------------------
    //  Verify that the volumeName is the expected NBI volume name.
    //  Verify that the disk that is mounting has mounted completely (have a volumeURL)
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
        NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)volumeCurrentSize countStyle:NSByteCountFormatterCountStyleDecimal];
        NSString *fileSizeOriginal = [NSByteCountFormatter stringFromByteCount:(long long)_netInstallVolumeSize countStyle:NSByteCountFormatterCountStyleDecimal];
        
        if ( _netInstallVolumeSize <= volumeCurrentSize || _copyComplete == YES ) {
            [timer invalidate];
            timer = nil;
        } else {
            double precentage = (((40 * volumeCurrentSize)/_netInstallVolumeSize) + 40);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                [self->_delegate updateProgressBar:precentage];
            });
        }
    } else {
        [timer invalidate];
        timer = nil;
        
        DDLogError(@"[ERROR] Could not get file attributes for volume: %@", _diskVolumePath);
        DDLogError(@"[ERROR] %@", error);
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
        
        DDLogError(@"[ERROR] Could not get file attributes for volume: %@", _diskVolumePath);
        DDLogError(@"[ERROR] %@", error);
    }
} // checkCopyProgress

- (void)updateProgressBar:(double)value {
    
    // --------------------------------
    //  Ignore negative progress value
    // --------------------------------
    if ( value <= 0 ) {
        return;
    }
    
    double precentage = (40 * value)/[@100 doubleValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Creating disk image... %d%%", (int)value] workflow:self];
        [self->_delegate updateProgressBar:precentage];
    });
} // updateProgressBar

@end
