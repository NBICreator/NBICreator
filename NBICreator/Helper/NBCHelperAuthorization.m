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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
                                         @"timeout": @(300),
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
}

+ (NSString *)authorizationRightForCommand:(SEL)command {
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}


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
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef {
    assert(authRef != NULL);
    [[self class] enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        OSStatus    blockErr;
        
        // First get the right.  If we get back errAuthorizationDenied that means there's
        // no current definition, so we add our default one.
        
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            blockErr = AuthorizationRightSet(
                                             authRef,                                    // authRef
                                             [authRightName UTF8String],                 // rightName
                                             (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                                             (__bridge CFStringRef) authRightDesc,       // descriptionKey
                                             NULL,                                       // bundle (NULL implies main bundle)
                                             CFSTR("Common")                             // localeTableName
                                             );
            assert(blockErr == errAuthorizationSuccess);
        } else {
            // A right already exists (err == noErr) or any other error occurs, we
            // assume that it has been set up in advance by the system administrator or
            // this is the second time we've run.  Either way, there's nothing more for
            // us to do.
        }
    }];
}

+ (NSError *)authorizeWorkflowCasper:(NSData *)authData {

    NSError *error = nil;
    OSStatus err;
    AuthorizationRef authRef = NULL;
    
    if ( (authData == nil) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        err = AuthorizationCreateFromExternalForm( [authData bytes], &authRef );
        
        if ( err == errAuthorizationSuccess ) {
            AuthorizationItem authItems[10];
            
            authItems[0].name = [NBCAuthorizationRightWorkflowCasper UTF8String];
            authItems[0].valueLength = 0;
            authItems[0].value = NULL;
            authItems[0].flags = 0;
            
            authItems[1].name = [NBCAuthorizationRightAddUsers UTF8String];
            authItems[1].valueLength = 0;
            authItems[1].value = NULL;
            authItems[1].flags = 0;
            
            authItems[2].name = [NBCAuthorizationRightCopyExtractedResourcesToCache UTF8String];
            authItems[2].valueLength = 0;
            authItems[2].value = NULL;
            authItems[2].flags = 0;
            
            authItems[3].name = [NBCAuthorizationRightCopyResourcesToVolume UTF8String];
            authItems[3].valueLength = 0;
            authItems[3].value = NULL;
            authItems[3].flags = 0;
            
            authItems[4].name = [NBCAuthorizationRightCreateNetInstall UTF8String];
            authItems[4].valueLength = 0;
            authItems[4].value = NULL;
            authItems[4].flags = 0;
            
            authItems[5].name = [NBCAuthorizationRightDisableSpotlight UTF8String];
            authItems[5].valueLength = 0;
            authItems[5].value = NULL;
            authItems[5].flags = 0;
            
            authItems[6].name = [NBCAuthorizationRightExtractResourcesFromPackage UTF8String];
            authItems[6].valueLength = 0;
            authItems[6].value = NULL;
            authItems[6].flags = 0;
            
            authItems[7].name = [NBCAuthorizationRightInstallPackages UTF8String];
            authItems[7].valueLength = 0;
            authItems[7].value = NULL;
            authItems[7].flags = 0;
            
            authItems[8].name = [NBCAuthorizationRightModifyResourcesOnVolume UTF8String];
            authItems[8].valueLength = 0;
            authItems[8].value = NULL;
            authItems[8].flags = 0;
            
            authItems[9].name = [NBCAuthorizationRightUpdateKernelCache UTF8String];
            authItems[9].valueLength = 0;
            authItems[9].value = NULL;
            authItems[9].flags = 0;
            
            AuthorizationRights authRights;
            authRights.count = sizeof (authItems) / sizeof (authItems[0]);
            authRights.items = authItems;
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &authRights,
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
}

+ (NSError *)authorizeWorkflowDeployStudio:(NSData *)authData {
    
    NSError *error = nil;
    OSStatus err;
    AuthorizationRef authRef = NULL;
    
    if ( (authData == nil) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        err = AuthorizationCreateFromExternalForm( [authData bytes], &authRef );
        
        if ( err == errAuthorizationSuccess ) {
            AuthorizationItem authItems[5];
            
            authItems[0].name = [NBCAuthorizationRightWorkflowDeployStudio UTF8String];
            authItems[0].valueLength = 0;
            authItems[0].value = NULL;
            authItems[0].flags = 0;
            
            authItems[1].name = [NBCAuthorizationRightCopyResourcesToVolume UTF8String];
            authItems[1].valueLength = 0;
            authItems[1].value = NULL;
            authItems[1].flags = 0;
            
            authItems[2].name = [NBCAuthorizationRightDisableSpotlight UTF8String];
            authItems[2].valueLength = 0;
            authItems[2].value = NULL;
            authItems[2].flags = 0;
            
            authItems[3].name = [NBCAuthorizationRightModifyResourcesOnVolume UTF8String];
            authItems[3].valueLength = 0;
            authItems[3].value = NULL;
            authItems[3].flags = 0;
            
            authItems[4].name = [NBCAuthorizationRightSysBuilderWithArguments UTF8String];
            authItems[4].valueLength = 0;
            authItems[4].value = NULL;
            authItems[4].flags = 0;
            
            AuthorizationRights authRights;
            authRights.count = sizeof (authItems) / sizeof (authItems[0]);
            authRights.items = authItems;
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &authRights,
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
}

+ (NSError *)authorizeWorkflowImagr:(NSData *)authData {
    
    NSError *error = nil;
    OSStatus err;
    AuthorizationRef authRef = NULL;
    
    if ( (authData == nil) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        err = AuthorizationCreateFromExternalForm( [authData bytes], &authRef );
        
        if ( err == errAuthorizationSuccess ) {
            AuthorizationItem authItems[10];
            
            authItems[0].name = [NBCAuthorizationRightWorkflowImagr UTF8String];
            authItems[0].valueLength = 0;
            authItems[0].value = NULL;
            authItems[0].flags = 0;
            
            authItems[1].name = [NBCAuthorizationRightAddUsers UTF8String];
            authItems[1].valueLength = 0;
            authItems[1].value = NULL;
            authItems[1].flags = 0;
            
            authItems[2].name = [NBCAuthorizationRightCopyExtractedResourcesToCache UTF8String];
            authItems[2].valueLength = 0;
            authItems[2].value = NULL;
            authItems[2].flags = 0;
            
            authItems[3].name = [NBCAuthorizationRightCopyResourcesToVolume UTF8String];
            authItems[3].valueLength = 0;
            authItems[3].value = NULL;
            authItems[3].flags = 0;
            
            authItems[4].name = [NBCAuthorizationRightCreateNetInstall UTF8String];
            authItems[4].valueLength = 0;
            authItems[4].value = NULL;
            authItems[4].flags = 0;
            
            authItems[5].name = [NBCAuthorizationRightDisableSpotlight UTF8String];
            authItems[5].valueLength = 0;
            authItems[5].value = NULL;
            authItems[5].flags = 0;
            
            authItems[6].name = [NBCAuthorizationRightExtractResourcesFromPackage UTF8String];
            authItems[6].valueLength = 0;
            authItems[6].value = NULL;
            authItems[6].flags = 0;
            
            authItems[7].name = [NBCAuthorizationRightInstallPackages UTF8String];
            authItems[7].valueLength = 0;
            authItems[7].value = NULL;
            authItems[7].flags = 0;
            
            authItems[8].name = [NBCAuthorizationRightModifyResourcesOnVolume UTF8String];
            authItems[8].valueLength = 0;
            authItems[8].value = NULL;
            authItems[8].flags = 0;
            
            authItems[9].name = [NBCAuthorizationRightUpdateKernelCache UTF8String];
            authItems[9].valueLength = 0;
            authItems[9].value = NULL;
            authItems[9].flags = 0;
            
            AuthorizationRights authRights;
            authRights.count = sizeof (authItems) / sizeof (authItems[0]);
            authRights.items = authItems;
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &authRights,
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
}

+ (NSError *)authorizeWorkflowNetInstall:(NSData *)authData {
    
    NSError *error = nil;
    OSStatus err;
    AuthorizationRef authRef = NULL;
    
    if ( (authData == nil) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if ( error == nil ) {
        err = AuthorizationCreateFromExternalForm( [authData bytes], &authRef );
        
        if ( err == errAuthorizationSuccess ) {
            AuthorizationItem authItems[6];
            
            authItems[0].name = [NBCAuthorizationRightWorkflowNetInstall UTF8String];
            authItems[0].valueLength = 0;
            authItems[0].value = NULL;
            authItems[0].flags = 0;
            
            authItems[1].name = [NBCAuthorizationRightCopyResourcesToVolume UTF8String];
            authItems[1].valueLength = 0;
            authItems[1].value = NULL;
            authItems[1].flags = 0;
            
            authItems[2].name = [NBCAuthorizationRightCreateNetInstall UTF8String];
            authItems[2].valueLength = 0;
            authItems[2].value = NULL;
            authItems[2].flags = 0;
            
            authItems[3].name = [NBCAuthorizationRightCreateRestoreFromSources UTF8String];
            authItems[3].valueLength = 0;
            authItems[3].value = NULL;
            authItems[3].flags = 0;
            
            authItems[4].name = [NBCAuthorizationRightDisableSpotlight UTF8String];
            authItems[4].valueLength = 0;
            authItems[4].value = NULL;
            authItems[4].flags = 0;
            
            authItems[5].name = [NBCAuthorizationRightModifyResourcesOnVolume UTF8String];
            authItems[5].valueLength = 0;
            authItems[5].value = NULL;
            authItems[5].flags = 0;
            
            AuthorizationRights authRights;
            authRights.count = sizeof (authItems) / sizeof (authItems[0]);
            authRights.items = authItems;
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &authRights,
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
}

+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command {
    
    NSError *error;
    OSStatus err;
    AuthorizationRef authRef;
    
    assert(command != nil);
    
    authRef = NULL;
    
    error = nil;
    if ((authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm))) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        if (err == errAuthorizationSuccess) {
            AuthorizationItem oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights = { 1, &oneRight };
            
            oneRight.name = [[[self class] authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                                          authRef,
                                          &rights,
                                          NULL,
                                          kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                                          NULL);
        }
        if (err != errAuthorizationSuccess) {
            NSString *message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
            error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : message }];
        }
    }
    
    return error;
}

+ (NSData *)authorizeHelper {
    OSStatus err;
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
        [[self class] setupAuthorizationRights:authRef];
    }
    
    return authorization;
}

@end

