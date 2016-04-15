//
//  NBCDiskController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-29.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCDiskController.h"

#import "NBCController.h"
#import "NBCDisk.h"
#import "NBCDiskArbitrator.h"
#import "NBCDiskImageController.h"
#import "NBCError.h"
#import "NBCLogging.h"
#import "NBCSource.h"
#import "NSString+randomString.h"
#import <DiskArbitration/DiskArbitration.h>

DDLogLevel ddLogLevel;

@implementation NBCDiskController

+ (BOOL)verifySystemDisk:(NBCDisk *)disk source:(NBCSource *)source requireRecoveryPartition:(BOOL)requireRecoveryPartition error:(NSError **)error {

    DDLogInfo(@"Verifying that disk contains a valid OS X System...");

    NSURL *systemVolumeURL = [disk volumeURL];
    DDLogDebug(@"[DEBUG] System disk volume path: %@", [systemVolumeURL path]);

    if ([systemVolumeURL checkResourceIsReachableAndReturnError:error]) {
        [source setSystemDisk:disk];
        [source setSystemVolumeURL:systemVolumeURL];
        [source setSystemVolumeBSDIdentifier:[disk BSDName]];

        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] SystemVersion.plist path: %@", [systemVersionPlistURL path]);

        if ([systemVersionPlistURL checkResourceIsReachableAndReturnError:error]) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];

            if ([systemVersionPlist count] != 0) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"Disk os version: %@", systemOSVersion);

                if ([systemOSVersion length] != 0) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];

                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"Disk os build: %@", systemOSBuild);

                    if ([systemOSBuild length] != 0) {
                        [source setSystemOSBuild:systemOSBuild];
                        [source setSourceBuild:systemOSBuild];

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

    if (requireRecoveryPartition && ![[source systemOSVersion] hasPrefix:@"10.6"]) {
        return [self verifyRecoveryPartitionFromSystemDisk:disk source:source error:error];
    } else {
        return YES;
    }
}

+ (BOOL)verifyRecoveryPartitionFromSystemDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error {

    DDLogInfo(@"Verifying that system disk contains a valid recovery partition...");

    NSURL *systemVolumeURL = [systemDisk volumeURL];
    DDLogDebug(@"[DEBUG] Disk image system volume path: %@", [systemVolumeURL path]);

    if (![systemVolumeURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    NSURL *recoveryVolumeURL;
    NSString *recoveryPartitionDiskIdentifier = [self getRecoveryPartitionIdentifierFromVolumeURL:systemVolumeURL];
    DDLogDebug(@"[DEBUG] Disk image recovery partition BSD identifier: %@", recoveryPartitionDiskIdentifier);

    if ([recoveryPartitionDiskIdentifier length] != 0) {
        [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];

        NBCDisk *recoveryDisk = [self diskFromBSDName:recoveryPartitionDiskIdentifier];
        if ([recoveryDisk isMounted]) {
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

            if ([self mountAtPath:[recoveryVolumeURL path] arguments:diskutilOptions diskIdentifier:recoveryPartitionDiskIdentifier]) {

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

    if ([recoveryVolumeURL checkResourceIsReachableAndReturnError:error]) {
        DDLogDebug(@"[DEBUG] Disk image recovery partition is mounted at path: %@", [recoveryVolumeURL path]);
        [source setRecoveryVolumeURL:recoveryVolumeURL];

        NSURL *baseSystemDiskImageURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] Recovery partition BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);

        if ([baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error]) {
            return [NBCDiskImageController verifyBaseSystemDiskImage:baseSystemDiskImageURL source:source error:error];
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // verifyRecoveryPartitionFromSystemDisk

+ (NSString *)getRecoveryPartitionIdentifierFromVolumeURL:(NSURL *)volumeURL {
    DDLogDebug(@"[DEBUG] Getting recovery partition BSD identifier from volume mount path...");
    DDLogDebug(@"[DEBUG] Volume mount path: %@", [volumeURL path]);

    NSString *recoveryPartitionIdentifier;
    NSTask *diskutilTask = [[NSTask alloc] init];
    [diskutilTask setLaunchPath:@"/bin/bash"];
    NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/usr/sbin/diskutil info \"%@\" | /usr/bin/grep \"Recovery Disk:\" | /usr/bin/awk '{ print $NF }'", [volumeURL path]] ];
    [diskutilTask setArguments:args];
    [diskutilTask setStandardOutput:[NSPipe pipe]];
    [diskutilTask setStandardError:[NSPipe pipe]];
    [diskutilTask launch];
    [diskutilTask waitUntilExit];

    NSData *stdOutData = [[[diskutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];

    NSData *stdErrData = [[[diskutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];

    if ([diskutilTask terminationStatus] == 0) {
        DDLogDebug(@"[DEBUG] diskutil command successful!");
        NSString *partitionIdentifier = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        partitionIdentifier = [partitionIdentifier stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if ([partitionIdentifier length] != 0 && [partitionIdentifier containsString:@"/dev/"]) {
            recoveryPartitionIdentifier = partitionIdentifier;
        } else if ([partitionIdentifier length] != 0) {
            recoveryPartitionIdentifier = [NSString stringWithFormat:@"/dev/%@", partitionIdentifier];
        }
        DDLogDebug(@"[DEBUG] Recovery partition BSD identifier: %@", recoveryPartitionIdentifier);
    } else {
        DDLogError(@"[diskutil] %@", stdOut);
        DDLogError(@"[diskutil] %@", stdErr);
        DDLogError(@"[ERROR] diskutil command failed with exit status: %d", [diskutilTask terminationStatus]);
    }
    return recoveryPartitionIdentifier;
} // getRecoveryPartitionIdentifierFromVolumeURL

+ (BOOL)mountAtPath:(NSString *)path arguments:(NSArray *)args diskIdentifier:(NSString *)diskIdentifier {

    DDLogDebug(@"[DEBUG] Mounting disk: %@ at path: %@...", diskIdentifier, path);

    DASessionRef session = NULL;
    session = DASessionCreate(kCFAllocatorDefault);
    if (!session) {
        DDLogError(@"[ERROR] Can't create Disk Arbitration session");
        return NO;
    }

    DADiskRef disk = NULL;
    disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, [diskIdentifier UTF8String]);
    if (!disk) {
        DDLogError(@"[ERROR] DADiskCreateFromBSDName(%s) failed", [diskIdentifier UTF8String]);
        return NO;
    }

    CFDictionaryRef dd = NULL;
    dd = DADiskCopyDescription(disk);
    if (!dd) {
        DDLogError(@"[ERROR] DADiskCopyDescription(%s) failed", [diskIdentifier UTF8String]);
        return NO;
    }

    CFStringRef *argv = calloc(args.count + 1, sizeof(CFStringRef));
    CFArrayGetValues((__bridge CFArrayRef)args, CFRangeMake(0, (CFIndex)args.count), (const void **)argv);

    NSURL *url = path ? [NSURL fileURLWithPath:path.stringByExpandingTildeInPath] : NULL;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:nil];
    DADiskMountWithArguments((DADiskRef)disk, (__bridge CFURLRef)url, kDADiskMountOptionDefault, NULL, (__bridge void *)self, argv);

    free(argv);
    return YES;
} // mountAtPath

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCArbitrator Functions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (NSArray *)mountedDiskUUUIDs {

    // --------------------------------------------------------------
    //  Return array of UUIDs for all mounted disks
    // --------------------------------------------------------------
    NSMutableArray *diskUUIDs = [[NSMutableArray alloc] init];
    NSMutableSet *disks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for (NBCDisk *disk in disks) {
        if ([disk isMounted]) {
            NSMutableDictionary *disksDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:disk, @"disk", nil];
            NSString *uuid = [disk uuid];
            if (uuid) {
                disksDict[@"uuid"] = uuid;
                [diskUUIDs addObject:disksDict];
            }
        }
    }
    return diskUUIDs;
} // mountedDiskUUUIDs

+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName {

    // --------------------------------------------------------------
    //  Return NBCDisk object for passed BSD identifier (if found)
    // --------------------------------------------------------------
    NSString *bsdNameCut = [bsdName lastPathComponent];
    NBCDisk *diskToReturn;
    for (NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks]) {
        if ([[disk BSDName] isEqualToString:bsdNameCut]) {
            diskToReturn = disk;
            break;
        }
    }
    return diskToReturn;
} // diskFromBSDName

+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL {

    // --------------------------------------------------------------
    //  Return NBCDisk object for passed VolumeURL (if found)
    // --------------------------------------------------------------
    NBCDisk *diskToReturn;
    for (NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks]) {
        if ([disk isMounted]) {
            CFDictionaryRef diskDescription = [disk diskDescription];
            CFURLRef value = CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumePathKey);
            if (value) {
                if ([[(__bridge NSURL *)value path] isEqualToString:[volumeURL path]]) {
                    return disk;
                }
            } else {
                DDLogWarn(@"[WARN] Disk %@ is listed as mounted but has no mountpoint!", diskDescription);
            }
        }
    }
    return diskToReturn;
} // diskFromVolumeURL

@end
