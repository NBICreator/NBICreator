//
//  NBCOptionBuildPanel.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-27.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCOptionBuildPanel.h"

@interface NBCOptionBuildPanel ()

@end

@implementation NBCOptionBuildPanel

- (id)init {
    self = [super initWithWindowNibName:@"NBCOptionBuildPanel"];
    if ( self != nil ) {

    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (IBAction)buttonContinue:(id)sender {
#pragma unused(sender)
}

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    [[[self window] sheetParent] endSheet:[self window] returnCode:NSModalResponseCancel];
}
@end
