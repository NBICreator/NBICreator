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
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.workflowImagr",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to start an Imagr workflow.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(addUsersToVolumeAtPath:userShortName:userPassword:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.addUsers",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to add a user.",
                                                                                 @"prompt shown when user is required to authorize to add a user"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(copyExtractedResourcesToCache:regexString:temporaryFolder:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.copyExtractedResourcesToCache",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying copy the extracted resources to cache.",
                                                                                 @"prompt shown when user is required to authorize to update kernel cache"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(copyResourcesToVolume:copyArray:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.copyResourcesToVolume",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying copy resources to the NBI.",
                                                                                 @"prompt shown when user is required to authorize to update kernel cache"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(createNetInstallWithArguments:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.createNetInstall",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a NetInstall NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(createRestoreFromSourcesWithArguments:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.createRestoreFromSources",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a NetInstall NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(disableSpotlightOnVolume:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.disableSpotlight",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to disable spotlight.",
                                                                                 @"prompt shown when user is required to authorize to disable spotlight on a volume"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(extractResourcesFromPackageAtPath:minorVersion:temporaryFolder:temporaryPackageFolder:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.extractResourcesFromPackage",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying extract resources from an installer package.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(installPackage:targetVolumePath:choices:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.installPackages",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying install packages on the NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(modifyResourcesOnVolume:modificationsArray:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.modifyResourcesOnVolume",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying modify the NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(sysBuilderWithArguments:sourceVersionMinor:selectedVersion:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.sysBuilderWithArguments",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
                                 kCommandKeyAuthRightDesc    : NSLocalizedString(
                                                                                 @"NBICreator is trying to create a DeployStudio NBI.",
                                                                                 @"prompt shown when user is required to authorize to start a NetInstall workflow"
                                                                                 )
                                 },
                         NSStringFromSelector(@selector(updateKernelCache:nbiVolumePath:minorVersion:authorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.github.NBICreator.updateKernelCache",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
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

+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command authRef:(AuthorizationRef)authRef {
#pragma unused(authData)
    NSError *           error;
    OSStatus            err = 0;
    //OSStatus            junk;
    //AuthorizationRef    authRef;

    assert(command != nil);
    
    //authRef = NULL;
    
    // First check that authData looks reasonable.
    
    error = nil;
    if ( ( authData == nil ) || ( [authData length] != sizeof(AuthorizationExternalForm) ) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    // Create an authorization ref from that the external form data contained within.
    
    if ( error == nil ) {
        
        // If authRef is empty, create one from authData
        /* I've moved this to the helper to retain the _authRef, could possibly do this here but unsure if that worked as I wanted?
         
        if ( authRef == NULL ) {
            err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
            if ( err != errAuthorizationSuccess ) {
                NSString *message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
                return [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : message }];
            }
        }
        */
        // Authorize the right associated with the command.
        
        AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
        AuthorizationRights rights   = { 1, &oneRight };
        
        oneRight.name = [[[self class] authorizationRightForCommand:command] UTF8String];
        assert(oneRight.name != NULL);
        
        err = AuthorizationCopyRights(
                                      authRef,
                                      &rights,
                                      NULL,
                                      kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                                      NULL
                                      );
        
        if ( err != errAuthorizationSuccess ) {
            NSString *message = CFBridgingRelease(SecCopyErrorMessageString(err, NULL));
            error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName] code:err userInfo:@{ NSLocalizedDescriptionKey : message }];
        }
    }
    
    //if ( authRef != NULL ) {
    //    junk = AuthorizationFree(authRef, 0);
    //   assert(junk == errAuthorizationSuccess);
    //}

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

