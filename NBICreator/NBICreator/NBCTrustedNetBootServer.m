//
//  NBCTrustedNetBootServer.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCTrustedNetBootServer.h"

@implementation NBCTrustedNetBootServer

- (id)init {
    self = [super init];
    if ( self ) {
        _netBootServerIP = @"10.0.1.1";
    }
    return self;
}

@end
