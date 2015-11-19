//
//  NBCTarget.h
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

#import <Foundation/Foundation.h>

#import "NBCDisk.h"

@interface NBCTarget : NSObject

@property NSDictionary *resourcesNetInstallDict;
@property NSDictionary *resourcesBaseSystemDict;

@property NSString *creationTool;

@property NSURL *nbiURL;
@property BOOL imagrApplicationExistOnTarget;
@property NSURL *imagrApplicationURL;
@property NSURL *imagrConfigurationPlistURL;
@property NSURL *rcImagingURL;
@property NSString *rcImagingContent;

@property NSURL *casperImagingApplicationURL;
@property NSURL *casperJSSPreferencePlistURL;

// Source NBI NetInstall
@property NBCDisk *nbiNetInstallDisk;
@property NSURL *nbiNetInstallURL;
@property NSString *nbiNetInstallShadowPath;
@property NSURL *nbiNetInstallVolumeURL;
@property NSDictionary *nbiNetInstallDiskImageDict;
@property NSString *nbiNetInstallVolumeBSDIdentifier;

// Soruce NBI BaseSystem
@property NBCDisk *baseSystemDisk;
@property NSURL *baseSystemURL;
@property NSString *baseSystemShadowPath;
@property NSURL *baseSystemVolumeURL;
@property NSDictionary *baseSystemDiskImageDict;
@property NSString *baseSystemVolumeBSDIdentifier;

- (void)resetAllVariables;
- (void)printAllVariables;

@end
