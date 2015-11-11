//
//  NBCImageDropViewController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-11.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@protocol NBCImageDropViewIconDelegate
- (void)updateIconFromURL:(NSURL *)iconURL;
@end

@protocol NBCImageDropViewBackgroundDelegate
- (void)updateBackgroundFromURL:(NSURL *)backgroundURL;
@end

@interface NBCImageDropViewIcon : NSImageView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end

@interface NBCImageDropViewBackground : NSImageView <NSDraggingDestination>
@property (nonatomic, weak) id delegate;
@end


