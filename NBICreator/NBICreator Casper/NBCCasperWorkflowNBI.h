//
//  NBCCasperWorkflowNBI.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCMessageDelegate.h"
#import "NBCWorkflowItem.h"

@protocol NBCCasperWorkflowNBIDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
@end

@interface NBCCasperWorkflowNBI : NSObject

@property (nonatomic, weak) id delegate;
@property (weak) id<NBCMessageDelegate> messageDelegate;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property NSString *nbiVolumeName;
@property NSURL *temporaryNBIURL;
@property NSString *temporaryNBIBaseSystemPath;
@property double temporaryNBIBaseSystemSize;
@property NSString *diskVolumePath;
@property double netInstallVolumeSize;
@property BOOL copyComplete;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;

@end
