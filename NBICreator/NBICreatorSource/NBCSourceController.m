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
#import "NBCWorkflowItem.h"
#import "NBCError.h"
#import "NBCDiskController.h"

DDLogLevel ddLogLevel;

@implementation NBCSourceController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCSourceControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
} // initWithDelegate

// ------------------------------------------------------
//  Drop Destination
// ------------------------------------------------------
- (BOOL)getInstallESDURLfromSourceURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Getting InstallESD from %@", [sourceURL path]);
    
    if ( ! [sourceURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    BOOL verified = NO;
    NSURL *installESDDiskImageURL;
    
    NSString *sourceExtension = [[sourceURL path] pathExtension];
    DDLogDebug(@"[DEBUG] ");
    if ( [sourceExtension isEqualToString:@"app"] ) {
        [source setOsxInstallerURL:sourceURL];
        NSBundle *osxInstallerBundle = [NSBundle bundleWithURL:sourceURL];
        if ( osxInstallerBundle ) {
            NSURL *osxInstallerIconURL = [osxInstallerBundle URLForResource:@"InstallAssistant" withExtension:@"icns"];
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
            [source setInstallESDDiskImageURL:installESDDiskImageURL];
            return YES;
        } else {
            return NO;
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
    
    DDLogInfo(@"Verifying that disk contains a valid OS X System...");
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    DDLogDebug(@"[DEBUG] System disk volume path: %@", [systemVolumeURL path]);
    
    if ( [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeURL:systemVolumeURL];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] SystemVersion.plist path: %@", [systemVersionPlistURL path]);
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( [systemVersionPlist count] != 0 ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"Disk os version: %@", systemOSVersion);
                
                if ( [systemOSVersion length] != 0 ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"Disk os build: %@", systemOSBuild);
                    
                    if ( [systemOSBuild length] != 0 ) {
                        [source setSystemOSBuild:systemOSBuild];
                        [source setSourceBuild:systemOSBuild];
                        return YES;
                    } else {
                        *error = [NBCError errorWithDescription:@"Unable to read os build from SystemVersion.plist"];
                        return NO;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"Unable to read os version from SystemVersion.plist"];
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"SystemVersion.plist is empty!"];
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // verifySystemFromDisk:source:error

- (BOOL)verifySystemFromDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying that disk image contains a valid OS X System...");
    
    DDLogDebug(@"[DEBUG] Disk image path: %@", [systemDiskImageURL path]);
    if ( ! [systemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    [source setSystemDiskImageURL:systemDiskImageURL];
    NBCDisk *systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                     imageType:@"System"];
    
    NSURL *systemVolumeURL;
    if ( systemDisk ) {
        [source setSystemDisk:systemDisk];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        systemVolumeURL = [systemDisk volumeURL];
        DDLogDebug(@"[DEBUG] Disk image volume path: %@", [systemVolumeURL path]);
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
            if ( [systemDiskImageDict count] != 0 ) {
                [source setSystemDiskImageDict:systemDiskImageDict];
                systemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:systemDiskImageDict];
                DDLogDebug(@"[DEBUG] Disk image volume path: %@", [systemVolumeURL path]);
                
                if ( [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    [source setSystemVolumeURL:systemVolumeURL];
                    systemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                            imageType:@"System"];
                    
                    if ( systemDisk ) {
                        [source setSystemDisk:systemDisk];
                        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
                        [systemDisk setIsMountedByNBICreator:YES];
                    } else {
                        *error = [NBCError errorWithDescription:@"Disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"Disk image hdiutil info was empty"];
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    if ( [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] Disk image is mounted at path: %@", [systemVolumeURL path]);
        [source setSystemVolumeURL:systemVolumeURL];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] SystemVersion.plist path: %@", [systemVersionPlistURL path]);
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( [systemVersionPlist count] != 0 ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"Disk image os version: %@", systemOSVersion);
                
                if ( [systemOSVersion length] != 0 ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"Disk image os build: %@", systemOSBuild);
                    
                    if ( [systemOSBuild length] != 0 ) {
                        [source setSystemOSBuild:systemOSBuild];
                        [source setSourceBuild:systemOSBuild];
                        return YES;
                    } else {
                        *error = [NBCError errorWithDescription:@"Unable to read os build from SystemVersion.plist"];
                        return NO;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"Unable to read os version from SystemVersion.plist"];
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"SystemVersion.plist is empty!"];
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Recovery Partition
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyRecoveryPartitionFromSystemDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying that system disk contains a valid recovery partition...");
    
    NSURL *systemVolumeURL = [systemDisk volumeURL];
    DDLogDebug(@"[DEBUG] Disk image system volume path: %@", [systemVolumeURL path]);
    
    if ( ! [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    NSURL *recoveryVolumeURL;
    NSString *recoveryPartitionDiskIdentifier = [NBCDiskController getRecoveryPartitionIdentifierFromVolumeURL:systemVolumeURL];
    DDLogDebug(@"[DEBUG] Disk image recovery partition BSD identifier: %@", recoveryPartitionDiskIdentifier);
    
    if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
        [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
        
        NBCDisk *recoveryDisk = [NBCDiskController diskFromBSDName:recoveryPartitionDiskIdentifier];
        if ( [recoveryDisk isMounted] ) {
            [source setRecoveryDisk:recoveryDisk];
            recoveryVolumeURL = [recoveryDisk volumeURL];
        } else {
            recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
            DDLogDebug(@"[DEBUG] Mounting disk recovery partition at path: %@", [recoveryVolumeURL path]);
            
            NSArray *diskutilOptions = @[
                                         @"rdonly",
                                         @"noowners",
                                         @"nobrowse",
                                         @"-j",
                                         ];
            
            if ( [NBCDiskController mountAtPath:[recoveryVolumeURL path]
                                      arguments:diskutilOptions
                                 diskIdentifier:recoveryPartitionDiskIdentifier] ) {
                
                [source setRecoveryDisk:recoveryDisk];
                [recoveryDisk setIsMountedByNBICreator:YES];
                
                usleep(2000000); // Wait for disk to mount, need to fix by watching for disk mounts!
            } else {
                *error = [NBCError errorWithDescription:@"Mounting disk recovery partition failed"];
                return NO;
            }
        }
    } else {
        *error = [NBCError errorWithDescription:@"System disk recovery partition BSD identifier returned empty"];
    }
    
    if ( [recoveryVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] Disk image recovery partition is mounted at path: %@", [recoveryVolumeURL path]);
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemDiskImageURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] Recovery partition BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
        
        if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemDiskImageURL:baseSystemDiskImageURL];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // verifyRecoveryPartitionFromSystemDisk

- (BOOL)verifyRecoveryPartitionFromSystemDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying that %@ contains a valid Recovery Partition...", [systemDiskImageURL path]);
    
    NSURL *systemVolumeURL = [source systemVolumeURL];
    DDLogDebug(@"[DEBUG] Disk image system volume path: %@", [systemVolumeURL path]);
    
    if ( ! [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    NSURL *recoveryVolumeURL;
    NBCDisk *recoveryDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:systemDiskImageURL
                                                                       imageType:@"Recovery"];
    
    if ( recoveryDisk ) {
        [source setRecoveryDisk:recoveryDisk];
        [source setRecoveryDiskImageURL:systemDiskImageURL];
        [source setRecoveryVolumeBSDIdentifier:[recoveryDisk BSDName]];
        recoveryVolumeURL = [recoveryDisk volumeURL];
    } else {
        NSString *recoveryPartitionDiskIdentifier;
        NSDictionary *systemDiskImageDict = [source systemDiskImageDict];
        if ( [systemDiskImageDict count] != 0 ) {
            recoveryPartitionDiskIdentifier = [NBCDiskImageController getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:systemDiskImageDict];
        }
        
        if ( [recoveryPartitionDiskIdentifier length] == 0 ) {
            recoveryPartitionDiskIdentifier = [NBCDiskController getRecoveryPartitionIdentifierFromVolumeURL:systemVolumeURL];
        }
        
        if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
            DDLogDebug(@"[DEBUG] Disk image recovery partition BSD identifier: %@", recoveryPartitionDiskIdentifier);
            
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            recoveryDisk = [NBCDiskController diskFromBSDName:recoveryPartitionDiskIdentifier];
            if ( [recoveryDisk isMounted] ) {
                [source setRecoveryDisk:recoveryDisk];
                [source setRecoveryDiskImageURL:systemDiskImageURL];
                recoveryVolumeURL = [recoveryDisk volumeURL];
                if ( [recoveryVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    DDLogDebug(@"[DEBUG] Disk image recovery partition is mounted at path: %@", [recoveryVolumeURL path]);
                    [source setRecoveryVolumeURL:recoveryVolumeURL];
                } else {
                    return NO;
                }
            } else {
                recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
                DDLogDebug(@"[DEBUG] Mounting disk image recovery partition at path: %@", [recoveryVolumeURL path]);
                
                NSArray *diskutilOptions = @[
                                             @"rdonly",
                                             @"noowners",
                                             @"nobrowse",
                                             @"-j",
                                             ];
                
                if ( [NBCDiskController mountAtPath:[recoveryVolumeURL path]
                                          arguments:diskutilOptions
                                     diskIdentifier:recoveryPartitionDiskIdentifier] ) {
                    
                    [source setRecoveryDisk:recoveryDisk];
                    [source setRecoveryDiskImageURL:systemDiskImageURL];
                    [recoveryDisk setIsMountedByNBICreator:YES];
                    
                    usleep(2000000); // Wait for disk to mount, need to fix by watching for disk mounts!
                } else {
                    *error = [NBCError errorWithDescription:@"Mounting disk image recovery partition failed"];
                    return NO;
                }
            }
        } else {
            *error = [NBCError errorWithDescription:@"No recovery partition found on disk"];
            return NO;
        }
    }
    
    if ( [recoveryVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] Disk image recovery partition is mounted at path: %@", [recoveryVolumeURL path]);
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemDiskImageURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] Recovery partition BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
        if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemDiskImageURL:baseSystemDiskImageURL];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // verifyRecoveryPartitionFromSystemDiskImageURL:source:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify BaseSystem.dmg
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyBaseSystemFromSource:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying that disk contains a valid BaseSystem.dmg...");
    
    NSURL *baseSystemDiskImageURL = [source baseSystemDiskImageURL];
    DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
    
    if ( ! [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    NSURL *baseSystemVolumeURL;
    NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                         imageType:@"BaseSystem"];
    if ( baseSystemDisk ) {
        [source setBaseSystemDisk:baseSystemDisk];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
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
            if ( [baseSystemImageDict count] != 0 ) {
                [source setBaseSystemDiskImageDict:baseSystemImageDict];
                baseSystemVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:baseSystemImageDict];
                if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                                imageType:@"BaseSystem"];
                    if ( baseSystemDisk ) {
                        [source setBaseSystemDisk:baseSystemDisk];
                        [source setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
                        [baseSystemDisk setIsMountedByNBICreator:YES];
                    } else {
                        *error = [NBCError errorWithDescription:@"Disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"Disk image hdiutil info was empty"];
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] BaseSystem disk image volume is mounted at path: %@", [baseSystemVolumeURL path]);
        [source setBaseSystemVolumeURL:baseSystemVolumeURL];
        
        NSURL *systemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] SystemVersion.plist path: %@", [systemVersionPlistURL path]);
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( [systemVersionPlist count] != 0 ) {
                NSString *baseSystemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"BaseSystem os version: %@", baseSystemOSVersion);
                
                if ( [baseSystemOSVersion length] != 0 ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                    
                    NSString *baseSystemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"BaseSystem os build: %@", baseSystemOSBuild);
                    
                    if ( [baseSystemOSBuild length] != 0 ) {
                        [source setBaseSystemOSBuild:baseSystemOSBuild];
                        [source setSourceBuild:baseSystemOSBuild];
                        return YES;
                    } else {
                        *error = [NBCError errorWithDescription:@"Unable to read os build from SystemVersion.plist"];
                        return NO;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"Unable to read os version from SystemVersion.plist"];
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"SystemVersion.plist is empty!"];
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // verifyBaseSystemFromSource:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify InstallESD.dmg
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyInstallESDFromDiskImageURL:(NSURL *)installESDDiskImageURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying that disk image contains a BaseSystem.dmg...");
    
    DDLogDebug(@"[DEBUG] Disk image path: %@", [installESDDiskImageURL path]);
    if ( ! [installESDDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
        return NO;
    }
    
    [source setInstallESDDiskImageURL:installESDDiskImageURL];
    NBCDisk *installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                         imageType:@"InstallESD"];
    
    NSURL *installESDVolumeURL;
    if ( installESDDisk != nil ) {
        [source setInstallESDDisk:installESDDisk];
        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
        installESDVolumeURL = [installESDDisk volumeURL];
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
            
            if ( [installESDDiskImageDict count] != 0 ) {
                [source setInstallESDDiskImageDict:installESDDiskImageDict];
                installESDVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:installESDDiskImageDict];
                if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    installESDDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:installESDDiskImageURL
                                                                                imageType:@"InstallESD"];
                    if ( installESDDisk ) {
                        [source setInstallESDDisk:installESDDisk];
                        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
                        [installESDDisk setIsMountedByNBICreator:YES];
                    } else {
                        *error = [NBCError errorWithDescription:@"Disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"Disk image hdiutil info was empty"];
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] InstallESD disk image volume is mounted at path: %@", [installESDVolumeURL path]);
        [source setInstallESDVolumeURL:installESDVolumeURL];
        
        NSURL *baseSystemDiskImageURL = [installESDVolumeURL URLByAppendingPathComponent:@"BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
        
        if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemDiskImageURL:baseSystemDiskImageURL];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
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
    DDLogDebug(@"[DEBUG] Disk image path: %@", [systemDiskImageURL path]);
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

+ (void)addKernel:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    [packageEssentialsRegexes addObject:regexkernel];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

+ (void)addDesktopPicture:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    
    NSString *regexDesktopPicture;
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( sourceVersionMinor == 11 ) {
        [packageEssentialsRegexes addObject:@".*Library/Desktop\\ Pictures/El\\ Capitan.jpg.*"];
        packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
        sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
        return;
    }
    
    NSString *packageMediaFilesPath = [NSString stringWithFormat:@"%@/Packages/MediaFiles.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageMediaFilesDict = sourceItemsDict[packageMediaFilesPath];
    NSMutableArray *packageMediaFilesRegexes;
    if ( [packageMediaFilesDict count] != 0 ) {
        packageMediaFilesRegexes = packageMediaFilesDict[NBCSettingsSourceItemsRegexKey];
        if ( packageMediaFilesRegexes == nil )
        {
            packageMediaFilesRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageMediaFilesDict = [[NSMutableDictionary alloc] init];
        packageMediaFilesRegexes = [[NSMutableArray alloc] init];
    }
    
    switch (sourceVersionMinor) {
        case 10:
            regexDesktopPicture = @".*Library/Desktop\\ Pictures/Yosemite.jpg.*";
            break;
        case 9:
            regexDesktopPicture = @".*Library/Desktop\\ Pictures/Wave.jpg.*";
            break;
        case 8:
            regexDesktopPicture = @".*Library/Desktop\\ Pictures/Galaxy.jpg.*";
            break;
        case 7:
            regexDesktopPicture = @".*Library/Desktop\\ Pictures/Lion.jpg.*";
            break;
        default:
            break;
    }
    
    if ( [regexDesktopPicture length] != 0 ) {
        [packageMediaFilesRegexes addObject:regexDesktopPicture];
    }
    
    packageMediaFilesDict[NBCSettingsSourceItemsRegexKey] = packageMediaFilesRegexes;
    sourceItemsDict[packageMediaFilesPath] = packageMediaFilesDict;
}

+ (void)addNTP:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    [packageBSDRegexes addObject:regexNTPDate];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addNSURLStoraged:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    
    NSString *regexNSURLSessiond = @".*nsurlsessiond.*";
    [packageBSDRegexes addObject:regexNSURLSessiond];
    
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
    [packageEssentialsRegexes addObject:regexNSURLSessiond];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

+ (void)addNetworkd:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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

+ (void)addLibSsl:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    
    NSString *regexLibSsl = @".*/lib/libssl.*";
    [packageEssentialsRegexes addObject:regexLibSsl];
    
    NSString *regexLibcrypto = @".*/lib/libcrypto.*";
    [packageEssentialsRegexes addObject:regexLibcrypto];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

+ (void)addSpctl:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    [packageBSDRegexes addObject:regexSpctl];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addDeployStudioDependencies:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSError *error;
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
    
    NSURL *casperImagingDependenciesURL;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( ! userApplicationSupport ) {
        DDLogError(@"Could not get Application Support folder for current User");
        DDLogError(@"Error: %@", error);
    }
    
    NSString *casperImagingDependenciesPathComponent = [NSString stringWithFormat:@"%@/DeployStudio.plist", NBCFolderResourcesDependencies];
    casperImagingDependenciesURL = [userApplicationSupport URLByAppendingPathComponent:casperImagingDependenciesPathComponent isDirectory:YES];
    if ( ! [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogError(@"[ERROR] Could not find a downloaded resource file!");
        casperImagingDependenciesURL = [[NSBundle mainBundle] URLForResource:@"DeployStudio" withExtension:@"plist"];
    }
    
    NSString *sourceVersionOS = [source expandVariables:@"%OSVERSION%"];
    NSString *sourceBuild = [source expandVariables:@"%OSBUILD%"];
    NSDictionary *buildDict;
    if ( [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *casperImagingDependenciesDict = [NSDictionary dictionaryWithContentsOfURL:casperImagingDependenciesURL];
        if ( [casperImagingDependenciesDict count] != 0 ) {
            NSDictionary *sourceDict = casperImagingDependenciesDict[sourceVersionOS];
            NSArray *sourceBuilds = [sourceDict allKeys];
            if ( [sourceDict count] != 0 && [sourceBuilds containsObject:sourceBuild] ) {
                buildDict = sourceDict[sourceBuild];
            } else {
                NSLog(@"Fix!");
            }
            
            if ( [buildDict count] == 0 ) {
                DDLogError(@"ERROR");
            }
        }
    }
    
    NSArray *casperImagingDepencenciesEssentials = buildDict[@"Essentials"];
    if ( [casperImagingDepencenciesEssentials count] != 0 ) {
        [packageEssentialsRegexes addObjectsFromArray:casperImagingDepencenciesEssentials];
    }
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        
        // For 'IOKit'
        //NSString *regexLibenergytrace = @".*/lib/libenergytrace.dylib.*";
        //[packageEssentialsRegexes addObject:regexLibenergytrace];
    }
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
    
    NSString *baseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *baseSystemBinariesDict = [sourceItemsDict[baseSystemBinariesPath] mutableCopy];
    NSMutableArray *baseSystemBinariesRegexes;
    if ( [baseSystemBinariesDict count] != 0 ) {
        baseSystemBinariesRegexes = [baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
        if ( baseSystemBinariesRegexes == nil )
        {
            baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        baseSystemBinariesDict = [[NSMutableDictionary alloc] init];
        baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
    }
    
    NSArray *casperImagingDepencenciesBaseSystemBinaries = buildDict[@"BaseSystemBinaries"];
    if ( [casperImagingDepencenciesBaseSystemBinaries count] != 0 ) {
        [baseSystemBinariesRegexes addObjectsFromArray:casperImagingDepencenciesBaseSystemBinaries];
    }
    
    baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] = baseSystemBinariesRegexes;
    sourceItemsDict[baseSystemBinariesPath] = baseSystemBinariesDict;
    
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
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addCasperImaging:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSError *error;
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
    
    NSURL *casperImagingDependenciesURL;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( ! userApplicationSupport ) {
        DDLogError(@"Could not get Application Support folder for current User");
        DDLogError(@"Error: %@", error);
    }
    
    NSString *casperImagingDependenciesPathComponent = [NSString stringWithFormat:@"%@/CasperImaging.plist", NBCFolderResourcesDependencies];
    casperImagingDependenciesURL = [userApplicationSupport URLByAppendingPathComponent:casperImagingDependenciesPathComponent isDirectory:YES];
    if ( ! [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogError(@"[ERROR] Could not find a downloaded resource file!");
        casperImagingDependenciesURL = [[NSBundle mainBundle] URLForResource:@"CasperImaging" withExtension:@"plist"];
    }
    
    NSString *sourceVersionOS = [source expandVariables:@"%OSVERSION%"];
    NSString *sourceBuild = [source expandVariables:@"%OSBUILD%"];
    NSDictionary *buildDict;
    if ( [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *casperImagingDependenciesDict = [NSDictionary dictionaryWithContentsOfURL:casperImagingDependenciesURL];
        if ( [casperImagingDependenciesDict count] != 0 ) {
            NSDictionary *sourceDict = casperImagingDependenciesDict[sourceVersionOS];
            NSArray *sourceBuilds = [sourceDict allKeys];
            if ( [sourceDict count] != 0 && [sourceBuilds containsObject:sourceBuild] ) {
                buildDict = sourceDict[sourceBuild];
            } else {
                NSLog(@"Fix!");
            }
            
            if ( [buildDict count] == 0 ) {
                DDLogError(@"ERROR");
            }
        }
    }
    
    NSArray *casperImagingDepencenciesEssentials = buildDict[@"Essentials"];
    if ( [casperImagingDepencenciesEssentials count] != 0 ) {
        [packageEssentialsRegexes addObjectsFromArray:casperImagingDepencenciesEssentials];
    }
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        
        // For 'IOKit'
        NSString *regexLibenergytrace = @".*/lib/libenergytrace.dylib.*";
        [packageEssentialsRegexes addObject:regexLibenergytrace];
        
        // For 'CoreGraphics'
        NSString *regexMetal = @".*/Frameworks/Metal.framework.*";
        [packageEssentialsRegexes addObject:regexMetal];
        
        // For 'Metal'
        NSString *regexLibCoreFSCache = @".*/Libraries/libCoreFSCache.dylib.*";
        [packageEssentialsRegexes addObject:regexLibCoreFSCache];
        
        // For 'libmecabra'
        NSString *regexLibmarisa = @".*/lib/libmarisa.dylib.*";
        [packageEssentialsRegexes addObject:regexLibmarisa];
        
        // For 'libmecabra'
        NSString *regexLibChineseTokenizer = @".*/lib/libChineseTokenizer.dylib.*";
        [packageEssentialsRegexes addObject:regexLibChineseTokenizer];
        
        // For 'CoreImage'
        NSString *regexLibFosl_dynamic = @".*/lib/libFosl_dynamic.dylib.*";
        [packageEssentialsRegexes addObject:regexLibFosl_dynamic];
        
        // For 'libCVMSPluginSupport'
        NSString *regexLibCoreVMClient = @".*/Libraries/libCoreVMClient.dylib.*";
        [packageEssentialsRegexes addObject:regexLibCoreVMClient];
        
        // For 'AppKit'
        NSString *regexLibScreenReader = @".*/lib/libScreenReader.dylib.*";
        [packageEssentialsRegexes addObject:regexLibScreenReader];
        
        // For 'DiskImages/CoreData'
        NSString *regexLibcompression = @".*/lib/libcompression.dylib.*";
        [packageEssentialsRegexes addObject:regexLibcompression];
        
        NSString *regexLibcldcpuengine = @".*/Libraries/libcldcpuengine.dylib.*";
        [packageEssentialsRegexes addObject:regexLibcldcpuengine];
        
        //-- BELOW ARE TESTING ONLY --
        NSString *regexKernel = @".*/Kernels/kernel.*";
        [packageEssentialsRegexes addObject:regexKernel];
        
        // warning, could not bind /Volumes/dmg.Zn4BY5/usr/lib/libUniversalAccess.dylib because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Libraries/libUAPreferences.dylib
        NSString *regexUniversalAccess = @".*/PrivateFrameworks/UniversalAccess.framework.*";
        [packageEssentialsRegexes addObject:regexUniversalAccess];
        
        // warning, could not bind /Volumes/dmg.Zn4BY5/System/Library/Frameworks/Automator.framework/Versions/A/Automator because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/XprotectFramework.framework/Versions/A/XprotectFramework
        NSString *regexXprotectFramework = @".*/PrivateFrameworks/XprotectFramework.framework.*";
        [packageEssentialsRegexes addObject:regexXprotectFramework];
        
        // warning, could not bind /System/Library/Frameworks/MultipeerConnectivity.framework/Versions/A/MultipeerConnectivity because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace
        NSString *regexAVConference = @".*/PrivateFrameworks/AVConference.framework.*";
        [packageEssentialsRegexes addObject:regexAVConference];
        
        // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
        NSString *regexMarco = @".*/PrivateFrameworks/Marco.framework.*";
        [packageEssentialsRegexes addObject:regexMarco];
        
        // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/VideoProcessing
        NSString *regexVideoProcessing = @".*/PrivateFrameworks/VideoProcessing.framework.*";
        [packageEssentialsRegexes addObject:regexVideoProcessing];
        
        // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices
        NSString *regexFTServices = @".*/PrivateFrameworks/FTServices.framework.*";
        [packageEssentialsRegexes addObject:regexFTServices];
        
        // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
        NSString *regexFTAWD = @".*/PrivateFrameworks/FTAWD.framework.*";
        [packageEssentialsRegexes addObject:regexFTAWD];
        
        // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore
        NSString *regexIMCore = @".*/PrivateFrameworks/IMCore.framework.*";
        [packageEssentialsRegexes addObject:regexIMCore];
        
        // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoConference.framework/Versions/A/VideoConference
        NSString *regexVideoConference = @".*/PrivateFrameworks/VideoConference.framework.*";
        [packageEssentialsRegexes addObject:regexVideoConference];
        
        // warning, could not bind /System/Library/PrivateFrameworks/IMTranscoding.framework/Versions/A/IMTranscoding because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation
        NSString *regexIMFoundation = @".*/PrivateFrameworks/IMFoundation.framework.*";
        [packageEssentialsRegexes addObject:regexIMFoundation];
        
        // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/WebKit2
        NSString *regexWebKit2 = @".*/PrivateFrameworks/WebKit2.framework.*";
        [packageEssentialsRegexes addObject:regexWebKit2];
        
        // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/CoreRecognition.framework/Versions/A/CoreRecognition
        NSString *regexCoreRecognition = @".*/PrivateFrameworks/CoreRecognition.framework.*";
        [packageEssentialsRegexes addObject:regexCoreRecognition];
        
        // warning, could not bind /System/Library/PrivateFrameworks/Shortcut.framework/Versions/A/Shortcut because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/HelpData.framework/Versions/A/HelpData
        NSString *regexHelpData = @".*/PrivateFrameworks/HelpData.framework.*";
        [packageEssentialsRegexes addObject:regexHelpData];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDSFoundation.framework/Versions/A/IDSFoundation
        NSString *regexIDSFoundation = @".*/PrivateFrameworks/IDSFoundation.framework.*";
        [packageEssentialsRegexes addObject:regexIDSFoundation];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/DiagnosticLogCollection.framework/Versions/A/DiagnosticLogCollection
        NSString *regexDiagnosticLogCollection = @".*/PrivateFrameworks/DiagnosticLogCollection.framework.*";
        [packageEssentialsRegexes addObject:regexDiagnosticLogCollection];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDS.framework/Versions/A/IDS
        NSString *regexIDS = @".*/PrivateFrameworks/IDS.framework.*";
        [packageEssentialsRegexes addObject:regexIDS];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/Frameworks/InstantMessage.framework/Versions/A/InstantMessage
        NSString *regexInstantMessage = @".*/Frameworks/InstantMessage.framework.*";
        [packageEssentialsRegexes addObject:regexInstantMessage];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/usr/lib/libtidy.A.dylib is missing arch i386
        NSString *regexLibtidy = @".*/lib/libtidy.A.dylib.*";
        [packageEssentialsRegexes addObject:regexLibtidy];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/CommonUtilities.framework/Versions/A/CommonUtilities is missing arch i386
        NSString *regexCommonUtilities = @".*/PrivateFrameworks/CommonUtilities.framework.*";
        [packageEssentialsRegexes addObject:regexCommonUtilities];
        
        // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom is missing arch i386
        NSString *regexBom = @".*/PrivateFrameworks/Bom.framework.*";
        [packageEssentialsRegexes addObject:regexBom];
        
        // update_dyld_shared_cache: warning can't use root '/System/Library/CoreServices/FolderActionsDispatcher.app/Contents/MacOS/FolderActionsDispatcher': file not found
        NSString *regexFolderActionsDispatcher = @".*/FolderActionsDispatcher.app.*";
        [packageEssentialsRegexes addObject:regexFolderActionsDispatcher];
        
        // update_dyld_shared_cache: warning can't use root '/System/Library/Image Capture/Support/icdd': file not found
        NSString *regexIcdd = @".*/Support/icdd.*";
        [packageEssentialsRegexes addObject:regexIcdd];
        
        // update_dyld_shared_cache: warning can't use root '/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/Support/suggestd': file not found
        NSString *regexCoreSuggestions = @".*/PrivateFrameworks/CoreSuggestions.framework.*";
        [packageEssentialsRegexes addObject:regexCoreSuggestions];
        
        // update_dyld_shared_cache: warning can't use root '/usr/libexec/symptomsd': file not found
        NSString *regexSymptomsd = @".*/libexec/symptomsd.*";
        [packageEssentialsRegexes addObject:regexSymptomsd];
        
        // update_dyld_shared_cache: warning can't use root '/usr/libexec/systemstats_boot': file not found
        NSString *regexSystemstats_boot = @".*/libexec/systemstats_boot.*";
        [packageEssentialsRegexes addObject:regexSystemstats_boot];
        
        // warning, could not bind /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom because /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/AppleFSCompression.framework/Versions/A/AppleFSCompression is missing arch i386
        NSString *regexAppleFSCompression = @".*/PrivateFrameworks/AppleFSCompression.framework.*";
        [packageEssentialsRegexes addObject:regexAppleFSCompression];
        
        // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on /Volumes/dmg.IuuO1f/System/Library/Frameworks/Contacts.framework/Versions/A/Contacts
        NSString *regexContacts = @".*/Frameworks/Contacts.framework.*";
        [packageEssentialsRegexes addObject:regexContacts];
        
        // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSpotlight.framework/Versions/A/CoreSpotlight
        NSString *regexCoreSpotlight = @".*/PrivateFrameworks/CoreSpotlight.framework.*";
        [packageEssentialsRegexes addObject:regexCoreSpotlight];
        
        // update_dyld_shared_cache failed: could not bind symbol _FZAVErrorDomain in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore expected in /System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore
        NSString *regexIMAVCore = @".*/PrivateFrameworks/IMAVCore.framework.*";
        [packageEssentialsRegexes addObject:regexIMAVCore];
        
        //NSString *regexOpenGLAll = @".*[Oo]pen[Gg][Ll].*";
        //[packageEssentialsRegexes addObject:regexOpenGLAll];
        
        NSString *regexGLEngine = @".*/Resources/GLEngine.bundle.*";
        [packageEssentialsRegexes addObject:regexGLEngine];
        
        NSString *regexGLRendererFloat = @".*/Resources/GLRendererFloat.bundle.*";
        [packageEssentialsRegexes addObject:regexGLRendererFloat];
        
        NSString *regexGPUCompiler = @".*/PrivateFrameworks/GPUCompiler.framework.*";
        [packageEssentialsRegexes addObject:regexGPUCompiler];
        
        NSString *regexGeForceGLDriver = @".*/PrivateFrameworks/GeForceGLDriver.bundle.*";
        [packageEssentialsRegexes addObject:regexGeForceGLDriver];
    }
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
    
    NSString *baseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *baseSystemBinariesDict = [sourceItemsDict[baseSystemBinariesPath] mutableCopy];
    NSMutableArray *baseSystemBinariesRegexes;
    if ( [baseSystemBinariesDict count] != 0 ) {
        baseSystemBinariesRegexes = [baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
        if ( baseSystemBinariesRegexes == nil )
        {
            baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        baseSystemBinariesDict = [[NSMutableDictionary alloc] init];
        baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
    }
    
    NSArray *casperImagingDepencenciesBaseSystemBinaries = buildDict[@"BaseSystemBinaries"];
    if ( [casperImagingDepencenciesBaseSystemBinaries count] != 0 ) {
        [baseSystemBinariesRegexes addObjectsFromArray:casperImagingDepencenciesBaseSystemBinaries];
    }
    
    baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] = baseSystemBinariesRegexes;
    sourceItemsDict[baseSystemBinariesPath] = baseSystemBinariesDict;
    
    
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
    
    NSString *regexExpect = @".*/bin/expect.*";
    [packageBSDRegexes addObject:regexExpect];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addTaskgated:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    
    NSString *regexTaskgated = @".*taskgated.*";
    [packageEssentialsRegexes addObject:regexTaskgated];
    
    
    // For taskgated-helper
    NSString *regexConfigurationProfiles = @".*ConfigurationProfiles.framework.*";
    [packageEssentialsRegexes addObject:regexConfigurationProfiles];
    
    NSString *regexUniversalAccess = @".*UniversalAccess.framework.*";
    [packageEssentialsRegexes addObject:regexUniversalAccess];
    
    NSString *regexManagedClient = @".*ManagedClient.*";
    [packageEssentialsRegexes addObject:regexManagedClient];
    
    NSString *regexSyspolicy = @".*syspolicy.*";
    [packageEssentialsRegexes addObject:regexSyspolicy];
    
    
    // For CoreServicesUIAgent
    NSString *regexCoreServicesUIAgent = @".*CoreServicesUIAgent.*";
    [packageEssentialsRegexes addObject:regexCoreServicesUIAgent];
    
    NSString *regexCoreServicesUIAgentPlist = @".*coreservices.uiagent.plist.*";
    [packageEssentialsRegexes addObject:regexCoreServicesUIAgentPlist];
    
    NSString *regexXprotectFramework = @".*XprotectFramework.framework.*";
    [packageEssentialsRegexes addObject:regexXprotectFramework];
    
    // For Kernel
    NSString *regexMobileFileIntegrity = @".*MobileFileIntegrity.plist*";
    [packageEssentialsRegexes addObject:regexMobileFileIntegrity];
    
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
    
    // For Kernel
    NSString *regexAmfid = @".*amfid.*";
    [packageBSDRegexes addObject:regexAmfid];
    
    [packageBSDRegexes addObject:regexSyspolicy];
    [packageBSDRegexes addObject:regexTaskgated];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
    
}

+ (void)addPython:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    [packageBSDRegexes addObject:regexPython];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addSystemUIServer:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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

+ (void)addSystemkeychain:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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

+ (void)addConsole:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    NSString *packageAdditionalEssentialsPath = [NSString stringWithFormat:@"%@/Packages/AdditionalEssentials.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageAdditionalEssentialsDict = sourceItemsDict[packageAdditionalEssentialsPath];
    NSMutableArray *packageAdditionalEssentialsRegexes;
    if ( [packageAdditionalEssentialsDict count] != 0 ) {
        packageAdditionalEssentialsRegexes = packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey];
        if ( packageAdditionalEssentialsRegexes == nil )
        {
            packageAdditionalEssentialsRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageAdditionalEssentialsDict = [[NSMutableDictionary alloc] init];
        packageAdditionalEssentialsRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *regexConsole = @".*Console.app.*";
    [packageAdditionalEssentialsRegexes addObject:regexConsole];
    
    packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageAdditionalEssentialsRegexes;
    sourceItemsDict[packageAdditionalEssentialsPath] = packageAdditionalEssentialsDict;
    
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
    
    NSString *regexShareKit = @".*ShareKit.framework.*";
    [packageEssentialsRegexes addObject:regexShareKit];
    
    NSString *regexSystemClr = @".*/Colors/System.clr.*";
    [packageEssentialsRegexes addObject:regexSystemClr];
    
    int sourceVersionMinor = (int)[[source expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor ) {
        
        // For 'ShareKit'
        NSString *regexAccountsUI = @".*AccountsUI.framework.*";
        [packageEssentialsRegexes addObject:regexAccountsUI];
        
        // For 'AddressBook'
        NSString *regexContactsPersistence = @".*ContactsPersistence.framework.*";
        [packageEssentialsRegexes addObject:regexContactsPersistence];
    }
    
    NSString *regexViewBridge = @".*ViewBridge.framework.*";
    [packageEssentialsRegexes addObject:regexViewBridge];
    
    NSString *regexSocial = @".*/Social.framework.*";
    [packageEssentialsRegexes addObject:regexSocial];
    
    NSString *regexAccountsDaemon = @".*AccountsDaemon.framework.*";
    [packageEssentialsRegexes addObject:regexAccountsDaemon];
    
    NSString *regexCloudDocs = @".*CloudDocs.framework.*";
    [packageEssentialsRegexes addObject:regexCloudDocs];
    
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
}

+ (void)addRuby:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
    
    NSString *regexRuby = @".*[Rr]uby.*";
    [packageEssentialsRegexes addObject:regexRuby];
    
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
    
    [packageBSDRegexes addObject:regexRuby];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

+ (void)addDtrace:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    
    NSString *regexDtrace = @".*(lib|libexec|sbin)/dtrace.*";
    [packageEssentialsRegexes addObject:regexDtrace];
    
    NSString *regexCoreSymbolication = @".*[Cc]ore[Ss]ymbolication.*";
    [packageEssentialsRegexes addObject:regexCoreSymbolication];
    
    NSString *regexDebuggingTools = @".*/bin/(dtruss).*";
    [packageEssentialsRegexes addObject:regexDebuggingTools];
    
    NSString *regexComAppleMetadata = @".*com.apple.metadata.*";
    [packageEssentialsRegexes addObject:regexComAppleMetadata];
    
    // Used by mds tools (mds, index)
    NSString *regexSpotlightIndex = @".*/SpotlightIndex.framework.*";
    [packageEssentialsRegexes addObject:regexSpotlightIndex];
    
    // Used by mds tools (mds, index)
    NSString *regexCoreDuet = @".*/PrivateFrameworks/CoreDuet.framework.*";
    [packageEssentialsRegexes addObject:regexCoreDuet];
    
    // Used by mds tools (mds, index)
    NSString *regexCoreDuetDaemonProtocol = @".*/PrivateFrameworks/CoreDuetDaemonProtocol.framework.*";
    [packageEssentialsRegexes addObject:regexCoreDuetDaemonProtocol];
    
    // Used by mds tools (mds, index)
    NSString *regexCoreDuetDebugLogging = @".*/PrivateFrameworks/CoreDuetDebugLogging.framework.*";
    [packageEssentialsRegexes addObject:regexCoreDuetDebugLogging];
    
    // Used by mds tools (mds)
    NSString *regexMDSChannel = @".*/MDSChannel.framework.*";
    [packageEssentialsRegexes addObject:regexMDSChannel];
    
    // Used by mds tools (mds)
    NSString *regexDCERPC = @".*/PrivateFrameworks/DCERPC.framework.*";
    [packageEssentialsRegexes addObject:regexDCERPC];
    
    // Used by mds tools (mds)
    NSString *regexMBClient = @".*/PrivateFrameworks/SMBClient.framework.*";
    [packageEssentialsRegexes addObject:regexMBClient];
    
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
    
    NSString *regexSnoop = @".*snoop.*";
    [packageBSDRegexes addObject:regexSnoop];
    
    [packageBSDRegexes addObject:regexDtrace];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
    
}

+ (void)addAppleScript:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    
    NSString *regexAppleScript = @".*/[Aa]pple[Ss]cript.*";
    [packageEssentialsRegexes addObject:regexAppleScript];
    
    NSString *regexAppleEvents = @".*appleevents.*";
    [packageEssentialsRegexes addObject:regexAppleEvents];
    
    NSString *regexSdefDTD = @".*/sdef.dtd.*";
    [packageEssentialsRegexes addObject:regexSdefDTD];
    
    NSString *regexScriptingAdditions = @".*ScriptingAdditions.*";
    [packageEssentialsRegexes addObject:regexScriptingAdditions];
    
    // TESTING
    //NSString *regexScript = @".*/[Ss]cript\\ [Ee]ditor.*";
    //[packageEssentialsRegexes addObject:regexScript];
    
    // Still need to get this to launch through launchd somehow?
    
    // System Events.app
    NSString *regexSystemEvents = @".*/[Ss]ystem\\ [Ee]vents.*";
    [packageEssentialsRegexes addObject:regexSystemEvents];
    
    // Required for System Events.app
    NSString *regexAutomator = @".*/Automator.framework.*";
    [packageEssentialsRegexes addObject:regexAutomator];
    
    // Required for System Events.app
    NSString *regexOSAKit = @".*/OSAKit.framework.*";
    [packageEssentialsRegexes addObject:regexOSAKit];
    
    // Required for System Events.app
    NSString *regexScriptingBridge = @".*/ScriptingBridge.framework.*";
    [packageEssentialsRegexes addObject:regexScriptingBridge];
    
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
    
    NSString *regexOSAScript = @".*/osascript.*";
    [packageBSDRegexes addObject:regexOSAScript];
    
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
}

- (void)addDependenciesForBinaryAtPath:(NSString *)binaryPath sourceItemsDict:(NSMutableDictionary *)sourceItemsDict workflowItem:(NBCWorkflowItem *)workflowItem  {
    NBCSource *source = [workflowItem source];
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy];
    NSMutableArray *packageEssentialsRegexes;
    if ( [packageEssentialsDict count] != 0 ) {
        packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
        if ( packageEssentialsRegexes == nil )
        {
            packageEssentialsRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        packageEssentialsDict = [[NSMutableDictionary alloc] init];
        packageEssentialsRegexes = [[NSMutableArray alloc] init];
    }
    
    NSString *baseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [[source installESDVolumeURL] path]];
    NSMutableDictionary *baseSystemBinariesDict = [sourceItemsDict[baseSystemBinariesPath] mutableCopy];
    NSMutableArray *baseSystemBinariesRegexes;
    if ( [baseSystemBinariesDict count] != 0 ) {
        baseSystemBinariesRegexes = [baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
        if ( baseSystemBinariesRegexes == nil )
        {
            baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
        }
    } else {
        baseSystemBinariesDict = [[NSMutableDictionary alloc] init];
        baseSystemBinariesRegexes = [[NSMutableArray alloc] init];
    }
    
    NSURL *dependencyCheckerScript = [[NSBundle mainBundle] URLForResource:@"sharedLibraryDependencyChecker" withExtension:@"bash"];
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:[dependencyCheckerScript path]];
    
    NSArray *args = @[
                      @"-t", binaryPath,
                      @"-t", @"/Users/erikberglund/Desktop/Casper/Casper Imaging.app/Contents/Support/jamf",
                      @"-t", @"/System/Library/Frameworks/AppleScriptObjC.framework/Versions/A/AppleScriptObjC",
                      @"-t", @"/System/Library/Frameworks/OpenGL.framework/Versions/A/Libraries/libLLVMContainer.dylib",
                      @"-t", @"/System/Library/PrivateFrameworks/ViewBridge.framework/Versions/A/ViewBridge",
                      @"-t", @"/System/Library/Extensions/GeForceGLDriver.bundle/Contents/MacOS/libclh.dylib",
                      @"-t", @"/System/Library/Frameworks/OpenCL.framework/Versions/A/Libraries/libcldcpuengine.dylib",
                      @"-t", @"/System/Library/PrivateFrameworks/AppleGVA.framework/Versions/A/AppleGVA",
                      @"-t", @"/System/Library/QuickTime/QuickTimeComponents.component/Contents/MacOS/QuickTimeComponents",
                      @"-e", @".*OpenGL.*",
                      @"-i", @".*libCoreVMClient.dylib$", // There is something special with the included version of this dylib, have not investigated
                      @"-a",
                      @"-x"
                      ];
    
    [newTask setArguments:args];
    
    
    
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        [newTask launch];
        [newTask waitUntilExit];
        
        NSData *newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
        NSData *newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
        
        NSString *stdOut = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
        NSString *stdErr = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
        
        if ( [newTask terminationStatus] == 0 ) {
            NSMutableArray *regexArray = [[stdOut componentsSeparatedByString:@"\n"] mutableCopy];
            [regexArray removeObject:@""];
            DDLogInfo(@"Found %lu dependencies", (unsigned long)[regexArray count]);
            for ( NSString *regex in regexArray ) {
                [packageEssentialsRegexes addObject:regex];
                [baseSystemBinariesRegexes addObject:regex];
            }
            packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
            sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
            
            baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] = baseSystemBinariesRegexes;
            sourceItemsDict[baseSystemBinariesPath] = baseSystemBinariesDict;
        } else {
            DDLogError(@"[ERROR] script failed!");
            DDLogError(@"[ERROR] %@", stdErr);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ( [self->_delegate respondsToSelector:@selector(dependencyCheckComplete:workflowItem:)] ) {
                [self->_delegate dependencyCheckComplete:[sourceItemsDict copy] workflowItem:workflowItem];
            }
        });
    });
}

+ (void)addVNC:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
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
    
    NSString *regexPerl = @".*[Pp]erl.*";
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

+ (void)addARD:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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

+ (void)addKerberos:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source {
    
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
