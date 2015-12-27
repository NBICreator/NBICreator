//
//  NBCTemplatesController.h
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

#import <Cocoa/Cocoa.h>
#import "NBCAlerts.h"

@protocol NBCTemplatesDelegate
@optional

@end

@interface NBCTemplatesController : NSWindowController <NBCAlertDelegate> {
    id _delegate;
}

@property id settingsViewController;
@property NSString *templateType;
@property NSString *templateDefaultSettings;
@property NSPopUpButton *popUpButton;

@property (strong) IBOutlet NSWindow *sheetRename;
@property (weak) IBOutlet NSButton *buttonSheetRenameRename;
- (IBAction)buttonSheetRenameRename:(id)sender;
- (IBAction)buttonSheetRenameCancel:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldSheetRenameName;


// ------------------------------------------------------
//  IBOutlets/Actions Sheet Save
// ------------------------------------------------------
@property (strong) IBOutlet NSWindow *sheetSaveAs;

@property (weak) IBOutlet NSButton *buttonSheetSaveAsSaveAs;
@property (weak) IBOutlet NSTextField *textFieldSheetSaveAsName;
- (IBAction)buttonSheetSaveAsSaveAs:(id)sender;
- (IBAction)buttonSheetSaveAsCancel:(id)sender;

@property (strong) IBOutlet NSView *viewExportPanel;
@property (weak) IBOutlet NSButton *checkboxExportPanelIncludeResources;

@property (weak) IBOutlet NSTextField *textFieldSheetRenameImportTemplate;
@property (weak) IBOutlet NSTextField *titleSheetRenameImportTemplate;

@property NSURL *importTemplateURL;
@property (strong) IBOutlet NSWindow *sheetRenameImportTemplate;
- (IBAction)buttonSheetRenameImportTemplateCancel:(id)sender;
@property (weak) IBOutlet NSButton *buttonSheetRenameImportTemplateImport;
- (IBAction)buttonSheetRenameImportTemplateImport:(id)sender;

// ------------------------------------------------------
//  IBOutlets/Actions Sheet Save Untitled
// ------------------------------------------------------
@property (strong) IBOutlet NSWindow *sheetSaveUntitled;

@property (weak) IBOutlet NSButton *buttonSheetSaveUntitledSaveAs;
@property (weak) IBOutlet NSTextField *textFieldSheetSaveUntitledName;

- (IBAction)buttonSheetSaveUntitledSaveAs:(id)sender;
- (IBAction)buttonSheetSaveUntitledCancel:(id)sender;
- (IBAction)buttonSheetSaveUntitledDelete:(id)sender;

- (void)menuItemNew:(NSNotification *)notification;
- (void)menuItemSave:(NSNotification *)notification;
- (void)menuItemSaveAs:(NSNotification *)notification;
- (void)menuItemRename:(NSNotification *)notification;
- (void)menuItemExport:(NSNotification *)notification;
- (void)menuItemDelete:(NSNotification *)notification;
- (void)menuItemShowInFinder:(NSNotification *)notification;
+ (BOOL)templateNameAlreadyExist:(NSURL *)templateURL;
+ (BOOL)templateIsDuplicate:(NSURL *)templateURL;
- (void)deleteTemplateAtURL:(NSURL *)templateURL updateTemplateList:(BOOL)update;
- (void)showSheetSaveUntitled:(NSString *)senderTitle buildNBI:(BOOL)buildNBI preWorkflowTasks:(NSDictionary *)preWorkflowTasks;
- (void)showSheetRenameImportTemplateWithName:(NSString *)name url:(NSURL *)templateURL;
- (id)initWithSettingsViewController:(id)settingsViewController templateType:(NSString *)templateType delegate:(id<NBCTemplatesDelegate>)delegate;
- (void)updateTemplateListForPopUpButton:(NSPopUpButton *)popUpButton title:(NSString *)title;
- (BOOL)importTemplateFromURL:(NSURL *)templateURL newName:(NSString *)newName error:(NSError **)error;
+ (NSDictionary *)templateInfoFromTemplateAtURL:(NSURL *)templateURL error:(NSError **)error;

@end
