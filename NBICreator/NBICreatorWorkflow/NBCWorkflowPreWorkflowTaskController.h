//
//  NBCWorkflowPreWorkflowTasks.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-21.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressViewController.h"

@protocol NBCWorkflowPreWorkflowTaskControllerDelegate
@optional
- (void)preWorkflowTasksCompleted;
@end

@interface NBCWorkflowPreWorkflowTaskController : NSObject {
    id _delegate;
}

@property id progressDelegate;

- (id)initWithDelegate:(id<NBCWorkflowPreWorkflowTaskControllerDelegate>)delegate;
- (void)runPreWorkflowTasks:(NSDictionary *)preWorkflowTasks workflowItem:(NBCWorkflowItem *)workflowItem;

@end
