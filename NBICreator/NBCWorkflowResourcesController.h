//
//  NBCWorkflowResourcesController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NBCWorkflowItem;

@protocol NBCResourcesControllerDelegate
@optional
- (void)copySourceRegexComplete:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath resourceFolderPackageURL:(NSURL *)resourceFolderPackage;
- (void)copySourceRegexFailed:(NBCWorkflowItem *)workflowItem temporaryFolderURL:(NSURL *)temporaryFolderURL;
@end

@interface NBCWorkflowResourcesController : NSObject {
    id _delegate;
}

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithDelegate:(id<NBCResourcesControllerDelegate>)delegate;
- (NSURL *)cachedVersionURL:(NSString *)version resourcesFolder:(NSString *)resourcesFolder;
- (NSDictionary *)getCachedSourceItemsDict:(NSString *)buildVersion resourcesFolder:(NSString *)resourcesFolder;
- (NSURL *)copyFileToResources:(NSURL *)fileURL resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
- (NSURL *)copySourceItemToResources:(NSURL *)fileURL sourceItemPath:(NSString *)sourceItemPath resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild;
- (void)copySourceRegexToResources:(NBCWorkflowItem *)workflowItem regexArray:(NSArray *)regexArray packagePath:(NSString *)packagePath sourceFolder:(NSString *)sourceFolder resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild;
- (NSURL *)attachDiskImageAndCopyFileToResourceFolder:(NSURL *)diskImageURL filePath:(NSString *)filePath resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version;
- (NSArray *)cachedVersionsFromResourceFolder:(NSString *)resourceFolder;
- (NSDictionary *)cachedDownloadsDictFromResourceFolder:(NSString *)resourceFolder;
- (NSURL *)cachedDownloadsDictURLFromResourceFolder:(NSString *)resourceFolder;

@end
