//
//  NBCDownloader.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-14.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDownloader.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCDownloader

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCDownloaderDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)downloadPageAsData:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setDownloadInfo:downloadInfo];
    [self setRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0]];
    [NSURLConnection connectionWithRequest:_request delegate:self];
}

- (void)downloadFileFromURL:(NSURL *)url destinationPath:(NSString *)destinationPath downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setDestinationFolder:destinationPath];
    [self setDownloadInfo:downloadInfo];
    [self setRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0]];
    [self setDownload:[[NSURLDownload alloc] initWithRequest:_request delegate:self]];
    if ( ! _download ) {
        NSLog(@"Download Failed!");
    }
}

- (void)cancelDownload {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_download cancel];
    [_delegate downloadCanceled:_downloadInfo];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NSURLConnection
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    #pragma unused(connection, response)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    _downloadData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    #pragma unused(connection)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_downloadData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
#pragma unused(connection)
    if ( [_delegate respondsToSelector:@selector(downloadFailed:withError:)] ) {
        [_delegate downloadFailed:_downloadInfo withError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    #pragma unused(connection)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( [_delegate respondsToSelector:@selector(dataDownloadCompleted:downloadInfo:)] ) {
        [_delegate dataDownloadCompleted:_downloadData downloadInfo:_downloadInfo];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NSURLDownload
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response {
    #pragma unused(download)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setBytesRecieved:0];
    [self setDownloadResponse:response];
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *destinationFilePath = [_destinationFolder stringByAppendingPathComponent:filename];
    
    [self setDestinationPath:destinationFilePath];
    [download setDestination:destinationFilePath allowOverwrite:YES];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
    #pragma unused(download)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    long long expectedLength = [[self downloadResponseTest] expectedContentLength];
    
    [self setBytesRecieved:(_bytesRecieved + length)];
    
    if (expectedLength != NSURLResponseUnknownLength) {
        if ( [_delegate respondsToSelector:@selector(updateProgressBytesRecieved:expectedLength:downloadInfo:)] ) {
            [_delegate updateProgressBytesRecieved:_bytesRecieved expectedLength:expectedLength downloadInfo:_downloadInfo];
        }
    } else {
        NSLog(@"Bytes received - %f",_bytesRecieved);
    }
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    #pragma unused(download)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *destinationURL = [NSURL fileURLWithPath:_destinationPath];
    if ( [_delegate respondsToSelector:@selector(fileDownloadCompleted:downloadInfo:)] ) {
        [_delegate fileDownloadCompleted:destinationURL downloadInfo:_downloadInfo];
    }
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    #pragma unused(download)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"Download failed! Error - %@ %@",
          [error localizedDescription],
          [error userInfo][NSURLErrorFailingURLStringErrorKey]);
}

- (void)setDownloadResponse:(NSURLResponse *)aDownloadResponse {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    _downloadResponseTest = aDownloadResponse;
}

@end
