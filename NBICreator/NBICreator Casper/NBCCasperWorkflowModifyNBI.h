//
//  NBCCasperWorkflowModifyNBI.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCInstallerPackageController.h"
#import "NBCMessageDelegate.h"
@class NBCSource;
@class NBCTarget;
@class NBCTargetController;
@class NBCWorkflowItem;

@protocol NBCCasperWorkflowModifyNBIDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
@end

@interface NBCCasperWorkflowModifyNBI : NSObject <NBCInstallerPackageDelegate, NBCMessageDelegate>

@property (nonatomic, weak) id delegate;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property BOOL modifyNetInstallComplete;
@property BOOL modifyBaseSystemComplete;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCTarget *target;
@property NBCTargetController *targetController;
@property NBCWorkflowItem *workflowItem;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;
- (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target; // Move to "controller?"

@end

