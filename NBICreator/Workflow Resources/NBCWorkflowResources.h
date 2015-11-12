//
//  NBCWorkflowResources.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-01.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
#import "NBCWorkflowResourcesExtract.h"
#import "NBCWorkflowResourceImagr.h"
@class NBCSource;
@class NBCWorkflowItem;


@interface NBCWorkflowResources : NSObject <NBCWorkflowResourcesExtractDelegate, NBCWorkflowResourceImagrDelegate>

@property (nonatomic, weak) id delegate;

@property NSMutableArray *resourcesNetInstallCopy;
@property NSMutableArray *resourcesBaseSystemCopy;
@property NSMutableArray *resourcesNetInstallInstall;
@property NSMutableArray *resourcesBaseSystemInstall;
@property NSURL *installESDVolumeURL;
@property NSString *sourceOSBuild;
@property NBCSource *source;
@property NBCWorkflowItem *workflowItem;
@property int sourceVersionMinor;
@property int workflowType;
@property BOOL isNBI;

@property NSString *creationTool;
@property NSDictionary *userSettings;
@property NSDictionary *resourcesSettings;
@property NSDictionary *settingsChanged;

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate;
- (void)prepareResources:(NBCWorkflowItem *)workflowItem;

@end
