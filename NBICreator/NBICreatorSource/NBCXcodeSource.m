//
//  NBCXcodeSource.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-25.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCXcodeSource.h"

@implementation NBCXcodeSource

+ (BOOL)isInstalled {
    NSArray *xcodeApplicationURLs = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier(CFSTR("com.apple.dt.Xcode"), NULL));;
    if ( [xcodeApplicationURLs count] != 0 ) {
        return YES;
    } else  {
        return NO;
    }
}



@end
