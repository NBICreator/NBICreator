//
//  NBCWorkflowProgressViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NBCWorkflowItem;

@interface NBCWorkflowProgressViewController : NSViewController

@property NBCWorkflowItem *workflowItem;

@property NSURL *nbiURL;

@property (weak) IBOutlet NSImageView *nbiIcon;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldCenter;
@property (weak) IBOutlet NSTextField *textFieldStatusInfo;


@property (weak) IBOutlet NSButton *buttonCancel;
- (IBAction)buttonCancel:(id)sender;

@property (weak) IBOutlet NSButton *buttonStatusInfo;
- (IBAction)buttonStatusInfo:(id)sender;

@end
