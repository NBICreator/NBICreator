//
//  NBCIMSettingsViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-29.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"

#import "NBCWorkflowItem.h"
#import "NBCSettingsController.h"
#import "NBCSourceController.h"
#import "NBCController.h"

#import "NBCImagrWorkflowNBI.h"
#import "NBCImagrWorkflowResources.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

#import "Reachability.h"

@interface NBCImagrSettingsViewController () {
    Reachability *_internetReachableFoo;
}
@end

@implementation NBCImagrSettingsViewController

#pragma mark -
#pragma mark Initialization
#pragma mark -

- (id)init {
    self = [super initWithNibName:@"NBCImagrSettingsViewController" bundle:nil];
    if (self != nil) {
        _templates = [[NBCTemplatesController alloc] initWithSettingsViewController:self templateType:NBCSettingsTypeImagr delegate:self];
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
    [nc addObserver:self selector:@selector(updateSource:) name:NBCNotificationImagrUpdateSource object:nil];
    [nc addObserver:self selector:@selector(removedSource:) name:NBCNotificationImagrRemovedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIIcon:) name:NBCNotificationImagrUpdateNBIIcon object:nil];
    
    // --------------------------------------------------------------
    //  Add KVO Observers
    // --------------------------------------------------------------
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:NBCUserDefaultsIndexCounter options:NSKeyValueObservingOptionNew context:nil];
    
    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( userApplicationSupport ) {
        _templatesFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesImagr isDirectory:YES];
    } else {
        NSLog(@"Could not get user Application Support Folder");
        NSLog(@"Error: %@", error);
    }
    _siuSource = [[NBCSystemImageUtilitySource alloc] init];
    _templatesDict = [[NSMutableDictionary alloc] init];
    [self setShowARDPassword:NO];
    
    [self testInternetConnection];
    
    // --------------------------------------------------------------
    //  Load saved templates and create the template menu
    // --------------------------------------------------------------
    [_templates updateTemplateListForPopUpButton:_popUpButtonTemplates title:nil];
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI Icon image view to allow to restore original icon.
    // -------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *restoreView = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalIcon action:@selector(restoreNBIIcon:) keyEquivalent:@""];
    [restoreView setTarget:self];
    [menu addItem:restoreView];
    [_imageViewIcon setMenu:menu];
    
    // ------------------------------------------------------------------------------
    //  Verify build button so It's not enabled by mistake
    // -------------------------------------------------------------------------------
    [self verifyBuildButton];
    
} // viewDidLoad

#pragma mark -
#pragma mark Reachability
#pragma mark -

- (void)testInternetConnection {
    _internetReachableFoo = [Reachability reachabilityWithHostname:@"github.com"];
    __unsafe_unretained typeof(self) weakSelf = self;
    
    // Internet is reachable
    _internetReachableFoo.reachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf getImagrVersions];
        });
    };
    
    // Internet is not reachable
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updatePopUpButtonImagrVersionsLocal];
        });
    };
    
    [_internetReachableFoo startNotifier];
} // testInternetConnection

#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    BOOL retval = YES;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalIcon] ) {
        
        // -------------------------------------------------------------
        //  No need to restore original icon if it's already being used
        // -------------------------------------------------------------
        if ( [_nbiIconPath isEqualToString:NBCFilePathNBIIconImagr] ) {
            retval = NO;
        }
        return retval;
    }
    
    return YES;
} // validateMenuItem

#pragma mark -
#pragma mark Delegate Methods TextField
#pragma mark -

- (void)controlTextDidChange:(NSNotification *)sender {
    
    // --------------------------------------------------------------------
    //  Expand variables for the NBI preview text fields
    // --------------------------------------------------------------------
    if ( [sender object] == _textFieldNBIName ) {
        if ( [_nbiName length] == 0 ) {
            [_textFieldNBINamePreview setStringValue:@""];
        } else {
            NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_siuSource];
            [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
        }
    } else if ( [sender object] == _textFieldIndex ) {
        if ( [_nbiIndex length] == 0 ) {
            [_textFieldIndexPreview setStringValue:@""];
        } else {
            NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
            [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
        }
    } else if ( [sender object] == _textFieldNBIDescription ) {
        if ( [_nbiDescription length] == 0 ) {
            [_textFieldNBIDescriptionPreview setStringValue:@""];
        } else {
            NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_siuSource];
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

#pragma mark -
#pragma mark Delegate Methods NBCDownloaderGitHub
#pragma mark -

- (void)githubReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagImagr] ) {
        [self setImagrVersions:versionsArray];
        [self setImagrVersionsDownloadLinks:downloadDict];
        [self updatePopUpButtonImagrVersions];
        [self updateCachedImagrVersions:downloadDict];
    }
} // githubReleaseVersionsArray:downloadDict:downloadInfo

#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsWarning] ) {
        if ( returnCode == NSAlertSecondButtonReturn ) {        // Continue
            NBCWorkflowItem *workflowItem = alertInfo[NBCAlertWorkflowItemKey];
            [self prepareWorkflowItem:workflowItem];
        }
    }
    
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
    
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsavedBuild] ) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save and Continue
            if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
                [_templates showSheetSaveUntitled:selectedTemplate buildNBI:YES];
                return;
            } else {
                [self saveUISettingsWithName:_selectedTemplate atUrl:_templatesDict[_selectedTemplate]];
                [self setSelectedTemplate:selectedTemplate];
                [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
                [self expandVariablesForCurrentSettings];
                [self verifySettings];
                return;
            }
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Continue
            [self verifySettings];
            return;
        } else {                                                // Cancel
            [_popUpButtonTemplates selectItemWithTitle:_selectedTemplate];
            return;
        }
    }
} // alertReturnCode:alertInfo

#pragma mark -
#pragma mark Notification Methods
#pragma mark -

- (void)updateSource:(NSNotification *)notification {
    NBCSource *source = [notification userInfo][NBCNotificationUpdateSourceUserInfoSource];
    if ( source != nil ) {
        [self setSource:source];
    }
    
    NBCTarget *target = [notification userInfo][NBCNotificationUpdateSourceUserInfoTarget];
    if ( target != nil ) {
        [self setTarget:target];
    }
    
    if ( [[source sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        [self setIsNBI:YES];
        NSURL *nbiURL = [source sourceURL];
        [self createSettingsFromNBI:nbiURL];
    } else {
        [self setIsNBI:NO];
        [_textFieldDestinationFolder setEnabled:YES];
        [_buttonChooseDestinationFolder setEnabled:YES];
        [_popUpButtonTool setEnabled:YES];
        [self expandVariablesForCurrentSettings];
        [self verifyBuildButton];
    }
} // updateSource

- (void)removedSource:(NSNotification *)notification {
#pragma unused(notification)
    if ( _source ) {
        [self setSource:nil];
    }
    [self setIsNBI:NO];
    [_textFieldDestinationFolder setEnabled:YES];
    [_buttonChooseDestinationFolder setEnabled:YES];
    [_popUpButtonTool setEnabled:YES];
    [self verifyBuildButton];
} // removedSource

- (void)updateNBIIcon:(NSNotification *)notification {
    NSURL *nbiIconURL = [notification userInfo][NBCNotificationUpdateNBIIconUserInfoIconURL];
    if ( nbiIconURL != nil )
    {
        // To get the view to update I have to first set the nbiIcon property to @""
        // It only happens when it recieves a dropped image, not when setting in code.
        [self setNbiIcon:@""];
        [self setNbiIconPath:[nbiIconURL path]];
    }
} // updateNBIIcon

- (void)restoreNBIIcon:(NSNotification *)notification {
#pragma unused(notification)
    [self setNbiIconPath:NBCFilePathNBIIconImagr];
    [self expandVariablesForCurrentSettings];
} // restoreNBIIcon

#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    if ( [keyPath isEqualToString:NBCUserDefaultsIndexCounter] ) {
        NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
        [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    }
} // observeValueForKeyPath:ofObject:change:context

#pragma mark -
#pragma mark Settings
#pragma mark -

- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict {
    [self setNbiCreationTool:settingsDict[NBCSettingsNBICreationToolKey]];
    [self setNbiName:settingsDict[NBCSettingsNBIName]];
    [self setNbiIndex:settingsDict[NBCSettingsNBIIndex]];
    [self setNbiProtocol:settingsDict[NBCSettingsNBIProtocol]];
    [self setNbiEnabled:[settingsDict[NBCSettingsNBIEnabled] boolValue]];
    [self setNbiDefault:[settingsDict[NBCSettingsNBIDefault] boolValue]];
    [self setNbiLanguage:settingsDict[NBCSettingsNBILanguage]];
    [self setNbiDescription:settingsDict[NBCSettingsNBIDescription]];
    [self setDestinationFolder:settingsDict[NBCSettingsNBIDestinationFolder]];
    [self setNbiIconPath:settingsDict[NBCSettingsNBIIcon]];
    [self setDisableWiFi:[settingsDict[NBCSettingsDisableWiFiKey] boolValue]];
    [self setDisplaySleep:[settingsDict[NBCSettingsDisplaySleepKey] boolValue]];
    [self setDisplaySleepMinutes:settingsDict[NBCSettingsDisplaySleepMinutesKey]];
    [self setArdLogin:settingsDict[NBCSettingsARDLoginKey]];
    [self setArdPassword:settingsDict[NBCSettingsARDPasswordKey]];
    [self setNetworkTimeServer:settingsDict[NBCSettingsNetworkTimeServerKey]];
    [self setImagrVersion:settingsDict[NBCSettingsImagrVersion]];
    [self setIncludeImagrPreReleaseVersions:[settingsDict[NBCSettingsImagrIncludePreReleaseVersions] boolValue]];
    [self setImagrConfigurationURL:settingsDict[NBCSettingsImagrConfigurationURL]];
    [self setImagrUseLocalVersion:[settingsDict[NBCSettingsImagrUseLocalVersion] boolValue]];
    [self setImagrLocalVersionPath:settingsDict[NBCSettingsImagrLocalVersionPath]];
    [self setIsNBI:[settingsDict[NBCSettingsImagrSourceIsNBI] boolValue]];
    
    if ( [_imagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        [self showImagrLocalVersionInput];
    } else {
        [self hideImagrLocalVersionInput];
    }
    
    [self uppdatePopUpButtonTool];
    
    if ( _isNBI ) {
        [_popUpButtonTool setEnabled:NO];
        [_textFieldDestinationFolder setEnabled:NO];
        [_buttonChooseDestinationFolder setEnabled:NO];
        if ([settingsDict[NBCSettingsDisableWiFiKey] boolValue] ) {
            [_checkboxDisableWiFi setEnabled:NO];
        } else {
            [_checkboxDisableWiFi setEnabled:YES];
        }
    } else {
        [_popUpButtonTool setEnabled:YES];
        [_textFieldDestinationFolder setEnabled:YES];
        [_buttonChooseDestinationFolder setEnabled:YES];
    }
    
    if ( _nbiCreationTool == nil || [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        [self hideSystemImageUtilityVersion];
    } else {
        [self showSystemImageUtilityVersion];
    }
    
    [self expandVariablesForCurrentSettings];
} // updateUISettingsFromDict

- (void)updateUISettingsFromURL:(NSURL *)url {
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
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    
    settingsDict[NBCSettingsNBICreationToolKey] = _nbiCreationTool ?: @"";
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
    settingsDict[NBCSettingsDisableWiFiKey] = @(_disableWiFi) ?: @NO;
    settingsDict[NBCSettingsDisplaySleepKey] = @(_displaySleep) ?: @NO;
    settingsDict[NBCSettingsDisplaySleepMinutesKey] = _displaySleepMinutes ?: @"";
    settingsDict[NBCSettingsImagrVersion] = _imagrVersion ?: @"";
    settingsDict[NBCSettingsImagrConfigurationURL] = _imagrConfigurationURL ?: @"";
    settingsDict[NBCSettingsImagrUseLocalVersion] = @(_imagrUseLocalVersion) ?: @NO;
    settingsDict[NBCSettingsImagrLocalVersionPath] = _imagrLocalVersionPath ?: @"";
    settingsDict[NBCSettingsARDLoginKey] = _ardLogin ?: @"";
    settingsDict[NBCSettingsARDPasswordKey] = _ardPassword ?: @"";
    settingsDict[NBCSettingsNetworkTimeServerKey] = _networkTimeServer ?: @"";
    settingsDict[NBCSettingsImagrSourceIsNBI] = @(_isNBI) ?: @NO;
    
    return [settingsDict copy];
} // returnSettingsFromUI

- (void)createSettingsFromNBI:(NSURL *)nbiURL {
    NSError *err;
    if ( ! [nbiURL checkResourceIsReachableAndReturnError:&err] ) {
        NSLog(@"Could not find NBI!");
        NSLog(@"Error: %@", err);
        return;
    }
    
    NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
    if ( ! [nbImageInfoURL checkResourceIsReachableAndReturnError:&err] ) {
        NSLog(@"Could not find nbImageInfoURL");
        NSLog(@"Error: %@", err);
        return;
    }
    
    NSDictionary *nbImageInfoDict = [[NSDictionary alloc] initWithContentsOfURL:nbImageInfoURL];
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    
    settingsDict[NBCSettingsImagrSourceIsNBI] = @YES;
    
    NSString *nbiName = nbImageInfoDict[NBCNBImageInfoDictNameKey];
    if ( nbiName != nil ) {
        settingsDict[NBCSettingsNBIName] = nbiName;
    } else {
        settingsDict[NBCSettingsNBIName] = _nbiName ?: @"";
    }
    
    NSNumber *nbiIndex = nbImageInfoDict[NBCNBImageInfoDictIndexKey];
    if ( nbiIndex != nil ) {
        settingsDict[NBCSettingsNBIIndex] = [nbiIndex stringValue];
    } else if ( _nbiIndex != nil ) {
        settingsDict[NBCSettingsNBIIndex] = _nbiIndex;
    }
    
    NSString *nbiProtocol = nbImageInfoDict[NBCNBImageInfoDictProtocolKey];
    if ( nbiProtocol != nil ) {
        settingsDict[NBCSettingsNBIProtocol] = nbiProtocol;
    } else {
        settingsDict[NBCSettingsNBIProtocol] = _nbiProtocol ?: @"NFS";
    }
    
    NSString *nbiLanguage = nbImageInfoDict[NBCNBImageInfoDictLanguageKey];
    if ( nbiLanguage != nil ) {
        settingsDict[NBCSettingsNBILanguage] = nbiLanguage;
    } else {
        settingsDict[NBCSettingsNBILanguage] = _nbiLanguage ?: @"Current";
    }
    
    BOOL nbiEnabled = [nbImageInfoDict[NBCNBImageInfoDictIsEnabledKey] boolValue];
    if ( @(nbiEnabled) != nil ) {
        settingsDict[NBCSettingsNBIEnabled] = @(nbiEnabled);
    } else {
        settingsDict[NBCSettingsNBIEnabled] = @(_nbiEnabled) ?: @NO;
    }
    
    BOOL nbiDefault = [nbImageInfoDict[NBCNBImageInfoDictIsDefaultKey] boolValue];
    if ( @(nbiDefault) != nil ) {
        settingsDict[NBCSettingsNBIDefault] = @(nbiDefault);
    } else {
        settingsDict[NBCSettingsNBIDefault] = @(_nbiDefault) ?: @NO;
    }
    
    NSString *nbiDescription = nbImageInfoDict[NBCNBImageInfoDictDescriptionKey];
    if ( [nbiDescription length] != 0 ) {
        settingsDict[NBCSettingsNBIDescription] = nbiDescription;
    } else {
        settingsDict[NBCSettingsNBIDescription] = _nbiDescription ?: @"";
    }
    
    NSURL *destinationFolderURL = [_source sourceURL];
    if ( destinationFolderURL != nil ) {
        settingsDict[NBCSettingsNBIDestinationFolder] = [destinationFolderURL path];
    } else if ( _destinationFolder != nil ) {
        NSString *currentUserHome = NSHomeDirectory();
        if ( [_destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [_destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsNBIDestinationFolder] = destinationFolderPath;
        } else {
            settingsDict[NBCSettingsNBIDestinationFolder] = _destinationFolder; }
    }
    
    //NSImage *nbiIcon = [[NSWorkspace sharedWorkspace] iconForFile:[nbiURL path]]; // To be fixed later
    
    settingsDict[NBCSettingsNBIIcon] = _nbiIconPath ?: @"";
    
    BOOL nbiImagrConfigurationDictFound = NO;
    BOOL nbiImagrVersionFound = NO;
    if ( _target != nil ) {
        NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
        NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
        if ( [nbiNetInstallVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
            NSURL *nbiImagrConfigurationDictURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrConfigurationPlistTargetURL];
            if ( [nbiImagrConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
                NSDictionary *nbiImagrConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiImagrConfigurationDictURL];
                if ( [nbiImagrConfigurationDict count] != 0 ) {
                    NSString *imagrConfigurationURL = nbiImagrConfigurationDict[NBCSettingsImagrServerURLKey];
                    if ( imagrConfigurationURL != nil ) {
                        settingsDict[NBCSettingsImagrConfigurationURL] = imagrConfigurationURL;
                        nbiImagrConfigurationDictFound = YES;
                    }
                }
            }
            
            NSURL *nbiApplicationURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrApplicationTargetURL];
            if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
                NSString *nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                if ( [nbiImagrVersion length] != 0 ) {
                    settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion;
                    [_target setImagrApplicationExistOnTarget:YES];
                    nbiImagrVersionFound = YES;
                }
            }
        } else if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
            NSURL *nbiImagrConfigurationDictURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrConfigurationPlistNBICreatorTargetURL];
            if ( [nbiImagrConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
                NSDictionary *nbiImagrConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiImagrConfigurationDictURL];
                if ( [nbiImagrConfigurationDict count] != 0 ) {
                    NSString *imagrConfigurationURL = nbiImagrConfigurationDict[NBCSettingsImagrServerURLKey];
                    if ( imagrConfigurationURL != nil ) {
                        settingsDict[NBCSettingsImagrConfigurationURL] = imagrConfigurationURL;
                        nbiImagrConfigurationDictFound = YES;
                    }
                }
            }
            
            NSURL *nbiApplicationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrApplicationNBICreatorTargetURL];
            if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
                NSString *nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                if ( [nbiImagrVersion length] != 0 ) {
                    settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion;
                    [_target setImagrApplicationExistOnTarget:YES];
                    nbiImagrVersionFound = YES;
                }
            }
        }
        
        if ( ! nbiImagrConfigurationDictFound ) {
            settingsDict[NBCSettingsImagrConfigurationURL] = @"";
        }
        
        if ( ! nbiImagrVersionFound ) {
            settingsDict[NBCSettingsImagrVersion] = NBCMenuItemImagrVersionLatest;
        }
        
        if ( @(_includeImagrPreReleaseVersions) != nil ) {
            settingsDict[NBCSettingsImagrIncludePreReleaseVersions] = @(_includeImagrPreReleaseVersions);
        }
        
        NSString *rcInstall;
        NSURL *rcInstallURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrRCInstallTargetURL];
        if ( [rcInstallURL checkResourceIsReachableAndReturnError:nil] ) {
            rcInstall = [NSString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:&err];
            
        }
        
        NSString *rcImaging;
        NSURL *rcImagingURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrRCImagingNBICreatorTargetURL];
        if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
            rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
            
        } else {
            rcImagingURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrRCImagingTargetURL];
            if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
                rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
            }
        }
        
        NSString *rcFiles = [NSString stringWithFormat:@"%@\n%@", rcInstall, rcImaging];
        
        if ( [rcFiles length] != 0 ) {
            NSArray *rcFilesArray = [rcFiles componentsSeparatedByString:@"\n"];
            for ( NSString *line in rcFilesArray ) {
                if ( [line containsString:@"pmset"] && [line containsString:@"displaysleep"] ) {
                    NSError* regexError = nil;
                    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"displaysleep [0-9]+"
                                                                                           options:0
                                                                                             error:&regexError];
                    
                    if ( regex == nil ) {
                        NSLog(@"Regex creation failed with error: %@", [regexError description]);
                    }
                    
                    NSArray *matches = [regex matchesInString:line
                                                      options:NSMatchingWithoutAnchoringBounds
                                                        range:NSMakeRange(0, line.length)];
                    
                    for (NSTextCheckingResult *entry in matches) {
                        NSString *text = [line substringWithRange:entry.range];
                        if ( [text length] != 0 ) {
                            NSString *displaySleepTime = [text componentsSeparatedByString:@" "][1];
                            if ( [displaySleepTime length] != 0 ) {
                                if ( [displaySleepTime integerValue] == 0 ) {
                                    settingsDict[NBCSettingsDisplaySleepKey] = @NO;
                                    settingsDict[NBCSettingsDisplaySleepMinutesKey] = @"0";
                                } else {
                                    settingsDict[NBCSettingsDisplaySleepKey] = @YES;
                                    settingsDict[NBCSettingsDisplaySleepMinutesKey] = displaySleepTime;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        NSURL *wifiKext = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
        if ( [wifiKext checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsDisableWiFiKey] = @NO;
        } else {
            settingsDict[NBCSettingsDisableWiFiKey] = @YES;
        }
        
        // Get network Time Server
        NSURL *ntpConfigurationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];
        if ( [ntpConfigurationURL checkResourceIsReachableAndReturnError:nil] ) {
            NSString *ntpConfiguration = [NSString stringWithContentsOfURL:ntpConfigurationURL encoding:NSUTF8StringEncoding error:nil];
            NSArray *ntpConfigurationArray = [ntpConfiguration componentsSeparatedByString:@"\n"];
            NSString *ntpConfigurationFirstLine = ntpConfigurationArray[0];
            if ( [ntpConfigurationFirstLine containsString:@"server"] ) {
                NSString *ntpServer = [ntpConfigurationFirstLine componentsSeparatedByString:@" "][1];
                if ( [ntpServer length] != 0 ) {
                    settingsDict[NBCSettingsNetworkTimeServerKey] = ntpServer;
                }
            }
        }
        
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
            }];
            
        }] readSettingsFromNBI:nbiBaseSystemVolumeURL settingsDict:[settingsDict copy] withReply:^(NSError *error, BOOL success, NSDictionary *newSettingsDict) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                
                if ( success )
                {
                    NSLog(@"Success");
                    NSLog(@"newSettingsDict=%@", newSettingsDict);
                    [self updateUISettingsFromDict:newSettingsDict];
                    [self saveUISettingsWithName:nbiName atUrl:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.nbic", NSTemporaryDirectory(), [[NSUUID UUID] UUIDString]]]]; // Temporary, to test
                    [self->_templates updateTemplateListForPopUpButton:self->_popUpButtonTemplates title:nbiName];
                    [self verifyBuildButton];
                } else {
                    NSLog(@"CopyFailed!");
                    NSLog(@"Error: %@", error);
                }
            }];
        }];
        /*
         
         
         // Get any configured user name
         NSURL *dsLocalUsersURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"var/db/dslocal/nodes/Default/users"];
         if ( [dsLocalUsersURL checkResourceIsReachableAndReturnError:&err] ) {
         NSArray *userFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dsLocalUsersURL path] error:nil];
         NSMutableArray *userFilesFiltered = [[userFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (self BEGINSWITH '_')"]] mutableCopy];
         [userFilesFiltered removeObjectsInArray:@[ @"daemon.plist", @"nobody.plist", @"root.plist" ]];
         if ( [userFilesFiltered count] != 0 ) {
         NSString *firstUser = userFilesFiltered[0];
         NSURL *firstUserPlistURL = [dsLocalUsersURL URLByAppendingPathComponent:firstUser];
         NSDictionary *firstUserDict = [NSDictionary dictionaryWithContentsOfURL:firstUserPlistURL];
         if ( firstUserDict ) {
         NSArray *userNameArray = firstUserDict[@"name"];
         NSString *userName = userNameArray[0];
         if ( [userName length] != 0 ) {
         settingsDict[NBCSettingsARDLoginKey] = userName;
         }
         }
         }
         } else {
         NSLog(@"Could not get path to local user database");
         NSLog(@"Error: %@", err);
         }
         
         // Get any configured user password
         NSURL *vncPasswordFile = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
         if ( [vncPasswordFile checkResourceIsReachableAndReturnError:nil] ) {
         NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
         NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-c",
         [NSString stringWithFormat:@"/bin/cat %@ | perl -wne 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; chomp; @p = unpack \"C*\", pack \"H*\", $_; foreach (@k) { printf \"%%c\", $_ ^ (shift @p || 0) }; print \"\n\"'", [vncPasswordFile path]],
         nil];
         NSPipe *stdOut = [[NSPipe alloc] init];
         NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
         [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
         __block NSString *outStr;
         NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
         id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
         object:[stdOut fileHandleForReading]
         queue:nil
         usingBlock:^(NSNotification *notification){
         #pragma unused(notification)
         
         // ------------------------
         //  Convert data to string
         // ------------------------
         NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
         outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
         
         // -----------------------------------------------------------------------
         //  When output data becomes available, pass it to workflow status parser
         // -----------------------------------------------------------------------
         NSLog(@"outStr=%@", outStr);
         
         [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
         }];
         
         // -----------------------------------------------------------------------------------
         //  Create standard error file handle and register for data available notifications.
         // -----------------------------------------------------------------------------------
         NSPipe *stdErr = [[NSPipe alloc] init];
         NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
         [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
         __block NSString *errStr;
         id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
         object:[stdErr fileHandleForReading]
         queue:nil
         usingBlock:^(NSNotification *notification){
         #pragma unused(notification)
         
         // ------------------------
         //  Convert data to string
         // ------------------------
         NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
         errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
         
         // -----------------------------------------------------------------------
         //  When error data becomes available, pass it to workflow status parser
         // -----------------------------------------------------------------------
         NSLog(@"errStr=%@", errStr);
         
         [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
         }];
         
         NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
         [helperConnector connectToHelper];
         
         [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
         [[NSOperationQueue mainQueue]addOperationWithBlock:^{
         
         // ------------------------------------------------------------------
         //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
         // ------------------------------------------------------------------
         NSLog(@"ProxyError? %@", proxyError);
         [nc removeObserver:stdOutObserver];
         [nc removeObserver:stdErrObserver];
         }];
         
         }] runTaskWithCommandAtPath:commandURL arguments:args environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
         #pragma unused(error)
         [[NSOperationQueue mainQueue]addOperationWithBlock:^{
         [nc removeObserver:stdOutObserver];
         [nc removeObserver:stdErrObserver];
         
         if ( terminationStatus == 0 )
         {
         if ( [outStr length] != 0 ) {
         settingsDict[NBCSettingsARDPasswordKey] = outStr;
         }
         [self updateUISettingsFromDict:settingsDict];
         [self->_templates updateTemplateListForPopUpButton:self->_popUpButtonTemplates title:nbiName];
         [self verifyBuildButton];
         [self->_textFieldDestinationFolder setEnabled:NO];
         [self->_buttonChooseDestinationFolder setEnabled:NO];
         [self->_popUpButtonTool setEnabled:NO];
         } else {
         
         }
         }];
         }];
         
         }
         */
        
    }
} // returnSettingsFromUI

- (NSDictionary *)returnSettingsFromURL:(NSURL *)url {
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    NSDictionary *settingsDict;
    if ( mainDict ) {
        settingsDict = mainDict[NBCSettingsSettingsKey];
    }
    
    return settingsDict;
} // returnSettingsFromURL

- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)url {
    NSURL *settingsURL = url;
    // -------------------------------------------------------------
    //  Create an empty dict and add template type, name and version
    // -------------------------------------------------------------
    NSMutableDictionary *mainDict = [[NSMutableDictionary alloc] init];
    mainDict[NBCSettingsNameKey] = name;
    mainDict[NBCSettingsTypeKey] = NBCSettingsTypeImagr;
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
    if ( settingsURL == nil ) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        settingsURL = [_templatesFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nbic", uuid]];
    }
    
    // -------------------------------------------------------------
    //  Create the template folder if it doesn't exist.
    // -------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ( ! [_templatesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fm createDirectoryAtURL:_templatesFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Imagr template folder create failed: %@", error);
        }
    }
    
    // -------------------------------------------------------------
    //  Write settings to url and update _templatesDict
    // -------------------------------------------------------------
    if ( [mainDict writeToURL:settingsURL atomically:NO] ) {
        _templatesDict[name] = settingsURL;
    } else {
        NSLog(@"Writing Imagr template to disk failed!");
    }
} // saveUISettingsWithName:atUrl

- (BOOL)haveSettingsChanged {
    BOOL retval = YES;
    
    NSURL *defaultSettingsURL = [[NSBundle mainBundle] URLForResource:NBCSettingsTypeImagrDefaultSettings withExtension:@"plist"];
    if ( defaultSettingsURL ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        if ( [defaultSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *defaultSettings = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsURL];
            if ( currentSettings && defaultSettings ) {
                if ( [currentSettings isEqualToDictionary:defaultSettings] ) {
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
            if ( [currentSettings isEqualToDictionary:savedSettings] ) {
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
    NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
    [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Name
    // -------------------------------------------------------------
    NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_siuSource];
    [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Description
    // -------------------------------------------------------------
    NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_siuSource];
    [_textFieldNBIDescriptionPreview setStringValue:nbiDescription];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Icon Path
    // -------------------------------------------------------------
    NSString *nbiIconPath = [NBCVariables expandVariables:_nbiIconPath source:_source applicationSource:_siuSource];
    [self setNbiIcon:nbiIconPath];
    
} // expandVariablesForCurrentSettings

#pragma mark -
#pragma mark IBAction Buttons
#pragma mark -

- (IBAction)buttonChooseDestinationFolder:(id)sender {
#pragma unused(sender)
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

#pragma mark -
#pragma mark IBAction PopUpButtons
#pragma mark -

- (IBAction)popUpButtonTemplates:(id)sender {
    NSString *selectedTemplate = [[sender selectedItem] title];
    BOOL settingsChanged = [self haveSettingsChanged];
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        [_templates showSheetSaveUntitled:selectedTemplate buildNBI:NO];
        return;
    } else if ( settingsChanged ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsUnsaved,
                                     NBCAlertUserInfoSelectedTemplate : selectedTemplate };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?"
                              alertInfo:alertInfo];
    } else {
        [self setSelectedTemplate:[[sender selectedItem] title]];
        [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
    }
} // popUpButtonTemplates

#pragma mark -
#pragma mark PopUpButton NBI Creation Tool
#pragma mark -

- (void)uppdatePopUpButtonTool {
    NSString *systemUtilityVersion = [_siuSource systemImageUtilityVersion];
    if ( ! [_siuSource isSupported] ) {
        //systemUtilityVersion = [systemUtilityVersion stringByAppendingString:@" (Untested)"];
    }
    [_textFieldSIUVersionString setStringValue:systemUtilityVersion];
    
    if ( _popUpButtonTool ) {
        [_popUpButtonTool removeAllItems];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemNBICreator];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemSystemImageUtility];
        
        [_popUpButtonTool selectItemWithTitle:_nbiCreationTool];
        [self setNbiCreationTool:[_popUpButtonTool titleOfSelectedItem]];
    }
} // uppdatePopUpButtonTool

- (IBAction)popUpButtonTool:(id)sender {
    NSString *selectedVersion = [[sender selectedItem] title];
    if ( [selectedVersion isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [self showSystemImageUtilityVersion];
        if ( [_nbiDescription isEqualToString:NBCNBIDescriptionNBC] ) {
            [self setNbiDescription:NBCNBIDescriptionSIU];
        }
        
        [self expandVariablesForCurrentSettings];
    } else {
        [self hideSystemImageUtilityVersion];
        if ( [_nbiDescription isEqualToString:NBCNBIDescriptionSIU] ) {
            [self setNbiDescription:NBCNBIDescriptionNBC];
        }
        
        [self expandVariablesForCurrentSettings];
    }
} // popUpButtonTool

- (void)showSystemImageUtilityVersion {
    [self setUseSystemImageUtility:YES];
    [_constraintTemplatesBoxHeight setConstant:93];
    [_constraintSavedTemplatesToTool setConstant:32];
} // showImagrLocalVersionInput

- (void)hideSystemImageUtilityVersion {
    [self setUseSystemImageUtility:NO];
    [_constraintTemplatesBoxHeight setConstant:70];
    [_constraintSavedTemplatesToTool setConstant:8];
} // hideImagrLocalVersionInput

#pragma mark -
#pragma mark PopUpButton Imagr Version
#pragma mark -

- (void)getImagrVersions {
    NBCDownloaderGitHub *downloader =  [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagImagr };
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCImagrGitHubRepository downloadInfo:downloadInfo];
} // getImagrVersions

- (void)updatePopUpButtonImagrVersionsLocal {
    if ( ! _resourcesController ) {
        [self setResourcesController:[[NBCWorkflowResourcesController alloc] init]];
    }
    
    [_popUpButtonImagrVersion removeAllItems];
    [_popUpButtonImagrVersion addItemWithTitle:NBCMenuItemImagrVersionLatest];
    NSMenuItem *menuItemVersionLocal = [[NSMenuItem alloc] init];
    [menuItemVersionLocal setTitle:NBCMenuItemImagrVersionLocal];
    [menuItemVersionLocal setTarget:self];
    [[_popUpButtonImagrVersion menu] addItem:menuItemVersionLocal];
    [[_popUpButtonImagrVersion menu] addItem:[NSMenuItem separatorItem]];
    [[_popUpButtonImagrVersion menu] setAutoenablesItems:NO];
    
    NSArray *localImagrVersions = [_resourcesController cachedVersionsFromResourceFolder:NBCFolderResourcesImagr];
    NSDictionary *cachedDownloadsDict = [_resourcesController cachedDownloadsDictFromResourceFolder:NBCFolderResourcesImagr];
    if ( cachedDownloadsDict != nil ) {
        [self setImagrVersionsDownloadLinks:cachedDownloadsDict];
        NSArray *cachedDownloadVersions = [cachedDownloadsDict allKeys];
        BOOL cachedVersionAvailable = NO;
        for ( NSString *version in cachedDownloadVersions ) {
            NSMenuItem *versionItem = [[NSMenuItem alloc] init];
            [versionItem setTitle:version];
            if ( [localImagrVersions containsObject:version] ) {
                cachedVersionAvailable = YES;
                [versionItem setEnabled:YES];
            } else {
                [versionItem setEnabled:NO];
            }
            [[_popUpButtonImagrVersion menu] addItem:versionItem];
        }
        if ( ! cachedVersionAvailable ) {
            NSMenuItem *latestVersionMenuItem = [[_popUpButtonImagrVersion menu] itemWithTitle:NBCMenuItemImagrVersionLatest];
            [latestVersionMenuItem setEnabled:NO];
            // Add check what segmented control is selected, only show when Imagr is selected. Queue notifications, how?
            [NBCAlerts showAlertOKWithTitle:@"No Cached Versions Available" informativeText:@"Until you connect to the internet, only local version of Imagr.app can be used to create an Imagr NBI."];
        }
    }
    
    [_imageViewNetworkWarning setHidden:NO];
    [_textFieldNetworkWarning setHidden:NO];
}

- (void)updatePopUpButtonImagrVersions {
    if ( _popUpButtonImagrVersion ) {
        [_popUpButtonImagrVersion removeAllItems];
        [_popUpButtonImagrVersion addItemWithTitle:NBCMenuItemImagrVersionLatest];
        NSMenuItem *menuItemVersionLocal = [[NSMenuItem alloc] init];
        [menuItemVersionLocal setTitle:NBCMenuItemImagrVersionLocal];
        [menuItemVersionLocal setTarget:self];
        [[_popUpButtonImagrVersion menu] addItem:menuItemVersionLocal];
        [[_popUpButtonImagrVersion menu] addItem:[NSMenuItem separatorItem]];
        
        [_popUpButtonImagrVersion addItemsWithTitles:_imagrVersions];
        [_popUpButtonImagrVersion selectItemWithTitle:_imagrVersion];
        [self setImagrVersion:[_popUpButtonImagrVersion titleOfSelectedItem]];
    }
    
    [_imageViewNetworkWarning setHidden:YES];
    [_textFieldNetworkWarning setHidden:YES];
} // updatePopUpButtonImagrVersions

- (void)updateCachedImagrVersions:(NSDictionary *)imagrVersionsDict
{
    if ( ! _resourcesController ) {
        [self setResourcesController:[[NBCWorkflowResourcesController alloc] init]];
    }
    
    NSURL *imagrDownloadsDictURL = [_resourcesController cachedDownloadsDictURLFromResourceFolder:NBCFolderResourcesImagr];
    if ( imagrDownloadsDictURL != nil ) {
        if ( ! [imagrVersionsDict writeToURL:imagrDownloadsDictURL atomically:YES] ) {
            NSLog(@"Error writing imagr downloads dict to caches");
        }
    }
} // updateCachedImagrVersions

- (IBAction)popUpButtonImagrVersion:(id)sender {
    NSString *selectedVersion = [[sender selectedItem] title];
    if ( [selectedVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        [self showImagrLocalVersionInput];
    } else {
        [self hideImagrLocalVersionInput];
    }
    
} // popUpButtonImagrVersion

- (void)showImagrLocalVersionInput {
    [self setImagrUseLocalVersion:YES];
    [_constraintConfigurationURLToImagrVersion setConstant:42];
    [_textFieldImagrLocalPathLabel setHidden:NO];
    [_textFieldImagrLocalPath setHidden:NO];
    [_buttonChooseImagrLocalPath setHidden:NO];
} // showImagrLocalVersionInput

- (void)hideImagrLocalVersionInput {
    [self setImagrUseLocalVersion:NO];
    [_constraintConfigurationURLToImagrVersion setConstant:13];
    [_textFieldImagrLocalPathLabel setHidden:YES];
    [_textFieldImagrLocalPath setHidden:YES];
    [_buttonChooseImagrLocalPath setHidden:YES];
} // hideImagrLocalVersionInput

- (IBAction)buttonChooseImagrLocalPath:(id)sender {
#pragma unused(sender)
    NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [chooseDestionation setTitle:@"Select Imagr Application"];
    [chooseDestionation setPrompt:@"Choose"];
    [chooseDestionation setCanChooseFiles:YES];
    [chooseDestionation setCanChooseDirectories:NO];
    [chooseDestionation setCanCreateDirectories:NO];
    [chooseDestionation setAllowsMultipleSelection:NO];
    
    if ( [chooseDestionation runModal] == NSModalResponseOK ) {
        // -------------------------------------------------------------------------
        //  Get first item in URL array returned (should only be one) and update UI
        // -------------------------------------------------------------------------
        NSArray* selectedURLs = [chooseDestionation URLs];
        NSURL* selectedURL = [selectedURLs firstObject];
        NSBundle *bundle = [NSBundle bundleWithURL:selectedURL];
        if ( bundle != nil ) {
            NSString *bundleIdentifier = [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
            if ( [bundleIdentifier isEqualToString:NBCImagrBundleIdentifier] ) {
                [self setImagrLocalVersionPath:[selectedURL path]];
                return;
            }
        }
        [NBCAlerts showAlertUnrecognizedImagrApplication];
    }
    
} // buttonChooseImagrLocalPath

#pragma mark -
#pragma mark Verify Build Button
#pragma mark -

- (void)verifyBuildButton {
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

#pragma mark -
#pragma mark Build NBI
#pragma mark -

- (void)buildNBI {
    if ( [self haveSettingsChanged] ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsUnsavedBuild,
                                     NBCAlertUserInfoSelectedTemplate : _selectedTemplate };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsavedBuild:@"You have unsaved settings, do you want to save current template and continue?"
                                   alertInfo:alertInfo];
    } else if ( _isNBI && ! [self haveSettingsChanged] ) {
        [NBCAlerts showAlertSettingsUnchangedNBI];
        return;
    } else {
        [self verifySettings];
    }
} // buildNBI

- (void)verifySettings {
    NBCWorkflowItem *workflowItem = [[NBCWorkflowItem alloc] initWithWorkflowType:kWorkflowTypeImagr];
    [workflowItem setSource:_source];
    [workflowItem setApplicationSource:_siuSource];
    [workflowItem setSettingsViewController:self];
    
    // ----------------------------------------------------------------
    //  Collect current UI settings and pass them through verification
    // ----------------------------------------------------------------
    NSDictionary *userSettings = [self returnSettingsFromUI];
    if ( userSettings ) {
        [workflowItem setUserSettings:userSettings];
        
        NBCSettingsController *sc = [[NBCSettingsController alloc] init];
        NSDictionary *errorInfoDict = [sc verifySettingsImagr:workflowItem];
        if ( [errorInfoDict count] != 0 ) {
            BOOL configurationError = NO;
            BOOL configurationWarning = NO;
            NSMutableString *alertInformativeText = [[NSMutableString alloc] init];
            NSArray *error = errorInfoDict[NBCSettingsError];
            NSArray *warning = errorInfoDict[NBCSettingsWarning];
            
            if ( [error count] != 0 ) {
                configurationError = YES;
                for ( NSString *errorString in error ) {
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n%@", errorString]];
                }
            }
            
            if ( [warning count] != 0 ) {
                configurationWarning = YES;
                for ( NSString *warningString in warning ) {
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n%@", warningString]];
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
                NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsWarning,
                                             NBCAlertWorkflowItemKey : workflowItem };
                
                NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
                [alerts showAlertSettingsWarning:alertInformativeText alertInfo:alertInfo];
            }
        } else {
            [self prepareWorkflowItem:workflowItem];
        }
    } else {
        NSLog(@"Could not get settings from UI");
    }
} // verifySettings

- (void)prepareWorkflowItem:(NBCWorkflowItem *)workflowItem {
    NSMutableDictionary *userSettings = [[workflowItem userSettings] mutableCopy];
    
    // -------------------------------------------------------------
    //  Get selected Imagr download URL
    // -------------------------------------------------------------
    NSMutableDictionary *resourcesSettings = [[NSMutableDictionary alloc] init];
    NSString *selectedImagrVersion = userSettings[NBCSettingsImagrVersion];
    if ( [selectedImagrVersion length] == 0 ) {
        NSLog(@"ImagrVersionError");
        return;
        
    } else if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        
        if ( [_imagrLocalVersionPath length] == 0 ) {
            NSLog(@"ImagrLocalPathIsEmpty");
            return;
        }
    } else {
        if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLatest] ) {
            if ( [_imagrVersions count] == 0 ) {
                NSLog(@"ImagrVersionsArrayEmpty!");
                return;
            }
            selectedImagrVersion = [_imagrVersions firstObject];
            userSettings[NBCSettingsImagrVersion] = selectedImagrVersion;
            [workflowItem setUserSettings:userSettings];
        }
        NSString *imagrDownloadURL = _imagrVersionsDownloadLinks[selectedImagrVersion];
        if ( [imagrDownloadURL length] == 0 ) {
            NSLog(@"ImagrDownloadLinkError");
            return;
        }
        resourcesSettings[NBCSettingsImagrDownloadURL] = imagrDownloadURL;
        [workflowItem setResourcesSettings:resourcesSettings];
    }
    
    // -------------------------------------------------------------
    //  Create list of items to extract from installer
    // -------------------------------------------------------------
    NBCSourceController *sourceController = [[NBCSourceController alloc] init];
    NSMutableDictionary *sourceItemsDict = [[NSMutableDictionary alloc] init];
    
    // - Python is required for Imagr
    [sourceController addPython:sourceItemsDict source:_source];
    
    // - NTP
    [sourceController addNTP:sourceItemsDict source:_source];
    
    // - VNC if an ARD/VNC password has been set
    if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [sourceController addVNC:sourceItemsDict source:_source];
    }
    
    // - ARD if both ARD login name and ARD/VNC password has been set
    if ( [userSettings[NBCSettingsARDLoginKey] length] != 0 && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [sourceController addARD:sourceItemsDict source:_source];
    }
    
    resourcesSettings[NBCSettingsSourceItemsKey] = sourceItemsDict;
    // -------------------------------------------------------------
    //  Instantiate all workflows to be used to create a Imagr NBI
    // -------------------------------------------------------------
    NBCImagrWorkflowResources *workflowResources = [[NBCImagrWorkflowResources alloc] init];
    [workflowItem setWorkflowResources:workflowResources];
    
    NBCImagrWorkflowNBI *workflowNBI = [[NBCImagrWorkflowNBI alloc] init];
    [workflowItem setWorkflowNBI:workflowNBI];
    
    NBCImagrWorkflowModifyNBI *workflowModifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    [workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    // -------------------------------------------------------------
    //  Post notification to add workflow item to queue
    // -------------------------------------------------------------
    NSDictionary *userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : workflowItem };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationAddWorkflowItemToQueue object:self userInfo:userInfo];
    
} // prepareWorkflowItem

@end
