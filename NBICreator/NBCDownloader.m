//
//  NBCDownloader.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-14.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDownloader.h"

@implementation NBCDownloader

#pragma mark -
#pragma mark Initialization
#pragma mark -

- (id)initWithDelegate:(id<NBCDownloaderDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

#pragma mark -
#pragma mark Methods
#pragma mark -

- (void)downloadPageAsData:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    [self setDownloadInfo:downloadInfo];
    [self setRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0]];
    [NSURLConnection connectionWithRequest:_request delegate:self];
}

- (void)downloadFileFromURL:(NSURL *)url destinationPath:(NSString *)destinationPath downloadInfo:(NSDictionary *)downloadInfo {
    [self setDestinationFolder:destinationPath];
    [self setDownloadInfo:downloadInfo];
    [self setRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0]];
    [self setDownload:[[NSURLDownload alloc] initWithRequest:_request delegate:self]];
    if ( ! _download ) {
        NSLog(@"Download Failed!");
    }
}

- (void)cancelDownload {
    [_download cancel];
    [_delegate downloadCanceled:_downloadInfo];
}

#pragma mark -
#pragma mark Delegate Methods NSURLConnection
#pragma mark -

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    #pragma unused(connection, response)
    //NSLog(@"ConnectionDidRecieveResponse");
    _downloadData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    #pragma unused(connection)
    //NSLog(@"ConnectionDidReceiveData");
    [_downloadData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    #pragma unused(connection)
    //NSLog(@"connectionDidFinishLoading");
    [_delegate dataDownloadCompleted:_downloadData downloadInfo:_downloadInfo];
}

#pragma mark -
#pragma mark Delegate Methods NSURLDownload
#pragma mark -

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response {
    #pragma unused(download)
    //NSLog(@"DidRecieveResponse");
    [self setBytesRecieved:0];
    [self setDownloadResponse:response];
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename {
    //NSLog(@"DecideDestinationWithSuggestedFilename");
    NSString *destinationFilePath = [_destinationFolder stringByAppendingPathComponent:filename];
    
    [self setDestinationPath:destinationFilePath];
    [download setDestination:destinationFilePath allowOverwrite:YES];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
    #pragma unused(download)
    long long expectedLength = [[self downloadResponseTest] expectedContentLength];
    
    [self setBytesRecieved:(_bytesRecieved + length)];
    
    if (expectedLength != NSURLResponseUnknownLength) {
        [_delegate updateProgressBytesRecieved:_bytesRecieved expectedLength:expectedLength downloadInfo:_downloadInfo ];
    } else {
        NSLog(@"Bytes received - %f",_bytesRecieved);
    }
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    #pragma unused(download)
    //NSLog(@"DowonlaodDidFinish");
    NSURL *destinationURL = [NSURL fileURLWithPath:_destinationPath];
    [_delegate fileDownloadCompleted:destinationURL downloadInfo:_downloadInfo];
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    #pragma unused(download)
    NSLog(@"Download failed! Error - %@ %@",
          [error localizedDescription],
          [error userInfo][NSURLErrorFailingURLStringErrorKey]);
}

- (void)setDownloadResponse:(NSURLResponse *)aDownloadResponse {
    //NSLog(@"SetDownloadResponse");
    _downloadResponseTest = aDownloadResponse;
}

@end
