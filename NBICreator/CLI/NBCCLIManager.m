//
//  NBCCLIManager.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCCLIManager.h"
#import "NBCCLIArguments.h"
#import "NBCLog.h"

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
        [self registerDefaults];
        [NBCLog configureLoggingFor:kWorkflowSessionTypeCLI];
    }
    return self;
} // init

- (void)registerDefaults {
    // --------------------------------------------------------------
    //  Register user defaults
    // --------------------------------------------------------------
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:@"Defaults" withExtension:@"plist"];
    NSError *error;
    if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *defaultSettingsDict=[NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
        if ( defaultSettingsDict ) {
            [ud registerDefaults:defaultSettingsDict];
        }
    } else {
        DDLogError(@"[ERROR] Could not find default settings plist \"Defaults.plist\" in main bundle!");
        DDLogError(@"[ERROR] %@", error);
    }

}

- (void)verifyCLIArguments {
    NBCCLIArguments *cliArguments = [[NBCCLIArguments alloc] init];
    [cliArguments verifyArguments];
}

@end
