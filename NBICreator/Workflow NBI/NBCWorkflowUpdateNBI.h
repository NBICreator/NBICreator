//
//  NBCWorkflowNBI.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-11.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
@class NBCWorkflowItem;
@class NBCTarget;

@interface NBCWorkflowUpdateNBI : NSObject

@property NBCWorkflowItem *workflowItem;
@property NBCTarget *target;
@property (nonatomic, weak) id delegate;

// Methods
- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate;
- (void)updateNBI:(NBCWorkflowItem *)workflowItem;

@end
