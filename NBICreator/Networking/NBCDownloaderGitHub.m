//
//  NBCDownloaderGitHub.m
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

#import "NBCConstants.h"
#import "NBCDownloaderGitHub.h"
#import "NBCLog.h"

@implementation NBCDownloaderGitHub

- (id)initWithDelegate:(id<NBCDownloaderGitHubDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)getReleaseVersionsAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"[DEBUG] GitHub repository name: %@", repository);
    NSString *githubURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases", repository];
    DDLogDebug(@"[DEBUG] GitHub repository releases URL: %@", githubURL);
    NSMutableDictionary *downloadInfoMutable = [[NSMutableDictionary alloc] initWithDictionary:downloadInfo];
    [downloadInfoMutable setObject:repository forKey:NBCDownloaderTagGitRepoName];
    [downloadInfoMutable setObject:NBCDownloaderTagGitRepoPathReleases forKey:NBCDownloaderTagGitRepoPath];
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:[NSURL URLWithString:githubURL] downloadInfo:[downloadInfoMutable copy]];
}

- (void)getBranchesAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"[DEBUG] GitHub repository name: %@", repository);
    NSString *githubURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/branches", repository];
    DDLogDebug(@"[DEBUG] GitHub repository branches URL: %@", githubURL);
    NSMutableDictionary *downloadInfoMutable = [[NSMutableDictionary alloc] initWithDictionary:downloadInfo];
    [downloadInfoMutable setObject:repository forKey:NBCDownloaderTagGitRepoName];
    [downloadInfoMutable setObject:NBCDownloaderTagGitRepoPathBranches forKey:NBCDownloaderTagGitRepoPath];
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:[NSURL URLWithString:githubURL] downloadInfo:[downloadInfoMutable copy]];
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"[DEBUG] Download completed!");
    if ([downloadInfo objectForKey:NBCDownloaderTagGitRepoPath] == NBCDownloaderTagGitRepoPathReleases) {
        NSMutableArray *releaseVersions = [[NSMutableArray alloc] init];
        NSMutableDictionary *releaseVersionsURLsDict = [[NSMutableDictionary alloc] init];
        NSArray *allReleases = [self convertJSONDataToArray:data];

        for (NSDictionary *dict in allReleases) {
            NSString *versionNumber = [dict[@"tag_name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
            [releaseVersions addObject:versionNumber];

            NSArray *assets = dict[@"assets"];
            NSDictionary *assetsDict = [assets firstObject];
            NSString *downloadURL = assetsDict[@"browser_download_url"];
            releaseVersionsURLsDict[versionNumber] = downloadURL;
        }

        [_delegate githubReleaseVersionsArray:[releaseVersions copy] downloadDict:[releaseVersionsURLsDict copy] downloadInfo:downloadInfo];
    } else if ([downloadInfo objectForKey:NBCDownloaderTagGitRepoPath] == NBCDownloaderTagGitRepoPathBranches) {
        NSString *repoName = downloadInfo[NBCDownloaderTagGitRepoName];
        NSMutableArray *branches = [[NSMutableArray alloc] init];
        NSMutableDictionary *branchesURLsDict = [[NSMutableDictionary alloc] init];
        NSArray *allBranches = [self convertJSONDataToArray:data];
        for (NSDictionary *dict in allBranches) {
            NSString *name = [dict[@"name"] capitalizedString];
            [branches addObject:name];

            NSString *downloadURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/zipball/%@", repoName, [name lowercaseString]];

            NSDictionary *commitDict = dict[@"commit"];
            NSString *sha = commitDict[@"sha"];
            if ([sha length] != 0) {
                NSDictionary *brancDict = @{ @"sha" : sha, @"url" : downloadURL };
                branchesURLsDict[name] = brancDict;
            } else {
                DDLogError(@"[ERROR] Could not get SHA from git branch: %@", name);
            }
        }
        [_delegate githubBranchesArray:[branches copy] downloadDict:[branchesURLsDict copy] downloadInfo:downloadInfo];
    }
}

- (NSArray *)convertJSONDataToArray:(NSData *)data {
    if (data != nil) {
        NSError *error;
        id jsonDataArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if ([jsonDataArray isKindOfClass:[NSArray class]]) {
            return jsonDataArray;
        } else if (jsonDataArray == nil) {
            DDLogError(@"[ERROR] Serializing JSON Data failed!");
            DDLogError(@"[ERROR] %@", error);
        }
    }
    return nil;
}

@end
