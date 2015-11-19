//
//  NBCOptionBuildPanel.h
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
#import "NBCSource.h"

@protocol NBCOptionBuildPanelDelegate
@optional
- (void)continueWorkflow:(NSDictionary *)preWorkflowTasks;
@end

@interface NBCOptionBuildPanel : NSWindowController {
    id _delegate;
}

@property (weak) id settingsViewController;
@property (strong) IBOutlet NSWindow *windowOptionWindow;


@property (weak) IBOutlet NSButton *checkboxClearSourceCache;
@property (weak) IBOutlet NSPopUpButton *popUpButtonClearSourceCache;
@property (weak) IBOutlet NSPopUpButton *pupUpButtonChangeLogLevel;

@property (weak) IBOutlet NSButton *buttonContinue;
- (IBAction)buttonContinue:(id)sender;
- (IBAction)buttonCancel:(id)sender;

- (id)initWithDelegate:(id<NBCOptionBuildPanelDelegate>)delegate;

@end
