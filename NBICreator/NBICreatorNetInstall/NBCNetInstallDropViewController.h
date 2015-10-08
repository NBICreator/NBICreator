//
//  NBCNIDropViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCSource.h"

@interface NBCNetInstallDropViewController : NSViewController

// ------------------------------------------------------
//  Views
// ------------------------------------------------------
@property (strong) IBOutlet NSView *viewDropView;
@property (strong) IBOutlet NSView *viewDropViewNoSource;

// ------------------------------------------------------
//  Class Instance Properties
// ------------------------------------------------------
@property NBCSource *source;
@property NBCSource *sourcePackageOnly;

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


// ------------------------------------------------------
//  Layout Progress Package Only
// ------------------------------------------------------
@property (weak) IBOutlet NSProgressIndicator *progressIndicatorStatusPackageOnly;
@property (weak) IBOutlet NSTextField *textFieldStatusPackageOnly;

// ------------------------------------------------------
//  Layout No Source
// ------------------------------------------------------
@property (weak) IBOutlet NSImageView *imageViewNoSource;
@property (weak) IBOutlet NSImageView *imageViewNoSourceMini;
@property (weak) IBOutlet NSTextField *textFieldNoSourceTitle;
@property (weak) IBOutlet NSTextField *textFieldSourceField1LabelPackageOnly;
@property (weak) IBOutlet NSTextField *textFieldSourceField1PackageOnly;
@property (weak) IBOutlet NSTextField *textFieldSourceField2LabelPackageOnly;
@property (weak) IBOutlet NSTextField *textFieldSourceField2PackageOnly;



@end

@interface NBCNetInstallDropView : NSView <NSDraggingDestination> @end
@interface NBCNetInstallDropViewBox : NSBox <NSDraggingDestination> @end
@interface NBCNetInstallDropViewImageView : NSImageView <NSDraggingDestination> @end
