//
//  NBCNetInstallWorkflowResources.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCWorkflowResourcesController.h"
#import "NBCDownloader.h"
#import "NBCWorkflowItem.h"
#import "NBCTarget.h"

@interface NBCNetInstallWorkflowResources : NSObject

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCTarget *target;
@property NBCWorkflowResourcesController *resourcesController;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property int resourcesCount;

@property NSMutableDictionary *resourcesNetInstallDict;
@property NSMutableDictionary *resourcesBaseSystemDict;

@property NSMutableArray *resourcesNetInstallCopy;
@property NSMutableArray *resourcesBaseSystemCopy;
@property NSMutableArray *resourcesNetInstallInstall;
@property NSMutableArray *resourcesBaseSystemInstall;

@property NSURL *resourcesFolder;
@property NSURL *resourcesDictURL;

@property NSDictionary *userSettings;
@property NSDictionary *resourcesSettings;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;

@end
