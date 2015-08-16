//
//  NBCDownloader.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-14.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NBCDownloaderDelegate
@optional
- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo;
- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo;
- (void)updateProgressBytesRecieved:(float)bytesRecieved expectedLength:(long long)expectedLength downloadInfo:(NSDictionary *)downloadInfo;
- (void)downloadCanceled:(NSDictionary *)downloadInfo;
@end

@interface NBCDownloader : NSObject <NSURLDownloadDelegate, NSURLConnectionDelegate> {
    id _delegate;
}

// -------------------------------------------------------------
//  Unsorted
// -------------------------------------------------------------
@property float bytesRecieved;
@property NSDictionary *downloadInfo;
@property NSString *destinationFolder;
@property NSString *destinationPath;
@property NSURLResponse *downloadResponseTest;
@property NSMutableData *downloadData;

@property NSURLRequest *request;
@property NSURLDownload *download;

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithDelegate:(id<NBCDownloaderDelegate>)delegate;
- (void)downloadFileFromURL:(NSURL *)url destinationPath:(NSString *)destinationPath downloadInfo:(NSDictionary *)downloadInfo;
- (void)downloadPageAsData:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo;
- (void)cancelDownload;

@end
