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

@implementation NBCCLIArguments

- (void)verifyArguments {
    
    // Verify all required ones are here
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    NSString *templatePath = [args objectForKey:NBCCLIArgumentTemplate];
    if ( [templatePath length] == 0 ) {
        NSLog(@"No template path specified!");
        return;
    }
    
    NSString *sourcePath = [args objectForKey:NBCCLIArgumentSource];
    if ( [sourcePath length] == 0 ) {
        NSLog(@"No source path specified!");
        return;
    }
    
    // Get any extra
    
    
    
    // Start checking with template
    NBCWorkflowItem *workflowItem;
    NSURL *templateURL = [NSURL fileURLWithPath:templatePath];
    if ( templateURL ) {
        workflowItem = [self workflowItemFromTemplateURL:templateURL];
    } else {
        NSLog(@"Template path was invalid");
        return;
    }
    
    // Vefify template settings
    
    
}

- (NBCWorkflowItem *)workflowItemFromTemplateURL:(NSURL *)templateURL {
    NSError *error = nil;
    if ( [templateURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
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
    } else {
        NSLog(@"No such file...");
    }
    return nil;
}

@end
