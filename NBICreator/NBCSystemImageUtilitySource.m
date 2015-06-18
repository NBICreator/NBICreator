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

@implementation NBCSystemImageUtilitySource

- (id)init {
    self = [super init];
    if (self) {
        _systemImageUtilityVersionsSupported = @[
                                                 @"10.10.2",
                                                 @"10.10.3"
                                                 ];
        [self setSystemImageUtilityURL];
    }
    return self;
}

- (NSArray *)systemImageUtilityURLs {
    
    NSMutableArray *systemImageUtilityURLs = [[NSMutableArray alloc] init];
    
    [systemImageUtilityURLs addObjectsFromArray:(__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.apple.SystemImageUtility"), NULL))];
    
    return [systemImageUtilityURLs copy];
}

- (void)setSystemImageUtilityURL {
    NSArray *systemImageUtilityURLs = [self systemImageUtilityURLs];
    
    NSURL *systemImageUtilityURL = [systemImageUtilityURLs firstObject];
    
    NSError *error;
    _systemImageUtilityURL = systemImageUtilityURL;
    if ( [_systemImageUtilityURL checkResourceIsReachableAndReturnError:&error] )
    {
        [self systemImageUtilityResourcesFromURL:_systemImageUtilityURL];
    } else {
        NSLog(@"System Image Utility Doesn't exist!_ %@", error);
    }
}

- (void)systemImageUtilityResourcesFromURL:(NSURL *)systemImageUtilityURL {
    NSError *error;
    
    [self setSystemImageUtilityVersion:[[NSBundle bundleWithURL:systemImageUtilityURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    [self setSelectedVersion:_systemImageUtilityVersion];
    if ( ! [_systemImageUtilityVersionsSupported containsObject:_systemImageUtilityVersion] ) {
        [self setIsSupported:NO];
    } else {
        [self setIsSupported:YES];
    }
    
    [self setSiuFoundationFrameworkURL:[[[NSBundle bundleWithURL:_systemImageUtilityURL] privateFrameworksURL] URLByAppendingPathComponent:@"SIUFoundation.framework"]];
    if ( [_siuFoundationFrameworkURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setSiuFoundationVersion:[[NSBundle bundleWithURL:_siuFoundationFrameworkURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    } else {
        NSLog(@"SIUFoundation.framework Doesn't exist!_ %@", error);
    }
    
    [self setSiuAgentXPCURL:[_siuFoundationFrameworkURL URLByAppendingPathComponent:@"Versions/A/XPCServices/com.apple.SIUAgent.xpc"]];
    if ( [_siuAgentXPCURL checkResourceIsReachableAndReturnError:&error] ) {
        NSBundle *siuAgentBundle = [NSBundle bundleWithURL:_siuAgentXPCURL];
        [self setSiuAgentVersion:[siuAgentBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        [self setCreateNetInstallURL:[siuAgentBundle URLForResource:@"createNetInstall" withExtension:@"sh"]];
        [self setCreateNetBootURL:[siuAgentBundle URLForResource:@"createNetBoot" withExtension:@"sh"]];
        [self setCreateCommonURL:[siuAgentBundle URLForResource:@"createCommon" withExtension:@"sh"]];
    } else {
        NSLog(@"SIUFoundation.framework Doesn't exist!_ %@", error);
    }
}

- (NSString *)expandVariables:(NSString *)string {
    NSString *newString = string;
    NSString *variableSIUVersion = @"%SIUVERSION%";
    
    // --------------------------------------------------------------
    //  Expand %DSVERSION%
    // --------------------------------------------------------------
    NSString *siuVersion;
    siuVersion = _systemImageUtilityVersion;
    if ( [siuVersion length] == 0 ) {
        siuVersion = @"Unknown";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableSIUVersion
                                               withString:siuVersion];
    
    return newString;
}

+ (NSArray *)systemImageUtilityVersions {
    NSArray *versions;
    return versions;
}

@end
