//
//  NBCSystemImageUtilitySource.m
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

#import "NBCApplicationSourceSystemImageUtility.h"
#import "NBCConstants.h"
//#import "NBCLogging.h"
#import "FileHash.h"
#import "NBCError.h"

// DDLogLevel ddLogLevel;

@implementation NBCApplicationSourceSystemImageUtility

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Init / Dealloc
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super init];
    if (self) {
        _systemImageUtilityURL = [NSURL fileURLWithPath:@"/System/Library/CoreServices/Applications/System Image Utility.app"];
    }
    return self;
} // init

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get Versions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSString *)siuFoundationVersionString:(NSError **)error {

    NSURL *siuFoundationVersionPlistURL = [[NSBundle bundleWithURL:[self siuFoundationURL]] URLForResource:@"version" withExtension:@"plist"];
    // DDLogDebug(@"[DEBUG] SIUFoundation.framework version.plist path: %@", [siuFoundationVersionPlistURL path]);
    if (![siuFoundationVersionPlistURL checkResourceIsReachableAndReturnError:error]) {
        return nil;
    }

    NSDictionary *siuFoundationVersionDict = [NSDictionary dictionaryWithContentsOfURL:siuFoundationVersionPlistURL];
    if ([siuFoundationVersionDict count] != 0) {
        NSString *siuFoundationBundleVersion = siuFoundationVersionDict[@"CFBundleShortVersionString"];
        // DDLogDebug(@"[DEBUG] SIUFoundation.framework bundle version: %@", siuFoundationBundleVersion);

        NSString *siuFoundationBuildVersion = siuFoundationVersionDict[@"BuildVersion"];
        // DDLogDebug(@"[DEBUG] SIUFoundation.framework build version: %@", siuFoundationBuildVersion);

        if ([siuFoundationBundleVersion length] != 0 && [siuFoundationBuildVersion length] != 0) {
            return [NSString stringWithFormat:@"%@-%@", siuFoundationBundleVersion, siuFoundationBuildVersion];
        } else {
            *error = [NBCError errorWithDescription:@"SIUFoundation.framework version info not available"];
        }
    } else {
        *error = [NBCError errorWithDescription:@"Unable to read SIUFoundation.framework version.plist"];
    }

    return nil;
} // siuFoundationVersionString

- (NSString *)systemImageUtilityVersion {
    return [[self siuBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
} // systemImageUtilityVersion

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSBundle *)siuBundle {
    if ([_systemImageUtilityURL checkResourceIsReachableAndReturnError:nil]) {
        return [NSBundle bundleWithURL:_systemImageUtilityURL];
    } else {
        return nil;
    }
} // siuBundle

- (NSBundle *)siuFoundationBundle {
    NSURL *siuFoundationURL = [self siuFoundationURL];
    if ([siuFoundationURL checkResourceIsReachableAndReturnError:nil]) {
        return [NSBundle bundleWithURL:siuFoundationURL];
    } else {
        return nil;
    }
} // siuFoundationBundle

- (NSBundle *)siuAgentBundle {
    NSURL *siuAgentURL = [self siuAgentURL];
    if ([siuAgentURL checkResourceIsReachableAndReturnError:nil]) {
        return [NSBundle bundleWithURL:siuAgentURL];
    } else {
        return nil;
    }
} // siuAgentBundle

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get URLs
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSURL *)urlForResourceNamed:(NSString *)resourceName {
    return [[self siuAgentBundle] URLForResource:[resourceName stringByDeletingPathExtension] withExtension:[resourceName pathExtension]];
} // urlForResourceNamed

- (NSURL *)siuFoundationURL {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (11 <= (int)version.minorVersion) {
        return [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/SIUFoundation.framework"];
    } else {
        return [[[NSBundle bundleWithPath:@"/System/Library/CoreServices/Applications/System Image Utility.app"] privateFrameworksURL] URLByAppendingPathComponent:@"SIUFoundation.framework"];
    }
} // siuFoundationURL

- (NSURL *)siuAgentURL {
    return [[self siuFoundationURL] URLByAppendingPathComponent:@"Versions/A/XPCServices/com.apple.SIUAgent.xpc"];
} // siuAgentURL

- (NSURL *)createCommonURL {
    return [self urlForResourceNamed:@"createCommon.sh"];
} // createCommonURL

- (NSURL *)createNetBootURL {
    return [self urlForResourceNamed:@"createNetBoot.sh"];
} // createNetBootURL

- (NSURL *)createNetInstallURL {
    return [self urlForResourceNamed:@"createNetInstall.sh"];
} // createNetInstallURL

- (NSURL *)createRestoreFromSourcesURL {
    return [self urlForResourceNamed:@"createRestoreFromSources.sh"];
} // createRestoreFromSourcesURL

- (NSURL *)addBSDPSourcesURL {
    return [self urlForResourceNamed:@"addBSDPSources.sh"];
} // addBSDPSourcesURL

- (NSURL *)asrInstallPkgURL {
    return [self urlForResourceNamed:@"ASRInstall.pkg"];
} // asrInstallPkgURL

- (NSURL *)asrFromVolumeURL {
    return [self urlForResourceNamed:@"asrFromVolume.sh"];
} // asrFromVolumeURL

- (NSURL *)installConfigurationProfilesURL {
    return [self urlForResourceNamed:@"installConfigurationProfiles.sh"];
} // installConfigurationProfilesURL

- (NSURL *)netInstallConfigurationProfiles {
    return [self urlForResourceNamed:@"netInstallConfigurationProfiles.sh"];
} // netInstallConfigurationProfiles

- (NSURL *)postInstallPackages {
    return [self urlForResourceNamed:@"postInstallPackages.sh"];
} // postInstallPackages

- (NSURL *)preserveInstallLog {
    return [self urlForResourceNamed:@"preserveInstallLog.sh"];
} // preserveInstallLog

- (NSURL *)netBootClientHelper {
    return [self urlForResourceNamed:@"NetBootClientHelper"];
} // netBootClientHelper

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Hashes
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)verifyCreateNetInstallHashes:(NSError **)error {

    NSString *siuFoundationVersionString = [self siuFoundationVersionString:error];
    if ([siuFoundationVersionString length] == 0) {
        return NO;
    }

    NSDictionary *cachedHashes = [self hashesForSIUFoundationVersion:siuFoundationVersionString error:error];
    if ([cachedHashes count] == 0) {
        return NO;
    }

    if (![self verifyHashForResourceNamed:@"createNetInstall.sh" cachedHashes:cachedHashes error:error]) {
        return NO;
    }

    if (![self verifyHashForResourceNamed:@"createCommon.sh" cachedHashes:cachedHashes error:error]) {
        return NO;
    }

    return YES;
} // verifyCreateNetInstallHashes

- (BOOL)verifyHashForResourceNamed:(NSString *)resourceName cachedHashes:(NSDictionary *)cachedHashes error:(NSError **)error {

    // -----------------------------------------------------------------------------------
    //  Verify resource path
    // -----------------------------------------------------------------------------------
    NSURL *resourceURL = [self urlForResourceNamed:resourceName];
    if ([resourceURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    // -----------------------------------------------------------------------------------
    //  Verify resource integrity
    // -----------------------------------------------------------------------------------
    NSString *resourceMD5 = [FileHash md5HashOfFileAtPath:[resourceURL path]];
    // DDLogDebug(@"[DEBUG] %@", [NSString stringWithFormat:@"Verifying resource: %@ current md5: %@", resourceName, resourceMD5]);

    NSString *cachedResourceMD5 = cachedHashes[resourceName];
    // DDLogDebug(@"[DEBUG] %@", [NSString stringWithFormat:@"Verifying resource: %@ script cached md5: %@", resourceName, cachedResourceMD5]);
    if ([cachedResourceMD5 length] == 0) {
        *error = [NBCError errorWithDescription:@""];
        return NO;
    }

    // DDLogDebug(@"[DEBUG] Comparing resource hashes...");
    if (![resourceMD5 isEqualToString:cachedResourceMD5]) {
        *error = [NBCError
            errorWithDescription:[NSString stringWithFormat:@"Resource hashes doesn't match! If you haven't modified %@ yourself, someone might be trying to exploit this application!", resourceName]];
        return NO;
    }

    return YES;
} // verifyHashForResourceNamed:cachedHashes:error

- (NSDictionary *)hashesForSIUFoundationVersion:(NSString *)siuFoundationVersion error:(NSError **)error {
    NSLog(@"hashesForSIUFoundationVersion:%@", siuFoundationVersion);
    NSLog(@"[NSBundle mainBundle]=%@", [[NSBundle mainBundle] bundlePath]);
    NSURL *siuHashesPlistURL = [[NSBundle mainBundle] URLForResource:@"HashesSystemImageUtility" withExtension:@"plist"];
    NSLog(@"siuHashesPlistURL=%@", siuHashesPlistURL);
    // DDLogDebug(@"[DEBUG] HashesSystemImageUtility.plist path: %@", siuHashesPlistURL);
    if (![siuHashesPlistURL checkResourceIsReachableAndReturnError:error]) {
        return nil;
    }

    NSDictionary *siuHashesDict = [NSDictionary dictionaryWithContentsOfURL:siuHashesPlistURL];
    if ([siuHashesDict count] != 0) {
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *osVersion = [NSString stringWithFormat:@"%ld.%ld", version.majorVersion, version.minorVersion];
        NSDictionary *siuHashesOSVersionDict = siuHashesDict[osVersion];
        if ([siuHashesOSVersionDict count] != 0) {
            return siuHashesOSVersionDict[siuFoundationVersion];
        } else {
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"No hashes found for os version: %@", osVersion]];
        }
    } else {
        *error = [NBCError errorWithDescription:@"Unable to read System Image Utility hash plist"];
    }

    return nil;
} // hashesForSIUFoundationVersion:error

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Expand Variables
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSString *)expandVariables:(NSString *)string {

    // --------------------------------------------------------------
    //  Expand %SIUVERSION%
    // --------------------------------------------------------------
    NSString *expandedString =
        [string stringByReplacingOccurrencesOfString:NBCVariableSystemImageUtilityVersion withString:[[self siuBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"Unknown"];

    // --------------------------------------------------------------
    //  Expand %NBITOOL%
    // --------------------------------------------------------------
    expandedString = [expandedString stringByReplacingOccurrencesOfString:@"%NBITOOL%" withString:@"SIU"];

    return expandedString;
} // expandVariables

@end
