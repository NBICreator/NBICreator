//
//  NBCWorkflowImagrModifyNBI.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCInstallerPackageController.h"
#import "NBCMessageDelegate.h"
@class NBCSource;
@class NBCTarget;
@class NBCTargetController;
@class NBCWorkflowItem;
@class NBCWorkflowProgressViewController;

@interface NBCImagrWorkflowModifyNBI : NSObject <NBCInstallerPackageDelegate, NBCMessageDelegate>

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
@property NBCWorkflowProgressViewController *progressView;
@property NBCWorkflowItem *workflowItem;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;
- (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target; // Move to "controller?"

@end
