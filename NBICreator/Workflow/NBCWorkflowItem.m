//
//  NBCWorkflowItem.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressViewController.h"

@implementation NBCWorkflowItem

- (id)initWithWorkflowType:(int)workflowType workflowSessionType:(int)workflowSessionType{
    self = [super init];
    if (self) {
        _workflowType = workflowType;
        _workflowSessionType = workflowSessionType;
    }
    return self;
}

@end
