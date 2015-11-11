//
//  NBCWorkflowResourcesExtract.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-04.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
@class NBCSource;
@class NBCWorkflowItem;

@protocol NBCWorkflowResourcesExtractDelegate
- (void)resourceExtractionComplete:(NSArray *)resourcesToCopy;
- (void)resourceExtractionFailed;
@end

@interface NBCWorkflowResourcesExtract : NSObject

@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) id progressDelegate;
@property NSMutableArray *resourcesBaseSystemCopy;
@property NSURL *installESDVolumeURL;
@property NSString *sourceOSBuild;
@property NBCSource *source;
@property NBCWorkflowItem *workflowItem;
@property int sourceVersionMinor;

- (id)initWithDelegate:(id<NBCWorkflowResourcesExtractDelegate>)delegate;
- (void)extractResources:(NSDictionary *)resourcesToExtract workflowItem:(NBCWorkflowItem *)workflowItem;

@end
