//
//  NBCPreferences.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-08.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NBCPreferences : NSWindowController

@property (weak) IBOutlet NSComboBox *comboBoxDateFormat;
- (IBAction)comboBoxDateFormat:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldDatePreview;

@end
