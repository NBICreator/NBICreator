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
#import "NBCLogging.h"
#import "ServerInformationComputerModelInfo.h"

DDLogLevel ddLogLevel;

@implementation NBCTargetController

- (BOOL)applyNBISettings:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
#pragma unused(error)
    DDLogInfo(@"Configuring NBImageInfo.plist...");
    BOOL verified = YES;
    NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
    NSMutableDictionary *nbImageInfoDict = [self getNBImageInfoDict:nbImageInfoURL nbiURL:nbiURL];
    if ( [nbImageInfoDict count] != 0 ) {
        nbImageInfoDict = [self updateNBImageInfoDict:nbImageInfoDict nbImageInfoURL:nbImageInfoURL workflowItem:workflowItem];
        if ( [nbImageInfoDict count] != 0 ) {
            if ( ! [nbImageInfoDict writeToURL:nbImageInfoURL atomically:NO] ) {
                DDLogError(@"[ERROR] Could not write NBImageInfo.plist!");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] nbImageInfoDict is empty!");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] nbImageInfoDict is empty!");
        verified = NO;
    }
    
    // Update rc.install
    
    if ( verified ) {
        NSImage *nbiIcon = [workflowItem nbiIcon];
        if ( ! [self updateNBIIcon:nbiIcon nbiURL:nbiURL] ) {
            DDLogError(@"[ERROR] Updating NBI Icon failed!");
            verified = NO;
        }
    }
    
    return verified;
} // applyNBISettings

- (NSMutableDictionary *)getNBImageInfoDict:(NSURL *)nbiImageInfoURL nbiURL:(NSURL *)nbiURL {
    DDLogInfo(@"Getting NBImageInfo.plist...");
    NSMutableDictionary *nbImageInfoDict;
    
    if ( [nbiImageInfoURL checkResourceIsReachableAndReturnError:nil] ) {
        nbImageInfoDict = [[NSMutableDictionary alloc] initWithContentsOfURL:nbiImageInfoURL];
    } else {
        nbImageInfoDict = [self createDefaultNBImageInfoPlist:nbiURL];
    }
    
    return nbImageInfoDict;
} // getNBImageInfoDict:nbiURL

- (NSMutableDictionary *)createDefaultNBImageInfoPlist:(NSURL *)nbiURL {
    DDLogInfo(@"Creating Default NBImageInfo.plist...");
    NSMutableDictionary *nbImageInfoDict = [[NSMutableDictionary alloc] init];
    NSArray *disabledSystemIdentifiers;
    NSDictionary *platformSupportDict;
    NSURL *platformSupportURL = [nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
    if ( platformSupportURL ) {
        platformSupportDict = [[NSDictionary alloc] initWithContentsOfURL:platformSupportURL];
    } else {
        DDLogWarn(@"[WARN] Could not find PlatformSupport.plist on source!");
    }
    
    if ( [platformSupportDict count] != 0 ) {
        disabledSystemIdentifiers = platformSupportDict[@"SupportedModelProperties"];
        if ( [disabledSystemIdentifiers count] != 0 ) {
            disabledSystemIdentifiers = [disabledSystemIdentifiers sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
        } else {
            DDLogWarn(@"[WARN] DisabledSystemIdentifiers was empty");
        }
    }
    
    nbImageInfoDict[@"Architectures"] = @[ @"i386" ];
    nbImageInfoDict[@"BackwardCompatible"] = @NO;
    nbImageInfoDict[@"BootFile"] = @"booter";
    nbImageInfoDict[@"Description"] = @"";
    nbImageInfoDict[@"DisabledSystemIdentifiers"] = disabledSystemIdentifiers ?: @[];
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
} // createDefaultNBImageInfoPlist

- (NSMutableDictionary *)updateNBImageInfoDict:(NSMutableDictionary *)nbImageInfoDict nbImageInfoURL:(NSURL *)nbImageInfoURL workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(nbImageInfoURL)
    DDLogInfo(@"Updating NBImageInfo.plist...");
    
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
    NSArray *supportedBoardIds;
    NSArray *supportedModelProperties;
    NSMutableArray *disabledSystemIdentifiers = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *newNBImageInfoDict = nbImageInfoDict;
    if ( [newNBImageInfoDict count] == 0 ) {
        DDLogError(@"[ERROR] NBImageInfo.plist is empty!");
        return nil;
    }
    
    NSDictionary *workflowSettings = [workflowItem userSettings];
    if ( [newNBImageInfoDict count] == 0 ) {
        DDLogError(@"[ERROR] workflowSettings are empty!");
        return nil;
    }
    
    [disabledSystemIdentifiers addObjectsFromArray:newNBImageInfoDict[@"DisabledSystemIdentifiers"]];
    NSDictionary *platformSupportDict;
    NSURL *platformSupportURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
    if ( platformSupportURL ) {
        platformSupportDict = [[NSDictionary alloc] initWithContentsOfURL:platformSupportURL];
    } else {
        DDLogWarn(@"[WARN] Could not find PlatformSupport.plist on source!");
    }
    
    if ( [platformSupportDict count] != 0 ) {
        supportedBoardIds = platformSupportDict[@"SupportedBoardIds"] ?: @[];
        supportedModelProperties = platformSupportDict[@"SupportedModelProperties"] ?: @[];
    }
    
    if ( [supportedModelProperties count] != 0 ) {
        [disabledSystemIdentifiers addObjectsFromArray:supportedModelProperties];
    }
    
    if ( [supportedBoardIds count] != 0 ) {
        NSArray *modelIDsFromBoardIDs = [ServerInformationComputerModelInfo modelPropertiesForBoardIDs:supportedBoardIds];
        if ( [modelIDsFromBoardIDs count] != 0 ) {
            [disabledSystemIdentifiers addObjectsFromArray:modelIDsFromBoardIDs];
        }
    }
    
    NSArray *newDisabledSystemIdentifiers = [[disabledSystemIdentifiers copy] valueForKeyPath:@"@distinctUnionOfObjects.self"];
    
    availabilityEnabled = [workflowSettings[NBCSettingsEnabledKey] boolValue];
    availabilityDefault = [workflowSettings[NBCSettingsDefaultKey] boolValue];
    
    nbiLanguage = workflowSettings[NBCSettingsLanguageKey];
    if ( [nbiLanguage length] == 0 ) {
        DDLogError(@"[ERROR] Language setting is empty!");
        return nil;
    }
    
    nbiType = workflowSettings[NBCSettingsProtocolKey];
    if ( [nbiType length] == 0 ) {
        DDLogError(@"[ERROR] Protocol setting is empty!");
        return nil;
    }
    
    nbiName = [NBCVariables expandVariables:workflowSettings[NBCSettingsNameKey]
                                     source:source
                          applicationSource:applicationSource];
    
    if ( [nbiName length] == 0 ) {
        DDLogError(@"[ERROR] NBI name setting is empty!");
        return nil;
    }
    nbiDescription = [NBCVariables expandVariables:workflowSettings[NBCSettingsDescriptionKey]
                                            source:source
                                 applicationSource:applicationSource];
    
    nbiIndexString = [NBCVariables expandVariables:workflowSettings[NBCSettingsIndexKey]
                                            source:source
                                 applicationSource:applicationSource];
    
    if ( [nbiName length] == 0 ) {
        DDLogError(@"[ERROR] NBI index setting is empty!");
        return nil;
    }
    
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *nbiIndex = [f numberFromString:nbiIndexString];
    
    NSString *variableString = @"%OSMAJOR%.%OSMINOR%";
    if ( source != nil ) {
        nbiOSVersion = [source expandVariables:variableString];
    }
    
    if ( newNBImageInfoDict ) {
        newNBImageInfoDict[@"IsEnabled"] = @(availabilityEnabled) ?: @NO;
        newNBImageInfoDict[@"DisabledSystemIdentifiers"] = [newDisabledSystemIdentifiers sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]?: @[];
        newNBImageInfoDict[@"IsDefault"] = @(availabilityDefault) ?: @NO;
        if ( [nbiLanguage isEqualToString:@"Current"] ) {
            nbiLanguage = @"Default";
        }
        newNBImageInfoDict[@"Language"] = nbiLanguage ?: @"Default";
        newNBImageInfoDict[@"Type"] = nbiType ?: @"NFS";
        newNBImageInfoDict[@"Description"] = nbiDescription ?: @"";
        newNBImageInfoDict[@"Index"] = nbiIndex ?: @1;
        newNBImageInfoDict[@"Name"] = nbiName ?: @"";
        newNBImageInfoDict[@"osVersion"] = nbiOSVersion ?: @"10.x";
    } else {
        DDLogError(@"[ERROR] newNBImageInfoDict is nil!");
    }
    
    return newNBImageInfoDict;
} // updateNBImageInfoDict:

- (NSArray *)updateSupportedModelIDs:(NSArray *)currentSupportedModelIDs supportedBoardIDs:(NSArray *)supportedBoardIDs {
    NSMutableArray *newSupportedModelIDs = [NSMutableArray arrayWithArray:currentSupportedModelIDs];
    NSURL *boardIDtoModelIDURL = [NSURL fileURLWithPath:@""];
    if ( boardIDtoModelIDURL ) {
        NSDictionary *boardIDtoModelIDDict = [NSDictionary dictionaryWithContentsOfURL:boardIDtoModelIDURL];
        if ( [supportedBoardIDs count] != 0 ) {
            for ( NSString *boardID in supportedBoardIDs ) {
                NSString *modelID = boardIDtoModelIDDict[boardID];
                if ( [modelID length] != 0 && ! [newSupportedModelIDs containsObject:modelID] ) {
                    DDLogInfo(@"Adding ModelID %@ from supportedBoardIDs", modelID);
                    [newSupportedModelIDs addObject:modelID];
                }
            }
        }
    }
    
    return [newSupportedModelIDs copy];
}

- (BOOL)updateNBIIcon:(NSImage *)nbiIcon nbiURL:(NSURL *)nbiURL {
    DDLogInfo(@"Setting NBI Icon...");
    BOOL verified = YES;
    if ( nbiIcon && nbiURL ) {
        if ( ! [[NSWorkspace sharedWorkspace] setIcon:nbiIcon forFile:[nbiURL path] options:0] ) {
            DDLogError(@"[ERROR] Setting NBI Icon Failed!");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Icon or Icon URL is empty!");
        verified = NO;
    }
    
    return verified;
} // updateNBIIcon

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NetInstall
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)attachNetInstallDiskImageWithShadowFile:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    DDLogInfo(@"Attaching NetInstall image with shadow file...");
    BOOL verified = YES;
    NSURL *nbiNetInstallVolumeURL;
    NSDictionary *nbiNetInstallDiskImageDict;
    
    NSString *shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowFilePath,
                                @"-owners", @"on", // Possibly comment out?
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
            if ( nbiNetInstallVolumeURL ) {
                NBCDisk *nbiNetInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallDiskImageURL imageType:@"NetInstall"];
                
                if ( nbiNetInstallDisk ) {
                    [target setNbiNetInstallDisk:nbiNetInstallDisk];
                    [target setNbiNetInstallVolumeBSDIdentifier:[nbiNetInstallDisk BSDName]];
                } else {
                    DDLogError(@"[ERROR] Could not get nbiNetInstallDisk!");
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] NetInstall volume url is empty!");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] No info dict returned from hdiutil");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Attach NBI NetInstall failed");
        verified = NO;
    }
    
    if ( verified && nbiNetInstallVolumeURL != nil ) {
        [target setNbiNetInstallVolumeURL:nbiNetInstallVolumeURL];
        [target setNbiNetInstallShadowPath:shadowFilePath];
        
        NSURL *baseSystemURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
        } else {
            DDLogError(@"[ERROR] Found No BaseSystem DMG!");
            verified = NO;
        }
    }
    
    return verified;
} // attachNetInstallDiskImageWithShadowFile:target:error

- (BOOL)convertNetInstallFromShadow:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    DDLogInfo(@"Converting NetInstall.dmg and shadow file...");
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NBCTarget *target = [workflowItem target];
    
    NSURL *netInstallURL = [target nbiNetInstallURL];
    NSString *netInstallShadowPath = [target nbiNetInstallShadowPath];
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiNetInstallVolumeURL path]] ) {
        NSString *diskImageExtension;
        NSString *diskImageFormat;
        if ( [[workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            diskImageExtension = @"sparseimage";
            diskImageFormat = NBCDiskImageFormatSparseImage;
        } else {
            diskImageExtension = @"dmg";
            diskImageFormat = NBCDiskImageFormatReadOnly;
        }
        NSURL *nbiNetInstallConvertedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.%@", [netInstallURL URLByDeletingPathExtension], diskImageFormat, diskImageExtension]];
        if ( [NBCDiskImageController convertDiskImageAtPath:[netInstallURL path] shadowImagePath:netInstallShadowPath format:diskImageFormat destinationPath:[nbiNetInstallConvertedURL path]] ) {
            if ( [fm removeItemAtURL:netInstallURL error:error] ) {
                netInstallURL = [[netInstallURL URLByDeletingPathExtension] URLByAppendingPathExtension:diskImageExtension];
                if ( ! [fm moveItemAtURL:nbiNetInstallConvertedURL toURL:netInstallURL error:error] ) {
                    DDLogError(@"[ERROR] Could not move image to NBI");
                    DDLogError(@"%@", *error);
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] Delete temporary NetInstall Failed!");
                DDLogError(@"%@", *error);
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] Converting NetInstall Failed!");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Detaching NetInstall Failed!");
        verified = NO;
    }
    
    if ( ! [fm removeItemAtPath:netInstallShadowPath error:error] ) {
        DDLogError(@"[ERROR] Deleteing NetInstall shadow file failed!");
        DDLogError(@"%@", *error);
        verified = NO;
    }
    
    return verified;
} // convertNetInstallFromShadow:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark BaseSystem
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)attachBaseSystemDiskImageWithShadowFile:(NSURL *)baseSystemDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    DDLogInfo(@"Attaching BaseSystem image with shadow file...");
    BOOL verified = YES;
    NSURL *nbiBaseSystemVolumeURL;
    NSDictionary *nbiBaseSystemDiskImageDict;
    
    NSString *shadowFilePath = [target baseSystemShadowPath];
    if ( [shadowFilePath length] == 0 ) {
        shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    }
    
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
            if ( nbiBaseSystemVolumeURL ) {
                NBCDisk *nbiBaseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL imageType:@"BaseSystem"];
                
                if ( nbiBaseSystemDisk ) {
                    [target setNbiNetInstallDisk:nbiBaseSystemDisk];
                    [target setNbiNetInstallVolumeBSDIdentifier:[nbiBaseSystemDisk BSDName]];
                } else {
                    DDLogError(@"[ERROR] Could not get nbiBaseSystemDisk!");
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] BaseSystem volume url is empty!");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] No info dict returned from hdiutil");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Attach NBI BaseSystem failed");
        verified = NO;
    }
    
    if ( verified && nbiBaseSystemVolumeURL != nil ) {
        [target setBaseSystemVolumeURL:nbiBaseSystemVolumeURL];
        [target setBaseSystemShadowPath:shadowFilePath];
    }
    
    return verified;
} // attachBaseSystemDiskImageWithShadowFile

- (BOOL)convertBaseSystemFromShadow:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    DDLogInfo(@"Converting BaseSystem.dmg and shadow file...");
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *baseSystemURL = [[workflowItem target] baseSystemURL];
    NSString *baseSystemShadowPath = [[workflowItem target] baseSystemShadowPath];
    NSURL *nbiBaseSystemVolumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]] ) {
        NSString *diskImageExtension;
        NSString *diskImageFormat;
        if ( [[workflowItem userSettings][NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            diskImageFormat = NBCDiskImageFormatSparseImage;
            diskImageExtension = @"sparseimage";
        } else {
            diskImageFormat = NBCDiskImageFormatReadOnly;
            diskImageExtension = @"dmg";
        }
        NSURL *nbiBaseSystemConvertedURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.%@", [baseSystemURL URLByDeletingPathExtension], diskImageFormat, diskImageExtension]];
        if ( [NBCDiskImageController convertDiskImageAtPath:[baseSystemURL path] shadowImagePath:baseSystemShadowPath format:diskImageFormat destinationPath:[nbiBaseSystemConvertedURL path]] ) {
            if ( [fm removeItemAtURL:baseSystemURL error:error] ) {
                baseSystemURL = [[baseSystemURL URLByDeletingPathExtension] URLByAppendingPathExtension:diskImageExtension];
                if ( [fm moveItemAtURL:nbiBaseSystemConvertedURL toURL:baseSystemURL error:error] ) {
                    [[workflowItem target] setBaseSystemURL:baseSystemURL];
                } else {
                    DDLogError(@"[ERROR] Could not move image to NBI");
                    DDLogError(@"%@", *error);
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] Delete temporary BaseSystem Failed!");
                DDLogError(@"%@", *error);
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] Converting BaseSystem Failed!");
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Detaching BaseSystem Failed!");
        verified = NO;
    }
    
    if ( ! [fm removeItemAtPath:baseSystemShadowPath error:error] ) {
        DDLogError(@"[ERROR] Deleteing BaseSystem shadow file failed!");
        DDLogError(@"%@", *error);
        verified = NO;
    }
    
    return verified;
} // convertBaseSystemFromShadow:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Copy
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)copyResourcesToVolume:(NSURL *)volumeURL resourcesDict:(NSDictionary *)resourcesDict target:(NBCTarget *)target  error:(NSError **)error {
#pragma unused(target)
    DDLogInfo(@"Copying resources to volume...");
    BOOL verified = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *blockVolumeURL = volumeURL;
    NSArray *copyArray = resourcesDict[NBCWorkflowCopy];
    for ( NSDictionary *copyDict in copyArray ) {
        NSString *copyType = copyDict[NBCWorkflowCopyType];
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            if ( [targetURLString length] != 0 ) {
                targetURL = [blockVolumeURL URLByAppendingPathComponent:targetURLString];
                if ( ! [[targetURL URLByDeletingLastPathComponent] checkResourceIsReachableAndReturnError:error] ) {
                    if ( ! [fileManager createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:error] ) {
                        DDLogError(@"[ERROR] Could not create target folder: %@", [targetURL URLByDeletingLastPathComponent]);
                        DDLogError(@"%@", *error);
                        return NO;
                    }
                }
            } else {
                DDLogError(@"[ERROR] Target URLString is empty!");
                return NO;
            }
            
            NSString *sourceURLString = copyDict[NBCWorkflowCopySourceURL];
            NSURL *sourceURL = [NSURL fileURLWithPath:sourceURLString];
            
            if ( [fileManager copyItemAtURL:sourceURL toURL:targetURL error:error] ) {
                NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
                if ( ! [fileManager setAttributes:attributes ofItemAtPath:[targetURL path] error:error] ) {
                    DDLogError(@"[ERROR] Changing file permissions failed on file: %@", [targetURL path]);
                    DDLogError(@"%@", *error);
                }
            } else {
                DDLogError(@"[ERROR] Copy Resource Failed!");
                DDLogError(@"%@", *error);
                verified = NO;
            }
        } else if ( [copyType isEqualToString:NBCWorkflowCopyRegex] ) {
            NSString *sourceFolderPath = copyDict[NBCWorkflowCopyRegexSourceFolderURL];
            if ( [sourceFolderPath length] == 0 ) {
                DDLogError(@"[ERROR] sourceFolderPath is empty!");
                return NO;
            }
            
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            if ( [regexString length] == 0 ) {
                DDLogError(@"[ERROR] regexString is empty!");
                return NO;
            }
            
            NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                               [NSString stringWithFormat:@"/usr/bin/find -E . -depth -regex '%@' | /usr/bin/cpio -admp --quiet '%@'", regexString, [volumeURL path]],
                                               nil];
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
                                                DDLogError(@"%@", errStr);
                                                
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
            
            // THIS SHOULD BE MOVED TO HELPER PROBABLY!
            
            [newTask launch];
            [newTask waitUntilExit];
            
            if ( [newTask terminationStatus] != 0 ) {
                DDLogError(@"[ERROR] ");
                verified = NO;
            }
            
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
        }
    }
    
    return verified;
}

- (BOOL)settingsToRemove:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    //NSError *error;
    //NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.FMM_recovery.plist
    // --------------------------------------------------------------
    NSURL *findmydevicedFMMRecoverySettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.FMM_recovery.plist"];
    NSDictionary *modifyFindmydevicedFMMRecoverySettings = @{
                                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                             NBCWorkflowModifyTargetURL : [findmydevicedFMMRecoverySettingsURL path]
                                                             };
    [modifyDictArray addObject:modifyFindmydevicedFMMRecoverySettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.webcontentfilter.RecoveryOS.plist
    // --------------------------------------------------------------
    NSURL *webcontentfilterRecoverySettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.webcontentfilter.RecoveryOS.plist"];
    NSDictionary *modifyWebcontentfilterRecoverySettings = @{
                                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                             NBCWorkflowModifyTargetURL : [webcontentfilterRecoverySettingsURL path]
                                                             };
    [modifyDictArray addObject:modifyWebcontentfilterRecoverySettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.VoiceOver.plist
    // --------------------------------------------------------------
    NSURL *voiceoverSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.VoiceOver.plist"];
    NSDictionary *modifyVoiceoverSettings = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                              NBCWorkflowModifyTargetURL : [voiceoverSettingsURL path]
                                              };
    [modifyDictArray addObject:modifyVoiceoverSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.sbd.plist
    // --------------------------------------------------------------
    NSURL *sbdSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.sbd.plist"];
    NSDictionary *modifySbdSettings = @{
                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                        NBCWorkflowModifyTargetURL : [sbdSettingsURL path]
                                        };
    [modifyDictArray addObject:modifySbdSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.scrod.plist
    // --------------------------------------------------------------
    NSURL *scrodSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.scrod.plist"];
    NSDictionary *modifyScrodSettings = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                          NBCWorkflowModifyTargetURL : [scrodSettingsURL path]
                                          };
    [modifyDictArray addObject:modifyScrodSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.tccd.system.plist
    // --------------------------------------------------------------
    NSURL *tccdSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.tccd.system.plist"];
    NSDictionary *modifyTccdSettings = @{
                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                         NBCWorkflowModifyTargetURL : [tccdSettingsURL path]
                                         };
    [modifyDictArray addObject:modifyTccdSettings];
    
    return retval;
}

- (BOOL)modifySettingsForFindMyDeviced:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    //NSError *error;
    //NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist
    // --------------------------------------------------------------
    NSURL *findmydevicedSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist"];
    NSDictionary *modifyFindmydevicedSettings = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                  NBCWorkflowModifyTargetURL : [findmydevicedSettingsURL path]
                                                  };
    [modifyDictArray addObject:modifyFindmydevicedSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.findmymac.plist
    // --------------------------------------------------------------
    NSURL *findmymacSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.findmymac.plist"];
    NSDictionary *modifyFindmymacSettings = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                              NBCWorkflowModifyTargetURL : [findmymacSettingsURL path]
                                              };
    [modifyDictArray addObject:modifyFindmymacSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.findmymacmessenger.plist
    // --------------------------------------------------------------
    NSURL *findmymacmessengerSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.findmymacmessenger.plist"];
    NSDictionary *modifyFindmymacMessengerSettings = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                       NBCWorkflowModifyTargetURL : [findmymacmessengerSettingsURL path]
                                                       };
    [modifyDictArray addObject:modifyFindmymacMessengerSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/PrivateFrameworks/FindMyDevice.framework
    // --------------------------------------------------------------
    NSURL *findmydeviceFrameworkURL = [volumeURL URLByAppendingPathComponent:@"System/Library/PrivateFrameworks/FindMyDevice.framework"];
    NSDictionary *modifyFindmydeviceFramework = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                  NBCWorkflowModifyTargetURL : [findmydeviceFrameworkURL path]
                                                  };
    [modifyDictArray addObject:modifyFindmydeviceFramework];
    
    // --------------------------------------------------------------
    //  /System/Library/PrivateFrameworks/FindMyMac.framework
    // --------------------------------------------------------------
    NSURL *findmymacFrameworkURL = [volumeURL URLByAppendingPathComponent:@"System/Library/PrivateFrameworks/FindMyMac.framework"];
    NSDictionary *modifyFindmymacFramework = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                               NBCWorkflowModifyTargetURL : [findmymacFrameworkURL path]
                                               };
    [modifyDictArray addObject:modifyFindmymacFramework];
    
    /*
     // --------------------------------------------------------------
     //  /System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist
     // --------------------------------------------------------------
     NSURL *findmydevicedSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist"];
     DDLogDebug(@"findmydevicedSettingsURL=%@", findmydevicedSettingsURL);
     NSDictionary *findmydevicedSettingsAttributes;
     NSMutableDictionary *findmydevicedSettingsDict;
     if ( [findmydevicedSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
     findmydevicedSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:findmydevicedSettingsURL];
     findmydevicedSettingsAttributes = [fm attributesOfItemAtPath:[findmydevicedSettingsURL path] error:&error];
     }
     
     if ( [findmydevicedSettingsDict count] == 0 ) {
     findmydevicedSettingsDict = [[NSMutableDictionary alloc] init];
     findmydevicedSettingsAttributes = @{
     NSFileOwnerAccountName : @"root",
     NSFileGroupOwnerAccountName : @"wheel",
     NSFilePosixPermissions : @0644
     };
     }
     DDLogDebug(@"findmydevicedSettingsDict=%@", findmydevicedSettingsDict);
     DDLogDebug(@"findmydevicedSettingsAttributes=%@", findmydevicedSettingsAttributes);
     findmydevicedSettingsDict[@"RunAtLoad"] = @NO;
     findmydevicedSettingsDict[@"Disabled"] = @YES;
     [findmydevicedSettingsDict removeObjectForKey:@"KeepAlive"];
     DDLogDebug(@"findmydevicedSettingsDict=%@", findmydevicedSettingsDict);
     NSDictionary *modifyFindmydevicedSettings = @{
     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
     NBCWorkflowModifyContent : findmydevicedSettingsDict,
     NBCWorkflowModifyAttributes : findmydevicedSettingsAttributes,
     NBCWorkflowModifyTargetURL : [findmydevicedSettingsURL path]
     };
     DDLogDebug(@"modifyFindmydevicedSettings=%@", modifyFindmydevicedSettings);
     [modifyDictArray addObject:modifyFindmydevicedSettings];
     */
    return retval;
} // modifySettingsForSystemKeychain:workflowItem

- (BOOL)modifySettingsForBootPlist:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [workflowItem temporaryNBIURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // ---------------------------------------------------------------
    //  /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
    // ---------------------------------------------------------------
    NSURL *bootSettingsURL = [volumeURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    NSDictionary *bootSettingsAttributes;
    NSMutableDictionary *bootSettingsDict;
    if ( [bootSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        bootSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:bootSettingsURL];
        bootSettingsAttributes = [fm attributesOfItemAtPath:[bootSettingsURL path] error:&error];
    }
    
    if ( [bootSettingsDict count] == 0 ) {
        bootSettingsDict = [[NSMutableDictionary alloc] init];
        bootSettingsAttributes = @{
                                   NSFileOwnerAccountName : @"root",
                                   NSFileGroupOwnerAccountName : @"wheel",
                                   NSFilePosixPermissions : @0644
                                   };
    }
    if ( [bootSettingsDict[@"Kernel Flags"] length] != 0 ) {
        NSString *currentKernelFlags = bootSettingsDict[@"Kernel Flags"];
        bootSettingsDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ -v", currentKernelFlags];
    } else {
        bootSettingsDict[@"Kernel Flags"] = @"-v";
    }
    
    NSDictionary *modifyBootSettings = @{
                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                         NBCWorkflowModifyContent : bootSettingsDict,
                                         NBCWorkflowModifyAttributes : bootSettingsAttributes,
                                         NBCWorkflowModifyTargetURL : [bootSettingsURL path]
                                         };
    [modifyDictArray addObject:modifyBootSettings];
    
    return retval;
} // modifySettingsForBootPlist

- (BOOL)modifySettingsForSystemKeychain:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Library/Security/Trust Settings
    // --------------------------------------------------------------
    NSURL *folderLibrarySecurityTrustSettings = [volumeURL URLByAppendingPathComponent:@"Library/Security/Trust Settings" isDirectory:YES];
    NSDictionary *folderLibrarySecurityTrustSettingsAttributes = @{
                                                                   NSFileOwnerAccountName : @"root",
                                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                                   NSFilePosixPermissions : @0755
                                                                   };
    
    NSDictionary *modifyFolderLibrarySecurityTrustSettings = @{
                                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                               NBCWorkflowModifyTargetURL : [folderLibrarySecurityTrustSettings path],
                                                               NBCWorkflowModifyAttributes : folderLibrarySecurityTrustSettingsAttributes
                                                               };
    [modifyDictArray addObject:modifyFolderLibrarySecurityTrustSettings];
    
    // --------------------------------------------------------------
    //  /Library/Security/Trust Settings/Admin.plist
    // --------------------------------------------------------------
    NSURL *systemKeychainTrustSettingsURL = [volumeURL URLByAppendingPathComponent:@"Library/Security/Trust Settings/Admin.plist"];
    NSDictionary *systemKeychainTrustSettingsAttributes;
    NSMutableDictionary *systemKeychainTrustSettingsDict;
    if ( [systemKeychainTrustSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        systemKeychainTrustSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:systemKeychainTrustSettingsURL];
        systemKeychainTrustSettingsAttributes = [fm attributesOfItemAtPath:[systemKeychainTrustSettingsURL path] error:&error];
    }
    
    if ( [systemKeychainTrustSettingsDict count] == 0 ) {
        systemKeychainTrustSettingsDict = [[NSMutableDictionary alloc] init];
        systemKeychainTrustSettingsAttributes = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0600
                                                  };
    }
    
    systemKeychainTrustSettingsDict[@"trustList"] = @{};
    systemKeychainTrustSettingsDict[@"trustVersion"] = @1;
    NSDictionary *modifyDictSystemKeychainTrustSettings = @{
                                                            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                            NBCWorkflowModifyContent : systemKeychainTrustSettingsDict,
                                                            NBCWorkflowModifyAttributes : systemKeychainTrustSettingsAttributes,
                                                            NBCWorkflowModifyTargetURL : [systemKeychainTrustSettingsURL path]
                                                            };
    [modifyDictArray addObject:modifyDictSystemKeychainTrustSettings];
    
    return retval;
} // modifySettingsForSystemKeychain:workflowItem

- (NSNumber *)keyboardLayoutIDFromSourceID:(NSString *)sourceID {
#pragma unused(sourceID)
    NSNumber *keyboardLayoutID;
    keyboardLayoutID = [NSNumber numberWithInt:7];
    return keyboardLayoutID;
} // keyboardLayoutIDFromSourceID

- (BOOL)modifySettingsForKextd:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Adding language and keyboard settings...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // ------------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.kextd.plist
    // ------------------------------------------------------------------
    NSDictionary *kextdLaunchDaemonAttributes;
    NSMutableDictionary *kextdLaunchDaemonDict;
    NSURL *kextdLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.kextd.plist"];
    
    if ( [kextdLaunchDaemonURL checkResourceIsReachableAndReturnError:nil] ) {
        kextdLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:kextdLaunchDaemonURL];
        kextdLaunchDaemonAttributes = [fm attributesOfItemAtPath:[kextdLaunchDaemonURL path] error:&error];
    }
    
    if ( [kextdLaunchDaemonDict count] == 0 ) {
        kextdLaunchDaemonDict = [[NSMutableDictionary alloc] init];
        kextdLaunchDaemonAttributes = @{
                                        NSFileOwnerAccountName : @"root",
                                        NSFileGroupOwnerAccountName : @"wheel",
                                        NSFilePosixPermissions : @0644
                                        };
    }
    
    NSMutableArray *kextdProgramArguments = [NSMutableArray arrayWithArray:kextdLaunchDaemonDict[@"ProgramArguments"]];
    [kextdProgramArguments addObject:@"-no-caches"];
    kextdLaunchDaemonDict[@"ProgramArguments"] = kextdProgramArguments;
    
    NSDictionary *modifyKextdLauncDaemon = @{
                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                             NBCWorkflowModifyContent : kextdLaunchDaemonDict,
                                             NBCWorkflowModifyAttributes : kextdLaunchDaemonAttributes,
                                             NBCWorkflowModifyTargetURL : [kextdLaunchDaemonURL path]
                                             };
    [modifyDictArray addObject:modifyKextdLauncDaemon];
    
    return retval;
} // modifySettingsForKextd:workflowItem

- (BOOL)modifyRCInstall:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(modifyDictArray)
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // ------------------------------------------------------------------
    //  /etc/rc.install
    // ------------------------------------------------------------------
    NSDictionary *rcInstallAttributes;
    NSMutableString *rcInstallContentString = [[NSMutableString alloc] init];
    NSString *rcInstallContentStringOriginal;
    NSURL *rcInstallURL = [volumeURL URLByAppendingPathComponent:@"etc/rc.install"];
    if ( [rcInstallURL checkResourceIsReachableAndReturnError:nil] ) {
        rcInstallContentStringOriginal = [NSMutableString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:&error];
        rcInstallAttributes = [fm attributesOfItemAtPath:[rcInstallURL path] error:&error];
    }
    
    if ( [rcInstallContentStringOriginal length] != 0 ) {
        
        NSArray *rcInstallContentArray = [rcInstallContentStringOriginal componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for ( NSString *line in rcInstallContentArray ) {
            if ( [line containsString:@"/System/Library/CoreServices/Installer\\ Progress.app"] ) {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"#%@\n", line]];
            } else {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"%@\n", line]];
            }
        }
        
        NSData *rcInstallData = [rcInstallContentString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *modifyRcInstall = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                          NBCWorkflowModifyContent : rcInstallData,
                                          NBCWorkflowModifyAttributes : rcInstallAttributes,
                                          NBCWorkflowModifyTargetURL : [rcInstallURL path]
                                          };
        [modifyDictArray addObject:modifyRcInstall];
    } else {
        retval = NO;
    }
    return retval;
}

- (BOOL)modifySettingsForDesktopViewer:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Adding language and keyboard settings...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    NSDictionary *resourceSettings = [workflowItem resourcesSettings];
    DDLogDebug(@"resourceSettings=%@", resourceSettings);
    
    // ------------------------------------------------------------------
    //  /Library/Desktop Pictures/...
    // ------------------------------------------------------------------
    NSDictionary *hiToolboxPreferencesAttributes;
    NSMutableDictionary *hiToolboxPreferencesDict;
    
    NSString *desktopPictureDefaultPath;
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    switch (sourceVersionMinor) {
        case 11:
            desktopPictureDefaultPath = @"Library/Desktop Pictures/El Capitan.jpg";
            break;
        case 10:
            desktopPictureDefaultPath = @"Library/Desktop Pictures/Yosemite.jpg";
            break;
        case 9:
            desktopPictureDefaultPath = @"Library/Desktop Pictures/Wave.jpg";
            break;
        case 8:
            desktopPictureDefaultPath = @"Library/Desktop Pictures/Galaxy.jpg";
            break;
        case 7:
            desktopPictureDefaultPath = @"Library/Desktop Pictures/Lion.jpg";
            break;
        default:
            break;
    }
    
    NSURL *desktopPictureSourceURL = [volumeURL URLByAppendingPathComponent:desktopPictureDefaultPath];
    NSURL *desktopPictureTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/DefaultDesktop.jpg"];
    
    if ( [desktopPictureSourceURL checkResourceIsReachableAndReturnError:nil] ) {
        hiToolboxPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:desktopPictureSourceURL];
        hiToolboxPreferencesAttributes = [fm attributesOfItemAtPath:[desktopPictureSourceURL path] error:&error];
    }
    
    if ( [hiToolboxPreferencesDict count] == 0 ) {
        hiToolboxPreferencesDict = [[NSMutableDictionary alloc] init];
        hiToolboxPreferencesAttributes = @{
                                           NSFileOwnerAccountName : @"root",
                                           NSFileGroupOwnerAccountName : @"wheel",
                                           NSFilePosixPermissions : @0644
                                           };
    }
    
    NSDictionary *modifyDesktopPicture = @{
                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                           NBCWorkflowModifySourceURL : [desktopPictureSourceURL path],
                                           NBCWorkflowModifyTargetURL : [desktopPictureTargetURL path]
                                           };
    [modifyDictArray addObject:modifyDesktopPicture];
    
    return retval;
}

- (BOOL)modifySettingsForLanguageAndKeyboardLayout:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Adding language and keyboard settings...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    NSDictionary *resourceSettings = [workflowItem resourcesSettings];
    
    // ------------------------------------------------------------------
    //  /Library/Preferences/com.apple.HIToolbox.plist (Keyboard Layout)
    // ------------------------------------------------------------------
    NSDictionary *hiToolboxPreferencesAttributes;
    NSMutableDictionary *hiToolboxPreferencesDict;
    NSURL *hiToolboxPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.HIToolbox.plist"];
    
    if ( [hiToolboxPreferencesURL checkResourceIsReachableAndReturnError:nil] ) {
        hiToolboxPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:hiToolboxPreferencesURL];
        hiToolboxPreferencesAttributes = [fm attributesOfItemAtPath:[hiToolboxPreferencesURL path] error:&error];
    }
    
    if ( [hiToolboxPreferencesDict count] == 0 ) {
        hiToolboxPreferencesDict = [[NSMutableDictionary alloc] init];
        hiToolboxPreferencesAttributes = @{
                                           NSFileOwnerAccountName : @"root",
                                           NSFileGroupOwnerAccountName : @"wheel",
                                           NSFilePosixPermissions : @0644
                                           };
    }
    
    NSString *selectedKeyboardLayoutSourceID = resourceSettings[NBCSettingsKeyboardLayoutID];
    NSString *selectedKeyboardName = resourceSettings[NBCSettingsKeyboardLayoutKey];
    NSNumber *keyboardLayoutID = [self keyboardLayoutIDFromSourceID:selectedKeyboardLayoutSourceID];
    NSDictionary *keyboardDict = @{
                                   @"InputSourceKind" : @"Keyboard Layout",
                                   @"KeyboardLayout ID" : keyboardLayoutID,
                                   @"KeyboardLayout Name" : selectedKeyboardName
                                   };
    
    hiToolboxPreferencesDict[@"AppleCurrentKeyboardLayoutInputSourceID"] = selectedKeyboardLayoutSourceID;
    hiToolboxPreferencesDict[@"AppleDefaultAsciiInputSource"] = keyboardDict;
    hiToolboxPreferencesDict[@"AppleEnabledInputSources"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleInputSourceHistory"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleSelectedInputSources"] = @[ keyboardDict ];
    
    NSDictionary *modifyDictHiToolboxPreferences = @{
                                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                     NBCWorkflowModifyContent : hiToolboxPreferencesDict,
                                                     NBCWorkflowModifyAttributes : hiToolboxPreferencesAttributes,
                                                     NBCWorkflowModifyTargetURL : [hiToolboxPreferencesURL path]
                                                     };
    [modifyDictArray addObject:modifyDictHiToolboxPreferences];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/.GlobalPreferences.plist (Language)
    // --------------------------------------------------------------
    NSURL *globalPreferencesRootURL = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/.GlobalPreferences.plist"];
    NSURL *globalPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
    NSMutableDictionary *globalPreferencesDict;
    NSDictionary *globalPreferencesAttributes;
    if ( [globalPreferencesURL checkResourceIsReachableAndReturnError:nil] ) {
        globalPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:globalPreferencesURL];
        globalPreferencesAttributes = [fm attributesOfItemAtPath:[globalPreferencesURL path] error:&error];
    }
    
    if ( [globalPreferencesDict count] == 0 ) {
        globalPreferencesDict = [[NSMutableDictionary alloc] init];
        globalPreferencesAttributes = @{
                                        NSFileOwnerAccountName : @"root",
                                        NSFileGroupOwnerAccountName : @"wheel",
                                        NSFilePosixPermissions : @0644
                                        };
    }
    
    NSString *selectedLanguage = resourceSettings[NBCSettingsLanguageKey];
    
    globalPreferencesDict[@"AppleLanguages"] = @[
                                                 selectedLanguage,
                                                 ];
    
    if ( [resourceSettings[NBCSettingsCountry] length] != 0 ) {
        globalPreferencesDict[@"Country"] = resourceSettings[NBCSettingsCountry];
    } else if ( [globalPreferencesDict[@"AppleLocale"] containsString:@"_"] ) {
        globalPreferencesDict[@"Country"] = [globalPreferencesDict[@"AppleLocale"] componentsSeparatedByString:@"_"][2];
    }
    
    if ( [resourceSettings[NBCSettingsLocale] length] != 0 ) {
        globalPreferencesDict[@"AppleLocale"] = resourceSettings[NBCSettingsLocale];
    } else {
        globalPreferencesDict[@"AppleLocale"] = selectedLanguage;
    }
    
    NSDictionary *modifyDictGlobalPreferences = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                  NBCWorkflowModifyContent : globalPreferencesDict,
                                                  NBCWorkflowModifyAttributes : globalPreferencesAttributes,
                                                  NBCWorkflowModifyTargetURL : [globalPreferencesURL path]
                                                  };
    [modifyDictArray addObject:modifyDictGlobalPreferences];
    
    NSDictionary *modifyDictGlobalPreferencesRoot = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                      NBCWorkflowModifyContent : globalPreferencesDict,
                                                      NBCWorkflowModifyAttributes : globalPreferencesAttributes,
                                                      NBCWorkflowModifyTargetURL : [globalPreferencesRootURL path]
                                                      };
    [modifyDictArray addObject:modifyDictGlobalPreferencesRoot];
    
    // --------------------------------------------------------------
    //  /private/var/log/CDIS.custom (Setup Assistant Language)
    // --------------------------------------------------------------
    NSURL *csdisURL = [volumeURL URLByAppendingPathComponent:@"private/var/log/CDIS.custom"];
    NSString *canonicalLanguage = [NSLocale canonicalLanguageIdentifierFromString:selectedLanguage];
    if ( [canonicalLanguage length] != 0 ) {
        NSData *cdisContentData = [canonicalLanguage dataUsingEncoding:NSUTF8StringEncoding];
        
        NSDictionary *cdisAttributes = @{
                                         NSFileOwnerAccountName : @"root",
                                         NSFileGroupOwnerAccountName : @"wheel",
                                         NSFilePosixPermissions : @0644
                                         };
        
        NSDictionary *modifyCdis = @{
                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                     NBCWorkflowModifyContent : cdisContentData,
                                     NBCWorkflowModifyTargetURL : [csdisURL path],
                                     NBCWorkflowModifyAttributes : cdisAttributes
                                     };
        [modifyDictArray addObject:modifyCdis];
    }
    return retval;
} // modifySettingsForLanguageAndKeyboardLayout

- (BOOL)modifySettingsForImagr:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Applications/Imagr.app/Contents/Info.plist
    // --------------------------------------------------------------
    NSURL *imagrInfoPlistURL = [volumeURL URLByAppendingPathComponent:@"Applications/Imagr.app/Contents/Info.plist"];
    NSMutableDictionary *imagrInfoPlistDict;
    NSDictionary *imagrInfoPlistAttributes;
    if ( [imagrInfoPlistURL checkResourceIsReachableAndReturnError:nil] ) {
        imagrInfoPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:imagrInfoPlistURL];
        imagrInfoPlistAttributes = [fm attributesOfItemAtPath:[imagrInfoPlistURL path] error:&error];
    }
    
    if ( [imagrInfoPlistDict count] == 0 ) {
        imagrInfoPlistDict = [[NSMutableDictionary alloc] init];
        imagrInfoPlistAttributes = @{
                                     NSFileOwnerAccountName : @"root",
                                     NSFileGroupOwnerAccountName : @"wheel",
                                     NSFilePosixPermissions : @0644
                                     };
    }
    
    NSDictionary *atsDict = [NSDictionary dictionaryWithObject:@YES forKey:@"NSAllowsArbitraryLoads"];
    imagrInfoPlistDict[@"NSAppTransportSecurity"] = atsDict;
    
    NSDictionary *modifyImagrInfoPlist = @{
                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                           NBCWorkflowModifyContent : imagrInfoPlistDict,
                                           NBCWorkflowModifyAttributes : imagrInfoPlistAttributes,
                                           NBCWorkflowModifyTargetURL : [imagrInfoPlistURL path]
                                           };
    [modifyDictArray addObject:modifyImagrInfoPlist];
    
    return retval;
}

- (BOOL)modifySettingsForMenuBar:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    NSDictionary *resourceSettings = [workflowItem resourcesSettings];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.systemuiserver.plist
    // --------------------------------------------------------------
    NSDictionary *systemUIServerPreferencesAttributes;
    NSMutableDictionary *systemUIServerPreferencesDict;
    NSURL *systemUIServerPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.systemuiserver.plist"];
    
    if ( [systemUIServerPreferencesURL checkResourceIsReachableAndReturnError:nil] ) {
        systemUIServerPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:systemUIServerPreferencesURL];
        systemUIServerPreferencesAttributes = [fm attributesOfItemAtPath:[systemUIServerPreferencesURL path] error:&error];
    }
    
    if ( [systemUIServerPreferencesDict count] == 0 ) {
        systemUIServerPreferencesDict = [[NSMutableDictionary alloc] init];
        systemUIServerPreferencesAttributes = @{
                                                NSFileOwnerAccountName : @"root",
                                                NSFileGroupOwnerAccountName : @"wheel",
                                                NSFilePosixPermissions : @0644
                                                };
    }
    
    systemUIServerPreferencesDict[@"menuExtras"] = @[
                                                     @"/System/Library/CoreServices/Menu Extras/TextInput.menu",
                                                     @"/System/Library/CoreServices/Menu Extras/Battery.menu",
                                                     @"/System/Library/CoreServices/Menu Extras/Clock.menu"
                                                     ];
    
    NSDictionary *modifyDictSystemUIServerPreferences = @{
                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                          NBCWorkflowModifyContent : systemUIServerPreferencesDict,
                                                          NBCWorkflowModifyAttributes : systemUIServerPreferencesAttributes,
                                                          NBCWorkflowModifyTargetURL : [systemUIServerPreferencesURL path]
                                                          };
    [modifyDictArray addObject:modifyDictSystemUIServerPreferences];
    
    // --------------------------------------------------------------
    //  /Library/LaunchAgents/com.apple.SystemUIServer.plist
    // --------------------------------------------------------------
    NSURL *systemUIServerLaunchAgentURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.SystemUIServer.plist"];
    NSURL *systemUIServerLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.SystemUIServer.plist"];
    NSMutableDictionary *systemUIServerDict;
    NSDictionary *systemUIServerAttributes;
    if ( [systemUIServerLaunchAgentURL checkResourceIsReachableAndReturnError:nil] ) {
        systemUIServerDict = [NSMutableDictionary dictionaryWithContentsOfURL:systemUIServerLaunchAgentURL];
        systemUIServerAttributes = [fm attributesOfItemAtPath:[systemUIServerLaunchAgentURL path] error:&error];
    }
    
    if ( [systemUIServerDict count] == 0 ) {
        systemUIServerDict = [[NSMutableDictionary alloc] init];
        systemUIServerAttributes = @{
                                     NSFileOwnerAccountName : @"root",
                                     NSFileGroupOwnerAccountName : @"wheel",
                                     NSFilePosixPermissions : @0644
                                     };
    }
    
    systemUIServerDict[@"RunAtLoad"] = @YES;
    systemUIServerDict[@"Disabled"] = @NO;
    systemUIServerDict[@"POSIXSpawnType"] = @"Interactive";
    [systemUIServerDict removeObjectForKey:@"KeepAlive"];
    
    NSDictionary *modifyDictSystemUIServer = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                               NBCWorkflowModifyContent : systemUIServerDict,
                                               NBCWorkflowModifyAttributes : systemUIServerAttributes,
                                               NBCWorkflowModifyTargetURL : [systemUIServerLaunchDaemonURL path]
                                               };
    [modifyDictArray addObject:modifyDictSystemUIServer];
    
    NSDictionary *modifySystemUIServerLaunchAgent = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                      NBCWorkflowModifyTargetURL : [systemUIServerLaunchAgentURL path]
                                                      };
    
    [modifyDictArray addObject:modifySystemUIServerLaunchAgent];
    
    // --------------------------------------------------------------
    //  /etc/localtime -> /usr/share/zoneinfo/...
    // --------------------------------------------------------------
    NSURL *localtimeURL = [volumeURL URLByAppendingPathComponent:@"etc/localtime"];
    NSDictionary *localtimeAttributes;
    if ( [localtimeURL checkResourceIsReachableAndReturnError:nil] ) {
        localtimeAttributes = [fm attributesOfItemAtPath:[localtimeURL path] error:&error];
    }
    
    if ( ! localtimeURL ) {
        localtimeAttributes = @{
                                NSFileOwnerAccountName : @"root",
                                NSFileGroupOwnerAccountName : @"wheel",
                                NSFilePosixPermissions : @0644
                                };
    }
    
    NSString *selectedTimeZone = resourceSettings[NBCSettingsTimeZoneKey];
    
    if ( [selectedTimeZone length] != 0 ) {
        NSURL *localtimeTargetURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/usr/share/zoneinfo/%@", selectedTimeZone]];
        
        NSDictionary *modifyLocaltime = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeLink,
                                          NBCWorkflowModifySourceURL : [localtimeURL path],
                                          NBCWorkflowModifyTargetURL : [localtimeTargetURL path]
                                          };
        
        [modifyDictArray addObject:modifyLocaltime];
    }
    
    return retval;
} // modifySettingsForMenuBar

- (BOOL)modifySettingsForTrustedNetBootServers:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSDictionary *resourcesSettings = [workflowItem resourcesSettings];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /usr/local/bsdpSources.txt
    // --------------------------------------------------------------
    NSArray *bsdpSourcesArray = resourcesSettings[NBCSettingsTrustedNetBootServersKey];
    if ( [bsdpSourcesArray count] != 0 ) {
        NSURL *usrLocalBsdpSourcesURL = [volumeURL URLByAppendingPathComponent:@"usr/local/bsdpSources.txt"];
        
        NSMutableString *bsdpSourcesContent = [[NSMutableString alloc] init];
        for ( NSString *trustedNetBootServer in bsdpSourcesArray ) {
            [bsdpSourcesContent appendString:[NSString stringWithFormat:@"%@\n", trustedNetBootServer]];
        }
        
        if ( [bsdpSourcesContent length] != 0 ) {
            NSData *bsdpSourcesData = [bsdpSourcesContent dataUsingEncoding:NSUTF8StringEncoding];
            
            NSDictionary *usrLocalBsdpSourcesAttributes = @{
                                                            NSFileOwnerAccountName : @"root",
                                                            NSFileGroupOwnerAccountName : @"wheel",
                                                            NSFilePosixPermissions : @0644
                                                            };
            NSDictionary *modifyUsrLocalBsdpSources = @{
                                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                        NBCWorkflowModifyContent : bsdpSourcesData,
                                                        NBCWorkflowModifyTargetURL : [usrLocalBsdpSourcesURL path],
                                                        NBCWorkflowModifyAttributes : usrLocalBsdpSourcesAttributes
                                                        };
            
            [modifyDictArray addObject:modifyUsrLocalBsdpSources];
        } else {
            DDLogError(@"[ERROR] bsdp Sources List is empty!");
        }
    } else {
        DDLogError(@"[ERROR] bsdp Sources List is empty!");
    }
    
    return retval;
}

- (BOOL)modifySettingsForCasperImaging:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Configure settings for Casper Imaging...");
    BOOL retval = YES;
    NSDictionary *userSettings = [workflowItem userSettings];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    // Casper Imaging Debug
    // --------------------------------------------------------------
    NSString *casperImagingPath = userSettings[NBCSettingsCasperImagingPathKey];
    if ( [casperImagingPath length] != 0 ) {
        NSURL *casperImagingDebugURL = [[NSURL fileURLWithPath:casperImagingPath] URLByAppendingPathComponent:@"Contents/Support/debug" isDirectory:YES];
        NSDictionary *folderCasperImagingDebugAttributes = @{
                                                             NSFileOwnerAccountName : @"root",
                                                             NSFileGroupOwnerAccountName : @"wheel",
                                                             NSFilePosixPermissions : @0755
                                                             };
        
        NSDictionary *modifyFolderCasperImagingDebug = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                         NBCWorkflowModifyTargetURL : [casperImagingDebugURL path],
                                                         NBCWorkflowModifyAttributes : folderCasperImagingDebugAttributes
                                                         };
        [modifyDictArray addObject:modifyFolderCasperImagingDebug];
    } else {
        DDLogError(@"[ERROR] Path to Casper Imaging.app was empty!");
        return NO;
    }
    
    NSURL *varRootCFUserTextEncodingURL = [volumeURL URLByAppendingPathComponent:@"var/root/.CFUserTextEncoding"];
    NSString *varRootCFUserTextEncodingContentString = @"0:0";
    NSData *varRootCFUserTextEncodingContentData = [varRootCFUserTextEncodingContentString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *varRootCFUserTextEncodingAttributes = @{
                                                          NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644
                                                          };
    NSDictionary *modifyVarRootCFUserTextEncoding = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                      NBCWorkflowModifyContent : varRootCFUserTextEncodingContentData,
                                                      NBCWorkflowModifyTargetURL : [varRootCFUserTextEncodingURL path],
                                                      NBCWorkflowModifyAttributes : varRootCFUserTextEncodingAttributes
                                                      };
    
    [modifyDictArray addObject:modifyVarRootCFUserTextEncoding];
    
    return retval;
}

- (BOOL)modifySettingsForLaunchdLogging:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Configure settings for launchd settings...");
    BOOL retval = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    NSURL *systemLaunchDaemonsFolderURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons"];
    NSURL *systemLaunchAgentsFolderURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents"];
    
    // Add all LaunchDaemons
    NSMutableArray *allLaunchdItemURLs = [[NSMutableArray alloc] initWithArray:[fm contentsOfDirectoryAtURL:systemLaunchDaemonsFolderURL
                                                                                 includingPropertiesForKeys:@[]
                                                                                                    options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                                      error:nil]];
    
    // Add all LaunchAgents
    [allLaunchdItemURLs arrayByAddingObjectsFromArray:[fm contentsOfDirectoryAtURL:systemLaunchAgentsFolderURL
                                                        includingPropertiesForKeys:@[]
                                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                             error:nil]];
    
    NSDictionary *plistAttributes = @{
                                      NSFileOwnerAccountName : @"root",
                                      NSFileGroupOwnerAccountName : @"wheel",
                                      NSFilePosixPermissions : @0644
                                      };
    
    NSPredicate *predicatePlist = [NSPredicate predicateWithFormat:@"pathExtension == 'plist'"];
    NSString *plistName;
    NSString *plistStdOutPath;
    NSString *plistStdErrPath;
    for ( NSURL *fileURL in [allLaunchdItemURLs filteredArrayUsingPredicate:predicatePlist] ) {
        NSMutableDictionary *fileDict = [NSMutableDictionary dictionaryWithContentsOfURL:fileURL];
        if ( [fileDict count] != 0 ) {
            plistName = [[fileURL lastPathComponent]  stringByDeletingPathExtension];
            plistStdOutPath = [NSString stringWithFormat:@"/tmp/%@-stdout", plistName];
            plistStdErrPath = [NSString stringWithFormat:@"/tmp/%@-stderr", plistName];
            
            fileDict[@"StandardOutPath"] = plistStdOutPath;
            fileDict[@"StandardErrorPath"] = plistStdErrPath;
            
            NSDictionary *modifyPlist = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                          NBCWorkflowModifyContent : fileDict,
                                          NBCWorkflowModifyAttributes : plistAttributes,
                                          NBCWorkflowModifyTargetURL : [fileURL path]
                                          };
            
            [modifyDictArray addObject:modifyPlist];
        } else {
            DDLogError(@"[ERROR] Could not read plist at path: %@", [fileURL path]);
        }
    }
    
    return retval;
}

- (BOOL)modifySettingsForConsole:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Configure settings for Console...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist
    // --------------------------------------------------------------
    NSURL *utilitiesPlistURL = [volumeURL URLByAppendingPathComponent:@"System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist"];
    NSMutableDictionary *utilitiesPlistDict;
    NSDictionary *utilitiesPlistAttributes;
    if ( [utilitiesPlistURL checkResourceIsReachableAndReturnError:nil] ) {
        utilitiesPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:utilitiesPlistURL];
        utilitiesPlistAttributes = [fm attributesOfItemAtPath:[utilitiesPlistURL path] error:&error];
    }
    
    if ( [utilitiesPlistDict count] == 0 ) {
        utilitiesPlistDict = [[NSMutableDictionary alloc] init];
        utilitiesPlistAttributes = @{
                                     NSFileOwnerAccountName : @"root",
                                     NSFileGroupOwnerAccountName : @"wheel",
                                     NSFilePosixPermissions : @0644
                                     };
    }
    
    NSMutableArray *menuArray = [[NSMutableArray alloc] initWithArray:utilitiesPlistDict[@"Menu"]];
    if ( [menuArray count] != 0 ) {
        NSDictionary *consoleMenuDict = @{
                                          @"BundlePath" : @"/Applications/Utilities/Console.app",
                                          @"Path" : @"/Applications/Utilities/Console.app/Contents/MacOS/Console",
                                          @"TitleKey" : @"Console"
                                          };
        [menuArray addObject:consoleMenuDict];
        utilitiesPlistDict[@"Menu"] = menuArray;
    }
    
    NSDictionary *modifyUtilitiesPlist = @{
                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                           NBCWorkflowModifyContent : utilitiesPlistDict,
                                           NBCWorkflowModifyAttributes : utilitiesPlistAttributes,
                                           NBCWorkflowModifyTargetURL : [utilitiesPlistURL path]
                                           };
    
    [modifyDictArray addObject:modifyUtilitiesPlist];
    
    return retval;
}

- (BOOL)modifySettingsForVNC:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Configure settings for ARD/VNC...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
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
    remoteManagementDict[@"LoadRemoteManagementMenuExtra"] = @NO;
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
        DDLogError(@"[ERROR] screensharingLaunchDaemonURL does not exist!");
        DDLogError(@"%@", error);
        return NO;
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
        DDLogError(@"|ERROR] remoteDesktopPrivilegeProxyDaemonURL does not esits!");
        DDLogError(@"%@", error);
        return NO;
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
        DDLogError(@"|ERROR] screensharingAgentDaemonURL does not esits!");
        DDLogError(@"%@", error);
        return NO;
    }
    
    // TESTING!
    //screensharingAgentLaunchDaemonDict[@"RunAtLoad"] = @YES;
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
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    
    if ( 7 < sourceVersionMinor ) {
        NSURL *screensharingMessagesAgentDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist"];
        NSMutableDictionary *screensharingMessagesAgentLaunchAgentDict;
        NSDictionary *screensharingMessagesAgentLaunchAgentAttributes;
        if ( [screensharingMessagesAgentDaemonURL checkResourceIsReachableAndReturnError:&error] ) {
            screensharingMessagesAgentLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingMessagesAgentDaemonURL];
            screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;
            screensharingMessagesAgentLaunchAgentAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:&error];
        } else if ( 7 < sourceVersionMinor ) {
            screensharingMessagesAgentLaunchAgentDict = [[NSMutableDictionary alloc] init];
            screensharingMessagesAgentLaunchAgentDict[@"EnableTransactions"] = @YES;
            screensharingMessagesAgentLaunchAgentDict[@"Label"] = @"com.apple.screensharing.MessagesAgent";
            screensharingMessagesAgentLaunchAgentDict[@"ProgramArguments"] = @[ @"/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/MacOS/AppleVNCServer" ];
            screensharingMessagesAgentLaunchAgentDict[@"MachServices"] = @{ @"com.apple.screensharing.MessagesAgent" : @YES };
            screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;
        } else {
            DDLogError(@"|ERROR] screensharingMessagesAgentDaemonURL does not esits!");
            DDLogError(@"%@", error);
            return NO;
        }
        
        if ( [screensharingMessagesAgentLaunchAgentAttributes count] == 0 ) {
            screensharingMessagesAgentLaunchAgentAttributes = @{
                                                                NSFileOwnerAccountName : @"root",
                                                                NSFileGroupOwnerAccountName : @"wheel",
                                                                NSFilePosixPermissions : @0644
                                                                };
        }
        
        NSDictionary *modifyDictScreensharingMessagesAgentLaunchAgent = @{
                                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                                          NBCWorkflowModifyContent : screensharingMessagesAgentLaunchAgentDict,
                                                                          NBCWorkflowModifyTargetURL : [screensharingMessagesAgentDaemonURL path],
                                                                          NBCWorkflowModifyAttributes : screensharingMessagesAgentLaunchAgentAttributes
                                                                          };
        
        [modifyDictArray addObject:modifyDictScreensharingMessagesAgentLaunchAgent];
    } else {
        DDLogDebug(@"MessagesAgent isn't available in 10.7 or lower.");
    }
    
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
        DDLogError(@"|ERROR] remoteDesktopDaemonURL does not esits!");
        DDLogError(@"%@", error);
        return NO;
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
    
    remoteDesktopDict[@"DOCAllowRemoteConnections"] = @YES;
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
    
    return retval;
} // modifySettingsForVNC:workflowItem

- (BOOL)modifySettingsForRCCdrom:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(modifyDictArray)
    DDLogInfo(@"Disabling WiFi in NBI...");
    BOOL retval = YES;
    NSError *error;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // --------------------------------------------------------------
    //  /etc/rc.cdm.cdrom
    // --------------------------------------------------------------
    NSURL *rcCdromURL = [volumeURL URLByAppendingPathComponent:@"etc/rc.cdrom"];
    NSURL *rcCdmCdromURL = [volumeURL URLByAppendingPathComponent:@"etc/rc.cdm.cdrom"];
    
    if ( [rcCdromURL checkResourceIsReachableAndReturnError:nil] ) {
        NSString *rcCdromOriginal = [NSString stringWithContentsOfURL:rcCdromURL encoding:NSUTF8StringEncoding error:&error];
        __block NSMutableString *rcCdmCdromNew = [[NSMutableString alloc] init];
        __block NSMutableString *rcCdmCdrom = [[NSMutableString alloc] init];
        __block BOOL copyComplete = NO;
        __block BOOL inspectNextLine = NO;
        __block BOOL copyNextLine = NO;
        [rcCdromOriginal enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
#pragma unused(stop)
            
            // Fix problem with paths with spaces in them
            if ( [line containsString:@"/usr/bin/stat"] ) {
                [rcCdmCdromNew appendString:@"    eval `/usr/bin/stat -s \"$mntpt\"`\n"];
                return;
            } else if ( [line containsString:@"mount -t hfs -o union -o nobrowse $dev $mntpt"] ) {
                [rcCdmCdromNew appendString:@"    mount -t hfs -o union -o nobrowse $dev \"$mntpt\"\n"];
                return;
            } else if ( [line containsString:@"chown $st_uid:$st_gid $mntpt"] ) {
                [rcCdmCdromNew appendString:@"    chown $st_uid:$st_gid \"$mntpt\"\n"];
                return;
            } else if ( [line containsString:@"chmod $st_mode $mntpt"] ) {
                [rcCdmCdromNew appendString:@"    chmod $st_mode \"$mntpt\"\n"];
                return;
            }else {
                [rcCdmCdromNew appendString:[NSString stringWithFormat:@"%@\n", line]];
            }
            
            if ( copyNextLine && ! copyComplete ) {
                if ( [line hasPrefix:@"fi"] ) {
                    copyComplete = YES;
                    //*stop = YES;
                    return;
                }
                
                NSRange range = [line rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
                line = [line stringByReplacingCharactersInRange:range withString:@""];
                
                if ( [line hasPrefix:@"RAMDisk"] ) {
                    NSMutableArray *lineArray = [NSMutableArray arrayWithArray:[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    NSString *path = lineArray[1];
                    
                    // These are a copy of what DeployStudio sets
                    if ( [path isEqualToString:@"/Volumes"] ) {
                        lineArray[2] = @"2048";
                    } else if ( [path isEqualToString:@"/var/tmp"] ) {
                        lineArray[2] = @"32768";
                    } else if ( [path isEqualToString:@"/var/run"] ) {
                        lineArray[2] = @"4096";
                    } else if ( [path isEqualToString:@"/var/db"] ) {
                        lineArray[2] = @"4096";
                    } else if ( [path isEqualToString:@"/var/root/Library"] ) {
                        lineArray[2] = @"32768";
                    } else if ( [path isEqualToString:@"/Library/ColorSync/Profiles/Displays"] ) {
                        lineArray[2] = @"4096";
                    } else if ( [path isEqualToString:@"/Library/Preferences"] ) {
                        lineArray[2] = @"4096";
                    } else if ( [path isEqualToString:@"/Library/Preferences/SystemConfiguration"] ) {
                        lineArray[2] = @"4096";
                    }
                    
                    line = [lineArray componentsJoinedByString:@" "];
                }
                [rcCdmCdrom appendString:[NSString stringWithFormat:@"%@\n", line]];
                return;
            }
            
            if ( inspectNextLine ) {
                if ( [line hasPrefix:@"else"] ) {
                    copyNextLine = YES;
                    return;
                }
            }
            
            if ( [line hasPrefix:@"if [ -f \"/etc/rc.cdm.cdrom\" ]; then"] ) {
                inspectNextLine = YES;
            }
        }];
        
        
        
        if ( [rcCdmCdrom length] != 0 ) {
            [rcCdmCdrom appendString:@"RAMDisk /System/Library/Caches 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /System/Library/Caches/com.apple.CVMS 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/lsd 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/crls 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db/com.apple.launchd 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/dslocal/nodes/Default/users 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Caches 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Caches/ocspd 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs 16384\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs/DiagnosticReports 4096\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Caches 65536\n"];
                        
            if ( [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
                [rcCdmCdrom appendString:@"RAMDisk '/Library/Security/Trust Settings' 2048\n"];
            }
            
            switch ( [workflowItem workflowType] ) {
                case kWorkflowTypeImagr:
                {
                    [rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Caches/com.grahamgilbert.Imagr 2048\n"];
                    break;
                }
                default:
                    break;
            }
            
        } else {
            DDLogError(@"[ERROR] rcCdmCdrom is nil!");
            return NO;
        }
        
        NSData *rcCdmCdromData = [rcCdmCdrom dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *rcCdmCdromAttributes = @{
                                               NSFileOwnerAccountName : @"root",
                                               NSFileGroupOwnerAccountName : @"wheel",
                                               NSFilePosixPermissions : @0555
                                               };
        
        NSDictionary *modifyRcCdmCdrom = @{
                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                           NBCWorkflowModifyContent : rcCdmCdromData,
                                           NBCWorkflowModifyTargetURL : [rcCdmCdromURL path],
                                           NBCWorkflowModifyAttributes : rcCdmCdromAttributes
                                           };
        
        [modifyDictArray addObject:modifyRcCdmCdrom];
        
        NSData *rcCdmCdromNewData = [rcCdmCdromNew dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *rcCdmCdromNewAttributes = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0555
                                                  };
        
        NSDictionary *modifyRcCdmCdromNew = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                              NBCWorkflowModifyContent : rcCdmCdromNewData,
                                              NBCWorkflowModifyTargetURL : [rcCdromURL path],
                                              NBCWorkflowModifyAttributes : rcCdmCdromNewAttributes
                                              };
        
        [modifyDictArray addObject:modifyRcCdmCdromNew];
    } else {
        DDLogError(@"[ERROR] rcCdromURL doesn't exist!");
        DDLogError(@"[ERROR] %@", error);
        return NO;
    }
    
    return retval;
}

- (BOOL)modifyNBIRemoveBluetooth:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Disabling Bluetooth in NBI...");
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IOBluetoothFamily.kext
    // --------------------------------------------------------------
    NSURL *bluetoothKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothFamily.kext"];
    NSURL *bluetoothKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IOBluetoothFamily.kext"];
    NSDictionary *modifyBluetoothKext = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                          NBCWorkflowModifySourceURL : [bluetoothKextSourceURL path],
                                          NBCWorkflowModifyTargetURL : [bluetoothKextTargetURL path]
                                          };
    [modifyDictArray addObject:modifyBluetoothKext];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IOBluetoothHIDDriver.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDDriverKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothHIDDriver.kext"];
    NSURL *bluetoothHIDDriverKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IOBluetoothHIDDriver.kext"];
    NSDictionary *modifyBluetoothHIDDriverKext = @{
                                                   NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                                   NBCWorkflowModifySourceURL : [bluetoothHIDDriverKextSourceURL path],
                                                   NBCWorkflowModifyTargetURL : [bluetoothHIDDriverKextTargetURL path]
                                                   };
    [modifyDictArray addObject:modifyBluetoothHIDDriverKext];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothHIDMouse.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDMouseKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothHIDMouse.kext"];
    NSURL *bluetoothHIDMouseKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothHIDMouse.kext"];
    NSDictionary *modifyBluetoothHIDMouseKext = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                                  NBCWorkflowModifySourceURL : [bluetoothHIDMouseKextSourceURL path],
                                                  NBCWorkflowModifyTargetURL : [bluetoothHIDMouseKextTargetURL path]
                                                  };
    [modifyDictArray addObject:modifyBluetoothHIDMouseKext];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothHIDKeyboard.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDKeyboardKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothHIDKeyboard.kext"];
    NSURL *bluetoothHIDKeyboardKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothHIDKeyboard.kext"];
    NSDictionary *modifyBluetoothHIDKeyboardKext = @{
                                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                                     NBCWorkflowModifySourceURL : [bluetoothHIDKeyboardKextSourceURL path],
                                                     NBCWorkflowModifyTargetURL : [bluetoothHIDKeyboardKextTargetURL path]
                                                     };
    [modifyDictArray addObject:modifyBluetoothHIDKeyboardKext];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothMultitouch.kext
    // --------------------------------------------------------------
    NSURL *bluetoothMultitouchKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothMultitouch.kext"];
    NSURL *bluetoothMultitouchKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothMultitouch.kext"];
    NSDictionary *modifyBluetoothMultitouchKext = @{
                                                    NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                                    NBCWorkflowModifySourceURL : [bluetoothMultitouchKextSourceURL path],
                                                    NBCWorkflowModifyTargetURL : [bluetoothMultitouchKextTargetURL path]
                                                    };
    [modifyDictArray addObject:modifyBluetoothMultitouchKext];
    
    return retval;
}

- (BOOL)modifyNBIRemoveWiFi:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Disabling WiFi in NBI...");
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    NSURL *wifiKextSourceURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    NSURL *wifiKextTargetURL = [volumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IO80211Family.kext"];
    NSDictionary *modifyWifiKext = @{
                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                     NBCWorkflowModifySourceURL : [wifiKextSourceURL path],
                                     NBCWorkflowModifyTargetURL : [wifiKextTargetURL path]
                                     };
    [modifyDictArray addObject:modifyWifiKext];
    
    // --------------------------------------------------------------
    //  /System/Library/CoreServices/Menu Extras/AirPort.menu
    // --------------------------------------------------------------
    NSURL *airPortMenuURL = [volumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras/AirPort.menu"];
    NSDictionary *modifyAirPortMenu = @{
                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                        NBCWorkflowModifyTargetURL : [airPortMenuURL path]
                                        };
    [modifyDictArray addObject:modifyAirPortMenu];
    
    return retval;
} // modifyNBIRemoveWiFi

- (BOOL)modifySettingsForCasper:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Adding settings for Casoper JSS for Casper Imaging...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // ---------------------------------------------------------------
    //  /var/root/Library/Preferences/com.jamfsoftware.jss
    // ---------------------------------------------------------------
    NSURL *jssSettingsURL = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/com.jamfsoftware.jss"];
    NSDictionary *jssSettingsAttributes;
    NSMutableDictionary *jssSettingsDict;
    if ( [jssSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        jssSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:jssSettingsURL];
        jssSettingsAttributes = [fm attributesOfItemAtPath:[jssSettingsURL path] error:&error];
    }
    
    if ( [jssSettingsDict count] == 0 ) {
        jssSettingsDict = [[NSMutableDictionary alloc] init];
        jssSettingsAttributes = @{
                                  NSFileOwnerAccountName : @"root",
                                  NSFileGroupOwnerAccountName : @"wheel",
                                  NSFilePosixPermissions : @0644
                                  };
    }
    
    jssSettingsDict[@"allowInvalidCertificate"] = @NO;
    
    NSString *jssURLString = userSettings[NBCSettingsCasperJSSURLKey];
    if ( [jssURLString length] != 0 ) {
        jssSettingsDict[@"url"] = jssURLString ?: @"";
        NSURL *jssURL = [NSURL URLWithString:jssURLString];
        jssSettingsDict[@"secure"] = [[jssURL scheme] isEqualTo:@"https"] ? @YES : @NO;
        jssSettingsDict[@"address"] = [jssURL host] ?: @"";
        
        NSNumber *port = [NSNumber numberWithInt:80];
        if( [jssURL port] == nil && [[jssURL scheme] isEqualTo:@"https"]){
            port = [NSNumber numberWithInt:443];
        } else if( [jssURL port] != nil){
            port = [jssURL port];
        }
        jssSettingsDict[@"port"] = [port stringValue] ?: @"";
        jssSettingsDict[@"path"] = [jssURL path] ?: @"";
    }
    
    NSDictionary *modifyJSSSettings = @{
                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                        NBCWorkflowModifyContent : jssSettingsDict,
                                        NBCWorkflowModifyAttributes : jssSettingsAttributes,
                                        NBCWorkflowModifyTargetURL : [jssSettingsURL path]
                                        };
    [modifyDictArray addObject:modifyJSSSettings];
    
    return retval;
}

- (BOOL)modifyNBINTP:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /etc/ntp.conf
    // --------------------------------------------------------------
    NSString *ntpServer = [workflowItem userSettings][NBCSettingsNetworkTimeServerKey];
    if ( [ntpServer length] == 0 ) {
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
        if ( [digOutput length] != 0 ) {
            NSArray *ntpServerArray = [digOutput componentsSeparatedByString:@"\n"];
            ntpServer = [NSString stringWithFormat:@"server %@", ntpServer];
            for ( NSString *ntpIP in ntpServerArray ) {
                ntpServer = [ntpServer stringByAppendingString:[NSString stringWithFormat:@"\nserver %@", ntpIP]];
            }
        } else {
            DDLogWarn(@"[WARN] Could not resolve ntp server!");
            // Add to warning report!
        }
    } else {
        DDLogWarn(@"[WARN] Got no output from dig!");
        // Add to warning report!
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
    
    return retval;
} // modifyNBINTP

- (BOOL)modifySettingsAddFolders:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Library/Caches
    // --------------------------------------------------------------
    NSURL *folderLibraryCache = [volumeURL URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES];
    NSDictionary *folderLibraryCacheAttributes = @{
                                                   NSFileOwnerAccountName : @"root",
                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                   NSFilePosixPermissions : @0777
                                                   };
    
    NSDictionary *modifyFolderLibraryCache = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                               NBCWorkflowModifyTargetURL : [folderLibraryCache path],
                                               NBCWorkflowModifyAttributes : folderLibraryCacheAttributes
                                               };
    [modifyDictArray addObject:modifyFolderLibraryCache];
    
    // --------------------------------------------------------------
    //  /var/db/lsd
    // --------------------------------------------------------------
    NSURL *folderVarDbLsd = [volumeURL URLByAppendingPathComponent:@"var/db/lsd" isDirectory:YES];
    NSDictionary *folderVarDbLsdAttributes = @{
                                               NSFileOwnerAccountName : @"root",
                                               NSFileGroupOwnerAccountName : @"wheel",
                                               NSFilePosixPermissions : @0777
                                               };
    
    NSDictionary *modifyFolderVarDbLsd = @{
                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                           NBCWorkflowModifyTargetURL : [folderVarDbLsd path],
                                           NBCWorkflowModifyAttributes : folderVarDbLsdAttributes
                                           };
    [modifyDictArray addObject:modifyFolderVarDbLsd];
    
    // --------------------------------------------------------------
    //  /var/db/launchd.db
    // --------------------------------------------------------------
    NSURL *folderVarDbLaunchdb = [volumeURL URLByAppendingPathComponent:@"var/db/launchd.db" isDirectory:YES];
    NSDictionary *folderVarDbLaunchdbAttributes = @{
                                                    NSFileOwnerAccountName : @"root",
                                                    NSFileGroupOwnerAccountName : @"wheel",
                                                    NSFilePosixPermissions : @0755
                                                    };
    NSDictionary *modifyFolderVarDbLaunchdb = @{
                                                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                NBCWorkflowModifyTargetURL : [folderVarDbLaunchdb path],
                                                NBCWorkflowModifyAttributes : folderVarDbLaunchdbAttributes
                                                };
    [modifyDictArray addObject:modifyFolderVarDbLaunchdb];
    
    NSURL *folderVarDbLaunchdbLaunchdURL = [volumeURL URLByAppendingPathComponent:@"var/db/launchd.db/com.apple.launchd" isDirectory:YES];
    NSDictionary *folderVarDbLaunchdbLaunchdAttributes = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0755
                                                           };
    NSDictionary *modifyFolderVarDbLaunchdbLaunchd = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                       NBCWorkflowModifyTargetURL : [folderVarDbLaunchdbLaunchdURL path],
                                                       NBCWorkflowModifyAttributes : folderVarDbLaunchdbLaunchdAttributes
                                                       };
    [modifyDictArray addObject:modifyFolderVarDbLaunchdbLaunchd];
    
    // --------------------------------------------------------------
    //  /Library/LaunchAgents
    // --------------------------------------------------------------
    NSURL *folderLibraryLaunchAgents = [volumeURL URLByAppendingPathComponent:@"Library/LaunchAgents" isDirectory:YES];
    NSDictionary *folderLibraryLaunchAgentsAttributes = @{
                                                          NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0755
                                                          };
    NSDictionary *modifyFolderLibraryLaunchAgents = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                      NBCWorkflowModifyTargetURL : [folderLibraryLaunchAgents path],
                                                      NBCWorkflowModifyAttributes : folderLibraryLaunchAgentsAttributes
                                                      };
    [modifyDictArray addObject:modifyFolderLibraryLaunchAgents];
    
    // --------------------------------------------------------------
    //  /Library/LaunchDaemons
    // --------------------------------------------------------------
    NSURL *folderLibraryLaunchDaemons = [volumeURL URLByAppendingPathComponent:@"Library/LaunchDaemons" isDirectory:YES];
    NSDictionary *folderLibraryLaunchDaemonsAttributes = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0755
                                                           };
    NSDictionary *modifyFolderLibraryLaunchDaemons = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                       NBCWorkflowModifyTargetURL : [folderLibraryLaunchDaemons path],
                                                       NBCWorkflowModifyAttributes : folderLibraryLaunchDaemonsAttributes
                                                       };
    [modifyDictArray addObject:modifyFolderLibraryLaunchDaemons];
    
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
    
    // --------------------------------------------------------------
    //  /var/root/Library/Caches/ocspd
    // --------------------------------------------------------------
    NSURL *folderRootLibraryCachesOcspd = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Caches/ocspd" isDirectory:YES];
    NSDictionary *folderRootLibraryCachesOcspdAttributes = @{
                                                             NSFileOwnerAccountName : @"root",
                                                             NSFileGroupOwnerAccountName : @"wheel",
                                                             NSFilePosixPermissions : @0755
                                                             };
    
    NSDictionary *modifyFolderRootLibraryCachesOcspd = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                         NBCWorkflowModifyTargetURL : [folderRootLibraryCachesOcspd path],
                                                         NBCWorkflowModifyAttributes : folderRootLibraryCachesOcspdAttributes
                                                         };
    [modifyDictArray addObject:modifyFolderRootLibraryCachesOcspd];
    
    switch ( [workflowItem workflowType] ) {
        case kWorkflowTypeImagr:
        {
            // --------------------------------------------------------------
            //  /var/root/Library/Caches/ocspd
            // --------------------------------------------------------------
            NSURL *folderRootLibraryCachesImagr = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Caches/com.grahamgilbert.Imagr" isDirectory:YES];
            NSDictionary *folderRootLibraryCachesImagrAttributes = @{
                                                                     NSFileOwnerAccountName : @"root",
                                                                     NSFileGroupOwnerAccountName : @"wheel",
                                                                     NSFilePosixPermissions : @0755
                                                                     };
            
            NSDictionary *modifyFolderRootLibraryCachesImagr = @{
                                                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                                 NBCWorkflowModifyTargetURL : [folderRootLibraryCachesImagr path],
                                                                 NBCWorkflowModifyAttributes : folderRootLibraryCachesImagrAttributes
                                                                 };
            [modifyDictArray addObject:modifyFolderRootLibraryCachesImagr];
            break;
        }
        default:
            break;
    }
    
    return retval;
} // modifySettingsAddFolders

- (BOOL)verifyNetInstallFromDiskImageURL:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    DDLogInfo(@"Verifying NetInstall.dmg...");
    BOOL verified = NO;
    NSURL *netInstallVolumeURL;
    
    [target setNbiNetInstallURL:netInstallDiskImageURL];
    NBCDisk *netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallDiskImageURL
                                                                         imageType:@"NetInstall"];
    if ( netInstallDisk != nil ) {
        [target setNbiNetInstallDisk:netInstallDisk];
        [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
        netInstallVolumeURL = [netInstallDisk volumeURL];
        DDLogDebug(@"netInstallVolumeURL=%@", netInstallVolumeURL);
        if ( netInstallVolumeURL ) {
            verified = YES;
        } else {
            DDLogError(@"[ERROR] netInstallVolumeURL is nil!");
            return NO;
        }
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
                if ( netInstallVolumeURL ) {
                    netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallVolumeURL
                                                                                imageType:@"NetInstall"];
                    if ( netInstallDisk ) {
                        [target setNbiNetInstallDisk:netInstallDisk];
                        [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
                        [netInstallDisk setIsMountedByNBICreator:YES];
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] netInstallDisk is nil!");
                    }
                } else {
                    DDLogError(@"[ERROR] netInstallVolumeURL is nil!");
                }
            } else {
                DDLogError(@"[ERROR] No info dict returned from hdiutil!");
            }
        } else {
            DDLogError(@"[ERROR] Attaching NetInstall image failed!");
        }
    }
    
    if ( verified && netInstallVolumeURL != nil ) {
        [target setNbiNetInstallVolumeURL:netInstallVolumeURL];
        NSURL *baseSystemURL = [netInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
        } else {
            DDLogError(@"[ERROR] Found no BaseSystem.dmg!");
            verified = NO;
        }
    }
    
    return verified;
} // verifyNetInstallFromDiskImageURL

- (BOOL)verifyBaseSystemFromTarget:(NBCTarget *)target source:(NBCSource *)source error:(NSError **)error {
    DDLogInfo(@"Verifying BaseSystem.dmg...");
    BOOL verified = NO;
    
    NSURL *baseSystemDiskImageURL = [target baseSystemURL];
    NSURL *baseSystemVolumeURL;
    
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk != nil ) {
        [target setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        if ( baseSystemVolumeURL ) {
            verified = YES;
        } else {
            DDLogError(@"[ERROR] baseSystemVolumeURL is nil!");
            return NO;
        }
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
                if ( baseSystemVolumeURL ) {
                    baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                                imageType:@"BaseSystem"];
                    if ( baseSystemDisk ) {
                        [target setBaseSystemDisk:baseSystemDisk];
                        [target setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
                        [baseSystemDisk setIsMountedByNBICreator:YES];
                        
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] baseSystemDisk is nil");
                    }
                } else {
                    DDLogError(@"[ERROR] baseSystemVolumeURL is nil");
                }
            } else {
                DDLogError(@"[ERROR] No info dict returned from hdiutil!");
            }
        } else {
            DDLogError(@"[ERROR] Attaching BaseSystem image failed!");
        }
    }
    
    if ( verified && baseSystemVolumeURL != nil ) {
        [target setBaseSystemVolumeURL:baseSystemVolumeURL];
        NSURL *systemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            if ( [systemVersionPlist count] != 0 ) {
                NSString *baseSystemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                if ( baseSystemOSVersion != nil ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                } else {
                    DDLogError(@"[ERROR] Unable to read osVersion from SystemVersion.plist");
                    return NO;
                }
                
                NSString *baseSystemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                if ( baseSystemOSBuild != nil ) {
                    [source setBaseSystemOSBuild:baseSystemOSBuild];
                    [source setSourceBuild:baseSystemOSBuild];
                } else {
                    DDLogError(@"[ERROR] Unable to read osBuild from SystemVersion.plist");
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] Error reading systemVersionPlist");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] Found no SystemVersion plist");
            DDLogError(@"%@", *error);
            verified = NO;
        }
    }
    
    return verified;
} // verifyBaseSystemFromTarget

@end
