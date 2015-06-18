//
//  NBCDeployStudioWorkflowNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioWorkflowNBI.h"
#import "NBCConstants.h"

#import "NBCController.h"
#import "NBCWorkflowNBIController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

@implementation NBCDeployStudioWorkflowNBI

#pragma mark -
#pragma mark Run Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    NSError *err;
    __unsafe_unretained typeof(self) weakSelf = self;
    _nbiVolumeName = [[workflowItem nbiName] stringByDeletingPathExtension];
    _progressView = [workflowItem progressView];
    [self setTemporaryNBIPath:[[workflowItem temporaryNBIURL] path]];
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
    
    // -------------------------------------------------------------
    //  Create arguments array for sys_builder.sh
    // -------------------------------------------------------------
    NSArray *sysBuilderArguments = [nbiController generateScriptArgumentsForSysBuilder:workflowItem];
    if ( [sysBuilderArguments count] != 0 ) {
        NSLog(@"sysBuilderArguments=%@", sysBuilderArguments);
        [workflowItem setScriptArguments:sysBuilderArguments];
    } else {
        NSLog(@"Error, no argumets for sysBuilderArguments");
        return;
    }
    
    // -------------------------------------------------------------
    //  Prepare destination folder
    // -------------------------------------------------------------
    if ( ! [self prepareDestinationFolder:[workflowItem temporaryNBIURL] workflowItem:workflowItem error:&err] ) {
        NSLog(@"Errror preparing destination folder");
        NSLog(@"Error: %@", err);
        return;
    }
    
    // ------------------------------------------
    //  Setup command to run sys_builder.sh
    // ------------------------------------------
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/sh"];
    
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
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When output data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        [weakSelf updateDeployStudioWorkflowStatus:outStr stdErr:nil];
                                        
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
                                        
                                        // ------------------------
                                        //  Convert data to string
                                        // ------------------------
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        // -----------------------------------------------------------------------
                                        //  When error data becomes available, pass it to workflow status parser
                                        // -----------------------------------------------------------------------
                                        [weakSelf updateDeployStudioWorkflowStatus:nil stdErr:errStr];
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------
    //  Connect to helper and run createNetInstall.sh
    // -----------------------------------------------
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
            // ------------------------------------------------------------------
            NSLog(@"ProxyError? %@", proxyError);
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:sysBuilderArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        #pragma unused(error)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            
            if ( terminationStatus == 0 ) {
                // ------------------------------------------------------------------
                //  If task exited successfully, post workflow complete notification
                // ------------------------------------------------------------------
                [self removeTemporaryItems:workflowItem];
                [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
            } else {
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }
        }];
    }];
} // runWorkflow

#pragma mark -
#pragma mark Pre-/Post Workflow Methods
#pragma mark -

- (BOOL)prepareDestinationFolder:(NSURL *)destinationFolderURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    #pragma unused(error)
    BOOL retval = YES;
    
    // ------------------------------------------------------------------
    //  Save URL for NBI NetInstall.dmg
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [destinationFolderURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    
    return retval;
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)removeTemporaryItems:(NBCWorkflowItem *)workflowItem {
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSError *error;
    NSArray *temporaryItemsNBI = [workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ( ! [fileManager removeItemAtURL:temporaryItemURL error:&error] ) {
            NSLog(@"Failed Deleting file: %@", [temporaryItemURL path] );
            NSLog(@"Error: %@", error);
        }
    }
} // removeTemporaryItems

- (void)updateDeployStudioWorkflowStatus:(NSString *)stdOut stdErr:(NSString *)stdErr {
    NSString *statusString = stdOut;
    if ( stdOut ) {
        NSLog(@"stdOut=%@", stdOut);
    }
    
    if ( stdErr ) {
        NSLog(@"stdErr=%@", stdErr);
    }
    
    if ( [statusString containsString:@"Adding lib"] ) {
        statusString = [NSString stringWithFormat:@"Adding Frameworks: %@", [[statusString lastPathComponent] stringByReplacingOccurrencesOfString:@"'" withString:@""]];
        [[_progressView textFieldStatusInfo] setStringValue:statusString];
    }
    
    if ( [statusString containsString:@"created"] && [statusString containsString:@"NetInstall.sparseimage"] ) {
        statusString = @"Disabling Spotlight Indexing";
        [[_progressView textFieldStatusInfo] setStringValue:statusString];
    }
    
    if ( [statusString containsString:@"Indexing disabled"] ) {
        statusString = @"Disabling Spotlight Indexing";
        [[_progressView textFieldStatusInfo] setStringValue:statusString];
    }
    
    if ( ! [statusString containsString:@"<loop"] ) {
        //[[_view textFieldStatusInfo] setStringValue:outStr];
        //NSLog(@"%@", stdOut);
    }
    
} // updateDeployStudioWorkflowStatus

@end
