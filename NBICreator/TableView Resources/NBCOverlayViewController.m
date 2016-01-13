//
//  NBCOverlayViewController.m
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
    NSImage *imageRight;
    NBCOverlayView *view = (NBCOverlayView *)[self view];
    [[view textField] setStringValue:@""];
    switch ( _contentType ) {
        case kContentTypePackages:
            image = [[NSWorkspace sharedWorkspace] iconForFileType:@"com.apple.installer-package-archive"];
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
        case kContentTypeNetInstallPackages:
            image = [[NSWorkspace sharedWorkspace] iconForFileType:@"com.apple.installer-package-archive"];
            [[view imageView] setImage:image];
            imageRight = [[NSWorkspace sharedWorkspace] iconForFileType:@"public.shell-script"];
            [[view imageViewRight] setImage:imageRight];
            [[view imageViewRight] setHidden:NO];
            [[view textField] setStringValue:@"Drop Packages and Scripts Here"];
            [_constraintImageLeft setConstant:195.0];
            break;
        case kContentTypeScripts:
            image = [[NSWorkspace sharedWorkspace] iconForFileType:@"public.shell-script"];
            [[view imageView] setImage:image];
            [[view textField] setStringValue:@"Drop Scripts Here"];
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
