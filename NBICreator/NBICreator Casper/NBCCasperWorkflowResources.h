//
//  NBCCasperWorkflowResources.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCWorkflowResourcesController.h"
#import "NBCDownloader.h"
#import "NBCWorkflowItem.h"
#import "NBCTarget.h"
#import "NBCSourceController.h"

@protocol NBCCasperWorkflowResourcesDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
@end

@interface NBCCasperWorkflowResources : NSObject <NBCDownloaderDelegate, NBCResourcesControllerDelegate, NBCSourceControllerDelegate>

@property (nonatomic, weak) id delegate;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCTarget *target;
@property NBCWorkflowResourcesController *resourcesController;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property int resourcesCount;
@property NSString *nbiCreationTool;

@property NSMutableDictionary *resourcesNetInstallDict;
@property NSMutableDictionary *resourcesBaseSystemDict;

@property NSMutableArray *resourcesNetInstallCopy;
@property NSMutableArray *resourcesBaseSystemCopy;
@property NSMutableArray *resourcesNetInstallInstall;
@property NSMutableArray *resourcesBaseSystemInstall;

@property NSMutableArray *itemsToExtractFromSource;

@property NSURL *resourcesFolder;
@property NSURL *resourcesDictURL;

@property NSString *CasperVersion;
@property NSString *pythonVersion;

@property NSDictionary *userSettings;
@property NSDictionary *resourcesSettings;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)runWorkflow:(NBCWorkflowItem *)workflowItem;

@end
