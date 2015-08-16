//
//  NBCBonjourBrowser.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-16.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCBonjourBrowser : NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate>

@property (strong, nonatomic, readwrite) NSNetServiceBrowser *browser;
@property (strong, nonatomic, readwrite) NSMutableArray *services;
@property (strong, nonatomic, readwrite) NSMutableArray *deployStudioURLs;

- (void)startBonjourDiscovery;
- (void)stopBonjourDiscovery;

@end
