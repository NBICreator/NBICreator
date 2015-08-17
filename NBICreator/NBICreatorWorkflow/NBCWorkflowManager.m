//
//  NBCWorkflowController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowManager.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NSString+randomString.h"

#import "NBCImagrWorkflowResources.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCDeployStudioWorkflowResources.h"
#import "NBCDeployStudioWorkflowModifyNBI.h"

#import "NBCNetInstallWorkflowResources.h"
#import "NBCNetInstallWorkflowModifyNBI.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowManager

+ (id)sharedManager {
    static NBCWorkflowManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

#pragma mark -
#pragma mark Initialization
#pragma mark -

- (id)init {
    self = [super init];
    if (self != nil) {
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(removeWorkflowItem:) name:NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem object:nil];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark Notification Methods
#pragma mark -

- (void)addWorkflowItemToQueue:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
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
    
    //[progressView updateProgressStatus:@"Waiting..."];
    
    NSError *error;
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // -------------------------------------------------------------
    //  Incremet global index counter if %COUNTER% is used.
    // -------------------------------------------------------------
    if ( [userSettings[NBCSettingsNBIIndex] isEqualToString:NBCVariableIndexCounter] ) {
        [self incrementIndexCounter];
    }

    // -------------------------------------------------------------
    //  Add NBI icon to workflow item and progress view
    // -------------------------------------------------------------
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
            DDLogError(@"Error: %@", [error localizedDescription]);
        }
    }
    
    [progressView setWorkflowItem:workflowItem];
    [workflowItem setProgressView:progressView];
    
    // -------------------------------------------------------------
    //  Add progress view to stack view and show it
    // -------------------------------------------------------------
    if ( ! _workflowPanel ) {
        [self setWorkflowPanel:[[NBCWorkflowPanelController alloc] initWithWindowNibName:@"NBCWorkflowPanelController"]];
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
    DDLogInfo(@"Adding %@ to workflow queue...", nbiName);
    [_workflowQueue addObject:workflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)workflowCompleteNBI:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"[Workflow: NBI] Base NBI created successfully!");
    [self setCurrentWorkflowNBIComplete:YES];
    
    if ( _currentWorkflowNBIComplete && _currentWorkflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        DDLogInfo(@"[Workflow: NBI] Waiting for additional resources to be prepared");
    }
}

- (void)workflowCompleteResources:(NSNotification *)notification {
    #pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"[Workflow: Resources] All resources prepared!");
    [self setCurrentWorkflowResourcesComplete:YES];
    
    if ( _currentWorkflowNBIComplete && _currentWorkflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        DDLogInfo(@"[Workflow: Resources] Waiting for base NBI to be created");
    }
}

- (void)workflowCompleteModifyNBI:(NSNotification *)notification {
    #pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"[Workflow: Modify] NBI modifications complete!");
    [self moveNBIToDestination:[_currentWorkflowItem temporaryNBIURL] destinationURL:[_currentWorkflowItem nbiURL]];
}

- (void)endWorkflow {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setCurrentWorkflowModifyNBIComplete:YES];
    [self setWorkflowRunning:NO];
    [self removeTemporaryFolder];
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)workflowFailed:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error = [notification userInfo][NBCUserInfoNSErrorKey];
    NSString *progressViewErrorMessage = nil;
    if ( error ) {
        progressViewErrorMessage = [error localizedDescription];
    }
    
    //[self removeTemporaryFolder];
    
    [self updateWorkflowStatusErrorWithMessage:progressViewErrorMessage];
    [self setWorkflowRunning:NO];
    
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
}

- (void)removeWorkflowItem:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCWorkflowProgressViewController *workflowView = [notification object];
    NBCWorkflowItem *workflowItem = [notification userInfo][NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem];
    [[_workflowPanel stackView] removeView:[workflowView view]];
    [_workflowQueue removeObject:workflowItem];
}

- (void)removeTemporaryFolder {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *temporaryFolderURL = [_currentWorkflowItem temporaryFolderURL];
    if ( ! [fileManager removeItemAtURL:temporaryFolderURL error:&error] ) {
        DDLogError(@"%@", [error localizedDescription]);
    }
}

#pragma mark -
#pragma mark Progress View Status Methods
#pragma mark -

- (void)updateWorkflowStatusComplete {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_currentWorkflowProgressView workflowCompleted];
    
    [self endWorkflow];
}

- (void)updateWorkflowStatusErrorWithMessage:(NSString *)errorMessage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *errorString = errorMessage;
    if ( errorString == nil ) {
        errorString = @"Unknown Error (-1)";
    }
    [_currentWorkflowProgressView workflowFailedWithError:errorString];
    [self endWorkflow];
}

#pragma mark -
#pragma mark
#pragma mark -

- (void)workflowQueueRunWorkflow {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( ! _workflowRunning && [_workflowQueue count] != 0 ) {
        
        // -------------------------------------------------------------
        //  Reset current workflow variables
        // -------------------------------------------------------------
        [self setCurrentWorkflowNBIComplete:NO];
        [self setCurrentWorkflowResourcesComplete:NO];
        [self setCurrentWorkflowModifyNBIComplete:NO];
        [self setWorkflowRunning:YES];
        [self setResourcesLastMessage:nil];
        
        // -------------------------------------------------------------
        //  Get workflow item from the top of the queue
        // -------------------------------------------------------------
        [self setCurrentWorkflowItem:[_workflowQueue firstObject]];
        [_currentWorkflowItem setStartTime:[NSDate date]];
        
        // -------------------------------------------------------------
        //  Get progress view from current workflow item
        // -------------------------------------------------------------
        [self setCurrentWorkflowProgressView:[_currentWorkflowItem progressView]];
        [_currentWorkflowProgressView workflowStartedForItem:_currentWorkflowItem];
        
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
                        DDLogError(@"Failed to create temporary NBI directory at: %@", [temporaryNBIURL path]);
                        DDLogError(@"Error: %@", [error localizedDescription]);
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
        //  Run workflows. Don't create NBI if source is a NBI itself.
        // -------------------------------------------------------------
        NSString *sourceType = [[_currentWorkflowItem source] sourceType];
        if ( ! [sourceType isEqualToString:NBCSourceTypeNBI] ) {
            [self setCurrentWorkflowNBI:[_currentWorkflowItem workflowNBI]];
            if ( _currentWorkflowNBI ) {
                [_currentWorkflowNBI setDelegate:_currentWorkflowProgressView];
                [_currentWorkflowNBI runWorkflow:_currentWorkflowItem];
            }
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
        }
        
        [self setCurrentWorkflowResources:[_currentWorkflowItem workflowResources]];
        if ( _currentWorkflowResources ) {
            [_currentWorkflowResources setDelegate:_currentWorkflowProgressView];
            [_currentWorkflowResources runWorkflow:_currentWorkflowItem];
        }
    }
}

- (void)workflowQueueRunWorkflowPostprocessing {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setCurrentWorkflowModifyNBI:[_currentWorkflowItem workflowModifyNBI]];
    if ( _currentWorkflowModifyNBI ) {
        [_currentWorkflowModifyNBI setDelegate:_currentWorkflowProgressView];
        [_currentWorkflowModifyNBI runWorkflow:_currentWorkflowItem];
    } else {
        NSLog(@"workflowModifyNBI is nil");
    }
}

#pragma mark -
#pragma mark
#pragma mark -

- (void)incrementIndexCounter {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSNumber *currentIndex = [ud objectForKey:NBCUserDefaultsIndexCounter];
    if ( [currentIndex integerValue] == 65535 ) {
        currentIndex = @0;
    }
    NSNumber *newIndex = @([currentIndex intValue] + 1);
    [ud setObject:newIndex forKey:NBCUserDefaultsIndexCounter];
    DDLogDebug(@"Updated NBI Index counter from %@ to %@", currentIndex, newIndex);
}

- (void)moveNBIToDestination:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    //Sanity Checking
    NSString *destinationExtension = [destinationURL pathExtension];
    if ( ! [destinationExtension isEqualToString:@"nbi"] ) {
        [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
        return;
    }
    
    NSString *destinationFileName = [destinationURL lastPathComponent];
    if ( [destinationFileName containsString:@" "] ) {
        destinationFileName = [destinationFileName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
        destinationURL = [[destinationURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:destinationFileName];
        if ( ! destinationURL ) {
            [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
            return;
        }
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
                [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
            }];
            
        }] removeItemAtURL:destinationURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    NSError *blockError;
                    if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&blockError] ) {
                        [self updateWorkflowStatusComplete];
                    } else {
                        NSLog(@"Could not move file");
                        NSLog(@"Error: %@", blockError);
                        [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
                    }
                } else {
                    NSLog(@"Delete Destination NBI Failed");
                    NSLog(@"Error: %@", error);
                    [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
                }
            }];
        }];
    } else {
        if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&err] ) {
            NSLog(@"Move Successful!");
            [self updateWorkflowStatusComplete];
        } else {
            NSLog(@"Moving NBI Failed!");
            NSLog(@"Error: %@", err);
            [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
        }
    }
}

- (NSURL *)temporaryFolderURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *temporaryFolderURL;
    NSString *tmpFolderName = [NSString stringWithFormat:@"%@/workflow.%@", NBCBundleIdentifier, [NSString nbc_randomString]];
    NSString *tmpFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpFolderName];
    
    if ( tmpFolderPath ) {
        temporaryFolderURL = [NSURL fileURLWithPath:tmpFolderPath];
    }
    
    return temporaryFolderURL;
} // temporaryFolderURL

@end
