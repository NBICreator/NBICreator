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

@interface NBCWorkflowController : NSObject

// -------------------------------------------------------------
//  Unsorted
// -------------------------------------------------------------
@property BOOL workflowRunning;

@property BOOL workflowNBIComplete;
@property BOOL workflowResourcesComplete;
@property BOOL workflowModifyNBIComplete;

@property NBCWorkflowItem *currentWorkflowItem;
@property NBCWorkflowPanelController *workflowPanel;
@property NBCWorkflowProgressViewController *currentWorkflowProgressView;

@property NSMutableArray *workflowQueue;
@property NSMutableArray *workflowViewArray;

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (void)addWorkflowItemToQueue:(NBCWorkflowItem *)workflowItem;

@end

