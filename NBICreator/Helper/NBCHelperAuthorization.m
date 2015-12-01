//
//  NBCHelperAuthorization.m
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

#import "NBCHelperAuthorization.h"
#import "NBCConstants.h"
#import "NBCHelperProtocol.h"

@implementation NBCHelperAuthorization

static NSString * kCommandKeyAuthRightName    = @"authRightName";
static NSString * kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString * kCommandKeyAuthRightDesc    = @"authRightDescription";

+ (NSDictionary *)commandInfo {
    static dispatch_once_t sOnceToken;
    static NSDictionary *  sCommandInfo;
    
    dispatch_once(&sOnceToken, ^{
        sCommandInfo = @{
                         NSStringFromSelector(@selector(authorizeWorkflowImagr:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightWorkflowImagr,
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to start a Imagr workflow.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(authorizeWorkflowCasper:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightWorkflowCasper,
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to start a Casper workflow.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(authorizeWorkflowDeployStudio:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightWorkflowDeployStudio,
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to start a DeployStudio workflow.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(authorizeWorkflowNetInstall:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightWorkflowNetInstall,
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to start a NetInstall workflow.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(addUsersToVolumeAtPath:userShortName:userPassword:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightAddUsers,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to add a user.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(copyExtractedResourcesToCache:regexString:temporaryFolder:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightCopyExtractedResourcesToCache,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying copy the extracted resources to cache.",
                                                                                 @"prompt shown when user is required to authorize to update kernel cache"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(copyResourcesToVolume:copyArray:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightCopyResourcesToVolume,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying copy resources to the NBI.",
                                                                                 @"prompt shown when user is required to authorize to update kernel cache"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(createNetInstallWithArguments:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightCreateNetInstall,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a NetInstall NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(createRestoreFromSourcesWithArguments:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightCreateRestoreFromSources,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a NetInstall NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(disableSpotlightOnVolume:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightDisableSpotlight,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to disable spotlight.",
                                                                                 @"prompt shown when user is required to authorize to disable spotlight on a volume"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(extractResourcesFromPackageAtPath:minorVersion:temporaryFolder:temporaryPackageFolder:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightExtractResourcesFromPackage,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying extract resources from an installer package.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(installPackage:targetVolumePath:choices:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightInstallPackages,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying install packages on the NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(modifyResourcesOnVolume:modificationsArray:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightModifyResourcesOnVolume,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying modify the NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(sysBuilderWithArguments:sourceVersionMinor:selectedVersion:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightSysBuilderWithArguments,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a DeployStudio NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(updateKernelCache:nbiVolumePath:minorVersion:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : NBCAuthorizationRightUpdateKernelCache,
                                 kCommandKeyAuthRightDefault : @{
                                         @"class": @"user",
                                         @"group": @"admin",
                                         //@"timeout": @(300),
                                         @"version": @(1),
                                         },
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying update the prelinked kernel in the NBI.",
                                                                                 @"prompt shown when user is required to authorize to update the NBI prelinked kernel"
                                                                                 )
                                 },
                         };
    });
    return sCommandInfo;
} // commandInfo

+ (NSString *)authorizationRightForCommand:(SEL)command {
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
} // authorizationRightForCommand

+ (void)enumerateRightsUsingBlock:( void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block {
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
#pragma unused(key)
#pragma unused(stop)
        NSDictionary *commandDict;
        NSString *authRightName;
        id authRightDefault;
        NSString *authRightDesc;
        
        // If any of the following asserts fire it's likely that you've got a bug
        // in sCommandInfo.
        
        commandDict = (NSDictionary *) obj;
        assert([commandDict isKindOfClass:[NSDictionary class]]);
        
        authRightName = commandDict[kCommandKeyAuthRightName];
        assert([authRightName isKindOfClass:[NSString class]]);
        
        authRightDefault = commandDict[kCommandKeyAuthRightDefault];
        assert(authRightDefault != nil);
        
        authRightDesc = commandDict[kCommandKeyAuthRightDesc];
        assert([authRightDesc isKindOfClass:[NSString class]]);
        
        block(authRightName, authRightDefault, authRightDesc);
    }];
} // enumerateRightsUsingBlock

+ (NSError *)setupAuthorizationRights:(AuthorizationRef)authRef {
    
    __block NSError *error = nil;
    
    // ------------------------------------------------
    //  Loop through all rights defined in commandInfo
    // ------------------------------------------------
    [[self class] enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        
        OSStatus blockErr;
        CFDictionaryRef currentRight = NULL;
        
        // -----------------------------------------------------------------
        //  Check if right already exist in policy database.
        //  errAuthorizationDenied means that it doesn't exit.
        //  If the versions mismatch, it needs to be updated.
        // -----------------------------------------------------------------
        blockErr = AuthorizationRightGet([authRightName UTF8String], &currentRight);
        if ( blockErr == errAuthorizationDenied || ( [authRightDefault isKindOfClass:[NSDictionary class]] && ! [authRightDefault[@"version"] isEqualTo:[(__bridge NSDictionary *)currentRight objectForKey:@"version"]] ) ) {
            
            // ---------------------------------------
            //  Add the right to the policy database
            // ---------------------------------------
            blockErr = AuthorizationRightSet(
                                             authRef,                                    // authRef
                                             [authRightName UTF8String],                 // rightName
                                             (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                                             (__bridge CFStringRef) authRightDesc,       // descriptionKey
                                             NULL,                                       // bundle (NULL implies main bundle)
                                             CFSTR("Common")                             // localeTableName
                                             );
            
            if ( blockErr != errAuthorizationSuccess ) {
                NSString *message = CFBridgingRelease(SecCopyErrorMessageString(blockErr, NULL));
                error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:blockErr userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
        }
    }];
    
    return error;
} // setupAuthorizationRights:error

+ (NSDictionary *)authRightsDictionary {
    // Define the group of rights that should be authorized for each workflow's execution.
    static dispatch_once_t dOnceToken;
    static NSDictionary *authRightsDictionary;
    dispatch_once(&dOnceToken, ^{
        authRightsDictionary = @{
                                 
                                 // -----------------------------------------------------------------------------------
                                 //  Casper
                                 // -----------------------------------------------------------------------------------
                                 NBCAuthorizationRightWorkflowCasper: @[
                                         NBCAuthorizationRightWorkflowCasper,
                                         NBCAuthorizationRightAddUsers,
                                         NBCAuthorizationRightCopyExtractedResourcesToCache,
                                         NBCAuthorizationRightCopyResourcesToVolume,
                                         NBCAuthorizationRightCreateNetInstall,
                                         NBCAuthorizationRightDisableSpotlight,
                                         NBCAuthorizationRightExtractResourcesFromPackage,
                                         NBCAuthorizationRightInstallPackages,
                                         NBCAuthorizationRightModifyResourcesOnVolume,
                                         NBCAuthorizationRightUpdateKernelCache
                                         ],
                                 
                                 // -----------------------------------------------------------------------------------
                                 //  DeployStudio
                                 // -----------------------------------------------------------------------------------
                                 NBCAuthorizationRightWorkflowDeployStudio: @[
                                         NBCAuthorizationRightWorkflowDeployStudio,
                                         NBCAuthorizationRightCopyResourcesToVolume,
                                         NBCAuthorizationRightDisableSpotlight,
                                         NBCAuthorizationRightModifyResourcesOnVolume,
                                         NBCAuthorizationRightSysBuilderWithArguments
                                         ],
                                 
                                 // -----------------------------------------------------------------------------------
                                 //  Imagr
                                 // -----------------------------------------------------------------------------------
                                 NBCAuthorizationRightWorkflowImagr: @[
                                         NBCAuthorizationRightWorkflowImagr,
                                         NBCAuthorizationRightAddUsers,
                                         NBCAuthorizationRightCopyExtractedResourcesToCache,
                                         NBCAuthorizationRightCopyResourcesToVolume,
                                         NBCAuthorizationRightCreateNetInstall,
                                         NBCAuthorizationRightDisableSpotlight,
                                         NBCAuthorizationRightExtractResourcesFromPackage,
                                         NBCAuthorizationRightInstallPackages,
                                         NBCAuthorizationRightModifyResourcesOnVolume,
                                         NBCAuthorizationRightUpdateKernelCache
                                         ],
                                 
                                 // -----------------------------------------------------------------------------------
                                 //  NetInstall
                                 // -----------------------------------------------------------------------------------
                                 NBCAuthorizationRightWorkflowNetInstall: @[
                                         NBCAuthorizationRightWorkflowNetInstall,
                                         NBCAuthorizationRightCopyResourcesToVolume,
                                         NBCAuthorizationRightDisableSpotlight,
                                         NBCAuthorizationRightModifyResourcesOnVolume,
                                         NBCAuthorizationRightCreateNetInstall ]
                                 };
        
    });
    return authRightsDictionary;
}

+ (NSArray *)authorizationRightsForWorkflow:(NSString *)workflow {
    NSArray *array = [[self class] authRightsDictionary][workflow];
    if ( [array count] ){
        return [array arrayByAddingObject:workflow];
    }
    return nil;
} // authorizationRightsForWorkflow

+ (NSError *)authorizeWorkflow:(NSString *)workflowId authData:(NSData *)authData {
    OSStatus err = 0;
    NSError *error = nil;
    AuthorizationRef authRef = NULL;
    
    if ( ( authData == nil ) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        err = AuthorizationCreateFromExternalForm( [authData bytes], &authRef );
        
        if ( err == errAuthorizationSuccess ) {
            
            NSArray *authRightsArray = [[self class] authorizationRightsForWorkflow:workflowId];
            if ( ! [authRightsArray count] ) {
                return [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : @"Invalid workflow process name. No rights returned." }];
            }
            
            AuthorizationItemSet * set = NULL;
            set = (AuthorizationItemSet*)calloc(1u, sizeof(AuthorizationItemSet));
            set->count = (UInt32)authRightsArray.count;
            set->items = (AuthorizationItem*)calloc(set->count, sizeof(AuthorizationItem));
            
            [authRightsArray enumerateObjectsUsingBlock:^(NSString *rightName, NSUInteger idx, BOOL * _Nonnull stop) {
#pragma unused(stop)
                set->items[idx].name = [rightName UTF8String];
                set->items[idx].valueLength = 0;
                set->items[idx].value = NULL;
                set->items[idx].flags = 0;
            }];
            
            AuthorizationRights authRights = { set->count, set->items };
            AuthorizationFlags flags = kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed;
            
            // -----------------------------------------------------------------------------------
            //  Try to obtain the right from the authorization server, might ask the user
            // -----------------------------------------------------------------------------------
            err = AuthorizationCopyRights(
                                          authRef,
                                          &authRights,
                                          NULL,
                                          flags,
                                          NULL);
        }
        
        if ( err != errAuthorizationSuccess ) {
            NSString *message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
            error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : message }];
        }
    }
    
    return error;
} // authorizeWorkflow:authData

+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command {
    assert(command != nil);
    assert(authData != nil);
    
    OSStatus err = 0;
    NSError *error = nil;
    AuthorizationRef authRef = NULL;
    
    // -----------------------------------------------------------------------------------
    //  Verify that authData is reasonable
    // -----------------------------------------------------------------------------------
    if ( ( authData == nil ) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        
        // -----------------------------------------------------------------------------------
        //  Extract authRef from it's data representation 'authData'
        // -----------------------------------------------------------------------------------
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        if (err == errAuthorizationSuccess) {
            
            // ----------------------------------------------------------------------------------------------
            //  Assemble right to obtain by returning a string representation of 'command' as the right name
            // ----------------------------------------------------------------------------------------------
            AuthorizationItem oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights = { 1, &oneRight };
            
            oneRight.name = [[[self class] authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            // --------------------------------------------------------------------------------------------------
            //  Try to obtain the right from the authorization server for session in authRef, might ask the user
            // --------------------------------------------------------------------------------------------------
            err = AuthorizationCopyRights(
                                          authRef,
                                          &rights,
                                          NULL,
                                          kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                                          NULL);
        }
        
        if ( err != errAuthorizationSuccess ) {
            NSString *message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
            error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : message }];
        }
    }
    
    return error;
} // checkAuthorization

+ (NSData *)authorizeHelper:(NSError **)error {
    OSStatus err = 0;
    AuthorizationExternalForm extForm;
    AuthorizationRef authRef;
    NSData *authorization;
    
    // -----------------------------------------------------------------------------------
    //  Create a empty AuthorizationRef
    // -----------------------------------------------------------------------------------
    err = AuthorizationCreate(NULL, NULL, 0, &authRef);
    
    if ( err == errAuthorizationSuccess ) {
        
        // -----------------------------------------------------------------------------------
        //  Create an external representation of the AuthorizationRef
        // -----------------------------------------------------------------------------------
        err = AuthorizationMakeExternalForm(authRef, &extForm);
    }
    
    if ( err == errAuthorizationSuccess ) {
        
        // -----------------------------------------------------------------------------------------
        //  Capture the external representation of the AuthorizationRef in NSData to send to helper
        // -----------------------------------------------------------------------------------------
        authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }
    
    assert( err == errAuthorizationSuccess );
    
    if ( authRef ) {
        *error = [[self class] setupAuthorizationRights:authRef];
    }
    
    return authorization;
}

@end

