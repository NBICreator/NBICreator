//
//  NBCDownloaderPython.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCDownloader.h"

@protocol NBCDownloaderPythonDelegate
@optional
- (void)pythonReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo;
@end

@interface NBCDownloaderPython : NSObject <NBCDownloaderDelegate> {
    id _delegate;
}

- (id)initWithDelegate:(id<NBCDownloaderPythonDelegate>)delegate;
- (void)getReleaseVersionsAndURLsFromPythonRepository:(NSString *)repository downloadInfo:(NSDictionary *)downloadInfo;

@end
