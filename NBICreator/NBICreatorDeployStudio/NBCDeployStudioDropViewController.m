//
//  NBCDSDropViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-22.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioDropViewController.h"
#import "NBCConstants.h"

#import "NBCAlerts.h"
#import "NBCDiskArbitrator.h"
#import "NBCController.h"
#import "NBCSourceController.h"
#import "NBCDiskImageController.h"
#import "NBCLogging.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

@interface NBCDeployStudioDropViewController ()

@property NSString *selectedSource;

@end

@implementation NBCDeployStudioDropViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCDeployStudioDropViewController" bundle:nil];
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
    [nc addObserver:self selector:@selector(verifyDroppedSource:) name:NBCNotificationDeployStudioVerifyDroppedSource object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidAppearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidDisappearNotification object:nil];
    [nc addObserver:self selector:@selector(updateSourceList:) name:DADiskDidChangeNotification object:nil];
    
    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    _sourceDictLinks = [[NSMutableDictionary alloc] init];
    _sourceDictSources = [[NSMutableDictionary alloc] init];
    
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
    
} // viewDidLoad

- (void)showSourceInFinder {
    
    if ( _source ) {
        NSURL *sourceURL;
        
        id source = _sourceDictLinks[_selectedSource];
        if ( [source isKindOfClass:[NSURL class]] ) {
            sourceURL = source;
        } else if ( [source isKindOfClass:[NBCDisk class]] ) {
            sourceURL = [source volumeURL];
        }
        
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

- (void)updateSourceList:(NSNotification *)notification {
    #pragma unused(notification)
    
    [self updatePopUpButtonSource];
    
} // updateSourceList

- (void)verifyDroppedSource:(NSNotification *)notification {
    
    NSURL *sourceURL = [notification userInfo][NBCNotificationVerifyDroppedSourceUserInfoSourceURL];
    [self verifyDiskImage:sourceURL];
    
} // verifyDroppedSource

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Content Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSourceInfo:(NBCSource *)source {
    
    NBCDisk *sourceSystemDisk = [source systemDisk];
    NSString *sourceType = [source sourceType];
    NSString *systemOSVersion = [source systemOSVersion];
    NSString *systemOSBuild = [source systemOSBuild];
    NSString *baseSystemOSVersion = [source baseSystemOSVersion];
    NSString *baseSystemOSBuild = [source baseSystemOSBuild];
    
    // -----------------------------------------------------------------
    //  If source os/build and baseSystem os/build mismatch, show error
    // -----------------------------------------------------------------
    if ( ! [systemOSVersion hasPrefix:@"10.6"] && ( ! [systemOSVersion isEqualToString:baseSystemOSVersion] || ! [systemOSBuild isEqualToString:baseSystemOSBuild] ) ) {
        [self updateRecoveryMismatchInfo:source];
        [self showRecoveryVersionMismatch];
        return;
    } else {
        
        // ------------------------------------------------------
        //  Set Source Title to system version string
        // ------------------------------------------------------
        NSString *systemVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", systemOSVersion, systemOSBuild];
        [_textFieldSourceTitle setStringValue:systemVersionString];
        
        // ------------------------------------------------------
        //  Set Source Field 1 and 2 depending on source type
        // ------------------------------------------------------
        if ( [sourceType isEqualToString:@"SystemDiskImage"] ) {
            [_textFieldSourceField1Label setStringValue:@"Source:"];
            [_textFieldSourceField1 setStringValue:@"Disk Image"];
            
            [_textFieldSourceField2Label setStringValue:@"Image Name:"];
            [_textFieldSourceField2 setStringValue:[[[source systemDiskImageURL] path] lastPathComponent]];
            
            NSImage *diskImageImage = [[NSImage alloc] initWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"IconDMG" withExtension:@"icns"]];
            [_imageViewSourceMini setImage:diskImageImage];
        } else {
            [_textFieldSourceField1Label setStringValue:@"Source:"];
            NSString *volumeTypeString;
            if ( [sourceSystemDisk isInternal] ) {
                volumeTypeString = @"Internal Disk";
            } else {
                volumeTypeString = @"External Disk";
            }
            [_textFieldSourceField1 setStringValue:volumeTypeString];
            
            NSImage *diskImage = [sourceSystemDisk icon];
            [_imageViewSourceMini setImage:diskImage];
            
            [_textFieldSourceField2Label setStringValue:@"Mount Point:"];
            [_textFieldSourceField2 setStringValue:[[source systemVolumeURL] path]];
        }
        
        NSImage *productImage = [source productImageForOSVersion:systemOSVersion];
        if ( productImage ) {
            [_imageViewSource setImage:productImage];
        }
        
        // ---------------------------------------------------------
        //  Post notification to update source
        // ---------------------------------------------------------
        NSDictionary *userInfo = @{ NBCNotificationUpdateSourceUserInfoSource : source };
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationDeployStudioUpdateSource object:self userInfo:userInfo];
        
        // ---------------------------------------------------------
        //  Show source info in UI
        // ---------------------------------------------------------
        [self showSource];
    }
} // updateSourceInfo

- (void)updateRecoveryMismatchInfo:(NBCSource *)source {
    
    NSString *systemOSVersion = [source systemOSVersion];
    NSString *systemOSBuild = [source systemOSBuild];
    NSString *baseSystemOSVersion = [source baseSystemOSVersion];
    NSString *baseSystemOSBuild = [source baseSystemOSBuild];
    NSString *systemVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", systemOSVersion, systemOSBuild];
    NSString *recoveryVersionString = [NSString stringWithFormat:@"Mac OS X %@ (%@)", baseSystemOSVersion, baseSystemOSBuild];
    NSString *sourceType = [source sourceType];
    NBCDisk *sourceSystemDisk = [source systemDisk];
    
    if ( [sourceType isEqualToString:@"SystemDiskImage"] ) {
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
    
    if ( ! [systemOSVersion isEqualToString:baseSystemOSVersion] ) {
        [_textFieldSourceTitle setStringValue:@"Recovery Version Mismatch!"];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:recoveryVersionString];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, string.length)];
        //[string applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[string length])];
        int max = (int)[recoveryVersionString length];
        int len = (max - 9);
        [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(9,(NSUInteger)len)];
        [_textFieldSourceField2 setAttributedStringValue:string];
    } else if ( ! [systemOSBuild isEqualToString:baseSystemOSBuild] ) {
        [_textFieldSourceTitle setStringValue:@"Recovery Version Mismatch!"];
        NSMutableAttributedString *recoveryVersionStringAttributed = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Mac OS X %@ (", baseSystemOSVersion]];
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:baseSystemOSBuild];
        [string addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12] range:NSMakeRange(0, string.length)];
        //[string applyFontTraits:NSBoldFontMask range:NSMakeRange(0,[string length])];
        int max = (int)[string length];
        [string addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)max)];
        [recoveryVersionStringAttributed appendAttributedString:string];
        [recoveryVersionStringAttributed appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@")"]];
        [_textFieldSourceField2 setAttributedStringValue:recoveryVersionStringAttributed];
    } else {
        [_textFieldSourceField2 setStringValue:recoveryVersionString];
    }
    
    NSImage *productImage = [source productImageForOSVersion:systemOSVersion];
    if ( productImage ) {
        [_imageViewSource setImage:productImage];
    }
} // updateRecoveryMismatchInfo

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
    [_textFieldChooseSource setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDropOSXImageHere setHidden:YES];
    [_verticalLine setHidden:YES];
    
    // ------------------------------------------------------
    //  Start and Show Progress
    // ------------------------------------------------------
    [_progressIndicatorStatus startAnimation:self];
    [_progressIndicatorStatus setHidden:NO];
    [_textFieldStatus setHidden:NO];
} // showProgress

- (void)showSource {
    
    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:18.0];
    
    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageViewDropImage setHidden:YES];
    [_textFieldChooseSource setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDropOSXImageHere setHidden:YES];
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

- (void)showRecoveryVersionMismatch {
    
    // ------------------------------------------------------
    //  Resize Source PopUpButton
    // ------------------------------------------------------
    [_constraintPopUpButtonSourceWidth setConstant:18.0];
    
    // ------------------------------------------------------
    //  Hide Default Layout
    // ------------------------------------------------------
    [_imageViewDropImage setHidden:YES];
    [_textFieldChooseSource setHidden:YES];
    [_textFieldOr setHidden:YES];
    [_textFieldDropOSXImageHere setHidden:YES];
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
    [_textFieldChooseSource setHidden:NO];
    [_textFieldOr setHidden:NO];
    [_textFieldDropOSXImageHere setHidden:NO];
    [_verticalLine setHidden:NO];
    
    [_popUpButtonSource selectItemWithTitle:NBCMenuItemNoSelection];
    
    // ------------------------------------------------------
    //  Post notification that source was removed
    // ------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationDeployStudioRemovedSource object:self userInfo:nil];
    
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
    NBCDisk *selectedDisk = _sourceDictLinks[_selectedSource];
    NBCSource *selectedSource = _sourceDictSources[_selectedSource];
    if ( selectedSource != nil ) {
        [self setSource:selectedSource];
        
        NSDictionary *userInfo = @{ NBCNotificationUpdateSourceUserInfoSource : selectedSource };
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationDeployStudioUpdateSource object:self userInfo:userInfo];
        
        [self updateSourceInfo:_source];
    } else {
        [self verifyPopUpButtonSelection:selectedDisk];
    }
} // popUpButtonSource

- (void)updatePopUpButtonSource {
    
    [_popUpButtonSource removeAllItems];
    [_popUpButtonSource addItemWithTitle:NBCMenuItemNoSelection];
    
    // --------------------------------------------------------------
    //  Add all mounted OS X disks to source popUpButton
    // --------------------------------------------------------------
    NSSet *currentDisks = [[[NBCDiskArbitrator sharedArbitrator] disks] copy];
    for ( NBCDisk *disk in currentDisks ) {
        NSString *volumeName = [disk volumeName];
        if (
            ! [volumeName isEqualToString:@"Recovery HD"] &&
            ! [volumeName isEqualToString:@"OS X Base System"] &&
            ! [volumeName isEqualToString:@"Mac OS X Install ESD"] &&
            ! [volumeName isEqualToString:@"DeployStudioRuntime"]
            ) {
            NSURL *volumeURL = [disk volumeURL];
            NSURL *systemVersionPlist = [volumeURL URLByAppendingPathComponent:@"/System/Library/CoreServices/SystemVersion.plist"];
            if ( [systemVersionPlist checkResourceIsReachableAndReturnError:nil] ) {
                NSDictionary *systemVersionDict = [[NSDictionary alloc] initWithContentsOfURL:systemVersionPlist];
                if ( systemVersionDict ) {
                    if ( [[volumeURL path] isEqualToString:@"/"] ) {
                        volumeName = @"Booted System";
                    }
                    
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

- (void)selecteSourceInPupUpButton:(NBCSource *)source {
    
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
            break;
        }
    }
} // addSourceToPopUpButton

- (void)verifyPopUpButtonSelection:(NBCDisk *)disk {
    
    NSURL *diskVolumeURL = [disk volumeURL];
    NSString *deviceModel = [disk deviceModel];
    if ([deviceModel isEqualToString:NBCDiskDeviceModelDiskImage]) {
        NSURL *diskImageURL = [NBCDiskImageController getDiskImageURLFromMountURL:diskVolumeURL];
        [self verifyDiskImage:diskImageURL];
    } else {
        if ( [disk isMounted] ) {
            [self verifyDisk:disk];
        } else {
            [disk mount];
            if ( [disk isMounted] ) {
                [self verifyDisk:disk];
            } else {
                DDLogError(@"Could not mount disk named: %@", [disk volumeName]);
            }
        }
    }
} // verifyPopUpButtonSelection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Disk
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)verifyDisk:(NBCDisk *)systemDisk {
    
    // ------------------------------------------------------
    //  Disable build button while checking new source
    // ------------------------------------------------------
    NSDictionary * userInfo = @{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @NO };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:userInfo];
    
    // ------------------------------------------------------
    //  Update UI to show working progress
    // ------------------------------------------------------
    [_textFieldStatus setStringValue:@"Checking System Version..."];
    [self showProgress];
    
    NBCSource *newSource = [[NBCSource alloc] init];
    NBCSourceController *sourceController = [[NBCSourceController alloc] init];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        BOOL verified = YES;
        NSError *error;
        NSString *errorMessage;
        
        // ------------------------------------------------------
        //  Verify the source is a valid OS X System
        // ------------------------------------------------------
        if ( systemDisk != nil ) {
            verified = [sourceController verifySystemFromDisk:systemDisk source:newSource error:&error];
            NSString *osVersion = [newSource systemOSVersion];
            if ( verified && ! [osVersion hasPrefix:@"10.6"] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldStatus setStringValue:@"Checking Recovery Version..."];
                });
                
                verified = [sourceController verifyRecoveryPartitionFromSystemDisk:systemDisk source:newSource error:&error];
                if ( verified ) {
                    verified = [sourceController verifyBaseSystemFromSource:newSource error:&error];
                    if ( ! verified ) {
                        errorMessage = @"Could not verify BaseSystem!";
                        DDLogError(@"Could not verify BaseSystem!");
                        DDLogError(@"Error: %@", error);
                    }
                } else {
                    errorMessage = @"Could not verify Recovery Partition!";
                    DDLogError(@"Could not verify Recovery Partition!");
                    DDLogError(@"Error: %@", error);
                }
            } else if ( ! verified ) {
                errorMessage = @"Could not verify System Partition!";
                DDLogError(@"Could not verify System Partition!");
                DDLogError(@"Error: %@", error);
            }
            
            if ( verified ) {
                [newSource setSourceType:NBCSourceTypeSystemDisk];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateSourceInfo:newSource];
                    [self selecteSourceInPupUpButton:newSource];
                    [self setSource:newSource];
                    [newSource detachBaseSystem];
                    [newSource unmountRecoveryHD];
                });
            } else {
                [newSource detachAll];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self restoreDropView];
                    [NBCAlerts showAlertUnrecognizedSourceForWorkflow:kWorkflowTypeDeployStudio errorMessage:errorMessage];
                });
            }
        }
    });
} // verifyDisk

- (void)verifyDiskImage:(NSURL *)diskImageURL {
    
    // ------------------------------------------------------
    //  Disable build button while checking new source
    // ------------------------------------------------------
    NSDictionary * userInfo = @{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @NO };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:userInfo];
    
    // ------------------------------------------------------
    //  Update UI to show working progress
    // ------------------------------------------------------
    [_textFieldStatus setStringValue:@"Checking System Version..."];
    [self showProgress];
    
    NBCSource *newSource = [[NBCSource alloc] init];
    NBCSourceController *sourceController = [[NBCSourceController alloc] init];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        BOOL verified = NO;
        NSError *error;
        NSString *errorMessage;
        
        // ------------------------------------------------------
        //  Verify the source is a valid OS X System Disk Image
        // ------------------------------------------------------
        if ( [diskImageURL checkResourceIsReachableAndReturnError:&error] ) {
            verified = [sourceController verifySystemFromDiskImageURL:diskImageURL source:newSource error:&error];
            NSString *osVersion = [newSource systemOSVersion];
            if ( verified && ! [osVersion hasPrefix:@"10.6"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldStatus setStringValue:@"Checking Recovery Version..."];
                });
                verified = [sourceController verifyRecoveryPartitionFromSystemDiskImageURL:diskImageURL source:newSource error:&error];
                if ( verified ) {
                    verified = [sourceController verifyBaseSystemFromSource:newSource error:&error];
                    if ( ! verified ) {
                        errorMessage = @"BaseSystem Verify Failed!";
                        NSLog(@"BaseSystem Verify Failed!");
                        NSLog(@"BaseSystem Error: %@", error);
                    }
                } else {
                    errorMessage = @"RecoveryPartition Verify Failed!";
                    NSLog(@"RecoveryPartition Verify Failed!");
                    NSLog(@"RecoveryPartition Error: %@", error);
                }
            } else if ( ! verified ) {
                errorMessage = @"System Disk Image Verify Failed!";
                NSLog(@"System Disk Image Verify Failed!");
                NSLog(@"System Error: %@", error);
            }
        } else {
            errorMessage = @"System Disk Image Not Found!";
            NSLog(@"System Disk Image Not Found!");
            NSLog(@"System Error: %@", error);
        }
        
        if ( verified ) {
            [newSource setSourceType:NBCSourceTypeSystemDiskImage];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateSourceInfo:newSource];
                [self selecteSourceInPupUpButton:newSource];
                [self setSource:newSource];
                [newSource detachBaseSystem];
                [newSource unmountRecoveryHD];
            });
        } else {
            [newSource detachAll];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self restoreDropView];
                [NBCAlerts showAlertUnrecognizedSourceForWorkflow:kWorkflowTypeDeployStudio errorMessage:errorMessage];
            });
        }
    });
} // verifyDiskImage

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Dragging Destination Classes
#pragma mark -
#pragma mark NBCDeployStudioDropView
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDeployStudioDropView

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
        [nc postNotificationName:NBCNotificationDeployStudioVerifyDroppedSource object:self userInfo:userInfo];
        
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
            //  Only accept a URL if it's a .dmg
            // ---------------------------------------------------------------------------------
            NSURL *draggedFileURL = [NSURL fileURLWithPath:[files firstObject]];
            if ( [[draggedFileURL pathExtension] isEqualToString:@"dmg"] ) {
                return draggedFileURL;
            }
            return nil;
        }
    }
    return nil;
}

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCDeployStudioDropViewBox
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDeployStudioDropViewBox

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
    NSDragOperation result = NSDragOperationNone;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate draggingEntered:sender];
    }
    
    return (result);
}   // draggingEntered

- (void)draggingExited:(id <NSDraggingInfo> )sender {
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [delegate draggingExited:sender];
    }
}   // draggingExited

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate prepareForDragOperation:sender];
    }
    
    return (result);
}   // prepareForDragOperation

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate performDragOperation:sender];
    }
    
    return (result);
}   // performDragOperation

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark NBCDeployStudioDropViewImageView
////////////////////////////////////////////////////////////////////////////////

@implementation NBCDeployStudioDropViewImageView

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:@[ NSURLPboardType ]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo> )sender {
    NSDragOperation result = NSDragOperationNone;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate draggingEntered:sender];
    }
    
    return (result);
}   // draggingEntered

- (void)draggingExited:(id <NSDraggingInfo> )sender {
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        [delegate draggingExited:sender];
    }
}   // draggingExited

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate prepareForDragOperation:sender];
    }
    
    return (result);
}   // prepareForDragOperation

- (BOOL)performDragOperation:(id <NSDraggingInfo> )sender {
    BOOL result = NO;
    NBCDeployStudioDropView *dropView = [[NBCDeployStudioDropView alloc] init];
    id delegate = dropView;
    delegate = delegate ?: self.window.delegate;
    if (delegate && [delegate respondsToSelector:_cmd]) {
        result = [delegate performDragOperation:sender];
    }
    
    return (result);
}   // performDragOperation

@end
