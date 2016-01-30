//
//  NBCSourceDropViewController.h
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
#import "NBCTarget.h"

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Constants
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
extern NSString *const NBCSourceTypeInstaller;
extern NSString *const NBCSourceTypeSystem;
//extern NSString *const NBCSourceTypeNBI;

@class NBCDropView;

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCSourceDropDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@protocol NBCSourceDropDelegate
@optional
- (void)verifySourceAtURL:(NSURL *)sourceURL;
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCSourceDropViewController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@protocol NBCSourceDropViewDelegate
- (void)updateSource:(NBCSource *)source target:(NBCTarget *)target;
- (void)removedSource;
- (void)refreshCreationTool;
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCSourceDropViewController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@interface NBCSourceDropViewController : NSViewController <NBCSourceDropDelegate>

// ------------------------------------------------------
//  Views
// ------------------------------------------------------
@property (strong) IBOutlet NSView *viewDropView;
@property (strong) IBOutlet NSView *viewNoSource;

// ------------------------------------------------------
//  Delegate
// ------------------------------------------------------
@property (nonatomic, weak) id delegate;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *currentSource;
@property NBCSource *sourceDeployStudioAssistant;
@property NBCSource *sourceNBI;
@property NBCSource *sourceNBICreator;
@property NBCSource *sourceSystemImageUtility;
@property NBCSource *sourceSystemImageUtilityPackageOnly;
@property NBCTarget *targetNBI;
@property NBCDropView *dropView;
@property id settingsViewController;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property NSArray *installerApplicationIdentifiers;
@property NSArray *imageViews;
@property NSArray *textFields;
@property NSArray *sourceTypes;
@property NSString *creationTool;
@property NSString *nbiType;
@property NSMutableArray *sourcesInstallESD;
@property BOOL allowNBISource;
@property BOOL sourceReadOnlyShown;

// ------------------------------------------------------
//  PopUpButton Source
// ------------------------------------------------------
@property NSString *currentSelectedSource;
@property NSString *nbiSelectedSource;
@property NSString *deployStudioAssistantSelectedSource;
@property NSString *nbiCreatorSelectedSource;
@property NSString *systemImageUtilitySelectedSource;
@property NSString *systemImageUtilityPackageOnlySelectedSource;

@property NSMutableDictionary *sourceDictLinks;
@property NSMutableDictionary *sourceDictSources;
@property (weak) IBOutlet NSPopUpButton *popUpButtonSource;
- (IBAction)popUpButtonSource:(id)sender;

// ------------------------------------------------------
//  Layout Constraints
// ------------------------------------------------------
@property (strong) IBOutlet NSLayoutConstraint *constraintPopUpButtonSourceWidth;
@property (strong) IBOutlet NSLayoutConstraint *constraintVerticalToImageView1;

// ------------------------------------------------------
//  Layout Default
// ------------------------------------------------------
@property (weak) IBOutlet NSImageView *imageView1;
@property (weak) IBOutlet NSTextField *textField1;

@property (weak) IBOutlet NSImageView *imageView2;
@property (weak) IBOutlet NSTextField *textField2;

@property (weak) IBOutlet NSImageView *imageView3;
@property (weak) IBOutlet NSTextField *textField3;

@property (weak) IBOutlet NSBox *verticalLine;
@property (weak) IBOutlet NSTextField *textFieldChoose;
@property (weak) IBOutlet NSTextField *textFieldOr;
@property (weak) IBOutlet NSTextField *textFieldDrop;

// ------------------------------------------------------
//  Layout Progress
// ------------------------------------------------------
@property (weak) IBOutlet NSProgressIndicator *progressIndicatorStatus;
@property (weak) IBOutlet NSTextField *textFieldStatus;

// ------------------------------------------------------
//  Layout Source
// ------------------------------------------------------
@property (weak) IBOutlet NSImageView *imageViewSource;
@property (weak) IBOutlet NSImageView *imageViewSourceMini;
@property (weak) IBOutlet NSTextField *textFieldSourceTitle;
@property (weak) IBOutlet NSTextField *textFieldSourceField1Label;
@property (weak) IBOutlet NSTextField *textFieldSourceField1;
@property (weak) IBOutlet NSTextField *textFieldSourceField2Label;
@property (weak) IBOutlet NSTextField *textFieldSourceField2;

// ------------------------------------------------------
//  Methods
// ------------------------------------------------------
- (id)initWithDelegate:(id<NBCSourceDropViewDelegate>)delegate;
+ (NSArray *)sourceTypesForCreationTool:(NSString *)creationTool allowNBISource:(BOOL)allowNBISource;
@end

@interface NBCDropView : NSView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@property BOOL allowNBISource;
- (id)initWithDelegate:(id<NBCSourceDropDelegate>)delegate;
@property NSArray *sourceTypes;
@end

@interface NBCDropViewBox : NSBox <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end

@interface NBCDropViewImageView : NSImageView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end


