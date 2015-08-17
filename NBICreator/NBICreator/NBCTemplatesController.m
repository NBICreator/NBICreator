//
//  NBCTemplatesController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-16.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCTemplatesController.h"
#import "NBCConstants.h"

#import "NBCImagrSettingsViewController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

enum {
    kTemplateSelectionNew = 100,
    kTemplateSelectionSave,
    kTemplateSelectionSaveAs,
    kTemplateSelectionDelete,
    kTemplateSelectionShowInFinder
};

@interface NBCTemplatesController ()

@end

@implementation NBCTemplatesController

- (id)initWithSettingsViewController:(id)settingsViewController templateType:(NSString *)templateType delegate:(id<NBCTemplatesDelegate>)delegate {
    self = [super initWithWindowNibName:@"NBCTemplatesController"];
    if (self != nil) {
        [self window]; // Loads the nib
        _settingsViewController = settingsViewController;
        _templateType = templateType;
        if ( [_templateType isEqualToString:NBCSettingsTypeImagr] ) {
            _templateDefaultSettings = NBCSettingsTypeImagrDefaultSettings;
        } else if ( [_templateType isEqualToString:NBCSettingsTypeNetInstall] ) {
            _templateDefaultSettings = NBCSettingsTypeNetInstallDefaultSettings;
        } else if ( [_templateType isEqualToString:NBCSettingsTypeDeployStudio] ) {
            _templateDefaultSettings = NBCSettingsTypeDeployStudioDefaultSettings;
        }
        
        _delegate = delegate;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsaved] ) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save
            [_settingsViewController saveUISettingsWithName:selectedTemplate atUrl:[_settingsViewController templatesDict][selectedTemplate]];
            [self addUntitledTemplate];
            return;
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Discard
            [self addUntitledTemplate];
            return;
        } else {                                                // Cancel
            [_popUpButton selectItemWithTitle:selectedTemplate];
            return;
        }
    } else if ( [alertTag isEqualToString:NBCAlertTagDeleteTemplate] ) {
        
        if ( returnCode == NSAlertSecondButtonReturn ) {        // Delete
            NSURL *templateURL = alertInfo[NBCAlertUserInfoTemplateURL];
            [self deleteTemplateAtURL:templateURL];
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    
    if ( [menuItem tag] == kTemplateSelectionSave || [[menuItem title] isEqualToString:@"Save…"] ) {
        // -------------------------------------------------------------------------
        //  Don't allow "Save" until template has been saved once with "Save As..."
        // -------------------------------------------------------------------------
        if ( [[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled] ) {
            retval = NO;
        }
        
        // ------------------------------------------------------------------------------------
        //  If no setting have changed between current UI and the saved plist, no need to save
        // ------------------------------------------------------------------------------------
        BOOL settingsChanged = [_settingsViewController haveSettingsChanged];
        if ( ! settingsChanged ) {
            retval = NO;
        }
        
        return retval;
    } else if ( [menuItem tag] == kTemplateSelectionShowInFinder || [[menuItem title] isEqualToString:@"Show in Finder…"] ) {
        // --------------------------------------------------------------------
        //  If template have not been saved yet, can't show it in finder either
        // --------------------------------------------------------------------
        if ( [[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled] ) {
            retval = NO;
        }
        
        return retval;
    } else if ( [menuItem tag] == kTemplateSelectionDelete || [[menuItem title] isEqualToString:@"Delete"] ) {
        if ( [[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled] ) {
            retval = NO;
        }
    }
    
    return retval;
}

- (void)deleteTemplateAtURL:(NSURL *)templateURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ( [fm trashItemAtURL:templateURL resultingItemURL:nil error:&error] ) {
        [self updateTemplateListForPopUpButton:_popUpButton title:nil];
    } else {
        NSLog(@"Could not move %@ to the trash", templateURL);
        NSLog(@"Error: %@", error);
    }
}

- (void)controlTextDidChange:(NSNotification *)sender {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -----------------------------------------------------------------------
    //  Don't allow empty template names or names that are already being used
    // -----------------------------------------------------------------------
    if ( [sender object] == _textFieldSheetSaveAsName ) {
        if ( [[_textFieldSheetSaveAsName stringValue] length] == 0 || [[_popUpButton itemTitles] containsObject:[_textFieldSheetSaveAsName stringValue]] ) {
            [_buttonSheetSaveAsSaveAs setEnabled:NO];
        } else {
            [_buttonSheetSaveAsSaveAs setEnabled:YES];
        }
    }
    
    if ( [sender object] == _textFieldSheetSaveUntitledName ) {
        if ( [[_textFieldSheetSaveUntitledName stringValue] length] == 0 ) {
            [_buttonSheetSaveUntitledSaveAs setEnabled:NO];
        } else {
            [_buttonSheetSaveUntitledSaveAs setEnabled:YES];
        }
    }
}

- (void)disableTemplateAtURL:(NSURL *)templateURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    NSURL *templatesDisabledFolderURL;
    if ( userApplicationSupport ) {
        templatesDisabledFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesDisabled isDirectory:YES];
    } else {
        NSLog(@"Could not find user Application Support Folder");
        NSLog(@"Error: %@", error);
        return;
    }
    
    if ( ! [templatesDisabledFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [fm createDirectoryAtURL:templatesDisabledFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Could not create disabled directory!");
            return;
        }
    }
    
    NSURL *templateTargetURL = [templatesDisabledFolderURL URLByAppendingPathComponent:[templateURL lastPathComponent]];
    if ( ! [fm moveItemAtURL:templateURL toURL:templateTargetURL error:&error] ) {
        NSLog(@"Could not move template to disabled directory!");
    }
}

- (void)updateTemplateListForPopUpButton:(NSPopUpButton *)popUpButton title:(NSString *)title {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( ! _popUpButton ) {
        _popUpButton = popUpButton;
    }
    
    if ( popUpButton ) {
        [popUpButton removeAllItems];
    }
    
    // -------------------------------------------------------------
    //  Add new template with passed title at the top of template list.
    // -------------------------------------------------------------
    if ( title != nil ) {
        [popUpButton addItemWithTitle:title];
    }
    
    // -------------------------------------------------------------
    //  Add all templates from templates folder
    // -------------------------------------------------------------
    NSError *error;
    BOOL userTemplateFolderExists = NO;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSMutableArray *templates = [[NSMutableArray alloc] init];
    NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];
    
    if ( [[_settingsViewController templatesFolderURL] checkResourceIsReachableAndReturnError:nil] ) {
        userTemplateFolderExists = YES;
        NSArray *contents = [fm contentsOfDirectoryAtURL:[_settingsViewController templatesFolderURL]
                              includingPropertiesForKeys:@[]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:nil];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == 'nbic'"];
        for ( NSURL *fileURL in [contents filteredArrayUsingPredicate:predicate] ) {
            NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfURL:fileURL];
            
            NSString *templateType = dict[NBCSettingsTypeKey];
            if ( [templateType isEqualToString:_templateType] ) {
                NSString *templateName = dict[NBCSettingsNameKey];
                if ( [templateName isEqualToString:NBCMenuItemUntitled] ) {
                    [self disableTemplateAtURL:fileURL];
                } else {
                    [templates addObject:templateName];
                    [[_settingsViewController templatesDict] setValue:fileURL forKey:templateName];
                }
            }
        }
        
        if ( [templates count] == 0 ) {
            if ( [title length] == 0 ) {
                if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
                    NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
                    if ( defaultSettingsDict ) {
                        [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
                    }
                } else {
                    NSLog(@"Could not find default settings file");
                    NSLog(@"Error: %@", error);
                }
                [popUpButton addItemWithTitle:NBCMenuItemUntitled];
            }
        } else {
            [popUpButton addItemsWithTitles:templates];
        }
    } else {
        if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
            NSDictionary *defaultSettingsDict=[NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
            if ( defaultSettingsDict ) {
                [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
            }
        } else {
            NSLog(@"Could not find default settings file");
            NSLog(@"Error: %@", error);
        }
        [popUpButton addItemWithTitle:NBCMenuItemUntitled];
    }
    
    // -------------------------------------------------------------
    //  Add all static menu items
    // -------------------------------------------------------------
    [[popUpButton menu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItemNew = [[NSMenuItem alloc] initWithTitle:NBCMenuItemNew action:@selector(menuItemNew:) keyEquivalent:@"n"];
    [menuItemNew setKeyEquivalentModifierMask:NSCommandKeyMask];
    [menuItemNew setTag:kTemplateSelectionNew];
    [menuItemNew setTarget:self];
    [[popUpButton menu] addItem:menuItemNew];
    
    NSMenuItem *menuItemSave = [[NSMenuItem alloc] initWithTitle:NBCMenuItemSave action:@selector(menuItemSave:) keyEquivalent:@"s"];
    [menuItemSave setKeyEquivalentModifierMask:NSCommandKeyMask];
    [menuItemSave setTag:kTemplateSelectionSave];
    [menuItemSave setTarget:self];
    [[popUpButton menu] addItem:menuItemSave];
    
    NSMenuItem *menuItemSaveAs = [[NSMenuItem alloc] initWithTitle:NBCMenuItemSaveAs action:@selector(menuItemSaveAs:) keyEquivalent:@"S"];
    [menuItemSaveAs setTag:kTemplateSelectionSaveAs];
    [menuItemSaveAs setTarget:self];
    [[popUpButton menu] addItem:menuItemSaveAs];
    
    [[popUpButton menu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItemDelete = [[NSMenuItem alloc] initWithTitle:NBCMenuItemDelete action:@selector(menuItemDelete:) keyEquivalent:@""];
    [menuItemDelete setTag:kTemplateSelectionDelete];
    [menuItemDelete setTarget:self];
    [[popUpButton menu] addItem:menuItemDelete];
    
    [[popUpButton menu] addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *menuItemShowInFinder = [[NSMenuItem alloc] initWithTitle:NBCMenuItemShowInFinder action:@selector(menuItemShowInFinder:) keyEquivalent:@""];
    [menuItemShowInFinder setTag:kTemplateSelectionShowInFinder];
    [menuItemShowInFinder setTarget:self];
    [[popUpButton menu] addItem:menuItemShowInFinder];
    
    // -------------------------------------------------------------
    //  Update settings from the selected template
    // -------------------------------------------------------------
    NSString *selectedTemplate = [popUpButton titleOfSelectedItem];
    [_settingsViewController setSelectedTemplate:selectedTemplate];
    
    if ( ! [selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        NSURL *selectionURL = [_settingsViewController templatesDict][selectedTemplate];
        if ( selectionURL ) {
            [_settingsViewController updateUISettingsFromURL:selectionURL];
        }
    }
}

- (void)addUntitledTemplate {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_popUpButton insertItemWithTitle:NBCMenuItemUntitled atIndex:0];
    [_popUpButton selectItemWithTitle:NBCMenuItemUntitled];
    [_settingsViewController setSelectedTemplate:NBCMenuItemUntitled];
    
    NSError *error;
    NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];
    
    if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
        if ( defaultSettingsDict ) {
            [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
        } else {
            NSLog(@"Error while reading default template file for %@!", _templateType);
        }
    } else {
        NSLog(@"Could not find default template file for %@!", _templateType);
        NSLog(@"Error: %@", error);
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MenuItem Actions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)menuItemNew:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL settingsChanged = [_settingsViewController haveSettingsChanged];
    
    // -----------------------------------------------------------------------
    //  Display save sheets if there currently are any unsaved settings
    // -----------------------------------------------------------------------
    if ( settingsChanged ) {
        NSString *selectedTemplate = [_settingsViewController selectedTemplate];
        
        // -----------------------------------------------------------------------
        //  If current template has never been saved, offer to save it
        // -----------------------------------------------------------------------
        if ( [selectedTemplate isEqualTo:NBCMenuItemUntitled] ) {
            [_textFieldSheetSaveUntitledName setStringValue:@""];
            [[NSApp mainWindow] beginSheet:_sheetSaveUntitled completionHandler:^(NSModalResponse returnCode) {
                if ( returnCode == NSModalResponseOK ) {               // OK
                    [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveUntitledName stringValue] atUrl:nil];
                } else if ( returnCode == NSModalResponseCancel ) {    // CANCEL
                    [self->_popUpButton selectItemWithTitle:[self->_settingsViewController selectedTemplate]];
                    return;
                }
                [self addUntitledTemplate];
            }];
        } else {
            NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
            NSDictionary *alertInfo = @{
                                        NBCAlertTagKey : NBCAlertTagSettingsUnsaved,
                                        NBCAlertUserInfoSelectedTemplate : selectedTemplate
                                        };
            
            [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?"
                                  alertInfo:alertInfo];
        }
    } else {
        [_popUpButton insertItemWithTitle:NBCMenuItemUntitled atIndex:0];
        [_popUpButton selectItemWithTitle:NBCMenuItemUntitled];
        [_settingsViewController setSelectedTemplate:NBCMenuItemUntitled];
        NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];
        NSError *error;
        if ( [defaultSettingsPath checkResourceIsReachableAndReturnError:&error] ) {
            NSDictionary *defaultSettingsDict=[NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
            if ( defaultSettingsDict ) {
                [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
            }
        } else {
            NSLog(@"Could not find default settings file");
            NSLog(@"Error: %@", error);
        }
    }
} // menuItemNew

- (void)menuItemSave:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][[_settingsViewController selectedTemplate]];
    [_settingsViewController saveUISettingsWithName:[_settingsViewController selectedTemplate] atUrl:currentTemplateURL];
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
} // menuItemSave

- (void)menuItemSaveAs:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self showSheetSaveAs];
} // menuItemSaveAs

- (void)menuItemShowInFinder:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][[_settingsViewController selectedTemplate]];
    if ( currentTemplateURL ) {
        NSArray *currentTemplateURLArray = @[ currentTemplateURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:currentTemplateURLArray];
        [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    }
} // menuItemShowInFinder

- (void)menuItemDelete:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *currentTemplateName = [_settingsViewController selectedTemplate];
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][currentTemplateName];
    if ( [currentTemplateURL checkResourceIsReachableAndReturnError:nil] ) {
        NSDictionary *alertInfo = @{
                                    NBCAlertTagKey : NBCAlertTagDeleteTemplate,
                                    NBCAlertUserInfoTemplateURL : currentTemplateURL
                                    };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertDeleteTemplate:[NSString stringWithFormat:@"Are you sure you want to delete the template %@?", currentTemplateName] templateName:currentTemplateName alertInfo:alertInfo];
    }
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Sheets
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)showSheetSaveUntitled:(NSString *)senderTitle buildNBI:(BOOL)buildNBI {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_textFieldSheetSaveUntitledName setStringValue:@""];
    [[NSApp mainWindow] beginSheet:_sheetSaveUntitled completionHandler:^(NSModalResponse returnCode) {
        if ( returnCode == NSModalResponseOK ) {
            [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveUntitledName stringValue] atUrl:nil];
            if ( buildNBI ) {
                [self->_settingsViewController verifySettings];
            }
        } else if ( returnCode == NSModalResponseContinue ) {
            [self->_settingsViewController setSelectedTemplate:senderTitle];
            [self->_settingsViewController updateUISettingsFromURL:[self->_settingsViewController templatesDict][[self->_settingsViewController selectedTemplate]]];
            [self->_settingsViewController expandVariablesForCurrentSettings];
            if ( buildNBI ) {
                [self->_settingsViewController verifySettings];
            }
        }
    }];
} // showSheetSaveUntitled

- (void)showSheetSaveAs {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_textFieldSheetSaveAsName setStringValue:@""];
    [[NSApp mainWindow] beginSheet:_sheetSaveAs completionHandler:^(NSModalResponse returnCode) {
        if ( returnCode == NSModalResponseOK ) {
            [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveAsName stringValue] atUrl:nil];
        }
    }];
} // showSheetSaveAs

- (IBAction)buttonSheetSaveAsCancel:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    [[NSApp mainWindow] endSheet:_sheetSaveAs returnCode:NSModalResponseCancel];
} // buttonSheetCancel

- (IBAction)buttonSheetSaveAsSaveAs:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *newName = [_textFieldSheetSaveAsName stringValue];
    [_popUpButton insertItemWithTitle:newName atIndex:0];
    [_popUpButton selectItemWithTitle:newName];
    if ( [[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled] ) {
        [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
        NSInteger indexSave = [_popUpButton indexOfItemWithTag:kTemplateSelectionSave];
        [[_popUpButton itemAtIndex:indexSave] setEnabled:YES];
        NSInteger indexShowInFinder = [_popUpButton indexOfItemWithTag:kTemplateSelectionShowInFinder];
        [[_popUpButton itemAtIndex:indexShowInFinder] setEnabled:YES];
    }
    [_settingsViewController setSelectedTemplate:newName];
    [[NSApp mainWindow] endSheet:_sheetSaveAs returnCode:NSModalResponseOK];
} // buttonSheetSave

- (IBAction)buttonSheetSaveUntitledCancel:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseCancel];
} // buttonSaveUntitledCancel

- (IBAction)buttonSheetSaveUntitledSaveAs:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *newName = [_textFieldSheetSaveUntitledName stringValue];
    [_popUpButton insertItemWithTitle:newName atIndex:0];
    [_popUpButton selectItemWithTitle:newName];
    if ( [[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled] ) {
        [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
        NSInteger indexSave = [_popUpButton indexOfItemWithTag:kTemplateSelectionSave];
        [[_popUpButton itemAtIndex:indexSave] setEnabled:YES];
        NSInteger indexShowInFinder = [_popUpButton indexOfItemWithTag:kTemplateSelectionShowInFinder];
        [[_popUpButton itemAtIndex:indexShowInFinder] setEnabled:YES];
    }
    [_settingsViewController setSelectedTemplate:newName];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseOK];
} // buttonSaveUntitledSave

- (IBAction)buttonSheetSaveUntitledDelete:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseContinue];
} // buttonSaveUntitledDelete

@end
