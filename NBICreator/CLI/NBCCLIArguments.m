//
//  NBCCLIArguments.m
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

#import "NBCCLIArguments.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

@implementation NBCCLIArguments

- (void)verifyArguments {
    NSError *error;

    // Verify all required ones are here
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    if ([arguments containsObject:[NSString stringWithFormat:@"-%@", NBCCLIArgumentVersion]]) {
        NSString *versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        DDLogInfo(@"NBICreator %@", versionString);
        [[NSApplication sharedApplication] terminate:nil];
    }

    NSString *templatePath = [args objectForKey:NBCCLIArgumentTemplate];
    NSURL *templateURL;
    if ([templatePath length] != 0) {
        templateURL = [NSURL fileURLWithPath:templatePath];
    } else {
        DDLogError(@"No template path specified!");
        return;
    }

    NSDictionary *templateDict;
    if ([templateURL checkResourceIsReachableAndReturnError:&error]) {
        templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
    } else {
        DDLogError(@"%@", error);
        return;
    }

    NSString *sourcePath = [args objectForKey:NBCCLIArgumentSource];
    if ([sourcePath length] == 0) {
        DDLogError(@"No source path specified!");
        return;
    }

    // Start checking with template
    NBCWorkflowItem *workflowItem;
    if ([templateDict count] != 0) {
        workflowItem = [self workflowItemFromTemplate:templateDict];
    } else {
        DDLogError(@"Invalid Template File");
        return;
    }

    // Vefify template settings
}

- (NBCWorkflowItem *)workflowItemFromTemplate:(NSDictionary *)templateDict {
    if ([templateDict count] != 0) {
        NSString *templateType = templateDict[NBCSettingsTypeKey];
        int workflowType = 0;
        if ([templateType isEqualToString:NBCSettingsTypeNetInstall]) {
            workflowType = kWorkflowTypeNetInstall;
        } else if ([templateType isEqualToString:NBCSettingsTypeDeployStudio]) {
            workflowType = kWorkflowTypeDeployStudio;
        } else if ([templateType isEqualToString:NBCSettingsTypeImagr]) {
            workflowType = kWorkflowTypeImagr;
        } else if ([templateType isEqualToString:NBCSettingsTypeCasper]) {
            workflowType = kWorkflowTypeCasper;
        } else {
            DDLogError(@"Unknown Template Type");
            return nil;
        }

        return [[NBCWorkflowItem alloc] initWithWorkflowType:workflowType workflowSessionType:kWorkflowSessionTypeCLI];
    } else {
        DDLogError(@"Invalid Template...");
    }
    return nil;
}

- (void)printUsage {
    DDLogInfo(@"Usage: NBICreator -");
}

@end
