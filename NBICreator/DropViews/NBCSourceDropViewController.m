//
//  NBCSourceDropViewController.m
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
#import "NBCApplicationSourceDeployStudio.h"
#import "NBCConstants.h"
#import "NBCController.h"
#import "NBCCustomSettingsViewController.h"
#import "NBCDiskArbitrator.h"
#import "NBCDiskController.h"
#import "NBCDiskImageController.h"
#import "NBCLogging.h"
#import "NBCSourceDropViewController.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Constants
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSourceTypeInstaller = @"NBCSourceTypeInstaller";
NSString *const NBCSourceTypeSystem = @"NBCSourceTypeSystem";
// NSString *const NBCSourceTypeNBI = @"NBCSourceTypeNBI";

@implementation NBCSourceDropViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCSourceDropViewDelegate>)delegate {
    self = [super initWithNibName:@"NBCSourceDropViewController" bundle:nil];
    if (self != nil) {
        _delegate = delegate;
    }
    return self;
} // init

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
} // dealloc

- (void)setDelegatesTo:(id)delegate forSubviewsOfView:(NSView *)view {
    for (NSView *subview in [view subviews]) {
        if ([subview isKindOfClass:[NBCDropViewBox class]]) {
            [(NBCDropViewBox *)subview setDelegate:delegate];
        } else if ([subview isKindOfClass:[NBCDropViewImageView class]]) {
            [(NBCDropViewImageView *)subview setDelegate:delegate];
        }

        [self setDelegatesTo:delegate forSubviewsOfView:subview];
    }
} // setDelegatesTo:forSubviewsOfView:

- (void)viewDidLoad {
    [super viewDidLoad];

    [self setSourceDictLinks:[[NSMutableDictionary alloc] init]];
    [self setSourceDictSources:[[NSMutableDictionary alloc] init]];

    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidAppearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidDisappearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidChangeNotification object:nil];

    [self setImageViews:@[ _imageView1, _imageView2, _imageView3 ]];
    [self setTextFields:@[ _textField1, _textField2, _textField3 ]];

    if ([_settingsViewController isKindOfClass:[NBCImagrSettingsViewController class]]) {
        [self setAllowNBISource:YES];
    } else {
        [self setAllowNBISource:NO];
    }

    [self setDropView:[[NBCDropView alloc] initWithDelegate:self]];
    [_dropView setAllowNBISource:_allowNBISource];
    [self setDelegatesTo:_dropView forSubviewsOfView:_viewDropView];

    if (_settingsViewController) {
        [_settingsViewController addObserver:self forKeyPath:@"nbiCreationTool" options:NSKeyValueObservingOptionNew context:nil];
        if ([_settingsViewController respondsToSelector:NSSelectorFromString(@"nbiType")]) {
            [_settingsViewController addObserver:self forKeyPath:@"nbiType" options:NSKeyValueObservingOptionNew context:nil];
        }
    }

    if (_delegate && [_delegate respondsToSelector:@selector(refreshCreationTool)]) {
        [_delegate refreshCreationTool];
    }

    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    [self setInstallerApplicationIdentifiers:@[
        @"com.apple.InstallAssistant.Sierra",
        @"com.apple.InstallAssistant.ElCapitan",
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

    [self setSourceReadOnlyShown:NO];

    [self hideNoSource];
} // viewDidLoad

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)

    if ([keyPath isEqualToString:@"nbiCreationTool"]) {
        NSString *creationTool = change[@"new"];
        if (![creationTool isKindOfClass:[NSNull class]]) {
            DDLogDebug(@"[DEBUG] Selected creation tool: %@", creationTool);

            if ([creationTool length] != 0 && [_creationTool length] == 0) {
                [self setCreationTool:creationTool];
                [self setSourceTypes:[NBCSourceDropViewController sourceTypesForCreationTool:creationTool allowNBISource:_allowNBISource] ?: @[]];
                [self updateViewForSourceTypes];

            } else if ([creationTool length] != 0 && ![creationTool isEqualToString:_creationTool]) {
                [self setCreationTool:creationTool];
                [self setSourceTypes:[NBCSourceDropViewController sourceTypesForCreationTool:creationTool allowNBISource:_allowNBISource] ?: @[]];
                [self updateViewForSourceTypes];

                if ([_nbiSelectedSource length] != 0 && _sourceNBI) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceNBI target:nil];
                    }
                } else if ([creationTool isEqualToString:NBCMenuItemNBICreator] && _sourceNBICreator) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceNBICreator target:nil];
                    }
                } else if ([creationTool isEqualToString:NBCMenuItemSystemImageUtility] && _sourceSystemImageUtility) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceSystemImageUtility target:nil];
                    }
                } else if ([creationTool isEqualToString:NBCMenuItemDeployStudioAssistant] && _sourceDeployStudioAssistant) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceDeployStudioAssistant target:nil];
                    }
                } else {
                    if (_delegate && [_delegate respondsToSelector:@selector(removedSource)]) {
                        [_delegate removedSource];
                    }
                }
            }
        }
    } else if ([keyPath isEqualToString:@"nbiType"]) {
        NSString *nbiType = change[@"new"];
        if (![nbiType isKindOfClass:[NSNull class]]) {
            DDLogDebug(@"[DEBUG] Selected nbi type: %@", nbiType);

            if ([nbiType length] != 0 && [_nbiType length] == 0) {
                [self setNbiType:nbiType];
                [self setSourceTypes:[NBCSourceDropViewController sourceTypesForNbiType:nbiType] ?: @[]];
                [self updateViewForSourceTypes];

            } else if ([nbiType length] != 0 && ![nbiType isEqualToString:_nbiType]) {
                [self setNbiType:nbiType];
                [self setSourceTypes:[NBCSourceDropViewController sourceTypesForNbiType:nbiType] ?: @[]];
                [self updateViewForSourceTypes];

                if ([nbiType isEqualToString:@"NetInstall"] && _sourceSystemImageUtility) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceSystemImageUtility target:nil];
                    }
                } else if ([nbiType isEqualToString:@"Package Only"] && _sourceSystemImageUtilityPackageOnly) {
                    if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
                        [_delegate updateSource:_sourceSystemImageUtilityPackageOnly target:nil];
                    }
                } else {
                    if (_delegate && [_delegate respondsToSelector:@selector(removedSource)]) {
                        [_delegate removedSource];
                    }
                }
            }
        }
    }
} // observeValueForKeyPath:ofObject:change:context

- (void)addSystemDisksToPopUpButton {

    // ------------------------------------------------------
    //  Add menu title: System Volumes
    // ------------------------------------------------------
    [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];
    NSMenuItem *titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"System Volumes" action:nil keyEquivalent:@""];
    [titleMenuItem setTarget:nil];
    [titleMenuItem setEnabled:NO];
    [[_popUpButtonSource menu] addItem:titleMenuItem];
    [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];

    // --------------------------------------------------------------
    //  Add all mounted OS X disks to source popUpButton
    // --------------------------------------------------------------
    NSSet *currentDisks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for (NBCDisk *disk in currentDisks) {
        if (!disk) {
            continue;
        }

        NSString *volumeName = [disk volumeName];
        if (![volumeName isEqualToString:@"Recovery HD"] && ![volumeName isEqualToString:@"OS X Base System"] && ![volumeName isEqualToString:@"Mac OS X Install ESD"] &&
            ![volumeName isEqualToString:@"DeployStudioRuntime"] && [volumeName length] != 0) {
            NSURL *volumeURL = [disk volumeURL];
            if (volumeURL) {
                NSURL *systemVersionPlist = [volumeURL URLByAppendingPathComponent:@"/System/Library/CoreServices/SystemVersion.plist"];
                if ([systemVersionPlist checkResourceIsReachableAndReturnError:nil]) {
                    NSDictionary *systemVersionDict = [[NSDictionary alloc] initWithContentsOfURL:systemVersionPlist];
                    if (systemVersionDict) {
                        if ([[volumeURL path] isEqualToString:@"/"]) {
                            volumeName = @"Booted System";
                        }

                        NSString *menuItemTitle =
                            [NSString stringWithFormat:@"%@ - %@ (%@)", volumeName, systemVersionDict[@"ProductUserVisibleVersion"] ?: @"", systemVersionDict[@"ProductBuildVersion"] ?: @""];
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
    }
}

- (void)addNBIToPopUpButton {

    // ------------------------------------------------------
    //  ONLY add this when an NBI is dropped
    // ------------------------------------------------------
    if ([_nbiSelectedSource length] != 0) {

        // ------------------------------------------------------
        //  Add menu title: NBI
        // ------------------------------------------------------
        [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"NBI" action:nil keyEquivalent:@""];
        [titleMenuItem setTarget:nil];
        [titleMenuItem setEnabled:NO];
        [[_popUpButtonSource menu] addItem:titleMenuItem];
        [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];

        // ------------------------------------------------------
        //  Add currently selected NBI to source popUpButton
        // ------------------------------------------------------
        NSMenuItem *newMenuItem = [[NSMenuItem alloc] initWithTitle:_nbiSelectedSource action:nil keyEquivalent:@""];
        NSURL *nbiURL = [_targetNBI nbiURL];
        if ([nbiURL checkResourceIsReachableAndReturnError:nil]) {
            NSImage *nbiImage = [[NSWorkspace sharedWorkspace] iconForFile:[nbiURL path]];
            [nbiImage setSize:NSMakeSize(16, 16)];
            [newMenuItem setImage:nbiImage];
        }
        [[_popUpButtonSource menu] addItem:newMenuItem];
    }
}

- (void)addInstallerToPopUpButton {

    // ------------------------------------------------------
    //  Add menu title: Installer Applications
    // ------------------------------------------------------
    [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];
    NSMenuItem *titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Installer Applications" action:nil keyEquivalent:@""];
    [titleMenuItem setTarget:nil];
    [titleMenuItem setEnabled:NO];
    [[_popUpButtonSource menu] addItem:titleMenuItem];
    [[_popUpButtonSource menu] addItem:[NSMenuItem separatorItem]];

    // ------------------------------------------------------
    //  Add all installer applications to source popUpButton
    // ------------------------------------------------------
    for (NSURL *applicationURL in [self installerApplications]) {
        if ([[applicationURL path] containsString:@"OS X Install ESD"] || [[applicationURL path] containsString:@"Mac OS X Base System"]) {
            continue;
        }
        NSImage *applicationImage = [[NSWorkspace sharedWorkspace] iconForFile:[applicationURL path]];
        NSString *applicationName = [applicationURL path];

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
    for (NBCDisk *disk in currentDisks) {
        NSString *volumeName = [disk volumeName];
        if ([volumeName containsString:@"OS X Install ESD"]) { // Only add disks that match this volume name
            NSURL *volumeURL = [disk volumeURL];
            NSURL *systemVersionPlist = [volumeURL URLByAppendingPathComponent:@"/System/Library/CoreServices/SystemVersion.plist"];
            if ([systemVersionPlist checkResourceIsReachableAndReturnError:nil]) {
                NSURL *diskImageURL = [NBCDiskImageController getDiskImageURLFromMountURL:volumeURL];
                if (([[diskImageURL path] containsString:@"/Install OS X"] || [[diskImageURL path] containsString:@"/Install Mac OS X"] || [[diskImageURL path] containsString:@"/Install macOS"]) &&
                    [[diskImageURL path] containsString:@".app/"]) {
                    continue;
                }

                NSDictionary *systemVersionDict = [[NSDictionary alloc] initWithContentsOfURL:systemVersionPlist];
                if ([systemVersionDict count] != 0) {
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
} // addInstallerToPopUpButton

- (void)showSourceInFinder {
    NSError *error = nil;
    if (_currentSource && ![[_currentSource sourceType] isEqualToString:NBCSourceTypeNBI]) {
        if (_currentSelectedSource) {
            NSURL *sourceURL;
            id sourceItem = _sourceDictLinks[_currentSelectedSource];
            if ([sourceItem isKindOfClass:[NBCDisk class]]) {
                sourceURL = [(NBCDisk *)sourceItem volumeURL];
                if (![(NBCDisk *)sourceItem isInternal]) {
                    sourceURL = [NBCDiskImageController getDiskImageURLFromMountURL:sourceURL];
                }
            } else if ([sourceItem isKindOfClass:[NSURL class]]) {
                sourceURL = (NSURL *)sourceItem;
            } else {
                DDLogError(@"[ERROR] Unknown source class: %@", [sourceItem class]);
                return;
            }

            if ([sourceURL checkResourceIsReachableAndReturnError:&error]) {
                NSArray *fileURLs = @[ sourceURL ];
                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
            } else {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
        } else {
            DDLogError(@"[ERROR] No source selected");
        }
    } else if ([[_currentSource sourceType] isEqualToString:NBCSourceTypeNBI]) {
        NSURL *sourceURL = [_currentSource sourceURL];
        if ([sourceURL checkResourceIsReachableAndReturnError:&error]) {
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ sourceURL ]];
        } else {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        DDLogError(@"[ERROR] No source available");
    }
} // showSourceInFinder

- (NSArray *)installerApplications {

    NSMutableArray *installerApplications = [[NSMutableArray alloc] init];

    CFErrorRef error = NULL;
    for (NSString *bundleIdentifier in _installerApplicationIdentifiers) {
        NSArray *applicationURLs = (__bridge NSArray *)(LSCopyApplicationURLsForBundleIdentifier((__bridge CFStringRef)(bundleIdentifier), &error));
        if ([applicationURLs count] != 0) {
            for (NSURL *url in applicationURLs) {
                if (![[url path] containsString:@"/OS X Base System/Install"] && ![[url path] containsString:@"/Volumes/dmg."]) {
                    [installerApplications addObject:url];
                }
            }
        } else if (CFErrorGetCode(error) != kLSApplicationNotFoundErr) {
            DDLogError(@"[ERROR] %@", error);
        }
    }

    if (error != NULL) {
        CFRelease(error);
    }
    return [installerApplications copy];
} // installerApplications

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    BOOL retval = YES;

    if ([[menuItem title] isEqualToString:NBCMenuItemShowInFinder]) {
        if (!_currentSource) {
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

- (void)updateSourceList:(NSNotification *)notification {
#pragma unused(notification)
    [self updatePopUpButtonSource];

} // updateSourceList

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Content Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSourceInfo:(NBCSource *)source {

    DDLogDebug(@"[DEBUG] Updating source info...");

    NSString *sourceType = [source sourceType];
    DDLogDebug(@"[DEBUG] Source type: %@", sourceType);

    if ([_creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {

        // -----------------------------------------------------------------
        //  If source os/build and baseSystem os/build mismatch, show error
        // -----------------------------------------------------------------
        if (![[source systemOSVersion] hasPrefix:@"10.6"] && (![[source systemOSVersion] isEqualToString:[source baseSystemOSVersion]])) {
            [self updateSourceInfoRecoveryMismatch:source];
            [self showRecoveryVersionMismatch];
            return;
        }

        // -----------------------------------------------------------------
        //  If sources is 10.6 and ds version is 1.7 +, show source error
        // -----------------------------------------------------------------
        NBCApplicationSourceDeployStudio *dsSource = [[NBCApplicationSourceDeployStudio alloc] init];
        int deployStudioVersionInt = [[[[dsSource dsAdminVersion] stringByReplacingOccurrencesOfString:@"." withString:@""] stringByPaddingToLength:4 withString:@"0" startingAtIndex:0] intValue];
        if ([[source systemOSVersion] hasPrefix:@"10.6"] && (1700 <= deployStudioVersionInt)) {
            [NBCAlerts showAlertErrorWithTitle:@"Unsupported Source Version"
                               informativeText:[NSString stringWithFormat:@"The installed version of DeployStudio Assistant (%@) doesn't support creating NBIs from OS X 10.6.\n\nInstall DeployStudio "
                                                                          @"Assistant version 1.6.18 or lower.",
                                                                          [dsSource dsAdminVersion]]];
            [self restoreDropView];
            return;
        }
    }

    // ------------------------------------------------------
    //  Set Source Title to system version string
    // ------------------------------------------------------
    NSString *sourceVersionString;
    NSImage *sourceImage;

    // ------------------------------------------------------
    //  Source Type: System Disk
    // ------------------------------------------------------
    if ([sourceType isEqualToString:NBCSourceTypeSystemDisk]) {

        // ---------------------------------------------------------
        //  Update source on delegates
        // ---------------------------------------------------------
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:nil];
        }

        sourceVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", [source sourceVersion], [source sourceBuild]];
        sourceImage = [source productImageForOSVersion:[source systemOSVersion]];

        [_textFieldSourceField1Label setStringValue:@"Source:"];
        NSString *volumeTypeString;
        if ([[source systemDisk] isInternal]) {
            volumeTypeString = @"Internal Disk";
        } else {
            volumeTypeString = @"External Disk";
        }
        [_textFieldSourceField1 setStringValue:volumeTypeString];

        [_textFieldSourceField2Label setStringValue:@"Mount Point:"];
        [_textFieldSourceField2 setStringValue:[[source systemVolumeURL] path] ?: @"Unknown"];

        [_imageViewSourceMini setImage:[[source systemDisk] icon]];

        // ------------------------------------------------------
        //  Source Type: System Disk Image
        // ------------------------------------------------------
    } else if ([sourceType isEqualToString:NBCSourceTypeSystemDiskImage]) {

        // ---------------------------------------------------------
        //  Update source on delegates
        // ---------------------------------------------------------
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:nil];
        }

        sourceVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", [source sourceVersion], [source sourceBuild]];
        sourceImage = [source productImageForOSVersion:[source sourceVersion]];

        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"Disk Image"];

        [_textFieldSourceField2Label setStringValue:@"Image Name:"];
        [_textFieldSourceField2 setStringValue:[[[source systemDiskImageURL] path] lastPathComponent] ?: @"Unknown"];

        [_imageViewSourceMini setImage:[[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconDMG" withExtension:@"icns"]]];

        // ------------------------------------------------------
        //  Source Type: InstallESD Disk Image
        // ------------------------------------------------------
    } else if ([sourceType isEqualToString:NBCSourceTypeInstallESDDiskImage]) {

        // ---------------------------------------------------------
        //  Update source on delegates
        // ---------------------------------------------------------
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:nil];
        }

        sourceVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", [source sourceVersion], [source sourceBuild]];
        sourceImage = [source productImageForOSVersion:[source sourceVersion]];

        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"InstallESD"];

        [_textFieldSourceField2Label setStringValue:@"Image Name:"];
        [_textFieldSourceField2 setStringValue:[[[source installESDDiskImageURL] path] lastPathComponent] ?: @"Unknown"];

        [_imageViewSourceMini setImage:[[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconDMG" withExtension:@"icns"]]];

        // ------------------------------------------------------
        //  Source Type: Install OS X Application
        // ------------------------------------------------------
    } else if ([sourceType isEqualToString:NBCSourceTypeInstallerApplication]) {

        // ---------------------------------------------------------
        //  Update source on delegates
        // ---------------------------------------------------------
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:nil];
        }

        sourceVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", [source sourceVersion], [source sourceBuild]];
        NSURL *installerIconURL = [source osxInstallerIconURL];
        if ([installerIconURL checkResourceIsReachableAndReturnError:nil]) {
            sourceImage = [[NSImage alloc] initWithContentsOfURL:installerIconURL];
        } else {
            sourceImage = [source productImageForOSVersion:[source sourceVersion]];
        }

        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"Installer Application"];

        [_textFieldSourceField2Label setStringValue:@"Name:"];
        [_textFieldSourceField2 setStringValue:[[source osxInstallerURL] lastPathComponent] ?: @"Unknown"];

        [_imageViewSourceMini setImage:nil];

        // ------------------------------------------------------
        //  Source Type: NBI
        // ------------------------------------------------------
    } else if ([sourceType isEqualToString:NBCSourceTypeNBI]) {

        // ---------------------------------------------------------
        //  Update source on delegates
        // ---------------------------------------------------------
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:_targetNBI];
        }

        sourceVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", [source sourceVersion], [source sourceBuild]];
        sourceImage = [source productImageForOSVersion:[source sourceVersion]];

        [_textFieldSourceField1Label setStringValue:@"Source:"];
        [_textFieldSourceField1 setStringValue:@"NetInstall Image"];

        [_textFieldSourceField2Label setStringValue:@"Name:"];
        [_textFieldSourceField2 setStringValue:[[_targetNBI nbiURL] lastPathComponent] ?: @"Unknown"];

        [_imageViewSourceMini setImage:[[NSWorkspace sharedWorkspace] iconForFile:[[_targetNBI nbiURL] path]]];
    } else {
        DDLogError(@"[ERROR] Unknown source type: %@", sourceType);
        return;
    }

    [_textFieldSourceTitle setStringValue:sourceVersionString];
    [_imageViewSource setImage:sourceImage];

    // ---------------------------------------------------------
    //  Show source info in UI
    // ---------------------------------------------------------
    [self showSource];
} // updateSourceInfo

- (void)updateSourceInfoRecoveryMismatch:(NBCSource *)source {

    NSString *systemOSVersion = [source systemOSVersion];
    NSString *systemOSBuild = [source systemOSBuild];
    NSString *baseSystemOSVersion = [source baseSystemOSVersion];
    NSString *baseSystemOSBuild = [source baseSystemOSBuild];
    NSString *systemVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", systemOSVersion, systemOSBuild];
    NSString *recoveryVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", baseSystemOSVersion, baseSystemOSBuild];
    NSString *sourceType = [source sourceType];
    NBCDisk *sourceSystemDisk = [source systemDisk];

    if ([sourceType isEqualToString:@"SystemDiskImage"]) {
        NSImage *diskImageImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconDMG" withExtension:@"icns"]];
        [_imageViewSourceMini setImage:diskImageImage];
    } else {
        NSImage *diskImage = [sourceSystemDisk icon];
        [_imageViewSourceMini setImage:diskImage];
    }

    // ------------------------------------------------------
    //  Set Source Field 1 to system version
    // ------------------------------------------------------
    [_textFieldSourceField1Label setStringValue:@"System:"];
    [_textFieldSourceField1 setStringValue:systemVersionString];

    // ------------------------------------------------------
    //  Set Source Field 2 to system recovery version
    // ------------------------------------------------------
    [_textFieldSourceField2Label setStringValue:@"Recovery:"];

    if (![systemOSVersion isEqualToString:baseSystemOSVersion]) {
        [_textFieldSourceTitle setStringValue:@"Recovery Version Mismatch!"];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:recoveryVersionString];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, string.length)];
        int max = (int)[recoveryVersionString length];
        int len = (max - 9);
        [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(9, (NSUInteger)len)];
        [_textFieldSourceField2 setAttributedStringValue:string];
    } else if (![systemOSBuild isEqualToString:baseSystemOSBuild]) {
        [_textFieldSourceTitle setStringValue:@"Recovery Version Mismatch!"];
        NSMutableAttributedString *recoveryVersionStringAttributed = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Mac OS X %@ (", baseSystemOSVersion]];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:baseSystemOSBuild];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, string.length)];
        int max = (int)[string length];
        [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0, (NSUInteger)max)];
        [recoveryVersionStringAttributed appendAttributedString:string];
        [recoveryVersionStringAttributed appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@")"]];
        [_textFieldSourceField2 setAttributedStringValue:recoveryVersionStringAttributed];
    } else {
        [_textFieldSourceField2 setStringValue:recoveryVersionString];
    }

    [_imageViewSource setImage:[source productImageForOSVersion:systemOSVersion]];

} // updateSourceInfoRecoveryMismatch

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
    [_imageView1 setHidden:YES];
    [_imageView2 setHidden:YES];
    [_imageView3 setHidden:YES];
    [_textFieldChoose setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDrop setHidden:YES];
    [_verticalLine setHidden:YES];

    // ------------------------------------------------------
    //  Start and Show Progress
    // ------------------------------------------------------
    [_progressIndicatorStatus startAnimation:self];
    [_progressIndicatorStatus setHidden:NO];
    [_textFieldStatus setHidden:NO];
} // showProgress

- (void)showRecoveryVersionMismatch {

    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:18.0];

    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageView1 setHidden:YES];
    [_imageView2 setHidden:YES];
    [_imageView3 setHidden:YES];
    [_textFieldChoose setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDrop setHidden:YES];
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
    //  Show Source Layout/Version Mismatch
    // ------------------------------------------------------
    [_imageViewSource setHidden:NO];
    [_imageViewSourceMini setHidden:NO];
    [_textFieldSourceTitle setHidden:NO];
    [_textFieldSourceField1Label setHidden:NO];
    [_textFieldSourceField1 setHidden:NO];
    [_textFieldSourceField2Label setHidden:NO];
    [_textFieldSourceField2 setHidden:NO];

    // ------------------------------------------------------
    //  Show Recovery Version Mismatch Alert
    // ------------------------------------------------------
    [NBCAlerts showAlertRecoveryVersionMismatch];
} // showRecoveryVersionMismatch

- (void)restoreDropView {
    DDLogDebug(@"[DEBUG] Restoring drop view");

    // ------------------------------------------------------
    //  Post notification that source was removed
    // ------------------------------------------------------
    if (_delegate && [_delegate respondsToSelector:@selector(removedSource)]) {
        [_delegate removedSource];
    }

    [self hideSource];
    [self removeSource];
    [self updateViewForSourceTypes];
} // restoreDropView

- (void)hideSource {
    DDLogDebug(@"[DEBUG] Hiding source from drop view");

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
    [_textFieldChoose setHidden:NO];
    [_textFieldOr setHidden:NO];
    [_textFieldDrop setHidden:NO];
    [_verticalLine setHidden:NO];
}

- (void)showSource {
    DDLogDebug(@"[DEBUG] Showing source in drop view");

    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:18.0];

    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageView1 setHidden:YES];
    [_imageView2 setHidden:YES];
    [_imageView3 setHidden:YES];
    [_textFieldChoose setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDrop setHidden:YES];
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

- (void)showNoSource {
    [_viewNoSource setHidden:NO];
    [_viewDropView setHidden:YES];
} // showNoSource

- (void)hideNoSource {
    [_viewDropView setHidden:NO];
    [_viewNoSource setHidden:YES];
} // hideNoSource

- (void)updateViewForOneSource {
    [_constraintVerticalToImageView1 setConstant:102.0];
    [self hideSource];
    [_imageView1 setHidden:NO];
    [_textField1 setHidden:NO];
    [_imageView2 setHidden:YES];
    [_textField2 setHidden:YES];
    [_imageView3 setHidden:YES];
    [_textField3 setHidden:YES];
} // updateViewForOneSource

- (void)updateViewForTwoSources {
    [_constraintVerticalToImageView1 setConstant:67.0];
    [self hideSource];
    [_imageView1 setHidden:NO];
    [_textField1 setHidden:NO];
    [_imageView2 setHidden:NO];
    [_textField2 setHidden:NO];
    [_imageView3 setHidden:YES];
    [_textField3 setHidden:YES];
} // updateViewForTwoSources

- (void)updateViewForThreeSources {
    [_constraintVerticalToImageView1 setConstant:32.0];
    [self hideSource];
    [_imageView1 setHidden:NO];
    [_textField1 setHidden:NO];
    [_imageView2 setHidden:NO];
    [_textField2 setHidden:NO];
    [_imageView3 setHidden:NO];
    [_textField3 setHidden:NO];
} // updateViewForThreeSources

- (void)updateViewForSourceTypes {

    [self updatePopUpButtonSource];

    [_sourceTypes enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
#pragma unused(stop)
      NSImage *image;
      if ([obj isEqualToString:NBCSourceTypeInstaller]) {
          image = [NSImage imageNamed:@"IconDMG.icns"];
          [self->_imageViews[idx] setImage:image];
          [self->_textFields[idx] setStringValue:@"InstallESD"];
      } else if ([obj isEqualToString:NBCSourceTypeSystem]) {
          image = [NSImage imageNamed:@"IconElCapitan.icns"];
          [self->_imageViews[idx] setImage:image];
          [self->_textFields[idx] setStringValue:@"System"];
      } else if ([obj isEqualToString:NBCSourceTypeNBI]) {
          image = [NSImage imageNamed:@"IconNetBootNBI.icns"];
          [self->_imageViews[idx] setImage:image];
          [self->_textFields[idx] setStringValue:@"NBI"];
      } else {
          DDLogError(@"[ERROR] Unknown source type: %@", obj);
      }
    }];

    DDLogDebug(@"[DEBUG] Current creation tool: %@", _creationTool);

    if ([_nbiSelectedSource length] != 0) {
        [self updateSourceInfo:_sourceNBI];
        [self setCurrentSelectedSource:_nbiSelectedSource ?: NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:_nbiSelectedSource ?: NBCMenuItemNoSelection];
    } else if ([_creationTool isEqualToString:NBCMenuItemNBICreator] && _sourceNBICreator) {
        [self updateSourceInfo:_sourceNBICreator];
        [self setCurrentSelectedSource:_nbiCreatorSelectedSource ?: NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:_nbiCreatorSelectedSource ?: NBCMenuItemNoSelection];
    } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility] && [_nbiType isEqualToString:@"Package Only"] && _sourceSystemImageUtilityPackageOnly) {
        [self updateSourceInfo:_sourceSystemImageUtilityPackageOnly];
        [self setCurrentSelectedSource:_systemImageUtilityPackageOnlySelectedSource ?: NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:_systemImageUtilityPackageOnlySelectedSource ?: NBCMenuItemNoSelection];
    } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility] && _sourceSystemImageUtility && ![_nbiType isEqualToString:@"Package Only"]) {
        [self updateSourceInfo:_sourceSystemImageUtility];
        [self setCurrentSelectedSource:_systemImageUtilitySelectedSource ?: NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:_systemImageUtilitySelectedSource ?: NBCMenuItemNoSelection];
    } else if ([_creationTool isEqualToString:NBCMenuItemDeployStudioAssistant] && _sourceDeployStudioAssistant) {
        [self updateSourceInfo:_sourceDeployStudioAssistant];
        [self setCurrentSelectedSource:_deployStudioAssistantSelectedSource ?: NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:_deployStudioAssistantSelectedSource ?: NBCMenuItemNoSelection];
    } else {
        switch ([_sourceTypes count]) {
        case 1:
            [self updateViewForOneSource];
            break;
        case 2:
            [self updateViewForTwoSources];
            break;
        case 3:
            [self updateViewForThreeSources];
            break;
        default:
            DDLogError(@"[ERROR] Cannot have more than three sources in drop view!");
            return;
            break;
        }
        [self setCurrentSelectedSource:NBCMenuItemNoSelection];
        [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
    }
} // updateViewForSourceTypes

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Source
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopUpButtonSource {

    NSString *currentSelection = [_popUpButtonSource titleOfSelectedItem];

    [_popUpButtonSource removeAllItems];
    [_popUpButtonSource addItemWithTitle:NBCMenuItemNoSelection];
    [[_popUpButtonSource menu] setAutoenablesItems:NO];

    [_sourceTypes enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
#pragma unused(idx, stop)
      if ([obj isEqualToString:NBCSourceTypeInstaller]) {
          [self addInstallerToPopUpButton];
      } else if ([obj isEqualToString:NBCSourceTypeSystem]) {
          [self addSystemDisksToPopUpButton];
      } else if ([obj isEqualToString:NBCSourceTypeNBI]) {
          [self addNBIToPopUpButton];
      } else {
          DDLogError(@"[ERROR] Unknown source type: %@", obj);
      }
    }];

    [_popUpButtonSource selectItemWithTitle:currentSelection ?: NBCMenuItemNoSelection];
} // updatePopUpButtonSource

- (IBAction)popUpButtonSource:(id)sender {

    NSString *selectedSource = [[sender selectedItem] title];
    DDLogInfo(@"Selected source: %@", selectedSource);

    // --------------------------------------------------------------------------------------------
    //  If an NBI is selected twice, don't update anything, else remove nbi selection
    // --------------------------------------------------------------------------------------------
    if ([selectedSource isEqualToString:_nbiSelectedSource]) {
        return;
    } else {
        [self setNbiSelectedSource:nil];
    }

    // --------------------------------------------------------------------------------------------
    //  If "No Selection" got selected, remove source from UI and post removed source notification
    // --------------------------------------------------------------------------------------------
    if ([selectedSource isEqualToString:NBCMenuItemNoSelection]) {
        [self restoreDropView];
        return;
    }

    [self updateSourceSelection:[[sender selectedItem] title] creationTool:_creationTool];

    // ----------------------------------------------------------------------
    //  Get selected source URL and/or Source Object.
    //  If already checked, update UI from source object, else verify source
    // ----------------------------------------------------------------------
    id selectedItem = _sourceDictLinks[_currentSelectedSource];
    NBCSource *source = _sourceDictSources[_currentSelectedSource];

    if (source) {
        [self updateSource:source creationTool:_creationTool nbiType:_nbiType];
        if (_delegate && [_delegate respondsToSelector:@selector(updateSource:target:)]) {
            [_delegate updateSource:source target:nil];
        }
        [self updateSourceInfo:source];
    } else {
        [self verifyPopUpButtonSelection:selectedItem];
    }
} // popUpButtonSource

- (void)addSourceToPopUpButton:(NBCSource *)source {

    // ------------------------------------------------------
    //  Update source menu to include the newly mounted disk
    // ------------------------------------------------------
    [self updatePopUpButtonSource];

    // --------------------------------------------------------------------------
    //  Check which mounted URL matches current source and select it in the menu
    // --------------------------------------------------------------------------
    NSURL *sourceSystemVolumeURL = [source systemVolumeURL];
    for (NSString *key in [_sourceDictLinks allKeys]) {
        NBCDisk *disk = _sourceDictLinks[key];
        NSURL *diskVolumeURL = [disk volumeURL];
        if ([sourceSystemVolumeURL isEqualTo:diskVolumeURL]) {
            [_popUpButtonSource selectItemWithTitle:key];
            [self updateSourceSelection:key creationTool:_creationTool];
            //_sourceDictSources[_selectedSource] = source;
        }
    }
} // addSourceToPopUpButton

- (void)verifyPopUpButtonSelection:(id)selectedItem {

    // --------------------------------------------------------------------------------------------
    //  If selected item isn't a NSURL, get the NSURL from the disk object to pass to verifySource
    // --------------------------------------------------------------------------------------------
    if ([selectedItem isKindOfClass:[NSURL class]]) {
        [self verifySourceAtURL:selectedItem];
    } else if ([selectedItem isKindOfClass:[NBCDisk class]]) {
        if ([[(NBCDisk *)selectedItem deviceModel] isEqualToString:NBCDiskDeviceModelDiskImage]) {
            NSURL *diskImageURL = [NBCDiskImageController getDiskImageURLFromMountURL:[selectedItem volumeURL]];
            [self verifySourceAtURL:diskImageURL];
        } else {
            if ([(NBCDisk *)selectedItem isMounted]) {
                [self verifySourceAtURL:[(NBCDisk *)selectedItem volumeURL]];
            } else {
                [(NBCDisk *)selectedItem mount];
                if ([(NBCDisk *)selectedItem isMounted]) {
                    [self verifySourceAtURL:[(NBCDisk *)selectedItem volumeURL]];
                } else {
                    DDLogError(@"Could not mount disk named: %@", [(NBCDisk *)selectedItem volumeName]);
                }
            }
        }
    }
} // verifyPopUpButtonSelection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Source
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)verifySourceAtURL:(NSURL *)sourceURL {

    [self setNbiSelectedSource:nil];
    [self setSourceReadOnlyShown:NO];

    // ------------------------------------------------------
    //  Disable build button while checking new source
    // ------------------------------------------------------
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:@{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @NO }];

    // ------------------------------------------------------
    //  Update UI to show working progress
    // ------------------------------------------------------
    DDLogInfo(@"Checking Source Version...");
    [_textFieldStatus setStringValue:@"Checking Source Version..."];
    [self showProgress];

    NSString *currentCreationTool = _creationTool;
    DDLogDebug(@"[DEBUG] Current creation tool: %@", currentCreationTool);

    NSString *currentNbiType = _nbiType;
    DDLogDebug(@"[DEBUG] Current nbi type: %@", currentNbiType);

    NSString *sourceExtension = [sourceURL pathExtension];
    DDLogDebug(@"[DEBUG] Source extension: %@", sourceExtension);

    // ------------------------------------------------------------------------------------------------------
    //  If dragging the InstallESD from within a OS X Installer.app, change source path to the installer app
    // ------------------------------------------------------------------------------------------------------
    if ([sourceExtension isEqualToString:@"dmg"] && [[sourceURL path] hasSuffix:[NSString stringWithFormat:@".app/Contents/SharedSupport/%@", [sourceURL lastPathComponent]]]) {
        sourceURL =
            [NSURL fileURLWithPath:[[sourceURL path] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"/Contents/SharedSupport/%@", [sourceURL lastPathComponent]] withString:@""]];
        sourceExtension = @"app";
    }

    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{

      NSError *error = nil;
      BOOL verified = NO;
      NBCSource *source = [[NBCSource alloc] init];
      NBCTarget *target = nil;

      if ([sourceExtension isEqualToString:@"dmg"]) {
          if ([self->_sourceTypes containsObject:NBCSourceTypeSystem]) {
              if ([NBCDiskImageController verifySystemDiskImage:sourceURL source:source requireRecoveryPartition:YES error:&error]) {
                  verified = YES;
                  [source setSourceType:NBCSourceTypeSystemDiskImage];
                  [source setSourceMenuName:[NSString stringWithFormat:@"%@ - %@ (%@)", [[source systemDisk] volumeName], [source sourceVersion], [source sourceBuild]]];
              }
          }

          if (!verified && [self->_sourceTypes containsObject:NBCSourceTypeInstaller]) {
              if ([NBCDiskImageController verifyInstallESDDiskImage:sourceURL source:source error:&error]) {
                  verified = YES;
                  [source setSourceType:NBCSourceTypeInstallESDDiskImage];
                  [source setSourceMenuName:[NSString stringWithFormat:@"%@ - %@ (%@)", [sourceURL path], [source sourceVersion], [source sourceBuild]]];
              }
          }
      } else if ([sourceExtension isEqualToString:@"app"]) {
          [source setSourceType:NBCSourceTypeInstallerApplication];
          if ([self->_sourceTypes containsObject:NBCSourceTypeInstaller]) {
              NSURL *installESDURL = [NBCDiskImageController installESDURLfromInstallerApplicationURL:sourceURL source:source error:&error];
              DDLogDebug(@"[DEBUG] InstallESD disk image path: %@", [installESDURL path]);

              if ([installESDURL checkResourceIsReachableAndReturnError:&error]) {
                  if ([NBCDiskImageController verifyInstallESDDiskImage:installESDURL source:source error:&error]) {
                      verified = YES;
                      [source setSourceMenuName:[sourceURL path]];
                  }
              }
          }
      } else if ([sourceExtension isEqualToString:@"nbi"]) {
          [source setSourceType:NBCSourceTypeNBI];
          if ([self->_sourceTypes containsObject:NBCSourceTypeNBI]) {
              NSURL *netInstallURL = [NBCDiskImageController netInstallURLFromNBI:sourceURL source:source error:&error];
              DDLogDebug(@"[DEBUG] NetInstall disk image path: %@", [netInstallURL path]);

              if ([netInstallURL checkResourceIsReachableAndReturnError:&error]) {
                  if (!target) {
                      target = [[NBCTarget alloc] init];
                  }

                  if ([NBCDiskImageController verifyNBINetInstallDiskImage:netInstallURL source:source target:target error:&error]) {
                      verified = YES;
                      [source setSourceURL:sourceURL];
                      [target setNbiURL:sourceURL];
                      [source setSourceMenuName:[NSString stringWithFormat:@"%@ - %@ (%@)", [sourceURL lastPathComponent], [source sourceVersion], [source sourceBuild]]];
                  }
              }
          }
      } else if ([sourceExtension length] == 0) {
          if ([self->_sourceTypes containsObject:NBCSourceTypeSystem]) {
              if ([NBCDiskController verifySystemDisk:[NBCDiskController diskFromVolumeURL:sourceURL] source:source requireRecoveryPartition:YES error:&error]) {
                  verified = YES;
                  [source setSourceType:NBCSourceTypeSystemDisk];
                  NSString *volumeName;
                  if ([[[[source systemDisk] volumeURL] path] isEqualToString:@"/"]) {
                      volumeName = @"Booted System";
                  } else {
                      volumeName = [[source systemDisk] volumeName];
                  }
                  [source setSourceMenuName:[NSString stringWithFormat:@"%@ - %@ (%@)", volumeName, [source sourceVersion], [source sourceBuild]]];
              }
          }
      }

      if (verified) {
          if ([[source sourceType] isEqualToString:NBCSourceTypeNBI]) {
              if (![[NSFileManager defaultManager] isWritableFileAtPath:[[source sourceURL] path]]) {
                  if (!self->_sourceReadOnlyShown) {
                      [self setSourceReadOnlyShown:YES];
                      dispatch_async(dispatch_get_main_queue(), ^{
                        [NBCAlerts showAlertSourceReadOnly];
                        [self restoreDropView];
                      });
                      return;
                  }
              }
          }

          if ([[source sourceType] isEqualToString:NBCSourceTypeNBI] && target) {
              [self setTargetNBI:target];
              [self setNbiSelectedSource:[source sourceMenuName]];
              [self updatePopUpButtonSource];
          }

          [self updateSource:source creationTool:currentCreationTool nbiType:currentNbiType];

          if ([currentCreationTool isEqualToString:self->_creationTool]) {
              if ([currentNbiType length] == 0 || ([currentNbiType length] != 0 && [currentNbiType isEqualToString:self->_nbiType])) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateSourceInfo:source];
                  });
              }
          }

          if (![[source sourceType] isEqualToString:NBCSourceTypeNBI]) {
              self->_sourceDictSources[self->_currentSelectedSource] = source;
              [source detachBaseSystem];
              [source unmountRecoveryHD];
          }
      } else {
          if (![[source sourceType] isEqualToString:NBCSourceTypeNBI]) {
              [source detachAll];
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            [self restoreDropView];
            [NBCAlerts showAlertUnrecognizedSourceForCreationTool:currentCreationTool errorMessage:[error localizedDescription]];
          });
      }
    });
} // verifySourceAtURL

- (void)selectSource:(NBCSource *)source creationTool:(NSString *)creationTool {

    DDLogDebug(@"[DEBUG] Selecting menu item for source...");

    NSString *sourceMenuName = [source sourceMenuName] ?: @"";
    DDLogDebug(@"[DEBUG] Source menu item name: %@", sourceMenuName);

    if ([sourceMenuName length] != 0) {
        if ([[_popUpButtonSource itemTitles] containsObject:sourceMenuName]) {
            [self updateSourceSelection:sourceMenuName creationTool:creationTool];
        } else {
            DDLogError(@"[ERROR] Source menu name doesn't exist in pop up button!");
            [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
            [[[_popUpButtonSource menu] itemWithTitle:NBCMenuItemNoSelection] setState:NSMixedState];
        }
    } else {
        DDLogError(@"[ERROR] Source menu item name was empty!");
        [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
        [[[_popUpButtonSource menu] itemWithTitle:NBCMenuItemNoSelection] setState:NSMixedState];
    }
} // selectSource

- (void)updateSourceSelection:(NSString *)selection creationTool:(NSString *)creationTool {

    if ([selection length] == 0) {
        DDLogError(@"[ERROR] Source menu item name was empty!");
        return;
    }

    if ([creationTool length] != 0) {
        DDLogDebug(@"[DEBUG] Selecting source: %@", selection);
        [self setCurrentSelectedSource:selection];

        if ([selection isEqualToString:_nbiSelectedSource]) {
            [self setNbiSelectedSource:selection];
        } else if ([creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self setNbiCreatorSelectedSource:selection];
        } else if ([creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            if ([_nbiType isEqualToString:@"Package Only"]) {
                [self setSystemImageUtilityPackageOnlySelectedSource:selection];
            } else {
                [self setSystemImageUtilitySelectedSource:selection];
            }
        } else if ([creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {
            [self setDeployStudioAssistantSelectedSource:selection];
        } else {
            DDLogError(@"[ERROR] Unknown creation tool: %@", creationTool);
            return;
        }
        [_popUpButtonSource selectItemWithTitle:selection];
    } else {
        DDLogError(@"[ERROR] Creation tool was empty!");
        return;
    }
} // updateSourceSelection

- (void)updateSource:(NBCSource *)source creationTool:(NSString *)creationTool nbiType:(NSString *)nbiType {

    DDLogDebug(@"[DEBUG] Updating selected source for creation tool: %@", creationTool);

    if ([creationTool length] != 0) {
        [self setCurrentSource:source];

        if ([_nbiSelectedSource length] != 0) {
            [self setSourceNBI:source];
        } else if ([creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self setSourceNBICreator:source];
        } else if ([creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            if ([nbiType isEqualToString:@"Package Only"]) {
                [self setSourceSystemImageUtilityPackageOnly:source];
            } else {
                [self setSourceSystemImageUtility:source];
            }
        } else if ([creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {
            [self setSourceDeployStudioAssistant:source];
        } else {
            DDLogError(@"[ERROR] Unknown creation tool: %@", creationTool);
            return;
        }
    } else {
        DDLogError(@"[ERROR] Creation tool was empty!");
        return;
    }

    [self selectSource:source creationTool:creationTool];
} // updateSource

- (void)removeSource {
    [self setCurrentSource:nil];
    [self setTargetNBI:nil];

    if ([_creationTool length] != 0) {
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self setSourceNBICreator:nil];
        } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            if ([_nbiType isEqualToString:@"Package Only"]) {
                [self setSourceSystemImageUtilityPackageOnly:nil];
            } else {
                [self setSourceSystemImageUtility:nil];
            }
        } else if ([_creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {
            [self setSourceDeployStudioAssistant:nil];
        }
    } else {
        DDLogError(@"[ERROR] Creation tool was empty!");
    }
} // removeSource

+ (NSArray *)sourceTypesForCreationTool:(NSString *)creationTool allowNBISource:(BOOL)allowNBISource {
    NSMutableArray *sourceTypes = [[NSMutableArray alloc] init];
    if ([creationTool isEqualToString:NBCMenuItemNBICreator]) {
        [sourceTypes addObjectsFromArray:@[ NBCSourceTypeInstaller ]];
    } else if ([creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {
        [sourceTypes addObjectsFromArray:@[ NBCSourceTypeSystem ]];
    } else if ([creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
        [sourceTypes addObjectsFromArray:@[ NBCSourceTypeInstaller ]];
    } else {
        DDLogError(@"[ERROR] Unknown creation tool: %@", creationTool);
        [sourceTypes addObjectsFromArray:@[]];
    }

    if (allowNBISource) {
        [sourceTypes addObject:NBCSourceTypeNBI];
    }

    return [sourceTypes copy];
} // sourceTypesForCreationTool

+ (NSArray *)sourceTypesForNbiType:(NSString *)nbiType {
    if ([nbiType isEqualToString:@"NetInstall"]) {
        return @[ NBCSourceTypeInstaller ];
    } else if ([nbiType isEqualToString:@"Package Only"]) {
        return @[ NBCSourceTypeSystem ];
    } else {
        DDLogError(@"[ERROR] Unknown nbi type: %@", nbiType);
        return @[];
    }
} // sourceTypesForNbiType

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Dragging Destination Classes
#pragma mark -
#pragma mark NBCDropView
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDropView

- (id)initWithDelegate:(id<NBCSourceDropDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
        if ([_delegate settingsViewController]) {
            [[_delegate settingsViewController] addObserver:self forKeyPath:@"nbiCreationTool" options:NSKeyValueObservingOptionNew context:nil];
            if ([_delegate respondsToSelector:NSSelectorFromString(@"nbiType")]) {
                [_delegate addObserver:self forKeyPath:@"nbiType" options:NSKeyValueObservingOptionNew context:nil];
            }
        }
    }
    return self;
} // initWithDelegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    if ([keyPath isEqualToString:@"nbiCreationTool"]) {
        NSString *creationTool = change[@"new"];
        if (![creationTool isKindOfClass:[NSNull class]]) {
            [self setSourceTypes:[NBCSourceDropViewController sourceTypesForCreationTool:creationTool allowNBISource:_allowNBISource] ?: @[]];
        }
    } else if ([keyPath isEqualToString:@"nbiType"]) {
        NSString *nbiType = change[@"new"];
        if (![nbiType isKindOfClass:[NSNull class]]) {
            [self setSourceTypes:[NBCSourceDropViewController sourceTypesForNbiType:nbiType] ?: @[]];
        }
    }
} // observeValueForKeyPath

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ([draggedFileURL checkResourceIsReachableAndReturnError:nil]) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationNone;
    }
} // draggingEntered

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ([draggedFileURL checkResourceIsReachableAndReturnError:nil]) {
        DDLogInfo(@"Dropped source path: %@", [draggedFileURL path]);

        if (_delegate && [_delegate respondsToSelector:@selector(verifySourceAtURL:)]) {
            [_delegate verifySourceAtURL:draggedFileURL];
        }
        return YES;
    } else {
        return NO;
    }
} // performDragOperation

- (NSURL *)getDraggedSourceURLFromPasteboard:(NSPasteboard *)pboard {
    if ([[pboard types] containsObject:NSFilenamesPboardType]) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

        // ------------------------------------------------------
        //  Verify only one item is dropped
        // ------------------------------------------------------
        if ([files count] != 1) {
            return nil;
        } else {
            NSURL *draggedFileURL = [NSURL fileURLWithPath:[files firstObject]];
            // DDLogDebug(@"[DEBUG] Dragged item path: %@", [draggedFileURL path]);

            NSString *draggedFileExtension = [draggedFileURL pathExtension];
            // DDLogDebug(@"[DEBUG] Dragged item extension: %@", draggedFileExtension);

            if ([draggedFileExtension isEqualToString:@"dmg"] && ([_sourceTypes containsObject:NBCSourceTypeInstaller] || [_sourceTypes containsObject:NBCSourceTypeSystem])) {
                return draggedFileURL;
            } else if ([draggedFileExtension isEqualToString:@"app"] && ([_sourceTypes containsObject:NBCSourceTypeInstaller])) {
                if ([[draggedFileURL URLByAppendingPathComponent:@"Contents/SharedSupport/InstallESD.dmg"] checkResourceIsReachableAndReturnError:nil]) {
                    return draggedFileURL;
                }
            } else if ([draggedFileExtension isEqualToString:@"nbi"] && ([_sourceTypes containsObject:NBCSourceTypeNBI])) {
                NSURL *nbImageInfoURL = [draggedFileURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
                if ([nbImageInfoURL checkResourceIsReachableAndReturnError:nil]) {
                    NSDictionary *nbImageInfo = [NSDictionary dictionaryWithContentsOfURL:nbImageInfoURL];
                    NSURL *nbiRootPathURL = [draggedFileURL URLByAppendingPathComponent:nbImageInfo[@"RootPath"] ?: @""];
                    if ([nbiRootPathURL checkResourceIsReachableAndReturnError:nil]) {
                        return draggedFileURL;
                    }
                }
            }
            return nil;
        }
    }
    return nil;
} // getDraggedSourceURLFromPasteboard

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCDropViewBox
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDropViewBox

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
} // initWithCoder

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSDragOperation result = NSDragOperationNone;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate draggingEntered:sender];
    }
    return (result);
} // draggingEntered

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        [_delegate draggingExited:sender];
    }
} // draggingExited

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    BOOL result = NO;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate prepareForDragOperation:sender];
    }
    return (result);
} // prepareForDragOperation

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    BOOL result = NO;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate performDragOperation:sender];
    }
    return (result);
} // performDragOperation

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCDropViewImageView
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDropViewImageView

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
} // initWithCoder

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    NSDragOperation result = NSDragOperationNone;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate draggingEntered:sender];
    }
    return (result);
} // draggingEntered

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        [_delegate draggingExited:sender];
    }
} // draggingExited

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    BOOL result = NO;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate prepareForDragOperation:sender];
    }
    return (result);
} // prepareForDragOperation

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    BOOL result = NO;
    if (_delegate && [_delegate respondsToSelector:_cmd]) {
        result = [_delegate performDragOperation:sender];
    }
    return (result);
} // performDragOperation

@end
