//
//  NBCTargetController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCTargetController.h"

#import "NSString+randomString.h"
#import "NBCDiskImageController.h"
#import "NBCDisk.h"
#import "NBCConstants.h"
#import "NBCTarget.h"
#import "NBCWorkflowItem.h"
#import "NBCVariables.h"
#import "NBCImagrSettingsViewController.h"

@implementation NBCTargetController

- (BOOL)applyNBISettings:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
#pragma unused(error)
    BOOL verified = YES;
    NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
    
    NSMutableDictionary *nbImageInfoDict = [self getNBImageInfoDict:nbImageInfoURL nbiURL:nbiURL];
    if ( nbImageInfoDict ) {
        nbImageInfoDict = [self updateNBImageInfoDict:nbImageInfoDict nbImageInfoURL:nbImageInfoURL workflowItem:workflowItem];
        if ( nbImageInfoDict ) {
            if ( ! [nbImageInfoDict writeToURL:nbImageInfoURL atomically:NO] ) {
                NSLog(@"Could not write NBImageInfo.plist!");
                
                verified = NO;
            }
        } else {
            verified = NO;
            NSLog(@"nbImageInfoDict is nil 2!");
        }
    } else {
        verified = NO;
        NSLog(@"nbImageInfoDict is nil!");
    }
    
    // Update rc.install
    
    
    
    if ( verified ) {
        NSImage *nbiIcon = [workflowItem nbiIcon];
        if ( ! [self updateNBIIcon:nbiIcon nbiURL:nbiURL] ) {
            NSLog(@"Updating NBI Icon failed!");
            
            verified = NO;
        }
    }
    
    return verified;
}

- (NSMutableDictionary *)getNBImageInfoDict:(NSURL *)nbiImageInfoURL nbiURL:(NSURL *)nbiURL {
    NSMutableDictionary *nbImageInfoDict;
    
    if ( [nbiImageInfoURL checkResourceIsReachableAndReturnError:nil] ) {
        nbImageInfoDict = [[NSMutableDictionary alloc] initWithContentsOfURL:nbiImageInfoURL];
    } else {
        nbImageInfoDict = [self createDefaultNBImageInfoPlist:nbiURL];
    }
    
    return nbImageInfoDict;
}

- (NSMutableDictionary *)createDefaultNBImageInfoPlist:(NSURL *)nbiURL {
    NSMutableDictionary *nbImageInfoDict = [[NSMutableDictionary alloc] init];
    
    NSDictionary *platformSupport = [[NSDictionary alloc] initWithContentsOfURL:[nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"]];
    NSArray *disabledSystemIdentifiers = platformSupport[@"SupportedModelProperties"];
    disabledSystemIdentifiers = [disabledSystemIdentifiers sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    nbImageInfoDict[@"Architectures"] = @[ @"i386" ];
    nbImageInfoDict[@"BackwardCompatible"] = @NO;
    nbImageInfoDict[@"BootFile"] = @"booter";
    nbImageInfoDict[@"Description"] = @"";
    nbImageInfoDict[@"DisabledSystemIdentifiers"] = disabledSystemIdentifiers;
    nbImageInfoDict[@"EnabledSystemIdentifiers"] = @[];
    nbImageInfoDict[@"Index"] = @1;
    nbImageInfoDict[@"IsDefault"] = @NO;
    nbImageInfoDict[@"IsEnabled"] = @YES;
    nbImageInfoDict[@"IsInstall"] = @YES;
    nbImageInfoDict[@"Kind"] = @1;
    nbImageInfoDict[@"Language"] = @"Default";
    nbImageInfoDict[@"Name"] = @"";
    nbImageInfoDict[@"RootPath"] = @"NetInstall.dmg";
    nbImageInfoDict[@"SupportsDiskless"] = @NO;
    nbImageInfoDict[@"Type"] = @"HTTP";
    nbImageInfoDict[@"imageType"] = @"netinstall";
    nbImageInfoDict[@"osVersion"] = @"10.x";
    
    return nbImageInfoDict;
}

- (NSMutableDictionary *)updateNBImageInfoDict:(NSMutableDictionary *)nbImageInfoDict nbImageInfoURL:(NSURL *)nbImageInfoURL workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(nbImageInfoURL)
    NSMutableDictionary *newNBImageInfoDict = nbImageInfoDict;
    NSDictionary *workflowSettings = [workflowItem userSettings];
    NBCSource *source = [workflowItem source];
    id applicationSource = [workflowItem applicationSource];
    
    BOOL availabilityEnabled = NO;
    BOOL availabilityDefault = NO;
    NSString *nbiName;
    NSString *nbiDescription;
    NSString *nbiIndexString;
    NSString *nbiLanguage;
    NSString *nbiType;
    NSString *nbiOSVersion;
    
    availabilityEnabled = [workflowSettings[NBCSettingsNBIEnabled] boolValue];
    availabilityDefault = [workflowSettings[NBCSettingsNBIDefault] boolValue];
    nbiLanguage = workflowSettings[NBCSettingsNBILanguage];
    nbiType = workflowSettings[NBCSettingsNBIProtocol];
    nbiName = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIName]
                                     source:source
                          applicationSource:applicationSource];
    nbiDescription = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIDescription]
                                            source:source
                                 applicationSource:applicationSource];
    nbiIndexString = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIIndex]
                                            source:source
                                 applicationSource:applicationSource];
    
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *nbiIndex = [f numberFromString:nbiIndexString];
    
    NSString *variableString = @"%OSMAJOR%.%OSMINOR%";
    if ( source != nil ) {
        nbiOSVersion = [source expandVariables:variableString];
    }
    
    if ( newNBImageInfoDict ) {
        if ( @(availabilityEnabled) != nil ) {
            newNBImageInfoDict[@"IsEnabled"] = @(availabilityEnabled); }
        if ( @(availabilityDefault) != nil ) {
            newNBImageInfoDict[@"IsDefault"] = @(availabilityDefault); }
        if ( nbiLanguage != nil ) {
            if ( [nbiLanguage isEqualToString:@"Current"] ) {
                nbiLanguage = @"Default"; }
            newNBImageInfoDict[@"Language"] = nbiLanguage; }
        if ( nbiType != nil ) {
            newNBImageInfoDict[@"Type"] = nbiType; }
        if ( nbiDescription != nil ) {
            newNBImageInfoDict[@"Description"] = nbiDescription; }
        if ( nbiIndex != nil ) {
            newNBImageInfoDict[@"Index"] = nbiIndex; }
        if ( nbiName != nil ) {
            newNBImageInfoDict[@"Name"] = nbiName; }
        if ( nbiOSVersion != nil ) {
            newNBImageInfoDict[@"osVersion"] = nbiOSVersion; }
    }
    
    return newNBImageInfoDict;
}

- (BOOL)updateNBIIcon:(NSImage *)nbiIcon nbiURL:(NSURL *)nbiURL {
    BOOL verified = YES;
    
    if ( nbiIcon && nbiURL ) {
        if ( ! [[NSWorkspace sharedWorkspace] setIcon:nbiIcon forFile:[nbiURL path] options:0] ) {
            verified = NO;
        }
    } else {
        verified = NO;
    }
    
    return verified;
}

// ------------------------------------------------------
//  NetInstall
// ------------------------------------------------------

#pragma mark -
#pragma mark NetInstall
#pragma mark -

- (BOOL)attachNetInstallDiskImageWithShadowFile:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    BOOL verified = YES;
    
    NSString *shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    NSURL *nbiNetInstallVolumeURL;
    NSDictionary *nbiNetInstallDiskImageDict;
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowFilePath,
                                //@"-owners", @"on",
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    
    if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&nbiNetInstallDiskImageDict
                                                              dmgPath:netInstallDiskImageURL
                                                              options:hdiutilOptions
                                                                error:error] ) {
        if ( nbiNetInstallDiskImageDict ) {
            [target setNbiNetInstallDiskImageDict:nbiNetInstallDiskImageDict];
            nbiNetInstallVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:nbiNetInstallDiskImageDict];
            NBCDisk *nbiNetInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallDiskImageURL imageType:@"NetInstall"];
            
            if ( nbiNetInstallDisk ) {
                [target setNbiNetInstallDisk:nbiNetInstallDisk];
                [target setNbiNetInstallVolumeBSDIdentifier:[nbiNetInstallDisk BSDName]];
            } else {
                
                NSLog(@"No nbiNetInstallDisk");
                verified = NO;
            }
        } else {
            
            NSLog(@"No nbiNetInstallDiskImageDict");
            verified = NO;
        }
    } else {
        verified = NO;
        NSLog(@"Attach NBI NetInstall Failed");
    }
    
    if ( verified && nbiNetInstallVolumeURL != nil ) {
        [target setNbiNetInstallVolumeURL:nbiNetInstallVolumeURL];
        [target setNbiNetInstallShadowPath:shadowFilePath];
        
        NSURL *baseSystemURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
        } else {
            NSLog(@"Found No BaseSystem DMG!");
        }
    }
    
    return verified;
}

- (BOOL)convertNetInstallFromShadow:(NBCTarget *)target error:(NSError **)error {
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *netInstallURL = [target nbiNetInstallURL];
    NSString *netInstallShadowPath = [target nbiNetInstallShadowPath];
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiNetInstallVolumeURL path]] ) {
        if ( [NBCDiskImageController convertDiskImageAtPath:[netInstallURL path] shadowImagePath:netInstallShadowPath] ) {
            NSURL *nbiNetInstallSparseimageURL = [[netInstallURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"sparseimage"];
            
            if ( [fm removeItemAtURL:netInstallURL error:error] ) {
                if ( ! [fm moveItemAtURL:nbiNetInstallSparseimageURL toURL:netInstallURL error:error] ) {
                    NSLog(@"Move Error");
                }
            } else {
                NSLog(@"Delete Failed!");
            }
        }
    }
    
    if ( ! [fm removeItemAtPath:netInstallShadowPath error:error] ) {
        NSLog(@"Deleteing NetInstall shadow file failed!");
        NSLog(@"Error: %@", *error);
        
        verified = NO;
    }
    
    return verified;
}

// ------------------------------------------------------
//  BaseSystem
// ------------------------------------------------------

#pragma mark -
#pragma mark BaseSystem
#pragma mark -

- (BOOL)attachBaseSystemDiskImageWithShadowFile:(NSURL *)baseSystemDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    BOOL verified = YES;
    
    NSString *shadowFilePath = [target baseSystemShadowPath];
    if ( [shadowFilePath length] == 0 ) {
        shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    }
    NSURL *nbiBaseSystemVolumeURL;
    NSDictionary *nbiBaseSystemDiskImageDict;
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowFilePath,
                                @"-owners", @"on",
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    
    if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&nbiBaseSystemDiskImageDict
                                                              dmgPath:baseSystemDiskImageURL
                                                              options:hdiutilOptions
                                                                error:error] ) {
        if ( nbiBaseSystemDiskImageDict ) {
            [target setBaseSystemDiskImageDict:nbiBaseSystemDiskImageDict];
            nbiBaseSystemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:nbiBaseSystemDiskImageDict];
            NBCDisk *nbiBaseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL imageType:@"BaseSystem"];
            
            if ( nbiBaseSystemDisk ) {
                [target setNbiNetInstallDisk:nbiBaseSystemDisk];
                [target setNbiNetInstallVolumeBSDIdentifier:[nbiBaseSystemDisk BSDName]];
            } else {
                
                NSLog(@"No nbiBaseSystemDisk");
                verified = NO;
            }
        } else {
            
            NSLog(@"No nbiBaseSystemDiskImageDict");
            verified = NO;
        }
    } else {
        verified = NO;
        NSLog(@"Attach NBI Base System Failed!");
    }
    
    if ( verified && nbiBaseSystemVolumeURL != nil ) {
        [target setBaseSystemVolumeURL:nbiBaseSystemVolumeURL];
        [target setBaseSystemShadowPath:shadowFilePath];
    }
    
    return verified;
}

- (BOOL)convertBaseSystemFromShadow:(NBCTarget *)target error:(NSError **)error {
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *baseSystemURL = [target baseSystemURL];
    NSString *baseSystemShadowPath = [target baseSystemShadowPath];
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]] ) {
        if ( [NBCDiskImageController convertDiskImageAtPath:[baseSystemURL path] shadowImagePath:baseSystemShadowPath] ) {
            NSURL *nbiBaseSystemSparseimageURL = [[baseSystemURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"sparseimage"];
            
            if ( [fm removeItemAtURL:baseSystemURL error:error] ) {
                if ( ! [fm moveItemAtURL:nbiBaseSystemSparseimageURL toURL:baseSystemURL error:error] ) {
                    NSLog(@"Move Error");
                }
            } else {
                NSLog(@"Delete BaseSystem Failed!");
            }
        } else {
            NSLog(@"Converting BaseSystem Failed!");
        }
    } else {
        NSLog(@"Detaching BaseSystem Failed!");
    }
    
    if ( ! [fm removeItemAtPath:baseSystemShadowPath error:error] ) {
        NSLog(@"Deleteing BaseSystem shadow file failed!");
        NSLog(@"Error: %@", *error);
        
        verified = NO;
    }
    return verified;
}

// ------------------------------------------------------
//  Copy
// ------------------------------------------------------

#pragma mark -
#pragma mark Copy
#pragma mark -

- (BOOL)copyResourcesToVolume:(NSURL *)volumeURL resourcesDict:(NSDictionary *)resourcesDict target:(NBCTarget *)target  error:(NSError **)error {
#pragma unused(target)
    BOOL verified = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *blockVolumeURL = volumeURL;
    NSArray *copyArray = resourcesDict[NBCWorkflowCopy];
    
    for ( NSDictionary *copyDict in copyArray ) {
        
        NSLog(@"copyDict=%@", copyDict);
        NSString *copyType = copyDict[NBCWorkflowCopyType];
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            NSLog(@"targetURLString=%@", targetURLString);
            if ( [targetURLString length] != 0 ) {
                targetURL = [blockVolumeURL URLByAppendingPathComponent:targetURLString];
                NSLog(@"targetURL=%@", targetURL);
                if ( ! [[targetURL URLByDeletingLastPathComponent] checkResourceIsReachableAndReturnError:error] ) {
                    NSLog(@"Folder: %@ not found!", [targetURL URLByDeletingLastPathComponent]);
                    if ( ! [fileManager createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:error] ) {
                        NSLog(@"Could not create target folder: %@", [targetURL URLByDeletingLastPathComponent]);
                        continue;
                    }
                }
            } else {
                NSLog(@"Target URLString is empty!");
                verified = NO;
                return verified;
            }
            
            NSString *sourceURLString = copyDict[NBCWorkflowCopySourceURL];
            NSLog(@"sourceURLString=%@", sourceURLString);
            NSURL *sourceURL = [NSURL fileURLWithPath:sourceURLString];
            NSLog(@"sourceURL=%@", sourceURL);
            
            if ( [fileManager copyItemAtURL:sourceURL toURL:targetURL error:error] ) {
                NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
                
                if ( ! [fileManager setAttributes:attributes ofItemAtPath:[targetURL path] error:error] ) {
                    NSLog(@"Changing file permissions failed on file: %@", [targetURL path]);
                }
            } else {
                NSLog(@"Copy Resource Failed!");
                NSLog(@"Error: %@", *error);
                
                verified = NO;
            }
        } else if ( [copyType isEqualToString:NBCWorkflowCopyRegex] ) {
            NSString *sourceFolderPath = copyDict[NBCWorkflowCopyRegexSourceFolderURL];
            NSLog(@"sourceFolderPath=%@", sourceFolderPath);
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                               [NSString stringWithFormat:@"/usr/bin/find -E . -depth -regex '%@' | /usr/bin/cpio -admp --quiet '%@'", regexString, [volumeURL path]],
                                               nil];
            NSLog(@"scriptArguments=%@", scriptArguments);
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
            
            NSTask *newTask = [[NSTask alloc] init];
            
            [newTask setLaunchPath:[commandURL path]];
            [newTask setArguments:scriptArguments];
            
            if ( [sourceFolderPath length] != 0 ) {
                [newTask setCurrentDirectoryPath:sourceFolderPath];
            }
            
            
            [newTask setStandardOutput:stdOutFileHandle];
            [newTask setStandardError:stdErrFileHandle];
            
            [newTask launch];
            [newTask waitUntilExit];
            
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
        }
    }
    
    return verified;
}

- (void)modifySettingsForVNC:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteManagement.plist
    // --------------------------------------------------------------
    NSURL *remoteManagementURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteManagement.plist"];
    NSMutableDictionary *remoteManagementDict;
    NSDictionary *remoteManagementAttributes;
    if ( [remoteManagementURL checkResourceIsReachableAndReturnError:nil] ) {
        remoteManagementDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteManagementURL];
        remoteManagementAttributes = [fm attributesOfItemAtPath:[remoteManagementURL path] error:&error];
    }
    
    if ( [remoteManagementDict count] == 0 ) {
        remoteManagementDict = [[NSMutableDictionary alloc] init];
        remoteManagementAttributes = @{
                                       NSFileOwnerAccountName : @"root",
                                       NSFileGroupOwnerAccountName : @"wheel",
                                       NSFilePosixPermissions : @0644
                                       };
    }
    
    remoteManagementDict[@"ARD_AllLocalUsers"] = @YES;
    remoteManagementDict[@"ARD_AllLocalUsersPrivs"] = @-1073741569;
    remoteManagementDict[@"DisableKerberos"] = @NO;
    remoteManagementDict[@"ScreenSharingReqPermEnabled"] = @NO;
    remoteManagementDict[@"VNCLegacyConnectionsEnabled"] = @YES;
    
    NSDictionary *modifyDictRemoteManagement = @{
                                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                 NBCWorkflowModifyContent : remoteManagementDict,
                                                 NBCWorkflowModifyAttributes : remoteManagementAttributes,
                                                 NBCWorkflowModifyTargetURL : [remoteManagementURL path]
                                                 };
    
    [modifyDictArray addObject:modifyDictRemoteManagement];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.screensharing.plist
    // --------------------------------------------------------------
    NSURL *screensharingLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.screensharing.plist"];
    NSMutableDictionary *screensharingLaunchDaemonDict;
    NSDictionary *screensharingLaunchDaemonAttributes;
    if ( [screensharingLaunchDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
        screensharingLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingLaunchDaemonURL];
        screensharingLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingLaunchDaemonURL path] error:&error];
    } else {
        NSLog(@"This should exist, if not, something went Wrong!");
        NSLog(@"Error: %@", error);
    }
    
    screensharingLaunchDaemonDict[@"UserName"] = @"root";
    screensharingLaunchDaemonDict[@"GroupName"] = @"wheel";
    
    NSDictionary *modifyDictScreensharingLaunchDaemon = @{
                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                          NBCWorkflowModifyContent : screensharingLaunchDaemonDict,
                                                          NBCWorkflowModifyTargetURL : [screensharingLaunchDaemonURL path],
                                                          NBCWorkflowModifyAttributes : screensharingLaunchDaemonAttributes
                                                          };
    
    [modifyDictArray addObject:modifyDictScreensharingLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopPrivilegeProxyDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist"];
    NSMutableDictionary *remoteDesktopPrivilegeProxyLaunchDaemonDict;
    NSDictionary *remoteDesktopPrivilegeProxyLaunchDaemonAttributes;
    if ( [remoteDesktopPrivilegeProxyDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
        remoteDesktopPrivilegeProxyLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopPrivilegeProxyDaemonURL];
        remoteDesktopPrivilegeProxyLaunchDaemonAttributes = [fm attributesOfItemAtPath:[remoteDesktopPrivilegeProxyDaemonURL path] error:&error];
    } else {
        NSLog(@"This should exist, if not, something went Wrong!");
        NSLog(@"Error: %@", error);
    }
    
    remoteDesktopPrivilegeProxyLaunchDaemonDict[@"UserName"] = @"root";
    remoteDesktopPrivilegeProxyLaunchDaemonDict[@"GroupName"] = @"wheel";
    
    NSDictionary *modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon = @{
                                                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                                        NBCWorkflowModifyContent : remoteDesktopPrivilegeProxyLaunchDaemonDict,
                                                                        NBCWorkflowModifyTargetURL : [remoteDesktopPrivilegeProxyDaemonURL path],
                                                                        NBCWorkflowModifyAttributes : remoteDesktopPrivilegeProxyLaunchDaemonAttributes
                                                                        };
    
    [modifyDictArray addObject:modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.agent.plist
    // --------------------------------------------------------------
    NSURL *screensharingAgentDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.agent.plist"];
    NSMutableDictionary *screensharingAgentLaunchDaemonDict;
    NSDictionary *screensharingAgentLaunchDaemonAttributes;
    if ( [screensharingAgentDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
        screensharingAgentLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingAgentDaemonURL];
        screensharingAgentLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:&error];
    } else {
        NSLog(@"This should exist, if not, something went Wrong!");
        NSLog(@"Error: %@", error);
    }
    
    screensharingAgentLaunchDaemonDict[@"RunAtLoad"] = @YES;
    [screensharingAgentLaunchDaemonDict removeObjectForKey:@"LimitLoadToSessionType"];
    
    NSDictionary *modifyDictScreensharingAgentLaunchDaemon = @{
                                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                               NBCWorkflowModifyContent : screensharingAgentLaunchDaemonDict,
                                                               NBCWorkflowModifyTargetURL : [screensharingAgentDaemonURL path],
                                                               NBCWorkflowModifyAttributes : screensharingAgentLaunchDaemonAttributes
                                                               };
    
    [modifyDictArray addObject:modifyDictScreensharingAgentLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist
    // --------------------------------------------------------------
    NSURL *screensharingMessagesAgentDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist"];
    NSMutableDictionary *screensharingMessagesAgentLaunchAgentDict;
    NSDictionary *screensharingMessagesAgentLaunchAgentAttributes;
    if ( [screensharingMessagesAgentDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
        screensharingMessagesAgentLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingMessagesAgentDaemonURL];
        screensharingMessagesAgentLaunchAgentAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:&error];
    } else {
        NSLog(@"This should exist, if not, something went Wrong!");
        NSLog(@"Error: %@", error);
    }
    
    screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;
    
    NSDictionary *modifyDictScreensharingMessagesAgentLaunchAgent = @{
                                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                                      NBCWorkflowModifyContent : screensharingMessagesAgentLaunchAgentDict,
                                                                      NBCWorkflowModifyTargetURL : [screensharingMessagesAgentDaemonURL path],
                                                                      NBCWorkflowModifyAttributes : screensharingMessagesAgentLaunchAgentAttributes
                                                                      };
    
    [modifyDictArray addObject:modifyDictScreensharingMessagesAgentLaunchAgent];
    
    // --------------------------------------------------------------
    //  /etc/com.apple.screensharing.agent.launchd
    // --------------------------------------------------------------
    NSURL *etcScreensharingAgentLaunchdURL = [volumeURL URLByAppendingPathComponent:@"etc/com.apple.screensharing.agent.launchd"];
    NSString *etcScreensharingAgentLaunchdContentString = @"enabled\n";
    NSData *etcScreensharingAgentLaunchdContentData = [etcScreensharingAgentLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *etcScreensharingAgentLaunchdAttributes = @{
                                                             NSFileOwnerAccountName : @"root",
                                                             NSFileGroupOwnerAccountName : @"wheel",
                                                             NSFilePosixPermissions : @0644
                                                             };
    
    NSDictionary *modifyEtcScreensharingAgentLaunchd = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                         NBCWorkflowModifyContent : etcScreensharingAgentLaunchdContentData,
                                                         NBCWorkflowModifyTargetURL : [etcScreensharingAgentLaunchdURL path],
                                                         NBCWorkflowModifyAttributes : etcScreensharingAgentLaunchdAttributes
                                                         };
    
    [modifyDictArray addObject:modifyEtcScreensharingAgentLaunchd];
    
    // --------------------------------------------------------------
    //  /etc/RemoteManagement.launchd
    // --------------------------------------------------------------
    NSURL *etcRemoteManagementLaunchdURL = [volumeURL URLByAppendingPathComponent:@"etc/RemoteManagement.launchd"];
    NSString *etcRemoteManagementLaunchdContentString = @"enabled\n";
    NSData *etcRemoteManagementLaunchdContentData = [etcRemoteManagementLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *etcRemoteManagementLaunchdAttributes = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644
                                                           };
    
    NSDictionary *modifyEtcRemoteManagementLaunchd = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                       NBCWorkflowModifyContent : etcRemoteManagementLaunchdContentData,
                                                       NBCWorkflowModifyTargetURL : [etcRemoteManagementLaunchdURL path],
                                                       NBCWorkflowModifyAttributes : etcRemoteManagementLaunchdAttributes
                                                       };
    
    [modifyDictArray addObject:modifyEtcRemoteManagementLaunchd];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.RemoteDesktop.plist"];
    NSMutableDictionary *remoteDesktopLaunchAgentDict;
    NSDictionary *remoteDesktopLaunchAgentAttributes;
    if ( [remoteDesktopDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
        remoteDesktopLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopDaemonURL];
        remoteDesktopLaunchAgentAttributes = [fm attributesOfItemAtPath:[remoteDesktopDaemonURL path] error:&error];
    } else {
        NSLog(@"This should exist, if not, something went Wrong!");
        NSLog(@"Error: %@", error);
    }
    
    [remoteDesktopLaunchAgentDict removeObjectForKey:@"LimitLoadToSessionType"];
    
    NSDictionary *modifyDictRemoteDesktopLaunchAgent = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                         NBCWorkflowModifyContent : remoteDesktopLaunchAgentDict,
                                                         NBCWorkflowModifyTargetURL : [remoteDesktopDaemonURL path],
                                                         NBCWorkflowModifyAttributes : remoteDesktopLaunchAgentAttributes
                                                         };
    
    [modifyDictArray addObject:modifyDictRemoteDesktopLaunchAgent];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteDesktop.plist"];
    NSMutableDictionary *remoteDesktopDict;
    NSDictionary *remoteDesktopAttributes;
    if ( [remoteDesktopURL checkResourceIsReachableAndReturnError:nil] ) {
        remoteDesktopDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopURL];
        remoteDesktopAttributes = [fm attributesOfItemAtPath:[remoteDesktopURL path] error:&error];
    }
    
    if ( [remoteDesktopDict count] == 0 ) {
        remoteDesktopDict = [[NSMutableDictionary alloc] init];
        remoteDesktopAttributes = @{
                                    NSFileOwnerAccountName : @"root",
                                    NSFileGroupOwnerAccountName : @"wheel",
                                    NSFilePosixPermissions : @0644
                                    };
    }
    
    NSArray *restrictedFeaturesList = @[
                                        @NO,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @YES,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        @NO,
                                        ];
    
    remoteDesktopDict[@"DOCAllowRemoteConnections"] = @NO;
    remoteDesktopDict[@"RestrictedFeatureList"] = restrictedFeaturesList;
    remoteDesktopDict[@"Text1"] = @"";
    remoteDesktopDict[@"Text2"] = @"";
    remoteDesktopDict[@"Text3"] = @"";
    remoteDesktopDict[@"Text4"] = @"";
    
    NSDictionary *modifyDictRemoteDesktop = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                              NBCWorkflowModifyContent : remoteDesktopDict,
                                              NBCWorkflowModifyTargetURL : [remoteDesktopURL path],
                                              NBCWorkflowModifyAttributes : remoteDesktopAttributes
                                              };
    
    [modifyDictArray addObject:modifyDictRemoteDesktop];
}

- (void)modifyNBIRemoveWiFi:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    NSURL *wifiKext = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    NSDictionary *modifyWifiKext = @{
                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                     NBCWorkflowModifyTargetURL : [wifiKext path]
                                     };
    
    [modifyDictArray addObject:modifyWifiKext];
}

- (void)modifyNBINTP:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    
    // --------------------------------------------------------------
    //  /etc/ntp.conf
    // --------------------------------------------------------------
    
    NSString *ntpServer = [workflowItem userSettings][NBCSettingsNetworkTimeServerKey];
    if ( [ntpServer length] == 0 )
    {
        ntpServer = NBCNetworkTimeServerDefault;
    }
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/dig"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @"+short",
                            ntpServer,
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskStandardOutputData = [[[newTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] == 0 ) {
        NSString *digOutput = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
        if ( [digOutput length] != 0 )
        {
            NSArray *ntpServerArray = [digOutput componentsSeparatedByString:@"\n"];
            ntpServer = [NSString stringWithFormat:@"server %@", ntpServer];
            for ( NSString *ntpIP in ntpServerArray )
            {
                ntpServer = [ntpServer stringByAppendingString:[NSString stringWithFormat:@"\nserver %@", ntpIP]];
            }
        } else {
            NSLog(@"Could not resolve ntp server");
            // Add to warning report!
        }
    } else {
        NSLog(@"ERROR! Could not get output from dig!");
    }
    
    NSURL *ntpConfURL = [volumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];
    NSData *ntpConfContentData = [ntpServer dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *ntpConfAttributes = @{
                                        NSFileOwnerAccountName : @"root",
                                        NSFileGroupOwnerAccountName : @"wheel",
                                        NSFilePosixPermissions : @0644
                                        };
    
    NSDictionary *modifyNtpConf = @{
                                    NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                    NBCWorkflowModifyContent : ntpConfContentData,
                                    NBCWorkflowModifyTargetURL : [ntpConfURL path],
                                    NBCWorkflowModifyAttributes : ntpConfAttributes
                                    };
    
    [modifyDictArray addObject:modifyNtpConf];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    
    NSURL *wifiKext = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    NSDictionary *modifyWifiKext = @{
                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                     NBCWorkflowModifyTargetURL : [wifiKext path]
                                     };
    
    [modifyDictArray addObject:modifyWifiKext];
}

- (void)modifySettingsAddFolders:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    
    // --------------------------------------------------------------
    //  /Library/Caches
    // --------------------------------------------------------------
    NSURL *folderLibraryCache = [volumeURL URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES];
    
    NSDictionary *folderLibraryCacheAttributes = @{
                                                   NSFileOwnerAccountName : @"root",
                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                   NSFilePosixPermissions : @0755
                                                   };
    
    NSDictionary *modifyFolderLibraryCache = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                               NBCWorkflowModifyTargetURL : [folderLibraryCache path],
                                               NBCWorkflowModifyAttributes : folderLibraryCacheAttributes
                                               };
    
    [modifyDictArray addObject:modifyFolderLibraryCache];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches
    // --------------------------------------------------------------
    
    NSURL *folderSystemLibraryCache = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches" isDirectory:YES];
    
    NSDictionary *folderSystemLibraryCacheAttributes = @{
                                                         NSFileOwnerAccountName : @"root",
                                                         NSFileGroupOwnerAccountName : @"wheel",
                                                         NSFilePosixPermissions : @0755
                                                         };
    
    NSDictionary *modifyFolderSystemLibraryCache = @{
                                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                     NBCWorkflowModifyTargetURL : [folderSystemLibraryCache path],
                                                     NBCWorkflowModifyAttributes : folderSystemLibraryCacheAttributes
                                                     };
    
    [modifyDictArray addObject:modifyFolderSystemLibraryCache];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.CVMS
    // --------------------------------------------------------------
    
    NSURL *folderSystemLibraryCVMS = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.CVMS" isDirectory:YES];
    
    NSDictionary *folderSystemLibraryCVMSAttributes = @{
                                                        NSFileOwnerAccountName : @"root",
                                                        NSFileGroupOwnerAccountName : @"wheel",
                                                        NSFilePosixPermissions : @0755
                                                        };
    
    NSDictionary *modifyFolderSystemLibraryCVMS = @{
                                                    NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                    NBCWorkflowModifyTargetURL : [folderSystemLibraryCVMS path],
                                                    NBCWorkflowModifyAttributes : folderSystemLibraryCVMSAttributes
                                                    };
    
    [modifyDictArray addObject:modifyFolderSystemLibraryCVMS];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.kext.caches/Directories/System/Library/Extensions
    // --------------------------------------------------------------
    
    NSURL *folderSystemLibraryKextExtensions = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Directories/System/Library/Extensions" isDirectory:YES];
    
    NSDictionary *folderSystemLibraryKextExtensionsAttributes = @{
                                                                  NSFileOwnerAccountName : @"root",
                                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                                  NSFilePosixPermissions : @0755
                                                                  };
    
    NSDictionary *modifyFolderSystemLibraryKextExtensions = @{
                                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                              NBCWorkflowModifyTargetURL : [folderSystemLibraryKextExtensions path],
                                                              NBCWorkflowModifyAttributes : folderSystemLibraryKextExtensionsAttributes
                                                              };
    
    [modifyDictArray addObject:modifyFolderSystemLibraryKextExtensions];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.kext.caches/Startup
    // --------------------------------------------------------------
    
    NSURL *folderSystemLibraryKextStartup = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup" isDirectory:YES];
    
    NSDictionary *folderSystemLibraryKextStartupAttributes = @{
                                                               NSFileOwnerAccountName : @"root",
                                                               NSFileGroupOwnerAccountName : @"wheel",
                                                               NSFilePosixPermissions : @0755
                                                               };
    
    NSDictionary *modifyFolderSystemLibraryKextStartup = @{
                                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                           NBCWorkflowModifyTargetURL : [folderSystemLibraryKextStartup path],
                                                           NBCWorkflowModifyAttributes : folderSystemLibraryKextStartupAttributes
                                                           };
    
    [modifyDictArray addObject:modifyFolderSystemLibraryKextStartup];
}

- (BOOL)verifyNetInstallFromDiskImageURL:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    BOOL verified = NO;
    NSURL *netInstallVolumeURL;
    
    [target setNbiNetInstallURL:netInstallDiskImageURL];
    NBCDisk *netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallDiskImageURL
                                                                         imageType:@"NetInstall"];
    if ( netInstallDisk != nil ) {
        [target setNbiNetInstallDisk:netInstallDisk];
        [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
        netInstallVolumeURL = [netInstallDisk volumeURL];
        
        verified = YES;
    } else {
        NSDictionary *netInstallDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist"
                                    ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&netInstallDiskImageDict
                                                                  dmgPath:netInstallDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( netInstallDiskImageDict ) {
                [target setNbiNetInstallDiskImageDict:netInstallDiskImageDict];
                netInstallVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:netInstallDiskImageDict];
                netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallVolumeURL
                                                                            imageType:@"NetInstall"];
                if ( netInstallDisk ) {
                    [target setNbiNetInstallDisk:netInstallDisk];
                    [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
                    [netInstallDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                } else {
                    NSLog(@"No Install ESD Disk");
                }
            } else {
                NSLog(@"No Install ESD Dict");
            }
        } else {
            NSLog(@"Attach Failed");
        }
    }
    
    if ( verified && netInstallVolumeURL != nil ) {
        [target setNbiNetInstallVolumeURL:netInstallVolumeURL];
        
        NSURL *baseSystemURL = [netInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
        } else {
            verified = NO;
            NSLog(@"Found no BaseSystem.dmg!");
        }
    }
    
    return verified;
}

- (BOOL)verifyBaseSystemFromTarget:(NBCTarget *)target source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *baseSystemDiskImageURL = [target baseSystemURL];
    NSURL *baseSystemVolumeURL;
    
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk != nil ) {
        [target setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        
        verified = YES;
    } else {
        NSDictionary *baseSystemImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist"
                                    ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&baseSystemImageDict
                                                                  dmgPath:baseSystemDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( baseSystemImageDict ) {
                [target setBaseSystemDiskImageDict:baseSystemImageDict];
                baseSystemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:baseSystemImageDict];
                baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                            imageType:@"BaseSystem"];
                if ( baseSystemDisk ) {
                    [target setBaseSystemDisk:baseSystemDisk];
                    [target setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
                    [baseSystemDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                } else {
                    NSLog(@"No Base System Disk");
                }
            } else {
                NSLog(@"No Base System Image Dict");
            }
        } else {
            NSLog(@"Base System Attach failed");
        }
    }
    
    if ( verified && baseSystemVolumeURL != nil ) {
        [target setBaseSystemVolumeURL:baseSystemVolumeURL];
        
        NSURL *systemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] == YES ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( systemVersionPlist != nil ) {
                NSString *baseSystemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                
                if ( baseSystemOSVersion != nil ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                } else {
                    NSLog(@"Unable to read osVersion from SystemVersion.plist");
                    verified = NO;
                }
                
                NSString *baseSystemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                
                if ( baseSystemOSBuild != nil ) {
                    [source setBaseSystemOSBuild:baseSystemOSBuild];
                    [source setSourceBuild:baseSystemOSBuild];
                } else {
                    NSLog(@"Unable to read osBuild from SystemVersion.plist");
                }
            } else {
                NSLog(@"No SystemVersion Dict");
                
                verified = NO;
            }
        } else {
            NSLog(@"No SystemVersion Plist");
            
            verified = NO;
        }
    }
    
    return verified;
}

@end
