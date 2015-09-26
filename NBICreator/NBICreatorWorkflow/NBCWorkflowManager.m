//
//  NBCWorkflowController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowManager.h"
#import "NBCController.h"
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
#import "NBCSourceController.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowManager

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (id)sharedManager {
    static NBCWorkflowManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
} // sharedManager

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
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    return self;
} // init

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    
    BOOL retval = NO;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemWorkflows] ) {
        if ( [[[_workflowPanel stackView] views] count] != 0 ) {
            retval = YES;
        }
    }
    
    return retval;
} // validateMenuItem

- (void)menuItemWindowWorkflows:(id)sender {
#pragma unused(sender)
    
    
    // -------------------------------------------------------------
    //  If sent from NBCController, just order front, not key
    //  Used to show progress window when activating app from background by clicking main window
    // -------------------------------------------------------------
    if ( [sender isKindOfClass:[NBCController class]] ) {
        if ( _workflowPanel ) {
            [[_workflowPanel window] orderFront:self];
        }
    } else {
        
        // -------------------------------------------------------------
        //  If sent from Menu Item, order front and make key
        // -------------------------------------------------------------
        if ( _workflowPanel ) {
            [[_workflowPanel window] makeKeyAndOrderFront:self];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addWorkflowItemToQueue:(NSNotification *)notification {
    
    
    // -------------------------------------------------------------
    //  Get workflow item from sender
    // -------------------------------------------------------------
    NBCWorkflowItem *workflowItem = [notification userInfo][NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem];
    
    // -------------------------------------------------------------
    //  Setup progress view and add a reference of it to workflow item
    // -------------------------------------------------------------
    NBCWorkflowProgressViewController *progressView = [[NBCWorkflowProgressViewController alloc] init];
    [[progressView view] setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    // ---------------------------------
    //  Add NBI name to progress view
    // ---------------------------------
    NSString *nbiName = [workflowItem nbiName];
    if ( nbiName ) {
        [[progressView textFieldTitle] setStringValue:nbiName];
    }
    
    NSError *error;
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // -------------------------------------------------------------
    //  Incremet global index counter if %COUNTER% is used.
    // -------------------------------------------------------------
    if ( [userSettings[NBCSettingsIndexKey] isEqualToString:NBCVariableIndexCounter] ) {
        [self incrementIndexCounter];
    }
    
    // -------------------------------------------------------------
    //  Add NBI icon to workflow item and progress view
    // -------------------------------------------------------------
    NSString *nbiIconPath = [NBCVariables expandVariables:userSettings[NBCSettingsIconKey]
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
    
    DDLogInfo(@"Base NBI created successfully!");
    [self setCurrentWorkflowNBIComplete:YES];
    
    if ( _currentWorkflowNBIComplete && _currentWorkflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        DDLogInfo(@"Waiting for additional resources to be prepared...");
    }
} // workflowCompleteNBI

- (void)workflowCompleteResources:(NSNotification *)notification {
#pragma unused(notification)
    
    DDLogInfo(@"All resources prepared!");
    [self setCurrentWorkflowResourcesComplete:YES];
    
    if ( _currentWorkflowNBIComplete && _currentWorkflowResourcesComplete ) {
        [self workflowQueueRunWorkflowPostprocessing];
    } else {
        DDLogInfo(@"Waiting for base NBI to be created...");
    }
} // workflowCompleteResources

- (void)workflowCompleteModifyNBI:(NSNotification *)notification {
#pragma unused(notification)
    DDLogInfo(@"NBI modifications complete!");
    [self moveNBIToDestination:[_currentWorkflowItem temporaryNBIURL] destinationURL:[_currentWorkflowItem nbiURL]];
} // workflowCompleteModifyNBI

- (void)endWorkflow {
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsEnabled] ) {
        NSString *name = [_currentWorkflowItem nbiName];
        NSString *workflowTime = [_currentWorkflowItem workflowTime];
        [self postNotificationWithTitle:name informativeText:[NSString stringWithFormat:@"Completed in %@", workflowTime]];
    }
    if ( ! [[NSApplication sharedApplication] isActive] ) {
        NSDockTile *dockTile = [NSApp dockTile];
        NSString *newBadgeLabel = @"1";
        NSString *currentBadgeLabel = [dockTile badgeLabel];
        if ( [currentBadgeLabel length] != 0 ) {
            int newBadgeInt = ( [currentBadgeLabel intValue] + 1);
            newBadgeLabel = [@(newBadgeInt) stringValue];
        }
        [dockTile setBadgeLabel:newBadgeLabel];
        [dockTile display];
    }
    [self setCurrentWorkflowModifyNBIComplete:YES];
    [self setWorkflowRunning:NO];
    [self removeTemporaryFolder];
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
} // endWorkflow

- (void)postNotificationWithTitle:(NSString *)title informativeText:(NSString *)informativeText {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    [notification setTitle:@"NBICreator"];
    [notification setSubtitle:title];
    [notification setInformativeText:informativeText];
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsSoundEnabled] ) {
        [notification setSoundName:NSUserNotificationDefaultSoundName];
    }
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

- (void)workflowFailed:(NSNotification *)notification {
    
    NSError *error = [notification userInfo][NBCUserInfoNSErrorKey];
    NSString *progressViewErrorMessage = nil;
    if ( error ) {
        progressViewErrorMessage = [error localizedDescription];
    }
    
    //[self removeTemporaryFolder];
    
    [self updateWorkflowStatusErrorWithMessage:progressViewErrorMessage];
    [self setWorkflowRunning:NO];
    
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsEnabled] ) {
        NSString *name = [_currentWorkflowItem nbiName];
        [self postNotificationWithTitle:name informativeText:@"Workflow Failed!"];
    }
    
    [_workflowQueue removeObject:_currentWorkflowItem];
    [self workflowQueueRunWorkflow];
} // workflowFailed

- (void)removeWorkflowItem:(NSNotification *)notification {
    
    NBCWorkflowProgressViewController *workflowView = [notification object];
    NBCWorkflowItem *workflowItem = [notification userInfo][NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem];
    [[_workflowPanel stackView] removeView:[workflowView view]];
    [_workflowQueue removeObject:workflowItem];
} // removeWorkflowItem

- (void)removeTemporaryFolder {
    
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *temporaryFolderURL = [_currentWorkflowItem temporaryFolderURL];
    if ( ! [fileManager removeItemAtURL:temporaryFolderURL error:&error] ) {
        DDLogError(@"%@", [error localizedDescription]);
    }
} // removeTemporaryFolder

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
#pragma unused(center, notification)
    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress View Status Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateWorkflowStatusComplete {
    
    [_currentWorkflowProgressView workflowCompleted];
    [self endWorkflow];
} // updateWorkflowStatusComplete

- (void)updateWorkflowStatusErrorWithMessage:(NSString *)errorMessage {
    
    NSString *errorString = errorMessage;
    if ( errorString == nil ) {
        errorString = @"Unknown Error (-1)";
    }
    [_currentWorkflowProgressView workflowFailedWithError:errorString];
    [self endWorkflow];
} // updateWorkflowStatusErrorWithMessage

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)workflowQueueRunWorkflow {
    
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
        BOOL temporaryFolderCreated = NO;
        NSURL *temporaryFolderURL = [self temporaryFolderURL];
        DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
        if ( temporaryFolderURL ) {
            [_currentWorkflowItem setTemporaryFolderURL:temporaryFolderURL];
            NSString *nbiName = [_currentWorkflowItem nbiName];
            DDLogInfo(@"Starting workflow for: %@", nbiName);
            if ( [nbiName length] != 0 ) {
                if ( [nbiName containsString:@" "] ) {
                    nbiName = [nbiName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
                }
                NSURL *temporaryNBIURL = [temporaryFolderURL URLByAppendingPathComponent:nbiName];
                DDLogDebug(@"temporaryNBIURL=%@", temporaryNBIURL);
                if ( temporaryNBIURL ) {
                    [_currentWorkflowItem setTemporaryNBIURL:temporaryNBIURL];
                    
                    NSError *error;
                    NSFileManager *fileManager = [NSFileManager defaultManager];
                    if ( [fileManager createDirectoryAtURL:temporaryNBIURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                        temporaryFolderCreated = YES;
                    } else {
                        DDLogError(@"[ERROR] Failed to create temporary NBI directory at: %@", [temporaryNBIURL path]);
                        DDLogError(@"%@", error);
                    }
                } else {
                    DDLogError(@"[ERROR] temporaryNBIURL was nil!");
                }
            } else {
                DDLogError(@"[ERROR] nbiName was empty!");
            }
        } else {
            DDLogError(@"[ERROR] temporaryFolderURL was nil!");
        }
        
        if ( ! temporaryFolderCreated ) {
            DDLogError(@"[ERROR] Could not create temporary NBI folder!");
            [self updateWorkflowStatusErrorWithMessage:@"Could not create temporary NBI folder!"];
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
        //  Mount source if not mounted
        // -------------------------------------------------------------
        if ( ! [self mountSource] ) {
            DDLogError(@"[ERROR] Could not mount source!");
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        // -------------------------------------------------------------
        //  Run workflows. Don't create NBI if source is a NBI itself.
        // -------------------------------------------------------------
        NSString *sourceType = [[_currentWorkflowItem source] sourceType];
        DDLogDebug(@"sourceType=%@", sourceType);
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
} // workflowQueueRunWorkflow

- (void)workflowQueueRunWorkflowPostprocessing {
    
    [self setCurrentWorkflowModifyNBI:[_currentWorkflowItem workflowModifyNBI]];
    if ( _currentWorkflowModifyNBI ) {
        [_currentWorkflowModifyNBI setDelegate:_currentWorkflowProgressView];
        [_currentWorkflowModifyNBI runWorkflow:_currentWorkflowItem];
    } else {
        DDLogError(@"[ERROR] workflowModifyNBI is nil");
    }
} // workflowQueueRunWorkflowPostprocessing

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)mountSource {
    
    BOOL retval = YES;
    NBCSourceController *sc = [[NBCSourceController alloc] init];
    switch ( [_currentWorkflowItem workflowType] ) {
        case kWorkflowTypeNetInstall:
        {
            retval = [sc verifySourceIsMountedInstallESD:[_currentWorkflowItem source]];
            break;
        }
        case kWorkflowTypeDeployStudio:
        {
            retval = [sc verifySourceIsMountedOSVolume:[_currentWorkflowItem source]];
            break;
        }
        case kWorkflowTypeImagr:
        {
            retval = [sc verifySourceIsMountedInstallESD:[_currentWorkflowItem source]];
            break;
        }
        case kWorkflowTypeCasper:
        {
            retval = [sc verifySourceIsMountedInstallESD:[_currentWorkflowItem source]];
            break;
        }
    }
    
    return retval;
}

- (void)incrementIndexCounter {
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSNumber *currentIndex = [ud objectForKey:NBCUserDefaultsIndexCounter];
    if ( [currentIndex integerValue] == 65535 ) {
        currentIndex = @0;
    }
    NSNumber *newIndex = @([currentIndex intValue] + 1);
    [ud setObject:newIndex forKey:NBCUserDefaultsIndexCounter];
    DDLogDebug(@"Updated NBI Index counter from %@ to %@", currentIndex, newIndex);
} // incrementIndexCounter

- (void)moveNBIToDestination:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL {
    
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Verify that destination has an nbi-extension
    // -------------------------------------------------------------
    NSString *destinationExtension = [destinationURL pathExtension];
    if ( ! [destinationExtension isEqualToString:@"nbi"] ) {
        [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
        return;
    }
    
    // -----------------------------------------------------------------------------
    //  Replace spaces with "-" in NBI filename to prevent problems when NetBooting
    // -----------------------------------------------------------------------------
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
                
                // ----------------------------------------------------
                //  If task failed, post workflow failed notification
                // ----------------------------------------------------
                DDLogError(@"%@", proxyError);
                [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
            }];
            
        }] removeItemAtURL:destinationURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    NSError *blockError;
                    if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&blockError] ) {
                        [self updateWorkflowStatusComplete];
                    } else {
                        DDLogError(@"[ERROR] Moving NBI to destination failed!");
                        DDLogError(@"%@", blockError);
                        [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
                    }
                } else {
                    DDLogError(@"[ERROR] Deleteing existing NBI at destination failed");
                    DDLogError(@"%@", error);
                    [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
                }
            }];
        }];
    } else {
        if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&err] ) {
            DDLogInfo(@"Moving NBI to destination successful!");
            [self updateWorkflowStatusComplete];
        } else {
            DDLogError(@"[ERROR] Moving NBI to destination failed!");
            DDLogError(@"%@", err);
            [self updateWorkflowStatusErrorWithMessage:@"Move Failed"];
        }
    }
} // moveNBIToDestination:destinationURL

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
