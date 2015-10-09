//
//  NBCNIDropViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallDropViewController.h"
#import "NBCConstants.h"

#import "NBCAlerts.h"
#import "NBCDiskArbitrator.h"
#import "NBCController.h"
#import "NBCSourceController.h"
#import "NBCDiskImageController.h"
#import "NBCLogging.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallDropViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCNetInstallDropViewController" bundle:nil];
    if (self != nil) {
        
    }
    return self;
} // init

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(verifyDroppedSource:) name:NBCNotificationNetInstallVerifyDroppedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIType:) name:NBCNotificationNetInstallUpdateNBIType object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidAppearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidDisappearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidChangeNotification object:nil];
    
    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    _sourceDictLinks = [[NSMutableDictionary alloc] init];
    _sourceDictSources = [[NSMutableDictionary alloc] init];
    [self setInstallerApplicationIdentifiers:@[
                                               @"com.apple.InstallAssistant.ElCapitan",
                                               @"com.apple.InstallAssistant.OSX11Seed1",
                                               @"com.apple.InstallAssistant.Yosemite",
                                               @"com.apple.InstallAssistant.Mavericks",
                                               @"com.apple.InstallAssistant.MountainLion",
                                               @"com.apple.InstallAssistant.Lion"
                                               ]];
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI source view to allow to show source in Finder.
    // -------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *showInFinderMenuItem = [[NSMenuItem alloc] initWithTitle:NBCMenuItemShowInFinder action:@selector(showSourceInFinder) keyEquivalent:@""];
    [showInFinderMenuItem setTarget:self];
    [menu addItem:showInFinderMenuItem];
    [_viewDropView setMenu:menu];
    
    // --------------------------------------------------------------
    //  Get all Installers and update the source list
    // --------------------------------------------------------------
    [self updatePopUpButtonSource];
    
    [self showProgressPackageOnly];
    // --------------------------------------------------------------------------
    //  Loop to check boot disk
    // --------------------------------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(getSystemDisk:)
                                   userInfo:nil
                                    repeats:YES];
} // viewDidLoad

- (void)showSourceInFinder {
    if ( _source ) {
        NSURL *sourceURL = _sourceDictLinks[_selectedSource];
        if ( [sourceURL checkResourceIsReachableAndReturnError:nil] ) {
            NSArray *fileURLs = @[ sourceURL ];
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
        }
    }
} // showSourceInFinder

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    
    BOOL retval = YES;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemShowInFinder] ) {
        if ( ! _source  ) {
            retval = NO;
        }
        return retval;
    }
    
    return YES;
} // validateMenuItem

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateNBIType:(NSNotification *)notification {
    if ( [[notification userInfo][NBCSettingsNetInstallPackageOnlyKey] boolValue] ) {
        [self hideSourceView];
    } else {
        [self showSourceView];
    }
}

- (void)updateSourceList:(NSNotification *)notification {
#pragma unused(notification)
    
    [self updatePopUpButtonSource];
    
} // updateSourceList

- (void)verifyDroppedSource:(NSNotification *)notification {
    
    NSURL *sourceURL = [notification userInfo][NBCNotificationVerifyDroppedSourceUserInfoSourceURL];
    [self verifySource:sourceURL];
    
} // verifyDroppedSource

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Content Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSourceInfo:(NBCSource *)source {
    
    NSString *sourceType = [source sourceType];
    NSString *baseSystemOSVersion = [source baseSystemOSVersion];
    NSString *baseSystemOSBuild = [source baseSystemOSBuild];
    
    // ------------------------------------------------------
    //  Set Source Title to system version string
    // ------------------------------------------------------
    NSString *systemVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", baseSystemOSVersion, baseSystemOSBuild];
    [_textFieldSourceTitle setStringValue:systemVersionString];
    
    // ------------------------------------------------------
    //  Set Source Field 1 and 2 depending on source type
    // ------------------------------------------------------
    if ( [sourceType isEqualToString:NBCSourceTypeInstallESDDiskImage] ) {
        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"InstallESD"];
        
        [_textFieldSourceField2Label setStringValue:@"Image Name:"];
        [_textFieldSourceField2 setStringValue:[[[source installESDDiskImageURL] path] lastPathComponent]];
        
        NSImage *diskImageImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconDMG" withExtension:@"icns"]];
        [_imageViewSourceMini setImage:diskImageImage];
    } else {
        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"Installer Application"];
        
        [_textFieldSourceField2Label setStringValue:@"Name:"];
        [_textFieldSourceField2 setStringValue:[[source osxInstallerURL] lastPathComponent]];
        [_imageViewSourceMini setImage:nil];
    }
    
    // ---------------------------------------------------------
    //  Set source image to installer application or OS Version
    // ---------------------------------------------------------
    NSURL *sourceIconURL = [source osxInstallerIconURL];
    if ( [sourceIconURL checkResourceIsReachableAndReturnError:nil] ) {
        NSImage *sourceIcon = [[NSImage alloc] initWithContentsOfURL:sourceIconURL];
        [_imageViewSource setImage:sourceIcon];
    } else {
        NSImage *productImage = [source productImageForOSVersion:baseSystemOSVersion];
        if ( productImage ) {
            [_imageViewSource setImage:productImage];
        }
    }
    
    // ---------------------------------------------------------
    //  Post notification to update source
    // ---------------------------------------------------------
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationNetInstallUpdateSource
                                                        object:self
                                                      userInfo:@{ NBCNotificationUpdateSourceUserInfoSource : source }];
    
    // ---------------------------------------------------------
    //  Show source info in UI
    // ---------------------------------------------------------
    [self showSource];
} // updateSourceInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Layout Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)showProgress {
    
    // ------------------------------------------------------
    //  Hide and Resize Source PopUpButton
    // ------------------------------------------------------
    [_popUpButtonSource setHidden:YES];
    [_constraintPopUpButtonSourceWidth setConstant:18.0];
    
    // ------------------------------------------------------
    //  Hide Source Layout
    // ------------------------------------------------------
    [_imageViewSource setHidden:YES];
    [_imageViewSourceMini setHidden:YES];
    [_textFieldSourceTitle setHidden:YES];
    [_textFieldSourceField1Label setHidden:YES];
    [_textFieldSourceField1 setHidden:YES];
    [_textFieldSourceField2Label setHidden:YES];
    [_textFieldSourceField2 setHidden:YES];
    
    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageViewDropImage setHidden:YES];
    [_textFieldChooseInstaller setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDropInstallESDHere setHidden:YES];
    [_verticalLine setHidden:YES];
    
    // ------------------------------------------------------
    //  Start and Show Progress
    // ------------------------------------------------------
    [_progressIndicatorStatus startAnimation:self];
    [_progressIndicatorStatus setHidden:NO];
    [_textFieldStatus setHidden:NO];
} // showProgress

- (void)showProgressPackageOnly {
    [_textFieldStatusPackageOnly setStringValue:@"Checking System Version..."];
    
    // ------------------------------------------------------
    //  Hide Source Layout
    // ------------------------------------------------------
    [_imageViewNoSource setHidden:YES];
    [_imageViewNoSourceMini setHidden:YES];
    [_textFieldNoSourceTitle setHidden:YES];
    [_textFieldSourceField1LabelPackageOnly setHidden:YES];
    [_textFieldSourceField1PackageOnly setHidden:YES];
    [_textFieldSourceField2LabelPackageOnly setHidden:YES];
    [_textFieldSourceField2PackageOnly setHidden:YES];
    
    // ------------------------------------------------------
    //  Start and Show Progress
    // ------------------------------------------------------
    [_progressIndicatorStatusPackageOnly startAnimation:self];
    [_progressIndicatorStatusPackageOnly setHidden:NO];
    [_textFieldStatusPackageOnly setHidden:NO];
} // showProgressPackageOnly

- (void)showSourcePackageOnly {
    
    // ------------------------------------------------------
    //  Start and Show Progress
    // ------------------------------------------------------
    [_progressIndicatorStatusPackageOnly stopAnimation:self];
    [_progressIndicatorStatusPackageOnly setHidden:YES];
    [_textFieldStatusPackageOnly setHidden:YES];
    
    // ------------------------------------------------------
    //  Hide Source Layout
    // ------------------------------------------------------
    [_imageViewNoSource setHidden:NO];
    [_imageViewNoSourceMini setHidden:NO];
    [_textFieldNoSourceTitle setHidden:NO];
    [_textFieldSourceField1LabelPackageOnly setHidden:NO];
    [_textFieldSourceField1PackageOnly setHidden:NO];
    [_textFieldSourceField2LabelPackageOnly setHidden:NO];
    [_textFieldSourceField2PackageOnly setHidden:NO];
} // showSourcePackageOnly

- (void)showSource {
    
    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:18.0];
    
    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageViewDropImage setHidden:YES];
    [_textFieldChooseInstaller setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDropInstallESDHere setHidden:YES];
    [_verticalLine setHidden:YES];
    
    // ------------------------------------------------------
    //  Stop and Hide Progress
    // ------------------------------------------------------
    [_progressIndicatorStatus stopAnimation:self];
    [_progressIndicatorStatus setHidden:YES];
    [_textFieldStatus setHidden:YES];
    
    // ------------------------------------------------------
    //  Show Source PopUpButton
    // ------------------------------------------------------
    [_popUpButtonSource setHidden:NO];
    
    // ------------------------------------------------------
    //  Show Source Layout
    // ------------------------------------------------------
    [_imageViewSource setHidden:NO];
    [_imageViewSourceMini setHidden:NO];
    [_textFieldSourceTitle setHidden:NO];
    [_textFieldSourceField1Label setHidden:NO];
    [_textFieldSourceField1 setHidden:NO];
    [_textFieldSourceField2Label setHidden:NO];
    [_textFieldSourceField2 setHidden:NO];
} // showSource

- (void)hideSourceView {
    if ( _sourcePackageOnly ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationNetInstallUpdateSource
                                                            object:self
                                                          userInfo:@{ NBCNotificationUpdateSourceUserInfoSource : _sourcePackageOnly }];
    }
    [_viewDropViewNoSource setHidden:NO];
    [_viewDropView setHidden:YES];
} // hideSourceView

- (void)showSourceView {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    if ( _source ) {
        [nc postNotificationName:NBCNotificationNetInstallUpdateSource
                          object:self
                        userInfo:@{ NBCNotificationUpdateSourceUserInfoSource : _source }];
    } else {
        [nc postNotificationName:NBCNotificationNetInstallRemovedSource object:self userInfo:nil];
    }
    [_viewDropView setHidden:NO];
    [_viewDropViewNoSource setHidden:YES];
    
} // showSourceView

- (void)restoreDropView {
    
    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:235.0];
    
    // ------------------------------------------------------
    //  Stop and Hide Progress Layout
    // ------------------------------------------------------
    [_progressIndicatorStatus stopAnimation:self];
    [_progressIndicatorStatus setHidden:YES];
    [_textFieldStatus setHidden:YES];
    
    // ------------------------------------------------------
    //  Hide Source Layout
    // ------------------------------------------------------
    [_imageViewSource setHidden:YES];
    [_imageViewSourceMini setHidden:YES];
    [_textFieldSourceTitle setHidden:YES];
    [_textFieldSourceField1Label setHidden:YES];
    [_textFieldSourceField1 setHidden:YES];
    [_textFieldSourceField2Label setHidden:YES];
    [_textFieldSourceField2 setHidden:YES];
    
    // ------------------------------------------------------
    //  Show Source PopUpButton
    // ------------------------------------------------------
    [_popUpButtonSource setHidden:NO];
    
    // ------------------------------------------------------
    //  Show Default Layout
    // ------------------------------------------------------
    [_imageViewDropImage setHidden:NO];
    [_textFieldChooseInstaller setHidden:NO];
    [_textFieldOr setHidden:NO];
    [_textFieldDropInstallESDHere setHidden:NO];
    [_verticalLine setHidden:NO];
    
    [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
    
    // ------------------------------------------------------
    //  Post notification that source was removed
    // ------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationNetInstallRemovedSource object:self userInfo:nil];
    [self setSource:nil];
} // restoreDropView

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Source
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)popUpButtonSource:(id)sender {
    [self setSelectedSource:[[sender selectedItem] title]];
    
    // --------------------------------------------------------------------------------------------
    //  If "No Selection" got selected, remove source from UI and post removed source notification
    // --------------------------------------------------------------------------------------------
    if ( [_selectedSource isEqualToString:NBCMenuItemNoSelection] ) {
        [self restoreDropView];
        return;
    }
    
    // ----------------------------------------------------------------------
    //  Get selected source URL and/or Source Object.
    //  If already checked, update UI from source object, else verify source
    // ----------------------------------------------------------------------
    id selectedItem = _sourceDictLinks[_selectedSource];
    NBCSource *selectedSource = _sourceDictSources[_selectedSource];
    if ( selectedSource != nil ) {
        [self setSource:selectedSource];
        
        NSDictionary *userInfo = @{ NBCNotificationUpdateSourceUserInfoSource : selectedSource };
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationNetInstallUpdateSource object:self userInfo:userInfo];
        
        [self updateSourceInfo:_source];
    } else {
        [self verifyPopUpButtonSelection:selectedItem];
    }
} // popUpButtonSource

- (void)updatePopUpButtonSource {
    
    [_popUpButtonSource removeAllItems];
    [_popUpButtonSource addItemWithTitle:NBCMenuItemNoSelection];
    
    NSArray *installerApplicationURLs = [self installerApplications];
    
    // ------------------------------------------------------
    //  Add all installer applications to source popUpButton
    // ------------------------------------------------------
    for ( NSURL *applicationURL in installerApplicationURLs ) {
        if ( [[applicationURL path] containsString:@"OS X Install ESD"] || [[applicationURL path] containsString:@"Mac OS X Base System"] ) {
            continue;
        }
        NSImage *applicationImage = [[NSWorkspace sharedWorkspace] iconForFile:[applicationURL path]];
        NSString *applicationName = [applicationURL path];
        //NSString *applicationName = [[applicationURL lastPathComponent] stringByDeletingPathExtension];
        
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:applicationName action:nil keyEquivalent:@""];
        [applicationImage setSize:NSMakeSize(16, 16)];
        [newMenuItem setImage:applicationImage];
        [[_popUpButtonSource menu] addItem:newMenuItem];
        
        _sourceDictLinks[applicationName] = applicationURL;
    }
    
    // --------------------------------------------------------------
    //  Add all mounted InstallESD disk images to source popUpButton
    // --------------------------------------------------------------
    NSSet *currentDisks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for ( NBCDisk *disk in currentDisks ) {
        NSString *volumeName = [disk volumeName];
        if ( [volumeName containsString:@"OS X Install ESD"] ) { // Only add disks that match this volume name
            NSURL *volumeURL = [disk volumeURL];
            NSURL *systemVersionPlist = [volumeURL URLByAppendingPathComponent:@"/System/Library/CoreServices/SystemVersion.plist"];
            if ( [systemVersionPlist checkResourceIsReachableAndReturnError:nil] ) {
                NSURL *diskImageURL = [NBCDiskImageController getDiskImageURLFromMountURL:volumeURL];
                if ( ( [[diskImageURL path] containsString:@"/Install OS X"] || [[diskImageURL path] containsString:@"/Install Mac OS X"] ) && [[diskImageURL path] containsString:@".app/"] ) {
                    continue;
                }
                
                NSDictionary *systemVersionDict = [[NSDictionary alloc] initWithContentsOfURL:systemVersionPlist];
                if ( systemVersionDict ) {
                    NSString *currentOSVersion = systemVersionDict[@"ProductUserVisibleVersion"];
                    NSString *currentOSBuild = systemVersionDict[@"ProductBuildVersion"];
                    NSString *menuItemTitle = [NSString stringWithFormat:@"%@ - %@ (%@)", volumeName, currentOSVersion, currentOSBuild];
                    
                    NSImage *icon = [[disk icon] copy];
                    NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:menuItemTitle action:nil keyEquivalent:@""];
                    [icon setSize:NSMakeSize(16, 16)];
                    [newMenuItem setImage:icon];
                    [[_popUpButtonSource menu] addItem:newMenuItem];
                    
                    _sourceDictLinks[menuItemTitle] = disk;
                }
            }
        }
    }
    
    if ( _selectedSource == nil ) {
        [self setSelectedSource:NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
    } else {
        [_popUpButtonSource selectItemWithTitle:_selectedSource];
    }
} // updatePopUpButtonSource

- (void)addSourceToPopUpButton:(NBCSource *)source {
    
    // ------------------------------------------------------
    //  Update source menu to include the newly mounted disk
    // ------------------------------------------------------
    [self updatePopUpButtonSource];
    
    // --------------------------------------------------------------------------
    //  Check which mounted URL matches current source and select it in the menu
    // --------------------------------------------------------------------------
    NSURL *sourceSystemVolumeURL = [source systemVolumeURL];
    for ( NSString *key in [_sourceDictLinks allKeys] ) {
        NBCDisk *disk = _sourceDictLinks[key];
        NSURL *diskVolumeURL = [disk volumeURL];
        if ( [sourceSystemVolumeURL isEqualTo:diskVolumeURL] ) {
            [_popUpButtonSource selectItemWithTitle:key];
            [self setSelectedSource:key];
            _sourceDictSources[_selectedSource] = source;
        }
    }
} // addSourceToPopUpButton

- (NSArray *)installerApplications {
    
    NSMutableArray *installerApplications = [[NSMutableArray alloc] init];
    
    CFErrorRef error = NULL;
    for ( NSString *bundleIdentifier in _installerApplicationIdentifiers ) {
        NSArray *applicationURLs = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)(bundleIdentifier), &error));
        if ( [applicationURLs count] != 0 ) {
            for (NSURL *url in applicationURLs) {
                if ( ! [[url path] containsString:@"/OS X Base System/Install"] ) {
                    [installerApplications addObject:url];
                }
            }
        } else if ( CFErrorGetCode(error) != kLSApplicationNotFoundErr ) {
            NSLog(@"Got no URLs from bundle Identifier \"%@\"", bundleIdentifier);
            NSLog(@"Error: %@", error);
        }
    }
    
    return [installerApplications copy];
} // installerApplications

- (void)verifyPopUpButtonSelection:(id)selectedItem {
    
    // --------------------------------------------------------------------------------------------
    //  If selected item isn't a NSURL, get the NSURL from the disk object to pass to verifySource
    // --------------------------------------------------------------------------------------------
    if ( [selectedItem isKindOfClass:[NSURL class]] ) {
        [self verifySource:selectedItem];
    } else if ( [selectedItem isKindOfClass:[NBCDisk class]] ) {
        if ( [selectedItem isMounted] ) {
            NSURL *diskImageURL = [NBCDiskImageController getDiskImageURLFromMountURL:[selectedItem volumeURL]];
            [self verifySource:diskImageURL];
        } else {
            NSLog(@"Selected Item is not Mounted!");
        }
    }
} // verifyPopUpButtonSelection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify URL
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)getSystemDisk:(NSTimer *)timer {
    NBCDisk *systemDisk = [NBCController diskFromVolumeURL:[NSURL fileURLWithPath:@"/"]];
    if ( systemDisk ) {
        [timer invalidate];
        timer = nil;
        [self verifyDisk:systemDisk];
    }
}

- (void)verifyDisk:(NBCDisk *)disk {
    NBCSource *newSource = [[NBCSource alloc] init];
    NBCSourceController *sourceController = [[NBCSourceController alloc] init];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        BOOL verified = YES;
        NSError *error;
        
        // ------------------------------------------------------
        //  Verify the source is a valid OS X System
        // ------------------------------------------------------
        if ( disk != nil ) {
            verified = [sourceController verifySystemFromDisk:disk source:newSource error:&error];
            if ( verified ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldStatusPackageOnly setStringValue:@"Checking Recovery Version..."];
                });
                verified = [sourceController verifyRecoveryPartitionFromSystemDisk:disk source:newSource error:&error];
                if ( ! verified ) {
                    DDLogError(@"Could not verify Recovery Partition!");
                    DDLogError(@"Error: %@", error);
                }
            }
            
            if ( verified ) {
                [self setSourcePackageOnly:newSource];
                NSString *systemOSVersion = [newSource systemOSVersion];
                NSString *baseSystemOSVersion = [newSource systemOSVersion];
                NSString *baseSystemOSBuild = [newSource systemOSBuild];
                // ------------------------------------------------------
                //  Set Source Info to No Source View
                // ------------------------------------------------------
                NSString *systemVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", baseSystemOSVersion, baseSystemOSBuild];
                NSImage *productImage = [newSource productImageForOSVersion:systemOSVersion];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldNoSourceTitle setStringValue:systemVersionString];
                    [self->_textFieldSourceField2PackageOnly setStringValue:[[newSource systemVolumeURL] path]];
                    if ( productImage ) {
                        [self->_imageViewNoSource setImage:productImage];
                    }
                    [self showSourcePackageOnly];
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationNetInstallUpdateSource
                                                                        object:self
                                                                      userInfo:@{ NBCNotificationUpdateSourceUserInfoSource : newSource }];
                });
            } else {
                DDLogError(@"Could not verify system disk!");
            }
        }
    });
}

- (void)verifySource:(NSURL *)sourceURL {
    
    // ------------------------------------------------------
    //  Disable build button while checking new source
    // ------------------------------------------------------
    NSDictionary * userInfo = @{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @NO };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:userInfo];
    
    // ------------------------------------------------------
    //  Update UI to show working progress
    // ------------------------------------------------------
    [_textFieldStatus setStringValue:@"Checking InstallESD Version..."];
    [self showProgress];
    
    NBCSource *newSource = [[NBCSource alloc] init];
    NBCSourceController *sourceController = [[NBCSourceController alloc] init];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        BOOL verified = YES;
        NSError *error;
        NSString *errorMessage;
        
        // ------------------------------------------------------
        //  If source is an installer app, get URL to InstallESD
        // ------------------------------------------------------
        verified = [sourceController getInstallESDURLfromSourceURL:sourceURL source:newSource error:&error];
        
        // ------------------------------------------------------
        //  Verify the source is a valid InstallESD Disk Image
        // ------------------------------------------------------
        if ( verified ) {
            NSURL *installESDDiskImageURL = [newSource installESDDiskImageURL];
            if ( installESDDiskImageURL != nil ) {
                verified = [sourceController verifyInstallESDFromDiskImageURL:installESDDiskImageURL source:newSource error:&error];
                if ( verified ) {
                    verified = [sourceController verifyBaseSystemFromSource:newSource error:&error];
                    if ( ! verified ) {
                        errorMessage = @"BaseSystem Verify Failed!";
                        NSLog(@"BaseSystem Verify Failed!");
                    }
                } else {
                    errorMessage = @"InstallESD Verify Failed!";
                    NSLog(@"InstallESD Verify Failed!");
                }
            } else {
                errorMessage = @"installESDURL is nil!";
                NSLog(@"installESDURL is nil!");
            }
        } else {
            NSLog(@"Invalid source!");
        }
        
        if ( verified ) {
            NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
            int osVersionMinor = (int)version.minorVersion;
            int sourceVersionMinor = (int)[[newSource expandVariables:@"%OSMINOR%"] integerValue];
            if ( osVersionMinor < sourceVersionMinor ) {
                NSString *osVersionString = [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
                errorMessage = [NSString stringWithFormat:@"This source contains OS X %@.\nYou are currently booted on OS X %@\n\nYou cannot create a NetInstall image using System Image Utility from sources with higher OS Minor Versions than your booted system.", [newSource baseSystemOSVersion], osVersionString];
                verified = NO;
            }
        }
        
        if ( verified ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateSourceInfo:newSource];
                self->_sourceDictSources[self->_selectedSource] = newSource;
                [self setSource:newSource];
                [newSource unmountBaseSystem];
                [newSource detachBaseSystem];
                [newSource unmountRecoveryHD];
            });
        } else {
            NSLog(@"Error: %@", error);
            [newSource detachAll];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self restoreDropView];
                [NBCAlerts showAlertUnrecognizedSourceForWorkflow:kWorkflowTypeNetInstall errorMessage:errorMessage];
            });
        }
    });
} // verifySource

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Dragging Destination Classes
#pragma mark -
#pragma mark NBCNetInstallDropView
////////////////////////////////////////////////////////////////////////////////

@implementation NBCNetInstallDropView

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ( draggedFileURL ) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ( draggedFileURL ) {
        NSDictionary * userInfo = @{ NBCNotificationVerifyDroppedSourceUserInfoSourceURL : draggedFileURL };
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationNetInstallVerifyDroppedSource object:self userInfo:userInfo];
        
        return YES;
    } else {
        return NO;
    }
}

- (NSURL *)getDraggedSourceURLFromPasteboard:(NSPasteboard *)pboard {
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        // ------------------------------------------------------
        //  Verify only one item is dropped
        // ------------------------------------------------------
        if ( [files count] != 1 ) {
            return nil;
        } else {
            
            // ---------------------------------------------------------------------------------
            //  Only accept a URL if it's a .app with InstallESD or a file that ends with .dmg
            // ---------------------------------------------------------------------------------
            NSURL *draggedFileURL = [NSURL fileURLWithPath:[files firstObject]];
            NSURL *draggedFileURLInstallESD = [draggedFileURL URLByAppendingPathComponent:@"Contents/SharedSupport/InstallESD.dmg"];
            if ( [draggedFileURLInstallESD checkResourceIsReachableAndReturnError:nil] == YES ) {
                return draggedFileURL;
            } else if ( [[draggedFileURL pathExtension] isEqualToString:@"dmg"] ) {
                return draggedFileURL;
            }
            return nil;
        }
    }
    return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCNetInstallDropViewBox
////////////////////////////////////////////////////////////////////////////////

@implementation NBCNetInstallDropViewBox

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
    NSDragOperation result = NSDragOperationNone;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate draggingEntered:sender];
    }
    
    return (result);
}   // draggingEntered

- (void)draggingExited:(id <NSDraggingInfo> )sender {
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [delegate draggingExited:sender];
    }
}   // draggingExited

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate prepareForDragOperation:sender];
    }
    
    return (result);
}   // prepareForDragOperation

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate performDragOperation:sender];
    }
    
    return (result);
}   // performDragOperation

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCNetInstallDropViewBox
////////////////////////////////////////////////////////////////////////////////

@implementation NBCNetInstallDropViewImageView

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
    NSDragOperation result = NSDragOperationNone;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate draggingEntered:sender];
    }
    
    return (result);
}   // draggingEntered

- (void)draggingExited:(id <NSDraggingInfo> )sender {
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [delegate draggingExited:sender];
    }
}   // draggingExited

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate prepareForDragOperation:sender];
    }
    
    return (result);
}   // prepareForDragOperation

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCNetInstallDropView *dropView = [[NBCNetInstallDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate performDragOperation:sender];
    }
    
    return (result);
}   // performDragOperation

@end
