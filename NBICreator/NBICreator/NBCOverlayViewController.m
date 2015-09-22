//
//  NBCOverlayViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-22.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCOverlayViewController.h"
#import "NBCConstants.h"

@interface NBCOverlayViewController ()

@end

@implementation NBCOverlayViewController

- (id)initWithContentType:(int)contentType {
    self = [super initWithNibName:@"NBCOverlayViewController" bundle:nil];
    if ( self != nil ) {
        _contentType = contentType;
        [self updateViewContent];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)updateViewContent {
    NSImage *image;
    NBCOverlayView *view = (NBCOverlayView *)[self view];
    [[view textField] setStringValue:@"Test"];
    switch ( _contentType ) {
        case kContentTypePackages:
            image = [[NSImage alloc] initWithContentsOfFile:IconMetaPackagePath];
            [[view imageView] setImage:image];
            [[view textField] setStringValue:@"Drop Packages Here"];
            break;
        case kContentTypeCertificates:
            image = [NSImage imageNamed:@"IconCertRoot"];
            [[view imageView] setImage:image];
            [[view textField] setStringValue:@"Drop Certificates Here"];
            break;
        case kContentTypeConfigurationProfiles:
            image = [[NSImage alloc] initWithContentsOfFile:IconConfigurationProfilePath];
            [[view imageView] setImage:image];
            [[view textField] setStringValue:@"Drop Configuration Profiles Here"];
            break;
        default:
            break;
    }
}


@end

@implementation NBCOverlayView

- (void)drawRect:(NSRect)dirtyRect {
#pragma unused(dirtyRect)
    [[NSColor whiteColor] set];
    NSRectFill([self bounds]);
}

@end
