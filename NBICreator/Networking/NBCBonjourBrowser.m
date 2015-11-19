//
//  NBCBonjourBrowser.m
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

#import "NBCBonjourBrowser.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCBonjourBrowser

- (void)startBonjourDiscovery {
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
    if ( ! _browser ) {
        _browser = [[NSNetServiceBrowser alloc] init];
    }
    [_browser setDelegate:self];
    [_browser searchForServicesOfType:NBCBonjourServiceDeployStudio inDomain:@"local."];
    DDLogDebug(@"[DEBUG] Searching for bonjour service type: %@ in domain: %@", NBCBonjourServiceDeployStudio, @"local.");
} // startSearch

- (void)dealloc {
    [_browser setDelegate:nil];
} // dealloc

- (void)restartBonjourDiscovery {
    
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
} // netServiceBrowserWillSearch

- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    #pragma unused(serviceBrowser, moreComing)
    [_services addObject:aNetService];
    [aNetService setDelegate:self];
    [aNetService resolveWithTimeout:10];
} // netServiceBrowser:didFindService:moreComing

- (void)netServiceDidStop:(NSNetService *)sender {
#pragma unused(sender)
} // netServiceDidStop

- (void)netServiceDidResolveAddress:(NSNetService *)aNetService {
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
    
} // netService:didNotResolve

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    
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
    
    [self stopBonjourDiscovery];
} // netServiceBrowserDidStopSearch

- (void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didNotSearch:(NSDictionary *)userInfo {
    #pragma unused(aBrowser, userInfo)
    
    [self stopBonjourDiscovery];
} // netServiceBrowser:didNotSearch

- (void)stopBonjourDiscovery {
    
    if ( _browser ) {
        [_browser stop];
        DDLogDebug(@"[DEBUG] Stopped bonjour search");
        [_browser setDelegate:nil];
        [self setBrowser:nil];
    }
} // stopBonjourDiscovery

@end
