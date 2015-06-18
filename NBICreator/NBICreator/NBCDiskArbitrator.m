//
//  NBCDiskArbitrator.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDiskArbitrator.h"

#import "NBCDisk.h"
#import "NBCDiskArbitrationPrivateFunctions.h"

@implementation NBCDiskArbitrator

@synthesize disks;

+ (void)initialize {
    InitializeDiskArbitration();
}

+ (id)sharedArbitrator {
    static NBCDiskArbitrator *arbitrator = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        arbitrator = [[self alloc] init];
    });
    return arbitrator;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqual:@"wholeDisks"])
        return [NSSet setWithObject:@"disks"];
    
    return [super keyPathsForValuesAffectingValueForKey:key];
}

- (id)init {
    self = [super init];
    if (self) {
        disks = [[NSMutableSet alloc] init];
        [self registerSession];
    }
    return self;
}

- (void)dealloc {
    [self unregisterSession];
}

- (BOOL)registerSession {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self selector:@selector(diskDidAppear:) name:DADiskDidAppearNotification object:nil];
    [nc addObserver:self selector:@selector(diskDidDisappear:) name:DADiskDidDisappearNotification object:nil];
    [nc addObserver:self selector:@selector(diskDidChange:) name:DADiskDidChangeNotification object:nil];
    
    return YES;
}

- (void)unregisterSession {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)diskDidAppear:(NSNotification *)notif {
    NBCDisk *disk = notif.object;
    [self addDisksObject:disk];
    
    /*
    if (disk.isMountable && !disk.isMounted) {
        
        CFDictionaryRef desc = disk.diskDescription;
        NSString *volumeKindRef = (NSString *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeKindKey);
        
        // Arguments will be passed via the -o flag of mount. If the file system specific mount, e.g. mount_hfs,
        // supports additional flags that mount(8) doesn't, they can be passed to -o.  That feature is used to
        // pass -j to mount_hfs, which instructs HFS to ignore journal.  Normally, an HFS volume that
        // has a dirty journal will fail to mount read-only because the file system is inconsistent.  "-j" is
        // a work-around.
        
        NSArray *args;
        if ([volumeKindRef isEqual:@"hfs"])
            args = [NSArray arrayWithObjects:@"-j", @"rdonly", nil];
        else
            args = [NSArray arrayWithObjects:@"rdonly", nil];
        
        [disk mountAtPath:nil withArguments:args];
    }
     */
}

- (void)diskDidDisappear:(NSNotification *)notif {
    [self removeDisksObject:notif.object];
}

- (void)diskDidChange:(NSNotification *)notif {
    #pragma unused(notif)
    //NSLog(@"Changed disk notification: %@", notif.description);
}

- (NSSet *)wholeDisks {
    NSMutableSet *wholeDisks = [[NSMutableSet alloc] init];
    
    for ( NBCDisk *disk in disks )
        if ( disk.isWholeDisk )
            [wholeDisks addObject:disk];
    
    return wholeDisks;
}

#pragma mark Disks KVC Methods

- (NSUInteger)countOfDisks {
    return disks.count;
}

- (NSEnumerator *)enumeratorOfDisks {
    return [disks objectEnumerator];
}

- (NBCDisk *)memberOfDisks:(NBCDisk *)anObject {
    return [disks member:anObject];
}

- (void)addDisksObject:(NBCDisk *)object {
    [disks addObject:object];
}

- (void)addDisks:(NSSet *)objects {
    [disks unionSet:objects];
}

- (void)removeDisksObject:(NBCDisk *)anObject {
    [disks removeObject:anObject];
}

- (void)removeDisks:(NSSet *)objects {
    [disks minusSet:objects];
}

@end
