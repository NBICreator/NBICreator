//
//  NBCNISettingsController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCNetInstallDropViewImage.h"
#import "NBCAlerts.h"

#import "NBCSource.h"
#import "NBCSystemImageUtilitySource.h"
#import "NBCTemplatesController.h"

#import "NBCDownloader.h"
#import "NBCDownloaderGitHub.h"

@interface NBCNetInstallSettingsViewController : NSViewController <NBCDownloaderDelegate, NBCDownloaderGitHubDelegate, NBCTemplatesDelegate, NBCAlertDelegate>

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldSystemImageUtilityVersion;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCSystemImageUtilitySource *siuSource;
@property NBCTemplatesController *templates;

// ------------------------------------------------------
//  Templates
// ------------------------------------------------------
@property NSURL *templatesFolderURL;
@property NSString *selectedTemplate;
@property NSMutableDictionary *templatesDict;
@property (weak) IBOutlet NSPopUpButton *popUpButtonTemplates;
- (IBAction)popUpButtonTemplates:(id)sender;

// ------------------------------------------------------
//  TabView General
// ------------------------------------------------------
@property (weak) IBOutlet NBCNetInstallDropViewImageIcon *imageViewIcon;
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

@property NSString *popOverOSVersion;
@property NSString *popOverOSMajor;
@property NSString *popOverOSMinor;
@property NSString *popOverOSPatch;
@property NSString *popOverOSBuild;
@property NSString *popOverIndex;
@property NSString *siuVersion;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)buildNBI;
- (void)verifyBuildButton;
- (BOOL)haveSettingsChanged;
- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict;
- (void)updateUISettingsFromURL:(NSURL *)url;
- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)settingsURL;
- (void)expandVariablesForCurrentSettings;

@end
