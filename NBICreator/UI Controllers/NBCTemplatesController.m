//
//  NBCTemplatesController.m
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

#import "NBCConstants.h"
#import "NBCTemplatesController.h"
#import "NBCController.h"

#import "NBCImagrSettingsViewController.h"
#import "NBCLog.h"

enum { kTemplateSelectionNew = 100, kTemplateSelectionSave, kTemplateSelectionSaveAs, kTemplateSelectionExport, kTemplateSelectionRename, kTemplateSelectionDelete, kTemplateSelectionShowInFinder };

@interface NBCTemplatesController ()

@end

@implementation NBCTemplatesController

- (id)init {
    self = [super initWithWindowNibName:@"NBCTemplatesController"];
    if (self != nil) {
        [self window]; // Loads the nib
    }
    return self;
} // init

- (id)initWithSettingsViewController:(id)settingsViewController templateType:(NSString *)templateType delegate:(id<NBCTemplatesDelegate>)delegate {
    self = [super initWithWindowNibName:@"NBCTemplatesController"];
    if (self != nil) {
        [self window]; // Loads the nib
        _settingsViewController = settingsViewController;
        _templateType = templateType;
        if ([_templateType isEqualToString:NBCSettingsTypeImagr]) {
            _templateDefaultSettings = NBCFileNameImagrDefaults;
        } else if ([_templateType isEqualToString:NBCSettingsTypeNetInstall]) {
            _templateDefaultSettings = NBCFileNameNetInstallDefaults;
        } else if ([_templateType isEqualToString:NBCSettingsTypeDeployStudio]) {
            _templateDefaultSettings = NBCFileNameDeployStudioDefaults;
        } else if ([_templateType isEqualToString:NBCSettingsTypeCasper]) {
            _templateDefaultSettings = NBCFileNameCasperDefaults;
        } else {
            DDLogWarn(@"[WARN] Unknown templatey type: %@", templateType);
        }

        _delegate = delegate;
    }
    return self;
} // initWithSettingsViewController:templateType:delegate

- (void)windowDidLoad {
    [super windowDidLoad];
} // windowDidLoad

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    NSString *alertTag = alertInfo[NBCAlertTagKey];

    if ([alertTag isEqualToString:NBCAlertTagSettingsUnsaved]) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        if (returnCode == NSAlertFirstButtonReturn) { // Save
            [_settingsViewController saveUISettingsWithName:selectedTemplate atUrl:[_settingsViewController templatesDict][selectedTemplate]];
            [self addUntitledTemplate];
            return;
        } else if (returnCode == NSAlertSecondButtonReturn) { // Discard
            [self addUntitledTemplate];
            return;
        } else { // Cancel
            [_popUpButton selectItemWithTitle:selectedTemplate];
            return;
        }
    } else if ([alertTag isEqualToString:NBCAlertTagDeleteTemplate]) {
        if (returnCode == NSAlertSecondButtonReturn) { // Delete
            NSURL *templateURL = alertInfo[NBCAlertUserInfoTemplateURL];
            if ([templateURL checkResourceIsReachableAndReturnError:nil]) {
                [self deleteTemplateAtURL:templateURL updateTemplateList:YES];
            }
        }
    }
} // alertReturnCode:alertInfo

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {

    BOOL retval = YES;

    if ([menuItem tag] == kTemplateSelectionSave || [[menuItem title] isEqualToString:NBCMenuItemSave]) {
        // -------------------------------------------------------------------------
        //  Don't allow "Save" until template has been saved once with "Save As..."
        // -------------------------------------------------------------------------
        if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
            retval = NO;
        }

        // ------------------------------------------------------------------------------------
        //  If no setting have changed between current UI and the saved plist, no need to save
        // ------------------------------------------------------------------------------------
        BOOL settingsChanged = [_settingsViewController haveSettingsChanged];
        if (!settingsChanged) {
            retval = NO;
        }

        return retval;
    } else if ([menuItem tag] == kTemplateSelectionShowInFinder || [[menuItem title] isEqualToString:NBCMenuItemShowInFinder]) {

        // --------------------------------------------------------------------
        //  If template have not been saved yet, can't show it in finder either
        // --------------------------------------------------------------------
        if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
            retval = NO;
        }

        return retval;
    } else if ([menuItem tag] == kTemplateSelectionRename || [[menuItem title] isEqualToString:NBCMenuItemRename]) {
        if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
            return NO;
        }
    } else if ([menuItem tag] == kTemplateSelectionDelete || [[menuItem title] isEqualToString:NBCMenuItemDelete]) {
        if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
            retval = NO;
        }
    }

    return retval;
} // validateMenuItem

- (void)deleteTemplateAtURL:(NSURL *)templateURL updateTemplateList:(BOOL)update {
    DDLogInfo(@"Deleting template: %@", [templateURL lastPathComponent]);
    NSError *error;
    if ([[NSFileManager defaultManager] trashItemAtURL:templateURL resultingItemURL:nil error:&error]) {
        if (update) {
            [self updateTemplateListForPopUpButton:_popUpButton title:nil];
        }
    } else {
        DDLogError(@"[ERROR] Could not move %@ to the trash", templateURL);
        DDLogError(@"[ERROR] %@", error);
    }
} // deleteTemplateAtURL:updateTemplateList

- (void)controlTextDidChange:(NSNotification *)sender {

    BOOL enableButton = YES;
    NSString *inputText = [[[sender userInfo] valueForKey:@"NSFieldEditor"] string];

    // -----------------------------------------------------------------------
    //  Don't allow empty template names or names that are already being used
    // -----------------------------------------------------------------------
    if ([inputText length] == 0 || [[_popUpButton itemTitles] containsObject:inputText] || [inputText isEqualToString:@"Untitled"]) {
        enableButton = NO;
    }

    if ([sender object] == _textFieldSheetSaveAsName) {
        [_buttonSheetSaveAsSaveAs setEnabled:enableButton];
    };
    if ([sender object] == _textFieldSheetRenameName) {
        [_buttonSheetRenameRename setEnabled:enableButton];
    };
    if ([sender object] == _textFieldSheetRenameImportTemplate) {
        [_buttonSheetRenameImportTemplateImport setEnabled:enableButton];
    };
    if ([sender object] == _textFieldSheetSaveUntitledName) {
        [_buttonSheetSaveUntitledSaveAs setEnabled:enableButton];
    };
} // controlTextDidChange

- (void)disableTemplateAtURL:(NSURL *)templateURL {

    DDLogError(@"[ERROR] Disabling template: %@", [templateURL lastPathComponent]);

    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    NSURL *templatesDisabledFolderURL;
    if ([userApplicationSupport checkResourceIsReachableAndReturnError:&error]) {
        templatesDisabledFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesDisabled isDirectory:YES];
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        return;
    }

    if (![templatesDisabledFolderURL checkResourceIsReachableAndReturnError:nil]) {
        if (![fm createDirectoryAtURL:templatesDisabledFolderURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogError(@"[ERROR] Could not create directory for disabled templates!");
            return;
        }
    }

    NSURL *templateTargetURL = [templatesDisabledFolderURL URLByAppendingPathComponent:[templateURL lastPathComponent]];
    if (![fm moveItemAtURL:templateURL toURL:templateTargetURL error:&error]) {
        DDLogError(@"[ERROR] Could not move template to disabled directory!");
    }
} // disableTemplateAtURL

- (void)updateTemplateListForPopUpButton:(NSPopUpButton *)popUpButton title:(NSString *)title {

    DDLogDebug(@"[DEBUG] Updating template list...");

    if (!_popUpButton) {
        _popUpButton = popUpButton;
    }

    if (_popUpButton) {
        [_popUpButton removeAllItems];
    }

    // -------------------------------------------------------------
    //  Add new template with passed title at the top of template list.
    // -------------------------------------------------------------
    if ([title length] != 0) {
        DDLogDebug(@"[DEBUG] Adding template with name: %@", title);
        [_popUpButton addItemWithTitle:title];
    }

    // -------------------------------------------------------------
    //  Add all templates from templates folder
    // -------------------------------------------------------------
    NSError *error;
    BOOL userTemplateFolderExists = NO;
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSMutableArray *templates = [[NSMutableArray alloc] init];

    NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];
    DDLogDebug(@"[DEBUG] Default template for workflow path: %@", defaultSettingsPath);
    DDLogDebug(@"[DEBUG] Templates folder for workflow path: %@", [[_settingsViewController templatesFolderURL] path]);
    if ([[_settingsViewController templatesFolderURL] checkResourceIsReachableAndReturnError:nil]) {
        userTemplateFolderExists = YES;

        /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
         //// Code to rename all existing template files with the old nbic extension to the new extension nbictemplate ///
         ///////////////////////////////////////////////////////////////////////////////////////////////////////////////*/
        NSArray *contents = [fm contentsOfDirectoryAtURL:[_settingsViewController templatesFolderURL] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

        NSPredicate *predicateNbic = [NSPredicate predicateWithFormat:@"pathExtension == 'nbic'"];
        for (NSURL *fileURL in [contents filteredArrayUsingPredicate:predicateNbic]) {
            if (![fm moveItemAtURL:fileURL toURL:[[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"nbictemplate"] error:&error]) {
                DDLogError(@"[ERROR] Renaming file %@ failed!", [fileURL lastPathComponent]);
                DDLogError(@"[ERROR] %@", error);
            }
        }
        /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

        contents = [fm contentsOfDirectoryAtURL:[_settingsViewController templatesFolderURL] includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

        NSPredicate *predicateNbictemplate = [NSPredicate predicateWithFormat:@"pathExtension == 'nbictemplate'"];
        for (NSURL *fileURL in [contents filteredArrayUsingPredicate:predicateNbictemplate]) {
            NSDictionary *templateDict = [[NSDictionary alloc] initWithContentsOfURL:fileURL];
            if ([templateDict count] != 0) {
                NSString *templateType = templateDict[NBCSettingsTypeKey];
                if ([templateType isEqualToString:_templateType]) {
                    NSString *templateName = templateDict[NBCSettingsTitleKey];
                    /*//////////////////////////////////////////////////////////
                     /// TEMPORARY FIX WHILE CHANGING WORKFLOW NAME -> TITLE ///
                     /////////////////////////////////////////////////////////*/
                    if (templateName == nil) {
                        templateName = templateDict[@"Name"];
                        NSMutableDictionary *newTemplateDict = [NSMutableDictionary dictionaryWithDictionary:[templateDict copy]];
                        [newTemplateDict removeObjectForKey:@"Name"];
                        newTemplateDict[NBCSettingsTitleKey] = templateName;
                        [newTemplateDict writeToURL:fileURL atomically:YES];
                    }
                    /* ------------------------------------------------------ */
                    if ([templateName isEqualToString:NBCMenuItemUntitled]) {
                        [self disableTemplateAtURL:fileURL];
                    } else {
                        DDLogDebug(@"[DEBUG] Adding template with name: %@", templateName);
                        [templates addObject:templateName];
                        [[_settingsViewController templatesDict] setValue:fileURL forKey:templateName];
                    }
                } else {
                    DDLogDebug(@"Template not correct type!");
                    DDLogDebug(@"_templateType=%@", _templateType);
                }
            } else {
                DDLogError(@"[ERROR] Could not read template: %@", [fileURL path]);
            }
        }

        if ([templates count] == 0) {
            if ([title length] == 0) {
                if ([defaultSettingsPath checkResourceIsReachableAndReturnError:&error]) {
                    NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
                    if ([defaultSettingsDict count] != 0) {
                        [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
                    }
                } else {
                    DDLogError(@"[ERROR] Could not find default settings file!");
                    DDLogError(@"[ERROR] %@", error);
                }
                [popUpButton addItemWithTitle:NBCMenuItemUntitled];
            }
        } else {
            [popUpButton addItemsWithTitles:templates];
        }
    } else {
        DDLogDebug(@"[DEBUG] Templates folder does NOT exist!");
        if ([defaultSettingsPath checkResourceIsReachableAndReturnError:&error]) {
            NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
            if (defaultSettingsDict) {
                [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
            }
        } else {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }

        DDLogDebug(@"[DEBUG] Adding template");
        [popUpButton addItemWithTitle:NBCMenuItemUntitled];
    }

    // -------------------------------------------------------------
    //  Add all static menu items
    // -------------------------------------------------------------
    DDLogDebug(@"[DEBUG] Adding static template menu items...");
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

    NSMenuItem *menuItemRename = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRename action:@selector(menuItemRename:) keyEquivalent:@""];
    [menuItemRename setTag:kTemplateSelectionRename];
    [menuItemRename setTarget:self];
    [[popUpButton menu] addItem:menuItemRename];

    [[popUpButton menu] addItem:[NSMenuItem separatorItem]];

    NSMenuItem *menuItemExport = [[NSMenuItem alloc] initWithTitle:NBCMenuItemExport action:@selector(menuItemExport:) keyEquivalent:@""];
    [menuItemExport setTag:kTemplateSelectionExport];
    [menuItemExport setTarget:self];
    [[popUpButton menu] addItem:menuItemExport];

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
    DDLogDebug(@"[DEBUG] Selected template name is: %@", selectedTemplate);
    [_settingsViewController setSelectedTemplate:selectedTemplate];

    if (![selectedTemplate isEqualToString:NBCMenuItemUntitled]) {
        NSURL *selectionURL = [_settingsViewController templatesDict][selectedTemplate];
        DDLogDebug(@"[DEBUG] Selected template path is: %@", [selectionURL path]);
        if ([selectionURL checkResourceIsReachableAndReturnError:&error]) {
            [_settingsViewController updateUISettingsFromURL:selectionURL];
        } else {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
} // updateTemplateListForPopUpButton:title

+ (NSURL *)templatesFolderForType:(NSString *)type {

    NSError *error = nil;
    NSURL *userApplicationSupport = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if (![userApplicationSupport checkResourceIsReachableAndReturnError:&error]) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        return nil;
    }

    if ([type isEqualToString:NBCSettingsTypeNetInstall]) {
        return [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesNetInstall isDirectory:YES];
    } else if ([type isEqualToString:NBCSettingsTypeDeployStudio]) {
        return [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesDeployStudio isDirectory:YES];
    } else if ([type isEqualToString:NBCSettingsTypeImagr]) {
        return [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesImagr isDirectory:YES];
    } else if ([type isEqualToString:NBCSettingsTypeCasper]) {
        return [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesCasper isDirectory:YES];
    } else {
        DDLogError(@"[ERROR] Unknown template type: %@", type);
        return nil;
    }
} // templatesFolderForType

+ (BOOL)templateNameAlreadyExist:(NSURL *)templateURL {

    DDLogDebug(@"[DEBUG] Checking if template is a duplicate...");

    BOOL retval = NO;

    NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
    if ([templateDict count] == 0) {
        DDLogError(@"[ERROR] Could not read template: %@", [templateURL path]);
        return NO;
    }

    NSURL *templatesFolderURL = [self templatesFolderForType:templateDict[NBCSettingsTypeKey]];
    DDLogDebug(@"[DEBUG] Template folder path: %@", [templatesFolderURL path]);
    if (![templatesFolderURL checkResourceIsReachableAndReturnError:nil]) {
        return NO;
    }

    NSString *templateName = templateDict[NBCSettingsTitleKey];

    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:templatesFolderURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == 'nbictemplate'"];
    for (NSURL *fileURL in [contents filteredArrayUsingPredicate:predicate]) {
        NSDictionary *currentTemplateDict = [[NSDictionary alloc] initWithContentsOfURL:fileURL];
        if ([currentTemplateDict count] != 0) {
            if ([templateName isEqualToString:currentTemplateDict[NBCSettingsTitleKey]]) {
                retval = YES;
                break;
            }
        }
    }

    return retval;

} // templateNameAlreadyExist

+ (BOOL)templateIsDuplicate:(NSURL *)templateURL {

    DDLogDebug(@"[DEBUG] Checking if template is a duplicate...");

    BOOL retval = NO;

    NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
    if ([templateDict count] == 0) {
        DDLogError(@"[ERROR] Could not read template: %@", [templateURL path]);
        return NO;
    }

    NSURL *templatesFolderURL = [self templatesFolderForType:templateDict[NBCSettingsTypeKey]];
    DDLogDebug(@"[DEBUG] Template folder path: %@", [templatesFolderURL path]);
    if (![templatesFolderURL checkResourceIsReachableAndReturnError:nil]) {
        return NO;
    }

    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:templatesFolderURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == 'nbictemplate'"];
    for (NSURL *fileURL in [contents filteredArrayUsingPredicate:predicate]) {
        NSDictionary *currentTemplateDict = [[NSDictionary alloc] initWithContentsOfURL:fileURL];
        if ([currentTemplateDict count] != 0) {
            if ([currentTemplateDict isEqualToDictionary:templateDict]) {
                retval = YES;
                break;
            }
        }
    }

    return retval;
} // templateIsDuplicate

- (void)addUntitledTemplate {
    [_popUpButton insertItemWithTitle:NBCMenuItemUntitled atIndex:0];
    [_popUpButton selectItemWithTitle:NBCMenuItemUntitled];
    [_settingsViewController setSelectedTemplate:NBCMenuItemUntitled];

    NSError *error;
    NSURL *defaultTemplateURL = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];

    if ([defaultTemplateURL checkResourceIsReachableAndReturnError:&error]) {
        NSDictionary *defaultTemplateDict = [NSDictionary dictionaryWithContentsOfURL:defaultTemplateURL];
        if ([defaultTemplateDict count] != 0) {
            [_settingsViewController updateUISettingsFromDict:defaultTemplateDict];
        } else {
            DDLogError(@"[ERROR] Template at path: %@ could not be opened", [defaultTemplateURL path]);
        }
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }
} // addUntitledTemplate

+ (NSDictionary *)templateInfoFromTemplateAtURL:(NSURL *)templateURL error:(NSError **)__unused error {
    NSMutableDictionary *templateInfoDict = [[NSMutableDictionary alloc] init];
    NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfURL:templateURL];
    if ([templateDict count] != 0) {
        NSString *name = templateDict[NBCSettingsTitleKey];
        if ([name length] != 0) {
            templateInfoDict[NBCSettingsTitleKey] = name;
        }
        NSString *type = templateDict[NBCSettingsTypeKey];
        if ([type length] != 0) {
            templateInfoDict[NBCSettingsTypeKey] = type;
        }
        NSString *version = templateDict[NBCSettingsVersionKey];
        if ([version length] != 0) {
            templateInfoDict[NBCSettingsVersionKey] = version;
        }
        return [templateInfoDict copy];
    } else {
        DDLogError(@"[ERROR] Template at path: %@ could not be opened", [templateURL path]);
        return nil;
    }
} // templateInfoFromTemplateAtURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark MenuItem Actions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)menuItemNew:(NSNotification *)__unused notification {
    BOOL settingsChanged = [_settingsViewController haveSettingsChanged];

    // -----------------------------------------------------------------------
    //  Display save sheets if there currently are any unsaved settings
    // -----------------------------------------------------------------------
    if (settingsChanged) {
        NSString *selectedTemplate = [_settingsViewController selectedTemplate];

        // -----------------------------------------------------------------------
        //  If current template has never been saved, offer to save it
        // -----------------------------------------------------------------------
        if ([selectedTemplate isEqualTo:NBCMenuItemUntitled]) {
            [_textFieldSheetSaveUntitledName setStringValue:@""];
            [[NSApp mainWindow] beginSheet:_sheetSaveUntitled
                         completionHandler:^(NSModalResponse returnCode) {
                           if (returnCode == NSModalResponseOK) { // OK
                               [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveUntitledName stringValue] atUrl:nil];
                           } else if (returnCode == NSModalResponseCancel) { // CANCEL
                               [self->_popUpButton selectItemWithTitle:[self->_settingsViewController selectedTemplate]];
                               return;
                           }
                           [self addUntitledTemplate];
                         }];
        } else {
            NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
            NSDictionary *alertInfo = @{NBCAlertTagKey : NBCAlertTagSettingsUnsaved, NBCAlertUserInfoSelectedTemplate : selectedTemplate};

            [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?" alertInfo:alertInfo];
        }
    } else {
        [_popUpButton insertItemWithTitle:NBCMenuItemUntitled atIndex:0];
        [_popUpButton selectItemWithTitle:NBCMenuItemUntitled];
        [_settingsViewController setSelectedTemplate:NBCMenuItemUntitled];
        NSURL *defaultSettingsPath = [[NSBundle mainBundle] URLForResource:_templateDefaultSettings withExtension:@"plist"];
        NSError *error;
        if ([defaultSettingsPath checkResourceIsReachableAndReturnError:&error]) {
            NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsPath];
            if (defaultSettingsDict) {
                [_settingsViewController updateUISettingsFromDict:defaultSettingsDict];
            }
        } else {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    }
} // menuItemNew

- (void)menuItemSave:(NSNotification *)__unused notification {
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][[_settingsViewController selectedTemplate]];
    [_settingsViewController saveUISettingsWithName:[_settingsViewController selectedTemplate] atUrl:currentTemplateURL];
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
} // menuItemSave

- (void)menuItemSaveAs:(NSNotification *)__unused notification {
    [self showSheetSaveAs];
} // menuItemSaveAs

- (void)menuItemRename:(NSNotification *)__unused notification {
    [self showSheetRename];
} // menuItemRename

- (void)menuItemExport:(NSNotification *)__unused notification {
    [self showSheetExport];
} // menuItemExport

- (void)menuItemShowInFinder:(NSNotification *)__unused notification {
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][[_settingsViewController selectedTemplate]];
    if (currentTemplateURL) {
        NSArray *currentTemplateURLArray = @[ currentTemplateURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:currentTemplateURLArray];
        [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    } else {
        [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    }
} // menuItemShowInFinder

- (void)menuItemDelete:(NSNotification *)__unused notification {
    NSString *currentTemplateName = [_settingsViewController selectedTemplate];
    NSURL *currentTemplateURL = [_settingsViewController templatesDict][currentTemplateName];
    if ([currentTemplateURL checkResourceIsReachableAndReturnError:nil]) {
        NSDictionary *alertInfo = @{NBCAlertTagKey : NBCAlertTagDeleteTemplate, NBCAlertUserInfoTemplateURL : currentTemplateURL};

        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertDeleteTemplate:[NSString stringWithFormat:@"Are you sure you want to delete the template %@?", currentTemplateName] templateName:currentTemplateName alertInfo:alertInfo];
    }
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
} // menuItemDelete

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Sheets
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)showSheetSaveUntitled:(NSString *)senderTitle buildNBI:(BOOL)buildNBI preWorkflowTasks:(NSDictionary *)preWorkflowTasks {
    [_textFieldSheetSaveUntitledName setStringValue:@""];
    [[NSApp mainWindow] beginSheet:_sheetSaveUntitled
                 completionHandler:^(NSModalResponse returnCode) {
                   if (returnCode == NSModalResponseOK) {
                       [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveUntitledName stringValue] atUrl:nil];
                       if (buildNBI) {
                           [self->_settingsViewController verifySettings:preWorkflowTasks];
                       }
                   } else if (returnCode == NSModalResponseContinue) {
                       [self->_settingsViewController setSelectedTemplate:senderTitle];
                       [self->_settingsViewController updateUISettingsFromURL:[self->_settingsViewController templatesDict][[self->_settingsViewController selectedTemplate]]];
                       [self->_settingsViewController expandVariablesForCurrentSettings];
                       if (buildNBI) {
                           [self->_settingsViewController verifySettings:preWorkflowTasks];
                       }
                   }
                 }];
} // showSheetSaveUntitled

- (void)showSheetRenameImportTemplateWithName:(NSString *)name url:(NSURL *)templateURL {
    DDLogInfo(@"showSheetRenameImportTemplateWithName");
    NSLog(@"_sheetRenameImportTemplate=%@", _sheetRenameImportTemplate);
    [self setImportTemplateURL:templateURL];
    [_titleSheetRenameImportTemplate setStringValue:[NSString stringWithFormat:@"Template name \"%@\" already exist", name]];
    NSLog(@"_titleSheetRenameImportTemplate=%@", [_titleSheetRenameImportTemplate stringValue]);
    [_textFieldSheetRenameImportTemplate setStringValue:name];
    NSLog(@"_textFieldSheetRenameImportTemplate=%@", [_textFieldSheetRenameImportTemplate stringValue]);
    NSLog(@"presenting_sheet");
    [[NSApp mainWindow] beginSheet:_sheetRenameImportTemplate
                 completionHandler:^(NSModalResponse returnCode) {
                   NSLog(@"returnCode=%ld", (long)returnCode);
                   if (returnCode == NSModalResponseOK) {
                   }
                 }];
} // showSheetSaveUntitled

- (void)showSheetSaveAs {
    [_textFieldSheetSaveAsName setStringValue:@""];
    [[NSApp mainWindow] beginSheet:_sheetSaveAs
                 completionHandler:^(NSModalResponse returnCode) {
                   if (returnCode == NSModalResponseOK) {
                       [self->_settingsViewController saveUISettingsWithName:[self->_textFieldSheetSaveAsName stringValue] atUrl:nil];
                   }
                 }];
} // showSheetSaveAs

- (void)showSheetRename {
    [_textFieldSheetRenameName setStringValue:@""];
    [[NSApp mainWindow] beginSheet:_sheetRename
                 completionHandler:^(NSModalResponse __unused returnCode){

                 }];
} // showSheetSaveAs

- (void)showSheetExport {

    __block NSError *error;
    NSURL *selectedTemplateURL;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *selectedTemplate = [_settingsViewController selectedTemplate];
    if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
        selectedTemplateURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/tmp/%@", selectedTemplate]];
        [_settingsViewController saveUISettingsWithName:selectedTemplate atUrl:selectedTemplateURL];
    } else {
        selectedTemplateURL = [_settingsViewController templatesDict][selectedTemplate];
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    NSDictionary *selectedTemplateDict = [NSDictionary dictionaryWithContentsOfURL:selectedTemplateURL];
    if ([selectedTemplateDict count] != 0) {
        NSString *templateName = selectedTemplateDict[NBCSettingsTitleKey] ?: @"";

        //[panel setAccessoryView:_viewExportPanel]; // Activate later for bundle export support
        [panel setAllowedFileTypes:@[ @"com.github.NBICreator.template" ]];
        [panel setCanCreateDirectories:YES];
        [panel setTitle:@"Export Template"];
        [panel setPrompt:@"Export"];
        [panel setNameFieldStringValue:[NSString stringWithFormat:@"%@", templateName]];
        [panel beginSheetModalForWindow:[(NBCController *)[[NSApplication sharedApplication] delegate] window]
                      completionHandler:^(NSInteger result) {
                        if (result == NSFileHandlingPanelOKButton) {
                            NSURL *saveURL = [panel URL];
                            [fm copyItemAtURL:selectedTemplateURL toURL:saveURL error:nil];
                        }
                        [self->_popUpButton selectItemWithTitle:selectedTemplate];

                        if ([[self->_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
                            if (![fm removeItemAtURL:selectedTemplateURL error:&error]) {
                                DDLogError(@"[ERROR] %@", [error localizedDescription]);
                            }
                        }
                      }];
    } else {
        [_popUpButton selectItemWithTitle:selectedTemplate];

        if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
            if (![fm removeItemAtURL:selectedTemplateURL error:&error]) {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
        }
    }
} // showSheetExport

- (IBAction)buttonSheetSaveAsCancel:(id)__unused sender {
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    [[NSApp mainWindow] endSheet:_sheetSaveAs returnCode:NSModalResponseCancel];
    [_sheetSaveAs orderOut:self];
} // buttonSheetCancel

- (IBAction)buttonSheetSaveAsSaveAs:(id)__unused sender {
    NSString *newName = [_textFieldSheetSaveAsName stringValue];
    [_popUpButton insertItemWithTitle:newName atIndex:0];
    [_popUpButton selectItemWithTitle:newName];
    if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
        [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
        NSInteger indexSave = [_popUpButton indexOfItemWithTag:kTemplateSelectionSave];
        [[_popUpButton itemAtIndex:indexSave] setEnabled:YES];
        NSInteger indexShowInFinder = [_popUpButton indexOfItemWithTag:kTemplateSelectionShowInFinder];
        [[_popUpButton itemAtIndex:indexShowInFinder] setEnabled:YES];
    }
    [_settingsViewController setSelectedTemplate:newName];
    [[NSApp mainWindow] endSheet:_sheetSaveAs returnCode:NSModalResponseOK];
    [_sheetSaveAs orderOut:self];
} // buttonSheetSave

- (IBAction)buttonSheetSaveUntitledCancel:(id)__unused sender {
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseCancel];
    [_sheetSaveUntitled orderOut:self];
} // buttonSaveUntitledCancel

- (IBAction)buttonSheetSaveUntitledSaveAs:(id)__unused sender {
    NSString *newName = [_textFieldSheetSaveUntitledName stringValue];
    [_popUpButton insertItemWithTitle:newName atIndex:0];
    [_popUpButton selectItemWithTitle:newName];
    if ([[_settingsViewController selectedTemplate] isEqualToString:NBCMenuItemUntitled]) {
        [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
        NSInteger indexSave = [_popUpButton indexOfItemWithTag:kTemplateSelectionSave];
        [[_popUpButton itemAtIndex:indexSave] setEnabled:YES];
        NSInteger indexShowInFinder = [_popUpButton indexOfItemWithTag:kTemplateSelectionShowInFinder];
        [[_popUpButton itemAtIndex:indexShowInFinder] setEnabled:YES];
    }
    [_settingsViewController setSelectedTemplate:newName];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseOK];
    [_sheetSaveUntitled orderOut:self];
} // buttonSaveUntitledSave

- (IBAction)buttonSheetSaveUntitledDelete:(id)__unused sender {
    [_popUpButton removeItemWithTitle:NBCMenuItemUntitled];
    [[NSApp mainWindow] endSheet:_sheetSaveUntitled returnCode:NSModalResponseContinue];
    [_sheetSaveUntitled orderOut:self];
} // buttonSaveUntitledDelete

- (IBAction)buttonSheetRenameRename:(id)__unused sender {
    NSString *newName = [_textFieldSheetRenameName stringValue];
    NSString *selectedTemplate = [_settingsViewController selectedTemplate];
    if ([selectedTemplate length] != 0) {
        NSURL *selectedTemplateURL = [_settingsViewController templatesDict][selectedTemplate];
        if (selectedTemplateURL) {
            NSMutableDictionary *templateDict = [NSMutableDictionary dictionaryWithContentsOfURL:selectedTemplateURL];
            if ([templateDict count] != 0) {
                templateDict[NBCSettingsTitleKey] = newName;
                if ([templateDict writeToURL:selectedTemplateURL atomically:YES]) {
                    [_settingsViewController templatesDict][newName] = selectedTemplateURL;
                } else {
                    DDLogError(@"[ERROR] Could not rename template!");
                    return;
                }
            }
        }
    }
    [_popUpButton insertItemWithTitle:newName atIndex:0];
    [_popUpButton selectItemWithTitle:newName];
    if ([[_popUpButton itemTitles] containsObject:[_textFieldSheetSaveAsName stringValue]]) {
        [_popUpButton removeItemWithTitle:[_settingsViewController selectedTemplate]];
    }
    [_settingsViewController setSelectedTemplate:newName];
    [[NSApp mainWindow] endSheet:_sheetRename returnCode:NSModalResponseOK];
    [_sheetRename orderOut:self];
} // buttonSheetRenameRename

- (IBAction)buttonSheetRenameCancel:(id)__unused sender {
    [_popUpButton selectItemWithTitle:[_settingsViewController selectedTemplate]];
    [[NSApp mainWindow] endSheet:_sheetRename returnCode:NSModalResponseCancel];
    [_sheetRename orderOut:self];
} // buttonSheetRenameCancel

- (IBAction)buttonSheetRenameImportTemplateCancel:(id)__unused sender {
    [[NSApp mainWindow] endSheet:_sheetRenameImportTemplate returnCode:NSModalResponseCancel];
    [_sheetRenameImportTemplate orderOut:self];
} // buttonSheetRenameImportTemplateCancel

- (IBAction)buttonSheetRenameImportTemplateImport:(id)__unused sender {
    NSString *newName = [_textFieldSheetRenameImportTemplate stringValue];
    NSError *error = nil;
    if (![self importTemplateFromURL:_importTemplateURL newName:newName error:&error]) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        [NBCAlerts showAlertErrorWithTitle:@"Import Error" informativeText:[error localizedDescription]];
    }

    [[NSApp mainWindow] endSheet:_sheetRenameImportTemplate returnCode:NSModalResponseOK];
    [_sheetRenameImportTemplate orderOut:self];
} // buttonSheetRenameImportTemplateImport

- (BOOL)importTemplateFromURL:(NSURL *)templateURL newName:(NSString *)newName error:(NSError **)error {
    NSURL *templatesFolderURL = [_settingsViewController templatesFolderURL];
    if (![templatesFolderURL checkResourceIsReachableAndReturnError:nil]) {
        if (![[NSFileManager defaultManager] createDirectoryAtURL:templatesFolderURL withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }

    if ([templateURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *importTemplate = [[NSMutableDictionary alloc] initWithContentsOfURL:templateURL];
        if ([newName length] != 0) {
            importTemplate[NBCSettingsTitleKey] = newName;
        }

        NSURL *templateSaveURL = [templatesFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nbictemplate", [[NSUUID UUID] UUIDString]]];
        if ([importTemplate writeToURL:templateSaveURL atomically:YES]) {
            [self updateTemplateListForPopUpButton:_popUpButton title:newName];
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
} // importTemplateFromURL:newName:error

@end
