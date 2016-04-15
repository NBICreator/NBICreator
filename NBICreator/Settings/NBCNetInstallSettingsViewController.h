//
//  NBCNISettingsController.h
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

#import "NBCAlerts.h"
#import "NBCApplicationSourceSystemImageUtility.h"
#import "NBCDownloader.h"
#import "NBCDownloaderGitHub.h"
#import "NBCImageDropViewController.h"
#import "NBCSource.h"
#import "NBCSourceDropViewController.h"
#import "NBCTemplatesController.h"
#import <Cocoa/Cocoa.h>

@interface NBCNetInstallSettingsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NBCDownloaderDelegate, NBCDownloaderGitHubDelegate, NBCTemplatesDelegate,
                                                                   NBCAlertDelegate, NBCSourceDropViewDelegate, NBCImageDropViewIconDelegate>

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldSystemImageUtilityVersion;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCApplicationSourceSystemImageUtility *siuSource;
@property NBCTemplatesController *templates;

// Table Views
@property NSRange objectRange;
@property NSArray *currentlyDraggedObjects;

// ------------------------------------------------------
//  Image Type
// ------------------------------------------------------
@property (weak) IBOutlet NSPopUpButton *popUpButtonNBIType;
- (IBAction)popUpButtonNBIType:(id)sender;
@property NSString *nbiType;
@property NSString *nbiCreationTool;

// ------------------------------------------------------
//  Templates
// ------------------------------------------------------
@property NSURL *templatesFolderURL;
@property NSString *selectedTemplate;
@property NSMutableDictionary *templatesDict;
@property (weak) IBOutlet NSPopUpButton *popUpButtonTemplates;
- (IBAction)popUpButtonTemplates:(id)sender;

// ------------------------------------------------------
//  TabView
// ------------------------------------------------------
@property (weak) IBOutlet NSTabView *tabViewSettings;

// ------------------------------------------------------
//  TabView General
// ------------------------------------------------------
@property (weak) IBOutlet NBCImageDropViewIcon *imageViewIcon;
@property (weak) IBOutlet NSTextField *textFieldNBIName;
@property (weak) IBOutlet NSTextField *textFieldNBINamePreview;
@property (weak) IBOutlet NSTextField *textFieldIndex;
@property (weak) IBOutlet NSTextField *textFieldIndexPreview;
@property (weak) IBOutlet NSTextField *textFieldNBIDescription;
@property (weak) IBOutlet NSTextField *textFieldNBIDescriptionPreview;
@property (weak) IBOutlet NSTextField *textFieldDestinationFolder;
@property (weak) IBOutlet NSPopUpButton *popUpButtonProtocol;
@property (weak) IBOutlet NSPopUpButton *popUpButtonLanguage;
@property (weak) IBOutlet NSButton *checkboxAvailabilityEnabled;
@property (weak) IBOutlet NSButton *checkboxAvailabilityDefault;
- (IBAction)buttonChooseDestinationFolder:(id)sender;

// ------------------------------------------------------
//  TabView Advanced
// ------------------------------------------------------
@property BOOL settingTrustedNetBootServersVisible;
@property BOOL addTrustedNetBootServers;
@property NSMutableArray *trustedServers;
@property (weak) IBOutlet NSTextField *textFieldTrustedServersCount;
@property (strong) IBOutlet NSPopover *popOverManageTrustedServers;
- (IBAction)buttonManageTrustedServers:(id)sender;
@property (weak) IBOutlet NSTableView *tableViewTrustedServers;
@property (weak) IBOutlet NSButton *buttonAddTrustedServer;
- (IBAction)buttonAddTrustedServer:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveTrustedServer;
- (IBAction)buttonRemoveTrustedServer:(id)sender;

// ------------------------------------------------------
//  TabView Post-Install
// ------------------------------------------------------

// Configuration Profiles
@property NSMutableArray *configurationProfilesTableViewContents;
@property (weak) IBOutlet NSView *superViewConfigurationProfiles;
@property (strong) NSView *viewOverlayConfigurationProfiles;
@property (weak) IBOutlet NSTableView *tableViewConfigurationProfiles;
- (IBAction)buttonAddConfigurationProfile:(id)sender;
- (IBAction)buttonRemoveConfigurationProfile:(id)sender;

// Packages and scripts
@property NSMutableArray *packagesNetInstallTableViewContents;
@property (weak) IBOutlet NSView *superViewPackagesNetInstall;
@property (strong) NSView *viewOverlayPackagesNetInstall;
@property (weak) IBOutlet NSTableView *tableViewPackagesNetInstall;
- (IBAction)buttonAddPackageNetInstall:(id)sender;
- (IBAction)buttonRemovePackageNetInstall:(id)sender;

// ------------------------------------------------------
//  TabView Post-Workflow
// ------------------------------------------------------
@property (weak) IBOutlet NSPopUpButton *popUpButtonUSBDevices;
@property (weak) IBOutlet NSButton *checkboxCreateUSBDevice;
@property BOOL createUSBDevice;
@property NSMutableDictionary *usbDevicesDict;
@property (weak) IBOutlet NSView *superViewPostWorkflowScripts;
@property NSMutableArray *postWorkflowScripts;
@property (strong) NSView *viewOverlayPostWorkflowScripts;
@property (weak) IBOutlet NSTableView *tableViewPostWorkflowScripts;
@property (weak) IBOutlet NSButton *buttonAddPostWorkflowScript;
- (IBAction)buttonAddPostWorkflowScript:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemovePostWorkflowScript;
- (IBAction)buttonRemovePostWorkflowScript:(id)sender;
@property (weak) IBOutlet NSTextField *textFieldUSBDeviceLabel;
@property NSString *usbLabel;

// ------------------------------------------------------
//  PopOver
// ------------------------------------------------------
@property (weak) IBOutlet NSPopover *popOverVariables;
- (IBAction)buttonPopOver:(id)sender;

// ------------------------------------------------------
//  UI Binding Properties
// ------------------------------------------------------
@property BOOL nbiEnabled;
@property BOOL nbiDefault;
@property NSString *nbiName;
@property NSString *nbiIcon;
@property NSString *nbiIconPath;
@property NSString *nbiIndex;
@property NSString *nbiProtocol;
@property NSString *nbiLanguage;
@property NSString *nbiDescription;
@property NSString *destinationFolder;

@property BOOL netInstallPackageOnly;

@property NSString *popOverOSVersion;
@property NSString *popOverOSMajor;
@property NSString *popOverOSMinor;
@property NSString *popOverOSPatch;
@property NSString *popOverOSBuild;
@property NSString *popOverDate;
@property NSString *popOverIndexCounter;
@property NSString *popOverOSIndex;
@property NSString *nbcVersion;
@property NSString *siuVersion;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)buildNBI:(NSDictionary *)preWorkflowTasks;
- (void)verifyBuildButton;
- (BOOL)haveSettingsChanged;
- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict;
- (void)updateUISettingsFromURL:(NSURL *)url;
- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)settingsURL;
- (void)expandVariablesForCurrentSettings;
- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo;

@end
