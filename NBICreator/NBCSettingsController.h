//
//  NBCSharedSettingsController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-19.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCWorkflowItem.h"

@interface NBCSettingsController : NSObject

- (NSDictionary *)verifySettingsImagr:(NBCWorkflowItem *)workflowItem;
- (NSDictionary *)verifySettingsNetInstall:(NBCWorkflowItem *)workflowItem;
- (NSDictionary *)verifySettingsDeployStudio:(NBCWorkflowItem *)workflowItem;

@end
