//
//  NBCPreferences.h
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
