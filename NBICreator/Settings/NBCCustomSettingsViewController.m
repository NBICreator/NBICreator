//
//  NBCCustomSettingsViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

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
