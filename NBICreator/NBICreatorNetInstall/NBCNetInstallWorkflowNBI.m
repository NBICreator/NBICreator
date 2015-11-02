//
//  NBCWorkflowNetInstall.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallWorkflowNBI.h"
#import "NBCConstants.h"

#import "NBCController.h"
#import "NBCWorkflowNBIController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"
#import "NBCDiskArbitrator.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallWorkflowNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    NSError *err;
    
    [self setPackageOnlyScriptRun:NO];
    [self setNbiVolumeName:[[workflowItem nbiName] stringByDeletingPathExtension]];
    [self setTemporaryNBIPath:[[workflowItem temporaryNBIURL] path]];
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
    
    NSDictionary *resourcesSettings = [workflowItem resourcesSettings];
    
    BOOL packageOnly = [[workflowItem userSettings][NBCSettingsNetInstallPackageOnlyKey] boolValue];
    
    NSArray *scriptArguments = @[];
    NSDictionary *environmentVariables = @{};
    
    if ( packageOnly ) {
        
        // -------------------------------------------------------------
        //  Create arguments array for createRestoreFromSources.sh
        // -------------------------------------------------------------
        NSArray *createRestoreFromSourcesArguments = [nbiController generateScriptArgumentsForCreateRestoreFromSources:workflowItem];
        if ( [createRestoreFromSourcesArguments count] != 0 ) {
            [workflowItem setScriptArguments:createRestoreFromSourcesArguments];
            scriptArguments = createRestoreFromSourcesArguments;
        } else {
            NSLog(@"[ERROR] No argumets for createRestoreFromSources");
            return;
        }
        
        // -------------------------------------------------------------
        //  Create environment variables for createRestoreFromSources.sh
        // -------------------------------------------------------------
        if ( [nbiController generateEnvironmentVariablesForCreateRestoreFromSources:workflowItem] ) {
            environmentVariables = @{}; // Here because not changing Helper Yet
        } else {
            DDLogError(@"[ERROR] No variables for createRestoreFromSources!");
            return;
        }
    } else {
        
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
            scriptArguments = createNetInstallArguments;
        } else {
            NSLog(@"[ERROR] No arguments for createNetInstall");
            return;
        }
        
        // -------------------------------------------------------------
        //  Create environment variables for createNetInstall.sh
        // -------------------------------------------------------------
        NSDictionary *createNetInstallEnvironmentVariables = [nbiController generateEnvironmentVariablesForCreateNetInstall:workflowItem];
        if ( [createNetInstallEnvironmentVariables count] != 0 ) {
            [workflowItem setScriptEnvironmentVariables:createNetInstallEnvironmentVariables];
            environmentVariables = createNetInstallEnvironmentVariables;
        } else {
            DDLogError(@"[ERROR] No variables for createNetInstall");
        }
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
    
    NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
    if ( ! temporaryItemsNBI ) {
        temporaryItemsNBI = [[NSMutableArray alloc] init];
    }
    
    if ( packageOnly ) {
        NSURL *installPreferencesPlist = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"InstallPreferences.plist"];
        if ( ! [@{ @"packageOnlyMode" : @YES } writeToURL:installPreferencesPlist atomically:NO] ) {
            DDLogError(@"[ERROR] Could not write InstallPreferences.plist to temporary folder!");
            return;
        }
        
        NSURL *asrInstallPkgSourceURL = [[workflowItem applicationSource] asrInstallPkgURL];
        if ( asrInstallPkgSourceURL ) {
            NSURL *asrInstallPkgTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:[asrInstallPkgSourceURL lastPathComponent]];
            if ( ! [[NSFileManager defaultManager] copyItemAtURL:asrInstallPkgSourceURL toURL:asrInstallPkgTargetURL error:&err] ) {
                DDLogError(@"[ERROR] %@", err);
                return;
            }
        } else {
            DDLogError(@"[ERROR] No path to asrInstallPkg");
            return;
        }
        
        NSURL *asrPostInstallPackagesURL = [[workflowItem applicationSource] postInstallPackages];
        if ( asrPostInstallPackagesURL ) {
            NSURL *asrPostInstallPackagesTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:[asrPostInstallPackagesURL lastPathComponent]];
            if ( ! [[NSFileManager defaultManager] copyItemAtURL:asrPostInstallPackagesURL toURL:asrPostInstallPackagesTargetURL error:&err] ) {
                DDLogError(@"[ERROR] %@", err);
                return;
            }
        } else {
            DDLogError(@"[ERROR] No path to postInstallPackages");
            return;
        }
        
        NSURL *preserveInstallLogURL = [[workflowItem applicationSource] preserveInstallLog];
        if ( preserveInstallLogURL ) {
            NSURL *preserveInstallLogTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:[preserveInstallLogURL lastPathComponent]];
            if ( ! [[NSFileManager defaultManager] copyItemAtURL:preserveInstallLogURL toURL:preserveInstallLogTargetURL error:&err] ) {
                DDLogError(@"[ERROR] %@", err);
                return;
            }
        } else {
            DDLogError(@"[ERROR] No path to preserveInstallLog");
            return;
        }
        
        NSURL *netBootClientHelperURL = [[workflowItem applicationSource] netBootClientHelper];
        if ( netBootClientHelperURL ) {
            NSURL *netBootClientHelperTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:[netBootClientHelperURL lastPathComponent]];
            if ( ! [[NSFileManager defaultManager] copyItemAtURL:netBootClientHelperURL toURL:netBootClientHelperTargetURL error:&err] ) {
                DDLogError(@"[ERROR] %@", err);
                return;
            }
        } else {
            DDLogError(@"[ERROR] No path to netBootClientHelper");
            return;
        }
        
        NSURL *buildCommandsTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"buildCommands.sh"];
        NSString *buildCommandsContent = [NSString stringWithFormat:@"'%@' \"%@\" \"/\" \"System\" || exit 1\n", [[[workflowItem applicationSource] asrFromVolumeURL] path], [[workflowItem temporaryNBIURL] path]];
        if ( ! [buildCommandsContent writeToURL:buildCommandsTargetURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
            NSLog(@"[ERROR] %@", err);
            return;
        }
    }
    
    BOOL writeOSInstall = NO;
    NSMutableArray *osInstallArray = [NSMutableArray arrayWithArray:@[ @"/System/Installation/Packages/OSInstall.mpkg",
                                                                       @"/System/Installation/Packages/OSInstall.mpkg" ]];
    
    NSArray *configurationProfilesNetInstall = resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey];
    if ( [configurationProfilesNetInstall count] != 0 ) {
        NSURL *configProfilesURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"configProfiles.txt"];
        [temporaryItemsNBI addObject:configProfilesURL];
        NSMutableString *configProfilesContent = [[NSMutableString alloc] init];
        for ( NSString *configProfilePath in configurationProfilesNetInstall ) {
            [configProfilesContent appendString:[NSString stringWithFormat:@"%@\n", configProfilePath]];
        }
        
        if ( [configProfilesContent writeToURL:configProfilesURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
            writeOSInstall = YES;
        } else {
            NSLog(@"[ERROR] %@", err);
            return;
        }
        
        NSURL *installConfigurationProfilesScriptURL = [[workflowItem applicationSource] installConfigurationProfiles];
        NSURL *installConfigurationProfilesScriptTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"installConfigurationProfiles.sh"];
        [temporaryItemsNBI addObject:installConfigurationProfilesScriptTargetURL];
        if ( [[NSFileManager defaultManager] copyItemAtURL:installConfigurationProfilesScriptURL toURL:installConfigurationProfilesScriptTargetURL error:&err] ) {
            [osInstallArray addObject:[NSString stringWithFormat:@"/System/Installation/Packages/%@.pkg", [installConfigurationProfilesScriptURL lastPathComponent]]];
        } else {
            NSLog(@"[ERROR] %@", err);
            return;
        }
    }
    
    NSArray *trustedNetBootServers = resourcesSettings[NBCSettingsTrustedNetBootServersKey];
    if ( [trustedNetBootServers count] != 0 ) {
        NSURL *bsdpSourcesURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"bsdpSources.txt"];
        [temporaryItemsNBI addObject:bsdpSourcesURL];
        NSMutableString *bsdpSourcesContent = [[NSMutableString alloc] init];
        for ( NSString *netBootServerIP in trustedNetBootServers ) {
            [bsdpSourcesContent appendString:[NSString stringWithFormat:@"%@\n", netBootServerIP]];
        }
        
        if ( [bsdpSourcesContent writeToURL:bsdpSourcesURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
            writeOSInstall = YES;
        } else {
            NSLog(@"ERROR %@", err);
            return;
        }
        
        NSURL *addBSDPSourcesScriptURL = [[workflowItem applicationSource] addBSDPSourcesURL];
        if ( packageOnly ) {
            NSURL *addBSDPSourcesScriptTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:[addBSDPSourcesScriptURL lastPathComponent]];
            if ( ! [[NSFileManager defaultManager] copyItemAtURL:addBSDPSourcesScriptURL toURL:addBSDPSourcesScriptTargetURL error:&err] ) {
                DDLogError(@"[ERROR] %@", [err localizedDescription]);
                return;
            }
        } else {
            NSURL *additionalScriptsURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"additionalScripts.txt"];
            NSMutableString *additionalScriptsContent = [[NSMutableString alloc] initWithContentsOfURL:additionalScriptsURL encoding:NSUTF8StringEncoding error:&err] ?: [[NSMutableString alloc] init];
            
            [additionalScriptsContent appendString:[NSString stringWithFormat:@"%@\n", [addBSDPSourcesScriptURL path]]];
            [osInstallArray addObject:[NSString stringWithFormat:@"/System/Installation/Packages/%@.pkg", [addBSDPSourcesScriptURL lastPathComponent]]];
            
            if ( [additionalScriptsContent writeToURL:additionalScriptsURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
                writeOSInstall = YES;
            } else {
                NSLog(@"ERROR %@", err);
                return;
            }
        }
    }
    
    NSArray *packagesNetInstall = resourcesSettings[NBCSettingsNetInstallPackagesKey];
    if ( [packagesNetInstall count] != 0 ) {
        NSError *error;
        NSURL *additionalPackagesURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"additionalPackages.txt"];
        [temporaryItemsNBI addObject:additionalPackagesURL];
        NSMutableString *additionalPackagesContent = [[NSMutableString alloc] init];
        
        NSURL *additionalScriptsURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"additionalScripts.txt"];
        NSMutableString *additionalScriptsContent = [[NSMutableString alloc] initWithContentsOfURL:additionalScriptsURL encoding:NSUTF8StringEncoding error:&err] ?: [[NSMutableString alloc] init];
        
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        for ( NSString *packagePath in packagesNetInstall ) {
            NSString *fileType = [[NSWorkspace sharedWorkspace] typeOfFile:packagePath error:&error];
            if ( [workspace type:fileType conformsToType:@"com.apple.installer-package-archive"] ) {
                [additionalPackagesContent appendString:[NSString stringWithFormat:@"%@\n", packagePath]];
                [osInstallArray addObject:[NSString stringWithFormat:@"/System/Installation/Packages/%@", [packagePath lastPathComponent]]];
            } else if ( [workspace type:fileType conformsToType:@"public.shell-script"] ) {
                [additionalScriptsContent appendString:[NSString stringWithFormat:@"%@\n", packagePath]];
                [osInstallArray addObject:[NSString stringWithFormat:@"/System/Installation/Packages/%@.pkg", [packagePath lastPathComponent]]];
            }
        }
        [additionalPackagesContent appendString:@"\\n"];
        
        
        [temporaryItemsNBI addObject:additionalScriptsURL];
        if ( [configurationProfilesNetInstall count] != 0 ) {
            NSURL *inetInstallConfigurationProfilesScriptURL = [[workflowItem applicationSource] netInstallConfigurationProfiles];
            [additionalScriptsContent appendString:[NSString stringWithFormat:@"%@\n", [inetInstallConfigurationProfilesScriptURL path]]];
        }
        
        if ( [additionalPackagesContent writeToURL:additionalPackagesURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
            writeOSInstall = YES;
        } else {
            NSLog(@"[ERROR] %@", err);
            return;
        }
        
        if ( [additionalScriptsContent writeToURL:additionalScriptsURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
            writeOSInstall = YES;
        } else {
            NSLog(@"[ERROR] %@", err);
            return;
        }
        
        if ( packageOnly ) {
            [@{} writeToURL:[[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"ASRInstall.mpkg"] atomically:YES];
        }
    }
    
    if ( writeOSInstall ) {
        NSURL *osInstallURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"OSInstall.collection"];
        [temporaryItemsNBI addObject:osInstallURL];
        NSDictionary *osInstallDict = (NSDictionary*)osInstallArray;
        [osInstallDict writeToURL:osInstallURL atomically:YES];
    }
    NSLog(@"path=%@", [[workflowItem temporaryNBIURL] path]);
    [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    
    // Mount recovery if not already mounted
    if ( packageOnly ) {
        NSLog(@"Mounting!");
        //[[[workflowItem source] recoveryDisk] unmountWithOptions:kDADiskUnmountOptionDefault];
    }
    
    [self runSystemImageUtilityScript:workflowItem striptArguments:scriptArguments];
}

- (void)runSystemImageUtilityScript:(NBCWorkflowItem *)workflowItem striptArguments:(NSArray *)scriptArguments {
    
    NSString *scriptName;
    
    if ( [scriptArguments count] != 0 ) {
        scriptName = [scriptArguments[0] lastPathComponent];
    } else {
        DDLogError(@"[ERROR] Arguments array passed to script was empty");
        return;
    }
    
    __unsafe_unretained typeof(self) weakSelf = self;
    BOOL packageOnly = [[workflowItem userSettings][NBCSettingsNetInstallPackageOnlyKey] boolValue];
    
    // ------------------------------------------
    //  Setup command to run createNetInstall.sh
    // ------------------------------------------
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
                                        DDLogDebug(@"[%@][stdout] %@", scriptName, outStr);
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
                                        NSString *errStr = [[[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        DDLogDebug(@"[%@][stderr] %@", scriptName, errStr);
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
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            DDLogError(@"[ERROR] %@", proxyError);
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:scriptArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
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
                
                // Emergency fix, need to figure out WHY the script always fail the first time it is run.
                if ( packageOnly && ! self->_packageOnlyScriptRun ) {
                    DDLogDebug(@"[DEBUG] createRestoreFromSources.sh failed on first try, trying again...");
                    [self setPackageOnlyScriptRun:YES];
                    [self runSystemImageUtilityScript:workflowItem striptArguments:scriptArguments];
                }
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                NSDictionary *userInfo = nil;
                if ( error ) {
                    userInfo = @{ NBCUserInfoNSErrorKey : error };
                }
                //[nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
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
            
            if ([[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                NSString *createCommon = [[NSString alloc] initWithContentsOfURL:createCommonDestinationURL encoding:NSUTF8StringEncoding error:error];
                NSString *updatedCreateCommon = [createCommon stringByReplacingOccurrencesOfString:@"CoreServices/PlatformSupport.plist"
                                                                                        withString:@"CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
                if ( ! [updatedCreateCommon writeToURL:createCommonDestinationURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                    NSLog(@"Could no write updated CreateCommon file to path %@", createCommonDestinationURL);
                }
            }
            
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
    DDLogInfo(@"Removing temporary items...");
    
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
    
    // Delete all items in root of NBI except 'allowedItems'.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *nbiFolder = [workflowItem temporaryNBIURL];
    NSArray *allowedItems = @[ @"i386", @"NetInstall.dmg", @"NBImageInfo.plist" ];
    NSArray *nbiFolderContents = [fm contentsOfDirectoryAtURL:nbiFolder includingPropertiesForKeys:@[] options:0 error:&error];
    
    [nbiFolderContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
        NSError *err;
        NSString *filename = [obj lastPathComponent];
        if ( ! [allowedItems containsObject:filename] ) {
            if ( ! [fm removeItemAtURL:obj error:&err] ) {
                NSLog(@"Could not remove temporary item: %@", filename);
                NSLog(@"%@", err);
            }
        }
    }];
} // removeTemporaryItems

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateNetInstallWorkflowStatus:(NSString *)outStr stdErr:(NSString *)stdErr {
#pragma unused(stdErr)
    
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
            if ( [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Creating disk image..." workflow:self];
            }
            
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
                [self->_delegate updateProgressBar:80];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Performing post install cleanup..." workflow:self];
                [self->_delegate updateProgressBar:85];
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
            
            [self updateProgressBarCopy];
        }
    }
} // checkDiskVolumeName

- (void)updateProgressBarCopy {
    
    // ---------------------------------------------------
    //  Loop to check volume size and update progress bar
    // ---------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgress:)
                                   userInfo:nil
                                    repeats:YES];
} // updateProgressBarCopy

-(void)checkCopyProgress:(NSTimer *)timer {
    
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
            timer = NULL;
        } else {
            double precentage = (((40 * volumeCurrentSize)/_netInstallVolumeSize) + 40);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                [self->_delegate updateProgressBar:precentage];
            });
        }
    } else {
        [timer invalidate];
        timer = NULL;
        
        NSLog(@"Could not get file attributes for volume: %@", _diskVolumePath);
        NSLog(@"Error: %@", error);
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
