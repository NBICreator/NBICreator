//
//  NBCCustomSettingsViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NBCTemplatesController.h"
#import "NBCDropViewController.h"

@interface NBCCustomSettingsViewController : NSViewController <NBCDropViewDelegate>

@property NBCTemplatesController *templates;

@property (weak) IBOutlet NSTextField *textFieldNBIName;

@property (weak) IBOutlet NSPopUpButton *popUpButtonTool;
@property NSString *nbiCreationTool;

- (void)verifyBuildButton;

@end
