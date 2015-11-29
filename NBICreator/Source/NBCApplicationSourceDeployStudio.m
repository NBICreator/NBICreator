//
//  NBCDeployStudioSource.m
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

#import "NBCApplicationSourceDeployStudio.h"
#import "NBCSource.h"
//#import "NBCLogging.h"

//DDLogLevel ddLogLevel;

@implementation NBCApplicationSourceDeployStudio

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Init / Dealloc
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super init];
    if (self) {
        [self selectLatestVersion];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get Versions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)selectLatestVersion {
    
    NSInteger latestVersionCleaned = 0;
    NSURL *latestVersionURL;
    for ( NSURL *dsAdminURL in [self dsAdminURLs] ) {
        NSString *dsAdminVersion = [[NSBundle bundleWithURL:dsAdminURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        NSString *dsAdminVersionCleaned = [dsAdminVersion stringByReplacingOccurrencesOfString:@"." withString:@""];
        if ( latestVersionCleaned < [dsAdminVersionCleaned integerValue]) {
            latestVersionCleaned = [dsAdminVersionCleaned integerValue];
            latestVersionURL = dsAdminURL;
        }
    }
    
    //NSError *error = nil;

    if ( [latestVersionURL checkResourceIsReachableAndReturnError:nil] ) {
        [self setIsInstalled:YES];
        [self setDsAdminURL:latestVersionURL];
        if ( [[latestVersionURL URLByAppendingPathComponent:@"Contents/Applications/DeployStudio Assistant.app"] checkResourceIsReachableAndReturnError:nil] ) {
            [self setDsAssistantURL:[latestVersionURL URLByAppendingPathComponent:@"Contents/Applications/DeployStudio Assistant.app"]];
        } else {
            [self setDsAssistantURL:nil];
            [self setDsAdminURL:nil];
            [self setIsInstalled:NO];
            //DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        //DDLogError(@"[ERROR] %@", [error localizedDescription]);
        [self setIsInstalled:NO];
    }
}

- (NSString *)dsAdminVersion {
    return [[self dsAdminBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
} // dsAdminVersion

- (NSString *)dsAssistantVersion {
    return [[self dsAssistantBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
} // dsAssistantVersion

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSBundle *)dsAdminBundle {
    return [NSBundle bundleWithURL:_dsAdminURL];
} // dsAdminBundle

- (NSBundle *)dsAssistantBundle {
    return [NSBundle bundleWithURL:_dsAssistantURL];
} // dsAssistantBundle

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get URLs
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSURL *)urlForDSAdminResourceNamed:(NSString *)resourceName {
    return [[self dsAdminBundle] URLForResource:[resourceName stringByDeletingPathExtension] withExtension:[resourceName pathExtension]];
} // urlForDSAdminResourceNamed

- (NSURL *)urlForDSAssistantResourceNamed:(NSString *)resourceName {
    return [[self dsAssistantBundle] URLForResource:[resourceName stringByDeletingPathExtension] withExtension:[resourceName pathExtension]];
} // urlForDSAssistantResourceNamed

- (NSArray *)dsAdminURLs {
    return (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.deploystudio.admin"), NULL));
} // dsAdminURLs

- (NSURL *)sysBuilderFolderURL {
    return [_dsAssistantURL URLByAppendingPathComponent:@"Contents/Resources/sysBuilder"];
} // sysBuilderFolderURL

- (NSURL *)sysBuilderURL {
    return [[self sysBuilderFolderURL] URLByAppendingPathComponent:@"sys_builder.sh"];
} // sysBuilderURL

- (NSURL *)sysBuilderRpURL {
    return [[self sysBuilderFolderURL] URLByAppendingPathComponent:@"sys_builder_rp.sh"];
} // sysBuilderRpURL

- (NSURL *)sysBuilderBestRecoveryDeviceURL {
    return [[self sysBuilderFolderURL] URLByAppendingPathComponent:@"netboot_helpers/ds_best_recovery_device_info.sh"];
} // sysBuilderBestRecoveryDeviceURL

- (NSURL *)sysBuilderFillVolumeURL {
    if ( [_sourceImageOSVersion length] != 0 ) {
        return [[self sysBuilderFolderURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/fill_volume.sh", _sourceImageOSVersion]];
    } else {
        return nil;
    }
} // sysBuilderFillVolumeURL

- (NSURL *)dsBackgroundURL {
    return [[self sysBuilderFolderURL] URLByAppendingPathComponent:@"common/DefaultDesktop.jpg"];
} // dsBackgroundURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Hashes
#pragma mark -
////////////////////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Expand Variables
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSString *)expandVariables:(NSString *)string {
    
    // --------------------------------------------------------------
    //  Expand %DSVERSION%
    // --------------------------------------------------------------
    NSString *expandedString = [string stringByReplacingOccurrencesOfString:@"%DSVERSION%"
                                               withString:[[self dsAdminBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"Unknown"];
    
    // --------------------------------------------------------------
    //  Expand %DSADMINURL%
    // --------------------------------------------------------------
    expandedString = [expandedString stringByReplacingOccurrencesOfString:@"%DSADMINURL%"
                                               withString:[_dsAdminURL path] ?: @"Unknown"];
    
    // --------------------------------------------------------------
    //  Expand %NBITOOL%
    // --------------------------------------------------------------
    expandedString = [expandedString stringByReplacingOccurrencesOfString:@"%NBITOOL%"
                                               withString:@"DSA"];
    
    return expandedString;
}

@end
