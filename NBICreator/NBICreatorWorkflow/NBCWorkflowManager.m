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
#import "NBCTargetController.h"
#import "NBCDiskImageController.h"
#import "NBCError.h"

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
    if ( ! [[[_currentWorkflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        [self moveNBIToDestination:[_currentWorkflowItem temporaryNBIURL] destinationURL:[_currentWorkflowItem nbiURL]];
    } else {
        [self updateWorkflowStatusComplete];
    }
} // workflowCompleteModifyNBI

- (void)endWorkflow {

    NSString *name = [_currentWorkflowItem nbiName];
    NSString *workflowTime = [_currentWorkflowItem workflowTime];
    
    DDLogInfo(@"*** Workflow: %@ completed in %@ ***", name, workflowTime);
    
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:NBCUserDefaultsUserNotificationsEnabled] ) {
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
    
    NSString *name = [_currentWorkflowItem nbiName];
    
    DDLogError(@"*** Workflow: %@ failed ***", name);

    NSError *error = [notification userInfo][NBCUserInfoNSErrorKey];
    NSString *progressViewErrorMessage = nil;
    if ( error ) {
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
    [_currentWorkflowProgressView workflowFailedWithError:errorMessage ?: @"Unknown Error (-1)"];
    [self endWorkflow];
} // updateWorkflowStatusErrorWithMessage

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)workflowQueueRunWorkflow {
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
            DDLogError(@"[ERROR] NBI name cannot be empty!");
            [self updateWorkflowStatusErrorWithMessage:@"NBI name cannot be empty!"];
            return;
        }
        [_currentWorkflowItem setStartTime:[NSDate date]];
        
        // -------------------------------------------------------------
        //  Get progress view from current workflow item
        // -------------------------------------------------------------
        [self setCurrentWorkflowProgressView:[_currentWorkflowItem progressView]];
        [_currentWorkflowProgressView workflowStartedForItem:_currentWorkflowItem];
        
        // -------------------------------------------------------------
        //  Create a path to a unique temporary folder
        // -------------------------------------------------------------
        if ( ! [self createTemporaryFolderForNBI:nbiName] ) {
            DDLogError(@"[ERROR] Creating temporary folder failed!");
            return;
        }
        
        NSDictionary *preWorkflowTasks = [_currentWorkflowItem preWorkflowTasks];
        if ( [preWorkflowTasks count] != 0 ) {
            NBCWorkflowPreWorkflowTaskController *preWorkflowTaskController = [[NBCWorkflowPreWorkflowTaskController alloc] initWithDelegate:self];
            [preWorkflowTaskController setProgressDelegate:_currentWorkflowProgressView];
            [preWorkflowTaskController runPreWorkflowTasks:preWorkflowTasks workflowItem:_currentWorkflowItem];
        } else {
            [self runWorkflows];
        }
    }
} // workflowQueueRunWorkflow

- (void)preWorkflowTasksCompleted {
    [self runWorkflows];
}

- (void)runWorkflows {
    
    // -------------------------------------------------------------
    //  Instantiate workflow target if it doesn't exist.
    // -------------------------------------------------------------
    NBCTarget *target = [_currentWorkflowItem target] ?: [[NBCTarget alloc] init];
    [_currentWorkflowItem setTarget:target];
    
    // -------------------------------------------------------------
    //  Run workflows. Don't create NBI if source is a NBI itself.
    // -------------------------------------------------------------
    NSString *sourceType = [[_currentWorkflowItem source] sourceType];
    DDLogDebug(@"[DEBUG] Workflow source type is: %@", sourceType);
    if ( ! [sourceType isEqualToString:NBCSourceTypeNBI] ) {
        [self runWorkflow];
    } else {
        [self runWorkflowNBISource:target];
    }
}

- (void)runWorkflow {
    // -------------------------------------------------------------
    //  Mount source if not mounted
    // -------------------------------------------------------------
    if ( ! [self mountSource] ) {
        DDLogError(@"[ERROR] Could not mount source disk!");
        [self updateWorkflowStatusErrorWithMessage:@"Could not mount source disk"];
        return;
    }
    
    [self setCurrentWorkflowNBI:[_currentWorkflowItem workflowNBI]];
    if ( _currentWorkflowNBI ) {
        [_currentWorkflowNBI setDelegate:_currentWorkflowProgressView];
        [_currentWorkflowNBI runWorkflow:_currentWorkflowItem];
    }
    
    [self setCurrentWorkflowResources:[_currentWorkflowItem workflowResources]];
    if ( _currentWorkflowResources ) {
        [_currentWorkflowResources setDelegate:_currentWorkflowProgressView];
        [_currentWorkflowResources runWorkflow:_currentWorkflowItem];
    }
}

- (void)prepareNBICreatorNBI:(NBCTarget *)target {
    NBCTargetController *targetController = [[NBCTargetController alloc] init];
    
    [_currentWorkflowItem setUserSettingsChangedRequiresBaseSystem:YES];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *error;
        if ( [targetController attachBaseSystemDiskImageWithShadowFile:[target baseSystemURL] target:target error:&error] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                
                [self setCurrentWorkflowResources:[self->_currentWorkflowItem workflowResources]];
                if ( self->_currentWorkflowResources ) {
                    [self->_currentWorkflowResources setDelegate:self->_currentWorkflowProgressView];
                    [self->_currentWorkflowResources runWorkflow:self->_currentWorkflowItem];
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                DDLogError(@"[ERROR] Attaching BaseSystem disk image failed!");
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
                [self updateWorkflowStatusErrorWithMessage:@"Attaching BaseSystem disk image failed"];
            });
        }
    });
}

- (void)prepareSystemImageUtilityNBI:(NBCTarget *)target {
    __block NSError *error;
    NBCTargetController *targetController = [[NBCTargetController alloc] init];
    DDLogDebug(@"[DEBUG] Workflow creation tool is: %@", NBCMenuItemSystemImageUtility);
    
    if ( [[target nbiNetInstallDisk] isWritable] ) {
        DDLogDebug(@"[DEBUG] NetInstall disk image is writeable");
        
        if ( ! [[target nbiNetInstallDisk] isMounted] ) {
            DDLogDebug(@"[DEBUG] NetInstall disk image is NOT mounted");
            
            dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
            dispatch_async(taskQueue, ^{
                
                NSDictionary *netInstallDiskImageDict;
                NSArray *hdiutilOptions = @[
                                            @"-mountRandom", @"/Volumes",
                                            @"-nobrowse",
                                            @"-noverify",
                                            @"-plist",
                                            ];
                
                if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&netInstallDiskImageDict
                                                                          dmgPath:[target nbiNetInstallURL]
                                                                          options:hdiutilOptions
                                                                            error:&error] ) {
                    
                    if ( netInstallDiskImageDict ) {
                        [target setNbiNetInstallDiskImageDict:netInstallDiskImageDict];
                        
                        NSURL *netInstallVolumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:netInstallDiskImageDict];
                        if ( [netInstallVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
                            
                            NBCDisk *netInstallDisk = [NBCDiskImageController checkDiskImageAlreadyMounted:[target nbiNetInstallURL]
                                                                                                 imageType:@"InstallESD"];
                            if ( netInstallDisk ) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    DDLogDebug(@"[DEBUG] NetInstall disk image volume mounted!");
                                    [target setNbiNetInstallDisk:netInstallDisk];
                                    DDLogDebug(@"[DEBUG] NetInstall disk image volume bsd identifier: %@", [netInstallDisk BSDName]);
                                    [target setNbiNetInstallVolumeBSDIdentifier:[netInstallDisk BSDName]];
                                    DDLogDebug(@"[DEBUG] NetInstall disk image volume path: %@", [netInstallVolumeURL path]);
                                    [target setNbiNetInstallVolumeURL:netInstallVolumeURL];
                                    [netInstallDisk setIsMountedByNBICreator:YES];
                                    [self prepareSystemImageUtilityNBIBaseSystem:target];
                                });
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    DDLogError(@"[ERROR] Found no disk object matching disk image volume url");
                                    [self updateWorkflowStatusErrorWithMessage:@"Found no disk object matching disk image volume url"];
                                    return;
                                });
                            }
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                DDLogError(@"[ERROR] NetInstall disk image volume url doesn't exist");
                                DDLogError(@"[ERROR] %@", [error localizedDescription] );
                                [self updateWorkflowStatusErrorWithMessage:[error localizedDescription]];
                                return;
                            });
                        }
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            DDLogError(@"[ERROR] Information dictionary returned from hdiutil was empty");
                            [self updateWorkflowStatusErrorWithMessage:@"Information dictionary returned from hdiutil was empty"];
                            return;
                        });
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DDLogError(@"[ERROR] Attaching NetInstall disk image failed");
                        [self updateWorkflowStatusErrorWithMessage:@"Attaching NetInstall disk image failed"];
                        return;
                    });
                }
            });
        }
    } else {
        DDLogDebug(@"[DEBUG] NetInstall disk image is NOT writeable");
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            
            if ( [[target nbiNetInstallDisk] isMounted] ) {
                DDLogDebug(@"[DEBUG] NetInstall disk image IS mounted");
                
                DDLogDebug(@"[DEBUG] Detaching NetInstall disk image...");
                if ( ! [NBCDiskImageController detachDiskImageAtPath:[[target nbiNetInstallVolumeURL] path]] ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DDLogError(@"[ERROR] Detaching NetInstall disk image failed!");
                        [self updateWorkflowStatusErrorWithMessage:@"Detaching NetInstall disk image failed"];
                        return;
                    });
                }
            }
            
            if ( [targetController attachNetInstallDiskImageWithShadowFile:[target nbiNetInstallURL] target:target error:&error] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self prepareSystemImageUtilityNBIBaseSystem:target];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogError(@"[ERROR] Attaching NetInstall disk image failed!");
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                    [self updateWorkflowStatusErrorWithMessage:@"Attaching NetInstall disk image failed"];
                    return;
                });
            }
        });
    }
}

- (void)prepareSystemImageUtilityNBIBaseSystem:(NBCTarget *)target {
    NBCTargetController *targetController = [[NBCTargetController alloc] init];
    NSDictionary *settingsChanged = [_currentWorkflowItem userSettingsChanged];
    if (
        [settingsChanged[NBCSettingsARDLoginKey] boolValue] ||
        [settingsChanged[NBCSettingsARDPasswordKey] boolValue] ||
        [settingsChanged[NBCSettingsAddCustomRAMDisksKey] boolValue] ||
        [settingsChanged[NBCSettingsRAMDisksKey] boolValue] ||
        [settingsChanged[NBCSettingsDisableBluetoothKey] boolValue] ||
        [settingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
        [settingsChanged[NBCSettingsIncludeConsoleAppKey] boolValue] ||
        [settingsChanged[NBCSettingsIncludeRubyKey] boolValue] ||
        [settingsChanged[NBCSettingsIncludeSystemUIServerKey] boolValue] ||
        [settingsChanged[NBCSettingsKeyboardLayoutID] boolValue] ||
        [settingsChanged[NBCSettingsLanguageKey] boolValue] ||
        [settingsChanged[NBCSettingsUseNetworkTimeServerKey] boolValue] ||
        [settingsChanged[NBCSettingsNetworkTimeServerKey] boolValue] ||
        [settingsChanged[NBCSettingsTimeZoneKey] boolValue]
        ) {
        
        DDLogDebug(@"[DEBUG] At least one setting that require BaseSystem was changed");
        [_currentWorkflowItem setUserSettingsChangedRequiresBaseSystem:YES];
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            
            NSError *error;
            if ( [targetController attachBaseSystemDiskImageWithShadowFile:[target baseSystemURL] target:target error:&error] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
                    
                    [self setCurrentWorkflowResources:[self->_currentWorkflowItem workflowResources]];
                    if ( self->_currentWorkflowResources ) {
                        [self->_currentWorkflowResources setDelegate:self->_currentWorkflowProgressView];
                        [self->_currentWorkflowResources runWorkflow:self->_currentWorkflowItem];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogError(@"[ERROR] Attaching BaseSystem disk image failed!");
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                    [self updateWorkflowStatusErrorWithMessage:@"Attaching BaseSystem disk image failed"];
                });
            }
        });
    } else {
        DDLogDebug(@"[DEBUG] No settings that require BaseSystem were changed");
        [_currentWorkflowItem setUserSettingsChangedRequiresBaseSystem:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
        
        [self setCurrentWorkflowResources:[_currentWorkflowItem workflowResources]];
        if ( _currentWorkflowResources ) {
            [_currentWorkflowResources setDelegate:_currentWorkflowProgressView];
            [_currentWorkflowResources runWorkflow:_currentWorkflowItem];
        }
    }
}

- (BOOL)onlyChangeNBImageInfo:(NSError **)error {
    
    NSDictionary *settingsChanged = [_currentWorkflowItem userSettingsChanged];
    NSMutableArray *keysChanged = [[settingsChanged allKeysForObject:@YES] mutableCopy];
    NSMutableArray *keysNBImageInfo = [[NSMutableArray alloc] init];
    NSMutableArray *keysBootPlist = [[NSMutableArray alloc] init];
    for ( NSString *key in [keysChanged copy] ) {
        if (
            [key isEqualToString:NBCSettingsProtocolKey] ||
            [key isEqualToString:NBCSettingsIndexKey] ||
            [key isEqualToString:NBCSettingsEnabledKey] ||
            [key isEqualToString:NBCSettingsDefaultKey] ||
            [key isEqualToString:NBCSettingsDescriptionKey]
            ) {
            [keysNBImageInfo addObject:key];
            [keysChanged removeObject:key];
        } else if ( [key isEqualToString:NBCSettingsUseVerboseBootKey] ) {
            [keysBootPlist addObject:key];
            [keysChanged removeObject:key];
        }
    }
    
    if ( [keysChanged count] == 0 ) {
        DDLogInfo(@"Only settings in the NBI folder changed...");
        NSDictionary *userSettings = [_currentWorkflowItem userSettings];
        
        if ( [keysNBImageInfo count] != 0 ) {
            DDLogInfo(@"Updating NBImageInfo.plist...");
            
            NSURL *nbImageInfoURL = [[_currentWorkflowItem source] nbImageInfoURL];
            DDLogDebug(@"[DEBUG] NBImageInfo.plist path: %@", [nbImageInfoURL path]);
            
            if ( [nbImageInfoURL checkResourceIsReachableAndReturnError:error] ) {
                DDLogDebug(@"[DEBUG] NBImageInfo.plist exists!");
                
                NSMutableDictionary *nbImageInfoDict = [NSMutableDictionary dictionaryWithContentsOfURL:nbImageInfoURL];
                if ( [nbImageInfoDict count] != 0 ) {
                    
                    NSString *nbImageInfoKey;
                    for ( NSString *key in keysNBImageInfo ) {
                        if ( [key isEqualToString:NBCSettingsProtocolKey] ) {
                            nbImageInfoKey = NBCNBImageInfoDictProtocolKey;
                        } else if ( [key isEqualToString:NBCSettingsIndexKey] ) {
                            nbImageInfoKey = NBCNBImageInfoDictIndexKey;
                        } else if ( [key isEqualToString:NBCSettingsEnabledKey] ) {
                            nbImageInfoKey = NBCNBImageInfoDictIsEnabledKey;
                        } else if ( [key isEqualToString:NBCSettingsDefaultKey] ) {
                            nbImageInfoKey = NBCNBImageInfoDictIsDefaultKey;
                        } else if ( [key isEqualToString:NBCSettingsDescriptionKey] ) {
                            nbImageInfoKey = NBCNBImageInfoDictDescriptionKey;
                        }
                        
                        DDLogDebug(@"[DEBUG] Changing key: %@", nbImageInfoKey);
                        DDLogDebug(@"[DEBUG] Original value: %@", nbImageInfoDict[nbImageInfoKey]);
                        DDLogDebug(@"[DEBUG] New value: %@", userSettings[key]);
                        if ( [key isEqualToString:NBCSettingsIndexKey] ) {
                            nbImageInfoDict[nbImageInfoKey] = @( [userSettings[key] integerValue] );
                        } else {
                            nbImageInfoDict[nbImageInfoKey] = userSettings[key];
                        }
                    }
                    
                    DDLogDebug(@"[DEBUG] Writing updated NBImageInfo.plist...");
                    if ( ! [nbImageInfoDict writeToURL:nbImageInfoURL atomically:YES] ) {
                        *error = [NBCError errorWithDescription:@"Writing updated NBImageInfo.plist failed"];
                        return YES;
                    }
                } else {
                    *error = [NBCError errorWithDescription:@"NBImageInfo.plist was empty"];
                    return YES;
                }
            } else {
                return YES;
            }
        }
        
        if ( [keysBootPlist count] != 0 ) {
            DDLogInfo(@"Updating com.apple.Boot.plist...");
            
            NSURL *bootPlistURL = [[_currentWorkflowItem nbiURL] URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
            DDLogDebug(@"[DEBUG] com.apple.Boot.plist path: %@", [bootPlistURL path]);
            
            NSMutableDictionary *bootPlistDict;
            if ( [bootPlistURL checkResourceIsReachableAndReturnError:nil] ) {
                DDLogDebug(@"[DEBUG] com.apple.Boot.plist exists!");
                
                bootPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:bootPlistURL];
                if ( ! bootPlistDict ) {
                    bootPlistDict = [[NSMutableDictionary alloc] init];
                }
            } else {
                bootPlistDict = [[NSMutableDictionary alloc] init];
            }
            
            if ( [userSettings[NBCSettingsUseVerboseBootKey] boolValue] ) {
                DDLogDebug(@"[DEBUG] Adding \"-v\" to \"Kernel Flags\"");
                if ( [bootPlistDict[@"Kernel Flags"] length] != 0 ) {
                    NSString *currentKernelFlags = bootPlistDict[@"Kernel Flags"];
                    bootPlistDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ -v", currentKernelFlags];
                } else {
                    bootPlistDict[@"Kernel Flags"] = @"-v";
                }
            } else {
                DDLogDebug(@"[DEBUG] Removing \"-v\" from \"Kernel Flags\"");
                if ( [bootPlistDict[@"Kernel Flags"] length] != 0 ) {
                    NSString *currentKernelFlags = bootPlistDict[@"Kernel Flags"];
                    bootPlistDict[@"Kernel Flags"] = [currentKernelFlags stringByReplacingOccurrencesOfString:@"-v" withString:@""];
                } else {
                    bootPlistDict[@"Kernel Flags"] = @"";
                }
            }
            
            if ( ! [bootPlistDict writeToURL:bootPlistURL atomically:YES] ) {
                *error = [NBCError errorWithDescription:@"Writing updated com.apple.Boot.plist failed"];
                return YES;
            }
        }
        return YES;
    } else {
        return NO;
    }
}

- (void)runWorkflowNBISource:(NBCTarget *)target {
    
    NSError *error = nil;
    
    // If only changes outside disk images are made, do those directly
    if ( [self onlyChangeNBImageInfo:&error] ) {
        if ( ! error ) {
            [self updateWorkflowStatusComplete];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Updating files in NBI folder failed"] }];
        }
        return;
    }
    
    if ( [[target baseSystemDisk] isMounted] ) {
        DDLogDebug(@"[DEBUG] BaseSystem disk image IS mounted");
        DDLogDebug(@"[DEBUG] Detaching BaseSystem disk image...");
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            
            if ( [NBCDiskImageController detachDiskImageAtPath:[[target baseSystemVolumeURL] path]] ) {
                if ( [[self->_currentWorkflowItem userSettings][NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self prepareSystemImageUtilityNBI:target];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self prepareNBICreatorNBI:target];
                    });
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    DDLogError(@"[ERROR] Detaching BaseSystem disk image failed!");
                    [self updateWorkflowStatusErrorWithMessage:@"Detaching BaseSystem disk image failed"];
                    return;
                });
            }
        });
    } else {
        if ( [[_currentWorkflowItem userSettings][NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
            [self prepareSystemImageUtilityNBI:target];
        } else {
            [self prepareNBICreatorNBI:target];
        }
    }
}

- (void)workflowQueueRunWorkflowPostprocessing {
    [self setCurrentWorkflowModifyNBI:[_currentWorkflowItem workflowModifyNBI]];
    if ( _currentWorkflowModifyNBI ) {
        [_currentWorkflowModifyNBI setDelegate:_currentWorkflowProgressView];
        [_currentWorkflowModifyNBI runWorkflow:_currentWorkflowItem];
    } else {
        DDLogError(@"[ERROR] workflowModifyNBI is nil");
        [self updateWorkflowStatusErrorWithMessage:@"Workflow ModifyNBI is nil"];
    }
} // workflowQueueRunWorkflowPostprocessing

- (BOOL)createTemporaryFolderForNBI:(NSString *)nbiName {
    NSError *error = nil;
    DDLogDebug(@"[DEBUG] Preparing workflow temporary folder...");
    NSURL *temporaryFolderURL = [self temporaryFolderURL];
    DDLogDebug(@"[DEBUG] Temporary folder path: %@", [temporaryFolderURL path]);
    if ( temporaryFolderURL ) {
        [_currentWorkflowItem setTemporaryFolderURL:temporaryFolderURL];
        
        NSURL *temporaryNBIURL = [temporaryFolderURL URLByAppendingPathComponent:nbiName];
        DDLogDebug(@"[DEBUG] Temporary NBI path: %@", [temporaryNBIURL path]);
        if ( temporaryNBIURL ) {
            [_currentWorkflowItem setTemporaryNBIURL:temporaryNBIURL];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            DDLogDebug(@"[DEBUG] Creating temporary NBI folder...");
            if ( ! [fileManager createDirectoryAtURL:temporaryNBIURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                DDLogError(@"[ERROR] Creating temporary NBI folder failed!");
                DDLogError(@"[ERROR] %@", error);
                [self updateWorkflowStatusErrorWithMessage:@"Creating temporary NBI folder failed"];
                return NO;
            }
        } else {
            DDLogError(@"[ERROR] Temporary NBI path cannot be empty!");
            [self updateWorkflowStatusErrorWithMessage:@"Temporary NBI path cannot be empty"];
            return NO;
        }
    } else {
        DDLogError(@"[ERROR] Temporary folder path cannot be empty!");
        [self updateWorkflowStatusErrorWithMessage:@"Temporary folder path cannot be empty"];
        return NO;
    }
    
    return YES;
}

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
            if ( ! [[_currentWorkflowItem userSettings][NBCSettingsNetInstallPackageOnlyKey] boolValue] ) {
                retval = [sc verifySourceIsMountedInstallESD:[_currentWorkflowItem source]];
            }
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
    NSNumber *currentIndex = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsIndexCounter];
    if ( [currentIndex integerValue] == 65535 ) {
        currentIndex = @0;
    }
    NSNumber *newIndex = @([currentIndex intValue] + 1);
    [[NSUserDefaults standardUserDefaults] setObject:newIndex forKey:NBCUserDefaultsIndexCounter];
    DDLogDebug(@"[DEBUG] Updated NBI Index counter from %@ to %@", currentIndex, newIndex);
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
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ----------------------------------------------------
                //  If task failed, post workflow failed notification
                // ----------------------------------------------------
                DDLogError(@"[ERROR] %@", proxyError);
                [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
            }];
            
        }] removeItemAtURL:destinationURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus == 0 ) {
                    NSError *blockError;
                    if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&blockError] ) {
                        [self updateWorkflowStatusComplete];
                    } else {
                        DDLogError(@"[ERROR] Moving NBI to destination failed!");
                        DDLogError(@"[ERROR] %@", blockError);
                        [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
                    }
                } else {
                    DDLogError(@"[ERROR] Deleting existing NBI at destination failed");
                    DDLogError(@"[ERROR] %@", error);
                    [self updateWorkflowStatusErrorWithMessage:@"Removing existing NBI at destination failed"];
                }
            }];
        }];
    } else {
        if ( [fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&err] ) {
            DDLogInfo(@"Moving NBI to destination successful!");
            [self updateWorkflowStatusComplete];
        } else {
            DDLogError(@"[ERROR] Moving NBI to destination failed!");
            DDLogError(@"[ERROR] %@", err);
            [self updateWorkflowStatusErrorWithMessage:@"Moving NBI to destination failed"];
        }
    }
} // moveNBIToDestination:destinationURL

- (NSURL *)temporaryFolderURL {
    NSURL *temporaryFolderURL;
    NSString *tmpFolderName = [NSString stringWithFormat:@"%@/workflow.%@", NBCBundleIdentifier, [NSString nbc_randomString]];
    NSString *tmpFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpFolderName];
    
    if ( [tmpFolderPath length] != 0 ) {
        temporaryFolderURL = [NSURL fileURLWithPath:tmpFolderPath];
    }
    
    return temporaryFolderURL;
} // temporaryFolderURL

@end
