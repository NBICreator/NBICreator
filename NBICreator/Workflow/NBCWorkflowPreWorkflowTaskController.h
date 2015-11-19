//
//  NBCWorkflowPreWorkflowTasks.h
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
@class NBCWorkflowItem;
#import "NBCWorkflowProgressViewController.h"

@protocol NBCWorkflowPreWorkflowTaskControllerDelegate
- (void)preWorkflowTasksCompleted;
- (void)preWorkflowTasksFailedWithError:(NSError *)error;
@end

@interface NBCWorkflowPreWorkflowTaskController : NSObject {
    id _delegate;
}

@property (nonatomic, weak) id progressDelegate;

- (id)initWithDelegate:(id<NBCWorkflowPreWorkflowTaskControllerDelegate>)delegate;
- (void)runPreWorkflowTasks:(NSDictionary *)preWorkflowTasks workflowItem:(NBCWorkflowItem *)workflowItem;

@end
