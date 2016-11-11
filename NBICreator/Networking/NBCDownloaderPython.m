//
//  NBCDownloaderPython.m
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

#import "NBCDownloaderPython.h"
#import "TFHpple.h"
#import "NBCLog.h"

@implementation NBCDownloaderPython

- (id)initWithDelegate:(id<NBCDownloaderPythonDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)getReleaseVersionsAndURLsFromPythonRepository:(NSString *)repositoryURL downloadInfo:(NSDictionary *)downloadInfo {

    NSURL *pythonUrl = [NSURL URLWithString:repositoryURL];

    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadPageAsData:pythonUrl downloadInfo:downloadInfo];
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {

    NSMutableArray *releaseVersions = [[NSMutableArray alloc] init];
    NSMutableDictionary *releaseVersionsURLsDict = [[NSMutableDictionary alloc] init];
    NSString *versionNumber;

    NSArray *allReleases = [self parseDownloadData:data];

    for (NSString *url in allReleases) {
        versionNumber = [[url lastPathComponent] stringByReplacingOccurrencesOfString:@".dmg" withString:@""];
        versionNumber = [versionNumber componentsSeparatedByString:@"-"][1];
        versionNumber = [versionNumber componentsSeparatedByString:@"_"][0];
        [releaseVersions addObject:versionNumber];
        releaseVersionsURLsDict[versionNumber] = url;
    }

    NSSortDescriptor *sortOrder = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(self)) ascending:NO];
    NSArray *releaseVersionsSorted = [releaseVersions sortedArrayUsingDescriptors:@[ sortOrder ]];

    [_delegate pythonReleaseVersionsArray:releaseVersionsSorted downloadDict:[releaseVersionsURLsDict copy] downloadInfo:downloadInfo];
}

- (NSArray *)parseDownloadData:(NSData *)data {

    NSMutableArray *pythonDownloadURLs = [[NSMutableArray alloc] init];
    NSString *childElementText;

    TFHpple *parser = [TFHpple hppleWithHTMLData:data];

    NSString *xpathQueryString = @"//article[@class='text']/ul/li/ul/li";
    NSArray *nodes = [parser searchWithXPathQuery:xpathQueryString];

    if (!nodes) {
        NSString *downloadString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        DDLogDebug(@"[DEBUG] Download String: %@", downloadString);
    }

    for (TFHppleElement *element in nodes) {
        NSArray *children = [element children];
        for (TFHppleElement *childElement in children) {
            childElementText = [childElement text];
            if (childElementText) {
                if ([childElementText containsString:@"PPC"]) {
                    continue;
                }
                [pythonDownloadURLs addObject:childElement[@"href"]];
            }
        }
    }

    return [pythonDownloadURLs copy];
}

@end
