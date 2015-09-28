//
//  NBCNISettingsController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"

#import "NBCWorkflowItem.h"
#import "NBCSettingsController.h"

#import "NBCNetInstallWorkflowNBI.h"
#import "NBCNetInstallWorkflowResources.h"
#import "NBCNetInstallWorkflowModifyNBI.h"
#import "NBCLogging.h"

#import "NBCPackageTableCellView.h"
#import "NBCDesktopEntity.h"
#import "NBCConfigurationProfileTableCellView.h"

#import "NBCDDReader.h"
#import "NBCOverlayViewController.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallSettingsViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCNetInstallSettingsViewController" bundle:nil];
    if (self != nil) {
        _templates = [[NBCTemplatesController alloc] initWithSettingsViewController:self templateType:NBCSettingsTypeNetInstall delegate:self];
    }
    return self;
} // init

- (void)awakeFromNib {
    [_tableViewConfigurationProfiles registerForDraggedTypes:@[ NSURLPboardType ]];
    [_tableViewPackagesNetInstall registerForDraggedTypes:@[ NSURLPboardType ]];
} // awakeFromNib

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _packagesNetInstallTableViewContents = [[NSMutableArray alloc] init];
    _configurationProfilesTableViewContents = [[NSMutableArray alloc] init];
    
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateSource:) name:NBCNotificationNetInstallUpdateSource object:nil];
    [nc addObserver:self selector:@selector(removedSource:) name:NBCNotificationNetInstallRemovedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIIcon:) name:NBCNotificationNetInstallUpdateNBIIcon object:nil];
    
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
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( userApplicationSupport ) {
        _templatesFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesNetInstall isDirectory:YES];
    } else {
        NSLog(@"Could not get user Application Support Folder");
        NSLog(@"Error: %@", error);
    }
    _siuSource = [[NBCSystemImageUtilitySource alloc] init];
    _templatesDict = [[NSMutableDictionary alloc] init];
    [self initializeTableViewOverlays];
    // --------------------------------------------------------------
    //  Load saved templates and create the template menu
    // --------------------------------------------------------------
    [self updatePopUpButtonTemplates];
    
    // --------------------------------------------------------------
    //  Update default System Image Utility Version in UI.
    // --------------------------------------------------------------
    NSString *systemUtilityVersion = [_siuSource systemImageUtilityVersion];
    if ( [systemUtilityVersion length] != 0 ) {
        [_textFieldSystemImageUtilityVersion setStringValue:systemUtilityVersion];
    } else {
        [_textFieldSystemImageUtilityVersion setStringValue:@"Not Installed"];
    }
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI Icon image view to allow to restore original icon.
    // -------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *restoreView = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalIcon action:@selector(restoreNBIIcon:) keyEquivalent:@""];
    [menu addItem:restoreView];
    [_imageViewIcon setMenu:menu];
    
    // ------------------------------------------------------------------------------
    //  Verify build button so It's not enabled by mistake
    // -------------------------------------------------------------------------------
    [self verifyBuildButton];
    
} // viewDidLoad

- (void)initializeTableViewOverlays {
    if ( ! _viewOverlayPackagesNetInstall ) {
        NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypeNetInstallPackages];
        _viewOverlayPackagesNetInstall = [vc view];
    }
    [self addOverlayViewToView:_superViewPackagesNetInstall overlayView:_viewOverlayPackagesNetInstall];
    
    if ( ! _viewOverlayConfigurationProfiles ) {
        NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypeConfigurationProfiles];
        _viewOverlayConfigurationProfiles = [vc view];
    }
    [self addOverlayViewToView:_superViewConfigurationProfiles overlayView:_viewOverlayConfigurationProfiles];
} // initializeTableViewOverlays

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    BOOL retval = YES;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalIcon] ) {
        // -------------------------------------------------------------
        //  No need to restore original icon if it's already being used
        // -------------------------------------------------------------
        if ( [_nbiIconPath isEqualToString:NBCFilePathNBIIconNetInstall] ) {
            retval = NO;
        }
        return retval;
    }
    
    return YES;
} // validateMenuItem

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods TextField
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsWarning] ) {
        if ( returnCode == NSAlertSecondButtonReturn ) {        // Continue
            NBCWorkflowItem *workflowItem = alertInfo[NBCAlertWorkflowItemKey];
            [self prepareWorkflowItem:workflowItem];
        }
    } else if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsaved] ) {
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
} // alertReturnCode:alertInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSource:(NSNotification *)notification {
    
    NBCSource *source = [notification userInfo][NBCNotificationUpdateSourceUserInfoSource];
    if ( source != nil ) {
        _source = source;
    }
    
    [self expandVariablesForCurrentSettings];
    [self verifyBuildButton];
    [self updatePopOver];
} // updateSource

- (void)removedSource:(NSNotification *)notification {
#pragma unused(notification)
    
    if ( _source ) {
        _source = nil;
    }
    
    [self verifyBuildButton];
    [self updatePopOver];
} // removedSource

- (void)updateNBIIcon:(NSNotification *)notification {
    
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
    
    [self setNbiIconPath:NBCFilePathNBIIconNetInstall];
    [self expandVariablesForCurrentSettings];
} // restoreNBIIcon

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    
    if ([keyPath isEqualToString:NBCUserDefaultsIndexCounter]) {
        NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
        [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
        [self setPopOverIndexCounter:nbiIndex];
    }
} // observeValueForKeyPath:ofObject:change:context

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict {
    
    [self setNbiName:settingsDict[NBCSettingsNameKey]];
    [self setNbiIndex:settingsDict[NBCSettingsIndexKey]];
    [self setNbiProtocol:settingsDict[NBCSettingsProtocolKey]];
    [self setNbiEnabled:[settingsDict[NBCSettingsEnabledKey] boolValue]];
    [self setNbiDefault:[settingsDict[NBCSettingsDefaultKey] boolValue]];
    [self setNbiLanguage:settingsDict[NBCSettingsLanguageKey]];
    [self setNbiDescription:settingsDict[NBCSettingsDescriptionKey]];
    [self setDestinationFolder:settingsDict[NBCSettingsDestinationFolderKey]];
    [self setNbiIconPath:settingsDict[NBCSettingsIconKey]];
    
    [_packagesNetInstallTableViewContents removeAllObjects];
    [_tableViewPackagesNetInstall reloadData];
    if ( [settingsDict[NBCSettingsPackagesNetInstallKey] count] != 0 ) {
        NSArray *packagesArray = settingsDict[NBCSettingsPackagesNetInstallKey];
        for ( NSString *packagePath in packagesArray ) {
            NSURL *packageURL = [NSURL fileURLWithPath:packagePath];
            NSDictionary *packageDict = [self examinePackageAtURL:packageURL];
            if ( [packageDict count] != 0 ) {
                [self insertItemInPackagesNetInstallTableView:packageDict];
            }
        }
    }
    
    [_configurationProfilesTableViewContents removeAllObjects];
    [_tableViewConfigurationProfiles reloadData];
    if ( [settingsDict[NBCSettingsConfigurationProfilesKey] count] != 0 ) {
        NSArray *configurationProfilesArray = settingsDict[NBCSettingsConfigurationProfilesKey];
        for ( NSString *path in configurationProfilesArray ) {
            NSURL *url = [NSURL fileURLWithPath:path];
            NSDictionary *configurationProfileDict = [self examineConfigurationProfileAtURL:url];
            if ( [configurationProfileDict count] != 0 ) {
                [self insertConfigurationProfileInTableView:configurationProfileDict];
            }
        }
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
    
    settingsDict[NBCSettingsNameKey] = _nbiName ?: @"";
    settingsDict[NBCSettingsIndexKey] = _nbiIndex ?: @"";
    settingsDict[NBCSettingsProtocolKey] = _nbiProtocol ?: @"";
    settingsDict[NBCSettingsLanguageKey] = _nbiLanguage ?: @"";
    settingsDict[NBCSettingsEnabledKey] = @(_nbiEnabled) ?: @NO;
    settingsDict[NBCSettingsDefaultKey] = @(_nbiDefault) ?: @NO;
    settingsDict[NBCSettingsDescriptionKey] = _nbiDescription ?: @"";
    if ( _destinationFolder != nil ) {
        NSString *currentUserHome = NSHomeDirectory();
        if ( [_destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [_destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolderPath ?: @"";
        } else {
            settingsDict[NBCSettingsDestinationFolderKey] = _destinationFolder ?: @""; }
    }
    settingsDict[NBCSettingsIconKey] = _nbiIconPath ?: @"";
    
    NSMutableArray *packageArray = [[NSMutableArray alloc] init];
    for ( NSDictionary *packageDict in _packagesNetInstallTableViewContents ) {
        NSString *packagePath = packageDict[NBCDictionaryKeyPath];
        if ( [packagePath length] != 0 ) {
            [packageArray insertObject:packagePath atIndex:0];
        }
    }
    settingsDict[NBCSettingsPackagesNetInstallKey] = packageArray ?: @[];
    
    NSMutableArray *configurationProfilesArray = [[NSMutableArray alloc] init];
    for ( NSDictionary *configurationProfileDict in _configurationProfilesTableViewContents ) {
        NSString *configurationProfilePath = configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath];
        if ( [configurationProfilePath length] != 0 ) {
            [configurationProfilesArray insertObject:configurationProfilePath atIndex:0];
        }
    }
    settingsDict[NBCSettingsConfigurationProfilesKey] = configurationProfilesArray ?: @[];
    
    return [settingsDict copy];
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
    mainDict[NBCSettingsTitleKey] = name;
    mainDict[NBCSettingsTypeKey] = NBCSettingsTypeNetInstall;
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
        settingsURL = [_templatesFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nbictemplate", uuid]];
    }
    
    // -------------------------------------------------------------
    //  Create the template folder if it doesn't exist.
    // -------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ( ! [_templatesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fm createDirectoryAtURL:_templatesFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"NetInstall template folder create failed: %@", error);
        }
    }
    
    // -------------------------------------------------------------
    //  Write settings to url and update _templatesDict
    // -------------------------------------------------------------
    if ( [mainDict writeToURL:settingsURL atomically:NO] ) {
        _templatesDict[name] = settingsURL;
    } else {
        NSLog(@"Writing NetInstall template to disk failed!");
    }
} // saveUISettingsWithName:atUrl

- (BOOL)haveSettingsChanged {
    
    BOOL retval = YES;
    
    NSURL *defaultSettingsURL = [[NSBundle mainBundle] URLForResource:NBCFileNameNetInstallDefaults withExtension:@"plist"];
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction Buttons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

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

- (IBAction)buttonPopOver:(id)sender {
    
    [self updatePopOver];
    [_popOverVariables showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
} // buttonPopOver

- (void)updatePopOver {
    
    NSString *separator = @";";
    NSString *variableString = [NSString stringWithFormat:@"%%OSVERSION%%%@"
                                "%%OSMAJOR%%%@"
                                "%%OSMINOR%%%@"
                                "%%OSPATCH%%%@"
                                "%%OSBUILD%%%@"
                                "%%DATE%%%@"
                                "%%OSINDEX%%%@"
                                "%%NBCVERSION%%%@"
                                ,separator, separator, separator, separator, separator, separator, separator, separator
                                ];
    NSString *expandedVariables = [NBCVariables expandVariables:variableString source:_source applicationSource:_siuSource];
    NSArray *expandedVariablesArray = [expandedVariables componentsSeparatedByString:separator];
    
    // %OSVERSION%
    if ( 1 <= [expandedVariablesArray count] ) {
        NSString *osVersion = expandedVariablesArray[0];
        if ( [osVersion length] != 0 ) {
            [self setPopOverOSVersion:osVersion];
        }
    }
    // %OSMAJOR%
    if ( 2 <= [expandedVariablesArray count] ) {
        NSString *osMajor = expandedVariablesArray[1];
        if ( [osMajor length] != 0 ) {
            [self setPopOverOSMajor:osMajor];
        }
    }
    // %OSMINOR%
    if ( 3 <= [expandedVariablesArray count] ) {
        NSString *osMinor = expandedVariablesArray[2];
        if ( [osMinor length] != 0 ) {
            [self setPopOverOSMinor:osMinor];
        }
    }
    // %OSPATCH%
    if ( 4 <= [expandedVariablesArray count] ) {
        NSString *osPatch = expandedVariablesArray[3];
        if ( [osPatch length] != 0 ) {
            [self setPopOverOSPatch:osPatch];
        }
    }
    // %OSBUILD%
    if ( 5 <= [expandedVariablesArray count] ) {
        NSString *osBuild = expandedVariablesArray[4];
        if ( [osBuild length] != 0 ) {
            [self setPopOverOSBuild:osBuild];
        }
    }
    // %DATE%
    if ( 6 <= [expandedVariablesArray count] ) {
        NSString *date = expandedVariablesArray[5];
        if ( [date length] != 0 ) {
            [self setPopOverDate:date];
        }
    }
    // %OSINDEX%
    if ( 7 <= [expandedVariablesArray count] ) {
        NSString *osIndex = expandedVariablesArray[6];
        if ( [osIndex length] != 0 ) {
            [self setPopOverOSIndex:osIndex];
        }
    }
    // %NBCVERSION%
    if ( 8 <= [expandedVariablesArray count] ) {
        NSString *nbcVersion = expandedVariablesArray[7];
        if ( [nbcVersion length] != 0 ) {
            [self setNbcVersion:nbcVersion];
        }
    }
    // %COUNTER%
    [self setPopOverIndexCounter:[[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsIndexCounter] stringValue]];
    // %SIUVERSION%
    [self setSiuVersion:[_siuSource systemImageUtilityVersion]];
} // updatePopOver

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction PopUpButtons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo {
    
    BOOL settingsChanged = [self haveSettingsChanged];
    
    if ( settingsChanged ) {
        NSDictionary *alertInfo = @{
                                    NBCAlertTagKey : NBCAlertTagSettingsUnsaved,
                                    NBCAlertUserInfoSelectedTemplate : _selectedTemplate
                                    };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?"
                              alertInfo:alertInfo];
    }
    NSLog(@"Importing %@", url);
    NSLog(@"templateInfo=%@", templateInfo);
} // importTemplateAtURL

- (void)updatePopUpButtonTemplates {
    
    [_templates updateTemplateListForPopUpButton:_popUpButtonTemplates title:nil];
} // updatePopUpButtonTemplates

- (IBAction)popUpButtonTemplates:(id)sender {
    
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

- (void)addOverlayViewToView:(NSView *)view overlayView:(NSView *)overlayView {
    [view addSubview:overlayView positioned:NSWindowAbove relativeTo:nil];
    [overlayView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSArray *constraintsArray;
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|-1-[overlayView]-1-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(overlayView)];
    [view addConstraints:constraintsArray];
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-1-[overlayView]-1-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(overlayView)];
    [view addConstraints:constraintsArray];
    [view setHidden:NO];
} // addOverlayViewToView:overlayView

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Build NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)buildNBI {
    NBCWorkflowItem *workflowItem = [[NBCWorkflowItem alloc] initWithWorkflowType:kWorkflowTypeNetInstall
                                                              workflowSessionType:kWorkflowSessionTypeGUI];
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
    NSMutableDictionary *resourcesSettings = [[NSMutableDictionary alloc] init];
    
    NSMutableArray *packages = [[NSMutableArray alloc] init];
    for ( NSDictionary *packageDict in _packagesNetInstallTableViewContents ) {
        NSString *packagePath = packageDict[NBCDictionaryKeyPath];
        [packages addObject:packagePath];
    }
    resourcesSettings[NBCSettingsPackagesNetInstallKey] = [packages copy];
    
    NSMutableArray *configurationProfiles = [[NSMutableArray alloc] init];
    for ( NSDictionary *configurationProfileDict in _configurationProfilesTableViewContents ) {
        NSString *configurationProfilePath = configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath];
        [configurationProfiles addObject:configurationProfilePath];
    }
    resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey] = [configurationProfiles copy];
    
    [workflowItem setResourcesSettings:[resourcesSettings copy]];
    
    // ------------------------------------------------------------------
    //  Instantiate all workflows to be used to create a NetInstall NBI
    // ------------------------------------------------------------------
    NBCNetInstallWorkflowResources *workflowResources = [[NBCNetInstallWorkflowResources alloc] init];
    [workflowItem setWorkflowResources:workflowResources];
    
    NBCNetInstallWorkflowNBI *workflowNBI = [[NBCNetInstallWorkflowNBI alloc] init];
    [workflowItem setWorkflowNBI:workflowNBI];
    
    NBCNetInstallWorkflowModifyNBI *workflowModifyNBI = [[NBCNetInstallWorkflowModifyNBI alloc] init];
    [workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    // -------------------------------------------------------------
    //  Post notification to add workflow item to queue
    // -------------------------------------------------------------
    NSDictionary *userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : workflowItem };
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:NBCNotificationAddWorkflowItemToQueue object:self userInfo:userInfo];
    
} // prepareWorkflow


- (IBAction)buttonAddConfigurationProfile:(id)sender {
#pragma unused(sender)
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [openPanel setTitle:@"Add Configuration Profiles"];
    [openPanel setPrompt:@"Add"];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:@[ @"com.apple.mobileconfig" ]];
    [openPanel setCanChooseDirectories:NO];
    [openPanel setCanCreateDirectories:YES];
    [openPanel setAllowsMultipleSelection:YES];
    
    if ( [openPanel runModal] == NSModalResponseOK ) {
        NSArray* selectedURLs = [openPanel URLs];
        for ( NSURL *packageURL in selectedURLs ) {
            NSDictionary *configurationProfileDict = [self examineConfigurationProfileAtURL:packageURL];
            if ( [configurationProfileDict count] != 0 ) {
                [self insertConfigurationProfileInTableView:configurationProfileDict];
            }
        }
    }
}

- (IBAction)buttonRemoveConfigurationProfile:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewConfigurationProfiles selectedRowIndexes];
    [_configurationProfilesTableViewContents removeObjectsAtIndexes:indexes];
    [_tableViewConfigurationProfiles removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    if ( [_configurationProfilesTableViewContents count] == 0 ) {
        [_viewOverlayConfigurationProfiles setHidden:NO];
    }
}

- (void)insertItemInPackagesNetInstallTableView:(NSDictionary *)itemDict {
    NSString *packagePath = itemDict[NBCDictionaryKeyPath];
    for ( NSDictionary *pkgDict in _packagesNetInstallTableViewContents ) {
        if ( [packagePath isEqualToString:pkgDict[NBCDictionaryKeyPath]] ) {
            DDLogWarn(@"Package %@ is already added!", [packagePath lastPathComponent]);
            return;
        }
    }
    
    NSInteger index = [_tableViewPackagesNetInstall selectedRow];
    index++;
    [_tableViewPackagesNetInstall beginUpdates];
    [_tableViewPackagesNetInstall insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewPackagesNetInstall scrollRowToVisible:index];
    [_packagesNetInstallTableViewContents insertObject:itemDict atIndex:(NSUInteger)index];
    [_tableViewPackagesNetInstall endUpdates];
    [_viewOverlayPackagesNetInstall setHidden:YES];
}

- (void)insertConfigurationProfileInTableView:(NSDictionary *)configurationProfileDict {
    NSString *path = configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath];
    for ( NSDictionary *dict in _configurationProfilesTableViewContents ) {
        if ( [path isEqualToString:dict[NBCDictionaryKeyConfigurationProfilePath]] ) {
            DDLogWarn(@"Configuration Profile %@ is already added!", [path lastPathComponent]);
            return;
        }
    }
    
    NSInteger index = [_tableViewConfigurationProfiles selectedRow];
    index++;
    [_tableViewConfigurationProfiles beginUpdates];
    [_tableViewConfigurationProfiles insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewConfigurationProfiles scrollRowToVisible:index];
    [_configurationProfilesTableViewContents insertObject:configurationProfileDict atIndex:(NSUInteger)index];
    [_tableViewConfigurationProfiles endUpdates];
    [_viewOverlayConfigurationProfiles setHidden:YES];
}

- (NSDictionary *)examinePackageAtURL:(NSURL *)url {
    NSMutableDictionary *newPackageDict = [[NSMutableDictionary alloc] init];
    newPackageDict[NBCDictionaryKeyPath] = [url path];
    newPackageDict[NBCDictionaryKeyName] = [url lastPathComponent];
    return newPackageDict;
}

- (NSDictionary *)examineScriptAtURL:(NSURL *)url {
    NSMutableDictionary *newScriptDict = [[NSMutableDictionary alloc] init];
    NBCDDReader *reader = [[NBCDDReader alloc] initWithFilePath:[url path]];
    [reader enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        if (
            [line hasPrefix:@"#!/bin/bash"] |
            [line hasPrefix:@"#!/bin/sh"]
            ) {
            newScriptDict[NBCDictionaryKeyScriptType] = @"Shell Script";
            *stop = YES;
        }
    }];
    
    if ( [newScriptDict[NBCDictionaryKeyScriptType] length] != 0 ) {
        newScriptDict[NBCDictionaryKeyPath] = [url path];
        newScriptDict[NBCDictionaryKeyName] = [url lastPathComponent];
        return newScriptDict;
    } else {
        return nil;
    }
}

- (NSDictionary *)examineConfigurationProfileAtURL:(NSURL *)url {
    NSMutableDictionary *newConfigurationProfileDict = [[NSMutableDictionary alloc] init];
    newConfigurationProfileDict[NBCDictionaryKeyConfigurationProfilePath] = [url path];
    NSDictionary *configurationProfileDict = [NSDictionary dictionaryWithContentsOfURL:url];
    NSString *payloadName = configurationProfileDict[@"PayloadDisplayName"];
    newConfigurationProfileDict[NBCDictionaryKeyConfigurationProfilePayloadDisplayName] = payloadName ?: @"Unknown";
    NSString *payloadDescription = configurationProfileDict[@"PayloadDescription"];
    newConfigurationProfileDict[NBCDictionaryKeyConfigurationProfilePayloadDisplayName] = payloadDescription ?: @"";
    return newConfigurationProfileDict;
}

- (BOOL)containsAcceptablePackageURLsFromPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadObjectForClasses:@[[NSURL class]]
                                       options:[self pasteboardReadingOptionsPackagesNetInstall]];
}

- (BOOL)containsAcceptableConfigurationProfileURLsFromPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadObjectForClasses:@[[NSURL class]]
                                       options:[self pasteboardReadingOptionsConfigurationProfiles]];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
#pragma unused(session, screenPoint)
    NSUInteger len = ([rowIndexes lastIndex] + 1) - [rowIndexes firstIndex];
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        [self setObjectRange:NSMakeRange([rowIndexes firstIndex], len)];
        [self setCurrentlyDraggedObjects:[_packagesNetInstallTableViewContents objectsAtIndexes:rowIndexes]];
    }
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
#pragma unused(session, screenPoint, operation)
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        [self setObjectRange:NSMakeRange(0,0)];
        [self setCurrentlyDraggedObjects:nil];
    }
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if ([[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        NSDictionary *itemDict = _packagesNetInstallTableViewContents[(NSUInteger)row];
        return [NSURL fileURLWithPath:itemDict[NBCDictionaryKeyPath]];
    }
    return nil;
}

- (NSDictionary *)pasteboardReadingOptionsPackagesNetInstall {
    return @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
              NSPasteboardURLReadingContentsConformToTypesKey : @[ @"com.apple.installer-package-archive", @"public.shell-script" ] };
}

- (NSDictionary *)pasteboardReadingOptionsConfigurationProfiles {
    return @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
              NSPasteboardURLReadingContentsConformToTypesKey : @[ @"com.apple.mobileconfig" ] };
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        NSDictionary *packageDict = _packagesNetInstallTableViewContents[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"PackageTableColumn"] ) {
            NBCPackageTableCellView *cellView = [tableView makeViewWithIdentifier:@"PackageCellView" owner:self];
            return [self populatePackageCellView:cellView packageDict:packageDict];
        }
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
        NSDictionary *configurationProfileDict = _configurationProfilesTableViewContents[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"ConfigurationProfileTableColumn"] ) {
            NBCConfigurationProfileTableCellView *cellView = [tableView makeViewWithIdentifier:@"ConfigurationProfileCellView" owner:self];
            return [self populateConfigurationProfileCellView:cellView configurationProfileDict:configurationProfileDict];
        }
    }
    
    return nil;
}

- (NBCConfigurationProfileTableCellView *)populateConfigurationProfileCellView:(NBCConfigurationProfileTableCellView *)cellView configurationProfileDict:(NSDictionary *)configurationProfileDict {
    NSMutableAttributedString *configurationProfilePath;
    NSImage *icon;
    NSURL *url = [NSURL fileURLWithPath:configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath]];
    if ( [url checkResourceIsReachableAndReturnError:nil] ) {
        [[cellView textFieldConfigurationProfileName] setStringValue:configurationProfileDict[NBCDictionaryKeyConfigurationProfilePayloadDisplayName]];
        icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
        [[cellView imageViewConfigurationProfileIcon] setImage:icon];
    } else {
        configurationProfilePath = [[NSMutableAttributedString alloc] initWithString:configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath]];
        [configurationProfilePath addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[configurationProfilePath length])];
        [[cellView textFieldConfigurationProfileName] setAttributedStringValue:configurationProfilePath];
    }
    
    return cellView;
}

- (NBCPackageTableCellView *)populatePackageCellView:(NBCPackageTableCellView *)cellView packageDict:(NSDictionary *)packageDict {
    NSMutableAttributedString *packageName;
    NSImage *packageIcon;
    NSURL *packageURL = [NSURL fileURLWithPath:packageDict[NBCDictionaryKeyPath]];
    if ( [packageURL checkResourceIsReachableAndReturnError:nil] ) {
        [[cellView textFieldPackageName] setStringValue:packageDict[NBCDictionaryKeyName]];
        packageIcon = [[NSWorkspace sharedWorkspace] iconForFile:[packageURL path]];
        [[cellView imageViewPackageIcon] setImage:packageIcon];
    } else {
        packageName = [[NSMutableAttributedString alloc] initWithString:packageDict[NBCDictionaryKeyName]];
        [packageName addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[packageName length])];
        [[cellView textFieldPackageName] setAttributedStringValue:packageName];
    }
    
    return cellView;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        return (NSInteger)[_packagesNetInstallTableViewContents count];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
        return (NSInteger)[_configurationProfilesTableViewContents count];
    } else {
        return 0;
    }
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
#pragma unused(row)
    if ( dropOperation == NSTableViewDropAbove ) {
        if ( [info draggingSource] == tableView && ( row < (NSInteger)_objectRange.location || (NSInteger)_objectRange.location+(NSInteger)_objectRange.length < row ) ) {
            return NSDragOperationMove;
        } else {
            if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
                if ( [self containsAcceptablePackageURLsFromPasteboard:[info draggingPasteboard]] ) {
                    [info setAnimatesToDestination:YES];
                    return NSDragOperationCopy;
                }
            } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
                if ( [self containsAcceptableConfigurationProfileURLsFromPasteboard:[info draggingPasteboard]] ) {
                    [info setAnimatesToDestination:YES];
                    return NSDragOperationCopy;
                }
            }
        }
    }
    return NSDragOperationNone;
}

- (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        NSArray *classes = @[ [NBCDesktopPackageEntity class], [NBCDesktopScriptEntity class], [NSPasteboardItem class] ];
        __block NSInteger validCount = 0;
        [draggingInfo enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                             usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                                 if (
                                                     [[draggingItem item] isKindOfClass:[NBCDesktopPackageEntity class]] ||
                                                     [[draggingItem item] isKindOfClass:[NBCDesktopScriptEntity class]]
                                                     ) {
                                                     validCount++;
                                                 }
                                             }];
        [draggingInfo setNumberOfValidItemsForDrop:validCount];
        [draggingInfo setDraggingFormation:NSDraggingFormationList];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
        NSArray *classes = @[ [NBCDesktopConfigurationProfileEntity class], [NSPasteboardItem class] ];
        __block NSInteger validCount = 0;
        [draggingInfo enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                             usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                                 if ( [[draggingItem item] isKindOfClass:[NBCDesktopConfigurationProfileEntity class]] ) {
                                                     validCount++;
                                                 }
                                             }];
        [draggingInfo setNumberOfValidItemsForDrop:validCount];
        [draggingInfo setDraggingFormation:NSDraggingFormationList];
    }
}

- (void)insertConfigurationProfilesInTableView:(NSTableView *)tableView draggingInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[ [NBCDesktopConfigurationProfileEntity class] ];
    __block NSInteger insertionIndex = row;
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                 usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                     NBCDesktopConfigurationProfileEntity *entity = (NBCDesktopConfigurationProfileEntity *)[draggingItem item];
                                     if ( [entity isKindOfClass:[NBCDesktopConfigurationProfileEntity class]] ) {
                                         NSDictionary *configurationProfileDict = [self examineConfigurationProfileAtURL:[entity fileURL]];
                                         if ( [configurationProfileDict count] != 0 ) {
                                             
                                             NSString *path = configurationProfileDict[NBCDictionaryKeyConfigurationProfilePath];
                                             for ( NSDictionary *dict in self->_configurationProfilesTableViewContents ) {
                                                 if ( [path isEqualToString:dict[NBCDictionaryKeyConfigurationProfilePath]] ) {
                                                     DDLogWarn(@"Configuration Profile %@ is already added!", [path lastPathComponent]);
                                                     return;
                                                 }
                                             }
                                             
                                             [self->_configurationProfilesTableViewContents insertObject:configurationProfileDict atIndex:(NSUInteger)insertionIndex];
                                             [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
                                             [draggingItem setDraggingFrame:[tableView frameOfCellAtColumn:0 row:insertionIndex]];
                                             insertionIndex++;
                                             [self->_viewOverlayConfigurationProfiles setHidden:YES];
                                         }
                                     }
                                 }];
}

- (void)reorderItemsInPackagesNetInstallTableView:(NSTableView *)tableView draggingInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[ [NBCDesktopPackageEntity class], [NBCDesktopScriptEntity class] ];
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                 usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop, draggingItem)
                                     NSInteger newIndex = ( row + idx );
                                     NBCDesktopEntity *entity = self->_currentlyDraggedObjects[(NSUInteger)idx];
                                     NSInteger oldIndex = (NSInteger)[self->_packagesNetInstallTableViewContents indexOfObject:entity];
                                     if ( oldIndex < newIndex ) {
                                         newIndex -= ( idx + 1 );
                                     }
                                     [self->_packagesNetInstallTableViewContents removeObjectAtIndex:(NSUInteger)oldIndex];
                                     [self->_packagesNetInstallTableViewContents insertObject:entity atIndex:(NSUInteger)newIndex];
                                     [self->_tableViewPackagesNetInstall moveRowAtIndex:oldIndex toIndex:newIndex];
                                 }];
}

- (void)insertItemInPackagesNetInstallTableView:(NSTableView *)tableView draggingInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[ [NBCDesktopPackageEntity class], [NBCDesktopScriptEntity class] ];
    __block NSInteger insertionIndex = row;
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                 usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                     if ( [[draggingItem item] isKindOfClass:[NBCDesktopPackageEntity class]] ) {
                                         NBCDesktopPackageEntity *entity = (NBCDesktopPackageEntity *)[draggingItem item];
                                         if ( [entity isKindOfClass:[NBCDesktopPackageEntity class]] ) {
                                             NSDictionary *packageDict = [self examinePackageAtURL:[entity fileURL]];
                                             if ( [packageDict count] != 0 ) {
                                                 
                                                 NSString *packagePath = packageDict[NBCDictionaryKeyPath];
                                                 for ( NSDictionary *pkgDict in self->_packagesNetInstallTableViewContents ) {
                                                     if ( [packagePath isEqualToString:pkgDict[NBCDictionaryKeyPath]] ) {
                                                         DDLogWarn(@"Package %@ is already added!", [packagePath lastPathComponent]);
                                                         return;
                                                     }
                                                 }
                                                 
                                                 [self->_packagesNetInstallTableViewContents insertObject:packageDict atIndex:(NSUInteger)insertionIndex];
                                                 [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
                                                 [draggingItem setDraggingFrame:[tableView frameOfCellAtColumn:0 row:insertionIndex]];
                                                 insertionIndex++;
                                                 [self->_viewOverlayPackagesNetInstall setHidden:YES];
                                             }
                                         }
                                     } else if ( [[draggingItem item] isKindOfClass:[NBCDesktopScriptEntity class]] ) {
                                         NBCDesktopScriptEntity *entity = (NBCDesktopScriptEntity *)[draggingItem item];
                                         if ( [entity isKindOfClass:[NBCDesktopScriptEntity class]] ) {
                                             NSDictionary *scriptDict = [self examineScriptAtURL:[entity fileURL]];
                                             if ( [scriptDict count] != 0 ) {
                                                 
                                                 NSString *scriptPath = scriptDict[NBCDictionaryKeyPath];
                                                 for ( NSDictionary *dict in self->_packagesNetInstallTableViewContents ) {
                                                     if ( [scriptPath isEqualToString:dict[NBCDictionaryKeyPath]] ) {
                                                         DDLogWarn(@"Script %@ is already added!", [scriptPath lastPathComponent]);
                                                         return;
                                                     }
                                                 }
                                                 
                                                 [self->_packagesNetInstallTableViewContents insertObject:scriptDict atIndex:(NSUInteger)insertionIndex];
                                                 [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
                                                 [draggingItem setDraggingFrame:[tableView frameOfCellAtColumn:0 row:insertionIndex]];
                                                 insertionIndex++;
                                                 [self->_viewOverlayPackagesNetInstall setHidden:YES];
                                             }
                                         }
                                     }
                                 }];
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
#pragma unused(dropOperation)
    if ( _currentlyDraggedObjects == nil ) {
        if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
            [self insertItemInPackagesNetInstallTableView:_tableViewPackagesNetInstall draggingInfo:info row:row];
        } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
            [self insertConfigurationProfilesInTableView:_tableViewConfigurationProfiles draggingInfo:info row:row];
        }
    } else {
        if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
            [tableView beginUpdates];
            [self reorderItemsInPackagesNetInstallTableView:_tableViewPackagesNetInstall draggingInfo:info row:row];
            [tableView endUpdates];
        } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierConfigurationProfiles] ) {
            //[tableView beginUpdates];
            //[self reorderConfigurationProfilesInTableView:_tableViewConfigurationProfiles draggingInfo:info row:row];
            //[tableView endUpdates];
        }
    }
    return NO;
}

- (IBAction)buttonAddPackageNetInstall:(id)sender {
#pragma unused(sender)
    NSOpenPanel* addPackages = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [addPackages setTitle:@"Add Packages and/or Scripts"];
    [addPackages setPrompt:@"Add"];
    [addPackages setCanChooseFiles:YES];
    [addPackages setAllowedFileTypes:@[ @"com.apple.installer-package-archive", @"public.shell-script" ]];
    [addPackages setCanChooseDirectories:NO];
    [addPackages setCanCreateDirectories:YES];
    [addPackages setAllowsMultipleSelection:YES];
    
    if ( [addPackages runModal] == NSModalResponseOK ) {
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        NSArray* selectedURLs = [addPackages URLs];
        for ( NSURL *url in selectedURLs ) {
            NSError *error;
            NSString *fileType = [[NSWorkspace sharedWorkspace] typeOfFile:[url path] error:&error];
            if ( [workspace type:fileType conformsToType:@"com.apple.installer-package-archive"] ) {
                NSDictionary *packageDict = [self examinePackageAtURL:url];
                if ( [packageDict count] != 0 ) {
                    [self insertItemInPackagesNetInstallTableView:packageDict];
                    return;
                }
            } else if ( [workspace type:fileType conformsToType:@"public.shell-script"] ) {
                NSDictionary *scriptDict = [self examineScriptAtURL:url];
                if ( [scriptDict count] != 0 ) {
                    [self insertItemInPackagesNetInstallTableView:scriptDict];
                    return;
                }
            }
        }
    }
}

- (IBAction)buttonRemovePackageNetInstall:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewPackagesNetInstall selectedRowIndexes];
    [_packagesNetInstallTableViewContents removeObjectsAtIndexes:indexes];
    [_tableViewPackagesNetInstall removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    if ( [_packagesNetInstallTableViewContents count] == 0 ) {
        [_viewOverlayPackagesNetInstall setHidden:NO];
    }
}

@end
