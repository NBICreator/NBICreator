//
//  NBCController.h
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
#import <Foundation/Foundation.h>
#import "NBCAlerts.h"

@class NBCDisk;
@class NBCSource;
@class NBCPreferences;
@class NBCDiskArbitrator;

@interface NBCController : NSObject <NSApplicationDelegate, NBCAlertDelegate, NSWindowDelegate>

// Windows
@property (weak) IBOutlet NSWindow *window;



- (IBAction)menuItemPreferences:(id)sender;
- (IBAction)menuItemHelp:(id)sender;
- (IBAction)menuItemMainWindow:(id)sender;

// Views
@property (strong) NSViewController *nbiSettingsViewController;

@property (strong) NSViewController *dsDropViewController;
@property (strong) NSViewController *dsSettingsViewController;

@property (strong) NSViewController *niDropViewController;
@property (strong) NSViewController *niSettingsViewController;

@property (strong) NSViewController *imagrDropViewController;
@property (strong) NSViewController *imagrSettingsViewController;

@property (strong) NSViewController *casperDropViewController;
@property (strong) NSViewController *casperSettingsViewController;

@property (strong) NSViewController *customDropViewController;
@property (strong) NSViewController *customSettingsViewController;

@property (readonly) NSInteger selectedSegment;

@property (weak) IBOutlet NSMenuItem *menuItemNew;
@property (weak) IBOutlet NSMenuItem *menuItemSave;
@property (weak) IBOutlet NSMenuItem *menuItemSaveAs;
@property (weak) IBOutlet NSMenuItem *menuItemRename;
@property (weak) IBOutlet NSMenuItem *menuItemExport;
@property (weak) IBOutlet NSMenuItem *menuItemDelete;
@property (weak) IBOutlet NSMenuItem *menuItemShowInFinder;
@property (weak) IBOutlet NSMenuItem *menuItemHelp;
@property (weak) IBOutlet NSMenuItem *menuItemWindowWorkflows;

@property (weak) IBOutlet NSView *viewMainWindow;
@property (weak) IBOutlet NSView *viewDropView;
@property (weak) IBOutlet NSView *viewNBISettings;
@property (weak) IBOutlet NSBox *viewInstallHelper;
@property (weak) IBOutlet NSView *viewNoInternetConnection;

@property BOOL helperAvailable;
@property id currentSettingsController;
@property NBCSource *currentSource;
@property NBCPreferences *preferencesWindow;
@property NBCDiskArbitrator *arbitrator;

// Buttons
@property (weak) IBOutlet NSButton *buttonBuild;
- (IBAction)buttonBuild:(id)sender;
@property (weak) IBOutlet NSSegmentedControl *segmentedControlNBI;
- (IBAction)segmentedControlNBI:(id)sender;

@property (weak) IBOutlet NSButton *buttonInstallHelper;
- (IBAction)buttonInstallHelper:(id)sender;

// Text Fields and Labels
@property (weak) IBOutlet NSTextField *textFieldInstallHelperText;

// Constraints
@property (strong) IBOutlet NSLayoutConstraint *constraintBetweenButtonBuildAndViewOutput;

+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName;
+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL;
+ (NSArray *)mountedDiskUUUIDs;

@end
