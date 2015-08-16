//
//  main.m
//  NBICreatorHelper
//
//  Created by Erik Berglund on 2015-02-13.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCHelper.h"

int main(int argc, const char * argv[]) {
#pragma unused(argc)
#pragma unused(argv)
        @autoreleasepool {
            NBCHelper *helper = [[NBCHelper alloc] init];
            [helper run];
        }
    return 0;
}
