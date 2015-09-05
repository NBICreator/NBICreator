//
//  NBCBackgroundViewWhite.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCBackgroundViewWhite.h"

@implementation NBCBackgroundViewWhite

- (void)drawRect:(NSRect)dirtyRect {
#pragma unused(dirtyRect)
    [[NSColor whiteColor] set];
    NSRectFill([self bounds]);
    /*
    [self setWantsLayer:YES];
    self.layer.masksToBounds   = YES;
    self.layer.borderWidth      = 1.0f ;
    
    [self.layer setBorderColor:CGColorGetConstantColor(kCGColorBlack)];
     */
}

@end
