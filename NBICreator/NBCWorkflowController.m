//
//  NBCWorkflowController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NSString+randomString.h"

#import "NBCImagrWorkflowNBI.h"
#import "NBCImagrWorkflowResources.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCDeployStudioWorkflowNBI.h"
#import "NBCDeployStudioWorkflowResources.h"
#import "NBCDeployStudioWorkflowModifyNBI.h"

#import "NBCNetInstallWorkflowNBI.h"
#import "NBCNetInstallWorkflowResources.h"
#import "NBCNetInstallWorkflowModifyNBI.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

@implementation NBCWorkflowController

#pragma mark -
#pragma mark Initialization
#pragma mark -

- (id)init {
    self = [super init];
    if (self != nil) {
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(removeWorkflowItem:) name:@"removeWorkflowItem" object:nil];
        [center addObserver:self selector:@selector(workflowFailed:) name:NBCNotificationWorkflowFailed object:nil];
        [center addObserver:self selector:@selector(workflowCompleteNBI:) name:NBCNotificationWorkflowCompleteNBI object:nil];
        [center addObserver:self selector:@selector(workflowCompleteResources:) name:NBCNotificationWorkflowCompleteResources object:nil];
        [center addObserver:self selector:@selector(workflowCompleteModifyNBI:) name:NBCNotificationWorkflowCompleteModifyNBI object:nil];
        [center addObserver:self selector:@selector(addWorkflowItemToQueue:) name:NBCNotificationAddWorkflowItemToQueue object:nil];
        
        _workflowQueue = [[NSMutableArray alloc] init];
        _workflowViewArray = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Notification Methods
#pragma mark -

- (void)addWorkflowItemToQueue:(NSNotification *)notification {
    // -------------------------------------------------------------
    //  Incremet global index counter
    // -------------------------------------------------------------
    
    [self incrementIndexCounter];
    
    // -------------------------------------------------------------
    //  Get workflow item from sender
    // -------------------------------------------------------------
    
    NBCWorkflowItem *workflowItem = [notification userInfo][NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem];
    
    // -------------------------------------------------------------
    //  Setup progress view and add a reference of it to workflow item
    // -------------------------------------------------------------
    
    NBCWorkflowProgressViewController *progressView = [[NBCWorkflowProgressViewController alloc] init];
    [[progressView view] setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSString *nbiName = [workflowItem nbiName];
    if ( nbiName ) {
        [[progressView textFieldTitle] setStringValue:nbiName];
    }
    
    [[progressView textFieldStatusInfo] setStringValue:@"Waiting..."];
    
    // -------------------------------------------------------------
    //  Add NBI icon to workflow item and progress view
    // -------------------------------------------------------------
    NSError *error;
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiIconPath = [NBCVariables expandVariables:userSettings[NBCSettingsNBIIcon]
                                                   source:[workflowItem source]
                                        applicationSource:[workflowItem applicationSource]];
    
    if ( [nbiIconPath length] != 0 ) {
        NSURL *nbiIconURL = [NSURL fileURLWithPath:nbiIconPath];
        if ( [nbiIconURL checkResourceIsReachableAndReturnError:&error] ) {
            [workflowItem setNbiIconURL:nbiIconURL];
            NSImage *nbiIcon = [[NSImage alloc] initWithContentsOfURL:nbiIconURL];
            [workflowItem setNbiIcon:nbiIcon];
            [[progressView nbiIcon] setImage:nbiIcon];
        } else {
            NSLog(@"Could not get selected NBI Icon");
            NSLog(@"Error: %@", error);
        }
    }
    
    [progressView setWorkflowItem:workflowItem];
    [workflowItem setProgressView:progressView];
    
    // -------------------------------------------------------------
    //  Add progress view to stack view and show it
    // -------------------------------------------------------------
    
    if ( ! _workflowPanel ) {
        _workflowPanel = [[NBCWorkflowPanelController alloc] initWithWindowNibName:@"NBCWorkflowPanelController"];
    }
    /* This needs to be here, otherwise the view doesn't show up... don't know why yet. */
    [[_workflowPanel window] setTitle:@"NBICreator Workflow"];
    /* -------------------------------------------------------------------------------- */
    
    [[_workflowPanel stackView] addView:[progressView view] inGravity:NSStackViewGravityLeading];
    [_workflowViewArray addObject:progressView];
    [_workflowPanel showWindow:self];
    [[_workflowPanel window] makeKeyAndOrderFront:self];
    
    // -------------------------------------------------------------
    //  Add workflow item to queue and run queue
    // -------------------------------------------------------------
    
    [_workflowQueue addObject:workflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)workflowCompleteNBI:(NSNotification *)notification {
#pragma unused(notification)
    NSLog(@"workflowCompleteNBI");
    _workflowNBIComplete = YES;
    
    if ( _workflowNBIComplete && _workflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        [[_currentWorkflowProgressView textFieldStatusInfo] setStringValue:@"Preparing Resources to be added to NBI..."];
        [[_currentWorkflowProgressView progressIndicator] setIndeterminate:YES];
        NSLog(@"Waiting for workflowResources");
    }
}

- (void)workflowCompleteResources:(NSNotification *)notification {
    #pragma unused(notification)
    NSLog(@"workflowCompleteResources");
    _workflowResourcesComplete = YES;
    
    if ( _workflowNBIComplete && _workflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        NSLog(@"Waiting for workflowNBI");
    }
}

- (void)workflowCompleteModifyNBI:(NSNotification *)notification {
    #pragma unused(notification)
    NSLog(@"workflowCompleteModifyNBI");
    [self moveNBIToDestination:[_currentWorkflowItem temporaryNBIURL] destinationURL:[_currentWorkflowItem nbiURL]];
}

- (void)endWorkflow {
    [self setWorkflowModifyNBIComplete:YES];
    [self setWorkflowRunning:NO];
    
    [self removeTemporaryFolder];
    
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)workflowFailed:(NSNotification *)notification {
    NSLog(@"workflowFailed");
    NSError *error = [notification userInfo][@"error"];
    NSString *progressViewErrorMessage = nil;
    if ( error ) {
        progressViewErrorMessage = [error localizedDescription];
    }
    
    //[self removeTemporaryFolder];
    
    [self updateWorkflowStatusError:_currentWorkflowProgressView errorMessage:progressViewErrorMessage];
    [self setWorkflowRunning:NO];
    
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)removeWorkflowItem:(NSNotification *)notification {
    NBCWorkflowProgressViewController *workflowView = [notification object];
    NBCWorkflowItem *workflowItem = [notification userInfo][NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem];
    [[_workflowPanel stackView] removeView:[workflowView view]];
    [_workflowQueue removeObject:workflowItem];
}

- (void)removeTemporaryFolder {
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *temporaryFolderURL = [_currentWorkflowItem temporaryFolderURL];
    if ( ! [fileManager removeItemAtURL:temporaryFolderURL error:&error] ) {
        NSLog(@"Removing temporary folder failed!");
        NSLog(@"Error: %@", error);
    }
}

#pragma mark -
#pragma mark Progress View Status Methods
#pragma mark -

- (void)updateWorkflowStatusComplete:(NBCWorkflowProgressViewController *)progressView {
    [[progressView textFieldCenter] setStringValue:@"Workflow Complete!"];
    [[progressView textFieldStatusInfo] setStringValue:[[progressView nbiURL] path]];
    [[progressView progressIndicator] stopAnimation:self];
    [[progressView progressIndicator] setHidden:YES];
    [[progressView textFieldCenter] setHidden:NO];
    [[progressView buttonStatusInfo] setHidden:NO];
    
    [self endWorkflow];
}

- (void)updateWorkflowStatusError:(NBCWorkflowProgressViewController *)progressView errorMessage:(NSString *)errorMessage {
    NSString *errorString = errorMessage;
    if ( errorString == nil ) {
        errorString = @"Unknown Error (-1)";
    }
    [[progressView textFieldCenter] setStringValue:@"Workflow Failed!"];
    [[progressView textFieldStatusInfo] setStringValue:errorString];
    [[progressView progressIndicator] stopAnimation:self];
    [[progressView progressIndicator] setHidden:YES];
    [[progressView textFieldCenter] setHidden:NO];
    [[progressView buttonStatusInfo] setHidden:NO];
    
    [self endWorkflow];
}

#pragma mark -
#pragma mark
#pragma mark -

- (void)workflowQueueRunWorkflow {
    if ( ! _workflowRunning && [_workflowQueue count] != 0 ) {
        // -------------------------------------------------------------
        //  Reset current workflow variables
        // -------------------------------------------------------------
        
        [self setWorkflowNBIComplete:NO];
        [self setWorkflowResourcesComplete:NO];
        [self setWorkflowModifyNBIComplete:NO];
        [self setWorkflowRunning:YES];
        
        // -------------------------------------------------------------
        //  Get workflow item from the top of the queue
        // -------------------------------------------------------------
        
        [self setCurrentWorkflowItem:[_workflowQueue firstObject]];
        [_currentWorkflowItem setStartTime:[NSDate date]];
        
        // -------------------------------------------------------------
        //  Get progress view from current workflow item
        // -------------------------------------------------------------
        
        [self setCurrentWorkflowProgressView:[_currentWorkflowItem progressView]];
        [_currentWorkflowProgressView setNbiURL:[_currentWorkflowItem nbiURL]];
        
        // -------------------------------------------------------------
        //  Create a path to a unique temporary folder
        // -------------------------------------------------------------
        NSURL *temporaryFolderURL = [self temporaryFolderURL];
        if ( temporaryFolderURL ) {
            [_currentWorkflowItem setTemporaryFolderURL:temporaryFolderURL];
            NSString *nbiName = [_currentWorkflowItem nbiName];
            if ( [nbiName length] != 0 ) {
                NSURL *temporaryNBIURL = [temporaryFolderURL URLByAppendingPathComponent:nbiName];
                if ( temporaryNBIURL ) {
                    [_currentWorkflowItem setTemporaryNBIURL:temporaryNBIURL];
                    
                    NSError *error;
                    NSFileManager *fileManager = [NSFileManager defaultManager];
                    if ( ! [fileManager createDirectoryAtURL:temporaryNBIURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                        NSLog(@"Failed creating temporary NBI URL: %@", temporaryNBIURL);
                        NSLog(@"Error: %@", error);
                    }
                }
            }
        }
        
        // -------------------------------------------------------------
        //  Instantiate workflow target if it doesn't exist.
        // -------------------------------------------------------------
        
        NBCTarget *target = [_currentWorkflowItem target];
        if ( target == nil ) {
            target = [[NBCTarget alloc] init];
            [_currentWorkflowItem setTarget:target];
        }
        
        // -------------------------------------------------------------
        //  Run workflows.Don't create NBI if source is a NBI itself.
        // -------------------------------------------------------------
        
        NSString *sourceType = [[_currentWorkflowItem source] sourceType];
        if ( ! [sourceType isEqualToString:NBCSourceTypeNBI] ) {
            id workflowNBI = [_currentWorkflowItem workflowNBI];
            if ( workflowNBI ) {
                [workflowNBI runWorkflow:_currentWorkflowItem];
            }
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
        }
        
        id workflowResources = [_currentWorkflowItem workflowResources];
        if ( workflowResources ) {
            [workflowResources runWorkflow:_currentWorkflowItem];
        }
    }
}

- (void)workflowQueueRunWorkflowPostprocessing {
    NSLog(@"workflowQueueRunWorkflowPostprocessing");
    id workflowModifyNBI = [_currentWorkflowItem workflowModifyNBI];
    if ( workflowModifyNBI ) {
        [workflowModifyNBI runWorkflow:_currentWorkflowItem];
    } else {
        NSLog(@"workflowModifyNBI is nil");
    }
}

#pragma mark -
#pragma mark
#pragma mark -

- (void)incrementIndexCounter {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSNumber *currentIndex = [ud objectForKey:NBCUserDefaultsIndexCounter];
    if ( [currentIndex integerValue] == 65535 ) {
        currentIndex = @0;
    }
    NSNumber *newIndex = @([currentIndex intValue] + 1);
    [ud setObject:newIndex forKey:NBCUserDefaultsIndexCounter];
}

- (void)moveNBIToDestination:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL {
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //Sanity Checking
    NSString *destinationExtension = [destinationURL pathExtension];
    if ( ! [destinationExtension isEqualToString:@"nbi"] ) {
        [self updateWorkflowStatusError:_currentWorkflowProgressView errorMessage:@"Move Failed"];
        return;
    }
    
    if ( [destinationURL checkResourceIsReachableAndReturnError:nil] ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
                [self updateWorkflowStatusError:self->_currentWorkflowProgressView errorMessage:@"Move Failed"];
            }];
            
        }] removeItemAtURL:destinationURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                NSLog(@"terminationStatus=%d", terminationStatus);
                if ( terminationStatus == 0 )
                {
                    NSError *blockError;
                    if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&blockError] )
                    {
                        [self updateWorkflowStatusComplete:self->_currentWorkflowProgressView];
                    } else {
                        NSLog(@"Could not move file");
                        NSLog(@"Error: %@", blockError);
                        [self updateWorkflowStatusError:self->_currentWorkflowProgressView errorMessage:@"Move Failed"];
                    }
                } else {
                    NSLog(@"Delete Destination NBI Failed");
                    NSLog(@"Error: %@", error);
                    [self updateWorkflowStatusError:self->_currentWorkflowProgressView errorMessage:@"Move Failed"];
                }
            }];
        }];
    } else {
        if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&err] ) {
            NSLog(@"Move Successful!");
            [self updateWorkflowStatusComplete:_currentWorkflowProgressView];
        } else {
            NSLog(@"Moving NBI Failed!");
            NSLog(@"Error: %@", err);
            [self updateWorkflowStatusError:_currentWorkflowProgressView errorMessage:@"Move Failed"];
        }
    }
}

- (NSURL *)temporaryFolderURL {
    NSURL *temporaryFolderURL;
    NSString *tmpFolderName = [NSString stringWithFormat:@"%@/workflow.%@", NBCBundleIdentifier, [NSString nbc_randomString]];
    NSString *tmpFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpFolderName];
    
    if ( tmpFolderPath ) {
        temporaryFolderURL = [NSURL fileURLWithPath:tmpFolderPath];
    }
    
    return temporaryFolderURL;
} // temporaryFolderURL

@end
