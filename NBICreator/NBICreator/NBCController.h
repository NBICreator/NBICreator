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
#import "NBCOptionBuildPanel.h"
#import "NBCNetInstallSettingsViewController.h"
#import "NBCDeployStudioSettingsViewController.h"
#import "NBCImagrSettingsViewController.h"
#import "NBCCasperSettingsViewController.h"
#import "NBCCustomSettingsViewController.h"
@class NBCSource;
@class NBCPreferences;

@interface NBCController : NSObject <NSApplicationDelegate, NSWindowDelegate, NBCAlertDelegate, NBCOptionBuildPanelDelegate>

// --------------------------------------------------------------
//  Windows
// --------------------------------------------------------------
@property (weak) IBOutlet NSWindow *window;
@property (strong) NBCOptionBuildPanel *optionBuildPanel;
@property (strong) NBCPreferences *preferencesWindow;

// --------------------------------------------------------------
//  Layout Constraints
// --------------------------------------------------------------
@property (strong) IBOutlet NSLayoutConstraint *constraintBetweenButtonBuildAndViewOutput;

// --------------------------------------------------------------
//  Properties
// --------------------------------------------------------------
@property (readonly) NSInteger selectedSegment;
@property BOOL helperAvailable;
@property id keyEventMonitor;
@property id currentSettingsController;

// --------------------------------------------------------------
//  Views: DeployStudio
// --------------------------------------------------------------
@property (strong) NBCSourceDropViewController *dsDropViewController;
@property (strong) NBCDeployStudioSettingsViewController *dsSettingsViewController;

// --------------------------------------------------------------
//  Views: NetInstall
// --------------------------------------------------------------
@property (strong) NBCSourceDropViewController *niDropViewController;
@property (strong) NBCNetInstallSettingsViewController *niSettingsViewController;

// --------------------------------------------------------------
//  Views: Imagr
// --------------------------------------------------------------
@property (strong) NBCSourceDropViewController *imagrDropViewController;
@property (strong) NBCImagrSettingsViewController *imagrSettingsViewController;

// --------------------------------------------------------------
//  Views: Casper
// --------------------------------------------------------------
@property (strong) NBCSourceDropViewController *casperDropViewController;
@property (strong) NBCCasperSettingsViewController *casperSettingsViewController;

// --------------------------------------------------------------
//  Views: Custom
// --------------------------------------------------------------
@property (strong) NBCSourceDropViewController *customDropViewController;
@property (strong) NBCCustomSettingsViewController *customSettingsViewController;

// --------------------------------------------------------------
//  Views: Other
// --------------------------------------------------------------
@property (weak) IBOutlet NSView *viewMainWindow;
@property (weak) IBOutlet NSView *viewDropView;
@property (weak) IBOutlet NSView *viewNBISettings;
@property (weak) IBOutlet NSBox *viewInstallHelper;
@property (weak) IBOutlet NSView *viewNoInternetConnection;

// --------------------------------------------------------------
//  Menu Items
// --------------------------------------------------------------
@property (weak) IBOutlet NSMenuItem *menuItemNew;
@property (weak) IBOutlet NSMenuItem *menuItemSave;
@property (weak) IBOutlet NSMenuItem *menuItemSaveAs;
@property (weak) IBOutlet NSMenuItem *menuItemRename;
@property (weak) IBOutlet NSMenuItem *menuItemExport;
@property (weak) IBOutlet NSMenuItem *menuItemDelete;
@property (weak) IBOutlet NSMenuItem *menuItemShowInFinder;
@property (weak) IBOutlet NSMenuItem *menuItemHelp;
@property (weak) IBOutlet NSMenuItem *menuItemWindowWorkflows;
- (IBAction)menuItemHelp:(id)sender;
- (IBAction)menuItemPreferences:(id)sender;
- (IBAction)menuItemMainWindow:(id)sender;

// --------------------------------------------------------------
//  Buttons
// --------------------------------------------------------------
@property (weak) IBOutlet NSButton *buttonBuild;
@property (weak) IBOutlet NSButton *buttonInstallHelper;
@property (weak) IBOutlet NSSegmentedControl *segmentedControlNBI;
- (IBAction)buttonBuild:(id)sender;
- (IBAction)segmentedControlNBI:(id)sender;
- (IBAction)buttonInstallHelper:(id)sender;

// --------------------------------------------------------------
//  TextFields
// --------------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldInstallHelperText;

@end
