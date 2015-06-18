//
//  NBCDownloaderDeployStudio.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-20.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCDownloader.h"

@protocol NBCDownloaderDeployStudioDelegate
@optional
- (void)dsReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo;
@end

@interface NBCDownloaderDeployStudio : NSObject <NBCDownloaderDelegate> {
    id _delegate;
}

- (id)initWithDelegate:(id<NBCDownloaderDeployStudioDelegate>)delegate;
- (void)getReleaseVersionsAndURLsFromDeployStudioRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo;

@end
