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

DDLogLevel ddLogLevel;

@implementation NBCTargetController

- (BOOL)applyNBISettings:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
#pragma unused(error)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Configuring NBImageInfo.plist...");
    BOOL verified = YES;
    NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
    DDLogDebug(@"nbImageInfoURL=%@", nbImageInfoURL);
    NSMutableDictionary *nbImageInfoDict = [self getNBImageInfoDict:nbImageInfoURL nbiURL:nbiURL];
    DDLogDebug(@"nbImageInfoDict=%@", nbImageInfoDict);
    if ( [nbImageInfoDict count] != 0 ) {
        nbImageInfoDict = [self updateNBImageInfoDict:nbImageInfoDict nbImageInfoURL:nbImageInfoURL workflowItem:workflowItem];
        DDLogDebug(@"nbImageInfoDict=%@", nbImageInfoDict);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Getting NBImageInfo.plist...");
    DDLogDebug(@"nbiImageInfoURL=%@", nbiImageInfoURL);
    DDLogDebug(@"nbiURL=%@", nbiURL);
    NSMutableDictionary *nbImageInfoDict;
    
    if ( [nbiImageInfoURL checkResourceIsReachableAndReturnError:nil] ) {
        nbImageInfoDict = [[NSMutableDictionary alloc] initWithContentsOfURL:nbiImageInfoURL];
    } else {
        nbImageInfoDict = [self createDefaultNBImageInfoPlist:nbiURL];
    }
    DDLogDebug(@"nbImageInfoDict=%@", nbImageInfoDict);
    
    return nbImageInfoDict;
} // getNBImageInfoDict:nbiURL

- (NSMutableDictionary *)createDefaultNBImageInfoPlist:(NSURL *)nbiURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Creating Default NBImageInfo.plist...");
    DDLogDebug(@"nbiURL=%@", nbiURL);
    NSMutableDictionary *nbImageInfoDict = [[NSMutableDictionary alloc] init];
    NSArray *disabledSystemIdentifiers;
    NSDictionary *platformSupportDict;
    NSURL *platformSupportURL = [nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
    DDLogDebug(@"platformSupportURL=%@", platformSupportURL);
    if ( platformSupportURL ) {
        platformSupportDict = [[NSDictionary alloc] initWithContentsOfURL:platformSupportURL];
    } else {
        DDLogWarn(@"[WARN] Could not find PlatformSupport.plist on source!");
    }
    DDLogDebug(@"platformSupportDict=%@", platformSupportDict);
    if ( [platformSupportDict count] != 0 ) {
        disabledSystemIdentifiers = platformSupportDict[@"SupportedModelProperties"];
        if ( [disabledSystemIdentifiers count] != 0 ) {
            disabledSystemIdentifiers = [disabledSystemIdentifiers sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            DDLogDebug(@"disabledSystemIdentifiers=%@", disabledSystemIdentifiers);
        } else {
            DDLogWarn(@"[WARN] DisabledSystemIdentifiers was empty");
        }
    }
    
    nbImageInfoDict[@"Architectures"] = @[ @"i386" ];
    nbImageInfoDict[@"BackwardCompatible"] = @NO;
    nbImageInfoDict[@"BootFile"] = @"booter";
    nbImageInfoDict[@"Description"] = @"";
    nbImageInfoDict[@"DisabledSystemIdentifiers"] = disabledSystemIdentifiers ? : @[];
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
    DDLogDebug(@"nbImageInfoDict=%@", nbImageInfoDict);
    
    return nbImageInfoDict;
} // createDefaultNBImageInfoPlist

- (NSMutableDictionary *)updateNBImageInfoDict:(NSMutableDictionary *)nbImageInfoDict nbImageInfoURL:(NSURL *)nbImageInfoURL workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(nbImageInfoURL)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSMutableDictionary *newNBImageInfoDict = nbImageInfoDict;
    DDLogDebug(@"newNBImageInfoDict=%@", newNBImageInfoDict);
    if ( [newNBImageInfoDict count] == 0 ) {
        DDLogError(@"[ERROR] NBImageInfo.plist is empty!");
        return nil;
    }
    
    NSDictionary *workflowSettings = [workflowItem userSettings];
    DDLogDebug(@"workflowSettings=%@", workflowSettings);
    if ( [newNBImageInfoDict count] == 0 ) {
        DDLogError(@"[ERROR] workflowSettings are empty!");
        return nil;
    }
    
    availabilityEnabled = [workflowSettings[NBCSettingsNBIEnabled] boolValue];
    DDLogDebug(@"availabilityEnabled=%hhd", availabilityEnabled);
    
    availabilityDefault = [workflowSettings[NBCSettingsNBIDefault] boolValue];
    DDLogDebug(@"availabilityDefault=%hhd", availabilityDefault);
    
    nbiLanguage = workflowSettings[NBCSettingsNBILanguage];
    DDLogDebug(@"nbiLanguage=%@", nbiLanguage);
    if ( [nbiLanguage length] == 0 ) {
        DDLogError(@"[ERROR] Language setting is empty!");
        return nil;
    }
    
    nbiType = workflowSettings[NBCSettingsNBIProtocol];
    DDLogDebug(@"nbiType=%@", nbiType);
    if ( [nbiType length] == 0 ) {
        DDLogError(@"[ERROR] Protocol setting is empty!");
        return nil;
    }
    
    nbiName = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIName]
                                     source:source
                          applicationSource:applicationSource];
    DDLogDebug(@"nbiName=%@", nbiName);
    if ( [nbiName length] == 0 ) {
        DDLogError(@"[ERROR] NBI name setting is empty!");
        return nil;
    }
    nbiDescription = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIDescription]
                                            source:source
                                 applicationSource:applicationSource];
    DDLogDebug(@"nbiDescription=%@", nbiDescription);
    
    nbiIndexString = [NBCVariables expandVariables:workflowSettings[NBCSettingsNBIIndex]
                                            source:source
                                 applicationSource:applicationSource];
    DDLogDebug(@"nbiIndexString=%@", nbiIndexString);
    if ( [nbiName length] == 0 ) {
        DDLogError(@"[ERROR] NBI index setting is empty!");
        return nil;
    }
    
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    NSNumber *nbiIndex = [f numberFromString:nbiIndexString];
    
    NSString *variableString = @"%OSMAJOR%.%OSMINOR%";
    DDLogDebug(@"variableString=%@", variableString);
    if ( source != nil ) {
        nbiOSVersion = [source expandVariables:variableString];
    }
    DDLogDebug(@"nbiOSVersion=%@", nbiOSVersion);
    
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
    } else {
        DDLogError(@"[ERROR] newNBImageInfoDict is nil!");
    }
    DDLogDebug(@"newNBImageInfoDict=%@", newNBImageInfoDict);
    
    return newNBImageInfoDict;
} // updateNBImageInfoDict:

- (BOOL)updateNBIIcon:(NSImage *)nbiIcon nbiURL:(NSURL *)nbiURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Setting NBI Icon...");
    DDLogDebug(@"nbiURL=%@", nbiURL);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Attaching NetInstall image with shadow file...");
    BOOL verified = YES;
    NSURL *nbiNetInstallVolumeURL;
    NSDictionary *nbiNetInstallDiskImageDict;
    
    NSString *shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    DDLogDebug(@"shadowFilePath=%@", shadowFilePath);
    
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowFilePath,
                                @"-owners", @"on", // Possibly comment out?
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    DDLogDebug(@"hdiutilOptions=%@", hdiutilOptions);
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
        DDLogDebug(@"nbiNetInstallVolumeURL=%@", nbiNetInstallVolumeURL);
        [target setNbiNetInstallVolumeURL:nbiNetInstallVolumeURL];
        [target setNbiNetInstallShadowPath:shadowFilePath];
        
        NSURL *baseSystemURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
        } else {
            DDLogError(@"[ERROR] Found No BaseSystem DMG!");
            verified = NO;
        }
    }
    
    return verified;
} // attachNetInstallDiskImageWithShadowFile:target:error

- (BOOL)convertNetInstallFromShadow:(NBCTarget *)target error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Converting NetInstall.dmg and shadow file to sparseimage...");
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *netInstallURL = [target nbiNetInstallURL];
    DDLogDebug(@"netInstallURL=%@", netInstallURL);
    NSString *netInstallShadowPath = [target nbiNetInstallShadowPath];
    DDLogDebug(@"netInstallShadowPath=%@", netInstallShadowPath);
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    DDLogDebug(@"nbiNetInstallVolumeURL=%@", nbiNetInstallVolumeURL);
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiNetInstallVolumeURL path]] ) {
        if ( [NBCDiskImageController convertDiskImageAtPath:[netInstallURL path] shadowImagePath:netInstallShadowPath] ) {
            NSURL *nbiNetInstallSparseimageURL = [[netInstallURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"sparseimage"];
            DDLogDebug(@"nbiNetInstallSparseimageURL=%@", nbiNetInstallSparseimageURL);
            if ( [fm removeItemAtURL:netInstallURL error:error] ) {
                if ( ! [fm moveItemAtURL:nbiNetInstallSparseimageURL toURL:netInstallURL error:error] ) {
                    DDLogError(@"[ERROR] Could not move sparse image to NBI");
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Attaching BaseSystem image with shadow file...");
    BOOL verified = YES;
    NSURL *nbiBaseSystemVolumeURL;
    NSDictionary *nbiBaseSystemDiskImageDict;
    
    NSString *shadowFilePath = [target baseSystemShadowPath];
    if ( [shadowFilePath length] == 0 ) {
        shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    }
    DDLogDebug(@"shadowFilePath=%@", shadowFilePath);
    
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowFilePath,
                                @"-owners", @"on",
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    DDLogDebug(@"hdiutilOptions=%@", hdiutilOptions);
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
        DDLogDebug(@"nbiBaseSystemVolumeURL=%@", nbiBaseSystemVolumeURL);
        [target setBaseSystemVolumeURL:nbiBaseSystemVolumeURL];
        [target setBaseSystemShadowPath:shadowFilePath];
    }
    
    return verified;
} // attachBaseSystemDiskImageWithShadowFile

- (BOOL)convertBaseSystemFromShadow:(NBCTarget *)target error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Converting BaseSystem.dmg and shadow file to sparseimage...");
    BOOL verified = YES;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *baseSystemURL = [target baseSystemURL];
    DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
    NSString *baseSystemShadowPath = [target baseSystemShadowPath];
    DDLogDebug(@"baseSystemShadowPath=%@", baseSystemShadowPath);
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    DDLogDebug(@"nbiBaseSystemVolumeURL=%@", nbiBaseSystemVolumeURL);
    if ( [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]] ) {
        if ( [NBCDiskImageController convertDiskImageAtPath:[baseSystemURL path] shadowImagePath:baseSystemShadowPath] ) {
            NSURL *nbiBaseSystemSparseimageURL = [[baseSystemURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"sparseimage"];
            DDLogDebug(@"nbiBaseSystemSparseimageURL=%@", nbiBaseSystemSparseimageURL);
            if ( [fm removeItemAtURL:baseSystemURL error:error] ) {
                if ( ! [fm moveItemAtURL:nbiBaseSystemSparseimageURL toURL:baseSystemURL error:error] ) {
                    DDLogError(@"[ERROR] Could not move sparse image to NBI");
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Copying resources to volume...");
    DDLogDebug(@"volumeURL=%@", volumeURL);
    BOOL verified = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *blockVolumeURL = volumeURL;
    NSArray *copyArray = resourcesDict[NBCWorkflowCopy];
    DDLogDebug(@"copyArray=%@", copyArray);
    for ( NSDictionary *copyDict in copyArray ) {
        DDLogDebug(@"copyDict=%@", copyDict);
        NSString *copyType = copyDict[NBCWorkflowCopyType];
        DDLogDebug(@"copyType=%@", copyType);
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            DDLogDebug(@"targetURLString=%@", targetURLString);
            if ( [targetURLString length] != 0 ) {
                targetURL = [blockVolumeURL URLByAppendingPathComponent:targetURLString];
                DDLogDebug(@"targetURL=%@", targetURL);
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
            DDLogDebug(@"sourceURLString=%@", sourceURLString);
            NSURL *sourceURL = [NSURL fileURLWithPath:sourceURLString];
            DDLogDebug(@"sourceURL=%@", sourceURL);
            
            if ( [fileManager copyItemAtURL:sourceURL toURL:targetURL error:error] ) {
                NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
                DDLogDebug(@"attributes=%@", attributes);
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
            DDLogDebug(@"sourceFolderPath=%@", sourceFolderPath);
            if ( [sourceFolderPath length] == 0 ) {
                DDLogError(@"[ERROR] sourceFolderPath is empty!");
                return NO;
            }
            
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            DDLogDebug(@"regexString=%@", regexString);
            if ( [regexString length] == 0 ) {
                DDLogError(@"[ERROR] regexString is empty!");
                return NO;
            }
            
            NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                               [NSString stringWithFormat:@"/usr/bin/find -E . -depth -regex '%@' | /usr/bin/cpio -admp --quiet '%@'", regexString, [volumeURL path]],
                                               nil];
            DDLogDebug(@"scriptArguments=%@", scriptArguments);
            NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
            DDLogDebug(@"commandURL=%@", commandURL);
            
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    //NSError *error;
    //NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.FMM_recovery.plist
    // --------------------------------------------------------------
    NSURL *findmydevicedFMMRecoverySettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.FMM_recovery.plist"];
    DDLogDebug(@"findmydevicedFMMRecoverySettingsURL=%@", findmydevicedFMMRecoverySettingsURL);
    NSDictionary *modifyFindmydevicedFMMRecoverySettings = @{
                                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                             NBCWorkflowModifyTargetURL : [findmydevicedFMMRecoverySettingsURL path]
                                                             };
    DDLogDebug(@"modifyFindmydevicedFMMRecoverySettings=%@", modifyFindmydevicedFMMRecoverySettings);
    [modifyDictArray addObject:modifyFindmydevicedFMMRecoverySettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.webcontentfilter.RecoveryOS.plist
    // --------------------------------------------------------------
    NSURL *webcontentfilterRecoverySettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.webcontentfilter.RecoveryOS.plist"];
    DDLogDebug(@"webcontentfilterRecoverySettingsURL=%@", webcontentfilterRecoverySettingsURL);
    NSDictionary *modifyWebcontentfilterRecoverySettings = @{
                                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                             NBCWorkflowModifyTargetURL : [webcontentfilterRecoverySettingsURL path]
                                                             };
    DDLogDebug(@"modifyWebcontentfilterRecoverySettings=%@", modifyWebcontentfilterRecoverySettings);
    [modifyDictArray addObject:modifyWebcontentfilterRecoverySettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.VoiceOver.plist
    // --------------------------------------------------------------
    NSURL *voiceoverSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.VoiceOver.plist"];
    DDLogDebug(@"voiceoverSettingsURL=%@", voiceoverSettingsURL);
    NSDictionary *modifyVoiceoverSettings = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                              NBCWorkflowModifyTargetURL : [voiceoverSettingsURL path]
                                              };
    DDLogDebug(@"modifyVoiceoverSettings=%@", modifyVoiceoverSettings);
    [modifyDictArray addObject:modifyVoiceoverSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.sbd.plist
    // --------------------------------------------------------------
    NSURL *sbdSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.sbd.plist"];
    DDLogDebug(@"sbdSettingsURL=%@", sbdSettingsURL);
    NSDictionary *modifySbdSettings = @{
                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                        NBCWorkflowModifyTargetURL : [sbdSettingsURL path]
                                        };
    DDLogDebug(@"modifySbdSettings=%@", modifySbdSettings);
    [modifyDictArray addObject:modifySbdSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.scrod.plist
    // --------------------------------------------------------------
    NSURL *scrodSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.scrod.plist"];
    DDLogDebug(@"scrodSettingsURL=%@", scrodSettingsURL);
    NSDictionary *modifyScrodSettings = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                          NBCWorkflowModifyTargetURL : [scrodSettingsURL path]
                                          };
    DDLogDebug(@"modifyScrodSettings=%@", modifyScrodSettings);
    [modifyDictArray addObject:modifyScrodSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.tccd.system.plist
    // --------------------------------------------------------------
    NSURL *tccdSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.tccd.system.plist"];
    DDLogDebug(@"tccdSettingsURL=%@", tccdSettingsURL);
    NSDictionary *modifyTccdSettings = @{
                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                         NBCWorkflowModifyTargetURL : [tccdSettingsURL path]
                                         };
    DDLogDebug(@"modifyTccdSettings=%@", modifyTccdSettings);
    [modifyDictArray addObject:modifyTccdSettings];
    
    return retval;
}

- (BOOL)modifySettingsForFindMyDeviced:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    //NSError *error;
    //NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist
    // --------------------------------------------------------------
    NSURL *findmydevicedSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.icloud.findmydeviced.plist"];
    DDLogDebug(@"findmydevicedSettingsURL=%@", findmydevicedSettingsURL);
    NSDictionary *modifyFindmydevicedSettings = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                  NBCWorkflowModifyTargetURL : [findmydevicedSettingsURL path]
                                                  };
    DDLogDebug(@"modifyFindmydevicedSettings=%@", modifyFindmydevicedSettings);
    [modifyDictArray addObject:modifyFindmydevicedSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.findmymac.plist
    // --------------------------------------------------------------
    NSURL *findmymacSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.findmymac.plist"];
    DDLogDebug(@"findmymacSettingsURL=%@", findmymacSettingsURL);
    NSDictionary *modifyFindmymacSettings = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                              NBCWorkflowModifyTargetURL : [findmymacSettingsURL path]
                                              };
    DDLogDebug(@"modifyFindmymacSettings=%@", modifyFindmymacSettings);
    [modifyDictArray addObject:modifyFindmymacSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.findmymacmessenger.plist
    // --------------------------------------------------------------
    NSURL *findmymacmessengerSettingsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.findmymacmessenger.plist"];
    DDLogDebug(@"findmymacmessengerSettingsURL=%@", findmymacmessengerSettingsURL);
    NSDictionary *modifyFindmymacMessengerSettings = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                       NBCWorkflowModifyTargetURL : [findmymacmessengerSettingsURL path]
                                                       };
    DDLogDebug(@"modifyFindmymacMessengerSettings=%@", modifyFindmymacMessengerSettings);
    [modifyDictArray addObject:modifyFindmymacMessengerSettings];
    
    // --------------------------------------------------------------
    //  /System/Library/PrivateFrameworks/FindMyDevice.framework
    // --------------------------------------------------------------
    NSURL *findmydeviceFrameworkURL = [volumeURL URLByAppendingPathComponent:@"System/Library/PrivateFrameworks/FindMyDevice.framework"];
    DDLogDebug(@"findmydeviceFrameworkURL=%@", findmydeviceFrameworkURL);
    NSDictionary *modifyFindmydeviceFramework = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                  NBCWorkflowModifyTargetURL : [findmydeviceFrameworkURL path]
                                                  };
    DDLogDebug(@"modifyFindmydeviceFramework=%@", modifyFindmydeviceFramework);
    [modifyDictArray addObject:modifyFindmydeviceFramework];
    
    // --------------------------------------------------------------
    //  /System/Library/PrivateFrameworks/FindMyMac.framework
    // --------------------------------------------------------------
    NSURL *findmymacFrameworkURL = [volumeURL URLByAppendingPathComponent:@"System/Library/PrivateFrameworks/FindMyMac.framework"];
    DDLogDebug(@"findmymacFrameworkURL=%@", findmymacFrameworkURL);
    NSDictionary *modifyFindmymacFramework = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                               NBCWorkflowModifyTargetURL : [findmymacFrameworkURL path]
                                               };
    DDLogDebug(@"modifyFindmymacFramework=%@", modifyFindmymacFramework);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [workflowItem temporaryNBIURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // ---------------------------------------------------------------
    //  /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
    // ---------------------------------------------------------------
    
    NSURL *bootSettingsURL = [volumeURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    DDLogDebug(@"bootSettingsURL=%@", bootSettingsURL);
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
    DDLogDebug(@"bootSettingsDict=%@", bootSettingsDict);
    DDLogDebug(@"bootSettingsAttributes=%@", bootSettingsAttributes);
    if ( [bootSettingsDict[@"Kernel Flags"] length] != 0 ) {
        NSString *currentKernelFlags = bootSettingsDict[@"Kernel Flags"];
        bootSettingsDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ -v", currentKernelFlags];
    } else {
        bootSettingsDict[@"Kernel Flags"] = @"-v";
    }
    DDLogDebug(@"bootSettingsDict=%@", bootSettingsDict);
    NSDictionary *modifyBootSettings = @{
                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                         NBCWorkflowModifyContent : bootSettingsDict,
                                         NBCWorkflowModifyAttributes : bootSettingsAttributes,
                                         NBCWorkflowModifyTargetURL : [bootSettingsURL path]
                                         };
    DDLogDebug(@"modifyBootSettings=%@", modifyBootSettings);
    [modifyDictArray addObject:modifyBootSettings];
    
    return retval;
} // modifySettingsForBootPlist

- (BOOL)modifySettingsForSystemKeychain:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Library/Security/Trust Settings
    // --------------------------------------------------------------
    NSURL *folderLibrarySecurityTrustSettings = [volumeURL URLByAppendingPathComponent:@"Library/Security/Trust Settings" isDirectory:YES];
    DDLogDebug(@"folderLibrarySecurityTrustSettings=%@", folderLibrarySecurityTrustSettings);
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
    DDLogDebug(@"modifyFolderLibrarySecurityTrustSettings=%@", modifyFolderLibrarySecurityTrustSettings);
    [modifyDictArray addObject:modifyFolderLibrarySecurityTrustSettings];
    
    // --------------------------------------------------------------
    //  /Library/Security/Trust Settings/Admin.plist
    // --------------------------------------------------------------
    NSURL *systemKeychainTrustSettingsURL = [volumeURL URLByAppendingPathComponent:@"Library/Security/Trust Settings/Admin.plist"];
    DDLogDebug(@"systemKeychainTrustSettingsURL=%@", systemKeychainTrustSettingsURL);
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
    DDLogDebug(@"systemKeychainTrustSettingsDict=%@", systemKeychainTrustSettingsDict);
    DDLogDebug(@"systemKeychainTrustSettingsAttributes=%@", systemKeychainTrustSettingsAttributes);
    systemKeychainTrustSettingsDict[@"trustList"] = @{};
    systemKeychainTrustSettingsDict[@"trustVersion"] = @0;
    DDLogDebug(@"systemKeychainTrustSettingsDict=%@", systemKeychainTrustSettingsDict);
    NSDictionary *modifyDictSystemKeychainTrustSettings = @{
                                                            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                            NBCWorkflowModifyContent : systemKeychainTrustSettingsDict,
                                                            NBCWorkflowModifyAttributes : systemKeychainTrustSettingsAttributes,
                                                            NBCWorkflowModifyTargetURL : [systemKeychainTrustSettingsURL path]
                                                            };
    DDLogDebug(@"modifyDictSystemKeychainTrustSettings=%@", modifyDictSystemKeychainTrustSettings);
    [modifyDictArray addObject:modifyDictSystemKeychainTrustSettings];
    
    return retval;
} // modifySettingsForSystemKeychain:workflowItem

- (NSNumber *)keyboardLayoutIDFromSourceID:(NSString *)sourceID {
#pragma unused(sourceID)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"sourceID=%@", sourceID);
    
    NSNumber *keyboardLayoutID;
    keyboardLayoutID = [NSNumber numberWithInt:7];
    DDLogDebug(@"keyboardLayoutID=%@", keyboardLayoutID);
    
    return keyboardLayoutID;
} // keyboardLayoutIDFromSourceID

- (BOOL)modifySettingsForKextd:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Adding language and keyboard settings...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
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
    DDLogDebug(@"kextdLaunchDaemonURL=%@", kextdLaunchDaemonURL);
    
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
    DDLogDebug(@"kextdLaunchDaemonDict=%@", kextdLaunchDaemonDict);
    DDLogDebug(@"kextdLaunchDaemonAttributes=%@", kextdLaunchDaemonAttributes);
    NSMutableArray *kextdProgramArguments = [NSMutableArray arrayWithArray:kextdLaunchDaemonDict[@"ProgramArguments"]];
    [kextdProgramArguments addObject:@"-no-caches"];
    kextdLaunchDaemonDict[@"ProgramArguments"] = kextdProgramArguments;
    
    NSDictionary *modifyKextdLauncDaemon = @{
                                             NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                             NBCWorkflowModifyContent : kextdLaunchDaemonDict,
                                             NBCWorkflowModifyAttributes : kextdLaunchDaemonAttributes,
                                             NBCWorkflowModifyTargetURL : [kextdLaunchDaemonURL path]
                                             };
    DDLogDebug(@"modifyKextdLauncDaemon=%@", modifyKextdLauncDaemon);
    [modifyDictArray addObject:modifyKextdLauncDaemon];
    
    return retval;
} // modifySettingsForKextd:workflowItem

- (BOOL)modifySettingsForLanguageAndKeyboardLayout:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Adding language and keyboard settings...");
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    NSDictionary *resourceSettings = [workflowItem resourcesSettings];
    DDLogDebug(@"resourceSettings=%@", resourceSettings);
    
    // ------------------------------------------------------------------
    //  /Library/Preferences/com.apple.HIToolbox.plist (Keyboard Layout)
    // ------------------------------------------------------------------
    NSDictionary *hiToolboxPreferencesAttributes;
    NSMutableDictionary *hiToolboxPreferencesDict;
    NSURL *hiToolboxPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.HIToolbox.plist"];
    DDLogDebug(@"hiToolboxPreferencesURL=%@", hiToolboxPreferencesURL);
    
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
    DDLogDebug(@"hiToolboxPreferencesDict=%@", hiToolboxPreferencesDict);
    DDLogDebug(@"hiToolboxPreferencesAttributes=%@", hiToolboxPreferencesAttributes);
    NSString *selectedKeyboardLayoutSourceID = resourceSettings[NBCSettingsNBIKeyboardLayout];
    DDLogDebug(@"selectedKeyboardLayoutSourceID=%@", selectedKeyboardLayoutSourceID);
    NSString *selectedKeyboardName = resourceSettings[NBCSettingsNBIKeyboardLayoutName];
    DDLogDebug(@"selectedKeyboardName=%@", selectedKeyboardName);
    NSNumber *keyboardLayoutID = [self keyboardLayoutIDFromSourceID:selectedKeyboardLayoutSourceID];
    DDLogDebug(@"keyboardLayoutID=%@", keyboardLayoutID);
    NSDictionary *keyboardDict = @{
                                   @"InputSourceKind" : @"Keyboard Layout",
                                   @"KeyboardLayout ID" : keyboardLayoutID,
                                   @"KeyboardLayout Name" : selectedKeyboardName
                                   };
    DDLogDebug(@"keyboardDict=%@", keyboardDict);
    hiToolboxPreferencesDict[@"AppleCurrentKeyboardLayoutInputSourceID"] = selectedKeyboardLayoutSourceID;
    hiToolboxPreferencesDict[@"AppleDefaultAsciiInputSource"] = keyboardDict;
    hiToolboxPreferencesDict[@"AppleEnabledInputSources"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleInputSourceHistory"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleSelectedInputSources"] = @[ keyboardDict ];
    DDLogDebug(@"hiToolboxPreferencesDict=%@", hiToolboxPreferencesDict);
    NSDictionary *modifyDictHiToolboxPreferences = @{
                                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                     NBCWorkflowModifyContent : hiToolboxPreferencesDict,
                                                     NBCWorkflowModifyAttributes : hiToolboxPreferencesAttributes,
                                                     NBCWorkflowModifyTargetURL : [hiToolboxPreferencesURL path]
                                                     };
    DDLogDebug(@"modifyDictHiToolboxPreferences=%@", modifyDictHiToolboxPreferences);
    [modifyDictArray addObject:modifyDictHiToolboxPreferences];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/.GlobalPreferences.plist (Language)
    // --------------------------------------------------------------
    NSURL *globalPreferencesRootURL = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/.GlobalPreferences.plist"];
    DDLogDebug(@"globalPreferencesRootURL=%@", globalPreferencesRootURL);
    NSURL *globalPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
    DDLogDebug(@"globalPreferencesURL=%@", globalPreferencesURL);
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
    DDLogDebug(@"globalPreferencesDict=%@", globalPreferencesDict);
    DDLogDebug(@"globalPreferencesAttributes=%@", globalPreferencesAttributes);
    NSString *selectedLanguage = resourceSettings[NBCSettingsNBILanguage];
    DDLogDebug(@"selectedLanguage=%@", selectedLanguage);
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
    
    DDLogDebug(@"globalPreferencesDict=%@", globalPreferencesDict);
    NSDictionary *modifyDictGlobalPreferences = @{
                                                  NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                  NBCWorkflowModifyContent : globalPreferencesDict,
                                                  NBCWorkflowModifyAttributes : globalPreferencesAttributes,
                                                  NBCWorkflowModifyTargetURL : [globalPreferencesURL path]
                                                  };
    DDLogDebug(@"modifyDictGlobalPreferences=%@", modifyDictGlobalPreferences);
    [modifyDictArray addObject:modifyDictGlobalPreferences];
    
    NSDictionary *modifyDictGlobalPreferencesRoot = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                      NBCWorkflowModifyContent : globalPreferencesDict,
                                                      NBCWorkflowModifyAttributes : globalPreferencesAttributes,
                                                      NBCWorkflowModifyTargetURL : [globalPreferencesRootURL path]
                                                      };
    DDLogDebug(@"modifyDictGlobalPreferencesRoot=%@", modifyDictGlobalPreferencesRoot);
    [modifyDictArray addObject:modifyDictGlobalPreferencesRoot];
    
    // --------------------------------------------------------------
    //  /private/var/log/CDIS.custom (Setup Assistant Language)
    // --------------------------------------------------------------
    NSURL *csdisURL = [volumeURL URLByAppendingPathComponent:@"private/var/log/CDIS.custom"];
    DDLogDebug(@"csdisURL=%@", csdisURL);
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
        DDLogDebug(@"modifyCdis=%@", modifyCdis);
        [modifyDictArray addObject:modifyCdis];
    }
    return retval;
} // modifySettingsForLanguageAndKeyboardLayout

- (BOOL)modifySettingsForMenuBar:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"modifyDictArray=%@", modifyDictArray);
    BOOL retval = YES;
    NSError *error;
    NSDictionary *systemUIServerPreferencesAttributes;
    NSMutableDictionary *systemUIServerPreferencesDict;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    NSDictionary *resourceSettings = [workflowItem resourcesSettings];
    DDLogDebug(@"resourceSettings=%@", resourceSettings);
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.systemuiserver.plist
    // --------------------------------------------------------------
    NSURL *systemUIServerPreferencesURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.systemuiserver.plist"];
    DDLogDebug(@"systemUIServerPreferencesURL=%@", systemUIServerPreferencesURL);
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
    DDLogDebug(@"systemUIServerPreferencesDict=%@", systemUIServerPreferencesDict);
    DDLogDebug(@"systemUIServerPreferencesAttributes=%@", systemUIServerPreferencesAttributes);
    systemUIServerPreferencesDict[@"menuExtras"] = @[
                                                     @"/System/Library/CoreServices/Menu Extras/TextInput.menu",
                                                     @"/System/Library/CoreServices/Menu Extras/Battery.menu",
                                                     @"/System/Library/CoreServices/Menu Extras/Clock.menu"
                                                     ];
    DDLogDebug(@"systemUIServerPreferencesDict=%@", systemUIServerPreferencesDict);
    NSDictionary *modifyDictSystemUIServerPreferences = @{
                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                          NBCWorkflowModifyContent : systemUIServerPreferencesDict,
                                                          NBCWorkflowModifyAttributes : systemUIServerPreferencesAttributes,
                                                          NBCWorkflowModifyTargetURL : [systemUIServerPreferencesURL path]
                                                          };
    DDLogDebug(@"modifyDictSystemUIServerPreferences=%@", modifyDictSystemUIServerPreferences);
    [modifyDictArray addObject:modifyDictSystemUIServerPreferences];
    
    // --------------------------------------------------------------
    //  /Library/LaunchAgents/com.apple.SystemUIServer.plist
    // --------------------------------------------------------------
    NSURL *systemUIServerLaunchAgentURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.SystemUIServer.plist"];
    DDLogDebug(@"systemUIServerLaunchAgentURL=%@", systemUIServerLaunchAgentURL);
    NSURL *systemUIServerLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.SystemUIServer.plist"];
    DDLogDebug(@"systemUIServerLaunchDaemonURL=%@", systemUIServerLaunchDaemonURL);
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
    DDLogDebug(@"systemUIServerDict=%@", systemUIServerDict);
    DDLogDebug(@"systemUIServerAttributes=%@", systemUIServerAttributes);
    systemUIServerDict[@"RunAtLoad"] = @YES;
    systemUIServerDict[@"Disabled"] = @NO;
    systemUIServerDict[@"POSIXSpawnType"] = @"Interactive";
    [systemUIServerDict removeObjectForKey:@"KeepAlive"];
    DDLogDebug(@"systemUIServerDict=%@", systemUIServerDict);
    NSDictionary *modifyDictSystemUIServer = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                               NBCWorkflowModifyContent : systemUIServerDict,
                                               NBCWorkflowModifyAttributes : systemUIServerAttributes,
                                               NBCWorkflowModifyTargetURL : [systemUIServerLaunchDaemonURL path]
                                               };
    DDLogDebug(@"modifyDictSystemUIServer=%@", modifyDictSystemUIServer);
    [modifyDictArray addObject:modifyDictSystemUIServer];
    
    NSDictionary *modifySystemUIServerLaunchAgent = @{
                                                      NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                                      NBCWorkflowModifyTargetURL : [systemUIServerLaunchAgentURL path]
                                                      };
    DDLogDebug(@"modifySystemUIServerLaunchAgent=%@", modifySystemUIServerLaunchAgent);
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
    
    NSString *selectedTimeZone = resourceSettings[NBCSettingsNBITimeZone];
    NSLog(@"selectedTimeZone=%@", selectedTimeZone);
    if ( [selectedTimeZone length] != 0 ) {
        NSURL *localtimeTargetURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/usr/share/zoneinfo/%@", selectedTimeZone]];
        
        NSDictionary *modifyLocaltime = @{
                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeLink,
                                          NBCWorkflowModifySourceURL : [localtimeURL path],
                                          NBCWorkflowModifyTargetURL : [localtimeTargetURL path]
                                          };
        
        [modifyDictArray addObject:modifyLocaltime];
    }
    
    /*
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.menuextra.textinput.plist
    // --------------------------------------------------------------
    NSURL *menuextraTextinputSettingsURL = [volumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/com.apple.menuextra.textinput.plist"];
    DDLogDebug(@"menuextraTextinputSettingsURL=%@", menuextraTextinputSettingsURL);
    NSMutableDictionary *menuextraTextinputSettingsDict;
    NSDictionary *menuextraTextinputSettingsAttributes;
    if ( [menuextraTextinputSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        menuextraTextinputSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:menuextraTextinputSettingsURL];
        menuextraTextinputSettingsAttributes = [fm attributesOfItemAtPath:[menuextraTextinputSettingsURL path] error:&error];
    }
    
    if ( [menuextraTextinputSettingsDict count] == 0 ) {
        menuextraTextinputSettingsDict = [[NSMutableDictionary alloc] init];
        menuextraTextinputSettingsAttributes = @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0644
                                                 };
    }
    DDLogDebug(@"menuextraTextinputSettingsDict=%@", menuextraTextinputSettingsDict);
    DDLogDebug(@"menuextraTextinputSettingsAttributes=%@", menuextraTextinputSettingsAttributes);
    menuextraTextinputSettingsDict[@"ModeNameVisible"] = @NO;
    DDLogDebug(@"menuextraTextinputSettingsDict=%@", menuextraTextinputSettingsDict);
    NSDictionary *modifyMenuextraTextinputSettings = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                       NBCWorkflowModifyContent : menuextraTextinputSettingsDict,
                                                       NBCWorkflowModifyAttributes : menuextraTextinputSettingsAttributes,
                                                       NBCWorkflowModifyTargetURL : [menuextraTextinputSettingsURL path]
                                                       };
    DDLogDebug(@"modifyMenuextraTextinputSettings=%@", modifyMenuextraTextinputSettings);
    [modifyDictArray addObject:modifyMenuextraTextinputSettings];
    */
    /*
     // --------------------------------------------------------------
     //  /Library/LaunchDaemons/com.apple.iconservices.iconservicesd.plist
     // --------------------------------------------------------------
     NSURL *iconservicesdLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.iconservices.iconservicesd.plist"];
     
     NSMutableDictionary *iconservicesdLaunchDaemonDict;
     NSDictionary *iconservicesdLaunchDaemonAttributes;
     if ( [iconservicesdLaunchDaemonURL checkResourceIsReachableAndReturnError:nil] ) {
     iconservicesdLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:iconservicesdLaunchDaemonURL];
     iconservicesdLaunchDaemonAttributes = [fm attributesOfItemAtPath:[iconservicesdLaunchDaemonURL path] error:&error];
     }
     
     if ( [iconservicesdLaunchDaemonDict count] == 0 ) {
     iconservicesdLaunchDaemonDict = [[NSMutableDictionary alloc] init];
     iconservicesdLaunchDaemonAttributes = @{
     NSFileOwnerAccountName : @"root",
     NSFileGroupOwnerAccountName : @"wheel",
     NSFilePosixPermissions : @0644
     };
     }
     
     iconservicesdLaunchDaemonDict[@"RunAtLoad"] = @NO;
     iconservicesdLaunchDaemonDict[@"Disabled"] = @YES;
     
     NSDictionary *modifyIconservicesdLaunchDaemon = @{
     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
     NBCWorkflowModifyContent : iconservicesdLaunchDaemonDict,
     NBCWorkflowModifyAttributes : iconservicesdLaunchDaemonAttributes,
     NBCWorkflowModifyTargetURL : [iconservicesdLaunchDaemonURL path]
     };
     
     [modifyDictArray addObject:modifyIconservicesdLaunchDaemon];
     */
    
    /*
     // --------------------------------------------------------------
     //  /System/Library/Frameworks/PreferencePanes.framework/Resources/global.defaults
     // --------------------------------------------------------------
     NSURL *globalDefaultsURL = [volumeURL URLByAppendingPathComponent:@"System/Library/Frameworks/PreferencePanes.framework/Resources/global.defaults"];
     
     NSMutableDictionary *globalDefaultsDict;
     NSDictionary *globalDefaultsAttributes;
     if ( [globalDefaultsURL checkResourceIsReachableAndReturnError:nil] ) {
     globalDefaultsDict = [NSMutableDictionary dictionaryWithContentsOfURL:globalDefaultsURL];
     globalDefaultsAttributes = [fm attributesOfItemAtPath:[globalDefaultsURL path] error:&error];
     }
     
     if ( [globalDefaultsDict count] == 0 ) {
     globalDefaultsDict = [[NSMutableDictionary alloc] init];
     globalDefaultsAttributes = @{
     NSFileOwnerAccountName : @"root",
     NSFileGroupOwnerAccountName : @"wheel",
     NSFilePosixPermissions : @0644
     };
     }
     NSDictionary *resourceSettings = [workflowItem resourcesSettings];
     DDLogDebug(@"resourceSettings=%@", resourceSettings);
     NSString *selectedTimeZone = resourceSettings[NBCSettingsNBITimeZone];
     NSLog(@"selectedTimeZone=%@", selectedTimeZone);
     if ( [selectedTimeZone length] != 0 ) {
     globalDefaultsDict[@"TimeZoneLabel"] = selectedTimeZone;
     }
     
     NSDictionary *modifyGlobalDefaults = @{
     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
     NBCWorkflowModifyContent : globalDefaultsDict,
     NBCWorkflowModifyAttributes : globalDefaultsAttributes,
     NBCWorkflowModifyTargetURL : [globalDefaultsURL path]
     };
     
     [modifyDictArray addObject:modifyGlobalDefaults];
     */
    
    return retval;
} // modifySettingsForMenuBar

- (BOOL)modifySettingsForVNC:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteManagement.plist
    // --------------------------------------------------------------
    NSURL *remoteManagementURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteManagement.plist"];
    DDLogDebug(@"remoteManagementURL=%@", remoteManagementURL);
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
    DDLogDebug(@"remoteManagementDict=%@", remoteManagementDict);
    DDLogDebug(@"remoteManagementAttributes=%@", remoteManagementAttributes);
    remoteManagementDict[@"ARD_AllLocalUsers"] = @YES;
    remoteManagementDict[@"ARD_AllLocalUsersPrivs"] = @-1073741569;
    remoteManagementDict[@"DisableKerberos"] = @NO;
    remoteManagementDict[@"ScreenSharingReqPermEnabled"] = @NO;
    remoteManagementDict[@"VNCLegacyConnectionsEnabled"] = @YES;
    DDLogDebug(@"remoteManagementDict=%@", remoteManagementDict);
    NSDictionary *modifyDictRemoteManagement = @{
                                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                 NBCWorkflowModifyContent : remoteManagementDict,
                                                 NBCWorkflowModifyAttributes : remoteManagementAttributes,
                                                 NBCWorkflowModifyTargetURL : [remoteManagementURL path]
                                                 };
    DDLogDebug(@"modifyDictRemoteManagement=%@", modifyDictRemoteManagement);
    [modifyDictArray addObject:modifyDictRemoteManagement];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.screensharing.plist
    // --------------------------------------------------------------
    NSURL *screensharingLaunchDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.screensharing.plist"];
    DDLogDebug(@"screensharingLaunchDaemonURL=%@", screensharingLaunchDaemonURL);
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
    DDLogDebug(@"screensharingLaunchDaemonDict=%@", screensharingLaunchDaemonDict);
    DDLogDebug(@"screensharingLaunchDaemonAttributes=%@", screensharingLaunchDaemonAttributes);
    screensharingLaunchDaemonDict[@"UserName"] = @"root";
    screensharingLaunchDaemonDict[@"GroupName"] = @"wheel";
    DDLogDebug(@"screensharingLaunchDaemonDict=%@", screensharingLaunchDaemonDict);
    NSDictionary *modifyDictScreensharingLaunchDaemon = @{
                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                          NBCWorkflowModifyContent : screensharingLaunchDaemonDict,
                                                          NBCWorkflowModifyTargetURL : [screensharingLaunchDaemonURL path],
                                                          NBCWorkflowModifyAttributes : screensharingLaunchDaemonAttributes
                                                          };
    DDLogDebug(@"modifyDictScreensharingLaunchDaemon=%@", modifyDictScreensharingLaunchDaemon);
    [modifyDictArray addObject:modifyDictScreensharingLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopPrivilegeProxyDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist"];
    DDLogDebug(@"remoteDesktopPrivilegeProxyDaemonURL=%@", remoteDesktopPrivilegeProxyDaemonURL);
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
    DDLogDebug(@"remoteDesktopPrivilegeProxyLaunchDaemonDict=%@", remoteDesktopPrivilegeProxyLaunchDaemonDict);
    DDLogDebug(@"remoteDesktopPrivilegeProxyLaunchDaemonAttributes=%@", remoteDesktopPrivilegeProxyLaunchDaemonAttributes);
    remoteDesktopPrivilegeProxyLaunchDaemonDict[@"UserName"] = @"root";
    remoteDesktopPrivilegeProxyLaunchDaemonDict[@"GroupName"] = @"wheel";
    DDLogDebug(@"remoteDesktopPrivilegeProxyLaunchDaemonDict=%@", remoteDesktopPrivilegeProxyLaunchDaemonDict);
    NSDictionary *modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon = @{
                                                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                                        NBCWorkflowModifyContent : remoteDesktopPrivilegeProxyLaunchDaemonDict,
                                                                        NBCWorkflowModifyTargetURL : [remoteDesktopPrivilegeProxyDaemonURL path],
                                                                        NBCWorkflowModifyAttributes : remoteDesktopPrivilegeProxyLaunchDaemonAttributes
                                                                        };
    DDLogDebug(@"modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon=%@", modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon);
    [modifyDictArray addObject:modifyDictRemoteDesktopPrivilegeProxyLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.agent.plist
    // --------------------------------------------------------------
    NSURL *screensharingAgentDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.agent.plist"];
    DDLogDebug(@"screensharingAgentDaemonURL=%@", screensharingAgentDaemonURL);
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
    DDLogDebug(@"screensharingAgentLaunchDaemonDict=%@", screensharingAgentLaunchDaemonDict);
    DDLogDebug(@"screensharingAgentLaunchDaemonAttributes=%@", screensharingAgentLaunchDaemonAttributes);
    screensharingAgentLaunchDaemonDict[@"RunAtLoad"] = @YES;
    [screensharingAgentLaunchDaemonDict removeObjectForKey:@"LimitLoadToSessionType"];
    DDLogDebug(@"screensharingAgentLaunchDaemonDict=%@", screensharingAgentLaunchDaemonDict);
    NSDictionary *modifyDictScreensharingAgentLaunchDaemon = @{
                                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                               NBCWorkflowModifyContent : screensharingAgentLaunchDaemonDict,
                                                               NBCWorkflowModifyTargetURL : [screensharingAgentDaemonURL path],
                                                               NBCWorkflowModifyAttributes : screensharingAgentLaunchDaemonAttributes
                                                               };
    DDLogDebug(@"modifyDictScreensharingAgentLaunchDaemon=%@", modifyDictScreensharingAgentLaunchDaemon);
    [modifyDictArray addObject:modifyDictScreensharingAgentLaunchDaemon];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist
    // --------------------------------------------------------------
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    DDLogDebug(@"sourceVersionMinor=%d", sourceVersionMinor);
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
        DDLogDebug(@"screensharingMessagesAgentLaunchAgentDict=%@", screensharingMessagesAgentLaunchAgentDict);
        if ( [screensharingMessagesAgentLaunchAgentAttributes count] == 0 ) {
            screensharingMessagesAgentLaunchAgentAttributes = @{
                                                                NSFileOwnerAccountName : @"root",
                                                                NSFileGroupOwnerAccountName : @"wheel",
                                                                NSFilePosixPermissions : @0644
                                                                };
        }
        DDLogDebug(@"screensharingMessagesAgentLaunchAgentAttributes=%@", screensharingMessagesAgentLaunchAgentAttributes);
        NSDictionary *modifyDictScreensharingMessagesAgentLaunchAgent = @{
                                                                          NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                                          NBCWorkflowModifyContent : screensharingMessagesAgentLaunchAgentDict,
                                                                          NBCWorkflowModifyTargetURL : [screensharingMessagesAgentDaemonURL path],
                                                                          NBCWorkflowModifyAttributes : screensharingMessagesAgentLaunchAgentAttributes
                                                                          };
        DDLogDebug(@"modifyDictScreensharingMessagesAgentLaunchAgent=%@", modifyDictScreensharingMessagesAgentLaunchAgent);
        [modifyDictArray addObject:modifyDictScreensharingMessagesAgentLaunchAgent];
    } else {
        DDLogDebug(@"MessagesAgent isn't available in 10.7 or lower.");
    }
    
    // --------------------------------------------------------------
    //  /etc/com.apple.screensharing.agent.launchd
    // --------------------------------------------------------------
    NSURL *etcScreensharingAgentLaunchdURL = [volumeURL URLByAppendingPathComponent:@"etc/com.apple.screensharing.agent.launchd"];
    DDLogDebug(@"etcScreensharingAgentLaunchdURL=%@", etcScreensharingAgentLaunchdURL);
    NSString *etcScreensharingAgentLaunchdContentString = @"enabled\n";
    NSData *etcScreensharingAgentLaunchdContentData = [etcScreensharingAgentLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *etcScreensharingAgentLaunchdAttributes = @{
                                                             NSFileOwnerAccountName : @"root",
                                                             NSFileGroupOwnerAccountName : @"wheel",
                                                             NSFilePosixPermissions : @0644
                                                             };
    DDLogDebug(@"etcScreensharingAgentLaunchdAttributes=%@", etcScreensharingAgentLaunchdAttributes);
    NSDictionary *modifyEtcScreensharingAgentLaunchd = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                         NBCWorkflowModifyContent : etcScreensharingAgentLaunchdContentData,
                                                         NBCWorkflowModifyTargetURL : [etcScreensharingAgentLaunchdURL path],
                                                         NBCWorkflowModifyAttributes : etcScreensharingAgentLaunchdAttributes
                                                         };
    DDLogDebug(@"modifyEtcScreensharingAgentLaunchd=%@", modifyEtcScreensharingAgentLaunchd);
    [modifyDictArray addObject:modifyEtcScreensharingAgentLaunchd];
    
    // --------------------------------------------------------------
    //  /etc/RemoteManagement.launchd
    // --------------------------------------------------------------
    NSURL *etcRemoteManagementLaunchdURL = [volumeURL URLByAppendingPathComponent:@"etc/RemoteManagement.launchd"];
    DDLogDebug(@"etcRemoteManagementLaunchdURL=%@", etcRemoteManagementLaunchdURL);
    NSString *etcRemoteManagementLaunchdContentString = @"enabled\n";
    NSData *etcRemoteManagementLaunchdContentData = [etcRemoteManagementLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *etcRemoteManagementLaunchdAttributes = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644
                                                           };
    DDLogDebug(@"etcRemoteManagementLaunchdAttributes=%@", etcRemoteManagementLaunchdAttributes);
    NSDictionary *modifyEtcRemoteManagementLaunchd = @{
                                                       NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                                       NBCWorkflowModifyContent : etcRemoteManagementLaunchdContentData,
                                                       NBCWorkflowModifyTargetURL : [etcRemoteManagementLaunchdURL path],
                                                       NBCWorkflowModifyAttributes : etcRemoteManagementLaunchdAttributes
                                                       };
    DDLogDebug(@"modifyEtcRemoteManagementLaunchd=%@", modifyEtcRemoteManagementLaunchd);
    [modifyDictArray addObject:modifyEtcRemoteManagementLaunchd];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopDaemonURL = [volumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.RemoteDesktop.plist"];
    DDLogDebug(@"remoteDesktopDaemonURL=%@", remoteDesktopDaemonURL);
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
    DDLogDebug(@"remoteDesktopLaunchAgentDict=%@", remoteDesktopLaunchAgentDict);
    DDLogDebug(@"remoteDesktopLaunchAgentAttributes=%@", remoteDesktopLaunchAgentAttributes);
    [remoteDesktopLaunchAgentDict removeObjectForKey:@"LimitLoadToSessionType"];
    DDLogDebug(@"remoteDesktopLaunchAgentDict=%@", remoteDesktopLaunchAgentDict);
    NSDictionary *modifyDictRemoteDesktopLaunchAgent = @{
                                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                                         NBCWorkflowModifyContent : remoteDesktopLaunchAgentDict,
                                                         NBCWorkflowModifyTargetURL : [remoteDesktopDaemonURL path],
                                                         NBCWorkflowModifyAttributes : remoteDesktopLaunchAgentAttributes
                                                         };
    DDLogDebug(@"modifyDictRemoteDesktopLaunchAgent=%@", modifyDictRemoteDesktopLaunchAgent);
    [modifyDictArray addObject:modifyDictRemoteDesktopLaunchAgent];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopURL = [volumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteDesktop.plist"];
    DDLogDebug(@"remoteDesktopURL=%@", remoteDesktopURL);
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
    DDLogDebug(@"remoteDesktopDict=%@", remoteDesktopDict);
    DDLogDebug(@"remoteDesktopAttributes=%@", remoteDesktopAttributes);
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
    DDLogDebug(@"remoteDesktopDict=%@", remoteDesktopDict);
    NSDictionary *modifyDictRemoteDesktop = @{
                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                                              NBCWorkflowModifyContent : remoteDesktopDict,
                                              NBCWorkflowModifyTargetURL : [remoteDesktopURL path],
                                              NBCWorkflowModifyAttributes : remoteDesktopAttributes
                                              };
    DDLogDebug(@"modifyDictRemoteDesktop=%@", modifyDictRemoteDesktop);
    [modifyDictArray addObject:modifyDictRemoteDesktop];
    
    return retval;
} // modifySettingsForVNC:workflowItem

- (BOOL)modifySettingsForRCCdrom:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
#pragma unused(modifyDictArray)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Disabling WiFi in NBI...");
    BOOL retval = YES;
    NSError *error;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /etc/rc.cdm.cdrom
    // --------------------------------------------------------------
    NSURL *rcCdromURL = [volumeURL URLByAppendingPathComponent:@"etc/rc.cdrom"];
    NSURL *rcCdmCdromURL = [volumeURL URLByAppendingPathComponent:@"etc/rc.cdm.cdrom"];
    DDLogDebug(@"rcCdromURL=%@", rcCdromURL);
    
    if ( [rcCdromURL checkResourceIsReachableAndReturnError:nil] ) {
        
        NSString *rcCdromOriginal = [NSString stringWithContentsOfURL:rcCdromURL encoding:NSUTF8StringEncoding error:&error];
        DDLogDebug(@"rcCdromOriginal=%@", rcCdromOriginal);
        
        __block NSMutableString *rcCdmCdrom = [[NSMutableString alloc] init];
        __block BOOL inspectNextLine = NO;
        __block BOOL copyNextLine = NO;
        [rcCdromOriginal enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
#pragma unused(stop)
            if ( copyNextLine ) {
                if ( [line hasPrefix:@"fi"] ) {
                    *stop = YES;
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
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db/com.apple.launchd 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/dslocal/nodes/Default/users 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/folders 12288\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs 16384\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs/DiagnosticReports 4096\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Caches 65536\n"];
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
        DDLogDebug(@"modifyRcCdmCdrom=%@", modifyRcCdmCdrom);
        [modifyDictArray addObject:modifyRcCdmCdrom];
    } else {
        DDLogError(@"[ERROR] rcCdromURL doesn't exist!");
        DDLogError(@"[ERROR] %@", error);
        return NO;
    }
    
    return retval;
}

- (BOOL)modifyNBIRemoveWiFi:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Disabling WiFi in NBI...");
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    NSURL *wifiKext = [volumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    DDLogDebug(@"wifiKext=%@", wifiKext);
    NSDictionary *modifyWifiKext = @{
                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                     NBCWorkflowModifyTargetURL : [wifiKext path]
                                     };
    DDLogDebug(@"modifyWifiKext=%@", modifyWifiKext);
    [modifyDictArray addObject:modifyWifiKext];
    
    // --------------------------------------------------------------
    //  /System/Library/CoreServices/Menu Extras/AirPort.menu
    // --------------------------------------------------------------
    NSURL *airPortMenuURL = [volumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras/AirPort.menu"];
    DDLogDebug(@"airPortMenuURL=%@", airPortMenuURL);
    NSDictionary *modifyAirPortMenu = @{
                                        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete,
                                        NBCWorkflowModifyTargetURL : [airPortMenuURL path]
                                        };
    DDLogDebug(@"modifyAirPortMenu=%@", modifyAirPortMenu);
    [modifyDictArray addObject:modifyAirPortMenu];
    
    return retval;
} // modifyNBIRemoveWiFi

- (BOOL)modifyNBINTP:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
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
    DDLogDebug(@"ntpServer=%@", ntpServer);
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/dig"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @"+short",
                            ntpServer,
                            nil];
    DDLogDebug(@"%@ %@", [newTask launchPath], [newTask arguments]);
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    DDLogDebug(@"Launching task...");
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskStandardOutputData = [[[newTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    DDLogDebug(@"terminationStatus=%d", [newTask terminationStatus]);
    if ( [newTask terminationStatus] == 0 ) {
        NSString *digOutput = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
        DDLogDebug(@"digOutput=%@", digOutput);
        if ( [digOutput length] != 0 ) {
            NSArray *ntpServerArray = [digOutput componentsSeparatedByString:@"\n"];
            DDLogDebug(@"ntpServerArray=%@", ntpServerArray);
            ntpServer = [NSString stringWithFormat:@"server %@", ntpServer];
            for ( NSString *ntpIP in ntpServerArray ) {
                ntpServer = [ntpServer stringByAppendingString:[NSString stringWithFormat:@"\nserver %@", ntpIP]];
            }
            DDLogDebug(@"ntpServer=%@", ntpServer);
        } else {
            DDLogWarn(@"[WARN] Could not resolve ntp server!");
            // Add to warning report!
        }
    } else {
        DDLogWarn(@"[WARN] Got no output from dig!");
        // Add to warning report!
    }
    
    NSURL *ntpConfURL = [volumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];
    DDLogDebug(@"ntpConfURL=%@", ntpConfURL);
    NSData *ntpConfContentData = [ntpServer dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *ntpConfAttributes = @{
                                        NSFileOwnerAccountName : @"root",
                                        NSFileGroupOwnerAccountName : @"wheel",
                                        NSFilePosixPermissions : @0644
                                        };
    DDLogDebug(@"ntpConfAttributes=%@", ntpConfAttributes);
    NSDictionary *modifyNtpConf = @{
                                    NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                    NBCWorkflowModifyContent : ntpConfContentData,
                                    NBCWorkflowModifyTargetURL : [ntpConfURL path],
                                    NBCWorkflowModifyAttributes : ntpConfAttributes
                                    };
    DDLogDebug(@"modifyNtpConf=%@", modifyNtpConf);
    [modifyDictArray addObject:modifyNtpConf];
    
    return retval;
} // modifyNBINTP

- (BOOL)modifySettingsAddFolders:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    NSURL *volumeURL = [[workflowItem target] baseSystemVolumeURL];
    DDLogDebug(@"volumeURL=%@", volumeURL);
    if ( ! volumeURL ) {
        DDLogError(@"[ERROR] volumeURL is nil");
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /Library/Caches
    // --------------------------------------------------------------
    NSURL *folderLibraryCache = [volumeURL URLByAppendingPathComponent:@"Library/Caches" isDirectory:YES];
    DDLogDebug(@"folderLibraryCache=%@", folderLibraryCache);
    NSDictionary *folderLibraryCacheAttributes = @{
                                                   NSFileOwnerAccountName : @"root",
                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                   NSFilePosixPermissions : @0777
                                                   };
    DDLogDebug(@"folderLibraryCacheAttributes=%@", folderLibraryCacheAttributes);
    NSDictionary *modifyFolderLibraryCache = @{
                                               NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                               NBCWorkflowModifyTargetURL : [folderLibraryCache path],
                                               NBCWorkflowModifyAttributes : folderLibraryCacheAttributes
                                               };
    DDLogDebug(@"modifyFolderLibraryCache=%@", modifyFolderLibraryCache);
    [modifyDictArray addObject:modifyFolderLibraryCache];
    
    /*
     // --------------------------------------------------------------
     //  /Library/Caches/com.apple.iconservices.store
     // --------------------------------------------------------------
     NSURL *folderLibraryCacheIconservices = [volumeURL URLByAppendingPathComponent:@"Library/Caches/com.apple.iconservices.store" isDirectory:YES];
     DDLogDebug(@"folderLibraryCacheIconservices=%@", folderLibraryCacheIconservices);
     NSDictionary *folderLibraryCacheIconservicesAttributes = @{
     NSFileOwnerAccountName : @"root",
     NSFileGroupOwnerAccountName : @"wheel",
     NSFilePosixPermissions : @0755
     };
     DDLogDebug(@"folderLibraryCacheIconservicesAttributes=%@", folderLibraryCacheIconservicesAttributes);
     NSDictionary *modifyFolderLibraryCacheIconservices = @{
     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
     NBCWorkflowModifyTargetURL : [folderLibraryCacheIconservices path],
     NBCWorkflowModifyAttributes : folderLibraryCacheIconservicesAttributes
     };
     DDLogDebug(@"modifyFolderLibraryCacheIconservices=%@", modifyFolderLibraryCacheIconservices);
     [modifyDictArray addObject:modifyFolderLibraryCacheIconservices];
     */
    
    // --------------------------------------------------------------
    //  /System/Library/Caches
    // --------------------------------------------------------------
    NSURL *folderSystemLibraryCache = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches" isDirectory:YES];
    DDLogDebug(@"folderSystemLibraryCache=%@", folderSystemLibraryCache);
    NSDictionary *folderSystemLibraryCacheAttributes = @{
                                                         NSFileOwnerAccountName : @"root",
                                                         NSFileGroupOwnerAccountName : @"wheel",
                                                         NSFilePosixPermissions : @0755
                                                         };
    DDLogDebug(@"folderSystemLibraryCacheAttributes=%@", folderSystemLibraryCacheAttributes);
    NSDictionary *modifyFolderSystemLibraryCache = @{
                                                     NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                     NBCWorkflowModifyTargetURL : [folderSystemLibraryCache path],
                                                     NBCWorkflowModifyAttributes : folderSystemLibraryCacheAttributes
                                                     };
    DDLogDebug(@"modifyFolderSystemLibraryCache=%@", modifyFolderSystemLibraryCache);
    [modifyDictArray addObject:modifyFolderSystemLibraryCache];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.CVMS
    // --------------------------------------------------------------
    NSURL *folderSystemLibraryCVMS = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.CVMS" isDirectory:YES];
    DDLogDebug(@"folderSystemLibraryCVMS=%@", folderSystemLibraryCVMS);
    NSDictionary *folderSystemLibraryCVMSAttributes = @{
                                                        NSFileOwnerAccountName : @"root",
                                                        NSFileGroupOwnerAccountName : @"wheel",
                                                        NSFilePosixPermissions : @0755
                                                        };
    DDLogDebug(@"folderSystemLibraryCVMSAttributes=%@", folderSystemLibraryCVMSAttributes);
    NSDictionary *modifyFolderSystemLibraryCVMS = @{
                                                    NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                    NBCWorkflowModifyTargetURL : [folderSystemLibraryCVMS path],
                                                    NBCWorkflowModifyAttributes : folderSystemLibraryCVMSAttributes
                                                    };
    DDLogDebug(@"modifyFolderSystemLibraryCVMS=%@", modifyFolderSystemLibraryCVMS);
    [modifyDictArray addObject:modifyFolderSystemLibraryCVMS];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.kext.caches/Directories/System/Library/Extensions
    // --------------------------------------------------------------
    NSURL *folderSystemLibraryKextExtensions = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Directories/System/Library/Extensions" isDirectory:YES];
    DDLogDebug(@"folderSystemLibraryKextExtensions=%@", folderSystemLibraryKextExtensions);
    NSDictionary *folderSystemLibraryKextExtensionsAttributes = @{
                                                                  NSFileOwnerAccountName : @"root",
                                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                                  NSFilePosixPermissions : @0755
                                                                  };
    DDLogDebug(@"folderSystemLibraryKextExtensionsAttributes=%@", folderSystemLibraryKextExtensionsAttributes);
    NSDictionary *modifyFolderSystemLibraryKextExtensions = @{
                                                              NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                              NBCWorkflowModifyTargetURL : [folderSystemLibraryKextExtensions path],
                                                              NBCWorkflowModifyAttributes : folderSystemLibraryKextExtensionsAttributes
                                                              };
    DDLogDebug(@"modifyFolderSystemLibraryKextExtensions=%@", modifyFolderSystemLibraryKextExtensions);
    [modifyDictArray addObject:modifyFolderSystemLibraryKextExtensions];
    
    // --------------------------------------------------------------
    //  /System/Library/Caches/com.apple.kext.caches/Startup
    // --------------------------------------------------------------
    NSURL *folderSystemLibraryKextStartup = [volumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup" isDirectory:YES];
    DDLogDebug(@"folderSystemLibraryKextStartup=%@", folderSystemLibraryKextStartup);
    NSDictionary *folderSystemLibraryKextStartupAttributes = @{
                                                               NSFileOwnerAccountName : @"root",
                                                               NSFileGroupOwnerAccountName : @"wheel",
                                                               NSFilePosixPermissions : @0755
                                                               };
    DDLogDebug(@"folderSystemLibraryKextStartupAttributes=%@", folderSystemLibraryKextStartupAttributes);
    NSDictionary *modifyFolderSystemLibraryKextStartup = @{
                                                           NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
                                                           NBCWorkflowModifyTargetURL : [folderSystemLibraryKextStartup path],
                                                           NBCWorkflowModifyAttributes : folderSystemLibraryKextStartupAttributes
                                                           };
    DDLogDebug(@"modifyFolderSystemLibraryKextStartup=%@", modifyFolderSystemLibraryKextStartup);
    [modifyDictArray addObject:modifyFolderSystemLibraryKextStartup];
    
    return retval;
} // modifySettingsAddFolders

- (BOOL)verifyNetInstallFromDiskImageURL:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying NetInstall.dmg...");
    DDLogDebug(@"netInstallDiskImageURL=%@", netInstallDiskImageURL);
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
        DDLogDebug(@"netInstallVolumeURL=%@", netInstallVolumeURL);
        NSURL *baseSystemURL = [netInstallVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying BaseSystem.dmg...");
    BOOL verified = NO;
    
    NSURL *baseSystemDiskImageURL = [target baseSystemURL];
    NSURL *baseSystemVolumeURL;
    
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk != nil ) {
        [target setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        DDLogDebug(@"baseSystemVolumeURL=%@", baseSystemVolumeURL);
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
        DDLogDebug(@"baseSystemVolumeURL=%@", baseSystemVolumeURL);
        NSURL *systemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"systemVersionPlistURL=%@", systemVersionPlistURL);
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            DDLogDebug(@"systemVersionPlist=%@", systemVersionPlist);
            if ( [systemVersionPlist count] != 0 ) {
                NSString *baseSystemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogDebug(@"baseSystemOSVersion=%@", baseSystemOSVersion);
                if ( baseSystemOSVersion != nil ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                } else {
                    DDLogError(@"[ERROR] Unable to read osVersion from SystemVersion.plist");
                    return NO;
                }
                
                NSString *baseSystemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                DDLogDebug(@"baseSystemOSBuild=%@", baseSystemOSBuild);
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
