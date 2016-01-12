//
//  NBCWorkflowPostWorkflowTaskController.h
//  NBICreator
//
//  Created by Erik Berglund on 2016-01-11.
//  Copyright © 2016 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCWorkflowItem;
#import "NBCWorkflowProgressViewController.h"

@protocol NBCWorkflowPostWorkflowTaskControllerDelegate
- (void)postWorkflowTasksCompleted;
- (void)postWorkflowTasksFailedWithError:(NSError *)error;
@end

@interface NBCWorkflowPostWorkflowTaskController : NSObject {
    id _delegate;
}

@property (nonatomic, weak) id progressDelegate;

- (id)initWithDelegate:(id<NBCWorkflowPostWorkflowTaskControllerDelegate>)delegate;
- (void)runPostWorkflowTasks:(NSDictionary *)postWorkflowTasks workflowItem:(NBCWorkflowItem *)workflowItem;

@end
