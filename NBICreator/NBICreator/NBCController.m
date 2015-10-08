//
//  NBCController.m
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Imports
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

// Main
#import "NBCController.h"
#import "NBCLog.h"
//#import "NBCLogging.h"
#import "NBCConstants.h"

// Apple
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>

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
#import "NBCCasperDropViewController.h"
#import "NBCCasperSettingsViewController.h"


#import "NBCPreferences.h"

// Other
#import "NBCSource.h"
#import "NBCWorkflowManager.h"
#import "NBCDisk.h"
#import "NBCDiskArbitrator.h"
#import "NBCDiskImageController.h"
#import "Reachability.h"
#import "NBCUpdater.h"
#import "NBCWorkflowManager.h"

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Constants
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

DDLogLevel ddLogLevel;

// --------------------------------------------------------------
//  Enum corresponding to segmented control position
// --------------------------------------------------------------
enum {
    kSegmentedControlNetInstall = 0,
    kSegmentedControlDeployStudio,
    kSegmentedControlImagr,
    kSegmentedControlCasper,
    kSegmentedControlCustom
};

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCController Interface
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@interface NBCController() {
    AuthorizationRef _authRef;
    Reachability *_internetReachableFoo;
}

@property (atomic, copy, readwrite) NSData *authorization;

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCController Implementation
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@implementation NBCController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Init / Dealloc
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)createEmptyAuthorizationRef {
    DDLogDebug(@"Creating empty authorization reference...");
    NSError                     *error;
    OSStatus                    status;
    AuthorizationExternalForm   extForm;
    
    // --------------------------------------------------------------
    //  Connect to the authorization system and create an authorization reference.
    // --------------------------------------------------------------
    status = AuthorizationCreate(NULL,
                                 kAuthorizationEmptyEnvironment,
                                 kAuthorizationFlagDefaults,
                                 &_authRef);
    
    if ( status == errAuthorizationSuccess ) {
        DDLogDebug(@"Creating empty authorization reference successful!");
        
        // --------------------------------------------------------------
        //  If creating the authorization reference was successful, try to make it interprocess compatible.
        // --------------------------------------------------------------
        DDLogDebug(@"Making authorization references interprocess compatible...");
        status = AuthorizationMakeExternalForm(_authRef, &extForm);
        if ( error == errAuthorizationSuccess ) {
            DDLogDebug(@"Making authorization references interprocess compatible successful!");
            _authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
        } else {
            DDLogError(@"[ERROR] Creating empty authorization reference failed!");
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            DDLogError(@"[ERROR] %@", error);
        }
    } else {
        DDLogError(@"[ERROR] Creating empty authorization reference failed!");
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        DDLogError(@"[ERROR] %@", error);
    }
} // createEmptyAuthorizationRef

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NSApplicationDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
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
        NSLog(@"Could not find default settings plist \"Defaults.plist\" in main bundle!");
        NSLog(@"%@", error);
    }
    
    // --------------------------------------------------------------
    //  Setup logging
    // --------------------------------------------------------------
    [NBCLog configureLoggingFor:kWorkflowSessionTypeGUI];
    
    // --------------------------------------------------------------
    //  Setup preference window so it can recieve notifications
    // --------------------------------------------------------------
    if ( ! _preferencesWindow ) {
        _preferencesWindow = [[NBCPreferences alloc] initWithWindowNibName:@"NBCPreferences"];
    }
    
    // --------------------------------------------------------------
    //  Test connection to the internet
    // --------------------------------------------------------------
    [self testInternetConnection];
    
    // --------------------------------------------------------------
    //  Register disk notifications
    // --------------------------------------------------------------
    [NBCDiskArbitrator sharedArbitrator];
    
    // --------------------------------------------------------------
    // Create an empty AuthorizationRef and make it interprocess compatible
    // It will be used whith tasks that require authentication to helper
    // --------------------------------------------------------------
    [self createEmptyAuthorizationRef];
    
    // --------------------------------------------------------------
    //  Check that helper tool is updated
    // --------------------------------------------------------------
    [self checkHelperVersion];
    
    // --------------------------------------------------------------
    //  Connect main menu items
    // --------------------------------------------------------------
    [_menuItemWindowWorkflows setAction:@selector(menuItemWindowWorkflows:)];
    [_menuItemWindowWorkflows setTarget:[NBCWorkflowManager sharedManager]];
    
    // --------------------------------------------------------------
    //  Restore last selected NBI type in segmented control
    // --------------------------------------------------------------
    int netBootSelection = (int)[[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsNetBootSelection] integerValue];
    [_segmentedControlNBI selectSegmentWithTag:netBootSelection];
    [self selectSegmentedControl:netBootSelection];
    
    // --------------------------------------------------------------
    //  Display Main Window
    // --------------------------------------------------------------
    [_window makeKeyAndOrderFront:self];
} // applicationDidFinishLaunching

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
#pragma unused(sender)
    return YES;
} // applicationShouldTerminateAfterLastWindowClosed

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
#pragma unused(sender)
    // --------------------------------------------------------------
    //  Run some checks before terminating application
    // --------------------------------------------------------------
    [self checkUnsavedSettingsQuit];
    return NSTerminateLater;
} // applicationShouldTerminate

- (void)applicationWillTerminate:(NSNotification *)notification {
#pragma unused(notification)
    // --------------------------------------------------------------
    //  Unmount all disks and disk images mounted by NBICreator
    // --------------------------------------------------------------
    NSSet *mountedDisks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for ( NBCDisk *disk in mountedDisks ) {
        if ( [disk isMountedByNBICreator] && [disk isMounted] ) {
            [disk unmountWithOptions:kDADiskUnmountOptionDefault];
            if ( [[disk deviceModel] isEqualToString:NBCDiskDeviceModelDiskImage] ) {
                [NBCDiskImageController detachDiskImageDevice:[disk BSDName]];
            }
        }
    }
} // applicationWillTerminate

- (void)applicationDidBecomeActive:(NSNotification *)notification {
#pragma unused(notification)
    NSDockTile *dockTile = [NSApp dockTile];
    [dockTile setBadgeLabel:@""];
    [dockTile display];
}

/*//////////////////////////////////////////////////////////////////////////////
 /// FUTURE FUNCTIONALITY - OPEN/IMPORT TEMPLATES                             ///
 //////////////////////////////////////////////////////////////////////////////*/
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    DDLogInfo(@"Recieved file to open: %@", filename);
#pragma unused(theApplication)
    NSError *error;
    NSURL *fileURL = [NSURL fileURLWithPath:filename];
    
    // --------------------------------------------------------------
    //  Try to read settings from sent file
    // --------------------------------------------------------------
    NSDictionary *templateInfo = [NBCTemplatesController templateInfoFromTemplateAtURL:fileURL error:&error];
    if ( [templateInfo count] != 0 ) {
        NSString *title = templateInfo[NBCSettingsTitleKey];
        NSString *type = templateInfo[NBCSettingsTypeKey];
        
        // --------------------------------------------------------------
        //  Check if template settings are an exact duplicate of an existing template
        // --------------------------------------------------------------
        if ( [NBCTemplatesController templateIsDuplicate:fileURL] ) {
            [NBCAlerts showAlertImportTemplateDuplicate:@"Template already imported!"];
            return NO;
        }
        
        if ( [type isEqualToString:NBCSettingsTypeNetInstall] ) {
            
        } else if ( [type isEqualToString:NBCSettingsTypeDeployStudio] ) {
            
        } else if ( [type isEqualToString:NBCSettingsTypeImagr] ) {
            
        }
        
        NSString *importTitle = [NSString stringWithFormat:@"Import %@ Template?", type];
        NSString *importMessage = [NSString stringWithFormat:@"Do you want to import the %@ template \"%@\"?", type, title];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Import"];
        [alert addButtonWithTitle:NBCButtonTitleCancel];
        [alert setMessageText:importTitle];
        [alert setInformativeText:importMessage];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
            if ( returnCode == NSAlertFirstButtonReturn ) {
                if ( [type isEqualToString:NBCSettingsTypeNetInstall] ) {
                    [self->_segmentedControlNBI selectSegmentWithTag:kSegmentedControlNetInstall];
                    [self selectSegmentedControl:kSegmentedControlNetInstall];
                    if ( self->_currentSettingsController ) {
                        [self->_currentSettingsController importTemplateAtURL:fileURL templateInfo:templateInfo];
                    } else {
                        NSLog(@"ERROR! Could not import template, internal error!");
                    }
                } else if ( [type isEqualToString:NBCSettingsTypeDeployStudio] ) {
                    [self->_segmentedControlNBI selectSegmentWithTag:kSegmentedControlDeployStudio];
                    [self selectSegmentedControl:kSegmentedControlDeployStudio];
                    if ( self->_currentSettingsController ) {
                        [self->_currentSettingsController importTemplateAtURL:fileURL templateInfo:templateInfo];
                    } else {
                        NSLog(@"ERROR! Could not import template, internal error!");
                    }
                } else if ( [type isEqualToString:NBCSettingsTypeImagr] ) {
                    [self->_segmentedControlNBI selectSegmentWithTag:kSegmentedControlImagr];
                    [self selectSegmentedControl:kSegmentedControlImagr];
                    if ( self->_currentSettingsController ) {
                        [self->_currentSettingsController importTemplateAtURL:fileURL templateInfo:templateInfo];
                    } else {
                        NSLog(@"ERROR! Could not import template, internal error!");
                    }
                }
            }
        }];
        return YES;
    } else {
        DDLogError(@"[ERROR] Could not read template!");
        DDLogError(@"[ERROR] %@", error);
        return NO;
    }
} // application:openFile
/* -------------------------------------------------------------------------- */

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NSWindowDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)windowDidBecomeKey:(NSNotification *)notification {
#pragma unused(notification)
    // I'm seeing strange behaviour when using this. Going to try and disable and run without for testing.
    //[[NBCWorkflowManager sharedManager] menuItemWindowWorkflows:self];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Application Termination Checks
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)checkUnsavedSettingsQuit {
    
    // --------------------------------------------------------------
    //  Alert user if there are unsaved settings before quitting
    // --------------------------------------------------------------
    
    //+ IMPROVEMENT Check ALL nbi types, not just currently selected.
    
    if ( [_currentSettingsController haveSettingsChanged] ) {
        NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
        [alerts showAlertSettingsUnsavedQuit:@"You have unsaved Settings."
                                   alertInfo:@{
                                               NBCAlertTagKey : NBCAlertTagSettingsUnsavedQuit
                                               }];
    } else {
        [self checkWorkflowRunningQuit];
    }
} // checkUnsavedSettingsQuit

- (void)checkWorkflowRunningQuit {
    
    
    // --------------------------------------------------------------
    //  Alert user if there are any workflows currently running before quitting
    // --------------------------------------------------------------
    if ( [[NBCWorkflowManager sharedManager] workflowRunning] ) {
        NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
        [alerts showAlertWorkflowRunningQuit:@"A workflow is still running. If you quit now, the current workflow will cancel and delete the NBI in creation."
                                   alertInfo:@{
                                               NBCAlertTagKey : NBCAlertTagWorkflowRunningQuit
                                               }];
    } else {
        [self terminateApp];
    }
} // checkWorkflowRunningQuit

- (void)terminateApp {
    
    [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
} // terminateApp

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlertsDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsavedQuit] ) {
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
    } else if ( [alertTag isEqualToString:NBCAlertTagWorkflowRunningQuit] ) {
        if ( returnCode == NSAlertFirstButtonReturn ) {             // Quit Anyway
            
            /*//////////////////////////////////////////////////////////////////////////////
             /// NEED TO IMPLEMENT THIS TO QUIT ALL RUNNING AND QUEUED WORKFLOWS         ///
             //////////////////////////////////////////////////////////////////////////////*/
            DDLogWarn(@"[WARN] Canceling all workflows...");
            /* --------------------------------------------------------------------------- */
            
            [self terminateApp];
        } else if ( returnCode == NSAlertSecondButtonReturn ) {     // Cancel
            [NSApp replyToApplicationShouldTerminate:NO];
        }
    }
} // alertReturnCode:alertInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateButtonBuild:(NSNotification *)notification {
    
    BOOL buttonState = [[notification userInfo][NBCNotificationUpdateButtonBuildUserInfoButtonState] boolValue];
    
    // --------------------------------------------------------------
    //  Only enable build button if connection to helper has been successful
    // --------------------------------------------------------------
    if ( _helperAvailable == YES ) {
        [_buttonBuild setEnabled:buttonState];
    } else {
        [_buttonBuild setEnabled:NO];
    }
} // updateButtonBuild

/*//////////////////////////////////////////////////////////////////////////////
 /// UNUSED - SOME WILL PROBABLY WILL BE USED IN THE FUTURE, KEEPING ATM     ///
 //////////////////////////////////////////////////////////////////////////////*/

- (void)diskDidChange:(NSNotification *)notif {
    
    NBCDisk *disk = [notif object];
    if ( [disk isMounted] ) {
    }
}

- (void)didAttemptMount:(NSNotification *)notif {
    
    NBCDisk *disk = [notif object];
    if ( [disk isMounted] ) {
    }
}

- (void)didAttemptUnmount:(NSNotification *)notif {
    
    NBCDisk *disk = [notif object];
    if ( [disk isMounted] ) {
    }
}

- (void)didAttemptEject:(NSNotification *)notif {
    
    NBCDisk *disk = [notif object];
    if ( [disk isMounted] ) {
    }
}
/* -------------------------------------------------------------------------- */

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Helper Tool
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)blessHelperWithLabel:(NSString *)label {
    
    DDLogInfo(@"Installing helper tool...");
    BOOL result = NO;
    NSError *error = nil;
    
    // --------------------------------------------------------------
    //  Create an Authorization Right for installing helper tool
    // --------------------------------------------------------------
    DDLogDebug(@"Creating authorization right...");
    AuthorizationItem authItem		= { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights	= { 1, &authItem };
    AuthorizationFlags flags		= kAuthorizationFlagDefaults |
    kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize |
    kAuthorizationFlagExtendRights;
    
    // --------------------------------------------------------------
    //  Try to obtain the right from authorization system (Ask User)
    // --------------------------------------------------------------
    DDLogDebug(@"Asking authorization system to grant right...");
    OSStatus status = AuthorizationCopyRights(_authRef, &authRights, kAuthorizationEmptyEnvironment, flags, NULL);
    if ( status != errAuthorizationSuccess ) {
        DDLogError(@"[ERROR] Could not install helper tool!");
        DDLogError(@"[ERROR] Authorization failed!");
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        DDLogError(@"[ERROR] %@", error);
    } else {
        CFErrorRef  cfError;
        DDLogDebug(@"Authorization successful!");
        
        // --------------------------------------------------------------
        //  Install helper tool using SMJobBless
        // --------------------------------------------------------------
        DDLogDebug(@"Running SMJobBless..");
        result = (BOOL) SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)label, _authRef, &cfError);
        if ( ! result ) {
            DDLogError(@"[ERROR] Could not install helper tool!");
            DDLogError(@"[ERROR] SMJobBless failed!");
            error = CFBridgingRelease(cfError);
            DDLogError(@"[ERROR] %@", error);
        }
    }
    
    return result;
} // blessHelperWithLabel

- (void)showHelperToolInstallBox {
    
    
    // --------------------------------------------------------------
    //  Show box with "Install Helper" button just above build button
    // --------------------------------------------------------------
    [_viewInstallHelper setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_viewMainWindow addSubview:_viewInstallHelper];
    [_viewMainWindow removeConstraint:_constraintBetweenButtonBuildAndViewOutput];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[_viewInstallHelper]-|"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_viewInstallHelper)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_viewNBISettings]-[_viewInstallHelper]-[_buttonBuild]"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_viewNBISettings, _viewInstallHelper, _buttonBuild)]];
    [_buttonBuild setEnabled:NO];
} // showHelperToolInstallBox

- (void)showHelperToolUpgradeBox {
    
    
    // --------------------------------------------------------------
    //  Show box with "Upgrade Helper" button just above build button
    // --------------------------------------------------------------
    [_textFieldInstallHelperText setStringValue:@"To create a NetInstall Image you need to upgrade the helper."];
    [_buttonInstallHelper setTitle:@"Upgrade Helper"];
    [self showHelperToolInstallBox];
} // showHelperToolUpgradeBox

- (void)hideHelperToolInstallBox {
    
    
    // --------------------------------------------------------------
    //  Hide box with "Install/Upgrade Helper" button
    // --------------------------------------------------------------
    [_viewInstallHelper removeFromSuperview];
    [_viewMainWindow addConstraint:_constraintBetweenButtonBuildAndViewOutput];
} // hideHelperToolInstallBox

- (void)checkHelperVersion {
    
    DDLogDebug(@"Checking currently installed helper tool version...");
    
    // --------------------------------------------------------------
    //  Get version of helper within our bundle
    // --------------------------------------------------------------
    NSString*       currentHelperToolBundlePath     = [NSString stringWithFormat:@"Contents/Library/LaunchServices/%@", NBCBundleIdentifierHelper];
    NSURL*          currentHelperToolURL            = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:currentHelperToolBundlePath];
    NSDictionary*   currentHelperToolInfoPlist      = (NSDictionary*)CFBridgingRelease(CFBundleCopyInfoDictionaryForURL((CFURLRef)currentHelperToolURL ));
    NSString*       currentHelperToolBundleVersion  = [currentHelperToolInfoPlist objectForKey:@"CFBundleVersion"];
    DDLogDebug(@"currentHelperToolBundleVersion=%@", currentHelperToolBundleVersion);
    
    // --------------------------------------------------------------
    //  Connect to helper and get installed helper's version
    // --------------------------------------------------------------
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
#pragma unused(proxyError)
        DDLogInfo(@"Unable to connect to the helper tool!");
        // --------------------------------------------------------------
        //  If connection failed, require (re)install of helper tool
        // --------------------------------------------------------------
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self setHelperAvailable:NO];
            [self showHelperToolInstallBox];
            [self->_buttonBuild setEnabled:NO];
        }];
        
    }] getVersionWithReply:^(NSString *version) {
        DDLogDebug(@"Connection to the helper tool successful!");
        DDLogDebug(@"Currently installed helper tool has version: %@", version);
        if ( ! [currentHelperToolBundleVersion isEqualToString:version] ) {
            
            DDLogInfo(@"A new version of the helper tool is availbale");
            // --------------------------------------------------------------
            //  If versions mismatch, require update of helper tool
            // --------------------------------------------------------------
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self setHelperAvailable:NO];
                [self showHelperToolUpgradeBox];
                [self->_buttonBuild setEnabled:NO];
            }];
        } else {
            DDLogDebug(@"Currently installed helper tool is up to date.");
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                [self setHelperAvailable:YES];
            }];
        }
    }];
} // checkHelperVersion

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Reachability
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)testInternetConnection {
    
    NSString *hostToCheck = @"github.com";
    // --------------------------------------------------------------
    //  Check if connection against github.com is succesful
    // --------------------------------------------------------------
    _internetReachableFoo = [Reachability reachabilityWithHostname:hostToCheck];
    __unsafe_unretained typeof(self) weakSelf = self;
    
    // --------------------------------------------------------------
    //  Host IS reachable
    // --------------------------------------------------------------
    _internetReachableFoo.reachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf hideNoInternetConnection];
            
            // --------------------------------------------------------------
            //  Check for updates to NBICreator
            // --------------------------------------------------------------
            if ( [[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsCheckForUpdates] boolValue] ) {
                [[NBCUpdater sharedUpdater] checkForUpdates];
            }
        });
    };
    
    // --------------------------------------------------------------
    //  Host is NOT reachable
    // --------------------------------------------------------------
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        DDLogDebug(@"Reachability: %@ is NOT reachable!", hostToCheck);
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf showNoInternetConnection];
        });
    };
    
    // --------------------------------------------------------------
    //  Start background notifier that will call above blocks if reachability changes
    // --------------------------------------------------------------
    [_internetReachableFoo startNotifier];
} // testInternetConnection

- (void)showNoInternetConnection {
    
    
    // --------------------------------------------------------------
    //  Show banner at top of application with text "No Internet Connection"
    // --------------------------------------------------------------
    [_viewNoInternetConnection setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_viewMainWindow addSubview:_viewNoInternetConnection positioned:NSWindowAbove relativeTo:nil];
    
    [_viewNoInternetConnection addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[_viewNoInternetConnection(==20)]"
                                                                                      options:0
                                                                                      metrics:nil
                                                                                        views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_viewNoInternetConnection]|"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
    [_viewMainWindow addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_viewNoInternetConnection]"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:NSDictionaryOfVariableBindings(_viewNoInternetConnection)]];
} // showNoInternetConnection

- (void)hideNoInternetConnection {
    
    
    // --------------------------------------------------------------
    //  Hider banner with text "No Internet Connection"
    // --------------------------------------------------------------
    [_viewNoInternetConnection removeFromSuperview];
} // hideNoInternetConnection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCArbitrator Functions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName {
    
    
    // --------------------------------------------------------------
    //  Return NBCDisk object for passed BSD identifier (if found)
    // --------------------------------------------------------------
    NSString *bsdNameCut = [bsdName lastPathComponent];
    NBCDisk *diskToReturn;
    for ( NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks] ) {
        if ( [[disk BSDName] isEqualToString:bsdNameCut] ) {
            diskToReturn = disk;
            break;
        }
    }
    return diskToReturn;
} // diskFromBSDName

+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL {
    
    
    // --------------------------------------------------------------
    //  Return NBCDisk object for passed VolumeURL (if found)
    // --------------------------------------------------------------
    NBCDisk *diskToReturn;
    for ( NBCDisk *disk in [[NBCDiskArbitrator sharedArbitrator] disks] ) {
        if ( [disk isMounted] ) {
            CFDictionaryRef diskDescription = [disk diskDescription];
            CFURLRef value = CFDictionaryGetValue(diskDescription, kDADiskDescriptionVolumePathKey);
            if ( value ) {
                if ( [[(__bridge NSURL *)value path] isEqualToString:[volumeURL path]]) {
                    return disk;
                }
            } else {
                DDLogWarn(@"[WARN] Disk %@ is listed as mounted but has no mountpoint!", diskDescription);
            }
        }
    }
    return diskToReturn;
} // diskFromVolumeURL

+(NSArray *)mountedDiskUUUIDs {
    
    // --------------------------------------------------------------
    //  Return array of UUIDs for all mounted disks
    // --------------------------------------------------------------
    NSMutableArray *diskUUIDs = [[NSMutableArray alloc] init];
    NSMutableSet *disks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for ( NBCDisk *disk in disks ) {
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)selectedSegment {
    return [_segmentedControlNBI selectedSegment];
} // selectedSegment

- (void)selectSegmentedControl:(NSInteger)selectedSegment {
    // --------------------------------------------------------------
    //  Add selected workflows views to main window placeholders
    // --------------------------------------------------------------
    if ( selectedSegment == kSegmentedControlNetInstall ) {
        if ( ! _niDropViewController ) {
            _niDropViewController = [[NBCNetInstallDropViewController alloc] init];
        }
        
        if ( _niDropViewController ) {
            [self addViewToDropView:[_niDropViewController view]];
        }
        
        if ( ! _niSettingsViewController ) {
            _niSettingsViewController = [[NBCNetInstallSettingsViewController alloc] init];
        }
        
        if ( _niSettingsViewController ) {
            [self addViewToSettingsView:[_niSettingsViewController view]];
            _currentSettingsController = _niSettingsViewController;
        }
    } else if (selectedSegment == kSegmentedControlDeployStudio) {
        if ( ! _dsDropViewController ) {
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
    } else if (selectedSegment == kSegmentedControlCasper) {
        if ( ! _casperDropViewController ) {
            _casperDropViewController = [[NBCCasperDropViewController alloc] init];
        }
        
        if ( _casperDropViewController ) {
            [self addViewToDropView:[_casperDropViewController view]];
        }
        
        if ( ! _casperSettingsViewController ) {
            _casperSettingsViewController = [[NBCCasperSettingsViewController alloc] init];
        }
        
        if ( _casperSettingsViewController ) {
            [self addViewToSettingsView:[_casperSettingsViewController view]];
            _currentSettingsController = _casperSettingsViewController;
        }
    }
    
    // --------------------------------------------------------------
    //  Update menu bar items with correct connections to currently selected workflow
    // --------------------------------------------------------------
    [_menuItemNew setAction:@selector(menuItemNew:)];
    [_menuItemNew setTarget:[_currentSettingsController templates]];
    
    [_menuItemSave setAction:@selector(menuItemSave:)];
    [_menuItemSave setTarget:[_currentSettingsController templates]];
    
    [_menuItemSaveAs setAction:@selector(menuItemSaveAs:)];
    [_menuItemSaveAs setTarget:[_currentSettingsController templates]];
    
    [_menuItemRename setAction:@selector(menuItemRename:)];
    [_menuItemRename setTarget:[_currentSettingsController templates]];
    
    [_menuItemExport setAction:@selector(menuItemExport:)];
    [_menuItemExport setTarget:[_currentSettingsController templates]];
    
    [_menuItemDelete setAction:@selector(menuItemDelete:)];
    [_menuItemDelete setTarget:[_currentSettingsController templates]];
    
    [_menuItemShowInFinder setAction:@selector(menuItemShowInFinder:)];
    [_menuItemShowInFinder setTarget:[_currentSettingsController templates]];
    
    [_window setInitialFirstResponder:[_currentSettingsController textFieldNBIName]];
    
    // --------------------------------------------------------------
    //  Verify that the currently selected workflow is ready to build
    // --------------------------------------------------------------
    [_currentSettingsController verifyBuildButton];
} // selectSegmentedControl

- (void)addViewToSettingsView:(NSView *)settingsView {
    // --------------------------------------------------------------
    //  Remove current view(s) from settings view placeholder
    // --------------------------------------------------------------
    NSArray *currentSubviews = [_viewNBISettings subviews];
    for ( NSView *view in currentSubviews ) {
        [view removeFromSuperview];
    }
    
    // --------------------------------------------------------------
    //  Add selected workflows settings view to settings view placeholder
    // --------------------------------------------------------------
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
    // --------------------------------------------------------------
    //  Remove current view(s) from drop view placeholder
    // --------------------------------------------------------------
    NSArray *currentSubviews = [[_viewDropView subviews] copy];
    for ( NSView *view in currentSubviews ) {
        [view removeFromSuperview];
    }
    
    // --------------------------------------------------------------
    //  Add selected workflows drop view to drop view placeholder
    // --------------------------------------------------------------
    [_viewDropView addSubview:dropView];
    [dropView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSArray *constraintsArray;
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|[dropView]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(dropView)];
    [_viewDropView addConstraints:constraintsArray];
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[dropView]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(dropView)];
    [_viewDropView addConstraints:constraintsArray];
    
    if ( [dropView isEqualTo:[_niDropViewController view]] ) {
        NSView *noSourceView = [_niDropViewController viewDropViewNoSource];
        [_viewDropView addSubview:noSourceView];
        [noSourceView setTranslatesAutoresizingMaskIntoConstraints:NO];
        constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|[noSourceView]|"
                                                                   options:0
                                                                   metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(noSourceView)];
        [_viewDropView addConstraints:constraintsArray];
        constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[noSourceView]|"
                                                                   options:0
                                                                   metrics:nil
                                                                     views:NSDictionaryOfVariableBindings(noSourceView)];
        [_viewDropView addConstraints:constraintsArray];
    }
    
} // addViewToDropView

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBActions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonInstallHelper:(id)sender {
#pragma unused(sender)
    
    if ( [self blessHelperWithLabel:NBCBundleIdentifierHelper] ) {
        [self setHelperAvailable:YES];
        [_currentSettingsController verifyBuildButton];
        [self hideHelperToolInstallBox];
    }
} // buttonInstallHelper

- (IBAction)buttonBuild:(id)sender {
#pragma unused(sender)
    if ( [NSEvent modifierFlags] & NSAlternateKeyMask ) {
        _optionBuildPanel = [[NBCOptionBuildPanel alloc] init];
        [[NSApp mainWindow] beginSheet:[_optionBuildPanel window] completionHandler:^(NSModalResponse returnCode) {
            NSLog(@"returnCode=%ld", (long)returnCode);
        }];
    } else {
        [_currentSettingsController buildNBI];
    }
} // buttonBuild

- (IBAction)segmentedControlNBI:(id)sender {
    
    NSSegmentedControl *segmentedControl = (NSSegmentedControl *) sender;
    [self selectSegmentedControl:[segmentedControl selectedSegment]];
} // segmentedControlNBI

- (IBAction)menuItemPreferences:(id)sender {
#pragma unused(sender)
    
    if ( ! _preferencesWindow ) {
        _preferencesWindow = [[NBCPreferences alloc] initWithWindowNibName:@"NBCPreferences"];
    }
    [_preferencesWindow updateCacheFolderSize];
    [[_preferencesWindow window] makeKeyAndOrderFront:self];
} // menuItemPreferences

- (IBAction)menuItemHelp:(id)sender {
#pragma unused(sender)
    
    DDLogInfo(@"Opening help URL: %@", NBCHelpURL);
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NBCHelpURL]];
} // menuItemHelp

- (IBAction)menuItemMainWindow:(id)sender {
#pragma unused(sender)
    
    if ( _window ) {
        [_window makeKeyAndOrderFront:self];
    }
}

@end
