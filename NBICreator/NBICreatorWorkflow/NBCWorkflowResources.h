//
//  NBCWorkflowResources.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-01.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCSource;
@class NBCWorkflowItem;

@interface NBCWorkflowResources : NSObject

@property NSMutableArray *resourcesNetInstallModify;
@property NSMutableArray *resourcesBaseSystemModify;
@property NSURL *installESDVolumeURL;
@property NBCSource *source;
@property NBCWorkflowItem *workflowItem;
@property int sourceVersionMinor;


- (id)initWithWorkflowItem:(NBCWorkflowItem *)workflowItem;
- (NSMutableDictionary *)prepareResourcesToExtract:(NSMutableDictionary *)resourcesSettings;

@end
