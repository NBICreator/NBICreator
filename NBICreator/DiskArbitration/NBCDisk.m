//
//  NBCDisk.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-05.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  This is an ARC version of Disk.h created by Aaron Burghardt
//  https://github.com/aburgh/Disk-Arbitrator

#import "NBCDisk.h"

#import <DiskArbitration/DiskArbitration.h>
#import <IOKit/kext/KextManager.h>
#include <sys/mount.h>

#import "NBCDiskArbitrationPrivateFunctions.h"

@implementation NBCDisk

@synthesize BSDName;
@synthesize isMounting;
@synthesize icon;
@synthesize parent;
@synthesize children;

+ (void)initialize {
    InitializeDiskArbitration();
}

- (void)dealloc {
    if (_disk)
        CFRelease(_disk);
    if (_diskDescription)
        CFRelease(_diskDescription);
    parent = nil;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqual:@"isMountable"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"isMounted"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"isEjectable"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"isWritable"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"isRemovable"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"isFileSystemWritable"])
        return [NSSet setWithObject:@"diskDescription"];

    if ([key isEqual:@"icon"])
        return [NSSet setWithObject:@"diskDescription"];

    return [super keyPathsForValuesAffectingValueForKey:key];
}

+ (id)uniqueDiskForDADisk:(DADiskRef)diskRef create:(BOOL)create {
    for (NBCDisk *disk in uniqueDisks) {
        if ([disk hash] == CFHash(diskRef))
            return disk;
    }

    return create ? [[self.class alloc] initWithDADisk:diskRef shouldCreateParent:YES] : nil;
}

- (id)initWithDADisk:(DADiskRef)diskRef shouldCreateParent:(BOOL)shouldCreateParent {
    NSAssert(diskRef, @"No Disk Arbitration disk provided to initializer.");

    // Return unique instance
    NBCDisk *uniqueDisk = [NBCDisk uniqueDiskForDADisk:diskRef create:NO];
    if (uniqueDisk) {
        return uniqueDisk;
    }

    self = [super init];
    if (self) {
        _disk = CFRetain(diskRef);
        BSDName = @(DADiskGetBSDName(diskRef));
        children = [[NSMutableSet alloc] init];
        _diskDescription = DADiskCopyDescription(diskRef);

        //		CFShow(description);

        if (self.isWholeDisk == NO) {

            DADiskRef parentRef = DADiskCopyWholeDisk(diskRef);
            if (parentRef) {
                NBCDisk *parentDisk = [NBCDisk uniqueDiskForDADisk:parentRef create:shouldCreateParent];
                if (parentDisk) {
                    parent = parentDisk; // weak reference
                    [[parent mutableSetValueForKey:NSStringFromSelector(@selector(children))] addObject:self];
                }
                CFRelease(parentRef);
            }
        }
        [uniqueDisks addObject:self];
    }

    return self;
}

- (NSUInteger)hash {
    if (_disk != nil) {
        return CFHash(_disk);
    } else {
        NSLog(@"***** DISK IS NULL *****");
        return 0;
    }
}

- (BOOL)isEqual:(id)object {
    if (_disk != nil) {
        return (CFHash(_disk) == [object hash]);
    } else {
        NSLog(@"***** DISK IS NULL *****");
        return NO;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ 0x%p %@>", self.class, self, BSDName];
}

- (void)mount {
    [self mountAtPath:nil withArguments:@[]];
}

- (void)mountAtPath:(NSString *)path withArguments:(NSArray *)args {
    NSAssert(self.isMountable, @"Disk isn't mountable.");
    NSAssert(self.isMounted == NO, @"Disk is already mounted.");

    self.isMounting = YES;

    // ensure arg list is NULL terminated
    CFStringRef *argv = calloc(args.count + 1, sizeof(CFStringRef));
    CFArrayGetValues((__bridge CFArrayRef)args, CFRangeMake(0, (CFIndex)args.count), (const void **)argv);

    NSURL *url = path ? [NSURL fileURLWithPath:path.stringByExpandingTildeInPath] : NULL;

    DADiskMountWithArguments((DADiskRef)_disk, (__bridge CFURLRef)url, kDADiskMountOptionDefault, DiskMountCallback, (__bridge void *)(self), (CFStringRef *)argv);

    free(argv);
}

- (void)unmountWithOptions:(NSUInteger)options {
    NSAssert(self.isMountable, @"Disk isn't mountable.");
    NSAssert(self.isMounted, @"Disk isn't mounted.");

    DADiskUnmount((DADiskRef)_disk, (DADiskUnmountOptions)options, DiskUnmountCallback, (__bridge void *)(self));
}

- (void)eject {
    NSAssert1(self.isEjectable, @"Disk is not ejectable: %@", self);

    DADiskEject((DADiskRef)_disk, kDADiskEjectOptionDefault, DiskEjectCallback, (__bridge void *)(self));
}

- (void)diskDidDisappear {
    [uniqueDisks removeObject:self];
    [[parent mutableSetValueForKey:NSStringFromSelector(@selector(children))] removeObject:self];

    CFRelease(_disk);
    _disk = NULL;

    self.parent = nil;
    [children removeAllObjects];
}

- (NSString *)uuid {
    CFUUIDRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaUUIDKey) : NULL;
    NSString *uuid;
    if (value) {
        CFStringRef string = CFUUIDCreateString(NULL, value);
        uuid = (__bridge NSString *)(string);
        CFRelease(string);
    }

    return (uuid);
}

- (NSURL *)volumeURL {
    CFURLRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumePathKey) : NULL;

    return (__bridge NSURL *)(value);
}

- (NSString *)deviceModel {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionDeviceModelKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSString *)deviceProtocol {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionDeviceProtocolKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSString *)devicePath {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionDevicePathKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSString *)volumeName {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumeNameKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSString *)mediaName {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaNameKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSNumber *)mediaSize {
    CFNumberRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaSizeKey) : NULL;

    return (__bridge NSNumber *)(value);
}

- (BOOL)isMountable {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumeMountableKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isMounted {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumePathKey) : NULL;

    return value ? YES : NO;
}

- (BOOL)isWholeDisk {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaWholeKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isLeaf {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaLeafKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isNetworkVolume {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumeNetworkKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isInternal {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionDeviceInternalKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isWritable {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaWritableKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isEjectable {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaEjectableKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (BOOL)isRemovable {
    CFBooleanRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaRemovableKey) : NULL;

    return value ? (BOOL)CFBooleanGetValue(value) : NO;
}

- (NSString *)type {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaTypeKey) : NULL;

    return (__bridge NSString *)(value);
}

- (NSString *)kind {
    CFStringRef value = _diskDescription ? CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaKindKey) : NULL;

    return (__bridge NSString *)(value);
}

- (BOOL)isFileSystemWritable {
    BOOL retval = NO;
    struct statfs fsstat;
    CFURLRef mountPath;
    UInt8 fsrep[MAXPATHLEN];

    // if the media is not writable, the file system cannot be either
    if (self.isWritable == NO)
        return NO;

    mountPath = CFDictionaryGetValue(_diskDescription, kDADiskDescriptionVolumePathKey);
    if (mountPath) {

        if (CFURLGetFileSystemRepresentation(mountPath, true, fsrep, sizeof(fsrep))) {

            if (statfs((char *)fsrep, &fsstat) == 0)
                retval = (fsstat.f_flags & MNT_RDONLY) ? NO : YES;
        }
    }

    return retval;
}

- (void)setDiskDescription:(CFDictionaryRef)desc {
    NSAssert(desc, @"A NULL disk description is not allowed.");

    if (desc != _diskDescription) {
        [self willChangeValueForKey:NSStringFromSelector(@selector(diskDescription))];

        CFRelease(_diskDescription);
        _diskDescription = CFRetain(desc);

        [self didChangeValueForKey:NSStringFromSelector(@selector(diskDescription))];
    }
}

- (CFDictionaryRef)diskDescription {
    return _diskDescription;
}

- (NSImage *)icon {
    if (!icon) {
        if (_diskDescription) {
            CFDictionaryRef iconRef = CFDictionaryGetValue(_diskDescription, kDADiskDescriptionMediaIconKey);
            if (iconRef) {

                CFStringRef identifier = CFDictionaryGetValue(iconRef, CFSTR("CFBundleIdentifier"));
                NSURL *url = (__bridge NSURL *)KextManagerCreateURLForBundleIdentifier(kCFAllocatorDefault, identifier);
                if (url) {
                    NSString *bundlePath = [url path];

                    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
                    if (bundle) {
                        NSString *filename = (NSString *)CFDictionaryGetValue(iconRef, CFSTR("IOBundleResourceFile"));
                        NSString *basename = [filename stringByDeletingPathExtension];
                        NSString *fileext = [filename pathExtension];

                        NSString *path = [bundle pathForResource:basename ofType:fileext];
                        if (path) {
                            icon = [[NSImage alloc] initWithContentsOfFile:path];
                        }
                    } else {
                        CFShow(_diskDescription);
                    }
                } else {
                    CFShow(_diskDescription);
                }
            }
        }
    }

    return icon;
}

@end
