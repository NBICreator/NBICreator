//
//  NBCSystemImageUtilitySource.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-15.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCSystemImageUtilitySource.h"
#import "NBCConstants.h"
#import "NBCWorkflowItem.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCSystemImageUtilitySource

- (id)init {
    self = [super init];
    if (self) {
        [self setSystemImageUtilityURL];
    }
    return self;
}

- (void)setSystemImageUtilityURL {
    NSError *error;
    NSArray *systemImageUtilityURLs = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.apple.SystemImageUtility"), NULL));
    NSURL *systemImageUtilityURL = [systemImageUtilityURLs firstObject];
    _systemImageUtilityURL = systemImageUtilityURL;
    if ( [_systemImageUtilityURL checkResourceIsReachableAndReturnError:&error] ) {
        [self systemImageUtilityResourcesFromURL:_systemImageUtilityURL];
    } else {
        NSLog(@"System Image Utility Doesn't exist!_ %@", error);
    }
}

- (void)systemImageUtilityResourcesFromURL:(NSURL *)systemImageUtilityURL {
    [self setSystemImageUtilityVersion:[[NSBundle bundleWithURL:systemImageUtilityURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    [self setSelectedVersion:_systemImageUtilityVersion];
    
    NSURL *siuFoundationFrameworkURL;
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    int osVersionMinor = (int)version.minorVersion;
    if ( 11 <= osVersionMinor ) {
        siuFoundationFrameworkURL = [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/SIUFoundation.framework"];
    } else {
        siuFoundationFrameworkURL = [[[NSBundle bundleWithURL:_systemImageUtilityURL] privateFrameworksURL] URLByAppendingPathComponent:@"SIUFoundation.framework"];
    }
    
    [self siuFoundationResourcesFromURL:siuFoundationFrameworkURL];
}

- (void)siuFoundationResourcesFromURL:(NSURL *)siuFoundationFrameworkURL {
    NSError *error;
    if ( [siuFoundationFrameworkURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setSiuFoundationFrameworkURL:siuFoundationFrameworkURL];
        [self setSiuFoundationVersion:[[NSBundle bundleWithURL:_siuFoundationFrameworkURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    } else {
        NSLog(@"[ERROR] %@", [error localizedDescription]);
    }
    
    [self setSiuAgentXPCURL:[_siuFoundationFrameworkURL URLByAppendingPathComponent:@"Versions/A/XPCServices/com.apple.SIUAgent.xpc"]];
    if ( [_siuAgentXPCURL checkResourceIsReachableAndReturnError:&error] ) {
        NSBundle *siuAgentBundle = [NSBundle bundleWithURL:_siuAgentXPCURL];
        [self setSiuAgentVersion:[siuAgentBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        [self setCreateNetInstallURL:[siuAgentBundle URLForResource:@"createNetInstall" withExtension:@"sh"]];
        [self setCreateNetBootURL:[siuAgentBundle URLForResource:@"createNetBoot" withExtension:@"sh"]];
        [self setCreateCommonURL:[siuAgentBundle URLForResource:@"createCommon" withExtension:@"sh"]];
        [self setCreateRestoreFromSourcesURL:[siuAgentBundle URLForResource:@"createRestoreFromSources" withExtension:@"sh"]];
        [self setAddBSDPSourcesURL:[siuAgentBundle URLForResource:@"addBSDPSources" withExtension:@"sh"]];
        [self setAsrInstallPkgURL:[siuAgentBundle URLForResource:@"ASRInstall" withExtension:@"pkg"]];
        [self setAsrFromVolumeURL:[siuAgentBundle URLForResource:@"asrFromVolume" withExtension:@"sh"]];
        [self setInstallConfigurationProfiles:[siuAgentBundle URLForResource:@"installConfigurationProfiles" withExtension:@"sh"]];
        [self setNetInstallConfigurationProfiles:[siuAgentBundle URLForResource:@"netInstallConfigurationProfiles" withExtension:@"sh"]];
        [self setPostInstallPackages:[siuAgentBundle URLForResource:@"postInstallPackages" withExtension:@"sh"]];
        [self setPreserveInstallLog:[siuAgentBundle URLForResource:@"preserveInstallLog" withExtension:@"sh"]];
        [self setNetBootClientHelper:[siuAgentBundle URLForResource:@"NetBootClientHelper" withExtension:@""]];
    } else {
        NSLog(@"[ERROR] %@", [error localizedDescription]);
    }
}

- (NSString *)expandVariables:(NSString *)string {
    // --------------------------------------------------------------
    //  Expand %SIUVERSION%
    // --------------------------------------------------------------
    NSString *siuVersion;
    siuVersion = _systemImageUtilityVersion;
    if ( [siuVersion length] == 0 ) {
        siuVersion = @"Unknown";
    }
    
    return [string stringByReplacingOccurrencesOfString:NBCVariableSystemImageUtilityVersion
                                                withString:siuVersion];
}

+ (NSArray *)systemImageUtilityVersions {
    
    NSArray *versions;
    return versions;
}

@end
