//
//  NBCCasperSettingsViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCCasperDropViewImage.h"
#import "NBCAlerts.h"

#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCApplicationSourceSystemImageUtility.h"
#import "NBCTemplatesController.h"

#import "NBCDownloader.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCDropViewController.h"

#define BasicTableViewDragAndDropDataType @"BasicTableViewDragAndDropDataType"

@interface NBCCasperSettingsViewController : NSViewController <NBCDownloaderDelegate, NBCTemplatesDelegate, NBCAlertDelegate, NSTableViewDataSource, NSTableViewDelegate, NBCDropViewDelegate>

@property NSMutableArray *certificateTableViewContents;
@property NSMutableArray *packagesTableViewContents;
@property NSMutableDictionary *keyboardLayoutDict;
@property NSDictionary *languageDict;
@property NSArray *timeZoneArray;
@property NSMenuItem *selectedMenuItem;
@property (weak) IBOutlet NSTabView *tabViewCasperSettings;

@property (strong) IBOutlet NSLayoutConstraint *constraintTemplatesBoxHeight;
@property (strong) IBOutlet NSLayoutConstraint *constraintSavedTemplatesToTool;

@property NSDictionary *nbiSourceSettings;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCTarget *target;
@property NBCApplicationSourceSystemImageUtility *siuSource;
@property NBCTemplatesController *templates;
@property NBCWorkflowResourcesController *resourcesController;
@property NBCDownloader *jssCertificateDownloader;
@property NBCDownloader *jssVersionDownloader;

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
@property (weak) IBOutlet NBCCasperDropViewImageIcon *imageViewIcon;
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

@property (weak) IBOutlet NSSlider *sliderDisplaySleep;
- (IBAction)sliderDisplaySleep:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldDisplaySleepPreview;

// ------------------------------------------------------
//  TabView Casper Settings
// ------------------------------------------------------
@property (weak) IBOutlet NSTextField *textFieldCasperImagingPath;
@property (weak) IBOutlet NSButton *buttonChooseCasperImagingPath;
- (IBAction)buttonChooseCasperImagingPath:(id)sender;
@property (weak) IBOutlet NSTextField *textFieldJSSURL;
@property (weak) IBOutlet NSButton *buttonVerifyJSS;
- (IBAction)buttonVerifyJSS:(id)sender;
@property (weak) IBOutlet NSProgressIndicator *progressIndicatorVerifyJSS;
@property (weak) IBOutlet NSTextField *textFieldVerifyJSSStatus;

@property (weak) IBOutlet NSProgressIndicator *progressIndicatorDownloadJSSCertificate;
@property (weak) IBOutlet NSImageView *imageViewDownloadJSSCertificateStatus;
@property (weak) IBOutlet NSTextField *textFieldDownloadJSSCertificateStatus;

@property NSDictionary *jssCACertificate;
@property NSString *casperImagingVersion;
@property BOOL verifyingJSS;
@property BOOL downloadingJSSCertificate;

@property (weak) IBOutlet NSButton *checkboxAllowInvalidCertificate;

@property (weak) IBOutlet NSImageView *imageViewVerifyJSSStatus;

@property (weak) IBOutlet NSButton *buttonDownloadJSSCertificate;
- (IBAction)buttonDownloadJSSCertificate:(id)sender;

@property (weak) IBOutlet NSButton *buttonShowJSSCertificate;
- (IBAction)buttonShowJSSCertificate:(id)sender;

@property (strong) IBOutlet NSPopover *popOverManageTrustedServers;
@property (weak) IBOutlet NSTextField *textFieldTrustedServersCount;
- (IBAction)buttonManageTrustedServers:(id)sender;
@property (weak) IBOutlet NSTableView *tableViewTrustedServers;

@property BOOL addTrustedNetBootServers;
@property NSMutableArray *trustedServers;

@property (weak) IBOutlet NSButton *buttonAddTrustedServer;
- (IBAction)buttonAddTrustedServer:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveTrustedServer;
- (IBAction)buttonRemoveTrustedServer:(id)sender;

@property NSMutableArray *ramDisks;
@property (weak) IBOutlet NSTableView *tableViewRAMDisks;
@property (strong) IBOutlet NSPopover *popOverRAMDisks;
@property (weak) IBOutlet NSButton *buttonAddRAMDisk;
- (IBAction)buttonAddRAMDisk:(id)sender;
@property (weak) IBOutlet NSButton *buttonRemoveRAMDisk;
- (IBAction)buttonRemoveRAMDisk:(id)sender;
- (IBAction)buttonRamDisks:(id)sender;
@property (strong) NSView *viewOverlayPackages;
@property (strong) NSView *viewOverlayCertificates;
@property (weak) IBOutlet NSTextField *textFieldRAMDiskCount;
@property (weak) IBOutlet NSTextField *textFieldRAMDiskSize;

// ------------------------------------------------------
//  TabView Options
// ------------------------------------------------------
@property (weak) IBOutlet NSButton *checkboxDisableWiFi;
@property (weak) IBOutlet NSButton *checkboxDisableBluetooth;
@property (weak) IBOutlet NSButton *checkboxIncludeRuby;
@property (weak) IBOutlet NSButton *checkboxIncludePython;
@property (weak) IBOutlet NSButton *checkboxIncludeSystemUIServer;
@property (weak) IBOutlet NSTextField *textFieldARDLogin;
@property (weak) IBOutlet NSTextField *textFieldARDPassword;
@property (weak) IBOutlet NSSecureTextField *secureTextFieldARDPassword;
@property (weak) IBOutlet NSButton *checkboxARDPasswordShow;
@property (weak) IBOutlet NSButton *checkboxUseNetworkTimeServer;
@property (weak) IBOutlet NSTextField *textFieldNetworkTimeServer;

@property (weak) IBOutlet NSView *superViewPackages;
@property (weak) IBOutlet NSView *superViewCertificates;
@property (weak) IBOutlet NSScrollView *scrollViewPackages;
@property (weak) IBOutlet NSScrollView *scrollViewCertificates;

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
@property (weak) IBOutlet NSButton *checkboxAddBackground;
@property (weak) IBOutlet NBCCasperDropViewImageBackground *imageViewBackgroundImage;

// ------------------------------------------------------
//  TabView Debug
// ------------------------------------------------------
@property (weak) IBOutlet NSButton *checkboxIncludeConsole;
@property (weak) IBOutlet NSButton *checkboxConsoleLaunchBehindApp;

// ------------------------------------------------------
//  UI Binding Properties
// ------------------------------------------------------
@property BOOL connectedToInternet;
@property BOOL verifyJSSWhenConnected;

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
@property BOOL diskImageReadWriteRename;
@property BOOL includeConsoleApp;
@property BOOL enableLaunchdLogging;
@property BOOL launchConsoleApp;
@property BOOL addCustomRAMDisks;
@property BOOL includeRuby;
@property BOOL includePython;

@property NSString *casperImagingPath;
@property NSString *casperJSSURL;
@property BOOL allowInvalidCertificate;
@property BOOL jssURLValid;
@property NSString *jssVersion;
@property BOOL jssCACertificateValid;
@property NSString *jssCACertificateExpirationString;
@property BOOL enableCasperImagingDebugMode;

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
@property NSString *cimVersion;

// ------------------------------------------------------
//  Instance Methods
// ------------------------------------------------------
- (void)buildNBI:(NSDictionary *)preWorkflowTasks;
- (void)verifyBuildButton;
- (void)verifySettings:(NSDictionary *)preWorkflowTasks;
- (BOOL)haveSettingsChanged;
- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict;
- (void)updateUISettingsFromURL:(NSURL *)url;
- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo;
- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)settingsURL;
- (void)expandVariablesForCurrentSettings;

@end
