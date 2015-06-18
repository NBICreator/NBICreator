//
//  NBCDownloaderDeployStudio.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-20.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDownloaderDeployStudio.h"
#import "NBCConstants.h"
#import "TFHpple.h"

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
    
    for ( NSString *url in allReleases ) {
        versionNumber = [[url lastPathComponent] stringByReplacingOccurrencesOfString:@".dmg" withString:@""];
        versionNumber = [[versionNumber componentsSeparatedByString:@"_"] lastObject];
        versionNumber = [versionNumber substringFromIndex:1];
        [releaseVersions addObject:versionNumber];
        releaseVersionsURLsDict[versionNumber] = url;
    }
    
    NSSortDescriptor* sortOrder = [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(self)) ascending: NO];
    NSArray *releaseVersionsSorted = [releaseVersions sortedArrayUsingDescriptors:@[ sortOrder ]];
    
    [_delegate dsReleaseVersionsArray:releaseVersionsSorted downloadDict:[releaseVersionsURLsDict copy] downloadInfo:downloadInfo];
}

- (NSArray *)parseDownloadData:(NSData *)data {
    NSMutableArray *dsDownloadURLs = [[NSMutableArray alloc] init];
    NSString *childElementContent;
    
    TFHpple *parser = [TFHpple hppleWithHTMLData:data];
    
    NSString *xpathQueryString = @"//table/tr";
    NSArray *nodes = [parser searchWithXPathQuery:xpathQueryString];
    
    if ( ! nodes ) {
        NSString *downloadString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"downloadString=%@", downloadString);
    }
    
    for ( TFHppleElement *element in nodes ) {
        NSArray *children = [element children];
        for (TFHppleElement *childElement in children) {
            childElementContent = [childElement content];
            if ( [childElementContent hasPrefix:@"DeployStudioServer"] ) {
                NSString *downloadURL = [NSString stringWithFormat:@"%@/%@", NBCDeployStudioRepository, childElementContent];
                [dsDownloadURLs addObject:downloadURL];
            }
        }
    }
    
    return [dsDownloadURLs copy];
}

@end
