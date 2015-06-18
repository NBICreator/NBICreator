//
//  NBCController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-19.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCController.h"
#import "NBCConstants.h"

// Helper
#import "NBCHelper.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"
#import "NBCHelperAuthorization.h"

// UI
#import "NBCDeployStudioDropViewController.h"
#import "NBCDeployStudioSettingsViewController.h"
#import "NBCNetInstallDropViewController.h"
#import "NBCNetInstallSettingsViewController.h"
#import "NBCImagrDropViewController.h"
#import "NBCImagrSettingsViewController.h"
#import "NBCPreferences.h"

// Other
#import "NBCDiskImageController.h"
#import "NBCSource.h"
#import "NBCWorkflowController.h"
#import "NBCDisk.h"
#import "NBCDiskArbitrator.h"

// Apple
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>

#import "Reachability.h"

enum {
    kSegmentedControlNetInstall = 0,
    kSegmentedControlDeployStudio,
    kSegmentedControlImagr,
    kSegmentedControlCustom
};

@interface NBCController() {
    AuthorizationRef _authRef;
    Reachability *_internetReachableFoo;
}

@property (atomic, copy, readwrite) NSData *authorization;

@end

@implementation NBCController

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -
#pragma mark NSApplicationDelegate methods
#pragma mark -

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
#pragma unused(notification)   
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
#pragma unused(notification)
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(updateButtonBuild:) name:NBCNotificationUpdateButtonBuild object:nil];
    [center addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:nil];
    [center addObserver:self selector:@selector(didAttemptEject:) name:DADiskDidAttemptEjectNotification object:nil];
    [center addObserver:self selector:@selector(didAttemptMount:) name:DADiskDidAttemptMountNotification object:nil];
    [center addObserver:self selector:@selector(didAttemptUnmount:) name:DADiskDidAttemptUnmountNotification object:nil];
    
    // --------------------------------------------------------------
    //  Register user defaults
    // --------------------------------------------------------------
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:@"Defaults" withExtension:@"plist"];
    NSError *error;
    if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *defaultSettingsDict=[NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
        if ( defaultSettingsDict ) {
            [ud registerDefaults:defaultSettingsDict];
        }
    } else {
        NSLog(@"Could not find default settings!");
        NSLog(@"Error: %@", error);
    }
    
    [self testInternetConnection];
    
    // --------------------------------------------------------------
    //  Initalize properties
    // --------------------------------------------------------------
    _arbitrator = [NBCDiskArbitrator sharedArbitrator];
    [self setWorkflowController:[[NBCWorkflowController alloc] init]];
    
    NSString *requiredVersion = @"1.0";
    
    OSStatus                    err;
    AuthorizationExternalForm   extForm;
    
    // Connect to the authorization system and create an authorization reference.
    // If unsuccessful, set _authRef to NULL which will cause all operations requiring authorization to fail.
    
    err = AuthorizationCreate(NULL,
                              kAuthorizationEmptyEnvironment,
                              kAuthorizationFlagDefaults,
                              &_authRef);
    
    if ( err == errAuthorizationSuccess ) {
        
        // If successful in creating an empty authorization reference, try to make it interprocess compatible.
        
        err = AuthorizationMakeExternalForm(_authRef, &extForm);
        if ( err == errAuthorizationSuccess ) {
            _authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
        }
    }
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
#pragma unused(proxyError)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self setHelperAvailable:NO];
            [self showHelperToolInstallBox];
            [self->_buttonBuild setEnabled:NO];
        }];
        
    }] getVersionWithReply:^(NSString *version) {
        if ( ! [requiredVersion isEqualToString:version] ) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self setHelperAvailable:NO];
                [self showHelperToolUpgradeBox];
                [self->_buttonBuild setEnabled:NO];
            }];
        } else {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self setHelperAvailable:YES];
            }];
        }
    }];
    
    // --------------------------------------------------------------
    //  Select last selected NBI Type Settings
    // --------------------------------------------------------------
    int netBootSelection = (int)[[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsNetBootSelection] integerValue];
    [_segmentedControlNBI selectSegmentWithTag:netBootSelection];
    [self selectSegmentedControl:netBootSelection];
    
    [_menuItemHelp setAction:@selector(openHelpURL)];
    [_menuItemHelp setTarget:self];
    
    // Display Main Window
    [_window makeKeyAndOrderFront:self];
} // applicationDidFinishLaunching

- (void)openHelpURL {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NBCHelpURL]];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
#pragma unused(sender)
    return YES;
} // applicationShouldTerminateAfterLastWindowClosed

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
#pragma unused(sender)
    [self checkUnsavedSettingsQuit];
    return NSTerminateLater;
} // applicationShouldTerminate

- (void)applicationWillTerminate:(NSNotification *)notification {
#pragma unused(notification)
    NSSet *mountedDisks = [[_arbitrator disks] copy];
    for ( NBCDisk *disk in mountedDisks ) {
        if ( [disk isMountedByNBICreator] && [disk isMounted] ) {
            [disk unmountWithOptions:kDADiskUnmountOptionDefault];
            if ( [[disk deviceModel] isEqualToString:NBCDiskDeviceModelDiskImage] ) {
                [NBCDiskImageController detachDiskImageDevice:[disk BSDName]];
            }
        }
    }
} // applicationWillTerminate

#pragma mark -
#pragma mark Application Termination Checks
#pragma mark -

- (void)checkUnsavedSettingsQuit {
    if ( [_currentSettingsController haveSettingsChanged] ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsUnsavedQuit };
        
        NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
        [alerts showAlertSettingsUnsavedQuit:@"You have unsaved Settings." alertInfo:alertInfo];
    } else {
        [self checkWorkflowRunningQuit];
    }
} // checkUnsavedSettingsQuit

- (void)checkWorkflowRunningQuit {
    if ( [_workflowController workflowRunning] ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagWorkflowRunningQuit };
        
        NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
        [alerts showAlertWorkflowRunningQuit:@"A workflow is still running, if you quit the  current workflow will cancel and result in an incomplete NBI." alertInfo:alertInfo];
    } else {
        [self terminateApp];
    }
} // checkWorkflowRunningQuit

- (void)terminateApp {
    NBCHelperConnection *helper = [[NBCHelperConnection alloc] init];
    [helper connectToHelper];
    
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        NSLog(@"Error: %@", error);
        [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
    }] quitHelper:^(BOOL success) {
#pragma unused(success)
        [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
    }];
}

#pragma mark -
#pragma mark Delegate Methods NBCAlertsDelegate
#pragma mark -

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsavedQuit] )
    {
        if ( returnCode == NSAlertFirstButtonReturn ) {             // Save and Quit
            NSString *selectedTemplate = [_currentSettingsController selectedTemplate];
            NSDictionary *templatesDict = [_currentSettingsController templatesDict];
            [_currentSettingsController saveUISettingsWithName:selectedTemplate atUrl:templatesDict[selectedTemplate]];
            [self checkWorkflowRunningQuit];
        } else if ( returnCode == NSAlertSecondButtonReturn ) {     // Quit
            [self checkWorkflowRunningQuit];
        } else if ( returnCode == NSAlertThirdButtonReturn ) {      // Cancel
            [NSApp replyToApplicationShouldTerminate:NO];
        }
    } else if ( [alertTag isEqualToString:NBCAlertTagWorkflowRunningQuit] )
    {
        if ( returnCode == NSAlertFirstButtonReturn ) {             // Quit Anyway
            NSLog(@"Canceling Workflow..."); // Need to Cancel Gracefully!
            [self terminateApp];
        } else if ( returnCode == NSAlertSecondButtonReturn ) {     // Cancel
            [NSApp replyToApplicationShouldTerminate:NO];
        }
    }
} // alertReturnCode:alertInfo

#pragma mark -
#pragma mark Reachability
#pragma mark -

- (void)testInternetConnection
{
    _internetReachableFoo = [Reachability reachabilityWithHostname:@"github.com"];
    __unsafe_unretained typeof(self) weakSelf = self;
    
    // Internet is reachable
    _internetReachableFoo.reachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf hideNoInternetConnection];
        });
    };
    
    // Internet is not reachable
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf showNoInternetConnection];
        });
    };
    
    [_internetReachableFoo startNotifier];
} // testInternetConnection

#pragma mark -
#pragma mark
#pragma mark -

- (void)addViewToSettingsView:(NSView *)settingsView {
    NSArray *currentSubviews = [_viewNBISettings subviews];
    for ( NSView *view in currentSubviews ) {
        [view removeFromSuperview];
    }
    
    [_viewNBISettings addSubview:settingsView];
    [settingsView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSArray *constraintsArray;
    
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|[settingsView]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(settingsView)];
    [_viewNBISettings addConstraints:constraintsArray];
    
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[settingsView]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(settingsView)];
    [_viewNBISettings addConstraints:constraintsArray];
} // addViewToSettingsView

- (void)addViewToDropView:(NSView *)dropView {
    NSArray *currentSubviews = [_viewDropView subviews];
    for ( NSView *view in currentSubviews ) {
        [view removeFromSuperview];
    }
    
    [_viewDropView addSubview:dropView];
    [dropView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSArray *constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|[dropView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:NSDictionaryOfVariableBindings(dropView)];
    [_viewDropView addConstraints:constraintsArray];
    
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[dropView]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(dropView)];
    [_viewDropView addConstraints:constraintsArray];
} // addViewToDropView

- (void)updateButtonBuild:(NSNotification *)notification {
    BOOL buttonState = [[notification userInfo][NBCNotificationUpdateButtonBuildUserInfoButtonState] boolValue];
    if ( _helperAvailable == YES ) {
        [_buttonBuild setEnabled:buttonState];
    } else {
        [_buttonBuild setEnabled:NO];
    }
} // updateButtonBuild

+ (NSSet *)currentDisks {
    return [[NBCDiskArbitrator sharedArbitrator] disks];
} // currentDisks

+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName {
    NSString *bsdNameCut = [bsdName lastPathComponent];
    NBCDisk *diskToReturn;
    for (NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks] ) {
        if ( [[disk BSDName] isEqualToString:bsdNameCut] ) {
            diskToReturn = disk;
            break;
        }
    }
    return diskToReturn;
} // diskFromBSDName

+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL {
    NBCDisk *diskToReturn;
    for (NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks] ) {
        if ( [disk isMounted] ) {
            CFDictionaryRef diskDescription = [disk diskDescription];
            CFURLRef value = CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumePathKey);
            if (value) {
                if ( [[(__bridge NSURL *)value path] isEqualToString:[volumeURL path]]) {
                    return disk;
                }
            } else {
                NSLog(@"No Volume but Mounted?: %@", diskDescription);
            }
        }
    }
    return diskToReturn;
} // diskFromVolumeURL

+(NSArray *)mountedDiskUUUIDs {
    NSMutableArray *diskUUIDs = [[NSMutableArray alloc] init];
    NSMutableSet *disks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for ( NBCDisk *disk in disks ) {
        NSLog(@"mountedDiskUUUIDs");
        if ([disk isMounted]) {
            NSMutableDictionary *disksDict = [[NSMutableDictionary alloc] initWithObjectsAndKeys:disk, @"disk", nil];
            NSString *uuid = [disk uuid];
            if ( uuid ) {
                disksDict[@"uuid"] = uuid;
                [diskUUIDs addObject:disksDict];
            }
        }
    }
    return diskUUIDs;
} // mountedDiskUUUIDs

- (void)showNoInternetConnection {
    [_viewNoInternetConnection setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_viewMainWindow addSubview:_viewNoInternetConnection positioned:NSWindowAbove relativeTo:nil];
    
    [_viewNoInternetConnection addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_viewNoInternetConnection(==20)]"
                                                                                      options:0
                                                                                      metrics:nil
                                                                                        views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_viewNoInternetConnection]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_viewNoInternetConnection]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
} // showNoInternetConnection

- (void)hideNoInternetConnection {
    [_viewNoInternetConnection removeFromSuperview];
} // hideNoInternetConnection

#pragma mark Helper Tool

- (void)showHelperToolInstallBox {
    [_viewInstallHelper setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_viewMainWindow addSubview:_viewInstallHelper];
    [_viewMainWindow removeConstraint:_constraintBetweenButtonBuildAndViewOutput];
    
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_viewInstallHelper]-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_viewInstallHelper)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_viewNBISettings]-[_viewInstallHelper]-[_buttonBuild]" options:0 metrics:nil views:NSDictionaryOfVariableBindings(_viewNBISettings, _viewInstallHelper, _buttonBuild)]];
    [_buttonBuild setEnabled:NO];
} // showHelperToolInstallBox

- (void)showHelperToolUpgradeBox {
    [_textFieldInstallHelperText setStringValue:@"To create a NetInstall Image you need to upgrade the helper tool."];
    [_buttonInstallHelper setTitle:@"Upgrade Helper"];
    [self showHelperToolInstallBox];
} // showHelperToolUpgradeBox

- (void)hideHelperToolInstallBox {
    [_viewInstallHelper removeFromSuperview];
    [_viewMainWindow addConstraint:_constraintBetweenButtonBuildAndViewOutput];
} // hideHelperToolInstallBox

- (BOOL)blessHelperWithLabel:(NSString *)label error:(NSError **)errorPtr {
    BOOL result = NO;
    NSError *error = nil;
    
    // Configure an Authorization Right to obtain the rights to install NBICreatorHelper
    
    AuthorizationItem authItem		= { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights	= { 1, &authItem };
    AuthorizationFlags flags		= kAuthorizationFlagDefaults |
    kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize |
    kAuthorizationFlagExtendRights;
    
    // Try to obtain the right from the authorization system.
    
    OSStatus status = AuthorizationCopyRights(_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if ( status != errAuthorizationSuccess ) {
        
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    } else {
        
        CFErrorRef  cfError;
        
        // Install NBICreatorHelper.
        
        result = (BOOL) SMJobBless(kSMDomainSystemLaunchd,
                                   (__bridge CFStringRef)label,
                                   _authRef,
                                   &cfError);
        if ( ! result ) {
            error = CFBridgingRelease(cfError);
        }
    }
    
    // If installation failed and the passed errorPointer is not NULL, then set error to errorPointer.
    
    if ( ! result && (errorPtr != NULL) ) {
        
        *errorPtr = error;
    }
    
    return result;
} // blessHelperWithLabel

#pragma mark IBActions

- (IBAction)buttonInstallHelper:(id)sender {
#pragma unused(sender)
    
    NSError *error = nil;
    
    if ( ! [self blessHelperWithLabel:NBCBundleIdentifierHelper error:&error] ) {
        
        NSLog(@"Something went wrong! %@ / %d", [error domain], (int) [error code]);
    } else {
        [self setHelperAvailable:YES];
        [_currentSettingsController verifyBuildButton];
        [self hideHelperToolInstallBox];
    }
} // buttonInstallHelper


- (IBAction)buttonBuild:(id)sender {
#pragma unused(sender)
    [_currentSettingsController buildNBI];
} // buttonBuild

- (void)diskDidChange:(NSNotification *)notif {
    NBCDisk *disk = [notif object];
    
    //NSLog(@"%@", disk);
    if (disk.isMounted) {
        //NSLog(@"IsMounted!");
    }
}

- (void)didAttemptMount:(NSNotification *)notif {
    //NSLog(@"DidAttemptMount");
    NBCDisk *disk = [notif object];
    
    //NSLog(@"%@", disk);
    if (disk.isMounted) {
        //NSLog(@"IsMounted!");
    }
}

- (void)didAttemptUnmount:(NSNotification *)notif {
    //NSLog(@"DidAttemptUnmount");
    NBCDisk *disk = [notif object];
    
    //NSLog(@"%@", disk);
    if (disk.isMounted) {
        //NSLog(@"IsMounted!");
    }
}

- (void)didAttemptEject:(NSNotification *)notif {
    //NSLog(@"DidAttemptEject");
    NBCDisk *disk = [notif object];
    
    //NSLog(@"%@", disk);
    if (disk.isMounted) {
        //NSLog(@"IsMounted!");
    }
}

- (IBAction)menuItemPreferences:(id)sender {
#pragma unused(sender)
    if (!_preferencesWindow) {
        _preferencesWindow = [[NBCPreferences alloc] initWithWindowNibName:@"NBCPreferences"];
    }
    
    [[_preferencesWindow window] makeKeyAndOrderFront:self];
} // menuItemPreferences

- (IBAction)segmentedControlNBI:(id)sender {
    NSSegmentedControl *segmentedControl = (NSSegmentedControl *) sender;
    NSInteger selectedSegment = [segmentedControl selectedSegment];
    [self selectSegmentedControl:selectedSegment];
} // segmentedControlNBI

- (NSInteger)selectedSegment {
    return [_segmentedControlNBI selectedSegment];
} // selectedSegment

- (void)selectSegmentedControl:(NSInteger)selectedSegment {
    if (selectedSegment == kSegmentedControlNetInstall) {
        if (!_niDropViewController) {
            _niDropViewController = [[NBCNetInstallDropViewController alloc] init];
        }
        
        if ( _niDropViewController ) {
            [self addViewToDropView:[_niDropViewController view]];
        }
        
        if (!_niSettingsViewController) {
            _niSettingsViewController = [[NBCNetInstallSettingsViewController alloc] init];
        }
        
        if ( _niSettingsViewController ) {
            [self addViewToSettingsView:[_niSettingsViewController view]];
            _currentSettingsController = _niSettingsViewController;
        }
    } else if (selectedSegment == kSegmentedControlDeployStudio) {
        if (!_dsDropViewController) {
            _dsDropViewController = [[NBCDeployStudioDropViewController alloc] init];
        }
        
        if ( _dsDropViewController ) {
            [self addViewToDropView:[_dsDropViewController view]];
        }
        
        if ( ! _dsSettingsViewController) {
            _dsSettingsViewController = [[NBCDeployStudioSettingsViewController alloc] init];
        }
        
        if ( _dsSettingsViewController ) {
            [self addViewToSettingsView:[_dsSettingsViewController view]];
            _currentSettingsController = _dsSettingsViewController;
            [_currentSettingsController updateDeployStudioVersion];
        }
    } else if (selectedSegment == kSegmentedControlImagr) {
        if ( ! _imagrDropViewController ) {
            _imagrDropViewController = [[NBCImagrDropViewController alloc] init];
        }
        
        if ( _imagrDropViewController ) {
            [self addViewToDropView:[_imagrDropViewController view]];
        }
        
        if ( ! _imagrSettingsViewController ) {
            _imagrSettingsViewController = [[NBCImagrSettingsViewController alloc] init];
        }
        
        if ( _imagrSettingsViewController ) {
            [self addViewToSettingsView:[_imagrSettingsViewController view]];
            _currentSettingsController = _imagrSettingsViewController;
        }
    }
    
    [_menuItemNew setAction:@selector(menuItemNew:)];
    [_menuItemNew setTarget:[_currentSettingsController templates]];
    
    [_menuItemSave setAction:@selector(menuItemSave:)];
    [_menuItemSave setTarget:[_currentSettingsController templates]];
    
    [_menuItemSaveAs setAction:@selector(menuItemSaveAs:)];
    [_menuItemSaveAs setTarget:[_currentSettingsController templates]];
    
    [_menuItemShowInFinder setAction:@selector(menuItemShowInFinder:)];
    [_menuItemShowInFinder setTarget:[_currentSettingsController templates]];
    
    [_window setInitialFirstResponder:[_currentSettingsController textFieldNBIName]];
    [_currentSettingsController verifyBuildButton];
} // selectSegmentedControl

@end
