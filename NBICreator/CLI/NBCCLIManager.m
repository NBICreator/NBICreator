//
//  NBCCLIManager.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

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
