//
//  NBCWorkflowProgressViewController.h
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

#import "NBCWorkflowItem.h"
#import "NBCWorkflowProgressDelegate.h"

@interface NBCWorkflowProgressViewController : NSViewController <NBCWorkflowProgressDelegate>

@property (strong) IBOutlet NSLayoutConstraint *layoutContraintStatusInfoLeading;
@property (strong) IBOutlet NSLayoutConstraint *layoutConstraintButtonOpenLogLeading;
@property (strong) IBOutlet NSLayoutConstraint *layoutConstraintButtonCloseTrailing;

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
@property (weak) IBOutlet NSTextField *textFieldStatusWarnings;

@property NSTimer *timer;
@property NSString *timeElapsed;
@property BOOL isRunning;
@property BOOL workflowNBIComplete;
@property BOOL workflowNBIResourcesComplete;
@property BOOL workflowComplete;
@property BOOL workflowFailed;

@property NSMutableDictionary *linkerErrors;
@property NSString *workflowNBIResourcesLastStatus;

@property (weak) IBOutlet NSButton *buttonCancel;
- (IBAction)buttonCancel:(id)sender;

@property (weak) IBOutlet NSButton *buttonShowInFinder;
- (IBAction)buttonShowInFinder:(id)sender;

@property (weak) IBOutlet NSButton *buttonOpenLog;
- (IBAction)buttonOpenLog:(id)sender;

@property (weak) IBOutlet NSButton *buttonWorkflowReport;
- (IBAction)buttonWorkflowReport:(id)sender;

- (void)workflowStartedForItem:(NBCWorkflowItem *)workflowItem;
- (void)workflowFailedWithError:(NSString *)errorMessage;
- (void)workflowCompleted;

@end
