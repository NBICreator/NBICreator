//
//  NBCWorkflowItem.h
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <Foundation/Foundation.h>

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCApplicationSourceDeployStudio.h"
#import "NBCApplicationSourceSystemImageUtility.h"

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

@property (readwrite) NSData *authData;

@property NSDictionary *preWorkflowTasks;
@property NSDictionary *postWorkflowTasks;

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
@property BOOL userSettingsChangedRequiresBaseSystem;
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
