//
//  NBCOptionBuildPanel.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-27.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NBCOptionBuildPanel : NSWindowController

@property (strong) IBOutlet NSWindow *windowOptionWindow;

@property (weak) IBOutlet NSButton *buttonContinue;
- (IBAction)buttonContinue:(id)sender;

- (IBAction)buttonCancel:(id)sender;

@end
