//
//  NBCImageDropViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-11.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCImageDropViewController.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCImageDropViewIcon
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@implementation NBCImageDropViewIcon

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:[NSImage imageTypes]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if ([NSImage canInitWithPasteboard:[sender draggingPasteboard]] && [sender draggingSourceOperationMask] & NSDragOperationCopy ) {
        NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
        
        // ----------------------------------------------
        //  Only accept a URL if it has a icns extension
        // ----------------------------------------------
        NSString *draggedFileExtension = [draggedFileURL pathExtension];
        if ( [draggedFileURL checkResourceIsReachableAndReturnError:nil] && [draggedFileExtension isEqualToString:@"icns"]) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
} // draggingEntered

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ( [draggedFileURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogInfo(@"Dropped icon path: %@", [draggedFileURL path]);
        
        if ( _delegate && [_delegate respondsToSelector:@selector(updateIconFromURL:)]) {
            [_delegate updateIconFromURL:draggedFileURL];
        }
        return YES;
    } else {
        return NO;
    }
} // performDragOperation

- (NSURL *)getDraggedSourceURLFromPasteboard:(NSPasteboard *)pboard {
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        // ---------------------------------
        //  Verify only one item is dropped
        // ---------------------------------
        if ( [files count] != 1 ) {
            return nil;
        } else {
            return [NSURL fileURLWithPath:[files firstObject]];;
        }
    }
    return nil;
} // getDraggedSourceURLFromPasteboard

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCImageDropViewBackground
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

@implementation NBCImageDropViewBackground

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
} // drawRect

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self registerForDraggedTypes:[NSImage imageTypes]];
    }
    return self;
} // initWithCoder

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    if ([NSImage canInitWithPasteboard:[sender draggingPasteboard]] && [sender draggingSourceOperationMask] & NSDragOperationCopy ) {
        NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
        if ( [draggedFileURL checkResourceIsReachableAndReturnError:nil] ) {
            return NSDragOperationCopy;
        }
    }
    return NSDragOperationNone;
} // draggingEntered

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSURL *draggedFileURL = [self getDraggedSourceURLFromPasteboard:[sender draggingPasteboard]];
    if ( [draggedFileURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogInfo(@"Dropped background path: %@", [draggedFileURL path]);
        
        if ( _delegate && [_delegate respondsToSelector:@selector(updateBackgroundFromURL:)]) {
            [_delegate updateBackgroundFromURL:draggedFileURL];
        }
        return YES;
    } else {
        return NO;
    }
} // performDragOperation

- (NSURL *)getDraggedSourceURLFromPasteboard:(NSPasteboard *)pboard {
    if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
        NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];
        
        // ---------------------------------
        //  Verify only one item is dropped
        // ---------------------------------
        if ( [files count] != 1 ) {
            return nil;
        } else {
            return [NSURL fileURLWithPath:[files firstObject]];
        }
    }
    return nil;
} // getDraggedSourceURLFromPasteboard

@end
