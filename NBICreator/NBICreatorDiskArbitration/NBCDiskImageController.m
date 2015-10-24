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
#import "NSString+SymlinksAndAliases.h"
#import "NBCController.h"
#import "NBCLogging.h"
#import "NBCError.h"

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
#pragma unused(error)
    DDLogDebug(@"[DEBUG] Attaching disk image at path: %@", [dmgPath path]);
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObject:@"attach"];
    [args addObjectsFromArray:options];
    [args addObject:[dmgPath path]];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] Attach successful!");
        
        // ------------------------------------------------------------------
        //  Set hdiutil output to passed property list
        // ------------------------------------------------------------------
        NSError *plistError = nil;
        *propertyList = [NSPropertyListSerialization propertyListWithData:stdOutData options:NSPropertyListImmutable format:nil error:&plistError];
        if ( ! *propertyList ) {
            DDLogWarn(@"[hdiutil] %@", stdOut);
            DDLogWarn(@"[hdiutil] %@", stdErr);
            DDLogError(@"[ERROR] hdiutil output could not be serialized as property list");
            *error = plistError;
            return NO;
        }
    } else {
        DDLogWarn(@"[hdiutil] %@", stdOut);
        DDLogWarn(@"[hdiutil] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
        return NO;
    }
    
    return YES;
} // attachDiskImageAndReturnPropertyList

+ (BOOL)attachDiskImageVolumeByOffsetAndReturnPropertyList:(id *)propertyList dmgPath:(NSURL *)dmgPath options:(NSArray *)options offset:(NSString *)offset error:(NSError **)error {
    
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
    DDLogDebug(@"[DEBUG] Mounting disk: %@ at path: %@...", diskID, path);
    
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
    
    if ( [mountPath length] == 0 ) {
        DDLogError(@"[ERROR] No mount path passed to hdiutil! Please check before calling detachDiskImageAtPath");
        return YES;
    }
    
    DDLogDebug(@"[DEBUG] Detaching disk image mounted at path: %@", mountPath);
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"detach",
                            mountPath,
                            nil];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];

    
    if ( [hdiutilTask terminationStatus] != 0 ) {
        DDLogWarn(@"[hdiutil] %@", stdOut);
        DDLogWarn(@"[hdiutil] %@", stdErr);
        DDLogWarn(@"[WARN] Detach failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for ( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            DDLogWarn(@"[WARN] Detach try %d of 3", maxTries);
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Detach successful on try %d!", maxTries);
                return YES;
            }
        }
        
        DDLogError(@"[DEBUG] Detach failed!");
        return NO;
    } else {
        DDLogDebug(@"[DEBUG] Detach successful!");
        return YES;
    }
} // detachDiskImageAtPath

+ (BOOL)detachDiskImageDevice:(NSString *)devName {
    
    if ( [devName length] == 0 ) {
        DDLogError(@"[ERROR] No BSD identifier passed to hdiutil! Please check before calling detachDiskImageDevice");
        return YES;
    }
    
    DDLogDebug(@"[DEBUG] Detaching disk image with device name: %@", devName);
    BOOL retval = YES;
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"detach",
                            devName,
                            nil];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] != 0 ) {
        DDLogWarn(@"[hdiutil] %@", stdOut);
        DDLogWarn(@"[hdiutil] %@", stdErr);
        DDLogWarn(@"[WARN] Detach failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Detach successful on try %d!", maxTries);
                return retval;
            }
        }
        retval = NO;
    } else {
        DDLogDebug(@"[DEBUG] Detach successful!");
    }
    
    return retval;
} // detachDiskImageDevice

+ (BOOL)unmountVolumeAtPath:(NSString *)mountPath {
    DDLogDebug(@"[DEBUG] Unmounting volume at path: %@", mountPath);
    BOOL retval = YES;
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"unmount",
                            mountPath,
                            nil];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] != 0 ) {
        DDLogWarn(@"[hdiutil] %@", stdOut);
        DDLogWarn(@"[hdiutil] %@", stdErr);
        DDLogWarn(@"[WARN] Unmount failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for ( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Unmount successful on try %d!", maxTries);
                return retval;
            }
        }
        retval = NO;
    } else {
        DDLogDebug(@"[DEBUG] Unmount successful!");
    }
    
    return retval;
} // unmountVolumeAtPath

+ (BOOL)compactDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath {
    DDLogInfo(@"Compacting disk image...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", diskImagePath);
    DDLogDebug(@"[DEBUG] Disk image shadow path: %@", shadowImagePath);
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    
    NSArray *args = @[
                      @"compact", diskImagePath,
                      @"-shadow", shadowImagePath,
                      @"-batteryallowed",
                      @"-puppetstrings",
                      @"-plist"
                      ];
    
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] hdiutil command successful!");
        return YES;
    } else {
        DDLogError(@"[hdiutil] %@", stdOut);
        DDLogError(@"[hdiutil] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
        return NO;
    }
}

+ (BOOL)convertDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath format:(NSString *)format destinationPath:(NSString *)destinationPath {
    DDLogInfo(@"Converting disk image...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", diskImagePath);
    DDLogDebug(@"[DEBUG] Disk image selected format: %@", format);
    DDLogDebug(@"[DEBUG] Disk image destination path: %@", destinationPath);
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    
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
        DDLogDebug(@"[DEBUG] Disk image shadow path: %@", shadowImagePath);
        [args addObject:@"-shadow"];
        [args addObject:shadowImagePath];
    }
    
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] hdiutil command successful!");
        return YES;
    } else {
        DDLogError(@"[hdiutil] %@", stdOut);
        DDLogError(@"[hdiutil] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
        return NO;
    }
} // convertDiskImageAtPath:shadowImagePath

+ (BOOL)resizeDiskImageAtURL:(NSURL *)diskImageURL shadowImagePath:(NSString *)shadowImagePath error:(NSError **)error {
    DDLogInfo(@"Resizing disk image using shadow file...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    DDLogDebug(@"[DEBUG] Disk image shadow path: %@", shadowImagePath);
    
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSArray *args = @[
                      @"resize",
                      @"-size", @"10G",
                      @"-shadow", shadowImagePath,
                      [diskImageURL path],
                      ];
    
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] hdiutil command successful!");
        return YES;
    } else {
        DDLogError(@"[hdiutil] %@", stdOut);
        DDLogError(@"[hdiutil] %@", stdErr);
        *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]]];
        return NO;
    }
}

+ (BOOL)getOffsetForRecoveryPartitionOnImageDevice:(id *)offset diskIdentifier:(NSString *)diskIdentifier {
    DDLogDebug(@"[DEBUG] Getting recovery partition byte offset from disk...");
    DDLogDebug(@"[DEBUG] Disk identifier: %@", diskIdentifier);

    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSArray *args = @[ @"pmap", diskIdentifier ];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] hdiutil command successful!");
        NSArray *stdOutLines = [stdOut componentsSeparatedByString:@"\n"];
        for ( NSString *line in stdOutLines ) {
            if ( [line containsString:@"Apple_Boot"] || [line containsString:@"Recovery HD"] ) {
                NSString *lineRegex = [line stringByReplacingOccurrencesOfString:@"[ ]+"
                                                                      withString:@" "
                                                                         options:NSRegularExpressionSearch
                                                                           range:NSMakeRange(0, [line length])];
                
                NSString *lineCleaned = [lineRegex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                NSArray *lineArray = [lineCleaned componentsSeparatedByString:@" "];
                *offset = lineArray[2];
                return YES;
            }
        }
    } else {
        DDLogError(@"[hdiutil] %@", stdOut);
        DDLogError(@"[hdiutil] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
    }
    
    return NO;
} // getOffsetForRecoveryPartitionOnImageDevice

+ (NSURL *)getMountURLFromHdiutilOutputPropertyList:(NSDictionary *)propertyList {
    DDLogDebug(@"[DEBUG] Getting mount path from hdiutil dictionary output...");
    
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
    
    DDLogDebug(@"[DEBUG] Disk image mount path: %@", [mountURL path]);
    return mountURL;
} // getMountURLFromHdiutilOutputPropertyList

+ (NSString *)getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:(NSDictionary *)propertyList {
    DDLogDebug(@"[DEBUG] Getting recovery partition BSD identifier from hdiutil dictionary output...");
    
    NSString *recoveryPartitionIdentifier;
    NSArray *systemEntities = [propertyList[@"system-entities"] copy];
    for ( NSDictionary *dict in systemEntities ) {
        NSString *contentHint = dict[@"content-hint"];
        if ( [contentHint isEqualTo:@"Apple_Boot"] ) {
            recoveryPartitionIdentifier = dict[@"dev-entry"];
        }
    }
    DDLogDebug(@"[DEBUG] Recovery partition BSD identifier: %@", recoveryPartitionIdentifier);
    return recoveryPartitionIdentifier;
}

+ (NSString *)getRecoveryPartitionIdentifierFromVolumeMountURL:(NSURL *)mountURL {
    DDLogDebug(@"[DEBUG] Getting recovery partition BSD identifier from volume mount path...");
    DDLogDebug(@"[DEBUG] Volume mount path: %@", [mountURL path]);
    
    NSString *recoveryPartitionIdentifier;
    NSTask *diskutilTask =  [[NSTask alloc] init];
    [diskutilTask setLaunchPath:@"/bin/bash"];
    NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/usr/sbin/diskutil info \"%@\" | /usr/bin/grep \"Recovery Disk:\" | /usr/bin/awk '{ print $NF }'", [mountURL path]]];
    [diskutilTask setArguments:args];
    [diskutilTask setStandardOutput:[NSPipe pipe]];
    [diskutilTask setStandardError:[NSPipe pipe]];
    [diskutilTask launch];
    [diskutilTask waitUntilExit];
    
    NSData *stdOutData = [[[diskutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[diskutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [diskutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] diskutil command successful!");
        NSString *partitionIdentifier = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        partitionIdentifier = [partitionIdentifier stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        if ( [partitionIdentifier length] != 0 && [partitionIdentifier containsString:@"/dev/"] ) {
            recoveryPartitionIdentifier = partitionIdentifier;
        } else if ( [partitionIdentifier length] != 0 ) {
            recoveryPartitionIdentifier = [NSString stringWithFormat:@"/dev/%@", partitionIdentifier];
        }
        DDLogDebug(@"[DEBUG] Recovery partition BSD identifier: %@", recoveryPartitionIdentifier);
    } else {
        DDLogError(@"[diskutil] %@", stdOut);
        DDLogError(@"[diskutil] %@", stdErr);
        DDLogError(@"[ERROR] diskutil command failed with exit status: %d", [diskutilTask terminationStatus]);
    }
    return recoveryPartitionIdentifier;
}

+ (NSDictionary *)getHdiutilInfoDict {
    DDLogDebug(@"[DEBUG] Getting information from hdiutil about all disk images currently attached...");

    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSArray *args = @[ @"info", @"-plist" ];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask setStandardError:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *stdOutData = [[[hdiutilTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
    
    NSData *stdErrData = [[[hdiutilTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
        DDLogDebug(@"[DEBUG] hdiutil command successful!");
        NSError *plistError = nil;
        NSPropertyListFormat format;
        NSDictionary *hdiutilDict = [NSPropertyListSerialization propertyListWithData:stdOutData options:NSPropertyListImmutable format:&format error:&plistError];
        if ( hdiutilDict == nil ) {
            DDLogError(@"[hdiutil] %@", stdOut);
            DDLogError(@"[hdiutil] %@", stdErr);
            DDLogError(@"[ERROR] hdiutil output could not be serialized as property list");
            DDLogError(@"[ERROR] %@", [plistError localizedDescription]);
            return nil;
        } else {
            return hdiutilDict;
        }
    } else {
        DDLogError(@"[hdiutil] %@", stdOut);
        DDLogError(@"[hdiutil] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
        return nil;
    }
}

+ (NSURL *)getDiskImageURLFromMountURL:(NSURL *)mountURL {
    DDLogDebug(@"[DEBUG] Getting disk image path from volume mount path...");
    DDLogDebug(@"[DEBUG] Disk image volume mount path: %@", [mountURL path]);
    
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
                }
            }
        }
    }
    
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    return diskImageURL;
}

+ (NBCDisk *)getBaseSystemDiskFromDiskImageURL:(NSURL *)diskImageURL {
    DDLogDebug(@"[DEBUG] Getting BaseSystem disk object from disk image path...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    
    NSError *error;
    NBCDisk *disk;
    NSDictionary *hdiutilDict = [self getHdiutilInfoDict];
    for ( NSDictionary *image in hdiutilDict[@"images"] ) {
        NSString *imagePath = image[@"image-path"];
        if ( [[diskImageURL path] isEqualToString:imagePath] ) {
            NSDictionary *systemEntities = image[@"system-entities"];
            for ( NSDictionary *entity in systemEntities ) {
                NSString *mountPoint = entity[@"mount-point"];
                if ( [mountPoint length] != 0 ) {
                    NSArray *rootItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:mountPoint]
                                                                       includingPropertiesForKeys:@[]
                                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                            error:&error];
                    __block BOOL isBaseSystem;
                    [rootItems enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
#pragma unused(idx)
                        NSString *itemName = [obj lastPathComponent];
                        if ( [itemName hasPrefix:@"Install OS X"] && [itemName hasSuffix:@".app"] ) {
                            isBaseSystem = YES;
                            *stop = YES;;
                        }
                    }];
                    if ( isBaseSystem ) {
                        disk = [NBCController diskFromVolumeURL:[NSURL fileURLWithPath:mountPoint]];
                    }
                }
            }
        }
    }
    
    return disk;
}

+ (NBCDisk *)getInstallESDDiskFromDiskImageURL:(NSURL *)diskImageURL {
    DDLogDebug(@"[DEBUG] Getting InstallESD/NetInstall disk object from disk image path...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    
    NBCDisk *disk;
    NSDictionary *hdiutilDict = [self getHdiutilInfoDict];
    for ( NSDictionary *image in hdiutilDict[@"images"] ) {
        NSString *imagePath = image[@"image-path"];
        if ( [[diskImageURL path] isEqualToString:imagePath] ) {
            NSDictionary *systemEntities = image[@"system-entities"];
            for ( NSDictionary *entity in systemEntities ) {
                NSString *mountPoint = entity[@"mount-point"];
                if ( [mountPoint length] != 0 ) {
                    NSURL *baseSystemURL = [[NSURL fileURLWithPath:mountPoint] URLByAppendingPathComponent:@"BaseSystem.dmg"];
                    if ( [baseSystemURL checkResourceIsReachableAndReturnError:nil] ) {
                        disk = [NBCController diskFromVolumeURL:[NSURL fileURLWithPath:mountPoint]];
                    }
                }
            }
        }
    }
    
    return disk;
}

+ (NBCDisk *)checkDiskImageAlreadyMounted:(NSURL *)diskImageURL imageType:(NSString *)imageType {
    DDLogDebug(@"[DEBUG] Checking if disk image is mounted...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    DDLogDebug(@"[DEBUG] Disk image type: %@", imageType);
    
    NBCDisk *disk;
    NSString *partitionHint;
    
    if ( [imageType isEqualToString:@"System"] ) {
        partitionHint = @"Apple_HFS";    // "Apple_HFS" - Mac OS Extended (HFS+)
    } else if ( [imageType isEqualToString:@"BaseSystem"] ) {
        return [self getBaseSystemDiskFromDiskImageURL:diskImageURL];
    } else if ( [imageType isEqualToString:@"InstallESD"] || [imageType isEqualToString:@"NetInstall"] ) {
        return [self getInstallESDDiskFromDiskImageURL:diskImageURL];;
    } else if ( [imageType isEqualToString:@"Recovery"] ) {
        partitionHint = @"426F6F74-0000-11AA-AA11-00306543ECAC"; // "" - OS X Recovery Partition
    }
    
    NSMutableArray *diskImageUUIDs = [[NSMutableArray alloc] init];
    NSTask *hdiutilTask =  [[NSTask alloc] init];
    [hdiutilTask setLaunchPath:@"/usr/bin/hdiutil"];
    NSArray *args = @[
                      @"imageinfo",
                      @"-plist",
                      [diskImageURL path]
                      ];
    [hdiutilTask setArguments:args];
    [hdiutilTask setStandardOutput:[NSPipe pipe]];
    [hdiutilTask launch];
    [hdiutilTask waitUntilExit];
    
    NSData *newTaskStandardOutputData = [[hdiutilTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSPropertyListFormat format;
    NSError *error;
    
    if ( [hdiutilTask terminationStatus] == 0 ) {
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
