//
//  NBCAlerts.m
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
#import "NBCConstants.h"
#import "NBCController.h"
#import "NBCLogging.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

@implementation NBCAlerts

- (id)initWithDelegate:(id<NBCAlertDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

+ (void)showAlertError:(NSError *)error {
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        #pragma unused(returnCode)
        
    }];
}

+ (void)showAlertOKWithTitle:(NSString *)title informativeText:(NSString *)informativeText {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:title ?: @""];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertErrorWithTitle:(NSString *)title informativeText:(NSString *)informativeText {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:title ?: @"Error"];
    [alert setInformativeText:informativeText ?: @"Unknown Error"];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertSettingsUnchangedNBI {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Nothing to update"];
    [alert setInformativeText:[NSString stringWithFormat:@"You have not made any changes to the NBI."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertRecoveryVersionMismatch {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Recovery Version Mismatch"];
    [alert setInformativeText:@"System version and it's Recovery HD must be of the same OS build and version to create a correct DeployStudio NBI. Consider using a Disk Image created from AutoDMG as source."];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        #pragma unused(returnCode)
        
    }];
}

+ (void)showAlertSourceReadOnly {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Read Only Destination"];
    [alert setInformativeText:  @"NBICreator have insufficient permissions to modify the selected NBI.\n\n"
                                @"Please move the NBI to a directory where NBICreator have write permissions and/or update the permissions on the NBI folder."];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}

+ (void)showAlertFeatureNotImplemented:(NSString *)featureName {
    NSAlert *alert = [[NSAlert alloc] init];
    NSString *featureNameString = featureName ?: @"Feature";
    NSString *informativeText = [NSString stringWithFormat:@"%@ is not implemented yet, but will be available in a future release.", featureNameString];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Feature Not Implemented Yet"];
    [alert setInformativeText:informativeText];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
        
    }];
}


+ (void)showAlertUnrecognizedImagrApplication {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Invalid Imagr Application"];
    [alert setInformativeText:[NSString stringWithFormat:@"You need to set the path to a local Imagr.app application."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
                #pragma unused(returnCode)
    }];
}

+ (void)showAlertUnrecognizedCasperImagingApplication {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Invalid Casper Imaging Application"];
    [alert setInformativeText:[NSString stringWithFormat:@"You need to set the path to a local Casper Imaging.app application."]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
    }];
}

+ (void)showAlertUnrecognizedSourceForCreationTool:(NSString *)creationTool errorMessage:(NSString *)errorMessage {
    NSString *informativeText;
    if ( [creationTool isEqualToString:NBCMenuItemNBICreator] ) {
        informativeText = @"NBICreator only accept the following sources:\n\n• Install OS X Application\n• InstallESD.dmg";
    } else if ( [creationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        informativeText = @"SystemImageUtility only accept the following sources:\n\n• Install OS X Application\n• InstallESD.dmg";
    } else if ( [creationTool isEqualToString:NBCMenuItemDeployStudioAssistant] ) {
        informativeText = @"DeployStudioAssistant only accept the following sources:\n\n• OS X System Volume and Recovery Partition";
    } else {
        DDLogError(@"[ERROR] Unknown creation tool: %@", creationTool);
        informativeText = @"Could not verify source for the selected creation tool";
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Invalid Source"];
    [alert setInformativeText:errorMessage ?: @"Unknown Error"];
    [alert setInformativeText:[NSString stringWithFormat:@"%@\n\n%@", errorMessage, informativeText]]; // Testing to only show error message
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
                #pragma unused(returnCode)
    }];
}

+ (void)showAlertSettingsError:(NSString *)informativeText {
    
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

+ (void)showAlertImportTemplateDuplicate:(NSString *)informativeText {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleOK];
    [alert setMessageText:@"Template already exist!"];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
    }];
}

- (void)showAlertSettingsWarning:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    
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
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleSave];   //NSAlertFirstButton
    [alert addButtonWithTitle:@"Discard"];          //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel]; //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertSettingsUnsavedBuild:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Save and Continue"];    //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleContinue];  //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertSettingsUnsavedQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Save and Quit"];        //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleQuit];      //NSAlertSecondButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertThirdButton
    [alert setMessageText:@"Unsaved Settings!"];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertWorkflowRunningQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Quit Anyway"];          //NSAlertFirstButton
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertSecondButton
    [alert setMessageText:@"Workflow Running!"];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

- (void)showAlertDeleteTemplate:(NSString *)informativeText templateName:(NSString *)templateName  alertInfo:(NSDictionary *)alertInfo {
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:NBCButtonTitleCancel];    //NSAlertFirstButton
    [alert addButtonWithTitle:@"Delete"];               //NSAlertSecondButton
    [alert setMessageText:[NSString stringWithFormat:@"Delete %@?", templateName]];
    [alert setInformativeText:informativeText ?: @""];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:[[NSApp delegate] window] completionHandler:^(NSInteger returnCode) {
        [self->_delegate alertReturnCode:returnCode alertInfo:alertInfo];
    }];
}

@end
