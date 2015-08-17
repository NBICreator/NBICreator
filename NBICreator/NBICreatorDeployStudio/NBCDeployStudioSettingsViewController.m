//
//  NBCDSViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-19.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDeployStudioSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"

#import "NBCWorkflowItem.h"
#import "NBCSettingsController.h"

#import "NBCDeployStudioWorkflowNBI.h"
#import "NBCDeployStudioWorkflowResources.h"
#import "NBCDeployStudioWorkflowModifyNBI.h"

#import "Reachability.h"
#import "NBCWorkflowResourcesController.h"

#include <ifaddrs.h>
#include <arpa/inet.h>
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@interface NBCDeployStudioSettingsViewController () {
    Reachability *_internetReachableFoo;
}
@end

@implementation NBCDeployStudioSettingsViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCDeployStudioSettingsViewController" bundle:nil];
    if (self != nil) {
        _templates = [[NBCTemplatesController alloc] initWithSettingsViewController:self templateType:NBCSettingsTypeDeployStudio delegate:self];
    }
    return self;
} // init

- (void)viewDidLoad {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [super viewDidLoad];
    
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateSource:) name:NBCNotificationDeployStudioUpdateSource object:nil];
    [nc addObserver:self selector:@selector(removedSource:) name:NBCNotificationDeployStudioRemovedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIIcon:) name:NBCNotificationDeployStudioUpdateNBIIcon object:nil];
    [nc addObserver:self selector:@selector(updateNBIBackground:) name:NBCNotificationDeployStudioUpdateNBIBackground object:nil];
    [nc addObserver:self selector:@selector(addBonjourService:) name:NBCNotificationDeployStudioAddBonjourService object:nil];
    [nc addObserver:self selector:@selector(removeBonjourService:) name:NBCNotificationDeployStudioRemoveBonjourService object:nil];
    
    // --------------------------------------------------------------
    //  Add KVO Observers
    // --------------------------------------------------------------
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud addObserver:self forKeyPath:NBCUserDefaultsIndexCounter options:NSKeyValueObservingOptionNew context:nil];
    
    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error]; // Unused error
    if ( userApplicationSupport ) {
        _templatesFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesDeployStudio isDirectory:YES];
    } else {
        NSLog(@"Could not get Application Support folder for current User");
        NSLog(@"Error: %@", error);
    }
    _dsSource = [[NBCDeployStudioSource alloc] init];
    _templatesDict = [[NSMutableDictionary alloc] init];
    _discoveredServers = [[NSMutableArray alloc] init];
    _bonjourBrowser = [[NBCBonjourBrowser alloc] init];
    [self setShowRuntimePassword:NO];
    [self setShowARDPassword:NO];
    [self setUseCustomServers:NO];
    
    // --------------------------------------------------------------
    //  Setup ComboBox to use self as DataSource
    // --------------------------------------------------------------
    [_comboBoxServerURL1 setUsesDataSource:YES];
    [_comboBoxServerURL1 setDataSource:self];
    
    [_comboBoxServerURL2 setUsesDataSource:YES];
    [_comboBoxServerURL2 setDataSource:self];
    
    [self testInternetConnection];
    
    // --------------------------------------------------------------
    //  Load saved templates and create the template menu
    // --------------------------------------------------------------
    [_templates updateTemplateListForPopUpButton:_popUpButtonTemplates title:nil];
    
    // --------------------------------------------------------------
    //  Update default Deploy Studio Version in UI.
    // --------------------------------------------------------------
    [self updateDeployStudioVersion];
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI Icon image view to allow to restore original icon.
    // -------------------------------------------------------------------------------
    NSMenu *menuIcon = [[NSMenu alloc] init];
    NSMenuItem *restoreViewIcon = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalIcon action:@selector(restoreNBIIcon:) keyEquivalent:@""];
    [menuIcon addItem:restoreViewIcon];
    [_imageViewIcon setMenu:menuIcon];
    
    // ------------------------------------------------------------------------------------------
    //  Add contextual menu to NBI background image view to allow to restore original background.
    // ------------------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *restoreViewBackground = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalBackground action:@selector(restoreNBIBackground:) keyEquivalent:@""];
    [menu addItem:restoreViewBackground];
    [_imageViewBackgroundImage setMenu:menu];
    
    // --------------------------------------------------
    //  Set correct background as no source is selected
    // --------------------------------------------------
    [self restoreNBIBackground:nil];
    
    // ----------------------------------------------------
    //  Verify build button so It's not enabled by mistake
    // ----------------------------------------------------
    [self verifyBuildButton];
    
} // viewDidLoad

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Reachability
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)testInternetConnection {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    _internetReachableFoo = [Reachability reachabilityWithHostname:@"www.deploystudio.com"];
    __unsafe_unretained typeof(self) weakSelf = self;
    
    // Internet is reachable
    _internetReachableFoo.reachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf getDeployStudioVersions];
        });
    };
    
    // Internet is not reachable
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf cachedDeployStudioVersionLocal];
        });
    };
    
    [_internetReachableFoo startNotifier];
} // testInternetConnection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalIcon] ) {
        // -------------------------------------------------------------
        //  No need to restore original icon if it's already being used
        // -------------------------------------------------------------
        if ( [_nbiIconPath isEqualToString:NBCFilePathNBIIconDeployStudio] ) {
            retval = NO;
        }
        return retval;
    } else if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalBackground] ) {
        // -------------------------------------------------------------------
        //  No need to restore original background if it's already being used
        // -------------------------------------------------------------------
        if (
            [_imageBackgroundURL isEqualToString:NBCDeployStudioBackgroundImageDefaultPath] ||
            [_imageBackgroundURL isEqualToString:NBCDeployStudioBackgroundDefaultPath] ||
            ! [_dsSource isInstalled]
            ) {
            retval = NO;
        }
        return retval;
    }
    
    return YES;
} // validateMenuItem

- (void)dealloc {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_comboBoxServerURL1 setDataSource:nil];
    [_comboBoxServerURL2 setDataSource:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods TextField
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)controlTextDidChange:(NSNotification *)sender {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // --------------------------------------------------------------------
    //  Expand variables for the NBI preview text fields
    // --------------------------------------------------------------------
    if ( [sender object] == _textFieldNBIName ) {
        if ( [_nbiName length] == 0 ) {
            [_textFieldNBINamePreview setStringValue:@""];
        } else {
            NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_dsSource];
            [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
        }
    } else if ( [sender object] == _textFieldIndex ) {
        if ( [_nbiIndex length] == 0 ) {
            [_textFieldIndexPreview setStringValue:@""];
        } else {
            NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_dsSource];
            [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
        }
    } else if ( [sender object] == _textFieldNBIDescription ) {
        if ( [_nbiDescription length] == 0 ) {
            [_textFieldNBIDescriptionPreview setStringValue:@""];
        } else {
            NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_dsSource];
            [_textFieldNBIDescriptionPreview setStringValue:nbiDescription];
        }
    }
    
    // --------------------------------------------------------------------
    //  Expand tilde for destination folder if tilde is used in settings
    // --------------------------------------------------------------------
    if ( [sender object] == _textFieldDestinationFolder ) {
        if ( [_destinationFolder length] == 0 ) {
            [self setDestinationFolder:@""];
        } else if ( [_destinationFolder hasPrefix:@"~"] ) {
            NSString *destinationFolder = [_destinationFolder stringByExpandingTildeInPath];
            [self setDestinationFolder:destinationFolder];
        }
    }
    
    // --------------------------------------------------------------------
    //  Continuously verify build button
    // --------------------------------------------------------------------
    [self verifyBuildButton];
    
} // controlTextDidChange

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagDeployStudio] ) {
        [_progressIndicatorDeployStudioDownloadProgress setIndeterminate:YES];
        [_progressIndicatorDeployStudioDownloadProgress stopAnimation:self];
        [[NSApp mainWindow] endSheet:_windowDeployStudioDownloadProgress];
        
        if ( url ) {
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ url ]];
        }
        [self setDeployStudioDownloader:nil];
    }
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagDeployStudio] ) {
        NSString *latestVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ( [latestVersion length] != 0 ) {
            [self setDeployStudioLatestVersion:latestVersion];
            [self updateCachedDeployStudioLatestVersion:latestVersion];
            NSString *currentVersion = [_dsSource deployStudioAdminVersion];
            if ( [currentVersion isEqualToString:latestVersion] ) {
                [self hideUpdateAvailable];
            } else {
                [self showUpdateAvailable:latestVersion];
            }
        }
    }
}

- (void)downloadCanceled:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagDeployStudio] ) {
        [_progressIndicatorDeployStudioDownloadProgress setIndeterminate:YES];
        [_progressIndicatorDeployStudioDownloadProgress stopAnimation:self];
        [[NSApp mainWindow] endSheet:_windowDeployStudioDownloadProgress];
        
        [self setDeployStudioDownloader:nil];
    }
}

- (void)updateProgressBytesRecieved:(float)bytesRecieved expectedLength:(long long)expectedLength downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagDeployStudio] ) {
        if ( _windowDeployStudioDownloadProgress ) {
            NSString *downloaded = [NSByteCountFormatter stringFromByteCount:(long long)bytesRecieved countStyle:NSByteCountFormatterCountStyleDecimal];
            NSString *downloadMax = [NSByteCountFormatter stringFromByteCount:expectedLength countStyle:NSByteCountFormatterCountStyleDecimal];
            
            float percentComplete = (bytesRecieved/(float)expectedLength)*(float)100.0;
            [_progressIndicatorDeployStudioDownloadProgress setDoubleValue:percentComplete];
            [_textFieldDeployStudioDownloadProgress setStringValue:[NSString stringWithFormat:@"%@/%@", downloaded, downloadMax]];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloaderDeployStudio
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)dsReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagDeployStudio] ) {
        [self setDeployStudioVersions:versionsArray];
        [self setDeployStudioVersionsDownloadLinks:downloadDict];
        [self getDeployStudioVersionLatest];
        [self updatePopUpButtonDeployStudioVersion];
    }
} // dsReleaseVersionsArray:downloadDict:downloadInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsWarning] ) {
        if ( returnCode == NSAlertSecondButtonReturn ) { // Continue
            NBCWorkflowItem *workflowItem = alertInfo[NBCAlertWorkflowItemKey];
            [self prepareWorkflowItem:workflowItem];
        }
    }
    
    alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsaved] ) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save
            [self saveUISettingsWithName:_selectedTemplate atUrl:_templatesDict[_selectedTemplate]];
            [self setSelectedTemplate:selectedTemplate];
            [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
            [self expandVariablesForCurrentSettings];
            return;
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Discard
            [self setSelectedTemplate:selectedTemplate];
            [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
            [self expandVariablesForCurrentSettings];
            return;
        } else {                                                // Cancel
            [_popUpButtonTemplates selectItemWithTitle:_selectedTemplate];
            return;
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods ComboBox
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
#pragma unused(aComboBox)
    return (NSInteger)[_discoveredServers count];
} // numberOfItemsInComboBox

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
#pragma unused(aComboBox)
    return _discoveredServers[(NSUInteger)index];
} // comboBox:objectValueForItemAtIndex

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods TabView
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
#pragma unused(tabView)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *tabViewTitle = [tabViewItem label];
    
    if ( [tabViewTitle isEqualToString:NBCDeployStudioTabTitleRuntime] ) {
        _isSearching = YES;
        [_discoveredServers removeAllObjects];
        [_bonjourBrowser startBonjourDiscovery];
    } else if ( _isSearching == YES ) {
        _isSearching = NO;
        [_bonjourBrowser stopBonjourDiscovery];
    }
} // tabView

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSource:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCSource *source = [notification userInfo][NBCNotificationUpdateSourceUserInfoSource];
    if ( source != nil ) {
        _source = source;
    }
    
    NSString *currentBackgroundImageURL = _imageBackgroundURL;
    NSURL *deployStudioBackgroundURL = [_dsSource deployStudioBackgroundURL];
    if ( [currentBackgroundImageURL isEqualToString:NBCDeployStudioBackgroundDefaultPath] ) {
        [self setImageBackground:@""];
        [self setImageBackground:[deployStudioBackgroundURL path]];
        [self setImageBackgroundURL:NBCDeployStudioBackgroundImageDefaultPath];
    }
    
    [self expandVariablesForCurrentSettings];
    [self verifyBuildButton];
} // updateSource

- (void)removedSource:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _source ) {
        _source = nil;
    }
    
    NSString *currentBackgroundImageURL = _imageBackgroundURL;
    NSURL *deployStudioBackgroundURL = [_dsSource deployStudioBackgroundURL];
    if ( [currentBackgroundImageURL isEqualToString:NBCDeployStudioBackgroundImageDefaultPath] ) {
        [self setImageBackground:@""];
        [self setImageBackground:[deployStudioBackgroundURL path]];
        [self setImageBackgroundURL:NBCDeployStudioBackgroundDefaultPath];
    }
    
    [self verifyBuildButton];
} // removedSource

- (void)updateNBIIcon:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *nbiIconURL = [notification userInfo][NBCNotificationUpdateNBIIconUserInfoIconURL];
    if ( nbiIconURL != nil ) {
        // To get the view to update I have to first set the nbiIcon property to @""
        // It only happens when it recieves a dropped image, not when setting in code.
        [self setNbiIcon:@""];
        [self setNbiIconPath:[nbiIconURL path]];
    }
} // updateNBIIcon

- (void)restoreNBIIcon:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setNbiIconPath:NBCFilePathNBIIconDeployStudio];
    [self expandVariablesForCurrentSettings];
} // restoreNBIIcon

- (void)updateNBIBackground:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *nbiBackgroundURL = [notification userInfo][NBCNotificationUpdateNBIBackgroundUserInfoIconURL];
    if ( nbiBackgroundURL != nil ) {
        // To get the view to update I have to first set the nbiIcon property to @""
        // It only happens when it recieves a dropped image, not when setting in code.
        [self setImageBackground:@""];
        [self setImageBackgroundURL:[nbiBackgroundURL path]];
    }
} // updateImageBackground

- (void)restoreNBIBackground:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _source == nil ) {
        //NSURL *deployStudioBackgroundURL = [_dsSource deployStudioBackgroundURL];
        [self setImageBackground:@""];
        [self setImageBackgroundURL:NBCDeployStudioBackgroundDefaultPath];
    } else {
        [self setImageBackground:@""];
        [self setImageBackgroundURL:NBCDeployStudioBackgroundImageDefaultPath];
    }
    
    [self expandVariablesForCurrentSettings];
} // restoreNBIBackground

- (void)addBonjourService:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSArray *serverURLs = [notification userInfo][@"serverURLs"];
    for ( NSString *url in serverURLs ) {
        if ( ! [_discoveredServers containsObject:url] ) {
            [_discoveredServers addObject:url];
        }
    }
    int urlCount = (int)[_discoveredServers count];
    [_comboBoxServerURL1 noteNumberOfItemsChanged];
    [_comboBoxServerURL1 reloadData];
    
    if ( [[_comboBoxServerURL1 stringValue] length] == 0 && urlCount != 0 ) {
        [_comboBoxServerURL1 selectItemAtIndex:0];
    }
    
    [_comboBoxServerURL2 noteNumberOfItemsChanged];
    [_comboBoxServerURL2 reloadData];
    
    if ( [[_comboBoxServerURL2 stringValue] length] == 0 && 1 < urlCount ) {
        [_comboBoxServerURL2 selectItemAtIndex:1];
    }
} // addBonjourService

- (void)removeBonjourService:(NSNotification *)notification {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSArray *serverURLs = [notification userInfo][@"serverURLs"];
    for ( NSString *url in serverURLs ) {
        [_discoveredServers removeObject:url];
    }
    
    [_comboBoxServerURL1 noteNumberOfItemsChanged];
    [_comboBoxServerURL1 reloadData];
    
    [_comboBoxServerURL2 noteNumberOfItemsChanged];
    [_comboBoxServerURL2 reloadData];
    
} // removeBonjourService

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ([keyPath isEqualToString:NBCUserDefaultsIndexCounter]) {
        NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_dsSource];
        [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    }
} // observeValueForKeyPath:ofObject:change:context

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setNbiName:settingsDict[NBCSettingsNBIName]];
    [self setNbiIndex:settingsDict[NBCSettingsNBIIndex]];
    [self setNbiProtocol:settingsDict[NBCSettingsNBIProtocol]];
    [self setNbiEnabled:[settingsDict[NBCSettingsNBIEnabled] boolValue]];
    [self setNbiDefault:[settingsDict[NBCSettingsNBIDefault] boolValue]];
    [self setNbiLanguage:settingsDict[NBCSettingsNBILanguage]];
    [self setNbiDescription:settingsDict[NBCSettingsNBIDescription]];
    [self setDestinationFolder:settingsDict[NBCSettingsNBIDestinationFolder]];
    [self setNbiIconPath:settingsDict[NBCSettingsNBIIcon]];
    [self setNetworkTimeServer:settingsDict[NBCSettingsDeployStudioTimeServerKey]];
    [self setUseCustomServers:[settingsDict[NBCSettingsDeployStudioUseCustomServersKey] boolValue]];
    [self setServerURL1:settingsDict[NBCSettingsDeployStudioServerURL1Key]];
    [self setServerURL2:settingsDict[NBCSettingsDeployStudioServerURL2Key]];
    [self setDisableVersionMismatchAlerts:[settingsDict[NBCSettingsDeployStudioDisableVersionMismatchAlertsKey] boolValue]];
    [self setDsRuntimeLogin:settingsDict[NBCSettingsDeployStudioRuntimeLoginKey]];
    [self setDsRuntimePassword:settingsDict[NBCSettingsDeployStudioRuntimePasswordKey]];
    [self setArdLogin:settingsDict[NBCSettingsARDLoginKey]];
    [self setArdPassword:settingsDict[NBCSettingsARDPasswordKey]];
    [self setDisplayLogWindow:[settingsDict[NBCSettingsDeployStudioDisplayLogWindowKey] boolValue]];
    [self setSleep:[settingsDict[NBCSettingsDeployStudioSleepKey] boolValue]];
    [self setSleepDelayMinutes:settingsDict[NBCSettingsDeployStudioSleepDelayKey]];
    [self setReboot:[settingsDict[NBCSettingsDeployStudioRebootKey] boolValue]];
    [self setRebootDelaySeconds:settingsDict[NBCSettingsDeployStudioRebootDelayKey]];
    [self setIncludePython:[settingsDict[NBCSettingsDeployStudioIncludePythonKey] boolValue]];
    [self setIncludeRuby:[settingsDict[NBCSettingsDeployStudioIncludeRubyKey] boolValue]];
    [self setUseCustomTCPStack:[settingsDict[NBCSettingsDeployStudioUseCustomTCPStackKey] boolValue]];
    [self setDisableWirelessSupport:[settingsDict[NBCSettingsDeployStudioDisableWirelessSupportKey] boolValue]];
    [self setUseSMB1:[settingsDict[NBCSettingsDeployStudioUseSMB1Key] boolValue]];
    [self setUseCustomRuntimeTitle:[settingsDict[NBCSettingsDeployStudioUseCustomRuntimeTitleKey] boolValue]];
    [self setCustomRuntimeTitle:settingsDict[NBCSettingsDeployStudioRuntimeTitleKey]];
    [self setUseCustomBackgroundImage:[settingsDict[NBCSettingsDeployStudioUseCustomBackgroundImageKey] boolValue]];
    [self setImageBackgroundURL:settingsDict[NBCSettingsDeployStudioCustomBackgroundImageKey]];
    
    [self expandVariablesForCurrentSettings];
} // updateUISettingsFromDict

- (void)updateUISettingsFromURL:(NSURL *)url {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    if ( mainDict ) {
        NSDictionary *settingsDict = mainDict[NBCSettingsSettingsKey];
        if ( settingsDict ) {
            [self updateUISettingsFromDict:settingsDict];
        } else {
            NSLog(@"No key named Settings i plist at URL: %@", url);
        }
    } else {
        NSLog(@"Could not read plist at URL: %@", url);
    }
} // updateUISettingsFromURL

- (NSDictionary *)returnSettingsFromUI {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    
    settingsDict[NBCSettingsNBIName] = _nbiName ?: @"";
    settingsDict[NBCSettingsNBIIndex] = _nbiIndex ?: @"";
    settingsDict[NBCSettingsNBIProtocol] = _nbiProtocol ?: @"";
    settingsDict[NBCSettingsNBILanguage] = _nbiLanguage ?: @"";
    settingsDict[NBCSettingsNBIEnabled] = @(_nbiEnabled) ?: @NO;
    settingsDict[NBCSettingsNBIDefault] = @(_nbiDefault) ?: @NO;
    settingsDict[NBCSettingsNBIDescription] = _nbiDescription ?: @"";
    if ( _destinationFolder != nil ) {
        NSString *currentUserHome = NSHomeDirectory();
        if ( [_destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [_destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsNBIDestinationFolder] = destinationFolderPath ?: @"";
        } else {
            settingsDict[NBCSettingsNBIDestinationFolder] = _destinationFolder ?: @""; }
    }
    settingsDict[NBCSettingsNBIIcon] = _nbiIconPath ?: @"";
    settingsDict[NBCSettingsDeployStudioTimeServerKey] = _networkTimeServer ?: @"";
    settingsDict[NBCSettingsDeployStudioUseCustomServersKey] = @(_useCustomServers) ?: @NO;
    settingsDict[NBCSettingsDeployStudioServerURL1Key] = _serverURL1 ?: @"";
    settingsDict[NBCSettingsDeployStudioServerURL2Key] = _serverURL2 ?: @"";
    settingsDict[NBCSettingsDeployStudioDisableVersionMismatchAlertsKey] = @(_disableVersionMismatchAlerts) ?: @NO;
    settingsDict[NBCSettingsDeployStudioRuntimeLoginKey] = _dsRuntimeLogin ?: @"";
    settingsDict[NBCSettingsDeployStudioRuntimePasswordKey] = _dsRuntimePassword ?: @"";
    settingsDict[NBCSettingsARDLoginKey] = _ardLogin ?: @"";
    settingsDict[NBCSettingsARDPasswordKey] = _ardPassword ?: @"";
    settingsDict[NBCSettingsDeployStudioDisplayLogWindowKey] = @(_displayLogWindow) ?: @NO;
    settingsDict[NBCSettingsDeployStudioSleepKey] = @(_sleep) ?: @NO;
    settingsDict[NBCSettingsDeployStudioSleepDelayKey] = _sleepDelayMinutes ?: @"";
    settingsDict[NBCSettingsDeployStudioRebootKey] = @(_reboot) ?: @NO;
    settingsDict[NBCSettingsDeployStudioRebootDelayKey] = _rebootDelaySeconds ?: @"";
    settingsDict[NBCSettingsDeployStudioIncludePythonKey] = @(_includePython) ?: @NO;
    settingsDict[NBCSettingsDeployStudioIncludeRubyKey] = @(_includeRuby) ?: @NO;
    settingsDict[NBCSettingsDeployStudioUseCustomTCPStackKey] = @(_useCustomTCPStack) ?: @NO;
    settingsDict[NBCSettingsDeployStudioDisableWirelessSupportKey] = @(_disableWirelessSupport) ?: @NO;
    settingsDict[NBCSettingsDeployStudioUseSMB1Key] = @(_useSMB1) ?: @NO;
    settingsDict[NBCSettingsDeployStudioUseCustomRuntimeTitleKey] = @(_useCustomRuntimeTitle) ?: @NO;
    settingsDict[NBCSettingsDeployStudioRuntimeTitleKey] = _customRuntimeTitle ?: @"";
    settingsDict[NBCSettingsDeployStudioUseCustomBackgroundImageKey] = @(_useCustomBackgroundImage) ?: @NO;
    settingsDict[NBCSettingsDeployStudioCustomBackgroundImageKey] = _imageBackgroundURL ?: @"";
    
    return [settingsDict copy];
} // returnSettingsFromUI

- (NSDictionary *)returnSettingsFromURL:(NSURL *)url {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    NSDictionary *settingsDict;
    if ( mainDict ) {
        settingsDict = mainDict[NBCSettingsSettingsKey];
    }
    
    return settingsDict;
} // returnSettingsFromURL

- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)settingsURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *targetURL = settingsURL;
    // -------------------------------------------------------------
    //  Create an empty dict and add template type, name and version
    // -------------------------------------------------------------
    NSMutableDictionary *mainDict = [[NSMutableDictionary alloc] init];
    mainDict[NBCSettingsNameKey] = name;
    mainDict[NBCSettingsTypeKey] = NBCSettingsTypeDeployStudio;
    mainDict[NBCSettingsVersionKey] = NBCSettingsFileVersion;
    
    // ----------------------------------------------------------------
    //  Get current UI settings and add to settings sub-dict
    // ----------------------------------------------------------------
    NSDictionary *settingsDict = [self returnSettingsFromUI];
    mainDict[NBCSettingsSettingsKey] = settingsDict;
    
    // -------------------------------------------------------------
    //  If no url was passed it means it's never been saved before.
    //  Create a new UUID and set 'settingsURL' to the new settings file
    // -------------------------------------------------------------
    if ( targetURL == nil ) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        targetURL = [_templatesFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nbic", uuid]];
    }
    
    // -------------------------------------------------------------
    //  Create the template folder if it doesn't exist.
    // -------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ( ! [_templatesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fm createDirectoryAtURL:_templatesFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"DeployStudio template folder create failed: %@", error);
        }
    }
    
    // -------------------------------------------------------------
    //  Write settings to url and update _templatesDict
    // -------------------------------------------------------------
    if ( [mainDict writeToURL:targetURL atomically:NO] ) {
        [_templatesDict setValue:targetURL forKey:name];
    } else {
        NSLog(@"Writing DeployStudio template to disk failed!");
    }
} // saveUISettingsWithName:atUrl

- (BOOL)haveSettingsChanged {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    NSURL *defaultSettingsURL = [[NSBundle mainBundle] URLForResource:NBCSettingsTypeDeployStudioDefaultSettings withExtension:@"plist"];
    if ( defaultSettingsURL ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        if ( [defaultSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *defaultSettings = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsURL];
            if ( currentSettings && defaultSettings ) {
                NSMutableDictionary *defaultSettingsOSBackground = [defaultSettings mutableCopy];
                defaultSettingsOSBackground[NBCSettingsDeployStudioCustomBackgroundImageKey] = NBCDeployStudioBackgroundImageDefaultPath;
                if ( [currentSettings isEqualToDictionary:defaultSettings] || [currentSettings isEqualToDictionary:defaultSettingsOSBackground] ) {
                    return NO;
                }
            }
        }
    }
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        return retval;
    }
    
    NSURL *savedSettingsURL = _templatesDict[_selectedTemplate];
    if ( savedSettingsURL ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        NSDictionary *savedSettings = [self returnSettingsFromURL:savedSettingsURL];
        if ( currentSettings && savedSettings ) {
            NSMutableDictionary *currentSettingsOSBackground = [currentSettings mutableCopy];
            if ( [currentSettings[NBCSettingsDeployStudioCustomBackgroundImageKey] isEqualToString:NBCDeployStudioBackgroundImageDefaultPath] ) {
                currentSettingsOSBackground[NBCSettingsDeployStudioCustomBackgroundImageKey] = NBCDeployStudioBackgroundDefaultPath;
            } else {
                currentSettingsOSBackground[NBCSettingsDeployStudioCustomBackgroundImageKey] = NBCDeployStudioBackgroundImageDefaultPath;
            }
            
            if ( [currentSettings isEqualToDictionary:savedSettings] || [currentSettingsOSBackground isEqualToDictionary:savedSettings] ) {
                retval = NO;
            }
        } else {
            NSLog(@"Could not compare UI settings to saved template settings, one of them is nil!");
        }
    } else {
        NSLog(@"Could not get URL to current template file!");
    }
    
    return retval;
} // haveSettingsChanged

- (void)expandVariablesForCurrentSettings {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -------------------------------------------------------------
    //  Expand tilde in destination folder path
    // -------------------------------------------------------------
    if ( [_destinationFolder hasPrefix:@"~"] ) {
        NSString *destinationFolderPath = [_destinationFolder stringByExpandingTildeInPath];
        [self setDestinationFolder:destinationFolderPath];
    }
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Index
    // -------------------------------------------------------------
    NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_dsSource];
    [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Name
    // -------------------------------------------------------------
    NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_dsSource];
    [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Description
    // -------------------------------------------------------------
    NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_dsSource];
    [_textFieldNBIDescriptionPreview setStringValue:nbiDescription];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Icon Path
    // -------------------------------------------------------------
    NSString *nbiIconPath = [NBCVariables expandVariables:_nbiIconPath source:_source applicationSource:_dsSource];
    [self setNbiIcon:nbiIconPath];
    
    // -------------------------------------------------------------
    //  Expand variables in Image Background Path
    // -------------------------------------------------------------
    NSString *customBackgroundPath = [NBCVariables expandVariables:_imageBackgroundURL source:_source applicationSource:_dsSource];
    [self setImageBackground:customBackgroundPath];
    
} // expandVariablesForCurrentSettings

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction Buttons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonChooseDestinationFolder:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [chooseDestionation setTitle:@"Choose Destination Folder"];
    [chooseDestionation setPrompt:@"Choose"];
    [chooseDestionation setCanChooseFiles:NO];
    [chooseDestionation setCanChooseDirectories:YES];
    [chooseDestionation setCanCreateDirectories:YES];
    [chooseDestionation setAllowsMultipleSelection:NO];
    
    if ( [chooseDestionation runModal] == NSModalResponseOK ) {
        // -------------------------------------------------------------------------
        //  Get first item in URL array returned (should only be one) and update UI
        // -------------------------------------------------------------------------
        NSArray* selectedURLs = [chooseDestionation URLs];
        NSURL* selectedURL = [selectedURLs firstObject];
        [self setDestinationFolder:[selectedURL path]];
    }
} // buttonChooseDestinationFolder

- (IBAction)matrixUseCustomServers:(id)sender {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( [sender isEqualTo:_matrixUseCustomServers] ) {
        if ( _useCustomServers == YES && _isSearching == NO ) {
            [self setIsSearching:YES];
            [_discoveredServers removeAllObjects];
            [_bonjourBrowser startBonjourDiscovery];
        } else if ( _useCustomServers == NO ) {
            [_bonjourBrowser stopBonjourDiscovery];
            [self setIsSearching:NO];
        }
    }
} // matrixUseCustomServers

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton DeployStudio Version
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)getDeployStudioVersions {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCDownloaderDeployStudio *downloader =  [[NBCDownloaderDeployStudio alloc] initWithDelegate:self];
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagDeployStudio };
    [downloader getReleaseVersionsAndURLsFromDeployStudioRepository:NBCDeployStudioRepository downloadInfo:downloadInfo];
} // getDeployStudioVersions

- (void)getDeployStudioVersionLatest {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCDownloader *downloader =  [[NBCDownloader alloc] initWithDelegate:self];
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagDeployStudio };
    [downloader downloadPageAsData:[NSURL URLWithString:NBCDeployStudioLatestVersionURL] downloadInfo:downloadInfo];
} // getDeployStudioVersions

- (void)updateDeployStudioVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *deployStudioVersion = [_dsSource deployStudioAdminVersion];
    if ( [deployStudioVersion length] != 0 ) {
        [_textFieldDeployStudioVersion setStringValue:deployStudioVersion];
        if ( [deployStudioVersion isEqualToString:_deployStudioLatestVersion] ) {
            [self hideUpdateAvailable];
        }
    } else {
        [_textFieldDeployStudioVersion setStringValue:@"Not Installed."];
        [self showDeployStudioNotInstalled:_deployStudioLatestVersion];
    }
}

- (void)showUpdateAvailable:(NSString *)latestVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_buttonDownloadDeployStudio setHidden:NO];
    if ( [_dsSource isInstalled] ) {
        [_textFieldUpdateAvailable setStringValue:[NSString stringWithFormat:@"(Update available: %@)", latestVersion]];
    } else {
        [_textFieldUpdateAvailable setStringValue:[NSString stringWithFormat:@"(Latest version: %@)", latestVersion]];
    }
    [_textFieldUpdateAvailable setHidden:NO];
}

- (void)showUpdateAvailableCached:(NSString *)latestVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_buttonDownloadDeployStudio setHidden:YES];
    if ( [_dsSource isInstalled] ) {
        [_textFieldUpdateAvailable setStringValue:[NSString stringWithFormat:@"(Update available: %@)", latestVersion]];
    } else {
        [_textFieldUpdateAvailable setStringValue:[NSString stringWithFormat:@"(Latest version: %@)", latestVersion]];
    }
    [_textFieldUpdateAvailable setHidden:NO];
}

- (void)hideUpdateAvailable {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_buttonDownloadDeployStudio setHidden:YES];
    [_textFieldUpdateAvailable setHidden:YES];
}

- (void)showDeployStudioNotInstalled:(NSString *)latestVersion {
#pragma unused(latestVersion)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_buttonDownloadDeployStudio setHidden:NO];
    [_textFieldUpdateAvailable setStringValue:[NSString stringWithFormat:@"(Latest version: %@)", latestVersion]];
    [_textFieldUpdateAvailable setHidden:NO];
}

- (IBAction)buttonDownloadDeployStudio:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0 ) {
        [[NSApp mainWindow] beginSheet:_windowDeployStudioDownload completionHandler:nil];
    } else {
        NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
        
        // --------------------------------------------------------------
        //  Setup open dialog to only allow one folder to be chosen.
        // --------------------------------------------------------------
        [chooseDestionation setTitle:@"Choose Destination Folder"];
        [chooseDestionation setPrompt:@"Download"];
        [chooseDestionation setCanChooseFiles:NO];
        [chooseDestionation setCanChooseDirectories:YES];
        [chooseDestionation setCanCreateDirectories:YES];
        [chooseDestionation setAllowsMultipleSelection:NO];
        
        if ( [chooseDestionation runModal] == NSModalResponseOK ) {
            // -------------------------------------------------------------------------
            //  Get first item in URL array returned (should only be one) and update UI
            // -------------------------------------------------------------------------
            NSArray* selectedURLs = [chooseDestionation URLs];
            NSURL* selectedURL = [selectedURLs firstObject];
            
            NSString *downloadURL = _deployStudioVersionsDownloadLinks[_deployStudioLatestVersion];
            if ( [downloadURL length] != 0 ) {
                NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagDeployStudio };
                if ( _deployStudioDownloader ) {
                    [self setDeployStudioDownloader:nil];
                }
                [self setDeployStudioDownloader:[[NBCDownloader alloc] initWithDelegate:self]];
                [_deployStudioDownloader downloadFileFromURL:[NSURL URLWithString:downloadURL]
                                destinationPath:[selectedURL path]
                                   downloadInfo:downloadInfo];
                [self showDeployStudioDownloadProgess:_deployStudioLatestVersion];
            } else {
                NSLog(@"Could not get download url for latest DeployStudio Version!");
            }
        }
    }
}

- (void)updatePopUpButtonDeployStudioVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _popUpButtonDeployStudioVersion ) {
        [_popUpButtonDeployStudioVersion removeAllItems];
        [_popUpButtonDeployStudioVersion addItemWithTitle:NBCMenuItemDeployStudioVersionLatest];
        [[_popUpButtonDeployStudioVersion menu] addItem:[NSMenuItem separatorItem]];
        [_popUpButtonDeployStudioVersion addItemsWithTitles:_deployStudioVersions];
        
        //[self setDeployStudioVersion:[_popUpButtonDeployStudioVersion titleOfSelectedItem]];
        //[self showPopUpButtonDeployStudioVersion];
    }
    
    if ( _popUpButtonDeployStudioDownload ) {
        [_popUpButtonDeployStudioDownload removeAllItems];
        [_popUpButtonDeployStudioDownload addItemWithTitle:NBCMenuItemDeployStudioVersionLatest];
        [[_popUpButtonDeployStudioDownload menu] addItem:[NSMenuItem separatorItem]];
        [_popUpButtonDeployStudioDownload addItemsWithTitles:_deployStudioVersions];
    }
    
} // updatePopUpButtonImagrVersions

- (void)cachedDeployStudioVersionLocal {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCWorkflowResourcesController *resourcesController = [[NBCWorkflowResourcesController alloc] init];
    NSDictionary *cachedDownloadsDict = [resourcesController cachedDownloadsDictFromResourceFolder:NBCFolderResourcesDeployStudio];
    if ( [cachedDownloadsDict count] != 0 ) {
        NSString *latestVersion = cachedDownloadsDict[NBCResourcesDeployStudioLatestVersionKey];
        if ( [latestVersion length] != 0 ) {
            [self setDeployStudioLatestVersion:latestVersion];
            NSString *currentVersion = [_dsSource deployStudioAdminVersion];
            if ( ! [currentVersion isEqualToString:latestVersion] ) {
                [self showUpdateAvailableCached:latestVersion];
            }
        }
    }
} // cachedDeployStudioVersionLocal

- (void)updateCachedDeployStudioLatestVersion:(NSString *)deployStudioLatestVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCWorkflowResourcesController *resourcesController = [[NBCWorkflowResourcesController alloc] init];
    NSURL *deployStudioDownloadsDictURL = [resourcesController cachedDownloadsDictURLFromResourceFolder:NBCFolderResourcesDeployStudio];
    if ( deployStudioDownloadsDictURL != nil ) {
        if ( [deployStudioDownloadsDictURL checkResourceIsReachableAndReturnError:nil] ) {
            NSMutableDictionary *deployStudioDownloadsDict = [[NSDictionary dictionaryWithContentsOfURL:deployStudioDownloadsDictURL] mutableCopy];
            deployStudioDownloadsDict[NBCResourcesDeployStudioLatestVersionKey] = deployStudioLatestVersion;
            if ( ! [deployStudioDownloadsDict writeToURL:deployStudioDownloadsDictURL atomically:YES] ) {
                NSLog(@"Error writing DeployStudio downloads dict to caches");
            }
        } else {
            NSError *error;
            NSFileManager *fm = [NSFileManager defaultManager];
            if ( [fm createDirectoryAtURL:[deployStudioDownloadsDictURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error] ) {
                NSDictionary *deployStudioDownloadsDict = @{ NBCResourcesDeployStudioLatestVersionKey : deployStudioLatestVersion };
                if ( ! [deployStudioDownloadsDict writeToURL:deployStudioDownloadsDictURL atomically:YES] ) {
                    NSLog(@"Error writing DeployStudio downloads dict to caches");
                }
            } else {
                NSLog(@"Could not create Cache Folder for DeployStudio");
                NSLog(@"Error: %@", error);
            }
        }
    }
} // updateCachedDeployStudioLatestVersion

- (void)showPopUpButtonDeployStudioVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_textFieldDeployStudioVersion setHidden:YES];
    [_popUpButtonDeployStudioVersion setHidden:NO];
} // showPopUpButtonDeployStudioVersion

- (void)hidePopUpButtonDeployStudioVersion {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_popUpButtonDeployStudioVersion setHidden:YES];
    [_textFieldDeployStudioVersion setHidden:NO];
} // hidePopUpButtonDeployStudioVersion

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction PopUpButtons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)popUpButtonTemplates:(id)sender {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *selectedTemplate = [[sender selectedItem] title];
    BOOL settingsChanged = [self haveSettingsChanged];
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        [_templates showSheetSaveUntitled:selectedTemplate buildNBI:NO];
        return;
    } else if ( settingsChanged ) {
        NSDictionary *alertInfo = @{
                                    NBCAlertTagKey : NBCAlertTagSettingsUnsaved,
                                    NBCAlertUserInfoSelectedTemplate : selectedTemplate
                                    };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?"
                              alertInfo:alertInfo];
    } else {
        [self setSelectedTemplate:[[sender selectedItem] title]];
        [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
    }
} // popUpButtonTemplates

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Build Button
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)verifyBuildButton {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL buildEnabled = YES;
    
    // -------------------------------------------------------------
    //  Verify that the current source is not nil.
    // -------------------------------------------------------------
    if ( _source == nil ) {
        buildEnabled = NO;
    }
    
    // -------------------------------------------------------------
    //  Verify that the destination folder is not empty
    // -------------------------------------------------------------
    if ( [_destinationFolder length] == 0 ) {
        buildEnabled = NO;
    }
    
    // --------------------------------------------------------------------------------
    //  Post a notification that sets the button state to value of bool 'buildEnabled'
    // --------------------------------------------------------------------------------
    NSDictionary * userInfo = @{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @(buildEnabled) };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:userInfo];
    
} // verifyBuildButton

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Build NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)buildNBI {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NBCWorkflowItem *workflowItem = [[NBCWorkflowItem alloc] initWithWorkflowType:kWorkflowTypeDeployStudio];
    [workflowItem setSource:_source];
    [workflowItem setApplicationSource:_dsSource];
    [workflowItem setSettingsViewController:self];
    
    // ----------------------------------------------------------------
    //  Collect current UI settings and pass them through verification
    // ----------------------------------------------------------------
    NSDictionary *userSettings = [self returnSettingsFromUI];
    if ( userSettings ) {
        [workflowItem setUserSettings:userSettings];
        
        NBCSettingsController *sc = [[NBCSettingsController alloc] init];
        NSDictionary *errorInfoDict = [sc verifySettings:workflowItem];
        if ( [errorInfoDict count] != 0 ) {
            BOOL configurationError = NO;
            BOOL configurationWarning = NO;
            NSMutableString *alertInformativeText = [[NSMutableString alloc] init];
            NSArray *error = errorInfoDict[NBCSettingsError];
            NSArray *warning = errorInfoDict[NBCSettingsWarning];
            
            if ( [error count] != 0 ) {
                configurationError = YES;
                for ( NSString *errorString in error ) {
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n• %@", errorString]];
                }
            }
            
            if ( [warning count] != 0 ) {
                configurationWarning = YES;
                for ( NSString *warningString in warning ) {
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n• %@", warningString]];
                }
            }
            
            // ----------------------------------------------------------------
            //  If any errors are found, display alert and stop NBI creation
            // ----------------------------------------------------------------
            if ( configurationError ) {
                [NBCAlerts showAlertSettingsError:alertInformativeText];
            }
            
            // --------------------------------------------------------------------------------
            //  If only warnings are found, display alert and allow user to continue or cancel
            // --------------------------------------------------------------------------------
            if ( ! configurationError && configurationWarning ) {
                NSDictionary *alertInfo = @{
                                            NBCAlertTagKey : NBCAlertTagSettingsWarning,
                                            NBCAlertWorkflowItemKey : workflowItem
                                            };
                
                NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
                [alerts showAlertSettingsWarning:alertInformativeText alertInfo:alertInfo];
            }
        } else {
            [self prepareWorkflowItem:workflowItem];
        }
    } else {
        NSLog(@"Could not get settings from UI");
    }
} // buildNBI

- (void)prepareWorkflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -------------------------------------------------------------------
    //  Instantiate all workflows to be used to create a DeployStudio NBI
    // -------------------------------------------------------------------
    NBCDeployStudioWorkflowResources *workflowResources = [[NBCDeployStudioWorkflowResources alloc] init];
    [workflowItem setWorkflowResources:workflowResources];
    
    NBCDeployStudioWorkflowNBI *workflowNBI = [[NBCDeployStudioWorkflowNBI alloc] init];
    [workflowItem setWorkflowNBI:workflowNBI];
    
    NBCDeployStudioWorkflowModifyNBI *workflowModifyNBI = [[NBCDeployStudioWorkflowModifyNBI alloc] init];
    [workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    // -------------------------------------------------------------
    //  Post notification to add workflow item to queue
    // -------------------------------------------------------------
    NSDictionary *userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : workflowItem };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationAddWorkflowItemToQueue object:self userInfo:userInfo];
} // prepareWorkflow

- (IBAction)buttonDeployStudioDownloadDownload:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *selectedVersion = [_popUpButtonDeployStudioDownload titleOfSelectedItem];
    if ( [selectedVersion isEqualToString:NBCMenuItemDeployStudioVersionLatest] ) {
        selectedVersion = _deployStudioLatestVersion;
    }
    NSString *downloadURLString = _deployStudioVersionsDownloadLinks[selectedVersion];
    NSURL *downloadURL = [NSURL URLWithString:downloadURLString];
    
    if ( downloadURL != nil ) {
        NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
        
        // --------------------------------------------------------------
        //  Setup open dialog to only allow one folder to be chosen.
        // --------------------------------------------------------------
        [chooseDestionation setTitle:@"Choose Destination Folder"];
        [chooseDestionation setPrompt:@"Download"];
        [chooseDestionation setCanChooseFiles:NO];
        [chooseDestionation setCanChooseDirectories:YES];
        [chooseDestionation setCanCreateDirectories:YES];
        [chooseDestionation setAllowsMultipleSelection:NO];
        
        if ( [chooseDestionation runModal] == NSModalResponseOK ) {
            // -------------------------------------------------------------------------
            //  Get first item in URL array returned (should only be one) and update UI
            // -------------------------------------------------------------------------
            NSArray* selectedURLs = [chooseDestionation URLs];
            NSURL* selectedURL = [selectedURLs firstObject];
            NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagDeployStudio };
            if ( _deployStudioDownloader ) {
                [self setDeployStudioDownloader:nil];
            }
            [self setDeployStudioDownloader:[[NBCDownloader alloc] initWithDelegate:self]];
            [_deployStudioDownloader downloadFileFromURL:downloadURL
                            destinationPath:[selectedURL path]
                               downloadInfo:downloadInfo];
        }
    } else {
        NSLog(@"Could not get download url for latest DeployStudio Version!");
    }
    [[NSApp mainWindow] endSheet:_windowDeployStudioDownload];
    [self showDeployStudioDownloadProgess:selectedVersion];
}

- (void)showDeployStudioDownloadProgess:(NSString *)version {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_textFieldDeployStudioDownloadProgressTitle setStringValue:[NSString stringWithFormat:@"Downloading DeployStudio v.%@", version]];
    [_progressIndicatorDeployStudioDownloadProgress setIndeterminate:NO];
    [_progressIndicatorDeployStudioDownloadProgress setMinValue:0];
    [_progressIndicatorDeployStudioDownloadProgress setDoubleValue:0.0];
    [[NSApp mainWindow] beginSheet:_windowDeployStudioDownloadProgress completionHandler:nil];
}

- (IBAction)buttonDeployStudioDownloadCancel:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [[NSApp mainWindow] endSheet:_windowDeployStudioDownload];
}

- (IBAction)buttonDeployStudioDownloadProgressCancel:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _deployStudioDownloader != nil ) {
        [_deployStudioDownloader cancelDownload];
    }
}
@end
