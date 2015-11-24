//
//  NBCWorkflowDeployStudioAssistant.m
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

#import "NBCWorkflowDeployStudioAssistant.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowNBIController.h"
#import "NBCLogging.h"
#import "NBCError.h"
#import "NBCConstants.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowDeployStudioAssistant

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Create NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)createNBI:(NBCWorkflowItem *)workflowItem {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [self setWorkflowItem:workflowItem];
    
    // -------------------------------------------------------------
    //  Create arguments array for sys_builder.sh
    // -------------------------------------------------------------
    NSArray *arguments = [NBCWorkflowNBIController generateScriptArgumentsForSysBuilder:workflowItem];
    if ( [arguments count] != 0 ) {
        [workflowItem setScriptArguments:arguments];
    } else {
        DDLogError(@"[ERROR] No argumets returned for sys_builder.sh");
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Creating script arguments for sys_builder.sh failed"] }];
    }
    
    // ------------------------------------------------------------------
    //  Save URL for NBI NetInstall.dmg
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"NetInstall.dmg"];
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    // -------------------------------------------------------------------
    //  Add sysBuilder.sh path
    // -------------------------------------------------------------------
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:self];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
            });
        }] sysBuilderWithArguments:arguments sourceVersionMinor:sourceVersionMinor selectedVersion:@"" withReply:^(NSError *error, int terminationStatus) {
            if ( terminationStatus == 0 ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finalizeNBI];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
                });
            }
        }];
    });
}

- (void)finalizeNBI {
    
    DDLogInfo(@"Removing temporary items...");
    
    __block NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSArray *temporaryItemsNBI = [_workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        DDLogDebug(@"[DEBUG] Removing item at path: %@", [temporaryItemURL path]);
        
        if ( ! [fm removeItemAtURL:temporaryItemURL error:&error] ) {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
    
    // ------------------------
    //  Send workflow complete
    // ------------------------
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)logStdOut:(NSString *)stdOutString {
    [self updateDeployStudioWorkflowStatus:stdOutString];
}

- (void)updateDeployStudioWorkflowStatus:(NSString *)stdOut {
    
    NSString *statusString = stdOut;
    
    if ( [stdOut containsString:@"Adding lib"] ) {
        statusString = [NSString stringWithFormat:@"Adding Framework: %@...", [[statusString lastPathComponent] stringByReplacingOccurrencesOfString:@"'" withString:@""]];
        [_delegate updateProgressStatus:statusString workflow:self];
    }
    
    if ( [stdOut containsString:@"created"] && [stdOut containsString:@"NetInstall.sparseimage"] ) {
        statusString = @"Disabling Spotlight Indexing...";
        [_delegate updateProgressStatus:statusString workflow:self];
    }
    
    if ( [stdOut containsString:@"Indexing disabled"] ) {
        statusString = @"Disabling Spotlight Indexing...";
        [_delegate updateProgressStatus:statusString workflow:self];
    }
    
    if ( [stdOut containsString:@"mounted"] ) {
        statusString = @"Determining Recovery Partition...";
        [_delegate updateProgressStatus:statusString workflow:self];
    }
    
    if ( [stdOut containsString:@"rsync"] || [stdOut containsString:@"ditto"] ) {
        statusString = @"Copying files to NBI...";
        [_delegate updateProgressStatus:statusString workflow:self];
    }
    
} // updateDeployStudioWorkflowStatus

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCWorkflowProgressDelegate (Required but unused/passed on)
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    [_delegate updateProgressStatus:statusMessage workflow:workflow];
}
- (void)updateProgressBar:(double)value {
    [_delegate updateProgressBar:value];
}
- (void)incrementProgressBar:(double)value {
    [_delegate incrementProgressBar:value];
}
- (void)updateProgressStatus:(NSString *)statusMessage {
    [_delegate updateProgressStatus:statusMessage];
}
- (void)logDebug:(NSString *)logMessage {
    [_delegate logDebug:logMessage];
}
- (void)logInfo:(NSString *)logMessage {
    [_delegate logInfo:logMessage];
}
- (void)logWarn:(NSString *)logMessage {
    [_delegate logWarn:logMessage];
}
- (void)logError:(NSString *)logMessage {
    [_delegate logError:logMessage];
}
- (void)logStdErr:(NSString *)stdErrString {
    [_delegate logStdErr:stdErrString];
}

@end
