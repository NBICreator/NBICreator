//
//  NBCWorkflowSystemImageUtility.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "NBCWorkflowSystemImageUtility.h"
#import "NBCWorkflowItem.h"
#import "NBCError.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"
#import "NBCHelperAuthorization.h"
#import "NBCWorkflowNBIController.h"

@implementation NBCWorkflowSystemImageUtility

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
#pragma mark Create NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)createNBI:(NBCWorkflowItem *)workflowItem {
    
    NSError *error = nil;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [self setWorkflowItem:workflowItem];
    [self setPackageOnly:[[workflowItem userSettings][NBCSettingsNetInstallPackageOnlyKey] boolValue]];
    [self setNbiVolumeName:[[workflowItem nbiName] stringByDeletingPathExtension]];
    
    // ------------------------------------------------------------------
    //  Check and set temporary NBI URL to property
    // ------------------------------------------------------------------
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    DDLogDebug(@"[DEBUG] Temporary nbi path: %@", [temporaryNBIURL path]);
    
    if ( [temporaryNBIURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setTemporaryNBIURL:temporaryNBIURL];
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Temporary NBI path not found"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Copy required items to NBI folder
    // -------------------------------------------------------------
    if ( ! [self prepareWorkflowFolder:_temporaryNBIURL error:&error] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing workflow folder failed"] }];
        return;
    }
    
    // ---------------------------------------------------------
    //  Prepare script and variables for selected workflow type
    // ---------------------------------------------------------
    if ( _packageOnly ) {
        [self prepareWorkflowPackageOnly];
    } else {
        [self runWorkflowNetInstall];
    }
}

- (BOOL)prepareWorkflowFolder:(NSURL *)workflowFolderURL error:(NSError **)error {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------------
    //  Create array for temporary items to be deleted at end of workflow
    // -------------------------------------------------------------------
    NSMutableArray *temporaryItemsNBI = [[_workflowItem temporaryItemsNBI] mutableCopy] ?: [[NSMutableArray alloc] init];
    
    // -------------------------------------------------
    //  Set temporary NBI NetInstall.dmg path to target
    // -------------------------------------------------
    NSURL *nbiNetInstallTemporaryURL = [workflowFolderURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    DDLogDebug(@"[DEBUG] NBI NetInstall disk image temporary path: %@", [nbiNetInstallTemporaryURL path]);
    [[_workflowItem target] setNbiNetInstallURL:nbiNetInstallTemporaryURL];
    
    // ------------------------------------
    //  Copy createCommon.sh to NBI folder
    // ------------------------------------
    NSURL *createCommonURL = [[_workflowItem applicationSource] createCommonURL];
    DDLogDebug(@"[DEBUG] createCommon.sh path: %@", [createCommonURL path]);
    
    NSURL *createCommonTargetURL = [workflowFolderURL URLByAppendingPathComponent:[createCommonURL lastPathComponent]];
    DDLogDebug(@"[DEBUG] createCommon.sh target path: %@", [createCommonTargetURL path]);
    
    if ( [fm copyItemAtURL:createCommonURL toURL:createCommonTargetURL error:error] ) {
        [temporaryItemsNBI addObject:createCommonTargetURL];
    } else {
        return NO;
    }
    
    // ----------------------------------------------------------------
    //  If this is a NetInstall workflow, check any additional content
    // ----------------------------------------------------------------
    if ( [_workflowItem workflowType] == kWorkflowTypeNetInstall ) {
        
        NSDictionary *resourcesSettings = [_workflowItem resourcesSettings];
        
        BOOL writeOSInstall = NO;
        NSMutableArray *osInstallArray = [NSMutableArray arrayWithArray:@[ @"/System/Installation/Packages/OSInstall.mpkg",
                                                                           @"/System/Installation/Packages/OSInstall.mpkg" ]];
        
        // -------------------------------------------
        //  Prepare to install configuration profiles
        // -------------------------------------------
        NSArray *configurationProfilesNetInstall = resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey];
        if ( [configurationProfilesNetInstall count] != 0 ) {
            
            // -------------------------------------------
            //  configProfiles.txt
            // -------------------------------------------
            NSURL *configProfilesURL = [_temporaryNBIURL URLByAppendingPathComponent:@"configProfiles.txt"];
            DDLogDebug(@"[DEBUG] configProfiles.txt path: %@", [configProfilesURL path]);
            
            [temporaryItemsNBI addObject:configProfilesURL];
            
            NSMutableString *configProfilesContent = [[NSMutableString alloc] init];
            for ( NSString *configProfilePath in configurationProfilesNetInstall ) {
                [configProfilesContent appendString:[NSString stringWithFormat:@"%@\n", configProfilePath]];
            }
            
            if ( [configProfilesContent writeToURL:configProfilesURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                writeOSInstall = YES;
            } else {
                return NO;
            }
            
            // -------------------------------------------
            //  installConfigurationProfiles.sh
            // -------------------------------------------
            NSURL *installConfigurationProfilesScriptURL = [[_workflowItem applicationSource] installConfigurationProfilesURL];
            DDLogDebug(@"[DEBUG] installConfigurationProfiles.sh path: %@", [installConfigurationProfilesScriptURL path]);
            
            NSURL *installConfigurationProfilesScriptTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[installConfigurationProfilesScriptURL lastPathComponent]];
            DDLogDebug(@"[DEBUG] installConfigurationProfiles.sh target path: %@", [installConfigurationProfilesScriptTargetURL path]);
            
            [temporaryItemsNBI addObject:installConfigurationProfilesScriptTargetURL];
            
            if ( [[NSFileManager defaultManager] copyItemAtURL:installConfigurationProfilesScriptURL toURL:installConfigurationProfilesScriptTargetURL error:error] ) {
                [osInstallArray addObject:@"/System/Installation/Packages/netInstallConfigurationProfiles.sh.pkg"];
            } else {
                return NO;
            }
        }
        
        // -------------------------------------------
        //  Prepare trusted netboot servers
        // -------------------------------------------
        NSArray *trustedNetBootServers = resourcesSettings[NBCSettingsTrustedNetBootServersKey];
        if ( [trustedNetBootServers count] != 0 ) {
            
            // -------------------------------------------
            //  bsdpSources.txt
            // -------------------------------------------
            NSURL *bsdpSourcesURL = [_temporaryNBIURL URLByAppendingPathComponent:@"bsdpSources.txt"];
            DDLogDebug(@"[DEBUG] bsdpSources.txt path: %@", [bsdpSourcesURL path]);
            
            [temporaryItemsNBI addObject:bsdpSourcesURL];
            
            NSMutableString *bsdpSourcesContent = [[NSMutableString alloc] init];
            for ( NSString *netBootServerIP in trustedNetBootServers ) {
                [bsdpSourcesContent appendString:[NSString stringWithFormat:@"%@\n", netBootServerIP]];
            }
            
            if ( [bsdpSourcesContent writeToURL:bsdpSourcesURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                writeOSInstall = YES;
            } else {
                return NO;
            }
            
            // -------------------------------------------
            //  addBSDPSources.sh
            // -------------------------------------------
            NSURL *addBSDPSourcesScriptURL = [[_workflowItem applicationSource] addBSDPSourcesURL];
            DDLogDebug(@"[DEBUG] addBSDPSources.sh path: %@", [addBSDPSourcesScriptURL path]);
            
            if ( _packageOnly ) {
                NSURL *addBSDPSourcesScriptTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[addBSDPSourcesScriptURL lastPathComponent]];
                DDLogDebug(@"[DEBUG] addBSDPSources.sh target path: %@", [addBSDPSourcesScriptTargetURL path]);
                
                if ( ! [[NSFileManager defaultManager] copyItemAtURL:addBSDPSourcesScriptURL toURL:addBSDPSourcesScriptTargetURL error:error] ) {
                    return NO;
                }
            } else {
                NSURL *additionalScriptsURL = [_temporaryNBIURL URLByAppendingPathComponent:@"additionalScripts.txt"];
                DDLogDebug(@"[DEBUG] additionalScripts.txt path: %@", [additionalScriptsURL path]);
                
                NSMutableString *additionalScriptsContent = [[NSMutableString alloc] initWithContentsOfURL:additionalScriptsURL encoding:NSUTF8StringEncoding error:error] ?: [[NSMutableString alloc] init];
                
                [additionalScriptsContent appendString:[NSString stringWithFormat:@"%@\n", [addBSDPSourcesScriptURL path]]];
                [osInstallArray addObject:[NSString stringWithFormat:@"/System/Installation/Packages/%@.pkg", [addBSDPSourcesScriptURL lastPathComponent]]];
                
                if ( [additionalScriptsContent writeToURL:additionalScriptsURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                    writeOSInstall = YES;
                } else {
                    return NO;
                }
            }
        }
        
        // -------------------------------------------
        //  Prepare packages and scripts
        // -------------------------------------------
        NSArray *packagesNetInstall = resourcesSettings[NBCSettingsNetInstallPackagesKey];
        if ( [packagesNetInstall count] != 0 ) {
            
            // -------------------------------------------
            //  additionalPackages.txt
            // -------------------------------------------
            NSURL *additionalPackagesURL = [_temporaryNBIURL URLByAppendingPathComponent:@"additionalPackages.txt"];
            DDLogDebug(@"[DEBUG] additionalPackages.txt path: %@", [additionalPackagesURL path]);
            
            [temporaryItemsNBI addObject:additionalPackagesURL];
            NSMutableString *additionalPackagesContent = [[NSMutableString alloc] init];
            
            // -------------------------------------------
            //  additionalScripts.txt
            // -------------------------------------------
            NSURL *additionalScriptsURL = [_temporaryNBIURL URLByAppendingPathComponent:@"additionalScripts.txt"];
            DDLogDebug(@"[DEBUG] additionalScripts.txt path: %@", [additionalScriptsURL path]);
            
            NSMutableString *additionalScriptsContent = [[NSMutableString alloc] initWithContentsOfURL:additionalScriptsURL encoding:NSUTF8StringEncoding error:error] ?: [[NSMutableString alloc] init];
            
            NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
            for ( NSString *packagePath in packagesNetInstall ) {
                NSString *fileType = [[NSWorkspace sharedWorkspace] typeOfFile:packagePath error:error];
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
                NSURL *netInstallConfigurationProfilesScriptURL = [[_workflowItem applicationSource] netInstallConfigurationProfiles];
                DDLogDebug(@"[DEBUG] netInstallConfigurationProfiles.sh path: %@", [netInstallConfigurationProfilesScriptURL path]);
                
                [additionalScriptsContent appendString:[NSString stringWithFormat:@"%@\n", [netInstallConfigurationProfilesScriptURL path]]];
            }
            
            if ( [additionalPackagesContent writeToURL:additionalPackagesURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                writeOSInstall = YES;
            } else {
                return NO;
            }
            
            if ( [additionalScriptsContent writeToURL:additionalScriptsURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                writeOSInstall = YES;
            } else {
                return NO;
            }
            
            if ( _packageOnly ) {
                if ( ! [@{} writeToURL:[_temporaryNBIURL URLByAppendingPathComponent:@"ASRInstall.mpkg"] atomically:YES] ) {
                    *error = [NBCError errorWithDescription:@"Writing ASRInstall.mpkg failed"];
                    return NO;
                }
            }
        }
        
        // -------------------------------------------------------------------------------
        //  If any additional content was added to NetInstall, write OSInstall.collection
        // -------------------------------------------------------------------------------
        if ( writeOSInstall ) {
            NSURL *osInstallURL = [_temporaryNBIURL URLByAppendingPathComponent:@"OSInstall.collection"];
            [temporaryItemsNBI addObject:osInstallURL];
            [(NSDictionary*)osInstallArray writeToURL:osInstallURL atomically:YES];
        }
    }
    
    [_workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    
    return YES;
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)prepareWorkflowPackageOnly {
    
    NSError *err = nil;
    NSArray *arguments;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [self setPackageOnlyScriptRun:NO];
    
    // --------------------------------------------------------
    //  Create arguments array for createRestoreFromSources.sh
    // --------------------------------------------------------
    NSArray *createRestoreFromSourcesArguments = [NBCWorkflowNBIController generateScriptArgumentsForCreateRestoreFromSources:_workflowItem];
    if ( [createRestoreFromSourcesArguments count] != 0 ) {
        [_workflowItem setScriptArguments:createRestoreFromSourcesArguments];
        arguments = createRestoreFromSourcesArguments;
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Creating script arguments for createRestoreFromSources.sh failed"] }];
        return;
    }
    
    // --------------------------------------------------------------
    //  Create environment variables for createRestoreFromSources.sh
    // --------------------------------------------------------------
    if ( ! [NBCWorkflowNBIController generateEnvironmentVariablesForCreateRestoreFromSources:_workflowItem] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Creating environment variables for createRestoreFromSources.sh failed"] }];
        return;
    }
    
    // --------------------------------
    //  Write InstallPreferences.plist
    // --------------------------------
    NSURL *installPreferencesPlistURL = [_temporaryNBIURL URLByAppendingPathComponent:@"InstallPreferences.plist"];
    DDLogDebug(@"[DEBUG] InstallPreferences.plist path: %@", [installPreferencesPlistURL path]);
    
    if ( ! [@{ @"packageOnlyMode" : @YES } writeToURL:installPreferencesPlistURL atomically:NO] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Writing InstallPreferences.plist failed"] }];
        return;
    }
    
    // --------------------------------
    //  Copy ASRInstall.pkg
    // --------------------------------
    NSURL *asrInstallPkgSourceURL = [[_workflowItem applicationSource] asrInstallPkgURL];
    DDLogDebug(@"[DEBUG] ASRInstall.pkg path: %@", [asrInstallPkgSourceURL path]);
    
    if ( [asrInstallPkgSourceURL checkResourceIsReachableAndReturnError:&err] ) {
        NSURL *asrInstallPkgTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[asrInstallPkgSourceURL lastPathComponent]];
        if ( ! [fm copyItemAtURL:asrInstallPkgSourceURL toURL:asrInstallPkgTargetURL error:&err] ) {
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Copying ASRInstall.pkg failed"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"ASRInstall.pkg doesn't exist"] }];
        return;
    }
    
    // --------------------------------
    //  Copy postInstallPackages.sh
    // --------------------------------
    NSURL *asrPostInstallPackagesURL = [[_workflowItem applicationSource] postInstallPackages];
    DDLogDebug(@"[DEBUG] postInstallPackages.sh path: %@", [asrPostInstallPackagesURL path]);
    
    if ( [asrPostInstallPackagesURL checkResourceIsReachableAndReturnError:&err] ) {
        NSURL *asrPostInstallPackagesTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[asrPostInstallPackagesURL lastPathComponent]];
        if ( ! [fm copyItemAtURL:asrPostInstallPackagesURL toURL:asrPostInstallPackagesTargetURL error:&err] ) {
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Copying postInstallPackages.sh failed"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"postInstallPackages.sh doesn't exist"] }];
        return;
    }
    
    // --------------------------------
    //  Copy reserveInstallLog.sh
    // --------------------------------
    NSURL *preserveInstallLogURL = [[_workflowItem applicationSource] preserveInstallLog];
    DDLogDebug(@"[DEBUG] reserveInstallLog.sh path: %@", [preserveInstallLogURL path]);
    
    if ( [preserveInstallLogURL checkResourceIsReachableAndReturnError:&err] ) {
        NSURL *preserveInstallLogTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[preserveInstallLogURL lastPathComponent]];
        if ( ! [fm copyItemAtURL:preserveInstallLogURL toURL:preserveInstallLogTargetURL error:&err] ) {
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Copying reserveInstallLog.sh failed"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"reserveInstallLog.sh doesn't exist"] }];
        return;
    }
    
    // --------------------------------
    //  Copy NetBootClientHelper
    // --------------------------------
    NSURL *netBootClientHelperURL = [[_workflowItem applicationSource] netBootClientHelper];
    DDLogDebug(@"[DEBUG] NetBootClientHelper path: %@", [netBootClientHelperURL path]);
    
    if ( [netBootClientHelperURL checkResourceIsReachableAndReturnError:&err] ) {
        NSURL *netBootClientHelperTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:[netBootClientHelperURL lastPathComponent]];
        if ( ! [fm copyItemAtURL:netBootClientHelperURL toURL:netBootClientHelperTargetURL error:&err] ) {
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Copying NetBootClientHelper failed"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"NetBootClientHelper doesn't exist"] }];
        return;
    }
    
    // --------------------------------
    //  Create buildCommands.sh
    // --------------------------------
    NSURL *buildCommandsTargetURL = [_temporaryNBIURL URLByAppendingPathComponent:@"buildCommands.sh"];
    DDLogDebug(@"[DEBUG] buildCommands.sh path: %@", [buildCommandsTargetURL path]);
    
    NSString *buildCommandsContent = [NSString stringWithFormat:@"'%@' \"%@\" \"/\" \"System\" || exit 1\n", [[[_workflowItem applicationSource] asrFromVolumeURL] path], [_temporaryNBIURL path]];
    if ( ! [buildCommandsContent writeToURL:buildCommandsTargetURL atomically:YES encoding:NSUTF8StringEncoding error:&err] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"NetBootClientHelper doesn't exist"] }];
        return;
    }
    
    // --------------------------------
    //  Create NBI
    // --------------------------------
    [self runWorkflowPackageOnlyWithArguments:arguments];
} // prepareWorkflowPackageOnly

- (void)runWorkflowPackageOnlyWithArguments:(NSArray *)arguments {
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:self];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
            });
        }] createRestoreFromSourcesWithArguments:arguments authorization:authData withReply:^(NSError *error, int terminationStatus) {
            if ( terminationStatus == 0 ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finalizeNBI];
                });
            } else {
                if ( ! self->_packageOnlyScriptRun ) {
                    DDLogDebug(@"[DEBUG] createRestoreFromSources.sh failed on first try, trying again...");
                    [self setPackageOnlyScriptRun:YES];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self runWorkflowPackageOnlyWithArguments:arguments];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
                    });
                }
            }
        }];
    });
} // runWorkflowPackageOnlyWithArguments

- (void)runWorkflowNetInstall {
    
    NSError *err = nil;
    NSArray *arguments;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // ------------------------------------------------------------------
    //  Check and set InstallESD disk image volume size for progress bar
    // ------------------------------------------------------------------
    DDLogInfo(@"Getting size of InstallESD disk image volume...");
    
    NSURL *installESDVolumeURL = [[_workflowItem source] installESDVolumeURL];
    DDLogDebug(@"[DEBUG] InstallESD disk image volume path: %@", [installESDVolumeURL path]);
    
    if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:&err] ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[installESDVolumeURL path] error:&err];
        if ( [volumeAttributes count] != 0 ) {
            double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
            DDLogDebug(@"[DEBUG] InstallESD disk image volume size: %f", maxSize);
            
            double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
            DDLogDebug(@"[DEBUG] InstallESD disk image volume free size: %f", freeSize);
            
            [self setNetInstallVolumeSize:( maxSize - freeSize )];
            DDLogDebug(@"[DEBUG] InstallESD disk image volume used size: %f", ( maxSize - freeSize ));
        } else {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"InstallESD disk image is not mounted"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create arguments array for createNetInstall.sh
    // -------------------------------------------------------------
    NSArray *createNetInstallArguments = [NBCWorkflowNBIController generateScriptArgumentsForCreateNetInstall:_workflowItem];
    if ( [createNetInstallArguments count] != 0 ) {
        [_workflowItem setScriptArguments:createNetInstallArguments];
        arguments = createNetInstallArguments;
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Creating script arguments for createNetInstall.sh failed"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create environment variables for createNetInstall.sh
    // -------------------------------------------------------------
    if ( ! [NBCWorkflowNBIController generateEnvironmentVariablesForCreateNetInstall:_workflowItem] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Creating environment variables for createNetInstall.sh failed"] }];
        return;
    }
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    // --------------------------------
    //  Create NBI
    // --------------------------------
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:self];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
            });
        }] createNetInstallWithArguments:arguments authorization:authData withReply:^(NSError *error, int terminationStatus) {
            if ( terminationStatus == 0 ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finalizeNBI];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
                });
            }
        }];
    });
} // runWorkflowNetInstall

- (void)finalizeNBI {
    
    DDLogInfo(@"Removing temporary items...");
    
    __block NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSArray *temporaryItemsNBI = [_workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        DDLogDebug(@"[DEBUG] Removing item at path: %@", [temporaryItemURL path]);
        
        if ( ! [fm removeItemAtURL:temporaryItemURL error:&error] ) {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
    
    // -------------------------------------------------------------
    //  Delete all items in NBI root except 'allowedItems'
    // -------------------------------------------------------------
    NSArray *allowedItems = @[ @"i386", @"NetInstall.dmg", @"NBImageInfo.plist" ];
    NSArray *nbiFolderContents = [fm contentsOfDirectoryAtURL:_temporaryNBIURL includingPropertiesForKeys:@[] options:0 error:&error];
    
    [nbiFolderContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
        NSString *filename = [obj lastPathComponent];
        if ( ! [allowedItems containsObject:filename] ) {
            DDLogDebug(@"[DEBUG] Removing item at path: %@", [obj path]);
            
            if ( ! [fm removeItemAtURL:obj error:&error] ) {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
        }
    }];
    
    // ------------------------
    //  Send workflow complete
    // ------------------------
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
} // finalizeNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)logStdOut:(NSString *)stdOutString {
    DDLogDebug(@"[DEBUG][stdout] %@", stdOutString);
    [self updateNetInstallWorkflowStatus:stdOutString];
} // logStdOut

- (void)updateNetInstallWorkflowStatus:(NSString *)outStr {
    
    // -------------------------------------------------------------
    //  Check if string begins with chosen prefix or with PERCENT:
    // -------------------------------------------------------------
    if ( [outStr hasPrefix:NBCWorkflowLogPrefix] ) {
        
        // ----------------------------------------------------------------------------------------------
        //  Check for build steps in output, then try to update UI with a meaningful message or progress
        // ----------------------------------------------------------------------------------------------
        NSString *buildStep = [outStr componentsSeparatedByString:@"_"][2];
        
        // -------------------------------------------------------------
        //  "creatingImage", update progress bar from PERCENT: output
        // -------------------------------------------------------------
        if ( [buildStep isEqualToString:@"creatingImage"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Creating disk image..." workflow:self];
            });
            
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
            [self setCopyComplete:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Preparing the kernel and boot loader for the boot image..." workflow:self];
                [self->_delegate updateProgressBar:55];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Performing post install cleanup..." workflow:self];
                [self->_delegate updateProgressBar:60];
            });
        }
        
        // ---------------------------------------------------------
        //  Read percent value from output and pass to progress bar
        // ---------------------------------------------------------
    } else if ( [outStr containsString:@"PERCENT:"] ) {
        NSString *progressPercentString = [outStr componentsSeparatedByString:@":"][1] ;
        double progressPercent = [progressPercentString doubleValue];
        if ( progressPercent <= 0 ) {
            return;
        }
        double precentage = (25 * progressPercent)/[@100 doubleValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Creating disk image... %d%%", (int)progressPercent] workflow:self];
            [self->_delegate updateProgressBar:precentage];
        });
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
            [self setNbiVolumePath:[[disk volumeURL] path]];
            
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
    NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:_nbiVolumePath error:&error];
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
            double precentage = (((25 * volumeCurrentSize)/_netInstallVolumeSize) + 25);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                [self->_delegate updateProgressBar:precentage];
            });
        }
    } else {
        [timer invalidate];
        timer = NULL;
        DDLogError(@"[ERROR] Could not get file attributes for volume: %@", _nbiVolumePath);
        DDLogError(@"[ERROR] %@", error);
    }
} // checkCopyProgress

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCWorkflowProgressDelegate (Required but unused/passed on)
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    [_delegate updateProgressStatus:statusMessage workflow:workflow];
}
- (void)updateProgressStatus:(NSString *)statusMessage {
    [_delegate updateProgressStatus:statusMessage];
}
- (void)updateProgressBar:(double)value {
    [_delegate updateProgressBar:value];
}
- (void)incrementProgressBar:(double)value {
    [_delegate incrementProgressBar:value];
}
- (void)logDebug:(NSString *)logMessage {
    [_delegate logDebug:logMessage];
}
- (void)logInfo:(NSString *)logMessage {
    [_delegate logInfo:logMessage];
}
- (void)logWarn:(NSString *)logMessage {
    [_delegate logWarn:logMessage];
}
- (void)logError:(NSString *)logMessage {
    [_delegate logError:logMessage];
}
- (void)logStdErr:(NSString *)stdErrString {
    [_delegate logStdErr:stdErrString];
}

@end
