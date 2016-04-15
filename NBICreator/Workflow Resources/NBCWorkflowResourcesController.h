//
//  NBCWorkflowResourcesController.h
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

#import "Main.h"
#import <Foundation/Foundation.h>

@class NBCWorkflowItem;

@protocol NBCResourcesControllerDelegate
@optional
- (void)xcodeBuildComplete:(NSURL *)productURL;
- (void)xcodeBuildFailed:(NSString *)errorOutput;
@end

@interface NBCWorkflowResourcesController : NSObject <ZipArchiveDelegate> {
    id _delegate;
}

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithDelegate:(id<NBCResourcesControllerDelegate>)delegate;
+ (NSURL *)cachedVersionURL:(NSString *)version resourcesFolder:(NSString *)resourcesFolder;
+ (NSURL *)cachedBranchURL:(NSString *)branch sha:(NSString *)sha resourcesFolder:(NSString *)resourcesFolder;
+ (NSURL *)urlForResourceFolder:(NSString *)resourceFolder;
+ (NSURL *)packageTemporaryFolderURL:(NBCWorkflowItem *)workflowItem;
+ (NSURL *)attachDiskImageAndCopyFileToResourceFolder:(NSURL *)diskImageURL filePath:(NSString *)filePath resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
+ (NSURL *)copyFileToResources:(NSURL *)fileURL resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
+ (NSURL *)unzipAndCopyGitBranchToResourceFolder:(NSURL *)zipURL resourcesFolder:(NSString *)resourcesFolder branchDict:(NSDictionary *)branchDict;

- (NSArray *)cachedVersionsFromResourceFolder:(NSString *)resourceFolder;
- (NSDictionary *)cachedDownloadsDictFromResourceFolder:(NSString *)resourceFolder;
- (NSURL *)cachedDownloadsDictURLFromResourceFolder:(NSString *)resourceFolder;

- (void)buildProjectAtURL:(NSURL *)projectURL buildTarget:(NSString *)buildTarget;

@end
