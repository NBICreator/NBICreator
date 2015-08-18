//
//  AppDelegate.h
//  NBICreatorDesktopViewer
//
//  Created by Erik Berglund on 2015-08-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property NSImage *backgroundImage;

@property (weak) IBOutlet NSImageView *imageViewBackgroundImage;

@end

