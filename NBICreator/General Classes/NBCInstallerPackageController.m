//
//  NBCInstallerPackageController.m
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

#import "NBCInstallerPackageController.h"
#import "NBCConstants.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"
#import "NBCError.h"
#import "NBCWorkflowResourcesController.h"

DDLogLevel ddLogLevel;

@implementation NBCInstallerPackageController

- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)installPackagesToVolume:(NSURL *)volumeURL packages:(NSArray *)packages {
    if ( [packages count] != 0 ) {
        [self setVolumeURL:volumeURL];
        [self setPackagesQueue:[[NSMutableArray alloc] initWithArray:packages]];
        [self runPackageQueue];
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installSuccessfulForPackage:(NSURL *)packageURL {
    DDLogInfo(@"%@ installed successfully!", [packageURL lastPathComponent]);
    [_packagesQueue removeObjectAtIndex:0];
    [self runPackageQueue];
}

- (void)runPackageQueue {
    if ( [_packagesQueue count] != 0 ) {
        NSDictionary *packageDict = [_packagesQueue firstObject];
        if ( [packageDict count] != 0 ) {
            NSString *packageSourcePath = packageDict[NBCWorkflowInstallerSourceURL];
            if ( [packageSourcePath length] != 0 ) {
                NSURL *packageURL = [NSURL fileURLWithPath:packageSourcePath];
                NSDictionary *packageChoiceChangeXML = packageDict[NBCWorkflowInstallerChoiceChangeXML];
                //[_delegate updateProgressStatus:[NSString stringWithFormat:@"Installing %@ to BaseSystem.dmg...", packageName] workflow:self];
                [self installPackageOnTargetVolume:_volumeURL packageURL:packageURL choiceChangesXML:packageChoiceChangeXML];
            }
        }
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installPackageOnTargetVolume:(NSURL *)volumeURL packageURL:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML {
    
    NSError *err = nil;
    
    DDLogInfo(@"Installing %@ on volume %@...", [packageURL lastPathComponent], [volumeURL path]);
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/installer"];
    NSMutableArray *installerArguments = [[NSMutableArray alloc] initWithObjects:
                                          @"-verboseR",
                                          @"-allowUntrusted",
                                          @"-plist",
                                          nil];
    
    if ( choiceChangesXML ) {
        [installerArguments addObject:@"-applyChoiceChangesXML"];
        [installerArguments addObject:choiceChangesXML];
    }
    
    if ( [packageURL checkResourceIsReachableAndReturnError:&err] ) {
        [installerArguments addObject:@"-package"];
        [installerArguments addObject:[packageURL path]];
    } else {
        if ( [self->_delegate respondsToSelector:@selector(installFailedWithError:)] ) {
            [self->_delegate installFailedWithError:err];
        }
        return;
    }
    
    if ( [volumeURL checkResourceIsReachableAndReturnError:&err] ) {
        [installerArguments addObject:@"-target"];
        [installerArguments addObject:[volumeURL path]];
    } else {
        if ( [self->_delegate respondsToSelector:@selector(installFailedWithError:)] ) {
            [self->_delegate installFailedWithError:err];
        }
        return;
    }
    
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
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        DDLogDebug(@"[installer][stdout] %@", outStr);
                                        
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
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        DDLogError(@"[installer][stderr] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [nc removeObserver:stdOutObserver];
        [nc removeObserver:stdErrObserver];
        [self->_delegate installFailedWithError:proxyError];
        
    }] runTaskWithCommandAtPath:commandURL arguments:installerArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        if ( terminationStatus == 0 ) {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self installSuccessfulForPackage:packageURL];
        } else {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self->_delegate installFailedWithError:error];
        }
    }];
}

+ (NSArray *)convertPackagesToProductArchivePackages:(NSArray *)packages {
    
    DDLogInfo(@"Converting %lu component package(s) to product archive...", (unsigned long)[packages count]);
    
    NSError *error = nil;
    NSMutableArray *convertedPkgURLArray = [[NSMutableArray alloc] init];
    
    // -----------------------------------------------------------------------------------
    //  Verify package cache folder exist.
    // -----------------------------------------------------------------------------------
    NSURL *cacheFolderPackagesURL = [NBCWorkflowResourcesController urlForResourceFolder:NBCFolderResourcesCachePackages];
    DDLogDebug(@"[DEBUG] Cache folder packages path: %@", cacheFolderPackagesURL);
    
    if ( ! [cacheFolderPackagesURL checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [[NSFileManager defaultManager] createDirectoryAtURL:cacheFolderPackagesURL withIntermediateDirectories:YES attributes:@{} error:&error] ) {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
            return nil;
        }
    }
    
    // ------------------------------------------------------------------------------------------
    //  Convert every package in array 'packages' to product archive using /usr/bin/productbuild.
    // ------------------------------------------------------------------------------------------
    for ( NSDictionary *pkgDict in packages ) {
        NSURL *pkgURL = [NSURL fileURLWithPath:pkgDict[NBCDictionaryKeyPath]];
        DDLogInfo(@"Component package path: %@", [pkgURL path]);
        
        if ( [pkgURL checkResourceIsReachableAndReturnError:&error] ) {
            
            NSURL *pkgTemporaryFolder = [cacheFolderPackagesURL URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
            DDLogDebug(@"[DEBUG] Product archive package folder path: %@", [pkgTemporaryFolder path]);
            
            if ( ! [[NSFileManager defaultManager] createDirectoryAtURL:pkgTemporaryFolder withIntermediateDirectories:YES attributes:@{} error:&error] ) {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
                continue;
            }
            
            NSURL *pkgTargetURL = [pkgTemporaryFolder URLByAppendingPathComponent:[pkgURL lastPathComponent]];
            DDLogDebug(@"[DEBUG] Product archive package path: %@", [pkgTargetURL path]);
            
            if ( ! [pkgTargetURL checkResourceIsReachableAndReturnError:nil] ) {
                NSTask *productbuildTask =  [[NSTask alloc] init];
                [productbuildTask setLaunchPath:@"/usr/bin/productbuild"];
                NSArray *args = @[
                                  @"--package", [pkgURL path],
                                  [pkgTargetURL path]
                                  ];
                
                [productbuildTask setArguments:args];
                [productbuildTask setStandardOutput:[NSPipe pipe]];
                [productbuildTask setStandardError:[NSPipe pipe]];
                [productbuildTask launch];
                [productbuildTask waitUntilExit];
                
                NSData *stdOutData = [[[productbuildTask standardOutput] fileHandleForReading] readDataToEndOfFile];
                NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
                
                NSData *stdErrData = [[[productbuildTask standardError] fileHandleForReading] readDataToEndOfFile];
                NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
                
                if ( [productbuildTask terminationStatus] == 0 ) {
                    DDLogDebug(@"[DEBUG] productbuild command successful!");
                    [convertedPkgURLArray addObject:pkgTargetURL];
                } else {
                    DDLogError(@"[productbuild][stdout] %@", stdOut);
                    DDLogError(@"[productbuild][stderr] %@", stdErr);
                    DDLogError(@"productbuild command failed with exit status: %d", [productbuildTask terminationStatus]);
                }
            } else {
                DDLogError(@"[ERROR] Package already exist at path!");
            }
        } else {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
    
    return [convertedPkgURLArray copy];
}

@end
