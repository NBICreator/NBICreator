//
//  NBCAlerts.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-17.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCAlerts.h"
#import "NBCConstants.h"
#import "NBCController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCAlerts

- (id)initWithDelegate:(id<NBCAlertDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)showAlertError:(NSError *)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        #pragma unused(returnCode)
        
    }];
}

+ (void)showAlertOKWithTitle:(NSString *)title informativeText:(NSString *)informativeText {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:title];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertSettingsUnchangedNBI {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Nothing to update"];
    [alert setInformativeText:[NSString stringWithFormat:@"You have not made any changes to the NBI. "]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertRecoveryVersionMismatch {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Recovery Version Mismatch"];
    [alert setInformativeText:[NSString stringWithFormat:@"System version and it's Recovery HD must be of the same OS build and version to create a correct DeployStudio NBI. Consider using a Disk Image created from AutoDMG as source."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        #pragma unused(returnCode)
        
    }];
}

+ (void)showAlertUnrecognizedImagrApplication {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Invalid Imagr Application"];
    [alert setInformativeText:[NSString stringWithFormat:@"You need to set the path to a local Imagr.app application."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
                #pragma unused(returnCode)
    }];
}

+ (void)showAlertUnrecognizedSource {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Invalid Source"];
    [alert setInformativeText:[NSString stringWithFormat:@"Imagr only accepts the following sources:\n\nInstall OS X Application\nInstallESD.dmg\nNetInstall Image"]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
                #pragma unused(returnCode)
    }];
}

+ (void)showAlertSettingsError:(NSString *)informativeText {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *text = [NSString stringWithFormat:@"The current settings contain errors that need to be addressed in order to create a valid NBI.\n%@", informativeText];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Configuration Error"];
    [alert setInformativeText:text];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
                #pragma unused(returnCode)
    }];
}

- (void)showAlertSettingsWarning:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *text = [NSString stringWithFormat:@"The current settings contain warnings that you need to approve before creating a NBI.\n%@", informativeText];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleCancel];     // NSAlertFirstButtonReturn
    [alert addButtonWithTitle:NBCButtonTitleContinue];   // NSAlertSecondButtonReturn
    [alert setMessageText:@"Configuration Warning"];
    [alert setInformativeText:text];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertSettingsUnsaved:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleSave];   //NSAlertFirstButton
    [alert addButtonWithTitle:@"Discard"];          //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel]; //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertSettingsUnsavedBuild:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Save and Continue"];    //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleContinue];  //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertSettingsUnsavedQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Save and Quit"];        //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleQuit];      //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertWorkflowRunningQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Quit Anyway"];          //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertSecondButton
    [alert setMessageText:@"Workflow Running!"];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertDeleteTemplate:(NSString *)informativeText templateName:(NSString *)templateName  alertInfo:(NSDictionary *)alertInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertFirstButton
    [alert addButtonWithTitle:@"Delete"];               //NSAlertSecondButton
    [alert setMessageText:[NSString stringWithFormat:@"Delete %@?", templateName]];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

@end