//
//  NBCDeployStudioWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioWorkflowResources.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCDeployStudioSource.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

@implementation NBCDeployStudioWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    NSError *error;
    [self setTarget:[workflowItem target]];
    _resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
    _resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
    _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
    _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
    _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
    _userSettings = [workflowItem userSettings];
    _resourcesSettings = [workflowItem resourcesSettings];
    _resourcesController = [[NBCWorkflowResourcesController alloc] init];
    
    NSString *creationTool = _userSettings[NBCSettingsNBICreationToolKey];
    if ( [creationTool isEqualToString:NBCMenuItemNBICreator] ) {
        
        // DeployStudio Admin.app
        [self setResourcesCount:1];
    } else if ( [creationTool isEqualToString:NBCMenuItemDeployStudioAssistant] ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
    }
    
    if ( _userSettings ) {
        
        if ( ! [self prepareDeployStudioAdmin:workflowItem error:&error] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing packages failed"] }];
            return;
        }
        
        [self checkCompletedResources];
    } else {
        NSLog(@"Could not get user settings!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Update Resource Dicts
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)checkCompletedResources {
    DDLogDebug(@"[DEBUG] Checking if all resources have been prepared...");
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    DDLogDebug(@"[DEBUG] Prepared resources for copy: %lu", requiredCopyResources);
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
    DDLogDebug(@"[DEBUG] Prepared resources for installation: %lu", requiredInstallResources);
    DDLogDebug(@"[DEBUG] Count of resources prepared: %d", ( (int) requiredCopyResources + (int) requiredInstallResources ) );
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
    if ( ( (int) requiredCopyResources + (int) requiredInstallResources ) == _resourcesCount ) {
        if ( [_resourcesNetInstallCopy count] != 0 ) {
            _resourcesNetInstallDict[NBCWorkflowCopy] = _resourcesNetInstallCopy;
        }
        
        if ( [_resourcesNetInstallInstall count] != 0 ) {
            _resourcesNetInstallDict[NBCWorkflowInstall] = _resourcesNetInstallInstall;
        }
        
        if ( [_resourcesBaseSystemCopy count] != 0 ) {
            _resourcesBaseSystemDict[NBCWorkflowCopy] = _resourcesBaseSystemCopy;
        }
        
        if ( [_resourcesBaseSystemInstall count] != 0 ) {
            _resourcesBaseSystemDict[NBCWorkflowInstall] = _resourcesBaseSystemInstall;
        }
        
        if ( ! _workflowCompleted ) {
            [self setWorkflowCompleted:YES];
            [_target setResourcesNetInstallDict:_resourcesNetInstallDict];
            [_target setResourcesBaseSystemDict:_resourcesBaseSystemDict];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
        } else {
            DDLogDebug(@"[DEBUG] Workflow has already completed!");
        }
    }
} // checkCompletedResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get External Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)prepareDeployStudioAdmin:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    
    DDLogInfo(@"Preparing DeployStudio Admin.app...");
    
    // ------------------------------------------------------
    //  Determine source URL
    // ------------------------------------------------------
    NSURL *deployStudioAdminSourceURL = [[workflowItem applicationSource] urlForDSAdminResource:@"self" extension:nil];
    if ( [deployStudioAdminSourceURL checkResourceIsReachableAndReturnError:error] ) {
        
        // ------------------------------------------------------
        //  Add item to copy
        // ------------------------------------------------------
        [self updateCopyDict:@{
                               NBCWorkflowCopyType : NBCWorkflowCopy,
                               NBCWorkflowCopySourceURL : [deployStudioAdminSourceURL path],
                               NBCWorkflowCopyTargetURL : @"/Applications/Utilities/DeployStudio Admin.app",
                               NBCWorkflowCopyAttributes : @{
                                       NSFileOwnerAccountName :      @"root",
                                       NSFileGroupOwnerAccountName : @"wheel",
                                       NSFilePosixPermissions :      @0755
                                       }
                               }];
        return YES;
    } else {
        return NO;
    }
}

- (void)updateCopyDict:(NSDictionary *)dict {
    [_resourcesBaseSystemCopy addObject:dict];
    [self checkCompletedResources];
}

@end

