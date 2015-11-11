//
//  NBCWorkflowProgressViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressDelegate.h"

@interface NBCWorkflowProgressViewController : NSViewController <NBCWorkflowProgressDelegate>

@property (strong) IBOutlet NSLayoutConstraint *layoutContraintStatusInfoLeading;

@property NBCWorkflowItem *workflowItem;
@property NSURL *nbiURL;
@property NSURL *nbiLogURL;

@property (weak) IBOutlet NSTextField *textFieldTimer;
@property (weak) IBOutlet NSImageView *nbiIcon;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSProgressIndicator *progressIndicatorSpinner;
@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldStatusTitle;
@property (weak) IBOutlet NSTextField *textFieldStatusInfo;

@property NSTimer *timer;
@property BOOL isRunning;
@property BOOL workflowNBIComplete;
@property BOOL workflowNBIResourcesComplete;
@property BOOL workflowComplete;
@property BOOL workflowFailed;

@property NSString *workflowNBIResourcesLastStatus;

@property (weak) IBOutlet NSButton *buttonCancel;
- (IBAction)buttonCancel:(id)sender;

@property (weak) IBOutlet NSButton *buttonShowInFinder;
- (IBAction)buttonShowInFinder:(id)sender;

@property (weak) IBOutlet NSButton *buttonOpenLog;
- (IBAction)buttonOpenLog:(id)sender;

- (void)workflowStartedForItem:(NBCWorkflowItem *)workflowItem;
- (void)workflowFailedWithError:(NSString *)errorMessage;
- (void)workflowCompleted;

@end
