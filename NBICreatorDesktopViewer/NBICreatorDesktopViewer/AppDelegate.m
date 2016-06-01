//
//  AppDelegate.m
//  NBICreatorDesktopViewer
//
//  Created by Erik Berglund on 2015-08-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (unsafe_unretained) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSURL *backgroundImageURL;
    NSURL *customBackgroundImageURL = [self customImageURL];
    NSURL *defaultBackgroundImageURL = [NSURL fileURLWithPath:@"/System/Library/CoreServices/DefaultDesktop.jpg"];

    if ([customBackgroundImageURL checkResourceIsReachableAndReturnError:nil]) {
        backgroundImageURL = customBackgroundImageURL;
    } else if ([defaultBackgroundImageURL checkResourceIsReachableAndReturnError:nil]) {
        backgroundImageURL = defaultBackgroundImageURL;
    }

    if (!backgroundImageURL) {
        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
        return;
    }

    NSImage *backgroundImage = [[NSImage alloc] initWithContentsOfURL:backgroundImageURL];
    if (backgroundImage) {

        [_window setFrame:[[NSScreen mainScreen] frame] display:YES];
        [[_window contentView] setWantsLayer:YES];
        [[[_window contentView] layer] setContents:backgroundImage];
        [_window setIgnoresMouseEvents:YES];
        [_window setLevel:(NSNormalWindowLevel - 1)];
        [_window orderFrontRegardless];
        [_window setCollectionBehavior:NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorCanJoinAllSpaces];
    }
}

- (NSURL *)customImageURL {
    NSURL *baseSystemImageURL = [NSURL fileURLWithPath:@"/Library/Application Support/NBICreator/Background.jpg"];
    if ([baseSystemImageURL checkResourceIsReachableAndReturnError:nil]) {
        return baseSystemImageURL;
    }

    NSURL *netInstallImageURL = [NSURL fileURLWithPath:@"/Volumes/Image Volume/Packages/Background.jpg"];
    if ([netInstallImageURL checkResourceIsReachableAndReturnError:nil]) {
        return netInstallImageURL;
    }

    return nil;
}

@end
