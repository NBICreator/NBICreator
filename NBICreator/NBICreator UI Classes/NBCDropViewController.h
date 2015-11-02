//
//  NBCIMDropViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-29.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

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
#pragma mark NBCDropDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@protocol NBCDropDelegate
@optional
- (void)verifySourceAtURL:(NSURL *)sourceURL;
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDropViewDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@protocol NBCDropViewDelegate
- (void)updateSource:(NBCSource *)source target:(NBCTarget *)target;
- (void)removedSource;
- (void)refreshCreationTool;
@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDropViewController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@interface NBCDropViewController : NSViewController <NBCDropDelegate>

// ------------------------------------------------------
//  Views
// ------------------------------------------------------
@property (strong) IBOutlet NSView *viewDropView;
@property (strong) IBOutlet NSView *viewNoSource;

// ------------------------------------------------------
//  Delegate
// ------------------------------------------------------
@property (nonatomic, weak) id delegate;
@property NSArray *sourceTypes;
@property NSString *creationTool;
@property NSMutableArray *sourcesInstallESD;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *currentSource;
@property NBCSource *sourceDeployStudioAssistant;
@property NBCSource *sourceNBICreator;
@property NBCSource *sourceSystemImageUtility;
@property NBCTarget *targetNBI;
@property NBCDropView *dropView;
@property id settingsViewController;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property NSArray *installerApplicationIdentifiers;
@property NSArray *imageViews;
@property NSArray *textFields;

// ------------------------------------------------------
//  PopUpButton Source
// ------------------------------------------------------
@property NSString *currentSelectedSource;
@property NSString *deployStudioAssistantSelectedSource;
@property NSString *nbiCreatorSelectedSource;
@property NSString *systemImageUtilitySelectedSource;

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
- (id)initWithDelegate:(id<NBCDropViewDelegate>)delegate;
+ (NSArray *)sourceTypesForCreationTool:(NSString *)creationTool;
@end

@interface NBCDropView : NSView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
- (id)initWithDelegate:(id<NBCDropDelegate>)delegate;
@property NSArray *sourceTypes;
@end

@interface NBCDropViewBox : NSBox <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end

@interface NBCDropViewImageView : NSImageView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end


