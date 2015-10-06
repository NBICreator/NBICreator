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
    
    _resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
    _resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
    _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
    _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
    _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
    _resourcesController = [[NBCWorkflowResourcesController alloc] init];
    
    [self setTarget:[workflowItem target]];
    [self setUserSettings:[workflowItem userSettings]];
    [self setResourcesSettings:[workflowItem resourcesSettings]];
    [self setResourcesCount:0];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
    
    /*
    // -------------------------------------------------------
    //  Update _resourcesCount with all sourceItems
    // -------------------------------------------------------
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    NSLog(@"sourceItemsDict=%@", sourceItemsDict);
    if ( [sourceItemsDict count] != 0 ) {
        NSArray *sourcePackages = [sourceItemsDict allKeys];
        for ( NSString *packagePath in sourcePackages ) {
            NSDictionary *packageDict = sourceItemsDict[packagePath];
            NSDictionary *packageDictPath = packageDict[NBCSettingsSourceItemsPathKey];
            int packageCount = (int)[packageDictPath count];
            [self setResourcesCount:( _resourcesCount + packageCount )];
            NSArray *packageRegexArray = packageDict[NBCSettingsSourceItemsRegexKey];
            if ( [packageDict count] != 0 ) {
                [self setResourcesCount:( _resourcesCount + (int)[packageRegexArray count] )];
            }
        }
    }
    NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
    if ( [certificatesArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + ( (int)[certificatesArray count] + 1 ) )];
    }
    NSArray *packagessArray = _resourcesSettings[NBCSettingsPackagesKey];
    if ( [packagessArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + (int)[packagessArray count] )];
    }
    NSArray *packagessNetInstallArray = _resourcesSettings[NBCSettingsPackagesNetInstallKey];
    if ( [packagessNetInstallArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + (int)[packagessNetInstallArray count] )];
    }
    NSArray *configurationProfilesArray = _resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey];
    if ( [configurationProfilesArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + ( (int)[configurationProfilesArray count] + 1 ) )];
    }
    
    if ( _userSettings ) {
        if ( ! [self preparePackagesForNetInstall:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self prepareConfigurationProfilesForNetInstall:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        
    } else {
        NSLog(@"Could not get user settings!");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
     */
} // runWorkflow

- (BOOL)prepareConfigurationProfilesForNetInstall:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogInfo(@"Preparing Configuration Profiles for NetInstall...");
    BOOL retval = YES;
    NSArray *configurationProfilesArray = _resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey];
    
    if ( [configurationProfilesArray count] != 0 ) {
        NSString *targetFolderPath = NBCFolderPathNetInstallConfigurationProfiles;
        
        for ( NSString *configurationProfilePath in configurationProfilesArray ) {
            NSString *targetConfigurationProfilePath = [targetFolderPath stringByAppendingPathComponent:[configurationProfilePath lastPathComponent]];
            
            NSDictionary *newCopyAttributes  = @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0644
                                                 };
            
            NSDictionary *newCopySetting = @{
                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                             NBCWorkflowCopySourceURL : configurationProfilePath,
                                             NBCWorkflowCopyTargetURL : targetConfigurationProfilePath,
                                             NBCWorkflowCopyAttributes : newCopyAttributes
                                             };
            [self updateNetInstallCopyDict:newCopySetting];
        }

        NSString *installConfigurationProfilesScriptPath = [[[workflowItem applicationSource] installConfigurationProfiles] path];
        NSString *installConfigurationProfilesScriptTargetPath = NBCFilePathNetInstallInstallConfigurationProfiles;
        
        NSDictionary *copyAttributes  = @{
                                             NSFileOwnerAccountName : @"root",
                                             NSFileGroupOwnerAccountName : @"wheel",
                                             NSFilePosixPermissions : @0755
                                             };
        
        NSDictionary *copySetting = @{
                                         NBCWorkflowCopyType : NBCWorkflowCopy,
                                         NBCWorkflowCopySourceURL : installConfigurationProfilesScriptPath,
                                         NBCWorkflowCopyTargetURL : installConfigurationProfilesScriptTargetPath,
                                         NBCWorkflowCopyAttributes : copyAttributes
                                         };
        [self updateNetInstallCopyDict:copySetting];
        
        [self checkCompletedResources];
    }
    return retval;
} // preparePackages

- (BOOL)preparePackagesForNetInstall:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogInfo(@"Preparing packages for NetInstall...");
    BOOL retval = YES;
    NSArray *packagesArray = _resourcesSettings[NBCSettingsNetInstallPackagesKey];
    
    if ( [packagesArray count] != 0 ) {
        NSString *targetFolderPath = NBCFolderPathNetInstallPackages;
        
        for ( NSString *packagePath in packagesArray ) {
            NSString *targetPackagePath = [targetFolderPath stringByAppendingPathComponent:[packagePath lastPathComponent]];
            NSDictionary *newCopyAttributes  = @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0755
                                                 };
            
            NSDictionary *newCopySetting = @{
                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                             NBCWorkflowCopySourceURL : packagePath,
                                             NBCWorkflowCopyTargetURL : targetPackagePath,
                                             NBCWorkflowCopyAttributes : newCopyAttributes
                                             };
            [self updateNetInstallCopyDict:newCopySetting];
        }
        
        [self checkCompletedResources];
    }
    return retval;
} // preparePackages

- (void)updateNetInstallCopyDict:(NSDictionary *)copyAttributes {
    [_resourcesNetInstallCopy addObject:copyAttributes];
} // updateNetInstallCopyDict:copyAttributes

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
        
        [_target setResourcesNetInstallDict:_resourcesNetInstallDict];
        [_target setResourcesBaseSystemDict:_resourcesBaseSystemDict];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
    }
} // checkCompletedResources

@end
