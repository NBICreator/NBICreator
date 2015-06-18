//
//  NSString+randomString.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NSString+randomString.h"

@implementation NSString (NBCrandomString)

+ (NSString*)nbc_randomString {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:6];
    for (int i=0; i<6; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    return randomString;
}

@end
