//
//  NBCWorkflowController.m
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

#import "NBCWorkflowManager.h"
#import "NBCController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NSString+randomString.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"
#import "NBCDiskImageController.h"
#import "NBCError.h"
#import "NBCWorkflowUpdateNBI.h"
#import "NBCWorkflowNBICreator.h"
#import "NBCWorkflowResources.h"
#import "NBCWorkflowModifyNBI.h"
#import "NBCWorkflowSystemImageUtility.h"
#import "NBCWorkflowDeployStudioAssistant.h"

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
        [center addObserver:self selector:@selector(workflowCompleteUpdateNBI:) name:NBCNotificationWorkflowCompleteUpdateNBI object:nil];
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
} // dealloc

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods SourceMountDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)sourceMountSuccessful {
    [[_currentWorkflowItem source] setDelegate:nil];
    [self runWorkflow];
} // sourceMountSuccessful

- (void)sourceMountFailedWithError:(NSError *)error {
    [[_currentWorkflowItem source] setDelegate:nil];
    [self updateWorkflowStatusErrorWithMessage:[error localizedDescription]];
} // sourceMountFailedWithError

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if ( [[menuItem title] isEqualToString:NBCMenuItemWorkflows] ) {
        if ( [[[_workflowPanel stackView] views] count] != 0 ) {
            return YES;
        }
    }
    return NO;
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
} // menuItemWindowWorkflows

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
    } else {
        DDLogWarn(@"[WARN] NBI name was empty");
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
            [self updateWorkflowStatusErrorWithMessage:[error localizedDescription]];
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
    [[_workflowPanel window] setTitle:@"NBICreator Workflow Queue"];
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
    } else if ( _currentWorkflowNBIComplete && [_currentWorkflowNBI isKindOfClass:[NBCWorkflowUpdateNBI class]] ) {
        NBCWorkflowResources *workflowResources = [[NBCWorkflowResources alloc] initWithDelegate:_currentWorkflowProgressView];
        [self setCurrentWorkflowResources:workflowResources];
        if ( workflowResources ) {
            [workflowResources prepareResources:_currentWorkflowItem];
        }
    } else {
        DDLogInfo(@"Waiting for additional resources to be prepared...");
    }
} // workflowCompleteNBI

- (void)workflowCompleteUpdateNBI:(NSNotification *)notification {
#pragma unused(notification)
    [self updateWorkflowStatusComplete];
} // workflowCompleteUpdateNBI

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
    if ( ! [[[_currentWorkflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        [self moveNBIToDestination:[_currentWorkflowItem temporaryNBIURL] destinationURL:[_currentWorkflowItem nbiURL]];
    } else {
        [self updateWorkflowStatusComplete];
    }
} // workflowCompleteModifyNBI

- (void)endWorkflow:(NSString *)status {
    
    if ( [status isEqualToString:@"completed"] ) {
        NSString *name = [_currentWorkflowItem nbiName];
        NSString *workflowTime = [_currentWorkflowItem workflowTime];
        
        DDLogInfo(@"*** Workflow: %@ completed in %@ ***", name, workflowTime);
        
        if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsEnabled] ) {
            NSString *notificationMessage;
            if ( [workflowTime length] != 0 ) {
                notificationMessage = [NSString stringWithFormat:@"Completed in %@", workflowTime];
            } else {
                notificationMessage = @"Workflow completed";
            }
            
            [self postNotificationWithTitle:name informativeText:notificationMessage];
        }
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
    
    NSString *name = [_currentWorkflowItem nbiName];
    
    DDLogError(@"*** Workflow: %@ failed ***", name);
    
    NSError *error = [notification userInfo][NBCUserInfoNSErrorKey];
    NSString *progressViewErrorMessage = nil;
    if ( [[error localizedDescription] length] != 0 ) {
        progressViewErrorMessage = [error localizedDescription];
        DDLogError(@"[ERROR] %@", progressViewErrorMessage);
    }
    
    [self updateWorkflowStatusErrorWithMessage:progressViewErrorMessage];
    [self setWorkflowRunning:NO];
    
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsEnabled] ) {
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

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
#pragma unused(center, notification)
    return YES;
} // userNotificationCenter

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress View Status Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateWorkflowStatusComplete {
    [_currentWorkflowProgressView workflowCompleted];
    [self endWorkflow:@"completed"];
} // updateWorkflowStatusComplete

- (void)updateWorkflowStatusErrorWithMessage:(NSString *)errorMessage {
    [_currentWorkflowProgressView workflowFailedWithError:errorMessage ?: @"Unknown Error (-1)"];
    [self endWorkflow:@"failed"];
} // updateWorkflowStatusErrorWithMessage

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)workflowQueueRunWorkflow {
    
    NSError *error;
    
    if ( ! _workflowRunning && [_workflowQueue count] != 0 ) {
        DDLogDebug(@"[DEBUG] Starting queued workflow...");
        
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
        NSString *nbiName = [_currentWorkflowItem nbiName];
        if ( [nbiName length] != 0 ) {
            DDLogInfo(@"*** Workflow: %@ started ***", nbiName);
            
            if ( [nbiName containsString:@" "] ) {
                DDLogDebug(@"[DEBUG] Replacing spaces in NBI name with dashes (-)...");
                
                nbiName = [nbiName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
                DDLogDebug(@"[DEBUG] New NBI name is: %@", nbiName);
            }
        } else {
            [self updateWorkflowStatusErrorWithMessage:@"NBI name cannot be empty!"];
            return;
        }
        
        [_currentWorkflowItem setStartTime:[NSDate date]];
        
        // -------------------------------------------------------------
        //  Get progress view from current workflow item
        // -------------------------------------------------------------
        [self setCurrentWorkflowProgressView:[_currentWorkflowItem progressView]];
        [_currentWorkflowProgressView workflowStartedForItem:_currentWorkflowItem];
        
        NSString *creationTool = [_currentWorkflowItem userSettings][NBCSettingsNBICreationToolKey];
        DDLogDebug(@"[DEBUG] NBI creation tool: %@", creationTool);
        
        if ( [creationTool length] != 0 ) {
            [self setCurrentCreationTool:creationTool];
        } else {
            [self updateWorkflowStatusErrorWithMessage:@"Creation tool cannot be empty"];
            return;
        }
        
        // -------------------------------------------------------------
        //  Create a path to a unique temporary folder
        // -------------------------------------------------------------
        if ( ! [self createTemporaryFolderForNBI:nbiName error:&error] ) {
            [self updateWorkflowStatusErrorWithMessage:[error localizedDescription]];
            return;
        }
        
        NSDictionary *preWorkflowTasks = [_currentWorkflowItem preWorkflowTasks];
        if ( [preWorkflowTasks count] != 0 ) {
            NBCWorkflowPreWorkflowTaskController *preWorkflowTaskController = [[NBCWorkflowPreWorkflowTaskController alloc] initWithDelegate:self];
            [preWorkflowTaskController setProgressDelegate:_currentWorkflowProgressView];
            [preWorkflowTaskController runPreWorkflowTasks:preWorkflowTasks workflowItem:_currentWorkflowItem];
        } else {
            [self prepareSource];
        }
    } else {
        DDLogInfo(@"Workflow queue is empty");
    }
} // workflowQueueRunWorkflow

- (void)workflowQueueRunWorkflowPostprocessing {
    if (
        [_currentCreationTool isEqualToString:NBCMenuItemNBICreator] ||
        [_currentCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ||
        [_currentCreationTool isEqualToString:NBCMenuItemDeployStudioAssistant]
        ) {
        NBCWorkflowModifyNBI *workflowModifyNBI = [[NBCWorkflowModifyNBI alloc] initWithDelegate:[_currentWorkflowItem progressView]];
        [_currentWorkflowItem setWorkflowModifyNBI:workflowModifyNBI];
        [self setCurrentWorkflowModifyNBI:workflowModifyNBI];
        if ( workflowModifyNBI ) {
            [workflowModifyNBI modifyNBI:_currentWorkflowItem];
        }
    } else {
        [self updateWorkflowStatusErrorWithMessage:[NSString stringWithFormat:@"Unknown creation tool: %@", _currentCreationTool]];
    }
} // workflowQueueRunWorkflowPostprocessing

- (void)preWorkflowTasksCompleted {
    DDLogDebug(@"[DEBUG] Pre-workflow tasks completed");
    [self prepareSource];
} // preWorkflowTasksCompleted

- (void)preWorkflowTasksFailedWithError:(NSError *)error {
    DDLogError(@"[ERROR] %@", [error localizedDescription]);
    [self updateWorkflowStatusErrorWithMessage:[error localizedDescription]];
} // preWorkflowTasksFailedWithError

- (void)prepareSource {
    
    // -------------------------------------------------------------
    //  Instantiate workflow target if it doesn't exist.
    // -------------------------------------------------------------
    NBCTarget *target = [_currentWorkflowItem target] ?: [[NBCTarget alloc] init];
    [target setBaseSystemDiskImageSize:[_currentWorkflowItem userSettings][NBCSettingsBaseSystemDiskImageSizeKey] ?: @10];
    [_currentWorkflowItem setTarget:target];
    
    // -------------------------------------------------------------
    //  Run workflows. Don't create NBI if source is a NBI itself.
    // -------------------------------------------------------------
    NSString *sourceType = [[_currentWorkflowItem source] sourceType];
    DDLogDebug(@"[DEBUG] Workflow source type is: %@", sourceType);
    
    if ( ! [sourceType isEqualToString:NBCSourceTypeNBI] ) {
        
        // -------------------------------------------------------------
        //  Mount source if not mounted
        // -------------------------------------------------------------
        DDLogInfo(@"Verifying source is mounted...");
        [_currentWorkflowProgressView updateProgressStatus:@"Verifying source..." workflow:self];
        [[_currentWorkflowItem source] setDelegate:self];
        [[_currentWorkflowItem source] verifySourceIsMounted];

    } else {
        NBCWorkflowUpdateNBI *workflowUpdateNBI = [[NBCWorkflowUpdateNBI alloc] initWithDelegate:_currentWorkflowProgressView];
        [_currentWorkflowItem setWorkflowNBI:workflowUpdateNBI];
        [self setCurrentWorkflowNBI:workflowUpdateNBI];
        if ( workflowUpdateNBI ) {
            [workflowUpdateNBI updateNBI:_currentWorkflowItem];
        }
    }
}

- (void)runWorkflow {
    if ( [_currentCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        NBCWorkflowNBICreator *workflowNBICreator = [[NBCWorkflowNBICreator alloc] initWithDelegate:_currentWorkflowProgressView];
        [_currentWorkflowItem setWorkflowNBI:workflowNBICreator];
        [self setCurrentWorkflowNBI:workflowNBICreator];
        if ( workflowNBICreator ) {
            [workflowNBICreator createNBI:_currentWorkflowItem];
        }
    } else if ( [_currentCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        NBCWorkflowSystemImageUtility *workflowSystemImageUtility = [[NBCWorkflowSystemImageUtility alloc] initWithDelegate:_currentWorkflowProgressView];
        [_currentWorkflowItem setWorkflowNBI:workflowSystemImageUtility];
        [self setCurrentWorkflowNBI:workflowSystemImageUtility];
        if ( workflowSystemImageUtility ) {
            [workflowSystemImageUtility createNBI:_currentWorkflowItem];
        }
    } else if ( [_currentCreationTool isEqualToString:NBCMenuItemDeployStudioAssistant] ) {
        NBCWorkflowDeployStudioAssistant *workflowDeployStudioAssistant = [[NBCWorkflowDeployStudioAssistant alloc] initWithDelegate:_currentWorkflowProgressView];
        [_currentWorkflowItem setWorkflowNBI:workflowDeployStudioAssistant];
        [self setCurrentWorkflowNBI:workflowDeployStudioAssistant];
        if ( workflowDeployStudioAssistant ) {
            [workflowDeployStudioAssistant createNBI:_currentWorkflowItem];
        }
    } else {
        [self updateWorkflowStatusErrorWithMessage:[NSString stringWithFormat:@"Unknown creation tool: %@", _currentCreationTool]];
        return;
    }
    
    NBCWorkflowResources *workflowResources = [[NBCWorkflowResources alloc] initWithDelegate:_currentWorkflowProgressView];
    [self setCurrentWorkflowResources:workflowResources];
    if ( workflowResources ) {
        [workflowResources prepareResources:_currentWorkflowItem];
    }
}

- (BOOL)createTemporaryFolderForNBI:(NSString *)nbiName error:(NSError **)error {
    
    DDLogInfo(@"Preparing workflow temporary folder...");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *temporaryFolderName = [NSString stringWithFormat:@"%@/workflow.%@", NBCBundleIdentifier, [NSString nbc_randomString]];
    DDLogDebug(@"[DEBUG] Temporary folder name: %@", temporaryFolderName);

    NSString *temporaryFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryFolderName];
    DDLogDebug(@"[DEBUG] Temporary folder path: %@", temporaryFolderPath);
    
    NSURL *temporaryFolderURL;
    if ( [temporaryFolderPath length] != 0 ) {
        temporaryFolderURL = [NSURL fileURLWithPath:temporaryFolderPath];
    } else {
        *error = [NBCError errorWithDescription:@"Temporary folder path was empty"];
        return NO;
    }
    
    if ( ! [temporaryFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogDebug(@"[DEBUG] Creating temporary folder...");
        
        if ( ! [fm createDirectoryAtURL:temporaryFolderURL withIntermediateDirectories:YES attributes:@{} error:error] ) {
            return NO;
        }
    }
    
    [_currentWorkflowItem setTemporaryFolderURL:temporaryFolderURL];
    
    NSURL *temporaryNBIURL = [temporaryFolderURL URLByAppendingPathComponent:nbiName];
    DDLogDebug(@"[DEBUG] Temporary NBI folder path: %@", [temporaryNBIURL path]);
    
    if ( ! [temporaryNBIURL checkResourceIsReachableAndReturnError:error] ) {
        DDLogDebug(@"[DEBUG] Creating temporary NBI folder...");
        
        if ( ! [fm createDirectoryAtURL:temporaryNBIURL withIntermediateDirectories:YES attributes:nil error:error] ) {
            return NO;
        }
    }
    
    [_currentWorkflowItem setTemporaryNBIURL:temporaryNBIURL];
    
    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Other Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)incrementIndexCounter {
    DDLogDebug(@"[DEBUG] Updating automatic index counter...");
    
    NSNumber *currentIndex = (NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsIndexCounter];
    DDLogDebug(@"[DEBUG] Current index: %@", [currentIndex stringValue]);
    
    if ( [currentIndex integerValue] == 65535 ) {
        currentIndex = @0;
    }
    
    NSNumber *newIndex = @([currentIndex intValue] + 1);
    DDLogDebug(@"[DEBUG] New index: %@", [newIndex stringValue]);
    
    [[NSUserDefaults standardUserDefaults] setObject:newIndex forKey:NBCUserDefaultsIndexCounter];
} // incrementIndexCounter

- (void)moveNBIToDestination:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL {
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // -------------------------------------------------------------
    //  Verify that destination has an nbi-extension
    // -------------------------------------------------------------
    NSString *destinationExtension = [destinationURL pathExtension];
    if ( ! [destinationExtension isEqualToString:@"nbi"] ) {
        [self updateWorkflowStatusErrorWithMessage:@"Destination path doesn't contain .nbi"];
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
            [self updateWorkflowStatusErrorWithMessage:@"Destination path is empty"];
            return;
        }
    }
    
    if ( [destinationURL checkResourceIsReachableAndReturnError:nil] ) {
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:self->_currentWorkflowProgressView];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                DDLogError(@"[ERROR] %@", [proxyError localizedDescription]);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
                });
            }] removeItemsAtPaths:@[ [destinationURL path] ] withReply:^(NSError *error, BOOL success) {
                if ( success ) {
                    NSError *blockError;
                    if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&blockError] ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateWorkflowStatusComplete];
                        });
                    } else {
                        DDLogError(@"[ERROR] %@", [blockError localizedDescription]);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
                        });
                    }
                } else {
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self updateWorkflowStatusErrorWithMessage:@"Removing existing NBI at destination failed"];
                    });
                }
            }];
        });
    } else {
        DDLogInfo(@"Moving NBI to destination...");
        DDLogDebug(@"[DEBUG] NBI destination path: %@", [destinationURL path]);
        if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&err] ) {
            [self updateWorkflowStatusComplete];
        } else {
            DDLogError(@"[ERROR] %@", [err localizedDescription]);
            [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
        }
    }
} // moveNBIToDestination:destinationURL

- (void)removeTemporaryFolder {
    
    NSURL *temporaryFolderURL = [_currentWorkflowItem temporaryFolderURL];
    if ( [temporaryFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:self->_currentWorkflowProgressView];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                DDLogError(@"[ERROR] %@", [proxyError localizedDescription]);
            }] removeItemsAtPaths:@[ [temporaryFolderURL path] ] withReply:^(NSError *error, BOOL success) {
                if ( ! success ) {
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                }
            }];
        });
    }
} // removeTemporaryFolder

@end
