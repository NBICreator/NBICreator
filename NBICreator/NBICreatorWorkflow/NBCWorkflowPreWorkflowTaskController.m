//
//  NBCWorkflowPreWorkflowTasks.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-21.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowPreWorkflowTaskController.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

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
    if ( [preWorkflowTasks[@"ClearCache"] boolValue] ) {
        NSString *selectedSource = preWorkflowTasks[@"ClearCacheSource"];
        if ( [selectedSource isEqualToString:@"Current Source"] ) {
            NSString *sourceBuild = [[workflowItem source] sourceBuild];
            if ( [sourceBuild length] != 0 ) {
                [self cleanCacheFolderForSourceBuild:sourceBuild];
            } else {
                DDLogError(@"[ERROR]Source build version was empty!");
            }
        } else if ( [selectedSource isEqualToString:@"All Sources"] ) {
            [self cleanCacheFolderForSourceBuild:@"All Sources"];
        }
    } else {
        if (_delegate && [_delegate respondsToSelector:@selector(preWorkflowTasksCompleted)]) {
            [_delegate preWorkflowTasksCompleted];
        }
    }
}

- (NSURL *)cacheFolderURL {
    NBCWorkflowResourcesController *resourcesController = [[NBCWorkflowResourcesController alloc] init];
    return [resourcesController urlForResourceFolder:NBCFolderResourcesCache];
}

- (void)cleanCacheFolderForSourceBuild:(NSString *)sourceBuild {
    DDLogInfo(@"Cleaning cache folder for source: %@", sourceBuild);
    if (_progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
        [_progressDelegate updateProgressStatus:@"Cleaning cache folder..." workflow:self];
    }
    NSURL *cacheFolderURL;
    NSURL *sourceFolderURL;
    if ( [sourceBuild isEqualToString:@"All Sources"] ) {
        cacheFolderURL = [self cacheFolderURL];
        if ( cacheFolderURL ) {
            sourceFolderURL = [cacheFolderURL URLByAppendingPathComponent:@"Source"];
            DDLogDebug(@"[DEBUG] Source cache folder path: %@", [sourceFolderURL path]);
        } else {
            DDLogError(@"[ERROR] Source cache folder cannot be empty!");
            return;
        }
        
        if ( ! [sourceFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            DDLogWarn(@"[WARN] Source cache folder doesn't exist!");
            if (_delegate && [_delegate respondsToSelector:@selector(preWorkflowTasksCompleted)]) {
                [_delegate preWorkflowTasksCompleted];
            }
            return;
        }
    } else {
        cacheFolderURL = [self cacheFolderURL];
        if ( cacheFolderURL ) {
            sourceFolderURL = [cacheFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"Source/%@", sourceBuild]];
            DDLogDebug(@"[DEBUG] Source cache folder path: %@", [sourceFolderURL path]);
        } else {
            DDLogError(@"[ERROR] Source cache folder cannot be empty!");
            return;
        }
        
        NSURL *sourcesDictURL = [cacheFolderURL URLByAppendingPathComponent:@"Source/Resources.plist"];
        DDLogDebug(@"[DEBUG] Source cache dict path: %@", [sourcesDictURL path]);
        if ( [sourcesDictURL checkResourceIsReachableAndReturnError:nil] ) {
            NSMutableDictionary *sourcesDict = [NSMutableDictionary dictionaryWithContentsOfURL:sourcesDictURL];
            if ( [sourcesDict count] != 0 ) {
                [sourcesDict removeObjectForKey:sourceBuild];
                if ( [sourcesDict writeToURL:sourcesDictURL atomically:YES] ) {
                    DDLogInfo(@"Source cache dict updated!");
                } else {
                    DDLogError(@"[ERROR] Could not write source cache dict to disk!");
                    return;
                }
            } else {
                DDLogWarn(@"[WARN] Source cache dict was empty!");
            }
        } else {
            DDLogWarn(@"[WARN] Source cache dict doesn't exist!");
        }
        
        if ( ! [sourceFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            DDLogWarn(@"[WARN] Source cache folder doesn't exist!");
            if (_delegate && [_delegate respondsToSelector:@selector(preWorkflowTasksCompleted)]) {
                [_delegate preWorkflowTasksCompleted];
            }
            return;
        }
    }
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            DDLogError(@"[ERROR] %@", proxyError);
        }];
        
    }] removeItemAtURL:sourceFolderURL withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                NSLog(@"Continue!");
            } else {
                DDLogError(@"[ERROR] Cleaning cache folder for source: %@ failed!", sourceBuild);
                DDLogError(@"[ERROR] %@", error);
            }
        }];
    }];
}

@end
