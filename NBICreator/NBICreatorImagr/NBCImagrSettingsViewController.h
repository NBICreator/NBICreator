//
//  NBCIMSettingsViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-29.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCImagrDropViewImage.h"
#import "NBCAlerts.h"

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCSystemImageUtilitySource.h"
#import "NBCTemplatesController.h"

#import "NBCDownloader.h"
#import "NBCDownloaderGitHub.h"
#import "NBCWorkflowResourcesController.h"

#define BasicTableViewDragAndDropDataType @"BasicTableViewDragAndDropDataType"

@interface NBCImagrSettingsViewController : NSViewController <NBCDownloaderDelegate, NBCDownloaderGitHubDelegate, NBCTemplatesDelegate, NBCAlertDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property NSMutableArray *certificateTableViewContents;
@property NSMutableArray *packagesTableViewContents;

@property NSMutableDictionary *keyboardLayoutDict;
@property NSDictionary *languageDict;
@property NSArray *timeZoneArray;
@property NSMenuItem *selectedMenuItem;
@property NSMenuItem *selectedImagrMenuItem;

// ------------------------------------------------------
//  Constraints
// ------------------------------------------------------
@property (strong) IBOutlet NSLayoutConstraint *constraintLocalPathToImagrVersion;
@property (strong) IBOutlet NSLayoutConstraint *constraintConfigurationURLToImagrVersion;
@property (strong) IBOutlet NSLayoutConstraint *constraintTemplatesBoxHeight;
@property (strong) IBOutlet NSLayoutConstraint *constraintSavedTemplatesToTool;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCTarget *target;
@property NBCSystemImageUtilitySource *siuSource;
@property NBCTemplatesController *templates;
@property NBCWorkflowResourcesController *resourcesController;

// ------------------------------------------------------
//  Tool
// ------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldSIUVersionLabel;
@property (weak) IBOutlet NSTextField *textFieldSIUVersionString;
@property (weak) IBOutlet NSPopUpButton *popUpButtonTool;
- (IBAction)popUpButtonTool:(id)sender;

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
@property (weak) IBOutlet NBCImagrDropViewImageIcon *imageViewIcon;
@property (weak) IBOutlet NSTextField *textFieldNBIName;
@property (weak) IBOutlet NSTextField *textFieldNBINamePreview;
@property (weak) IBOutlet NSTextField *textFieldIndex;
@property (weak) IBOutlet NSTextField *textFieldIndexPreview;
@property (weak) IBOutlet NSTextField *textFieldNBIDescription;
@property (weak) IBOutlet NSTextField *textFieldNBIDescriptionPreview;
@property (weak) IBOutlet NSTextField *textFieldDestinationFolder;
@property (weak) IBOutlet NSPopUpButton *popUpButtonProtocol;
@property (weak) IBOutlet NSPopUpButton *popUpButtonLanguage;
@property (weak) IBOutlet NSPopUpButton *popUpButtonTimeZone;
@property (weak) IBOutlet NSPopUpButton *popUpButtonKeyboardLayout;
@property (weak) IBOutlet NSButton *checkboxAvailabilityEnabled;
@property (weak) IBOutlet NSButton *checkboxAvailabilityDefault;
@property (weak) IBOutlet NSButton *buttonChooseDestinationFolder;
- (IBAction)buttonChooseDestinationFolder:(id)sender;
@property (weak) IBOutlet NSPopover *popOverVariables;
- (IBAction)buttonPopOver:(id)sender;
@property (weak) IBOutlet NSView *superViewPackages;
@property (weak) IBOutlet NSView *superViewCertificates;
@property (weak) IBOutlet NSScrollView *scrollViewCertificates;
@property (weak) IBOutlet NSScrollView *scrollViewPackages;

@property (weak) IBOutlet NSTextField *textFieldTrustedServersCount;
@property (strong) IBOutlet NSPopover *popOverManageTrustedServers;
- (IBAction)buttonManageTrustedServers:(id)sender;
@property (weak) IBOutlet NSTableView *tableViewTrustedServers;
@property (strong) NSView *viewOverlayPackages;
@property (strong) NSView *viewOverlayCertificates;

@property BOOL addTrustedNetBootServers;
@property NSMutableArray *trustedServers;

@property NSMutableArray *ramDisks;
@property (weak) IBOutlet NSTableView *tableViewRAMDisks;

@property (weak) IBOutlet NSButton *buttonAddTrustedServer;
- (IBAction)buttonAddTrustedServer:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveTrustedServer;
- (IBAction)buttonRemoveTrustedServer:(id)sender;

@property (weak) IBOutlet NSSlider *sliderDisplaySleep;
- (IBAction)sliderDisplaySleep:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldDisplaySleepPreview;
- (IBAction)buttonRamDisks:(id)sender;

@property (weak) IBOutlet NSButton *buttonAddRAMDisk;
- (IBAction)buttonAddRAMDisk:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveRAMDisk;
- (IBAction)buttonRemoveRAMDisk:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldRAMDiskCount;
@property (weak) IBOutlet NSTextField *textFieldRAMDiskSize;

// ------------------------------------------------------
//  TabView Imagr Settings
// ------------------------------------------------------
@property NSArray *imagrVersions;
@property NSDictionary *imagrVersionsDownloadLinks;
@property NSArray *imagrBranches;
@property NSDictionary *imagrBranchesDownloadLinks;
@property (weak) IBOutlet NSPopUpButton *popUpButtonImagrVersion;
- (IBAction)popUpButtonImagrVersion:(id)sender;
@property (weak) IBOutlet NSTextField *textFieldImagrLocalPathLabel;
@property (weak) IBOutlet NSTextField *textFieldImagrLocalPath;
@property (weak) IBOutlet NSButton *buttonChooseImagrLocalPath;
- (IBAction)buttonChooseImagrLocalPath:(id)sender;
@property (weak) IBOutlet NSTextField *textFieldConfigurationURL;

@property (weak) IBOutlet NSTextField *textFieldReportingURL;

@property (weak) IBOutlet NSButton *checkboxDisableWiFi;

@property (weak) IBOutlet NSImageView *imageViewNetworkWarning;
@property (weak) IBOutlet NSTextField *textFieldNetworkWarning;

@property (weak) IBOutlet NSTextField *textFieldImagrGitBranchLabel;
@property (weak) IBOutlet NSPopUpButton *popUpButtonImagrGitBranch;
- (IBAction)popUpButtonImagrGitBranch:(id)sender;
@property (weak) IBOutlet NSTextField *textFieldImagrGitBranchBuildTargetLabel;
@property (weak) IBOutlet NSPopUpButton *popUpButtonImagrGitBranchBuildTarget;
- (IBAction)popUpButtonImagrGitBranchBuildTarget:(id)sender;

@property (weak) IBOutlet NSButton *buttonInstallXcode;
- (IBAction)buttonInstallXcode:(id)sender;

@property (strong) IBOutlet NSPopover *popOverRAMDisks;

@property BOOL xcodeInstalled;

// ------------------------------------------------------
//  TabView Options
// ------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldARDLogin;
@property (weak) IBOutlet NSTextField *textFieldARDPassword;
@property (weak) IBOutlet NSSecureTextField *secureTextFieldARDPassword;
@property (weak) IBOutlet NSTextField *textFieldNetworkTimeServer;

// ------------------------------------------------------
//  TabView Extras
// ------------------------------------------------------
@property (weak) IBOutlet NSTableView *tableViewCertificates;
@property (weak) IBOutlet NSTableView *tableViewPackages;
@property (weak) IBOutlet NSButton *buttonAddCertificate;
- (IBAction)buttonAddCertificate:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveCertificate;
- (IBAction)buttonRemoveCertificate:(id)sender;

@property (weak) IBOutlet NSButton *buttonAddPackage;
- (IBAction)buttonAddPackage:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemovePackage;
- (IBAction)buttonRemovePackage:(id)sender;

// Pop Over

@property BOOL settingTrustedNetBootServersVisible;
@property BOOL settingDisableATSVisible;

@property (weak) IBOutlet NBCImagrDropViewImageBackground *imageViewBackgroundImage;

// ------------------------------------------------------
//  UI Binding Properties
// ------------------------------------------------------
@property NSString *nbiCreationTool;
@property BOOL useSystemImageUtility;

@property BOOL isNBI;

@property BOOL nbiEnabled;
@property BOOL nbiDefault;
@property NSString *nbiName;
@property NSString *nbiIcon;
@property NSString *nbiIconPath;
@property NSString *nbiIndex;
@property NSString *nbiProtocol;
@property NSString *nbiLanguage;
@property NSString *nbiTimeZone;
@property NSString *nbiKeyboardLayout;
@property NSString *nbiDescription;
@property NSString *destinationFolder;

@property BOOL disableWiFi;
@property BOOL disableBluetooth;
@property BOOL displaySleep;
@property BOOL includeSystemUIServer;
@property int displaySleepMinutes;
@property NSString *ardLogin;
@property NSString *ardPassword;
@property BOOL showARDPassword;
@property BOOL useNetworkTimeServer;
@property NSString *networkTimeServer;
@property BOOL useVerboseBoot;
@property BOOL diskImageReadWrite;
@property BOOL includeConsoleApp;
@property BOOL enableLaunchdLogging;
@property BOOL launchConsoleApp;
@property BOOL addCustomRAMDisks;
@property BOOL includeRuby;

@property BOOL disableATS;
@property BOOL includeImagrPreReleaseVersionsEnabled;
@property BOOL includeImagrPreReleaseVersions;
@property NSString *imagrVersion;
@property NSString *imagrConfigurationURL;
@property NSString *imagrReportingURL;
@property NSString *imagrSyslogServerURI;
@property BOOL imagrUseLocalVersion;
@property BOOL imagrUseGitBranch;
@property NSString *imagrLocalVersionPath;
@property NSString *imagrGitBranch;
@property NSString *imagrBuildTarget;
@property BOOL useBackgroundImage;
@property NSString *imageBackgroundURL;
@property NSString *imageBackground;

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
- (void)buildNBI;
- (void)verifyBuildButton;
- (void)verifySettings;
- (BOOL)haveSettingsChanged;
- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict;
- (void)updateUISettingsFromURL:(NSURL *)url;
- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo;
- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)settingsURL;
- (void)expandVariablesForCurrentSettings;

@end
