//
//  NBCSourceController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCSourceController.h"
#import "NBCConstants.h"

#import "NBCSource.h"
#import "NBCController.h"
#import "NBCDisk.h"
#import "NBCDiskImageController.h"
#import "NSString+randomString.h"

@implementation NBCSourceController

// ------------------------------------------------------
//  Drop Destination
// ------------------------------------------------------
- (BOOL)getInstallESDURLfromSourceURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *installESDDiskImageURL;
    NSString *sourceExtension = [[sourceURL path] pathExtension];
    if ( [sourceExtension isEqualToString:@"app"] ) {
        [source setOsxInstallerURL:sourceURL];
        NSBundle *osxInstallerBundle = [NSBundle bundleWithURL:sourceURL];
        if ( osxInstallerBundle ) {
            NSURL *osxInstallerIconURL = [osxInstallerBundle URLForResource:@"InstallAssistant" withExtension:@"icns"];
            if ( osxInstallerIconURL ) {
                [source setOsxInstallerIconURL:osxInstallerIconURL];
                [source setSourceType:NBCSourceTypeInstallerApplication];
            }
            
            installESDDiskImageURL = [[osxInstallerBundle bundleURL] URLByAppendingPathComponent:@"Contents/SharedSupport/InstallESD.dmg"];
            
            verified = YES;
        } else {
            
            NSLog(@"Could not find bundle from source URL");
            verified = NO;
        }
    } else if ( [sourceExtension isEqualToString:@"dmg"] ) {
        installESDDiskImageURL = sourceURL;
        [source setSourceType:NBCSourceTypeInstallESDDiskImage];
        
        verified = YES;
    } else {
        
        NSLog(@"Invalid Source Extension!");
        verified = NO;
    }
    
    if ( verified ) {
        if ( [installESDDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            [source setInstallESDDiskImageURL:installESDDiskImageURL];
            
            verified = YES;
        } else {
            
            NSLog(@"Install ESD URL is invalid!");
            verified = NO;
        }
    }
    
    return verified;
}

// ------------------------------------------------------
//  System
// ------------------------------------------------------

- (BOOL)verifySystemFromDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    
    if ( systemVolumeURL != nil ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeURL:systemVolumeURL];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] == YES ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( systemVersionPlist != nil ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                
                if ( systemOSVersion != nil ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                } else {
                    NSLog(@"Unable to read osVersion from SystemVersion.plist");
                    
                    verified = NO;
                }
                
                NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                
                if ( systemOSBuild != nil ) {
                    [source setSystemOSBuild:systemOSBuild];
                    [source setSourceBuild:systemOSBuild];
                    
                    verified = YES;
                } else {
                    NSLog(@"Unable to read osBuild from SystemVersion.plist");
                }
            } else {
                NSLog(@"No SystemVersion Dict");
                
                verified = NO;
            }
        } else {
            NSLog(@"No System Version Plist");
            
            verified = NO;
        }
    }
    
    return verified;
}

- (BOOL)verifySystemFromDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *systemVolumeURL;
    [source setSystemDiskImageURL:systemDiskImageURL];
    NBCDisk *systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                     imageType:@"System"];
    
    
    
    if ( systemDisk ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        systemVolumeURL = [systemDisk volumeURL];
        
        verified = YES;
    } else {
        NSDictionary *systemDiskImageDict;
        NSArray *hdiutilOptions = @[
                                   @"-mountRandom", @"/Volumes",
                                   @"-nobrowse",
                                   @"-noverify",
                                   @"-plist",
                                   ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&systemDiskImageDict
                                                                  dmgPath:systemDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( systemDiskImageDict ) {
                [source setSystemDiskImageDict:systemDiskImageDict];
                systemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:systemDiskImageDict];
                systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                        imageType:@"System"];
                if ( systemDisk ) {
                    [source setSystemDisk:systemDisk];
                    [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
                    [systemDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                } else {
                    NSLog(@"No System Disk");
                }
            } else {
                NSLog(@"No System Disk Image Dict");
            }
        } else {
            NSLog(@"System Disk Image Attach Failed");
        }
    }
    
    if ( verified && systemVolumeURL != nil ) {
        [source setSystemVolumeURL:systemVolumeURL];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] == YES ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( systemVersionPlist != nil ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                
                if ( systemOSVersion != nil ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                } else {
                    NSLog(@"Unable to read osVersion from SystemVersion.plist");
                    
                    verified = NO;
                }
                
                NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                
                if ( systemOSBuild != nil ) {
                    [source setSystemOSBuild:systemOSBuild];
                    [source setSourceBuild:systemOSBuild];
                } else {
                    NSLog(@"Unable to read osBuild from SystemVersion.plist");
                }
            } else {
                NSLog(@"No SystemVersion Dict");
                
                verified = NO;
            }
        } else {
            NSLog(@"No System Version Plist");
            
            verified = NO;
        }
    }
    
    return verified;
}

// ------------------------------------------------------
//  Recovery Partition
// ------------------------------------------------------

- (BOOL)verifyRecoveryPartitionFromSystemDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    NSURL *recoveryVolumeURL;
    if ( systemVolumeURL != nil ) {
        NSString *recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromVolumeMountURL:systemVolumeURL];
        
        if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            NBCDisk *recoveryDisk = [NBCController diskFromBSDName:recoveryPartitionDiskIdentifier];
            if ( [recoveryDisk isMounted] ) {
                [source setRecoveryDisk:recoveryDisk];
                recoveryVolumeURL = [recoveryDisk volumeURL];
                [source setRecoveryVolumeURL:recoveryVolumeURL];
                
                verified = YES;
            } else {
                recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
                NSArray *diskutilOptions = @[
                                            @"rdonly",
                                            @"noowners",
                                            @"nobrowse",
                                            @"-j",
                                            ];
                
                if ( [recoveryPartitionDiskIdentifier length] != 0 && [NBCDiskImageController mountAtPath:[recoveryVolumeURL path]
                                                                                            withArguments:diskutilOptions
                                                                                                  forDisk:recoveryPartitionDiskIdentifier] ) {
                    
                    [source setRecoveryDisk:recoveryDisk];
                    [recoveryDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                    usleep(2000000); // Need to fix!
                }
            }
        }
    }
    
    if ( verified && recoveryVolumeURL != nil ) {
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemURL:baseSystemURL];
        } else {
            NSLog(@"Found No BaseSystem DMG!");
        }
    }
    
    return verified;
}

- (BOOL)verifyRecoveryPartitionFromSystemDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *systemVolumeURL = [source systemVolumeURL];
    NSURL *recoveryVolumeURL;
    
    NBCDisk *recoveryDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                       imageType:@"Recovery"];
    if ( verified && recoveryDisk != nil ) {
        [source setRecoveryDisk:recoveryDisk];
        recoveryVolumeURL = [recoveryDisk volumeURL];
        [source setRecoveryDiskImageURL:systemDiskImageURL];
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        [source setRecoveryVolumeBSDIdentifier:[recoveryDisk BSDName]];
        
        verified = YES;
    } else {
        NSString *recoveryPartitionDiskIdentifier;
        NSDictionary *systemDiskImageDict = [source systemDiskImageDict];
        if ( systemDiskImageDict ) {
            recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:systemDiskImageDict];
        }
        
        if ( [recoveryPartitionDiskIdentifier length] == 0 ) {
            recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromVolumeMountURL:systemVolumeURL];
        }
        
        if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            recoveryDisk = [NBCController diskFromBSDName:recoveryPartitionDiskIdentifier];
            if ( [recoveryDisk isMounted] ) {
                [source setRecoveryDisk:recoveryDisk];
                [source setRecoveryDiskImageURL:systemDiskImageURL];
                
                recoveryVolumeURL = [recoveryDisk volumeURL];
                [source setRecoveryVolumeURL:recoveryVolumeURL];
                
                verified = YES;
            } else {
                recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
                NSArray *diskutilOptions = @[
                                            @"rdonly",
                                            @"noowners",
                                            @"nobrowse",
                                            @"-j",
                                            ];
                
                if ( [recoveryPartitionDiskIdentifier length] != 0 && [NBCDiskImageController mountAtPath:[recoveryVolumeURL path]
                                                                                            withArguments:diskutilOptions
                                                                                                  forDisk:recoveryPartitionDiskIdentifier] ) {
                    [source setRecoveryDisk:recoveryDisk];
                    [source setRecoveryDiskImageURL:systemDiskImageURL];
                    [recoveryDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                    usleep(2000000); // Need to fix!
                }
            }
        }
    }
    
    if ( verified && recoveryVolumeURL != nil ) {
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemURL:baseSystemURL];
        } else {
            NSLog(@"Found No BaseSystem DMG!");
        }
    }
    
    return verified;
}

// ------------------------------------------------------
//  BaseSystem
// ------------------------------------------------------

- (BOOL)verifyBaseSystemFromSource:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *baseSystemDiskImageURL = [source baseSystemURL];
    NSURL *baseSystemVolumeURL;
    
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk != nil ) {
        [source setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        
        verified = YES;
    } else {
        NSDictionary *baseSystemImageDict;
        NSArray *hdiutilOptions = @[
                                   @"-mountRandom", @"/Volumes",
                                   @"-nobrowse",
                                   @"-noverify",
                                   @"-plist",
                                   ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&baseSystemImageDict
                                                                  dmgPath:baseSystemDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( baseSystemImageDict ) {
                [source setBaseSystemDiskImageDict:baseSystemImageDict];
                baseSystemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:baseSystemImageDict];
                baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                            imageType:@"BaseSystem"];
                if ( baseSystemDisk ) {
                    [source setBaseSystemDisk:baseSystemDisk];
                    [source setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
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
        [source setBaseSystemVolumeURL:baseSystemVolumeURL];
        
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

// ------------------------------------------------------
//  InstallESD
// ------------------------------------------------------

- (BOOL)verifyInstallESDFromDiskImageURL:(NSURL *)installESDDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    BOOL verified = NO;
    
    NSURL *installESDVolumeURL;
    
    [source setInstallESDDiskImageURL:installESDDiskImageURL];
    NBCDisk *installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                         imageType:@"InstallESD"];
    if ( installESDDisk != nil ) {
        [source setInstallESDDisk:installESDDisk];
        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
        installESDVolumeURL = [installESDDisk volumeURL];
        
        verified = YES;
    } else {
        NSDictionary *installESDDiskImageDict;
        NSArray *hdiutilOptions = @[
                                   @"-mountRandom", @"/Volumes",
                                   @"-nobrowse",
                                   @"-noverify",
                                   @"-plist",
                                   ];
        
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&installESDDiskImageDict
                                                                  dmgPath:installESDDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( installESDDiskImageDict ) {
                [source setInstallESDDiskImageDict:installESDDiskImageDict];
                installESDVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:installESDDiskImageDict];
                installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                            imageType:@"InstallESD"];
                if ( installESDDisk ) {
                    [source setInstallESDDisk:installESDDisk];
                    [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
                    [installESDDisk setIsMountedByNBICreator:YES];
                    
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
    
    if ( verified && installESDVolumeURL != nil ) {
        [source setInstallESDVolumeURL:installESDVolumeURL];
        
        NSURL *baseSystemURL = [installESDVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemURL:baseSystemURL];
        } else {
            verified = NO;
            NSLog(@"Found no BaseSystem.dmg!");
        }
    }
    
    return verified;
}

- (void)addNTP:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageBSDDict = sourceItemsDict[packageBSDPath];
    NSMutableArray *packageBSDRegexes;
    if ( [packageBSDDict count] != 0 ) {
        packageBSDRegexes = packageBSDDict[NBCSettingsSourceItemsRegexKey];
        if ( packageBSDRegexes == nil ) {
            packageBSDRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageBSDDict = [[NSMutableDictionary alloc] init];
        packageBSDRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexNTPDate = @".*/sbin/ntpdate.*";
    [packageBSDRegexes addObject:regexNTPDate];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addPython:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageBSDDict = sourceItemsDict[packageBSDPath];
    NSMutableArray *packageBSDRegexes;
    if ( [packageBSDDict count] != 0 ) {
        packageBSDRegexes = packageBSDDict[NBCSettingsSourceItemsRegexKey];
        if ( packageBSDRegexes == nil )
        {
            packageBSDRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageBSDDict = [[NSMutableDictionary alloc] init];
        packageBSDRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexPython = @".*/[Pp]ython.*";
    [packageBSDRegexes addObject:regexPython];
    
    NSString *regexSpctl = @".*spctl.*";
    [packageBSDRegexes addObject:regexSpctl];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addVNC:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
    NSMutableArray *packageEssentialsRegexes;
    if ( [packageEssentialsDict count] != 0 ) {
        packageEssentialsRegexes = packageEssentialsDict[NBCSettingsSourceItemsRegexKey];
        if ( packageEssentialsRegexes == nil )
        {
            packageEssentialsRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageEssentialsDict = [[NSMutableDictionary alloc] init];
        packageEssentialsRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexScreensharingPreferences = @".*/Preferences/com.apple.RemoteManagement.*";
    [packageEssentialsRegexes addObject:regexScreensharingPreferences];
    
    NSString *regexScreensharingLaunch = @".*/Launch(Agents|Daemons)/com.apple.screensharing.*";
    [packageEssentialsRegexes addObject:regexScreensharingLaunch];
    
    NSString *regexARDLaunch = @".*/Launch(Agents|Daemons)/com.apple.RemoteDesktop.*";
    [packageEssentialsRegexes addObject:regexARDLaunch];
    
    NSString *regexScreensharingAgent = @".*/ScreensharingAgent.bundle.*";
    [packageEssentialsRegexes addObject:regexScreensharingAgent];
    
    NSString *regexScreensharingD = @".*/screensharingd.bundle.*";
    [packageEssentialsRegexes addObject:regexScreensharingD];
    
    NSString *regexOD = @".*Library/OpenDirectory.*";
    [packageEssentialsRegexes addObject:regexOD];
    
    NSString *regexODConfigFramework = @".*OpenDirectoryConfig.framework.*";
    [packageEssentialsRegexes addObject:regexODConfigFramework];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addARD:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
    NSMutableArray *packageEssentialsRegexes;
    if ( [packageEssentialsDict count] != 0 ) {
        packageEssentialsRegexes = packageEssentialsDict[NBCSettingsSourceItemsRegexKey];
        if ( packageEssentialsRegexes == nil ) {
            packageEssentialsRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageEssentialsDict = [[NSMutableDictionary alloc] init];
        packageEssentialsRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexARDAgent = @".*/ARDAgent.app.*";
    [packageEssentialsRegexes addObject:regexARDAgent];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addKerberos:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
    NSMutableArray *packageEssentialsRegexes;
    if ( [packageEssentialsDict count] != 0 ) {
        packageEssentialsRegexes = packageEssentialsDict[NBCSettingsSourceItemsRegexKey];
        if ( packageEssentialsRegexes == nil ) {
            packageEssentialsRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageEssentialsDict = [[NSMutableDictionary alloc] init];
        packageEssentialsRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexKerberosUsers = @".*/users/_krb.*";
    [packageEssentialsRegexes addObject:regexKerberosUsers];
    
    NSString *regexKerberosLaunchDaemons = @".*/LaunchDaemons/com.apple.Kerberos.*";
    [packageEssentialsRegexes addObject:regexKerberosLaunchDaemons];
    
    NSString *regexKerberosBundles = @".*Kerberos.*\\.bundle.*";
    [packageEssentialsRegexes addObject:regexKerberosBundles];
    
    NSString *regexManagedClient = @".*/ManagedClient.app.*";
    [packageEssentialsRegexes addObject:regexManagedClient];
    
    NSString *regexDirectoryServer = @".*/DirectoryServer.framework.*";
    [packageEssentialsRegexes addObject:regexDirectoryServer];
    
    NSString *regexKerberosLocalKDCLaunchDaemon = @".*/com.apple.configureLocalKDC.*";
    [packageEssentialsRegexes addObject:regexKerberosLocalKDCLaunchDaemon];
    
    //NSString *regexCerttool = @".*/certtool.*";
    //[packageEssentialsRegexes addObject:regexCerttool];
    
    NSString *lkdcAcl = @".*/lkdc_acl.*";
    [packageEssentialsRegexes addObject:lkdcAcl];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
    
    NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageBSDDict = sourceItemsDict[packageBSDPath];
    NSMutableArray *packageBSDRegexes;
    if ( [packageBSDDict count] != 0 ) {
        packageBSDRegexes = packageBSDDict[NBCSettingsSourceItemsRegexKey];
        if ( packageBSDRegexes == nil ) {
            packageBSDRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageBSDDict = [[NSMutableDictionary alloc] init];
        packageBSDRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexKerberosBSDBinaries = @".*bin/krb.*";
    [packageBSDRegexes addObject:regexKerberosBSDBinaries];
    
    NSString *regexKerberosLocalKDC = @".*/libexec/.*KDC.*";
    [packageBSDRegexes addObject:regexKerberosLocalKDC];
    
    NSString *regexKerberosKdcsetup = @".*sbin/kdcsetup.*";
    [packageBSDRegexes addObject:regexKerberosKdcsetup];
    
    NSString *regexKerberosSandboxKDC = @".*sandbox/kdc.sb.*";
    [packageBSDRegexes addObject:regexKerberosSandboxKDC];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

@end
