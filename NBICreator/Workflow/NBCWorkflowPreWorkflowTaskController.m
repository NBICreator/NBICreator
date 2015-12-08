//
//  NBCWorkflowPreWorkflowTasks.m
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

#import "NBCWorkflowPreWorkflowTaskController.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCError.h"
#import "NBCWorkflowItem.h"

@implementation NBCWorkflowPreWorkflowTaskController

- (id)initWithDelegate:(id<NBCWorkflowPreWorkflowTaskControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)runPreWorkflowTasks:(NSDictionary *)preWorkflowTasks workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Starting Pre-Workflow tasks...");
    [_progressDelegate updateProgressStatus:@"Starting Pre-Workflow tasks..." workflow:self];
    
    if ( [preWorkflowTasks[@"ClearCache"] boolValue] ) {
        NSString *selectedSource = preWorkflowTasks[@"ClearCacheSource"];
        if ( [selectedSource isEqualToString:@"Current Source"] ) {
            NSString *sourceBuild = [[workflowItem source] sourceBuild];
            if ( [sourceBuild length] != 0 ) {
                [self cleanCacheFolderForSourceBuild:sourceBuild];
            } else {
                [_delegate preWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"Source build version was empty"]];
            }
        } else if ( [selectedSource isEqualToString:@"All Sources"] ) {
            [self cleanCacheFolderForSourceBuild:@"All Sources"];
        }
    } else {
        [_delegate preWorkflowTasksCompleted];
    }
}

- (NSURL *)cacheFolderURL {
    return [NBCWorkflowResourcesController urlForResourceFolder:NBCFolderResourcesCache];
}

- (void)cleanCacheFolderForSourceBuild:(NSString *)sourceBuild {
    
    DDLogInfo(@"Cleaning cache folder for source: %@", sourceBuild);
    [_progressDelegate updateProgressStatus:@"Cleaning cache folder..." workflow:self];
    
    NSError *err;
    NSURL *cacheFolderURL;
    NSURL *sourceFolderURL;
    if ( [sourceBuild isEqualToString:@"All Sources"] ) {
        cacheFolderURL = [self cacheFolderURL];
        if ( [cacheFolderURL checkResourceIsReachableAndReturnError:&err] ) {
            sourceFolderURL = [cacheFolderURL URLByAppendingPathComponent:@"Source"];
            DDLogDebug(@"[DEBUG] Source cache folder path: %@", [sourceFolderURL path]);
        } else {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
            [_delegate preWorkflowTasksCompleted];
            return;
        }
        
        if ( ! [sourceFolderURL checkResourceIsReachableAndReturnError:&err] ) {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
            [_delegate preWorkflowTasksCompleted];
            return;
        }
    } else {
        cacheFolderURL = [self cacheFolderURL];
        if ( [cacheFolderURL checkResourceIsReachableAndReturnError:&err] ) {
            sourceFolderURL = [cacheFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Source/%@", sourceBuild]];
            DDLogDebug(@"[DEBUG] Source cache folder path: %@", [sourceFolderURL path]);
        } else {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
            [_delegate preWorkflowTasksCompleted];
            return;
        }
        
        NSURL *sourcesDictURL = [cacheFolderURL URLByAppendingPathComponent:@"Source/Resources.plist"];
        DDLogDebug(@"[DEBUG] Source cache dict path: %@", [sourcesDictURL path]);
        
        if ( [sourcesDictURL checkResourceIsReachableAndReturnError:&err] ) {
            NSMutableDictionary *sourcesDict = [[NSDictionary dictionaryWithContentsOfURL:sourcesDictURL] mutableCopy];
            if ( [sourcesDict objectForKey:sourceBuild] ) {
                [sourcesDict removeObjectForKey:sourceBuild];
                if ( ! [sourcesDict objectForKey:sourceBuild] ) {
                    if ( [sourcesDict writeToURL:sourcesDictURL atomically:YES] ) {
                        DDLogInfo(@"Source cache dict updated!");
                    } else {
                        DDLogError(@"[ERROR] Could not write source cache dict to disk!");
                        return;
                    }
                } else {
                    DDLogError(@"[ERROR] Could not remove key: %@!", sourceBuild);
                    return;
                }
            } else {
                DDLogWarn(@"[WARN] Source cache dict has no entry for %@!", sourceBuild);
            }
        } else {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
        }
        
        if ( ! [sourceFolderURL checkResourceIsReachableAndReturnError:&err] ) {
            DDLogWarn(@"[WARN] %@", [err localizedDescription]);
            [_delegate preWorkflowTasksCompleted];
            return;
        }
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:self->_progressDelegate];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [self->_delegate preWorkflowTasksFailedWithError:proxyError];
        }] removeItemsAtPaths:@[ [sourceFolderURL path] ] withReply:^(NSError *error, BOOL success) {
            if ( success ) {
                [self->_delegate preWorkflowTasksCompleted];
            } else {
                [self->_delegate preWorkflowTasksFailedWithError:error];
            }
        }];
    });
}

@end
