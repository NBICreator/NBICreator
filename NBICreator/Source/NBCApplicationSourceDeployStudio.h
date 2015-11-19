//
//  NBCDeployStudioSource.h
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

@interface NBCApplicationSourceDeployStudio : NSObject

// Source Image
@property NSString *sourceImageOSVersion;

@property BOOL isSupported;
@property BOOL isInstalled;

@property NSBundle *deployStudioAdminBundle;
@property NSBundle *deployStudioAssistantBundle;

// DeployStudio
@property NSString *selectedVersion;
@property NSURL *deployStudioAdminURL;
@property NSURL *deployStudioAssistantURL;
@property NSString *deployStudioAdminVersion;
@property NSString *deployStudioAssistantVersion;
@property NSArray *deployStudioVersionsSupported;
@property NSArray *deployStudioAdminURLs;

// SysBuilder
@property NSURL *deployStudioBackgroundURL;
@property NSURL *sysBuilderFolder;
@property NSURL *sysBuilderScript;
@property NSURL *sysBuilderScriptRp;
@property NSURL *sysBuilderScriptFillVolume;
@property NSURL *sysBuilderScriptBestRecoveryDevice;

// Methods
- (NSString *)expandVariables:(NSString *)string;
+ (NSArray *)deployStudioAdminVersions;

- (NSURL *)urlForDSAdminResource:(NSString *)resource extension:(NSString *)extension;

@end
