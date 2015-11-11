//
//  NBCWorkflowResourcesController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Main.h"

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
