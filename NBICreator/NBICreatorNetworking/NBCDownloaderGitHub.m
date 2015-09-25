//
//  NBCDownloaderGitHub.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDownloaderGitHub.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCDownloaderGitHub

- (id)initWithDelegate:(id<NBCDownloaderGitHubDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)getReleaseVersionsAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo {
    NSString *githubURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/releases", repository];
    NSMutableDictionary *downloadInfoMutable = [[NSMutableDictionary alloc] initWithDictionary:downloadInfo];
    [downloadInfoMutable setObject:repository forKey:NBCDownloaderTagGitRepoName];
    [downloadInfoMutable setObject:NBCDownloaderTagGitRepoPathReleases forKey:NBCDownloaderTagGitRepoPath];
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:[NSURL URLWithString:githubURL] downloadInfo:[downloadInfoMutable copy]];
}

- (void)getBranchesAndURLsFromGithubRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo {
    NSString *githubURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/branches", repository];
    NSMutableDictionary *downloadInfoMutable = [[NSMutableDictionary alloc] initWithDictionary:downloadInfo];
    [downloadInfoMutable setObject:repository forKey:NBCDownloaderTagGitRepoName];
    [downloadInfoMutable setObject:NBCDownloaderTagGitRepoPathBranches forKey:NBCDownloaderTagGitRepoPath];
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:[NSURL URLWithString:githubURL] downloadInfo:[downloadInfoMutable copy]];
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {
    if ( [downloadInfo objectForKey:NBCDownloaderTagGitRepoPath] == NBCDownloaderTagGitRepoPathReleases ) {
        NSMutableArray *releaseVersions = [[NSMutableArray alloc] init];
        NSMutableDictionary *releaseVersionsURLsDict = [[NSMutableDictionary alloc] init];
        NSArray *allReleases = [self convertJSONDataToArray:data];
        
        for ( NSDictionary *dict in allReleases ) {
            NSString *versionNumber = [dict[@"tag_name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
            [releaseVersions addObject:versionNumber];
            
            NSArray *assets = dict[@"assets"];
            NSDictionary *assetsDict = [assets firstObject];
            NSString *downloadURL = assetsDict[@"browser_download_url"];
            releaseVersionsURLsDict[versionNumber] = downloadURL;
        }
        
        [_delegate githubReleaseVersionsArray:[releaseVersions copy] downloadDict:[releaseVersionsURLsDict copy] downloadInfo:downloadInfo];
    } else if ( [downloadInfo objectForKey:NBCDownloaderTagGitRepoPath] == NBCDownloaderTagGitRepoPathBranches ) {
        NSString *repoName = downloadInfo[NBCDownloaderTagGitRepoName];
        NSMutableArray *branches = [[NSMutableArray alloc] init];
        NSMutableDictionary *branchesURLsDict = [[NSMutableDictionary alloc] init];
        NSArray *allBranches = [self convertJSONDataToArray:data];
        for ( NSDictionary *dict in allBranches ) {
            NSString *name = [dict[@"name"] capitalizedString];
            [branches addObject:name];
            
            NSString *downloadURL = [NSString stringWithFormat:@"https://api.github.com/repos/%@/zipball/%@", repoName, [name lowercaseString]];
            
            NSDictionary *commitDict = dict[@"commit"];
            NSString *sha = commitDict[@"sha"];
            if ( [sha length] != 0 ) {
                NSDictionary *brancDict = @{
                                            @"sha" : sha,
                                            @"url" : downloadURL
                                            };
                branchesURLsDict[name] = brancDict;
            } else {
                DDLogError(@"[ERROR] Could not get SHA from git branch: %@", name);
            }
        }
        [_delegate githubBranchesArray:[branches copy] downloadDict:[branchesURLsDict copy] downloadInfo:downloadInfo];
    }
}

- (NSArray *)convertJSONDataToArray:(NSData *)data {
    if ( data != nil ) {
        NSError *error;
        
        id jsonDataArray = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        
        if ( [jsonDataArray isKindOfClass:[NSArray class]] ) {
            return jsonDataArray;
        } else if ( jsonDataArray == nil ) {
            NSLog(@"Error when serializing JSONData: %@.", error);
        }
    }
    return nil;
}

@end
