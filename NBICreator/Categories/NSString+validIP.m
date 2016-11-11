//
//  NSString+validIP.m
//  NBICreator
//
//  Taken from http://stackoverflow.com/a/10971521/4596429
//

#import "NBCResolver.h"
#import "NSString+validIP.h"
#include <arpa/inet.h>
#import "NBCLog.h"

@implementation NSString (NBCvalidIP)

- (BOOL)isValidIPAddress {
    const char *utf8 = [self UTF8String];
    int success;

    struct in_addr dst;
    success = inet_pton(AF_INET, utf8, &dst);
    if (success != 1) {
        struct in6_addr dst6;
        success = inet_pton(AF_INET6, utf8, &dst6);
    }

    return success == 1;
}

- (BOOL)isValidHostname {
    NBCResolver *resolver = [[NBCResolver alloc] initWithHostname:self];
    return [resolver lookup];
}

@end
