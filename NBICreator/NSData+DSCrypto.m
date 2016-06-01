//
//  NSData+DSCrypto.m
//  DSEnc
//
//  Created by Erik Berglund on 2016-05-18.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

#import "NBCLog.h"
#import "NSData+DSCrypto.h"
#import "NSString+randomString.h"
#import <CommonCrypto/CommonCrypto.h>

NSString *const key = @"1YL601802TQ";
NSString *const iv = @"0000000000000000";
NSString *const iv_17 = @"1234567890abcdef";

@implementation NSData (NBCDSCrypto)

- (NSData *)nbc_encryptLegacyDSPassword {

    NSData *encryptedData;
    NSError *error = nil;

    NSMutableData *inputPasswordData = [self mutableCopy];
    [inputPasswordData increaseLengthBy:(8 - ([inputPasswordData length] % 8))];

    NSURL *tmpURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/tmp/%@", [NSString nbc_randomString]]];
    if ([inputPasswordData writeToURL:tmpURL options:0 error:&error]) {

        NSTask *opensslTask = [[NSTask alloc] init];
        [opensslTask setLaunchPath:@"/usr/bin/openssl"];
        [opensslTask setArguments:@[ @"enc", @"-des-cbc", @"-in", [tmpURL path], @"-nosalt", @"-nopad", @"-K", @"f137ec7cb5a49e4c", @"-iv", iv ]];
        [opensslTask setStandardOutput:[NSPipe pipe]];
        [opensslTask setStandardError:[NSPipe pipe]];

        [opensslTask launch];
        [opensslTask waitUntilExit];

        NSData *stdOutData = [[[opensslTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSData *stdErrData = [[[opensslTask standardError] fileHandleForReading] readDataToEndOfFile];

        if ([tmpURL checkResourceIsReachableAndReturnError:nil]) {
            if (![[NSFileManager defaultManager] removeItemAtURL:tmpURL error:&error]) {
                DDLogError(@"[ERROR] Unable to remove temporary pass-file!");
            }
        }

        if ([opensslTask terminationStatus] == 0) {
            if (stdOutData) {
                encryptedData = [[stdOutData base64EncodedDataWithOptions:0] base64EncodedDataWithOptions:0];
            }
        } else {
            DDLogError(@"[ERROR] %@", [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding]);
        }
    }

    return encryptedData;
}

- (NSData *)nbc_encryptDSPassword {

    NSData *encryptedData;

    NSData *ivData = [self dataForHexString:iv_17];
    Byte *ivBytes = (Byte *)[ivData bytes];

    NSUInteger dataLength = [self length];
    NSUInteger bufferLength = dataLength + kCCBlockSizeAES128;

    unsigned char buffer[bufferLength];
    memset(buffer, 0, sizeof(char));

    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus =
        CCCrypt(kCCEncrypt, kCCAlgorithmDES, kCCOptionPKCS7Padding, [key UTF8String], kCCKeySizeDES, ivBytes, [self bytes], dataLength, buffer, bufferLength, &numBytesEncrypted);

    if (cryptStatus == kCCSuccess) {
        encryptedData = [[[NSData dataWithBytes:buffer length:numBytesEncrypted] base64EncodedDataWithOptions:0] base64EncodedDataWithOptions:0];
    }
    return encryptedData;
}

- (NSData *)dataForHexString:(NSString *)hexString {
    NSUInteger inLength = [hexString length];

    unichar *inCharacters = alloca(sizeof(unichar) * inLength);
    [hexString getCharacters:inCharacters range:NSMakeRange(0, inLength)];

    UInt8 *outBytes = malloc(sizeof(UInt8) * ((inLength / 2) + 1));

    NSInteger i, o = 0;
    UInt8 outByte = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wsign-compare"
#pragma clang diagnostic ignored "-Wconversion"
    for (i = 0; i < inLength; i++) {
        UInt8 c = inCharacters[i];
        SInt8 value = -1;

        if (c >= '0' && c <= '9')
            value = (c - '0');
        else if (c >= 'A' && c <= 'F')
            value = 10 + (c - 'A');
        else if (c >= 'a' && c <= 'f')
            value = 10 + (c - 'a');

        if (value >= 0) {
            if (i % 2 == 1) {
                outBytes[o++] = (outByte << 4) | value;
                outByte = 0;
            } else {
                outByte = value;
            }

        } else {
            if (o != 0)
                break;
        }
    }

    return [[NSData alloc] initWithBytesNoCopy:outBytes length:o freeWhenDone:YES];
#pragma clang diagnostic pop
}

@end
