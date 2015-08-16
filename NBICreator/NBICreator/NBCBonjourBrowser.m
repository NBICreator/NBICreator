//
//  NBCBonjourBrowser.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-16.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCBonjourBrowser.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCBonjourBrowser

- (void)startBonjourDiscovery {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _services ) {
        [_services removeAllObjects];
    } else {
        _services = [[NSMutableArray alloc] init];
    }
    
    if ( _deployStudioURLs ) {
        [_deployStudioURLs removeAllObjects];
    } else {
        _deployStudioURLs = [[NSMutableArray alloc] init];
    }
    [self startSearch];
} // startBonjourDiscovery

- (void)startSearch {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( ! _browser ) {
        _browser = [[NSNetServiceBrowser alloc] init];
    }
    [_browser setDelegate:self];
    [_browser searchForServicesOfType:NBCBonjourServiceDeployStudio inDomain:@"local."];
} // startSearch

- (void)dealloc {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_browser setDelegate:nil];
} // dealloc

- (void)restartBonjourDiscovery {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (_browser) {
        [_browser stop];
        [NSTimer scheduledTimerWithTimeInterval:0.5f
                                         target:self
                                       selector:@selector(startSearch)
                                       userInfo:nil
                                        repeats:NO];
    }
} // restartBonjourDiscovery

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser {
    #pragma unused(aNetServiceBrowser)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
} // netServiceBrowserWillSearch

- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    #pragma unused(serviceBrowser, moreComing)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_services addObject:aNetService];
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:10];
} // netServiceBrowser:didFindService:moreComing

- (void)netServiceDidStop:(NSNetService *)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
} // netServiceDidStop

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *txtRecordDict = [NSNetService dictionaryFromTXTRecordData:[aNetService TXTRecordData]];
    if ( [txtRecordDict count] == 0) {
        [self restartBonjourDiscovery];
        return;
    }

    NSData *altUrlsData = txtRecordDict[@"alt-urls"];
    NSString *altURLsString = [[NSString alloc] initWithData:altUrlsData encoding:NSUTF8StringEncoding];
    NSArray *altURLs = [altURLsString componentsSeparatedByString:@";"];
    for ( NSString *url in altURLs ) {
        if ( [url length] != 0 && ! [_deployStudioURLs containsObject:url] ) {
            [_deployStudioURLs addObject:url];
        }
    }
    
    NSDictionary *userInfo = @{ @"serverURLs" : _deployStudioURLs };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationDeployStudioAddBonjourService
                                                        object:self
                                                      userInfo:userInfo];
    
} // netServiceDidResolveAddress

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    #pragma unused(sender, errorDict)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
} // netService:didNotResolve

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    #pragma unused(aNetServiceBrowser, moreComing)
    if ([_services containsObject:aNetService]) {
        NSDictionary *txtRecordDict = [NSNetService dictionaryFromTXTRecordData:[aNetService TXTRecordData]];
        
        NSData *altUrlsData = txtRecordDict[@"alt-urls"];
        NSString *altURLsString = [[NSString alloc] initWithData:altUrlsData encoding:NSUTF8StringEncoding];
        NSArray *altURLs = [altURLsString componentsSeparatedByString:@";"];
        for (NSString *url in altURLs) {
            if ( [_deployStudioURLs containsObject:url] ) {
                [_deployStudioURLs removeObject:url];
            }
        }
        
        NSDictionary * userInfo = @{ @"serverURLs" : _deployStudioURLs };
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationDeployStudioRemoveBonjourService
                                                            object:self
                                                          userInfo:userInfo];
        [_services removeObject:aNetService];
    }
} // netServiceBrowser:didRemoveService:moreComing

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)serviceBrowser {
    #pragma unused(serviceBrowser)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self stopBonjourDiscovery];
} // netServiceBrowserDidStopSearch

- (void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didNotSearch:(NSDictionary *)userInfo {
    #pragma unused(aBrowser, userInfo)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self stopBonjourDiscovery];
} // netServiceBrowser:didNotSearch

- (void)stopBonjourDiscovery {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _browser ) {
        [_browser stop];
        [_browser setDelegate:nil];
        [self setBrowser:nil];
    }
} // stopBonjourDiscovery

@end
