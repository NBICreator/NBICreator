//
//  NBCOptionBuildPanel.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-27.
//  Copyright © 2015 NBICreator. All rights reserved.
//

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
