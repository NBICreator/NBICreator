//
//  NBCWorkflowController.h
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

#import <Foundation/Foundation.h>
#import "NBCSource.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressViewController.h"
#import "NBCWorkflowPanelController.h"
#import "NBCWorkflowPreWorkflowTaskController.h"
#import "NBCWorkflowPostWorkflowTaskController.h"

@interface NBCWorkflowManager : NSObject <NSUserNotificationCenterDelegate, NBCWorkflowPreWorkflowTaskControllerDelegate, NBCWorkflowPostWorkflowTaskControllerDelegate, NBCSourceMountDelegate>

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

