//
//  NBCViewNoInternetConnection.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-29.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCViewNoInternetConnection.h"

@implementation NBCViewNoInternetConnection

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Fill in background Color
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 0.227,0.251,0.337,0.6);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

@end
