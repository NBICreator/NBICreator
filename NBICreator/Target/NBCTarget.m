//
//  NBCTarget.m
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

#import "NBCLogging.h"
#import "NBCTarget.h"

DDLogLevel ddLogLevel;

@implementation NBCTarget

- (void)resetAllVariables {
    [self setResourcesNetInstallDict:nil];
    [self setResourcesBaseSystemDict:nil];
    [self setCreationTool:nil];
    [self setNbiURL:nil], [self setImagrApplicationExistOnTarget:NO];
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

- (void)printAllVariables {
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
