//
//  NBCDeployStudioWorkflowModifyNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioWorkflowModifyNBI.h"
#import "NBCConstants.h"
#import "NSString+randomString.h"

#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressViewController.h"

#import "NBCTargetController.h"

#import "NBCDisk.h"
#import "NBCDiskImageController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCDeployStudioWorkflowModifyNBI

#pragma mark -
#pragma mark Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    _workflowItem = workflowItem;
    _targetController = [[NBCTargetController alloc] init];
    _progressView = [workflowItem progressView];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self->_progressView textFieldStatusInfo] setStringValue:@"Adding resources to NBI"];
        [[self->_progressView progressIndicator] setDoubleValue:91];
    });
    
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    if ( temporaryNBIURL ) {
        // ---------------------------------------------------------------
        //  Apply all settings to NBImageInfo.plist in NBI
        // ---------------------------------------------------------------
        if ( [_targetController applyNBISettings:temporaryNBIURL workflowItem:workflowItem error:&error] ) {
            [self finalizeWorkflow];
        } else {
            NSLog(@"Error when applying NBImageInfo settings");
            NSLog(@"Error: %@", error);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        NSLog(@"Could not get temporary NBI url from workflowItem");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

- (void)finalizeWorkflow {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteModifyNBI object:self userInfo:nil];
} // finalizeWorkflow

@end
