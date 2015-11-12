//
//  NBCTarget.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCTarget.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCTarget

- (void)resetAllVariables {
    [self setResourcesNetInstallDict:nil];
    [self setResourcesBaseSystemDict:nil];
    [self setCreationTool:nil];
    [self setNbiURL:nil],
    [self setImagrApplicationExistOnTarget:NO];
    [self setImagrApplicationURL:nil];
    [self setImagrConfigurationPlistURL:nil];
    [self setRcImagingURL:nil];
    [self setRcImagingContent:nil];
    [self setCasperImagingApplicationURL:nil];
    [self setCasperJSSPreferencePlistURL:nil];
    [self setNbiNetInstallDisk:nil];
    [self setNbiNetInstallURL:nil];
    [self setNbiNetInstallShadowPath:nil];
    [self setNbiNetInstallVolumeURL:nil];
    [self setNbiNetInstallDiskImageDict:nil];
    [self setNbiNetInstallVolumeBSDIdentifier:nil];
    [self setBaseSystemDisk:nil];
    [self setBaseSystemURL:nil];
    [self setBaseSystemShadowPath:nil];
    [self setBaseSystemVolumeURL:nil];
    [self setBaseSystemDiskImageDict:nil];
    [self setBaseSystemVolumeBSDIdentifier:nil];
}

- (void)printAllVariables
{
    DDLogDebug(@"resourcesNetInstallDict=%@", _resourcesNetInstallDict);
    DDLogDebug(@"resourcesBaseSystemDict=%@", _resourcesBaseSystemDict);
    DDLogDebug(@"nbiNetInstallDisk=%@", _nbiNetInstallDisk);
    DDLogDebug(@"nbiNetInstallURL=%@", _nbiNetInstallURL);
    DDLogDebug(@"nbiNetInstallVolumeURL=%@", _nbiNetInstallVolumeURL);
    DDLogDebug(@"nbiNetInstallDiskImageDict=%@", _nbiNetInstallDiskImageDict);
    DDLogDebug(@"nbiNetInstallVolumeBSDIdentifier=%@", _nbiNetInstallVolumeBSDIdentifier);
    DDLogDebug(@"baseSystemDisk=%@", _baseSystemDisk);
    DDLogDebug(@"baseSystemURL=%@", _baseSystemURL);
    DDLogDebug(@"baseSystemVolumeURL=%@", _baseSystemVolumeURL);
    DDLogDebug(@"baseSystemDiskImageDict=%@", _baseSystemDiskImageDict);
    DDLogDebug(@"baseSystemVolumeBSDIdentifier=%@", _baseSystemVolumeBSDIdentifier);
}

@end
