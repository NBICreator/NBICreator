//
//  NBCDeployStudioWorkflowModifyNBI.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NBCTargetController;
@class NBCWorkflowItem;
@class NBCWorkflowProgressViewController;

@protocol NBCDeployStudioWorkflowModifyNBIDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
@end

@interface NBCDeployStudioWorkflowModifyNBI : NSObject

@property id delegate;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCTargetController *targetController;
@property NBCWorkflowProgressViewController *progressView;
@property NBCWorkflowItem *workflowItem;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;

@end
