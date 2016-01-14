//
//  NBCDisk.h
//  NBICreator
//
//  Copyright (c) 2010, Aaron Burghardt
//  All rights reserved.
//
//  Created by Erik Berglund on 2015-04-05.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  This is an ARC version of Disk.h created by Aaron Burghardt
//  https://github.com/aburgh/Disk-Arbitrator

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>


extern NSString * const DADiskDidAppearNotification;
extern NSString * const DADiskDidDisappearNotification;
extern NSString * const DADiskDidChangeNotification;
extern NSString * const DADiskDidAttemptMountNotification;
extern NSString * const DADiskDidAttemptUnmountNotification;
extern NSString * const DADiskDidAttemptEjectNotification;

extern NSString * const DAStatusErrorKey;

enum {
    kDiskUnmountOptionDefault = 0x00000000,
    kDiskUnmountOptionForce = 0x00080000,
    kDiskUnmountOptionWhole = 0x00000001
};

@interface NBCDisk : NSObject
{
    CFTypeRef _disk;
    NSString *BSDName;
    CFDictionaryRef _diskDescription;
    BOOL isMounting;
    NSImage *icon;
    NBCDisk *parent;
    NSMutableSet *children;
}

@property BOOL isMountedByNBICreator;
@property (readonly) NSString *uuid;
@property (copy) NSString *BSDName;
@property CFDictionaryRef diskDescription;
@property (readonly) BOOL isMountable;
@property (readonly) BOOL isMounted;
@property (readwrite) BOOL isMounting;
@property (readonly) BOOL isWritable;
@property (readonly) BOOL isFileSystemWritable;
@property (readonly) BOOL isEjectable;
@property (readonly) BOOL isRemovable;
@property (readonly) BOOL isWholeDisk;
@property (readonly) BOOL isLeaf;
@property (readonly) BOOL isNetworkVolume;
@property (readonly) BOOL isInternal;
@property (readonly, strong) NSImage *icon;
@property NBCDisk *containerDiskImageDisk;
@property NSURL *containerDiskImageURL;
@property NBCDisk *parent;
@property (strong) NSMutableSet *children;
@property (readonly) NSURL *volumeURL;
@property (readonly) NSString *volumeName;
@property (readonly) NSString *mediaName;
@property (readonly) NSNumber *mediaSize;
@property (readonly) NSString *deviceModel;
@property (readonly) NSString *deviceProtocol;
@property (readonly) NSString *kind;
@property (readonly) NSString *type;

- (void)mount;
- (void)mountAtPath:(NSString *)path withArguments:(NSArray *)args;
- (void)unmountWithOptions:(NSUInteger)options;
- (void)eject;

@end
