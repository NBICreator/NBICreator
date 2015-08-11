//
//  NBCController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-19.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

@class NBCDisk;
@class NBCSource;
@class NBCPreferences;
@class NBCDiskArbitrator;
#import "NBCAlerts.h"

@interface NBCController : NSObject <NSApplicationDelegate, NBCAlertDelegate>

// Windows
@property (weak) IBOutlet NSWindow *window;

- (IBAction)menuItemPreferences:(id)sender;

// Views
@property (strong) NSViewController *nbiSettingsViewController;

@property (strong) NSViewController *dsDropViewController;
@property (strong) NSViewController *dsSettingsViewController;

@property (strong) NSViewController *niDropViewController;
@property (strong) NSViewController *niSettingsViewController;

@property (strong) NSViewController *imagrDropViewController;
@property (strong) NSViewController *imagrSettingsViewController;

@property (strong) NSViewController *customDropViewController;
@property (strong) NSViewController *customSettingsViewController;

@property (readonly) NSInteger selectedSegment;

@property (weak) IBOutlet NSMenuItem *menuItemNew;
@property (weak) IBOutlet NSMenuItem *menuItemSave;
@property (weak) IBOutlet NSMenuItem *menuItemSaveAs;
@property (weak) IBOutlet NSMenuItem *menuItemShowInFinder;
@property (weak) IBOutlet NSMenuItem *menuItemHelp;

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

+ (NSSet *)currentDisks;
+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName;
+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL;
+ (NSArray *)mountedDiskUUUIDs;

@end
