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

@interface NBCImagrDropViewController : NSViewController

// ------------------------------------------------------
//  Views
// ------------------------------------------------------
@property (strong) IBOutlet NSView *viewDropView;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCTarget *target;

// ------------------------------------------------------
//  Properties
// ------------------------------------------------------
@property NSArray *installerApplicationIdentifiers;

// ------------------------------------------------------
//  PopUpButton Source
// ------------------------------------------------------
@property NSString *selectedSource;
@property NSMutableDictionary *sourceDictLinks;
@property NSMutableDictionary *sourceDictSources;
@property (weak) IBOutlet NSPopUpButton *popUpButtonSource;
- (IBAction)popUpButtonSource:(id)sender;

// ------------------------------------------------------
//  Layout Constraints
// ------------------------------------------------------
@property (strong) IBOutlet NSLayoutConstraint *constraintPopUpButtonSourceWidth;

// ------------------------------------------------------
//  Layout Default
// ------------------------------------------------------
@property (weak) IBOutlet NSImageView *imageViewDropImage;
@property (weak) IBOutlet NSImageView *imageViewDropNBI;
@property (weak) IBOutlet NSBox *verticalLine;
@property (weak) IBOutlet NSTextField *textFieldChooseInstaller;
@property (weak) IBOutlet NSTextField *textFieldOr;
@property (weak) IBOutlet NSTextField *textFieldDropInstallESDHere;

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

@end

@interface NBCImagrDropView : NSView <NSDraggingDestination> @end
@interface NBCImagrDropViewBox : NSBox <NSDraggingDestination> @end
@interface NBCImagrDropViewImageView : NSImageView <NSDraggingDestination> @end
