//
//  NBCDeployStudioSource.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-03-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioSource.h"

#import "NBCSource.h"

@implementation NBCDeployStudioSource

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateSource:)
                                                     name:@"updateImageSource"
                                                   object:nil];
        
        _deployStudioVersionsSupported = @[
                                           @"1.6.12",
                                           @"1.6.13",
                                           ];
        [self getDeployStudioURL];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *)deployStudioApplicationURLs {
    
    NSMutableArray *deployStudioApplicationURLs = [[NSMutableArray alloc] init];
    
    [deployStudioApplicationURLs addObjectsFromArray:(__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.deploystudio.admin"), NULL))];
    
    return [deployStudioApplicationURLs copy];
}

- (void)getDeployStudioURL {
    NSError *error;
    NSArray *deployStudioApplicationURLs = [self deployStudioApplicationURLs];
    
    NSURL *dsAdminURL = [deployStudioApplicationURLs firstObject];
    
    if ( dsAdminURL ) {
        [self setDeployStudioAdminURL:dsAdminURL];
        if ( [_deployStudioAdminURL checkResourceIsReachableAndReturnError:&error] ) {
            [self setIsInstalled:YES];
            [self deployStudioResourcesFromAdminURL];
        } else  {
            [self setIsInstalled:NO];
            NSLog(@"DSAssistant Doesn't exist! %@", error);
        }
    }
}

- (void)deployStudioResourcesFromAdminURL {
    [self setDeployStudioAdminVersion:[[NSBundle bundleWithURL:_deployStudioAdminURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    if ( ! [_deployStudioVersionsSupported containsObject:_deployStudioAdminVersion] ) {
        [self setIsSupported:NO];
    } else {
        [self setIsSupported:YES];
    }
    
    [self setDeployStudioAssistantURL:[_deployStudioAdminURL URLByAppendingPathComponent:@"Contents/Applications/DeployStudio Assistant.app"]];
    NSError *error;
    if ( [_deployStudioAssistantURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setDeployStudioAssistantVersion:[[NSBundle bundleWithURL:_deployStudioAssistantURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
        
        [self setSysBuilderFolder:[_deployStudioAssistantURL URLByAppendingPathComponent:@"Contents/Resources/sysBuilder"]];
        [self setSysBuilderScript:[_sysBuilderFolder URLByAppendingPathComponent:@"sys_builder.sh"]];
        [self setSysBuilderScriptFillVolume:[_sysBuilderFolder URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/fill_volume.sh", _sourceImageOSVersion]]];
        [self setSysBuilderScriptBestRecoveryDevice:[_sysBuilderFolder URLByAppendingPathComponent:@"netboot_helpers/ds_best_recovery_device_info.sh"]];
        [self setDeployStudioBackgroundURL:[_sysBuilderFolder URLByAppendingPathComponent:@"common/DefaultDesktop.jpg"]];
    } else {
        [self setIsInstalled:NO];
        NSLog(@"DSAssistant Doesn't exist! %@", error);
    }
    
}

- (void)updateSource:(NSNotification *)notification {
    NBCSource *source = [notification userInfo][@"currentSource"];
    NSString *variableString = @"%OSMAJOR%.%OSMINOR%";
    if ( source != nil ) {
        [self setSourceImageOSVersion:[source expandVariables:variableString]];
    }
}

- (NSString *)expandVariables:(NSString *)string {
    NSString *newString = string;
    NSString *variableDSVersion = @"%DSVERSION%";
    NSString *variableDSAdmin = @"%DSADMINURL%";
    
    // --------------------------------------------------------------
    //  Expand %DSVERSION%
    // --------------------------------------------------------------
    NSString *dsVersion;
    dsVersion = _deployStudioAdminVersion;
    if ( [dsVersion length] == 0 ) {
        dsVersion = @"Unknown";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableDSVersion
                                                     withString:dsVersion];
    
    // --------------------------------------------------------------
    //  Expand %DSVERSION%
    // --------------------------------------------------------------
    NSString *dsAdminPath;
    dsAdminPath = [_deployStudioAdminURL path];
    if ( [dsAdminPath length] == 0 ) {
        dsAdminPath = @"Unknown";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:variableDSAdmin
                                                     withString:dsAdminPath];
    
    return newString;
}

+ (NSArray *)deployStudioAdminVersions {
    NSArray *versions;
    return versions;
}

@end
