//
//  NBCTemplatesController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-16.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

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

// ------------------------------------------------------
//  IBOutlets/Actions Sheet Save
// ------------------------------------------------------
@property (strong) IBOutlet NSWindow *sheetSaveAs;

@property (weak) IBOutlet NSButton *buttonSheetSaveAsSaveAs;
@property (weak) IBOutlet NSTextField *textFieldSheetSaveAsName;
- (IBAction)buttonSheetSaveAsSaveAs:(id)sender;
- (IBAction)buttonSheetSaveAsCancel:(id)sender;

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
- (void)menuItemShowInFinder:(NSNotification *)notification;

- (void)showSheetSaveUntitled:(NSString *)senderTitle buildNBI:(BOOL)buildNBI;
- (id)initWithSettingsViewController:(id)settingsViewController templateType:(NSString *)templateType delegate:(id<NBCTemplatesDelegate>)delegate;
- (void)updateTemplateListForPopUpButton:(NSPopUpButton *)popUpButton title:(NSString *)title;

@end
