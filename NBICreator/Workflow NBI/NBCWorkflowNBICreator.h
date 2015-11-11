//
//  NBCWorkflowNBICreator.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
@class NBCWorkflowItem;

@interface NBCWorkflowNBICreator : NSObject
@property NBCWorkflowItem *workflowItem;
@property (nonatomic, weak) id delegate;
@property double temporaryNBIBaseSystemSize;
@property BOOL copyComplete;
@property NSString *temporaryNBIBaseSystemPath;

// Methods

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate;
- (void)createNBI:(NBCWorkflowItem *)workflowItem;

@end
