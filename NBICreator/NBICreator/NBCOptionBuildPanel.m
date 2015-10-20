//
//  NBCOptionBuildPanel.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-27.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCOptionBuildPanel.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCNetInstallSettingsViewController.h"
#import "NBCDeployStudioSettingsViewController.h"
#import "NBCImagrSettingsViewController.h"
#import "NBCCasperSettingsViewController.h"

DDLogLevel ddLogLevel;

@interface NBCOptionBuildPanel ()

@end

@implementation NBCOptionBuildPanel

- (id)initWithDelegate:(id<NBCOptionBuildPanelDelegate>)delegate {
    self = [super initWithWindowNibName:@"NBCOptionBuildPanel"];
    if ( self != nil ) {
        _delegate = delegate;
    }
    return self;
}

- (id)init {
    self = [super initWithWindowNibName:@"NBCOptionBuildPanel"];
    if ( self != nil ) {

    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)awakeFromNib {
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:NBCUserDefaultsLogLevel options:NSKeyValueObservingOptionNew context:nil];
    
    if ( [_settingsViewController isKindOfClass:[NBCNetInstallSettingsViewController class]] ) {
        [_checkboxClearAppCache setEnabled:NO];
        [_popUpButtonClearAppCache setEnabled:NO];
        [_checkboxClearSourceCache setEnabled:NO];
        [_popUpButtonClearSourceCache setEnabled:NO];
    } else if ( [_settingsViewController isKindOfClass:[NBCDeployStudioSettingsViewController class]] ) {
        
    } else if ( [_settingsViewController isKindOfClass:[NBCImagrSettingsViewController class]] ) {
        
    } else if ( [_settingsViewController isKindOfClass:[NBCCasperSettingsViewController class]] ) {
        
    } else {
        DDLogError(@"[ERROR] Unknown settings view class!");
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    if ( [keyPath isEqualToString:NBCUserDefaultsLogLevel] ) {
        NSNumber *logLevel = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsLogLevel];
        if ( logLevel ) {
            ddLogLevel = (DDLogLevel)[logLevel intValue];
        }
    }
} // observeValueForKeyPath:ofObject:change:context

- (IBAction)buttonContinue:(id)sender {
#pragma unused(sender)
    [[[self window] sheetParent] endSheet:[self window] returnCode:NSModalResponseOK];
    if ( [_delegate respondsToSelector:@selector(continueWorkflow)] ) {
        [_delegate continueWorkflow];
    }
}

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    [[[self window] sheetParent] endSheet:[self window] returnCode:NSModalResponseCancel];
}

@end
