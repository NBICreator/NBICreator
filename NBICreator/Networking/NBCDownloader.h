//
//  NBCDownloader.h
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

#import <Foundation/Foundation.h>

@protocol NBCDownloaderDelegate
@optional
- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo;
- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo;
- (void)updateProgressBytesRecieved:(float)bytesRecieved expectedLength:(long long)expectedLength downloadInfo:(NSDictionary *)downloadInfo;
- (void)downloadCanceled:(NSDictionary *)downloadInfo;
- (void)downloadFailed:(NSDictionary *)downloadInfo withError:(NSError *)error;
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
