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
#import "NBCConstants.h"
#import "NBCController.h"
#import "NBCLogging.h"
#import "NBCError.h"
#import "NBCSource.h"
#import "NBCDiskController.h"

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
            DDLogWarn(@"[hdiutil][stdout] %@", stdOut);
            DDLogWarn(@"[hdiutil][stderr] %@", stdErr);
            DDLogError(@"[ERROR] hdiutil output could not be serialized as property list");
            *error = plistError;
            return NO;
        }
    } else {
        DDLogWarn(@"[hdiutil][stdout] %@", stdOut);
        DDLogWarn(@"[hdiutil][stderr] %@", stdErr);
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
        DDLogWarn(@"[hdiutil][stdout] %@", stdOut);
        DDLogWarn(@"[hdiutil][stderr] %@", stdErr);
        DDLogWarn(@"[WARN] Detach failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for ( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            DDLogWarn(@"[WARN] Detach with force try %d of 3", maxTries);
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask setStandardOutput:[NSPipe pipe]];
            [forceTask setStandardError:[NSPipe pipe]];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            stdOutData = [[[forceTask standardOutput] fileHandleForReading] readDataToEndOfFile];
            stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            
            stdErrData = [[[forceTask standardError] fileHandleForReading] readDataToEndOfFile];
            stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Detach successful on try %d!", maxTries);
                return YES;
            }
        }
        
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
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
        DDLogWarn(@"[hdiutil][stdout] %@", stdOut);
        DDLogWarn(@"[hdiutil][stderr] %@", stdErr);
        DDLogWarn(@"[WARN] Detach failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            DDLogWarn(@"[WARN] Detach with force try %d of 3", maxTries);
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask setStandardOutput:[NSPipe pipe]];
            [forceTask setStandardError:[NSPipe pipe]];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            stdOutData = [[[forceTask standardOutput] fileHandleForReading] readDataToEndOfFile];
            stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            
            stdErrData = [[[forceTask standardError] fileHandleForReading] readDataToEndOfFile];
            stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Detach successful on try %d!", maxTries);
                return retval;
            }
        }
        
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
        DDLogError(@"[DEBUG] Detach failed!");
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
        DDLogWarn(@"[hdiutil][stdout] %@", stdOut);
        DDLogWarn(@"[hdiutil][stderr] %@", stdErr);
        DDLogWarn(@"[WARN] Unmount failed, trying with force...");
        [args addObject:@"-force"];
        
        int maxTries;
        for ( maxTries = 1; maxTries < 5; maxTries = maxTries + 1 ) {
            DDLogWarn(@"[WARN] Detach with force try %d of 3", maxTries);
            NSTask *forceTask =  [[NSTask alloc] init];
            [forceTask setLaunchPath:@"/usr/bin/hdiutil"];
            [forceTask setArguments:args];
            [forceTask setStandardOutput:[NSPipe pipe]];
            [forceTask setStandardError:[NSPipe pipe]];
            [forceTask launch];
            [forceTask waitUntilExit];
            
            stdOutData = [[[forceTask standardOutput] fileHandleForReading] readDataToEndOfFile];
            stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            
            stdErrData = [[[forceTask standardError] fileHandleForReading] readDataToEndOfFile];
            stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
            
            if ( [forceTask terminationStatus] == 0 ) {
                DDLogInfo(@"Unmount successful on try %d!", maxTries);
                return retval;
            }
        }
        
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
        DDLogError(@"[DEBUG] Detach failed!");
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
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
        DDLogError(@"[ERROR] hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]);
        return NO;
    }
}

+ (BOOL)convertDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath format:(NSString *)format destinationPath:(NSString *)destinationPath {
    DDLogDebug(@"[DEBUG] Converting disk image at path: %@", diskImagePath);
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
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
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
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
        *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"hdiutil command failed with exit status: %d", [hdiutilTask terminationStatus]]];
        return NO;
    }
} // resizeDiskImageAtURL

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
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
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
            DDLogError(@"[hdiutil][stdout] %@", stdOut);
            DDLogError(@"[hdiutil][stderr] %@", stdErr);
            DDLogError(@"[ERROR] hdiutil output could not be serialized as property list");
            DDLogError(@"[ERROR] %@", [plistError localizedDescription]);
            return nil;
        } else {
            return hdiutilDict;
        }
    } else {
        DDLogError(@"[hdiutil][stdout] %@", stdOut);
        DDLogError(@"[hdiutil][stderr] %@", stdErr);
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

/* Wrong approach to do the testing, here, just return disk object and then check for correct info in respective method.
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
 */
+ (NBCDisk *)getDiskFromDiskImageURL:(NSURL *)diskImageURL {
    DDLogDebug(@"[DEBUG] Getting disk object from disk image path...");
    DDLogDebug(@"[DEBUG] Disk image path: %@", [diskImageURL path]);
    
    NSString *diskImagPathResolved = [[diskImageURL path] stringByResolvingSymlink];
    DDLogDebug(@"[DEBUG] Disk image path (resolved): %@", diskImagPathResolved);
    
    NBCDisk *disk;
    NSDictionary *hdiutilDict = [self getHdiutilInfoDict];
    for ( NSDictionary *image in hdiutilDict[@"images"] ) {
        NSString *imagePath = image[@"image-path"];
        DDLogDebug(@"[DEBUG] Checking disk image at path: %@", imagePath);
        
        if ( [[diskImageURL path] isEqualToString:imagePath] || [diskImagPathResolved isEqualToString:imagePath] ) {
            NSDictionary *systemEntities = image[@"system-entities"];
            for ( NSDictionary *entity in systemEntities ) {
                NSString *mountPoint = entity[@"mount-point"];
                if ( [mountPoint length] != 0 ) {
                    
                    DDLogDebug(@"[DEBUG] Disk image volume path: %@", mountPoint);
                    disk = [NBCDiskController diskFromVolumeURL:[NSURL fileURLWithPath:mountPoint]];
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
    } else if ( [imageType isEqualToString:@"BaseSystem"] || [imageType isEqualToString:@"InstallESD"] || [imageType isEqualToString:@"NetInstall"] ) {
        return [self getDiskFromDiskImageURL:diskImageURL];;
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
    
    NSArray *mountedDisksUUIDs = [NBCDiskController mountedDiskUUUIDs];
    
    for ( NSString *uuid in diskImageUUIDs ) {
        for ( NSDictionary *dict in mountedDisksUUIDs ) {
            if ( [uuid isEqualToString:dict[@"uuid"]] ) {
                return dict[@"disk"];
            }
        }
    }
    
    if ( ( [imageType isEqualToString:@"System"] || [imageType isEqualToString:@"NetInstall"] ) && disk == nil ) {
        disk = [self getDiskFromDiskImageURL:diskImageURL];
    }
    
    return disk;
}

+ (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target error:(NSError **)error {
    
    DDLogInfo(@"Resize BaseSystem disk image and mount with shadow file...");
    
    // ---------------------------------------------------
    //  Generate a random path for BaseSystem shadow file
    // ---------------------------------------------------
    NSString *shadowFilePath = [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    DDLogDebug(@"[DEBUG] BaseSystem disk image shadow file path: %@", shadowFilePath);
    [target setBaseSystemShadowPath:shadowFilePath];
    
    if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
        
        // ----------------------------------------
        //  Resize BaseSystem to fit extra content
        // ----------------------------------------
        //[_delegate updateProgressStatus:@"Resizing disk image using shadow file..." workflow:self];
        if ( [NBCDiskImageController resizeDiskImageAtURL:baseSystemURL shadowImagePath:shadowFilePath error:error] ) {
            
            // -------------------------------------------------------
            //  Attach BaseSystem and add volume url to target object
            // -------------------------------------------------------
            return [self attachBaseSystemDiskImageWithShadowFile:baseSystemURL target:target error:error];
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // resizeAndMountBaseSystemWithShadow:target:error

+ (BOOL)attachNetInstallDiskImageWithShadowFile:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    
    DDLogInfo(@"Attaching NetInstall disk image with shadow file...");
    
    NSString *shadowPath = [target nbiNetInstallShadowPath] ?: [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    
    if ( [self attachDiskImageAtURL:netInstallDiskImageURL shadowPath:shadowPath error:error] ) {
        NBCDisk *netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:netInstallDiskImageURL
                                                                             imageType:@"NetInstall"];
        
        if ( ! netInstallDisk ) {
            *error = [NBCError errorWithDescription:@"Disk image volume path not found among mounted volume paths"];
            return NO;
        }
        
        [netInstallDisk setIsMountedByNBICreator:YES];
        [target setNbiNetInstallDisk:netInstallDisk];
        [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
        [target setNbiNetInstallURL:netInstallDiskImageURL];
        [target setNbiNetInstallVolumeURL:[netInstallDisk volumeURL]];
        [target setNbiNetInstallShadowPath:shadowPath];
        
        NSURL *baseSystemURL = [[netInstallDisk volumeURL] URLByAppendingPathComponent:@"BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] NetInstall BaseSystem disk image path: %@", [baseSystemURL path]);
        
        if ( [baseSystemURL checkResourceIsReachableAndReturnError:error] ) {
            [target setBaseSystemURL:baseSystemURL];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

+ (BOOL)attachBaseSystemDiskImageWithShadowFile:(NSURL *)baseSystemDiskImageURL target:(NBCTarget *)target error:(NSError **)error {
    
    DDLogInfo(@"Attaching BaseSystem disk image with shadow file...");
    
    NSString *shadowPath = [target baseSystemShadowPath] ?: [NSString stringWithFormat:@"/tmp/dmg.%@.shadow", [NSString nbc_randomString]];
    
    if ( [self attachDiskImageAtURL:baseSystemDiskImageURL shadowPath:shadowPath error:error] ) {
        NBCDisk *baseSystemDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:baseSystemDiskImageURL
                                                                             imageType:@"BaseSystem"];
        
        if ( ! baseSystemDisk ) {
            *error = [NBCError errorWithDescription:@"Disk image volume path not found among mounted volume paths"];
            return NO;
        }
        
        [baseSystemDisk setIsMountedByNBICreator:YES];
        [target setBaseSystemDisk:baseSystemDisk];
        [target setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
        [target setBaseSystemURL:baseSystemDiskImageURL];
        [target setBaseSystemVolumeURL:[baseSystemDisk volumeURL]];
        [target setBaseSystemShadowPath:shadowPath];
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)attachDiskImageAtURL:(NSURL *)diskImageURL shadowPath:(NSString *)shadowPath error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Attaching disk image with shadow file...");
    
    NSURL *volumeURL;
    NSDictionary *diskImageDict;
    
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-shadow", shadowPath,
                                @"-owners", @"on",
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    
    if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&diskImageDict
                                                              dmgPath:diskImageURL
                                                              options:hdiutilOptions
                                                                error:error] ) {
        if ( [diskImageDict count] != 0 ) {
            volumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:diskImageDict];
            
            return [volumeURL checkResourceIsReachableAndReturnError:error];
        } else {
            *error = [NBCError errorWithDescription:@"Disk image hdiutil info was empty"];
            return NO;
        }
    } else {
        return NO;
    }
} // attachBaseSystemDiskImageWithShadowFile

+ (BOOL)verifyBaseSystemDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source error:(NSError **)error {
#pragma unused(diskImageURL, source, error)
    
    DDLogInfo(@"Verifying disk image is a BaseSystem.dmg...");
    
    NSURL *baseSystemVolumeURL;
    NBCDisk *baseSystemDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                       imageType:@"BaseSystem"];
    
    if ( baseSystemDisk ) {
        [source setBaseSystemDisk:baseSystemDisk];
        [source setBaseSystemDiskImageURL:diskImageURL];
        [source setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
        baseSystemVolumeURL = [baseSystemDisk volumeURL];
        DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
    } else {
        
        NSDictionary *baseSystemDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        
        if ( [self attachDiskImageAndReturnPropertyList:&baseSystemDiskImageDict
                                                dmgPath:diskImageURL
                                                options:hdiutilOptions
                                                  error:error] ) {
            if ( [baseSystemDiskImageDict count] != 0 ) {
                [source setBaseSystemDiskImageDict:baseSystemDiskImageDict];
                baseSystemVolumeURL = [self getMountURLFromHdiutilOutputPropertyList:baseSystemDiskImageDict];
                DDLogDebug(@"[DEBUG] BaseSystem disk image volume path: %@", [baseSystemVolumeURL path]);
                
                if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    baseSystemDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                              imageType:@"BaseSystem"];
                    
                    if ( baseSystemDisk ) {
                        [source setBaseSystemDisk:baseSystemDisk];
                        [source setBaseSystemVolumeBSDIdentifier:[baseSystemDisk BSDName]];
                        [baseSystemDisk setIsMountedByNBICreator:YES];
                    } else {
                        *error = [NBCError errorWithDescription:@"BaseSystem disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"BaseSystem disk image hdiutil info was empty"];
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] BaseSystem disk image volume is mounted at path: %@", [baseSystemVolumeURL path]);
        [source setBaseSystemVolumeURL:baseSystemVolumeURL];
        
        NSURL *baseSystemVersionPlistURL = [baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] BaseSystem disk image volume SystemVersion.plist path: %@", [baseSystemVersionPlistURL path]);
        
        if ( [baseSystemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *baseSystemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:baseSystemVersionPlistURL];
            
            if ( [baseSystemVersionPlist count] != 0 ) {
                NSString *baseSystemOSVersion = baseSystemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"BaseSystem os version: %@", baseSystemOSVersion);
                
                if ( [baseSystemOSVersion length] != 0 ) {
                    [source setBaseSystemOSVersion:baseSystemOSVersion];
                    [source setSourceVersion:baseSystemOSVersion];
                    
                    NSString *baseSystemOSBuild = baseSystemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"BaseSystem os build: %@", baseSystemOSBuild);
                    
                    if ( [baseSystemOSBuild length] != 0 ) {
                        [source setBaseSystemOSBuild:baseSystemOSBuild];
                        [source setSourceBuild:baseSystemOSBuild];
                        
                    } else {
                        *error = [NBCError errorWithDescription:@"Unable to read os build from SystemVersion.plist"];
                        return NO;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"Unable to read os version from SystemVersion.plist"];
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"BaseSystem disk image volume SystemVersion.plist is empty!"];
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }
    
    return YES;
}

+ (BOOL)verifyInstallESDDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying disk image contains an OS X Installer...");
    
    NSURL *installESDVolumeURL;
    NBCDisk *installESDDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                       imageType:@"InstallESD"];
    
    if ( installESDDisk ) {
        [source setInstallESDDisk:installESDDisk];
        [source setInstallESDDiskImageURL:diskImageURL];
        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
        installESDVolumeURL = [installESDDisk volumeURL];
        DDLogDebug(@"[DEBUG] InstallESD disk image volume path: %@", [installESDVolumeURL path]);
    } else {
        
        NSDictionary *installESDDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        
        if ( [self attachDiskImageAndReturnPropertyList:&installESDDiskImageDict
                                                dmgPath:diskImageURL
                                                options:hdiutilOptions
                                                  error:error] ) {
            
            if ( [installESDDiskImageDict count] != 0 ) {
                [source setInstallESDDiskImageDict:installESDDiskImageDict];
                installESDVolumeURL = [self getMountURLFromHdiutilOutputPropertyList:installESDDiskImageDict];
                DDLogDebug(@"[DEBUG] InstallESD disk image volume path: %@", [installESDVolumeURL path]);
                
                if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    installESDDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                              imageType:@"InstallESD"];
                    
                    if ( installESDDisk ) {
                        [source setInstallESDDisk:installESDDisk];
                        [source setInstallESDDiskImageURL:diskImageURL];
                        [source setInstallESDVolumeBSDIdentifier:[installESDDisk BSDName]];
                        [installESDDisk setIsMountedByNBICreator:YES];
                        
                    } else {
                        *error = [NBCError errorWithDescription:@"InstallESD disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"InstallESD disk image hdiutil info was empty"];
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
            return [self verifyBaseSystemDiskImage:baseSystemDiskImageURL source:source error:error];
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

+ (NSURL *)installESDURLfromInstallerApplicationURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Getting InstallESD from %@", [sourceURL path]);
    
    if ( ! [sourceURL checkResourceIsReachableAndReturnError:error] ) {
        return nil;
    }
    
    [source setOsxInstallerURL:sourceURL];
    NSBundle *osxInstallerBundle = [NSBundle bundleWithURL:sourceURL];
    if ( osxInstallerBundle ) {
        NSURL *osxInstallerIconURL = [osxInstallerBundle URLForResource:@"InstallAssistant" withExtension:@"icns"];
        if ( [osxInstallerIconURL checkResourceIsReachableAndReturnError:error] ) {
            [source setOsxInstallerIconURL:osxInstallerIconURL];
            return [[osxInstallerBundle bundleURL] URLByAppendingPathComponent:@"Contents/SharedSupport/InstallESD.dmg"];
        } else {
            return nil;
        }
    } else {
        return nil;
    }
} // installESDURLfromInstallerApplicationURL

+ (BOOL)verifySystemDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source requireRecoveryPartition:(BOOL)requireRecoveryPartition error:(NSError **)error {
    
    DDLogInfo(@"Verifying disk image contains an OS X System...");
    
    NSURL *systemVolumeURL;
    NBCDisk *systemDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                   imageType:@"BaseSystem"];
    if ( systemDisk ) {
        [source setSystemDisk:systemDisk];
        [source setSystemDiskImageURL:diskImageURL];
        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
        systemVolumeURL = [systemDisk volumeURL];
        DDLogDebug(@"[DEBUG] System disk image volume path: %@", [systemVolumeURL path]);
        
    } else {
        
        NSDictionary *systemDiskImageDict;
        NSArray *hdiutilOptions = @[
                                    @"-mountRandom", @"/Volumes",
                                    @"-nobrowse",
                                    @"-noverify",
                                    @"-plist",
                                    ];
        
        if ( [self attachDiskImageAndReturnPropertyList:&systemDiskImageDict
                                                dmgPath:diskImageURL
                                                options:hdiutilOptions
                                                  error:error] ) {
            
            if ( [systemDiskImageDict count] != 0 ) {
                [source setSystemDiskImageDict:systemDiskImageDict];
                systemVolumeURL = [self getMountURLFromHdiutilOutputPropertyList:systemDiskImageDict];
                DDLogDebug(@"[DEBUG] System disk image volume path: %@", [systemVolumeURL path]);
                
                if ( [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
                    systemDisk = [self checkDiskImageAlreadyMounted:diskImageURL
                                                          imageType:@"BaseSystem"];
                    
                    if ( systemDisk ) {
                        [source setSystemDisk:systemDisk];
                        [source setSystemDiskImageURL:diskImageURL];
                        [source setSystemVolumeBSDIdentifier:[systemDisk BSDName]];
                        [systemDisk setIsMountedByNBICreator:YES];
                        
                    } else {
                        *error = [NBCError errorWithDescription:@"System disk image volume path not found among mounted volume paths"];
                        return NO;
                    }
                } else {
                    return NO;
                }
            } else {
                *error = [NBCError errorWithDescription:@"System disk image hdiutil info was empty"];
                return NO;
            }
        } else {
            return NO;
        }
    }
    
    if ( [systemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] System disk image volume is mounted at path: %@", [systemVolumeURL path]);
        [source setSystemVolumeURL:systemVolumeURL];
        
        NSURL *systemVersionPlistURL = [systemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        DDLogDebug(@"[DEBUG] System disk image volume SystemVersion.plist path: %@", [systemVersionPlistURL path]);
        
        if ( [systemVersionPlistURL checkResourceIsReachableAndReturnError:error] ) {
            NSDictionary *systemVersionPlist = [NSDictionary dictionaryWithContentsOfURL:systemVersionPlistURL];
            
            if ( [systemVersionPlist count] != 0 ) {
                NSString *systemOSVersion = systemVersionPlist[@"ProductUserVisibleVersion"];
                DDLogInfo(@"System os version: %@", systemOSVersion);
                
                if ( [systemOSVersion length] != 0 ) {
                    [source setSystemOSVersion:systemOSVersion];
                    [source setSourceVersion:systemOSVersion];
                    
                    NSString *systemOSBuild = systemVersionPlist[@"ProductBuildVersion"];
                    DDLogInfo(@"System os build: %@", systemOSBuild);
                    
                    if ( [systemOSBuild length] != 0 ) {
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
                *error = [NBCError errorWithDescription:@"System disk image volume SystemVersion.plist is empty!"];
                return NO;
            }
        } else {
            return NO;
        }
    } else {
        return NO;
    }

    if ( requireRecoveryPartition && ! [[source systemOSVersion] hasPrefix:@"10.6"] ) {
        return [self verifyRecoveryPartitionFromSystemVolumeURL:systemVolumeURL source:source error:error];
    } else {
        return YES;
    }
}

+ (BOOL)verifyRecoveryPartitionFromSystemVolumeURL:(NSURL *)systemVolumeURL source:(NBCSource *)source error:(NSError **)error {
    
    DDLogInfo(@"Verifying disk has a recovery partition...");
    
    NSURL *recoveryVolumeURL;
    NSString *recoveryPartitionDiskIdentifier = [NBCDiskController getRecoveryPartitionIdentifierFromVolumeURL:systemVolumeURL];
    DDLogDebug(@"[DEBUG] Recovery partition BSD identifier: %@", recoveryPartitionDiskIdentifier);
    
    if ( [recoveryPartitionDiskIdentifier length] != 0 ) {
        NBCDisk *recoveryDisk = [NBCDiskController diskFromBSDName:recoveryPartitionDiskIdentifier];
        if ( [recoveryDisk isMounted] ) {
            [source setRecoveryDisk:recoveryDisk];
            [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
            recoveryVolumeURL = [recoveryDisk volumeURL];
            DDLogDebug(@"[DEBUG] Recovery partition volume path: %@", [systemVolumeURL path]);
            
        } else {
            recoveryVolumeURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/Volumes/dmg.%@", [NSString nbc_randomString]]];
            
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
                [source setRecoveryVolumeBSDIdentifier:recoveryPartitionDiskIdentifier];
                [recoveryDisk setIsMountedByNBICreator:YES];
                
                usleep(2000000); // Wait for disk to mount, need to fix by watching for disk mounts!
            } else {
                *error = [NBCError errorWithDescription:@"Mounting recovery partition failed"];
                return NO;
            }
        }
    } else {
        *error = [NBCError errorWithDescription:@"Recovery partition BSD identifier was empty"];
        return NO;
    }
    
    if ( [recoveryVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] Recovery partition is mounted at path: %@", [recoveryVolumeURL path]);
        [source setRecoveryVolumeURL:recoveryVolumeURL];
        
        NSURL *baseSystemDiskImageURL = [recoveryVolumeURL URLByAppendingPathComponent:@"com.apple.recovery.boot/BaseSystem.dmg"];
        DDLogDebug(@"[DEBUG] Recovery partition BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
        
        if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:error] ) {
            [source setBaseSystemDiskImageURL:baseSystemDiskImageURL];
            return [self verifyBaseSystemDiskImage:baseSystemDiskImageURL source:source error:error];
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

@end

