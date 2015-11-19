//
//  NBCCustomSettingsViewController.m
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

#import "NBCCustomSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@interface NBCCustomSettingsViewController ()

@end

@implementation NBCCustomSettingsViewController

- (id)init {
    self = [super initWithNibName:@"NBCCustomSettingsViewController" bundle:nil];
    if (self != nil) {
    
    }
    return self;
} // init

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)refreshCreationTool {
    NSLog(@"Refreshing");
}

-(void)verifyBuildButton {
    NSLog(@"verifyBuildButton");
    [self uppdatePopUpButtonTool];
}

- (void)updateSource:(NBCSource *)source target:(NBCTarget *)target {
    NSLog(@"source=%@", source);
    NSLog(@"target=%@", target);
}

- (void)removedSource {
    NSLog(@"removedSource");
}

- (BOOL)haveSettingsChanged {
    return NO;
}

- (void)uppdatePopUpButtonTool {
    if ( _popUpButtonTool ) {
        [_popUpButtonTool removeAllItems];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemNBICreator];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemDeployStudioAssistant];
        [_popUpButtonTool selectItemWithTitle:_nbiCreationTool ?: NBCMenuItemNBICreator];
        [self setNbiCreationTool:[_popUpButtonTool titleOfSelectedItem]];
    }
} // uppdatePopUpButtonTool

@end
