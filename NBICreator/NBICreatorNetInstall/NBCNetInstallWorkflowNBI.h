//
//  NBCWorkflowNetInstall.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCWorkflowItem.h"
//#import "NBCWorkflowProgressViewController.h"

@protocol NBCNetInstallWorkflowNBIDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
@end

@interface NBCNetInstallWorkflowNBI : NSObject

@property (nonatomic, weak) id delegate;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
//@property NBCWorkflowProgressViewController *progressView;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property NSString *nbiVolumeName;
@property NSString *temporaryNBIPath;
@property NSString *diskVolumePath;
@property double netInstallVolumeSize;
@property BOOL copyComplete;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;

@end
