//
//  NBCCLIManager.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCCLIManager.h"
#import "NBCCLIArguments.h"

@implementation NBCCLIManager

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (id)sharedManager {
    static NBCCLIManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
} // sharedManager

- (id)init {
    self = [super init];
    if (self != nil) {
        
    }
    return self;
} // init

- (void)verifyCLIArguments {
    NBCCLIArguments *cliArguments = [[NBCCLIArguments alloc] init];
    [cliArguments verifyArguments];
}

@end
