//
//  NBCCLIArguments.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCCLIArguments.h"
#import "NBCConstants.h"
#import "NBCWorkflowItem.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCCLIArguments

- (void)verifyArguments {
    NSError *error;
    
    // Verify all required ones are here
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    if ( [arguments containsObject:[NSString stringWithFormat:@"-%@", NBCCLIArgumentVersion]] ) {
        NSString *versionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        DDLogInfo(@"NBICreator %@", versionString);
        [[NSApplication sharedApplication] terminate:nil];
    }
    
    NSString *templatePath = [args objectForKey:NBCCLIArgumentTemplate];
    NSURL *templateURL;
    if ( [templatePath length] != 0 ) {
        templateURL = [NSURL fileURLWithPath:templatePath];
    } else {
        NSLog(@"No template path specified!");
        return;
    }
    
    NSDictionary *templateDict;
    if ( [templateURL checkResourceIsReachableAndReturnError:&error] ) {
        templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
    } else {
        NSLog(@"No such file or directory");
        NSLog(@"%@", error);
        return;
    }
    
    NSString *sourcePath = [args objectForKey:NBCCLIArgumentSource];
    if ( [sourcePath length] == 0 ) {
        NSLog(@"No source path specified!");
        return;
    }
    
    // Start checking with template
    NBCWorkflowItem *workflowItem;
    if ( [templateDict count] != 0 ) {
        workflowItem = [self workflowItemFromTemplate:templateDict];
    } else {
        NSLog(@"Invalid Template File");
        return;
    }
    
    // Vefify template settings
    
    
}

- (NBCWorkflowItem *)workflowItemFromTemplate:(NSDictionary *)templateDict {
    if ( [templateDict count] != 0 ) {
        NSString *templateType = templateDict[NBCSettingsTypeKey];
        int workflowType = 0;
        if ( [templateType isEqualToString:NBCSettingsTypeNetInstall] ) {
            workflowType = kWorkflowTypeNetInstall;
        } else if ( [templateType isEqualToString:NBCSettingsTypeDeployStudio] ) {
            workflowType = kWorkflowTypeDeployStudio;
        } else if ( [templateType isEqualToString:NBCSettingsTypeImagr] ) {
            workflowType = kWorkflowTypeImagr;
        } else if ( [templateType isEqualToString:NBCSettingsTypeCasper] ) {
            workflowType = kWorkflowTypeCasper;
        } else {
            NSLog(@"Unknown Template Type");
            return nil;
        }
        
        return [[NBCWorkflowItem alloc] initWithWorkflowType:workflowType
                                         workflowSessionType:kWorkflowSessionTypeCLI];
    } else {
        NSLog(@"Invalid Template...");
    }
    return nil;
}

@end
