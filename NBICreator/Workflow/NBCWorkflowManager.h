//
//  NBCWorkflowController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressViewController.h"
#import "NBCWorkflowPanelController.h"
#import "NBCWorkflowPreWorkflowTaskController.h"

@interface NBCWorkflowManager : NSObject <NSUserNotificationCenterDelegate, NBCWorkflowPreWorkflowTaskControllerDelegate>

// -------------------------------------------------------------
//  Unsorted
// -------------------------------------------------------------
@property BOOL workflowRunning;

@property id currentWorkflowNBI;
@property BOOL currentWorkflowNBIComplete;

@property id currentWorkflowResources;
@property BOOL currentWorkflowResourcesComplete;

@property id currentWorkflowModifyNBI;
@property BOOL currentWorkflowModifyNBIComplete;

@property NSString *resourcesLastMessage;

@property NBCWorkflowItem *currentWorkflowItem;
@property NBCWorkflowPanelController *workflowPanel;
@property NBCWorkflowProgressViewController *currentWorkflowProgressView;

@property NSString *currentCreationTool;

@property NSMutableArray *workflowQueue;
@property NSMutableArray *workflowViewArray;


// -------------------------------------------------------------
//  Class Methods
// -------------------------------------------------------------
+ (id)sharedManager;

// -------------------------------------------------------------
//  Instance Methods
// -------------------------------------------------------------
- (void)addWorkflowItemToQueue:(NBCWorkflowItem *)workflowItem;
- (void)menuItemWindowWorkflows:(id)sender;

@end

