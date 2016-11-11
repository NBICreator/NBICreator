//
//  NBCDownloaderDeployStudio.m
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
#import "NBCDownloaderDeployStudio.h"
#import "TFHpple.h"
#import "NBCLog.h"

@implementation NBCDownloaderDeployStudio

- (id)initWithDelegate:(id<NBCDownloaderDeployStudioDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)getReleaseVersionsAndURLsFromDeployStudioRepository:(NSString *)repositoryURL downloadInfo:(NSDictionary *)downloadInfo {

    NSURL *dsRepositoryUrl = [NSURL URLWithString:repositoryURL];

    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:dsRepositoryUrl downloadInfo:downloadInfo];
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {

    NSMutableArray *releaseVersions = [[NSMutableArray alloc] init];
    NSMutableDictionary *releaseVersionsURLsDict = [[NSMutableDictionary alloc] init];
    NSString *versionNumber;

    NSArray *allReleases = [self parseDownloadData:data];

    for (NSString *url in allReleases) {
        versionNumber = [[url lastPathComponent] stringByReplacingOccurrencesOfString:@".dmg" withString:@""];
        versionNumber = [[versionNumber componentsSeparatedByString:@"_"] lastObject];
        versionNumber = [versionNumber substringFromIndex:1];
        [releaseVersions addObject:versionNumber];
        releaseVersionsURLsDict[versionNumber] = url;
    }

    NSSortDescriptor *sortOrder = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(self)) ascending:NO];
    NSArray *releaseVersionsSorted = [releaseVersions sortedArrayUsingDescriptors:@[ sortOrder ]];

    [_delegate dsReleaseVersionsArray:releaseVersionsSorted downloadDict:[releaseVersionsURLsDict copy] downloadInfo:downloadInfo];
}

- (NSArray *)parseDownloadData:(NSData *)data {

    NSMutableArray *dsDownloadURLs = [[NSMutableArray alloc] init];
    NSString *childElementContent;

    TFHpple *parser = [TFHpple hppleWithHTMLData:data];

    NSString *xpathQueryString = @"//table/tr";
    NSArray *nodes = [parser searchWithXPathQuery:xpathQueryString];

    if (!nodes) {
        NSString *downloadString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        DDLogDebug(@"[DEBUG] Download String: %@", downloadString);
    }

    for (TFHppleElement *element in nodes) {
        NSArray *children = [element children];
        for (TFHppleElement *childElement in children) {
            childElementContent = [childElement content];
            if ([childElementContent hasPrefix:@"DeployStudioServer"]) {
                NSString *downloadURL = [NSString stringWithFormat:@"%@/%@", NBCDeployStudioRepository, childElementContent];
                [dsDownloadURLs addObject:downloadURL];
            }
        }
    }

    return [dsDownloadURLs copy];
}

@end
