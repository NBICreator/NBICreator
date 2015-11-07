//
//  NBCWorkflowDeployStudioAssistant.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-06.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
@class NBCWorkflowItem;

@interface NBCWorkflowDeployStudioAssistant : NSObject

@property NBCWorkflowItem *workflowItem;
@property (nonatomic, weak) id delegate;

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate;
- (void)createNBI:(NBCWorkflowItem *)workflowItem;

@end
