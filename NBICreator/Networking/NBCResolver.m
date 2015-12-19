//
//  NBCResolver.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-12-18.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCResolver.h"

@implementation NBCResolver

- (id)initWithHostname:(NSString *)hostname {
    self = [super init];
    if (self) {
        _hostname = hostname;
    }
    return self;
}

- (BOOL)lookup {
    // sanity check
    if (!self.hostname) {
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"No hostname provided."}];
        return NO;
    }
    // set up the CFHost object
    CFHostRef host = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)self.hostname);
    CFHostClientContext ctx = {.info = (__bridge void*)self};
    CFHostSetClient(host, DNSResolverHostClientCallback, &ctx);
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFHostScheduleWithRunLoop(host, runloop, CFSTR("DNSResolverRunLoopMode"));
    // start the name resolution
    CFStreamError error;
    Boolean didStart = CFHostStartInfoResolution(host, kCFHostAddresses, &error);
    if (!didStart) {
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"CFHostStartInfoResolution failed."}];
        return NO;
    }
    // run the run loop for 50ms at a time, always checking if we should cancel
    while(!self.shouldCancel && !self.done) {
        CFRunLoopRunInMode(CFSTR("DNSResolverRunLoopMode"), 0.05, true);
    }
    if (self.shouldCancel) {
        CFHostCancelInfoResolution(host, kCFHostAddresses);
        self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Name look up cancelled."}];
    }
    if (!self.error) {
        Boolean hasBeenResolved;
        CFArrayRef addressArray = CFHostGetAddressing(host, &hasBeenResolved);
        if (hasBeenResolved) {
            self.addresses = [(__bridge NSArray*)addressArray copy];
        } else {
            self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Name look up failed"}];
        }
    }
    // clean up the CFHost object
    CFHostSetClient(host, NULL, NULL);
    CFHostUnscheduleFromRunLoop(host, runloop, CFSTR("DNSResolverRunLoopMode"));
    CFRelease(host);
    return self.error ? NO : YES;
}

void DNSResolverHostClientCallback ( __unused CFHostRef theHost, __unused CFHostInfoType typeInfo, const CFStreamError *error, void *info) {
    NBCResolver *self = (__bridge NBCResolver*)info;
    if (error->domain || error->error) self.error = [NSError errorWithDomain:@"MyDomain" code:1 userInfo:@{NSLocalizedDescriptionKey:@"Name look up failed"}];
    self.done = YES;
}

@end
