//
//  NBCNetInstallWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallWorkflowResources.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    [self setTarget:[workflowItem target]];
    _resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
    _resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
    _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
    _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
    _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
    [self setUserSettings:[workflowItem userSettings]];
    [self setResourcesSettings:[workflowItem resourcesSettings]];
    _resourcesController = [[NBCWorkflowResourcesController alloc] init];
    [self setResourcesCount:0];
    
    if ( _userSettings ) {
        [self checkCompletedResources];
    } else {
        NSLog(@"Could not get user settings!");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Update Resource Dicts
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)checkCompletedResources {
    
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
    
    if ( ( (int)requiredCopyResources + (int)requiredInstallResources ) == _resourcesCount ) {
        if ( _resourcesNetInstallCopy ) {
            _resourcesNetInstallDict[NBCWorkflowCopy] = _resourcesNetInstallCopy; }
        
        [_target setResourcesNetInstallDict:_resourcesNetInstallDict];
        [_target setResourcesBaseSystemDict:_resourcesBaseSystemDict];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
    }
} // checkCompletedResources

@end
