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
    [super drawRect:dirtyRect];
    [[NSColor whiteColor] set];
    NSRectFill([self bounds]);
}

@end
