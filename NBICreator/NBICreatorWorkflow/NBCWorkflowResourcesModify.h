//
//  NBCWorkflowResourcesModify.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-01.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCWorkflowItem;

@interface NBCWorkflowResourcesModify : NSObject

@property BOOL isNBI;
@property NSURL *baseSystemVolumeURL;
@property NSDictionary *settingsChanged;
@property NBCWorkflowItem *workflowItem;
@property int sourceVersionMinor;
@property NSString *creationTool;

- (id)initWithWorkflowItem:(NBCWorkflowItem *)workflowItem;
- (NSArray *)prepareResourcesToModify;

@end
