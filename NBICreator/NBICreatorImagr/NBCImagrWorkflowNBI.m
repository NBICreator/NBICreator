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
#import "NBCWorkflowProgressViewController.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Starting workflow Imagr NBI...");
    [self setNbiVolumeName:[[workflowItem nbiName] stringByDeletingPathExtension]];
    DDLogDebug(@"[DEBUG] _nbiVolumeName=%@", _nbiVolumeName);
    [self setTemporaryNBIURL:[workflowItem temporaryNBIURL]];
    DDLogDebug(@"[DEBUG] _temporaryNBIURL=%@", _temporaryNBIURL);
    if ( ! _temporaryNBIURL ) {
        DDLogError(@"[ERROR] Got no path to temporary NBI folder");
        NSDictionary *errorUserInfo = @{
                                        NSLocalizedDescriptionKey: NSLocalizedString(@"No path to temporary NBI folder.", nil),
                                        NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Path to temporary NBI folder was empty.", nil),
                                        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try restarting the Application and try again.", nil)
                                        };
        NSError *error = [NSError errorWithDomain:NBCErrorDomain
                                             code:-1
                                         userInfo:errorUserInfo];
        NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        return;
    }

    [self setMessageDelegate:[workflowItem progressView]];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiCreationTool = userSettings[NBCSettingsNBICreationToolKey];
    DDLogDebug(@"[DEBUG] nbiCreationTool=%@", nbiCreationTool);
    if ( [nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemSystemImageUtility];
        [self runWorkflowSystemImageUtility:workflowItem];
    } else if ( [nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        [[workflowItem target] setCreationTool:NBCMenuItemNBICreator];
        [self runWorkflowNBICreator:workflowItem];
    }
}

- (void)runWorkflowNBICreator:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Using NBI Creator to create base NBI");
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Get used space for BaseSystem.dmg for copy progress bar
    // -------------------------------------------------------------
    NSURL *baseSystemURL = [[workflowItem source] baseSystemURL];
    DDLogDebug(@"[DEBUG] baseSystemURL=%@", baseSystemURL);
    NSString *baseSystemPath = [baseSystemURL path];
    DDLogDebug(@"[DEBUG] baseSystemPath=%@", baseSystemPath);
    if ( [baseSystemPath length] != 0 ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:baseSystemPath error:&error];
        if ( [volumeAttributes count] != 0 ) {
            double fileSize = [volumeAttributes[NSFileSize] doubleValue];
            [self setTemporaryNBIBaseSystemSize:fileSize];
            DDLogDebug(@"[DEBUG] _temporaryNBIBaseSystemSize=%f", _temporaryNBIBaseSystemSize);
        } else {
            DDLogError(@"[ERROR] Could not get volumeAttributes from InstallESD Volume");
            NSDictionary *userInfo = nil;
            if ( error ) {
                DDLogError(@"[ERROR] %@", error);
                userInfo = @{ NBCUserInfoNSErrorKey : error };
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }
    } else {
        DDLogError(@"[ERROR] Path for source BaseSystem.dmg is empty!");
        NSDictionary *errorUserInfo = @{
                                        NSLocalizedDescriptionKey: NSLocalizedString(@"No path to source BaseSystem.dmg.", nil),
                                        NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Path to BaseSystem.dmg was empty.", nil),
                                        NSLocalizedRecoverySuggestionErrorKey: NSLocalizedString(@"Try restarting the Application and try again.", nil)
                                        };
        error = [NSError errorWithDomain:NBCErrorDomain
                                    code:-1
                                userInfo:errorUserInfo];
        NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Creating NBI folder...");
    NSURL *temporaryNBIx86FolderURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64"];
    DDLogDebug(@"[DEBUG] temporaryNBIx86FolderURL=%@", temporaryNBIx86FolderURL);
    if ( temporaryNBIx86FolderURL ) {
        if ( ! [fm createDirectoryAtURL:temporaryNBIx86FolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            DDLogError(@"[ERROR] Could not create NBI folder!");
            DDLogError(@"%@", error);
            NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
            return;
        }
    }
    
    // -------------------------------------------------------------
    //  Copy BaseSystem.dmg to temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Copying BaseSystem.dmg from source to NBI folder...");
    [self setCopyComplete:NO];
    DDLogDebug(@"[DEBUG] _copyComplete=%hhd", _copyComplete);
    NSURL *baseSystemTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
    DDLogDebug(@"[DEBUG] baseSystemTargetURL=%@", baseSystemTargetURL);
    [self setTemporaryNBIBaseSystemPath:[baseSystemTargetURL path]];
    DDLogDebug(@"[DEBUG] _temporaryNBIBaseSystemPath=%@", _temporaryNBIBaseSystemPath);
    [[workflowItem target] setBaseSystemURL:baseSystemTargetURL];
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        NSError *blockError;
        if ( ! [fm copyItemAtURL:baseSystemURL toURL:baseSystemTargetURL error:&blockError] ) {
            [self setCopyComplete:YES];
            DDLogDebug(@"[DEBUG] _copyComplete=%hhd", self->_copyComplete);
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogError(@"[ERROR] Could not copy BaseSystem.dmg to NBI folder!");
                NSDictionary *userInfo = nil;
                if ( error ) {
                    DDLogError(@"[ERROR] %@", blockError);
                    userInfo = @{ NBCUserInfoNSErrorKey : blockError };
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:userInfo];
                return;
            });
        } else {
            [self setCopyComplete:YES];
            DDLogDebug(@"[DEBUG] _copyComplete=%hhd", self->_copyComplete);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createNBIFilesNBICreator:workflowItem baseSystemTemporaryURL:baseSystemTargetURL];
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
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Copying NBI specific files...");
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFileManager *fm = [NSFileManager defaultManager];
    NBCImagrWorkflowModifyNBI *modifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    
    if ( [modifyNBI resizeAndMountBaseSystemWithShadow:baseSystemTemporaryURL target:[workflowItem target]] ) {
        NSURL *baseSystemTemporaryVolumeURL = [[workflowItem target] baseSystemVolumeURL];
        if ( baseSystemTemporaryVolumeURL ) {
            
            // --------------------------------------------------------------------------
            //  Copy booter
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying booter file...");
            [_delegate updateProgressStatus:@"Copying booter file..." workflow:self];
            NSURL *booterSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/boot.efi"];
            DDLogDebug(@"[DEBUG] booterSourceURL=%@", booterSourceURL);
            NSURL *booterTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/booter"];
            DDLogDebug(@"[DEBUG] booterTargetURL=%@", booterTargetURL);
            
            if ( ! [fm copyItemAtURL:booterSourceURL toURL:booterTargetURL error:&error] ) {
                DDLogError(@"[ERROR] Could not copy booter file!");
                DDLogError(@"%@", error );
                NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
            } else {
                NSDictionary *booterAttributes = @{ NSFileImmutable : @NO };
                if ( ! [fm setAttributes:booterAttributes ofItemAtPath:[booterTargetURL path] error:&error] ) {
                    DDLogWarn(@"[WARN] Unable to unlock booter file!");
                    DDLogWarn(@"%@", error );
                }
            }
            
            // --------------------------------------------------------------------------
            //  Copy PlatformSupport.plist
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying PlatformSupport.plist...");
            [_delegate updateProgressStatus:@"Copying PlatformSupport.plist..." workflow:self];
            NSURL *platformSupportSourceURL;
            NSURL *platformSupportTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
            DDLogDebug(@"[DEBUG] platformSupportTargetURL=%@", platformSupportTargetURL);
            if ( [[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
            } else {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/PlatformSupport.plist"];
            }
            DDLogDebug(@"[DEBUG] platformSupportSourceURL=%@", platformSupportSourceURL);
            if ( ! [fm copyItemAtURL:platformSupportSourceURL toURL:platformSupportTargetURL error:&error] ) {
                DDLogError(@"[ERROR] Error while copying platform support plist");
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
                NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
            }
            
            // --------------------------------------------------------------------------
            //  Copy kernel cache
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying kernel cache files...");
            [_delegate updateProgressStatus:@"Copying kernel cache files..." workflow:self];
            NSURL *kernelCacheTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
            NSURL *kernelCacheSourceURL;
            kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/PrelinkedKernels/prelinkedkernel"];
            if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"];
                if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                    DDLogInfo(@"Found no precompiled kernel cache files!");
                    //[self generateKernelCacheForNBI:workflowItem];
                    
                } else {
                    DDLogDebug(@"[DEBUG] kernelCacheSourceURL=%@", kernelCacheSourceURL);
                    if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                        [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                    } else {
                        DDLogError(@"[ERROR] Error while copying kernel cache file");
                        NSDictionary *userInfo = nil;
                        if ( error ) {
                            DDLogError(@"[ERROR] %@", error);
                            userInfo = @{ NBCUserInfoNSErrorKey : error };
                        }
                        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                    }
                }
            } else {
                DDLogDebug(@"[DEBUG] kernelCacheSourceURL=%@", kernelCacheSourceURL);
                if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                    [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                } else {
                    DDLogError(@"[ERROR] Error while copying kernel cache file");
                    DDLogError(@"[ERROR] %@", error);
                    NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
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

- (void)runWorkflowSystemImageUtility:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Using System Image Utitlity to create base NBI");
    NSError *err;
    __unsafe_unretained typeof(self) weakSelf = self;
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
    
    // -------------------------------------------------------------
    //  Get used space on InstallESD source volume for progress bar
    // -------------------------------------------------------------
    NSString *installESDVolumePath = [[[workflowItem source] installESDVolumeURL] path];
    DDLogDebug(@"[DEBUG] installESDVolumePath=%@", installESDVolumePath);
    if ( [installESDVolumePath length] != 0 ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:installESDVolumePath error:&err];
        DDLogDebug(@"[DEBUG] volumeAttributes=%@", volumeAttributes);
        if ( [volumeAttributes count] != 0 ) {
            double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
            double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
            [self setNetInstallVolumeSize:( maxSize - freeSize )];
            DDLogDebug(@"[DEBUG] _netInstallVolumeSize=%f", _netInstallVolumeSize);
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
    DDLogDebug(@"[DEBUG] createNetInstallArguments=%@", createNetInstallArguments);
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
    DDLogDebug(@"[DEBUG] environmentVariables=%@", environmentVariables);
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
    DDLogDebug(@"[DEBUG] createCommonURL=%@", createCommonURL);
    if ( createCommonURL ) {
        if ( ! [self prepareDestinationFolder:_temporaryNBIURL createCommonURL:createCommonURL workflowItem:workflowItem error:&err] ) {
            DDLogError(@"[ERROR] Errror preparing destination folder");
            DDLogError(@"%@", err);
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
    
    NSLog(@"_messageDelegate=%@", _messageDelegate);
    [[helperConnector connection] setExportedObject:_messageDelegate];
    NSLog(@"[helperConnector connection] exportedObject=%@", [[helperConnector connection] exportedObject]),
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCMessageDelegate)]];
    
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
        
    }] runTaskWithCommandAtPath:commandURL arguments:createNetInstallArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            DDLogDebug(@"[DEBUG] terminationStatus=%d", terminationStatus);
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
} // runWorkflow

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Pre-/Post Workflow Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)prepareDestinationFolder:(NSURL *)destinationFolderURL createCommonURL:(NSURL *)createCommonURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    BOOL retval = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // ------------------------------------------------------------------
    //  Create array for temporary items to be deleted at end of workflow
    // ------------------------------------------------------------------
    NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
    if ( ! temporaryItemsNBI ) {
        temporaryItemsNBI = [[NSMutableArray alloc] init];
    }
    DDLogDebug(@"[DEBUG] temporaryItemsNBI=%@", temporaryItemsNBI);
    
    // ------------------------------------------------------------------
    //  Save URL for NBI NetInstall.dmg
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [destinationFolderURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    DDLogDebug(@"[DEBUG] nbiNetInstallURL=%@", nbiNetInstallURL);
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    // -------------------------------------------------------------------------------------
    //  Copy createCommon.sh to NBI folder for createNetInstall.sh to use when building NBI
    // -------------------------------------------------------------------------------------
    NSURL *createCommonDestinationURL = [destinationFolderURL URLByAppendingPathComponent:@"createCommon.sh"];
    DDLogDebug(@"[DEBUG] createCommonDestinationURL=%@", createCommonDestinationURL);
    if ( [fileManager isReadableFileAtPath:[createCommonURL path]] ) {
        if ( [fileManager copyItemAtURL:createCommonURL toURL:createCommonDestinationURL error:error] ) {
            [temporaryItemsNBI addObject:createCommonDestinationURL];
            
            retval = YES;
        } else {
            DDLogError(@"[ERROR] Could not copy createCommon.sh");
            DDLogError(@"%@", *error);
        }
    } else {
        DDLogError(@"Could not read createCommon.sh to copy to tmp folder");
    }
    
    [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    
    return retval;
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)removeTemporaryItems:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *temporaryItemsNBI = [workflowItem temporaryItemsNBI];
    DDLogDebug(@"[DEBUG] temporaryItemsNBI=%@", temporaryItemsNBI);
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        DDLogDebug(@"[DEBUG] temporaryItemURL=%@", temporaryItemURL);
        if ( ! [fileManager removeItemAtURL:temporaryItemURL error:&error] ) {
            DDLogError(@"[ERROR] Failed Deleting file: %@", [temporaryItemURL path] );
            DDLogError(@"%@", error);
        }
    }
} // removeTemporaryItems

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateNetInstallWorkflowStatus:(NSString *)outStr stdErr:(NSString *)stdErr {
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    DDLogDebug(@"[createNetInstall.sh] %@", outStr);
    
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
    DDLogDebug(@"[DEBUG] %@", NSStringFromSelector(_cmd));
    
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
        DDLogError(@"%@", error);
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
        DDLogError(@"%@", error);
    }
} // checkCopyProgress

- (void)updateProgressBar:(double)value {
    
    if ( value <= 0 ) {
        return;
    }
    
    double precentage = (40 * value)/[@100 doubleValue];
    [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Creating disk image... %d%%", (int)value] workflow:self];
    [self->_delegate updateProgressBar:precentage];
} // updateProgressBar

@end
