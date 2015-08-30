//
//  NBCDiskImageController.m
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

/* TODO Support for SLA, check DiskAribitrator Project */
/* also, condence to more unversal methods like hdiutilTaskWithCommand */

#import "NBCDiskImageController.h"

#import <DiskArbitration/DiskArbitration.h>
#import "NSString+randomString.h"
#import "NBCController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCDiskImageController

- (id)initWithDelegate:(id<NBCAlertDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

+ (BOOL)attachDiskImageAndReturnPropertyList:(id *)propertyList dmgPath:(NSURL *)dmgPath options:(NSArray *)options error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSData *newTaskOutputData;
    NSMutableDictionary *errorInfo;
    NSString *failureReason;
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"attach"];
    [args addObjectsFromArray:options];
    [args addObject:[dmgPath path]];
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    
    [newTask launch];
    [newTask waitUntilExit];
    
    newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] == 0 ) {
        
        // Set hdiutil output to propertyList
        NSError *plistError = nil;
        *propertyList = [NSPropertyListSerialization propertyListWithData:newTaskOutputData options:NSPropertyListImmutable format:nil error:&plistError];
        if ( propertyList == nil ) {
            failureReason = [plistError localizedDescription];
        }
        
        // Add error if hdiutil output could not be serialized as a property list
        if ( ! *propertyList ) {
            failureReason = NSLocalizedString(@"hdiutil output is not a property list.", nil);
            retval = NO;
        }
    } else {
        
        // Add error if hdiutil exited with non-zero exit status
        failureReason = NSLocalizedString(@"hdiutil exited with non-zero exit status.", nil);
        retval = NO;
    }
    
    // If any error was encoutered, populate NSError object
    if ( retval == NO && error ) {
        errorInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                     NSLocalizedString(@"Error executing hdiutil command", nil), NSLocalizedDescriptionKey,
                     failureReason, NSLocalizedFailureReasonErrorKey,
                     failureReason, NSLocalizedRecoverySuggestionErrorKey,
                     nil];
        *error = [NSError errorWithDomain:@"com.github.NBICreator" code:-1 userInfo:errorInfo];
    }
    
    return retval;
} // attachDiskImageAndReturnPropertyList

+ (BOOL)attachDiskImageVolumeByOffsetAndReturnPropertyList:(id *)propertyList dmgPath:(NSURL *)dmgPath options:(NSArray *)options offset:(NSString *)offset error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSData *newTaskOutputData;
    NSMutableDictionary *errorInfo;
    NSString *failureReason;
    
    // Setup Task
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"attach"];
    [args addObject:@"-section"];
    [args addObject:offset];
    [args addObjectsFromArray:options];
    [args addObject:[dmgPath path]];
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] == 0 ) {
        
        // Set hdiutil output to propertyList
        NSError *plistError = nil;
        *propertyList = [NSPropertyListSerialization propertyListWithData:newTaskOutputData options:NSPropertyListImmutable format:nil error:&plistError];
        if ( propertyList == nil ) {
            failureReason = [plistError localizedDescription];
        }
        
        // Add error if hdiutil output could not be serialized as a property list
        if ( ! *propertyList ) {
            failureReason = NSLocalizedString(@"hdiutil output is not a property list.", nil);
            retval = NO;
        }
    } else {
        
        // Add error if hdiutil exited with non-zero exit status
        failureReason = NSLocalizedString(@"hdiutil exited with non-zero exit status.", nil);
        retval = NO;
    }
    
    // If any error was encoutered, populate NSError object
    if ( retval == NO && error ) {
        errorInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                     NSLocalizedString(@"Error executing hdiutil command", nil), NSLocalizedDescriptionKey,
                     failureReason, NSLocalizedFailureReasonErrorKey,
                     failureReason, NSLocalizedRecoverySuggestionErrorKey,
                     nil];
        *error = [NSError errorWithDomain:@"com.github.NBICreator" code:-1 userInfo:errorInfo];
    } // mountDiskImageVolumeByOffsetAndReturnPropertyList
    
    return retval;
} // attachDiskImageAndReturnPropertyList

+ (BOOL)mountDiskImageVolumeByDeviceAndReturnMountURL:(id *)mountURL deviceName:(NSString *)devName error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSData *newTaskOutputData;
    NSMutableDictionary *errorInfo;
    NSString *failureReason;
    
    *mountURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]] isDirectory:YES];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ( ! [fileManager createDirectoryAtURL:*mountURL withIntermediateDirectories:NO attributes:nil error:error] ) {
        retval = NO;
        return retval;
    }
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/sbin/diskutil"];
    
    NSArray *args = @[
                      @"quiet",
                      @"mount",
                      @"readOnly",
                      @"-mountPoint", [*mountURL path],
                      devName,
                      ];
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    //NSData *newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
    //NSString *standardError = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
    
    if ( [newTask terminationStatus] == 0 ) {
        
    } else {
        
        failureReason = NSLocalizedString(@"hdiutil exited with non-zero exit status.", nil);
        retval = NO;
    }
    
    // If any error was encoutered, populate NSError object
    if ( retval == NO && error ) {
        errorInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                     NSLocalizedString(@"Error executing hdiutil command", nil), NSLocalizedDescriptionKey,
                     failureReason, NSLocalizedFailureReasonErrorKey,
                     failureReason, NSLocalizedRecoverySuggestionErrorKey,
                     nil];
        *error = [NSError errorWithDomain:@"com.github.NBICreator" code:-1 userInfo:errorInfo];
    }
    
    return retval;
} // attachDiskImageAndReturnPropertyList

+ (BOOL)mountAtPath:(NSString *)path withArguments:(NSArray *)args forDisk:(NSString *)diskID {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DASessionRef session = NULL;
    session = DASessionCreate(kCFAllocatorDefault);
    if ( ! session ) {
        DDLogError(@"[ERROR] Can't create Disk Arbitration session");
        return NO;
    }
    
    DADiskRef disk = NULL;
    disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, [diskID UTF8String]);
    if ( ! disk ) {
        DDLogError(@"[ERROR] DADiskCreateFromBSDName(%s) failed", [diskID UTF8String]);
        return NO;
    }
    
    CFDictionaryRef dd = NULL;
    dd = DADiskCopyDescription(disk);
    if ( ! dd ) {
        DDLogError(@"[ERROR] DADiskCopyDescription(%s) failed", [diskID UTF8String]);
        return NO;
    }
    
    CFStringRef *argv = calloc(args.count + 1, sizeof(CFStringRef));
    CFArrayGetValues((__bridge CFArrayRef)args, CFRangeMake(0, (CFIndex)args.count), (const void **)argv );
    
    NSURL *url = path ? [NSURL fileURLWithPath:path.stringByExpandingTildeInPath] : NULL;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtURL:url withIntermediateDirectories:NO attributes:nil error:nil];
    DADiskMountWithArguments((DADiskRef) disk, (__bridge CFURLRef) url, kDADiskMountOptionDefault, NULL, (__bridge void *)self, argv);
    
    free(argv);
    return YES;
}

+ (BOOL)detachDiskImageAtPath:(NSString *)mountPath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"detach",
                            mountPath,
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    if ( [newTask terminationStatus] != 0 ) {
        [args addObject:@"-force"];
        
        int maxTries;
        for( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            
            // Launch Task
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                return retval;
            }
        }
        retval = NO;
    }
    
    return retval;
} // detachDiskImageAtPath

+ (BOOL)detachDiskImageDevice:(NSString *)devName {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    // Setup Task
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"detach",
                            devName,
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] != 0 ) {
        [args addObject:@"-force"];
        
        int maxTries;
        for( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            
            // Launch Task
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                return retval;
            }
        }
        retval = NO;
    }
    
    return retval;
} // detachDiskImageDevice

+ (BOOL)unmountVolumeAtPath:(NSString *)mountPath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    // Setup Task
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"unmount",
                            mountPath,
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    if ( [newTask terminationStatus] != 0 ) {
        [args addObject:@"-force"];
        
        int maxTries;
        for ( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            
            // Launch Task
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                return retval;
            }
        }
        retval = NO;
    }
    
    return retval;
} // unmountVolumeAtPath

+ (BOOL)compactDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Compacting disk image...");
    BOOL retval = NO;
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    NSArray *args = @[
                      @"compact", diskImagePath,
                      @"-shadow", shadowImagePath,
                      @"-batteryallowed",
                      @"-puppetstrings",
                      @"-plist"
                      ];
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *standardOutput = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
    
    NSLog(@"standardOutput=%@", standardOutput);
    
    NSData *newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
    NSString *standardError = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
    
    if ( [newTask terminationStatus] == 0 ) {
        retval = YES;
    } else {
        DDLogError(@"[ERROR] Disk image conversion failed!");
        DDLogError(@"[ERROR] %@", standardError);
        retval = NO;
    }
    
    return retval;
}

+ (BOOL)convertDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath format:(NSString *)format destinationPath:(NSString *)destinationPath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Converting disk image and shadow file to sparsimage...");
    BOOL retval = NO;
    //NSData *newTaskOutputData;
    NSData *newTaskErrorData;
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    /*
     UDRW - UDIF read/write image
     UDRO - UDIF read-only image
     UDSP - SPARSE (grows with content)
     UDSB - SPARSEBUNDLE (grows with content; bundle-backed)
     */
    
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[
                      @"convert", diskImagePath,
                      @"-format", format,
                      @"-o", destinationPath,
                      ]];
    
    if ( [shadowImagePath length] != 0 ) {
        [args addObject:@"-shadow"];
        [args addObject:shadowImagePath];
    }
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    //newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    //NSString *standardOutput = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
    
    newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
    NSString *standardError = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
    
    if ( [newTask terminationStatus] == 0 ) {
        retval = YES;
    } else {
        DDLogError(@"[ERROR] Disk image conversion failed!");
        DDLogError(@"[ERROR] %@", standardError);
        retval = NO;
    }
    
    return retval;
} // convertDiskImageAtPath:shadowImagePath

+ (BOOL)resizeDiskImageAtURL:(NSURL *)diskImageURL shadowImagePath:(NSString *)shadowImagePath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Resizing disk image using shadow file...");
    BOOL retval = NO;
    
    //NSData *newTaskOutputData;
    NSData *newTaskErrorData;
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    NSArray *args = @[
                      @"resize",
                      @"-size", @"10G",
                      @"-shadow", shadowImagePath,
                      [diskImageURL path],
                      ];
    
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    //newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    //NSString *standardOutput = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
    
    newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
    NSString *standardError = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
    
    if ( [newTask terminationStatus] == 0 ) {
        retval = YES;
    } else {
        DDLogError(@"[ERROR] Disk image resize failed!");
        DDLogError(@"[ERROR] %@", standardError);
        retval = NO;
    }
    
    return retval;
}

+ (BOOL)getOffsetForRecoveryPartitionOnImageDevice:(id *)offset diskIdentifier:(NSString *)diskIdentifier {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = NO;
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"pmap",
                            diskIdentifier,
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] == 0 ) {
        NSString *standardOutput = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
        NSArray *standardOutputLines = [[NSArray alloc] init];
        standardOutputLines = [standardOutput componentsSeparatedByString:@"\n"];
        for (NSString *line in standardOutputLines) {
            if ( [line containsString:@"Apple_Boot"] || [line containsString:@"Recovery HD"] ) {
                NSString *lineRegex = [line stringByReplacingOccurrencesOfString:@"[ ]+"
                                                                      withString:@" "
                                                                         options:NSRegularExpressionSearch
                                                                           range:NSMakeRange(0, [line length])];
                
                NSString *lineCleaned = [lineRegex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                NSArray *lineArray = [lineCleaned componentsSeparatedByString:@" "];
                *offset = lineArray[2];
                retval = YES;
            }
        }
    }
    return retval;
} // getOffsetForRecoveryPartitionOnImageDevice

+ (NSURL *)getMountURLFromHdiutilOutputPropertyList:(NSDictionary *)propertyList {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *mountURL;
    NSArray *systemEntities = [propertyList[@"system-entities"] copy];
    for ( NSDictionary *dict in systemEntities ) {
        NSString *contentHint = dict[@"content-hint"];
        if ( [contentHint isEqualTo:@"Apple_HFS"] ) {
            mountURL = [NSURL fileURLWithPath:dict[@"mount-point"]];
        }
    }
    
    if ( mountURL == nil && [systemEntities count] == 1 ) {
        NSDictionary *dict = systemEntities[0];
        mountURL = [NSURL fileURLWithPath:dict[@"mount-point"]];
    }
    
    return mountURL;
} // getMountURLFromHdiutilOutputPropertyList

+ (NSString *)getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:(NSDictionary *)propertyList {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *recoveryPartitionIdentifier;
    NSArray *systemEntities = [propertyList[@"system-entities"] copy];
    for (NSDictionary *dict in systemEntities)
    {
        NSString *contentHint = dict[@"content-hint"];
        if ( [contentHint isEqualTo:@"Apple_Boot"] )
        {
            recoveryPartitionIdentifier = dict[@"dev-entry"];
        }
    }
    return recoveryPartitionIdentifier;
}

+ (NSString *)getRecoveryPartitionIdentifierFromVolumeMountURL:(NSURL *)mountURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *recoveryPartitionIdentifier;
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/bin/bash"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-c",
                            [NSString stringWithFormat:@"/usr/sbin/diskutil info \"%@\" | /usr/bin/grep \"Recovery Disk:\" | /usr/bin/awk '{ print $NF }'", [mountURL path]],
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskStandardOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    
    if ( [newTask terminationStatus] == 0 ) {
        NSString *partitionIdentifier = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
        partitionIdentifier = [partitionIdentifier stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if ( [partitionIdentifier length] != 0 && [partitionIdentifier containsString:@"/dev/"] )
        {
            recoveryPartitionIdentifier = partitionIdentifier;
        } else if ( [partitionIdentifier length] != 0 ) {
            recoveryPartitionIdentifier = [NSString stringWithFormat:@"/dev/%@", partitionIdentifier];
        }
    }
    return recoveryPartitionIdentifier;
}

+ (NSDictionary *)getHdiutilInfoDict {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *hdiutilDict;
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/bin/bash"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:
                            @"-c",
                            @"/usr/bin/hdiutil info -plist",
                            nil];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    
    NSData *newTaskStandardOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSPropertyListFormat format;
    NSError *error;
    if ( [newTask terminationStatus] == 0 ) {
        hdiutilDict = [NSPropertyListSerialization propertyListWithData:newTaskStandardOutputData options:NSPropertyListImmutable format:&format error:&error];
        if ( hdiutilDict == nil ) {
            NSLog(@"Could not get hdiutilDict");
            NSLog(@"Error: %@", error);
        }
    }
    return hdiutilDict;
}

+ (NSURL *)getDiskImageURLFromMountURL:(NSURL *)mountURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *diskImageURL;
    NSDictionary *hdiutilDict = [self getHdiutilInfoDict];
    for (NSDictionary *image in hdiutilDict[@"images"]) {
        NSDictionary *systemEntities = image[@"system-entities"];
        for (NSDictionary *entity in systemEntities) {
            NSString *mountPoint = entity[@"mount-point"];
            if (mountPoint) {
                if ([mountPoint isEqualToString:[mountURL path]]) {
                    NSString *imagePath = image[@"image-path"];
                    diskImageURL = [NSURL fileURLWithPath:imagePath];
                    return diskImageURL;
                }
            }
        }
    }
    return diskImageURL;
}



+ (NBCDisk *)getBaseSystemDiskFromDiskImageURL:(NSURL *)diskImageURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCDisk *disk;
    NSDictionary *hdiutilDict = [self getHdiutilInfoDict];
    for ( NSDictionary *image in hdiutilDict[@"images"] ) {
        NSString *imagePath = image[@"image-path"];
        if ( [[diskImageURL path] isEqualToString:imagePath] ) {
            NSDictionary *systemEntities = image[@"system-entities"];
            for ( NSDictionary *entity in systemEntities ) {
                NSString *mountPoint = entity[@"mount-point"];
                if ( mountPoint ) {
                    disk = [NBCController diskFromVolumeURL:[NSURL fileURLWithPath:mountPoint]];
                }
            }
        }
    }
    
    return disk;
}

+ (NBCDisk *)checkDiskImageAlreadyMounted:(NSURL *)diskImageURL imageType:(NSString *)imageType {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Checking if %@ is already mounted...", [diskImageURL path]);
    DDLogDebug(@"diskImageURL=%@", diskImageURL);
    DDLogDebug(@"imageType=%@", imageType);
    NBCDisk *disk;
    NSString *partitionHint;
    
    if (
        [imageType isEqualToString:@"System"]
        ) {
        partitionHint = @"Apple_HFS";    // "Apple_HFS" - Mac OS Extended (HFS+)
    } else if (
               [imageType isEqualToString:@"BaseSystem"] ||
               [imageType isEqualToString:@"InstallESD"] ||
               [imageType isEqualToString:@"NetInstall"]
               ) {
        disk = [self getBaseSystemDiskFromDiskImageURL:diskImageURL];
        return disk;
    } else if (
               [imageType isEqualToString:@"Recovery"]
               ) {
        partitionHint = @"426F6F74-0000-11AA-AA11-00306543ECAC";    // "" - OS X Recovery Partition
    }
    NSMutableArray *diskImageUUIDs = [[NSMutableArray alloc] init];
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSArray *args = @[
                      @"imageinfo",
                      @"-plist",
                      [diskImageURL path]
                      ];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask launch];
    [newTask waitUntilExit];
    
    NSData *newTaskStandardOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSPropertyListFormat format;
    NSError *error;
    
    if ( [newTask terminationStatus] == 0 ) {
        NSDictionary *hdiutilDict = [NSPropertyListSerialization propertyListWithData:newTaskStandardOutputData
                                                                              options:NSPropertyListImmutable
                                                                               format:&format
                                                                                error:&error];
        if ( hdiutilDict ) {
            NSDictionary *partitions = hdiutilDict[@"partitions"];
            NSArray *partitionsArray = partitions[@"partitions"];
            
            for (NSDictionary *partition in partitionsArray) {
                if ([partition[@"partition-hint"] isEqualToString:partitionHint]) {
                    NSString *partitionUUID = partition[@"partition-UUID"];
                    if ( [partitionUUID length] != 0 ) {
                        [diskImageUUIDs addObject:partitionUUID];
                    }
                }
            }
        } else {
            NSLog(@"Error getting propertyList from hdiutil");
            NSLog(@"Error: %@", error);
        }
    }
    
    NSArray *mountedDisksUUIDs = [NBCController mountedDiskUUUIDs];
    
    for (NSString *uuid in diskImageUUIDs) {
        for (NSDictionary *dict in mountedDisksUUIDs) {
            if ([uuid isEqualToString:dict[@"uuid"]]) {
                return dict[@"disk"];
            }
        }
    }
    
    if ( ( [imageType isEqualToString:@"System"] || [imageType isEqualToString:@"NetInstall"] ) && disk == nil ) {
        disk = [self getBaseSystemDiskFromDiskImageURL:diskImageURL];
    }
    
    return disk;
}

@end
