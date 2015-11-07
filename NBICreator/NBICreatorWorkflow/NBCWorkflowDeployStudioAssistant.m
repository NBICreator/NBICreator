//
//  NBCWorkflowDeployStudioAssistant.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-06.
//  Copyright © 2015 NBICreator. All rights reserved.
//

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
    
    // --------------------------------
    //  Create NBI
    // --------------------------------
    [self runWorkflowScriptWithArguments:arguments];
}

- (void)runWorkflowScriptWithArguments:(NSArray *)arguments {
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    [[helperConnector connection] setExportedObject:self];
    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
        }];
    }] runTaskWithCommand:@"/bin/sh" arguments:arguments currentDirectory:nil environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self finalizeNBI];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Creating NBI failed"] }];
            }
        }];
    }];
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
        if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
            [_delegate updateProgressStatus:statusString workflow:self];
        }
    }
    
    if ( [stdOut containsString:@"created"] && [stdOut containsString:@"NetInstall.sparseimage"] ) {
        statusString = @"Disabling Spotlight Indexing...";
        if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
            [_delegate updateProgressStatus:statusString workflow:self];
        }
    }
    
    if ( [stdOut containsString:@"Indexing disabled"] ) {
        statusString = @"Disabling Spotlight Indexing...";
        if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
            [_delegate updateProgressStatus:statusString workflow:self];
        }
    }
    
    if ( [stdOut containsString:@"mounted"] ) {
        statusString = @"Determining Recovery Partition...";
        if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
            [_delegate updateProgressStatus:statusString workflow:self];
        }
    }
    
    if ( [stdOut containsString:@"rsync"] || [stdOut containsString:@"ditto"] ) {
        statusString = @"Copying files to NBI...";
        if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)]) {
            [_delegate updateProgressStatus:statusString workflow:self];
        }
    }
    
} // updateDeployStudioWorkflowStatus

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCWorkflowProgressDelegate (Required but unused/passed on)
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
        [_delegate updateProgressStatus:statusMessage workflow:workflow];
    }
}
- (void)updateProgressBar:(double)value {
    if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressBar:)]) {
        [_delegate updateProgressBar:value];
    }
}
- (void)updateProgressStatus:(NSString *)statusMessage {
    if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:)]) {
        [_delegate updateProgressStatus:statusMessage];
    }
}
- (void)logDebug:(NSString *)logMessage {
    if ( _delegate && [_delegate respondsToSelector:@selector(logDebug:)]) {
        [_delegate logDebug:logMessage];
    }
}
- (void)logInfo:(NSString *)logMessage {
    if ( _delegate && [_delegate respondsToSelector:@selector(logInfo:)]) {
        [_delegate logInfo:logMessage];
    }
}
- (void)logWarn:(NSString *)logMessage {
    if ( _delegate && [_delegate respondsToSelector:@selector(logWarn:)]) {
        [_delegate logWarn:logMessage];
    }
}
- (void)logError:(NSString *)logMessage {
    if ( _delegate && [_delegate respondsToSelector:@selector(logError:)]) {
        [_delegate logError:logMessage];
    }
}
- (void)logStdErr:(NSString *)stdErrString {
    if ( _delegate && [_delegate respondsToSelector:@selector(logStdErr:)]) {
        [_delegate logStdErr:stdErrString];
    }
}

@end
