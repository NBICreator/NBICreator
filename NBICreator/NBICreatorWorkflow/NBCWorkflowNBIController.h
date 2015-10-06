//
//  NBCWorkflowNBIController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowItem.h"


@interface NBCWorkflowNBIController : NSObject

- (NSArray *)generateScriptArgumentsForCreateRestoreFromSources:(NBCWorkflowItem *)workflowItem;
- (NSArray *)generateScriptArgumentsForCreateNetInstall:(NBCWorkflowItem *)workflowItem;
- (NSDictionary *)generateEnvironmentVariablesForCreateRestoreFromSources:(NBCWorkflowItem *)workflowItem;
- (NSDictionary *)generateEnvironmentVariablesForCreateNetInstall:(NBCWorkflowItem *)workflowItem;
- (NSArray *)generateScriptArgumentsForSysBuilder:(NBCWorkflowItem *)workflowItem;
+ (NSString *)generateImagrRCImagingForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion;
+ (NSString *)generateCasperRCImagingForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion;
+ (NSString *)generateCasperRCCdromPreWSForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion;

@end
