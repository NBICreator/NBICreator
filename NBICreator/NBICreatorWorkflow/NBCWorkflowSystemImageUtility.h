//
//  NBCWorkflowSystemImageUtility.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-06.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
@class NBCWorkflowItem;

@interface NBCWorkflowSystemImageUtility : NSObject <NBCWorkflowProgressDelegate>

@property NBCWorkflowItem *workflowItem;
@property (nonatomic, weak) id delegate;
@property double netInstallVolumeSize;

@property BOOL packageOnly;
@property BOOL packageOnlyScriptRun;

@property BOOL copyComplete;

@property NSString *nbiVolumeName;
@property NSString *nbiVolumePath;
@property NSURL *temporaryNBIURL;

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate;
- (void)createNBI:(NBCWorkflowItem *)workflowItem;

@end
