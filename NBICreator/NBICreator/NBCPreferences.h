//
//  NBCPreferences.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-08.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NBCPreferences : NSWindowController

@property BOOL checkingForApplicationUpdates;

@property (weak) IBOutlet NSButton *buttonCheckForUpdatesNow;
- (IBAction)buttonCheckForUpdatesNow:(id)sender;

@property (weak) IBOutlet NSImageView *imageViewLogWarning;
@property (weak) IBOutlet NSTextField *textFieldLogWarning;

@property (weak) IBOutlet NSComboBox *comboBoxDateFormat;
- (IBAction)comboBoxDateFormat:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldDatePreview;

@property (weak) IBOutlet NSTextField *textFieldCacheFolderSize;

@property (weak) IBOutlet NSButton *buttonClearCache;
- (IBAction)buttonClearCache:(id)sender;

@property (weak) IBOutlet NSButton *buttonShowCache;
- (IBAction)buttonShowCache:(id)sender;

- (void)updateCacheFolderSize;

@property (weak) IBOutlet NSTextField *textFieldUpdateStatus;

@end
