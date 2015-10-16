//
//  NBCWorkflowItem.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCDeployStudioSource.h"
#import "NBCSystemImageUtilitySource.h"

@class NBCWorkflowProgressViewController;

enum {
    kWorkflowTypeDeployStudio = 0,
    kWorkflowTypeNetInstall,
    kWorkflowTypeImagr,
    kWorkflowTypeCasper
};

enum {
    kWorkflowSessionTypeGUI = 0,
    kWorkflowSessionTypeCLI
};

@interface NBCWorkflowItem : NSObject

// -------------------------------------------------------------
//  Unsorted
// -------------------------------------------------------------
@property id settingsViewController;
@property id workflowNBI;
@property id workflowResources;
@property id workflowModifyNBI;
@property id applicationSource;
@property int workflowType;

@property int workflowSessionType;

@property NSImage *nbiIcon;
@property NSURL *nbiIconURL;

@property NSURL *temporaryFolderURL;
@property NSURL *temporaryNBIURL;

@property NSString *destinationFolder;
@property NSString *nbiName;
@property NSNumber *nbiIndex;
@property NSURL *nbiURL;
@property NSArray *scriptArguments;
@property NSDictionary *scriptEnvironmentVariables;

// -------------------------------------------------------------
//  Class instance properties
// -------------------------------------------------------------
@property NBCSource *source;
@property NBCTarget *target;
@property NBCWorkflowProgressViewController *progressView;

// -------------------------------------------------------------
//  Workflow status
// -------------------------------------------------------------
@property BOOL isRunning;
@property BOOL hasCompleted;
@property NSDate *startTime;
@property NSDate *endTime;
@property NSString *workflowTime;

// -------------------------------------------------------------
//  Convenience porperties for user settings
// -------------------------------------------------------------
@property NSDictionary *userSettings;
@property NSDictionary *userSettingsChanged;
@property NSDictionary *resourcesSettings;

// -------------------------------------------------------------
//  Arrays with items to be deleted at end of each workflow
// -------------------------------------------------------------
@property NSArray *temporaryItemsNBI;
@property NSArray *temporaryItemsResources;
@property NSArray *temporaryItemsModifyNBI;

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithWorkflowType:(int)workflowType workflowSessionType:(int)workflowSessionType;

@end
