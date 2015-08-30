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
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCSourceController

// ------------------------------------------------------
//  Drop Destination
// ------------------------------------------------------
- (BOOL)getInstallESDURLfromSourceURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Getting InstallESD from %@", [sourceURL path]);
    DDLogDebug(@"sourceURL=%@", sourceURL);
    if ( ! sourceURL ) {
        DDLogError(@"[ERROR] No url was passed!");
        return NO;
    }
    BOOL verified = NO;
    NSURL *installESDDiskImageURL;
    
    NSString *sourceExtension = [[sourceURL path] pathExtension];
    DDLogDebug(@"sourceExtension=%@", sourceExtension);
    if ( [sourceExtension isEqualToString:@"app"] ) {
        [source setOsxInstallerURL:sourceURL];
        NSBundle *osxInstallerBundle = [NSBundle bundleWithURL:sourceURL];
        DDLogDebug(@"osxInstallerBundle=%@", osxInstallerBundle);
        if ( osxInstallerBundle ) {
            NSURL *osxInstallerIconURL = [osxInstallerBundle URLForResource:@"InstallAssistant" withExtension:@"icns"];
            DDLogDebug(@"osxInstallerIconURL=%@", osxInstallerIconURL);
            if ( osxInstallerIconURL ) {
                [source setOsxInstallerIconURL:osxInstallerIconURL];
                installESDDiskImageURL = [[osxInstallerBundle bundleURL] URLByAppendingPathComponent:@"Contents/SharedSupport/InstallESD.dmg"];
                if ( installESDDiskImageURL ) {
                    [source setSourceType:NBCSourceTypeInstallerApplication];
                    verified = YES;
                } else {
                    DDLogError(@"[ERROR] Could not get installESDDiskImageURL!");
                }
            } else {
                DDLogError(@"[ERROR] Could not get osxInstallerIconURL!");
            }
        } else {
            DDLogError(@"[ERROR] Could not find an app bundle from path: %@", [sourceURL path]);
            verified = NO;
        }
    } else if ( [sourceExtension isEqualToString:@"dmg"] ) {
        installESDDiskImageURL = sourceURL;
        [source setSourceType:NBCSourceTypeInstallESDDiskImage];
        verified = YES;
    } else {
        DDLogError(@"\"%@\" is an invalid file extension!", sourceExtension);
        verified = NO;
    }
    
    if ( verified ) {
        if ( [installESDDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            DDLogDebug(@"installESDDiskImageURL=%@", installESDDiskImageURL);
            [source setInstallESDDiskImageURL:installESDDiskImageURL];
            verified = YES;
        } else {
            DDLogError(@"File doesn't exist: %@", [installESDDiskImageURL path]);
            DDLogError(@"%@", *error);
            verified = NO;
        }
    }
    
    return verified;
} // getInstallESDURLfromSourceURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify System Partition
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifySystemFromDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that disk contains a valid OS X System...");
    BOOL verified = NO;
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    DDLogDebug(@"systemVolumeURL=%@", systemVolumeURL);
    if ( systemVolumeURL ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeURL:systemVolumeURL];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"systemVersionPlistURL=%@", systemVersionPlistURL);
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            DDLogDebug(@"systemVersionPlist=%@", systemVersionPlist);
            if ( [systemVersionPlist count] != 0 ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogDebug(@"systemOSVersion=%@", systemOSVersion);
                if ( [systemOSVersion length] != 0 ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogDebug(@"systemOSBuild=%@", systemOSBuild);
                    if ( systemOSBuild != nil ) {
                        [source setSystemOSBuild:systemOSBuild];
                        [source setSourceBuild:systemOSBuild];
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] Unable to read osBuild from SystemVersion.plist");
                    }
                } else {
                    DDLogError(@"[ERROR] Unable to read osVersion from SystemVersion.plist");
                }
            } else {
                DDLogError(@"[ERROR] SystemVersion.plist is empty!");
            }
        } else {
            DDLogError(@"[ERROR] Found no SystemVersion.plist");
        }
    } else {
        DDLogError(@"[ERROR] systemVolumeURL is nil");
    }
    
    return verified;
} // verifySystemFromDisk:source:error

- (BOOL)verifySystemFromDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that disk image contains a valid OS X System...");
    DDLogDebug(@"systemDiskImageURL=%@", systemDiskImageURL);
    BOOL verified = NO;
    NSURL *systemVolumeURL;
    
    if ( ! systemDiskImageURL ) {
        DDLogError(@"[ERROR] systemDiskImageURL is nil!");
        return NO;
    }
    
    [source setSystemDiskImageURL:systemDiskImageURL];
    NBCDisk *systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                     imageType:@"System"];
    
    if ( systemDisk ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        systemVolumeURL = [systemDisk volumeURL];
        DDLogDebug(@"systemVolumeURL=%@", systemVolumeURL);
        if ( systemVolumeURL ) {
            verified = YES;
        } else {
            DDLogError(@"[ERROR] systemVolumeURL is nil!");
        }
    } else {
        NSDictionary *systemDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        DDLogDebug(@"hdiutilOptions=%@", hdiutilOptions);
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&systemDiskImageDict
                                                                  dmgPath:systemDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( systemDiskImageDict ) {
                [source setSystemDiskImageDict:systemDiskImageDict];
                systemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:systemDiskImageDict];
                
                if ( systemVolumeURL ) {
                    systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                            imageType:@"System"];
                    if ( systemDisk ) {
                        [source setSystemDisk:systemDisk];
                        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
                        [systemDisk setIsMountedByNBICreator:YES];
                        
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] No System Disk");
                    }
                } else {
                    DDLogError(@"[ERROR] Could not get systemVolumeURL");
                }
            } else {
                DDLogError(@"[ERROR] No disk image dict returned from hdiutil!");
            }
        } else {
            DDLogError(@"[ERROR] Attach System disk image failed");
        }
    }
    
    if ( verified && systemVolumeURL != nil ) {
        DDLogDebug(@"systemVolumeURL=%@", systemVolumeURL);
        [source setSystemVolumeURL:systemVolumeURL];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"systemVersionPlistURL=%@", systemVersionPlistURL);
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            DDLogDebug(@"systemVersionPlist=%@", systemVersionPlist);
            if ( [systemVersionPlist count] != 0 ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogDebug(@"systemOSVersion=%@", systemOSVersion);
                if ( [systemOSVersion length] != 0 ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogDebug(@"systemOSBuild=%@", systemOSBuild);
                    if ( [systemOSBuild length] != 0 ) {
                        [source setSystemOSBuild:systemOSBuild];
                        [source setSourceBuild:systemOSBuild];
                    } else {
                        DDLogError(@"[ERROR] Unable to read osBuild from SystemVersion.plist");
                        verified = NO;
                    }
                } else {
                    DDLogError(@"[ERROR] Unable to read osVersion from SystemVersion.plist");
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] SystemVersion.plist is empty!");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] Found no SystemVersion.plist");
            verified = NO;
        }
    }
    
    return verified;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Recovery Partition
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyRecoveryPartitionFromSystemDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that system disk contains a valid Recovery Partition...");
    BOOL verified = NO;
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    DDLogDebug(@"systemVolumeURL=%@", systemVolumeURL);
    
    if ( systemVolumeURL ) {
        NSURL *recoveryVolumeURL;
        NSString *recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromVolumeMountURL:systemVolumeURL];
        DDLogDebug(@"recoveryPartitionDiskIdentifier=%@", recoveryPartitionDiskIdentifier);
        if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            NBCDisk *recoveryDisk = [NBCController diskFromBSDName:recoveryPartitionDiskIdentifier];
            if ( [recoveryDisk isMounted] ) {
                [source setRecoveryDisk:recoveryDisk];
                recoveryVolumeURL = [recoveryDisk volumeURL];
                DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
                if ( recoveryVolumeURL ) {
                    [source setRecoveryVolumeURL:recoveryVolumeURL];
                    verified = YES;
                } else {
                    DDLogError(@"[ERROR] recoveryVolumeURL is nil");
                }
            } else {
                recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
                DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
                NSArray *diskutilOptions = @[
                                             @"rdonly",
                                             @"noowners",
                                             @"nobrowse",
                                             @"-j",
                                             ];
                DDLogDebug(@"diskutilOptions=%@", diskutilOptions);
                if ( [NBCDiskImageController mountAtPath:[recoveryVolumeURL path]
                                           withArguments:diskutilOptions
                                                 forDisk:recoveryPartitionDiskIdentifier] ) {
                    [source setRecoveryDisk:recoveryDisk];
                    [recoveryDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                    usleep(2000000); // Wait for disk to mount, need to fix by watching for disk mounts!
                } else {
                    DDLogError(@"[ERROR] Mounting Recovery Partition volume failed! ");
                }
            }
        } else {
            DDLogError(@"[ERROR] recoveryPartitionDiskIdentifier is nil!");
        }
        
        if ( verified && recoveryVolumeURL ) {
            DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
            [source setRecoveryVolumeURL:recoveryVolumeURL];
            
            NSURL *baseSystemURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
            DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
            if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
                [source setBaseSystemURL:baseSystemURL];
            } else {
                DDLogError(@"[ERROR] Found no BaseSystem image!");
                DDLogError(@"%@", *error);
                verified = NO;
            }
        }
    } else {
        DDLogError(@"[ERROR] systemVolumeURL is nil!");
    }
    
    return verified;
} // verifyRecoveryPartitionFromSystemDisk

- (BOOL)verifyRecoveryPartitionFromSystemDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that %@ contains a valid Recovery Partition...", [systemDiskImageURL path]);
    BOOL verified = NO;
    NSURL *recoveryVolumeURL;
    
    NSURL *systemVolumeURL = [source systemVolumeURL];
    DDLogDebug(@"systemVolumeURL=%@", systemVolumeURL);
    if ( ! systemVolumeURL ) {
        DDLogError(@"[ERROR] systemVolumeURL is nil!");
        return NO;
    }
    
    NBCDisk *recoveryDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                       imageType:@"Recovery"];
    if ( recoveryDisk ) {
        [source setRecoveryDisk:recoveryDisk];
        recoveryVolumeURL = [recoveryDisk volumeURL];
        DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
        if ( recoveryVolumeURL ) {
            [source setRecoveryDiskImageURL:systemDiskImageURL];
            [source setRecoveryVolumeURL:recoveryVolumeURL];
            [source setRecoveryVolumeBSDIdentifier:[recoveryDisk BSDName]];
            verified = YES;
        } else {
            DDLogError(@"[ERROR] recoveryVolumeURL is nil!");
        }
    } else {
        NSString *recoveryPartitionDiskIdentifier;
        NSDictionary *systemDiskImageDict = [source systemDiskImageDict];
        DDLogDebug(@"systemDiskImageDict=%@", systemDiskImageDict);
        if ( systemDiskImageDict ) {
            recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:systemDiskImageDict];
        }
        
        if ( [recoveryPartitionDiskIdentifier length] == 0 ) {
            recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromVolumeMountURL:systemVolumeURL];
        }
        DDLogDebug(@"recoveryPartitionDiskIdentifier=%@", recoveryPartitionDiskIdentifier);
        
        if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            recoveryDisk = [NBCController diskFromBSDName:recoveryPartitionDiskIdentifier];
            if ( [recoveryDisk isMounted] ) {
                DDLogDebug(@"recoveryDisk is already mounted");
                [source setRecoveryDisk:recoveryDisk];
                [source setRecoveryDiskImageURL:systemDiskImageURL];
                recoveryVolumeURL = [recoveryDisk volumeURL];
                DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
                [source setRecoveryVolumeURL:recoveryVolumeURL];
                
                verified = YES;
            } else {
                DDLogDebug(@"recoveryDisk is not mounted");
                recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
                DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
                NSArray *diskutilOptions = @[
                                             @"rdonly",
                                             @"noowners",
                                             @"nobrowse",
                                             @"-j",
                                             ];
                DDLogDebug(@"diskutilOptions=%@", diskutilOptions);
                if ( [NBCDiskImageController mountAtPath:[recoveryVolumeURL path]
                                           withArguments:diskutilOptions
                                                 forDisk:recoveryPartitionDiskIdentifier] ) {
                    [source setRecoveryDisk:recoveryDisk];
                    [source setRecoveryDiskImageURL:systemDiskImageURL];
                    [recoveryDisk setIsMountedByNBICreator:YES];
                    
                    verified = YES;
                    usleep(2000000); // Wait for disk to mount, need to fix by watching for disk mounts!
                } else {
                    DDLogError(@"[ERROR] Mounting Recovery Partition volume failed! ");
                }
            }
        } else {
            DDLogError(@"[ERROR] recoveryPartitionDiskIdentifier is nil");
        }
    }
    
    if ( verified && recoveryVolumeURL != nil ) {
        DDLogDebug(@"recoveryVolumeURL=%@", recoveryVolumeURL);
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemURL:baseSystemURL];
        } else {
            DDLogError(@"[ERROR] Found no BaseSystem image!");
            DDLogError(@"%@", *error);
            verified = NO;
        }
    }
    
    return verified;
} // verifyRecoveryPartitionFromSystemDiskImageURL:source:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify BaseSystem.dmg
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyBaseSystemFromSource:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that disk contains a valid BaseSystem.dmg...");
    BOOL verified = NO;
    NSURL *baseSystemVolumeURL;
    
    NSURL *baseSystemDiskImageURL = [source baseSystemURL];
    DDLogDebug(@"baseSystemDiskImageURL=%@", baseSystemDiskImageURL);
    if ( ! baseSystemDiskImageURL ) {
        DDLogError(@"[ERROR] baseSystemDiskImageURL is nil");
        return NO;
    }
    
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk ) {
        [source setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        DDLogDebug(@"baseSystemVolumeURL=%@", baseSystemVolumeURL);
        if ( baseSystemVolumeURL ) {
            verified = YES;
        } else {
            DDLogError(@"[ERROR] baseSystemVolumeURL is nil!");
        }
    } else {
        NSDictionary *baseSystemImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        DDLogDebug(@"hdiutilOptions=%@", hdiutilOptions);
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&baseSystemImageDict
                                                                  dmgPath:baseSystemDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( baseSystemImageDict ) {
                [source setBaseSystemDiskImageDict:baseSystemImageDict];
                baseSystemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:baseSystemImageDict];
                DDLogDebug(@"baseSystemVolumeURL=%@", baseSystemVolumeURL);
                if ( baseSystemVolumeURL ) {
                    baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                                imageType:@"BaseSystem"];
                    if ( baseSystemDisk ) {
                        [source setBaseSystemDisk:baseSystemDisk];
                        [source setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
                        [baseSystemDisk setIsMountedByNBICreator:YES];
                        
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] baseSystemDisk is nil!");
                    }
                } else {
                    DDLogError(@"[ERROR] Could not get baseSystemVolumeURL");
                }
            } else {
                DDLogError(@"[ERROR] baseSystemImageDict is nil");
            }
        } else {
            DDLogError(@"[ERROR] Attach BaseSystem image failed");
        }
    }
    
    if ( verified && baseSystemVolumeURL != nil ) {
        DDLogDebug(@"baseSystemVolumeURL=%@", baseSystemVolumeURL);
        [source setBaseSystemVolumeURL:baseSystemVolumeURL];
        
        NSURL *systemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"systemVersionPlistURL=%@", systemVersionPlistURL);
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( systemVersionPlist != nil ) {
                NSString *baseSystemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogDebug(@"baseSystemOSVersion=%@", baseSystemOSVersion);
                if ( [baseSystemOSVersion length] != 0 ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                    
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
                    DDLogError(@"[ERROR] Unable to read osVersion from SystemVersion.plist");
                    verified = NO;
                }
            } else {
                DDLogError(@"[ERROR] SystemVersion.plist is empty!");
                verified = NO;
            }
        } else {
            DDLogError(@"[ERROR] Found no SystemVersion.plist");
            verified = NO;
        }
    }
    
    return verified;
} // verifyBaseSystemFromSource:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify InstallESD.dmg
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyInstallESDFromDiskImageURL:(NSURL *)installESDDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Verifying that %@ is a valid InstallESD.dmg", [installESDDiskImageURL path]);
    DDLogDebug(@"installESDDiskImageURL=%@", installESDDiskImageURL);
    BOOL verified = NO;
    NSURL *installESDVolumeURL;
    
    if ( ! installESDDiskImageURL ) {
        DDLogError(@"[ERROR] installESDDiskImageURL is nil!");
        return NO;
    }
    
    [source setInstallESDDiskImageURL:installESDDiskImageURL];
    NBCDisk *installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                         imageType:@"InstallESD"];
    
    if ( installESDDisk != nil ) {
        [source setInstallESDDisk:installESDDisk];
        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
        installESDVolumeURL = [installESDDisk volumeURL];
        DDLogDebug(@"installESDVolumeURL=%@", installESDVolumeURL);
        if ( installESDVolumeURL ) {
            verified = YES;
        } else {
            DDLogError(@"[ERROR] installESDVolumeURL is nil!");
            return NO;
        }
    } else {
        NSDictionary *installESDDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        DDLogDebug(@"hdiutilOptions=%@", hdiutilOptions);
        if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&installESDDiskImageDict
                                                                  dmgPath:installESDDiskImageURL
                                                                  options:hdiutilOptions
                                                                    error:error] ) {
            if ( installESDDiskImageDict ) {
                [source setInstallESDDiskImageDict:installESDDiskImageDict];
                installESDVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:installESDDiskImageDict];
                DDLogDebug(@"installESDVolumeURL=%@", installESDVolumeURL);
                if ( installESDVolumeURL ) {
                    installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                                imageType:@"InstallESD"];
                    if ( installESDDisk ) {
                        [source setInstallESDDisk:installESDDisk];
                        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
                        [installESDDisk setIsMountedByNBICreator:YES];
                        
                        verified = YES;
                    } else {
                        DDLogError(@"[ERROR] installESDDisk is nil!");
                    }
                } else {
                    DDLogError(@"[ERROR] Could not get installESDVolumeURL");
                }
            } else {
                DDLogError(@"[ERROR] installESDDiskImageDict is nil");
            }
        } else {
            DDLogError(@"[ERROR] Attach InstallESD image failed");
        }
    }
    
    if ( verified && installESDVolumeURL != nil ) {
        DDLogDebug(@"installESDVolumeURL=%@", installESDVolumeURL);
        [source setInstallESDVolumeURL:installESDVolumeURL];
        
        NSURL *baseSystemURL = [installESDVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        DDLogDebug(@"baseSystemURL=%@", baseSystemURL);
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemURL:baseSystemURL];
        } else {
            DDLogError(@"File doesn't exist: %@", [installESDDiskImageURL path]);
            DDLogError(@"%@", *error);
            verified = NO;
        }
    }

    return verified;
}

- (BOOL)verifySourceIsMountedOSVolume:(NBCSource *)source {
    BOOL retval = NO;
    NSError *error;
    NBCDisk *systemDisk = [source systemDisk];
    if ( systemDisk ) {
        if ( [systemDisk isMounted] ) {
            return YES;
        } else {
            [systemDisk mount];
            if ( [systemDisk isMounted] ) {
                return YES;
            }
        }
    }
    
    NSURL *systemDiskImageURL = [source systemDiskImageURL];
    if ( [systemDiskImageURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( [self verifySystemFromDiskImageURL:systemDiskImageURL source:source error:&error] ) {
            if ( [[source systemDisk] isMounted] ) {
                return YES;
            } else {
                DDLogError(@"[ERROR] systemDisk is not mounted!");
                return NO;
            }
        } else {
            DDLogError(@"[ERROR] Mounting systemDisk failed, verify NO!");
            return NO;
        }
    } else {
        DDLogError(@"[ERROR] Could not find systemDiskImageURL!");
        DDLogError(@"[ERROR] %@", error);
        return NO;
    }
    
    return retval;
}

- (BOOL)verifySourceIsMountedInstallESD:(NBCSource *)source {
    BOOL retval = NO;
    NSError *error;
    NBCDisk *installESDDisk = [source installESDDisk];
    if ( installESDDisk ) {
        if ( [installESDDisk isMounted] ) {
            return YES;
        }
    }

    NSURL *installESDDiskImageURL = [source installESDDiskImageURL];
    if ( [installESDDiskImageURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( [self verifyInstallESDFromDiskImageURL:installESDDiskImageURL source:source  error:&error] ) {
            if ( [[source installESDDisk] isMounted] ) {
                return YES;
            } else {
                DDLogError(@"[ERROR] installESDDisk is not mounted!");
                return NO;
            }
        } else {
            DDLogError(@"[ERROR] Mounting installESD failed, verify NO!");
            return NO;
        }
    } else {
        DDLogError(@"[ERROR] Could not find installESDDiskImageURL!");
        DDLogError(@"[ERROR] %@", error);
        return NO;
    }
    
    return retval;
} // verifySourceIsMountedNetInstall

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Create settings
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addKernel:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    
    NSString *regexkernel = @".*/Kernels/.*";
    DDLogDebug(@"regexkernel=%@", regexkernel);
    [packageEssentialsRegexes addObject:regexkernel];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addNTP:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        NSString *regexSntpWrapper = @".*/sntp-wrapper.*";
        [packageBSDRegexes addObject:regexSntpWrapper];
    }
    
    NSString *regexNTPDate = @".*/sbin/ntpdate.*";
    DDLogDebug(@"regexNTPDate=%@", regexNTPDate);
    [packageBSDRegexes addObject:regexNTPDate];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addNSURLStoraged:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexNSURLStoraged = @".*nsurlstoraged.*";
    [packageBSDRegexes addObject:regexNSURLStoraged];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
    
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
    
    [packageEssentialsRegexes addObject:regexNSURLStoraged];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addNetworkd:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexNetworkd = @".*(/|com.apple.)networkd.*";
    [packageEssentialsRegexes addObject:regexNetworkd];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addSpctl:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexSpctl = @".*spctl.*";
    DDLogDebug(@"regexSpctl=%@", regexSpctl);
    [packageBSDRegexes addObject:regexSpctl];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addPython:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexPython = @".*/[Pp]ython.*";
    DDLogDebug(@"regexPython=%@", regexPython);
    [packageBSDRegexes addObject:regexPython];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addSystemUIServer:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexSystemUIServer = @".*SystemUIServer.*";
    [packageEssentialsRegexes addObject:regexSystemUIServer];
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        NSString *regexFrameworkAVFoundation = @".*AVFoundation.framework.*";
        [packageEssentialsRegexes addObject:regexFrameworkAVFoundation];
        
        NSString *regexFrameworkAPTransport = @".*APTransport.framework.*";
        [packageEssentialsRegexes addObject:regexFrameworkAPTransport];
        
        NSString *regexFrameworkWirelessProximity = @".*WirelessProximity.framework.*";
        [packageEssentialsRegexes addObject:regexFrameworkWirelessProximity];
        
        NSString *regexSCIM = @".*SCIM.app.*";
        [packageEssentialsRegexes addObject:regexSCIM];
        
        NSString *regexTCIM = @".*TCIM.app.*";
        [packageEssentialsRegexes addObject:regexTCIM];
    }
        
    NSString *regexFrameworkMediaControlSender = @".*MediaControlSender.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkMediaControlSender];
    
    NSString *regexFrameworkSystemUIPlugin = @".*SystemUIPlugin.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkSystemUIPlugin];
    
    NSString *regexFrameworkICANotifications = @".*ICANotifications.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkICANotifications];
    
    NSString *regexFrameworkIpod = @".*iPod.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkIpod];
    
    NSString *regexFrameworkAirPlaySupport = @".*AirPlaySupport.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkAirPlaySupport];
    
    NSString *regexFrameworkCoreUtils = @".*CoreUtils.framework.*";
    [packageEssentialsRegexes addObject:regexFrameworkCoreUtils];
    
    NSString *regexMenuExtraTextInput = @".*TextInput.menu.*";
    [packageEssentialsRegexes addObject:regexMenuExtraTextInput];
    
    NSString *regexMenuExtraBattery = @".*Battery.menu.*";
    [packageEssentialsRegexes addObject:regexMenuExtraBattery];
    
    NSString *regexMenuExtraClock = @".*Clock.menu.*";
    [packageEssentialsRegexes addObject:regexMenuExtraClock];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addSystemkeychain:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    NSString *regexSystemkeychain = @".*systemkeychain.*";
    [packageEssentialsRegexes addObject:regexSystemkeychain];
    
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
    
    NSString *regexSecurityChecksystem = @".*security-checksystem.*";
    [packageBSDRegexes addObject:regexSecurityChecksystem];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addVNC:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        NSString *regexAppleVNCServer = @".*/AppleVNCServer.bundle.*";
        [packageEssentialsRegexes addObject:regexAppleVNCServer];
    }
    
    NSString *regexPerl = @".*perl.*";
    [packageEssentialsRegexes addObject:regexPerl];
    
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
    
    NSString *regexOD = @".*[Oo]pen[Dd]irectory.*";
    [packageEssentialsRegexes addObject:regexOD];
    
    NSString *regexODConfigFramework = @".*OpenDirectoryConfig.framework.*";
    [packageEssentialsRegexes addObject:regexODConfigFramework];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

- (void)addARD:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
