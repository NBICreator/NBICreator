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
- (void)copySourceRegexComplete:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath resourceFolderPackageURL:(NSURL *)resourceFolderPackage;
- (void)copySourceRegexFailed:(NBCWorkflowItem *)workflowItem temporaryFolderURL:(NSURL *)temporaryFolderURL error:(NSError *)error;
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
- (NSDictionary *)getCachedSourceItemsDict:(NSString *)buildVersion resourcesFolder:(NSString *)resourcesFolder;
+ (NSURL *)copyFileToResources:(NSURL *)fileURL resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
- (NSURL *)copySourceItemToResources:(NSURL *)fileURL sourceItemPath:(NSString *)sourceItemPath resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild;
- (void)copySourceRegexToResources:(NBCWorkflowItem *)workflowItem regexArray:(NSArray *)regexArray packagePath:(NSString *)packagePath sourceFolder:(NSString *)sourceFolder resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild;
+ (NSURL *)attachDiskImageAndCopyFileToResourceFolder:(NSURL *)diskImageURL filePath:(NSString *)filePath resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
- (NSArray *)cachedVersionsFromResourceFolder:(NSString *)resourceFolder;
- (NSDictionary *)cachedDownloadsDictFromResourceFolder:(NSString *)resourceFolder;
- (NSURL *)cachedDownloadsDictURLFromResourceFolder:(NSString *)resourceFolder;
+ (NSURL *)urlForResourceFolder:(NSString *)resourceFolder;
+ (NSURL *)unzipAndCopyGitBranchToResourceFolder:(NSURL *)zipURL resourcesFolder:(NSString *)resourcesFolder branchDict:(NSDictionary *)branchDict;
- (void)buildProjectAtURL:(NSURL *)projectURL buildTarget:(NSString *)buildTarget;
+ (NSURL *)packageTemporaryFolderURL:(NBCWorkflowItem *)workflowItem;

@end
