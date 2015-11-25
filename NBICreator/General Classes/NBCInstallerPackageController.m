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
#import "NBCWorkflowItem.h"
#import "NBCHelperAuthorization.h"

DDLogLevel ddLogLevel;

@implementation NBCInstallerPackageController

- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)installPackagesToVolume:(NSURL *)volumeURL packages:(NSArray *)packages workflowItem:(NBCWorkflowItem *)workflowItem {
    if ( [packages count] != 0 ) {
        [self setWorkflowItem:workflowItem];
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
                [self installPackageOnTargetVolume:_volumeURL packageURL:packageURL choiceChangesXML:packageChoiceChangeXML];
            }
        }
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installPackageOnTargetVolume:(NSURL *)volumeURL packageURL:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML {
    
    DDLogInfo(@"Installing %@ on volume %@...", [packageURL lastPathComponent], [volumeURL path]);
    
    NSError *err = nil;
    
    DDLogDebug(@"[DEBUG] Verifying package path...");
    if ( ! [packageURL checkResourceIsReachableAndReturnError:&err] ) {
        [self->_delegate installFailedWithError:err];
        return;
    }
    
    DDLogDebug(@"[DEBUG] Verifying volume path...");
    if ( ! [volumeURL checkResourceIsReachableAndReturnError:&err] ) {
        [self->_delegate installFailedWithError:err];
        return;
    }
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [_workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper];
        [_workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NSXPCConnection *helperConnection = [self->_workflowItem helperConnection];
        if ( ! helperConnection ) {
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [self->_workflowItem setHelperConnection:[helperConnector connection]];
        }
        [[self->_workflowItem helperConnection] setExportedObject:self->_progressDelegate];
        [[self->_workflowItem helperConnection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[self->_workflowItem helperConnection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [self->_delegate installFailedWithError:proxyError];
        }] installPackage:[packageURL path] targetVolumePath:[volumeURL path] choices:choiceChangesXML authorization:authData withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
            if ( terminationStatus == 0 ) {
                [self installSuccessfulForPackage:packageURL];
            } else {
                [self->_delegate installFailedWithError:error];
            }
        }];
    });
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
