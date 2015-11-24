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

@property BOOL isInstalled;
@property NSString *sourceImageOSVersion;
@property NSString *selectedVersion;
@property (readonly) NSArray *dsAdminURLs;
@property NSURL *dsAdminURL;
@property NSURL *dsAssistantURL;

@property (readonly) NSString *dsAdminVersion;
@property (readonly) NSString *dsAssistantVersion;
@property (readonly) NSURL *dsBackgroundURL;
@property (readonly) NSURL *sysBuilderFolderURL;
@property (readonly) NSURL *sysBuilderURL;
@property (readonly) NSURL *sysBuilderRpURL;
@property (readonly) NSURL *sysBuilderFillVolumeURL;
@property (readonly) NSURL *sysBuilderBestRecoveryDeviceURL;

- (NSString *)expandVariables:(NSString *)string;

@end
