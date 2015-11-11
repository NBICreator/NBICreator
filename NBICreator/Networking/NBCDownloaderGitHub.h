//
//  NBCDownloaderGitHub.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCDownloader.h"

@protocol NBCDownloaderGitHubDelegate
@optional
- (void)githubReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo;
- (void)githubBranchesArray:(NSArray *)branchesArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo;
@end

@interface NBCDownloaderGitHub : NSObject <NBCDownloaderDelegate> {
    id _delegate;
}

- (id)initWithDelegate:(id<NBCDownloaderGitHubDelegate>)delegate;
- (void)getReleaseVersionsAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo;
- (void)getBranchesAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo;

@end
