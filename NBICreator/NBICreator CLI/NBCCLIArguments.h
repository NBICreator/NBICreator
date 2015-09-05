//
//  NBCCLIArguments.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowItem.h"

@interface NBCCLIArguments : NSObject

@property NBCWorkflowItem *workflowItem;

- (void)verifyArguments;

@end
