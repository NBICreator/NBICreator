//
//  NBCInstallerPackageController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCInstallerPackageController.h"
#import "NBCConstants.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <xar/xar.h>
#include "lzma.h"

#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCInstallerPackageController

- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)installPackagesToVolume:(NSURL *)volumeURL packages:(NSArray *)packages {
    NSLog(@"installPackagesToVolume");
    NSLog(@"volumeURL=%@", volumeURL);
    NSLog(@"packages=%@", packages);
    if ( [packages count] != 0 ) {
        [self setVolumeURL:volumeURL];
        _packagesQueue = [[NSMutableArray alloc] initWithArray:packages];
        [self runPackageQueue];
    }
}

- (void)installSuccessfulForPackage:(NSURL *)packageURL {
    DDLogInfo(@"%@ installed successfully!", [packageURL lastPathComponent]);
    [_packagesQueue removeObjectAtIndex:0];
    [self runPackageQueue];
}

- (void)runPackageQueue {
    NSLog(@"runPackageQueue");
    if ( [_packagesQueue count] != 0 ) {
        NSDictionary *packageDict = [_packagesQueue firstObject];
        NSLog(@"packageDict=%@", packageDict);
        if ( [packageDict count] != 0 ) {
            NSString *packageName = packageDict[NBCWorkflowInstallerName];
            NSLog(@"packageName=%@", packageName);
            NSString *packageSourcePath = packageDict[NBCWorkflowInstallerSourceURL];
            NSLog(@"packageSourcePath=%@", packageSourcePath);
            if ( [packageSourcePath length] != 0 ) {
                NSURL *packageURL = [NSURL fileURLWithPath:packageSourcePath];
                NSLog(@"packageURL=%@", packageURL);
                NSDictionary *packageChoiceChangeXML = packageDict[NBCWorkflowInstallerChoiceChangeXML];
                NSLog(@"packageChoiceChangeXML=%@", packageChoiceChangeXML);
                //[_delegate updateProgressStatus:[NSString stringWithFormat:@"Installing %@ to BaseSystem.dmg...", packageName] workflow:self];
                [self installPackageOnTargetVolume:_volumeURL packageURL:packageURL choiceChangesXML:packageChoiceChangeXML];
            }
        }
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installPackageOnTargetVolume:(NSURL *)volumeURL packageURL:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSLog(@"installPackageOnTargetVolume");
    BOOL verified = YES;
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/installer"];
    
    NSLog(@"commandURL=%@", commandURL);
    
    NSMutableArray *installerArguments;
    installerArguments = [[NSMutableArray alloc] initWithObjects:
                          @"-verboseR",
                          @"-allowUntrusted",
                          @"-plist",
                          nil];
    
    if ( choiceChangesXML ) {
        [installerArguments addObject:@"-applyChoiceChangesXML"];
        [installerArguments addObject:choiceChangesXML];
    }
    
    if ( packageURL ) {
        [installerArguments addObject:@"-package"];
        [installerArguments addObject:[packageURL path]];
    } else {
        NSLog(@"No package URL passed!");
        verified = NO;
    }
    
    if ( volumeURL ) {
        [installerArguments addObject:@"-target"];
        [installerArguments addObject:[volumeURL path]];
    } else {
        NSLog(@"No volume URL passed!");
        verified = NO;
    }
    
    NSLog(@"installerArguments=%@", installerArguments);
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                                      object:[stdOut fileHandleForReading]
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification){
                                                      #pragma unused(notification)
                                                      NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                                      NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                                      
                                                      NSLog(@"stdout: %@", outStr);
                                                      
                                                      [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                                  }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                                      object:[stdErr fileHandleForReading]
                                                       queue:nil
                                                  usingBlock:^(NSNotification *notification){
                                                      #pragma unused(notification)
                                                      NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                                      NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                                      
                                                      NSLog(@"stderr: %@", errStr);
                                                      
                                                      [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                                  }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        NSLog(@"ProxyError? %@", proxyError);
        [nc removeObserver:stdOutObserver];
        [nc removeObserver:stdErrObserver];
        NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        
    }] runTaskWithCommandAtPath:commandURL arguments:installerArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        
        if ( terminationStatus == 0 ) {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self installSuccessfulForPackage:packageURL];
            
        } else {
            NSLog(@"Pkg install failed!");
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            if ( [self->_delegate respondsToSelector:@selector(installFailed)] ) {
                [self->_delegate installFailed];
            }
        }
    }];
}

/*
//
//  main.c
//  pbzx
//
//  Created by PHPdev32 on 6/20/14.
//  Licensed under GPLv3, full text at http://www.gnu.org/licenses/gpl-3.0.txt
//


#define min(A,B) ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#define err(c, m) if (c) { fprintf(stderr, m"\n"); exit(__COUNTER__ + 1); }
#define XBSZ 4 * 1024
#define ZBSZ 1024 * XBSZ

static inline void xar_read(char *buffer, uint32_t size, xar_stream *stream) {
    stream->next_out = buffer;
    stream->avail_out = size;
    while (stream->avail_out)
        err(xar_extract_tostream(stream) != XAR_STREAM_OK, "XAR extraction failure");
}

static inline size_t cpio_out(char *buffer, size_t size) {
    size_t c = 0;
    while (c < size)
        c+= fwrite(buffer + c, 1, size - c, stdout);
    return c;
}

static inline uint64_t xar_read_64(xar_stream *stream) {
    char t[8];
    xar_read(t, 8, stream);
    return __builtin_bswap64(*(uint64_t *)t);
}

int test(const char *file)
{
    
    // insert code here...
    char xbuf[XBSZ], *zbuf = malloc(sizeof(ZBSZ));
    xar_t x;

    err(!(x = xar_open(file, READ)), "XAR open failure");
    xar_iter_t i = xar_iter_new();
    xar_file_t f = xar_file_first(x, i);
    char *path;
    while (strncmp((path = xar_get_path(f)), "Payload", 7) && (f = xar_file_next(i)))
        free(path);
    free(path);
    xar_iter_free(i);
    err(!f, "No payload");
    err(xar_verify(x, f) != XAR_STREAM_OK, "File verification failed");
    xar_stream xs;
    err(xar_extract_tostream_init(x, f, &xs) != XAR_STREAM_OK, "XAR init failed");
    xar_read(xbuf, 4, &xs);
    err(strncmp(xbuf, "pbzx", 4), "Not a pbzx stream");
    uint64_t length = 0, flags = xar_read_64(&xs), last = 0;
    lzma_stream zs = LZMA_STREAM_INIT;
    err(lzma_stream_decoder(&zs, UINT64_MAX, LZMA_CONCATENATED) != LZMA_OK, "LZMA init failed");
    while (flags & 1 << 24) {
        flags = xar_read_64(&xs);
        length = xar_read_64(&xs);
        char plain = length == 0x1000000;
        xar_read(xbuf, min(XBSZ, (uint32_t)length), &xs);
        err(!plain && strncmp(xbuf, "\xfd""7zXZ\0", 6), "Header is not <FD>7zXZ<00>");
        while (length) {
            if (plain)
                cpio_out(xbuf, min(XBSZ, length));
            else {
                zs.next_in = (typeof(zs.next_in))xbuf;
                zs.avail_in = min(XBSZ, length);
                while (zs.avail_in) {
                    zs.next_out = (typeof(zs.next_out))zbuf;
                    zs.avail_out = ZBSZ;
                    err(lzma_code(&zs, LZMA_RUN) != LZMA_OK, "LZMA failure");
                    cpio_out(zbuf, ZBSZ - zs.avail_out);
                }
            }
            length -= last = min(XBSZ, length);
            xar_read(xbuf, min(XBSZ, (uint32_t)length), &xs);
        }
        err(!plain && strncmp(xbuf + last - 2, "YZ", 2), "Footer is not YZ");
    }
    xar_extract_tostream_end(&xs);
    free(zbuf);
    lzma_end(&zs);
    xar_close(x);
    return 0;
}
*/
@end
