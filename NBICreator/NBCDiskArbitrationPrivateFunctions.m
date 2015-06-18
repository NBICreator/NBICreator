//
//  NBCDiskArbitrationPrivateFunctions.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  This is an ARC version of DiskArbitrationPrivateFunctions.m created by Aaron Burghardt
//  https://github.com/aburgh/Disk-Arbitrator

#import "NBCDiskArbitrationPrivateFunctions.h"

// Globals
NSMutableSet *uniqueDisks;
DASessionRef session;

void InitializeDiskArbitration(void) {
    static BOOL isInitialized = NO;
    
    if (isInitialized) return;
    
    isInitialized = YES;
    
    uniqueDisks = [[NSMutableSet alloc] init];
    
    session = DASessionCreate(kCFAllocatorDefault);
    if (!session) {
        [NSException raise:NSInternalInconsistencyException format:@"Failed to create Disk Arbitration session."];
        return;
    }
    
    DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    CFMutableDictionaryRef matching = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryAddValue(matching, kDADiskDescriptionVolumeNetworkKey, kCFBooleanFalse);
    
    DARegisterDiskAppearedCallback(session, matching, DiskAppearedCallback, (__bridge void *)([NBCDisk class]));
    DARegisterDiskDisappearedCallback(session, matching, DiskDisappearedCallback, (__bridge void *)([NBCDisk class]));
    DARegisterDiskDescriptionChangedCallback(session, matching, NULL, DiskDescriptionChangedCallback, (__bridge void *)([NBCDisk class]));
    
    CFRelease(matching);
}

BOOL NBCDiskValidate(DADiskRef diskRef) {
    //
    // Reject certain disk media
    //
    
    BOOL isOK = YES;
    
    // Reject if no BSDName
    if (DADiskGetBSDName(diskRef) == NULL)
        [NSException raise:NSInternalInconsistencyException format:@"Disk without BSDName"];
    //		return NO;
    
    CFDictionaryRef desc = DADiskCopyDescription(diskRef);
    	//CFShow(desc);
    
    // Reject if no key-value for Whole Media
    CFBooleanRef wholeMediaValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaWholeKey);
    if (isOK && !wholeMediaValue) isOK = NO;
    
    // If not a whole disk, then must be a media leaf
    if (isOK && CFBooleanGetValue(wholeMediaValue) == false) {
        CFBooleanRef mediaLeafValue = CFDictionaryGetValue(desc, kDADiskDescriptionMediaLeafKey);
        if (!mediaLeafValue || CFBooleanGetValue(mediaLeafValue) == false) isOK = NO;
    }
    CFRelease(desc);
    
    return isOK;
}

void DiskAppearedCallback(DADiskRef diskRef, void *context) {
    if (context != (__bridge void *)([NBCDisk class])) return;
    
    if (NBCDiskValidate(diskRef))
    {
       NBCDisk *disk = [NBCDisk uniqueDiskForDADisk:diskRef create:YES];
        [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAppearNotification object:disk];
    }
}

void DiskDisappearedCallback(DADiskRef diskRef, void *context) {
    if (context != (__bridge void *)([NBCDisk class])) return;
    
    NBCDisk *tmpDisk = [NBCDisk uniqueDiskForDADisk:diskRef create:NO];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidDisappearNotification object:tmpDisk];
    
    [tmpDisk diskDidDisappear];
}

void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context) {
#pragma unused(keys)
    if (context != (__bridge void *)([NBCDisk class])) return;

    NSSet *uniqueDisksCopy = uniqueDisks;
    for ( NBCDisk *disk in uniqueDisksCopy ) {
        if ( CFHash(diskRef) == [disk hash] ) {
            CFDictionaryRef desc = DADiskCopyDescription(diskRef);
            disk.diskDescription = desc;
            CFRelease(desc);
            
            [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidChangeNotification object:disk];
        }
    }
    //CFRelease(diskRef);
}

void DiskMountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context) {
    #pragma unused(diskRef)
    //	Disk *disk = (Disk *)context;
    NSMutableDictionary *info = nil;
    
    if (dissenter) {
        DAReturn status = DADissenterGetStatus(dissenter);
        
        NSString *statusString = (__bridge NSString *) DADissenterGetStatusString(dissenter);
        if (!statusString)
            statusString = [NSString stringWithFormat:@"%@: %#x", NSLocalizedString(@"Dissenter status code", nil), status];
        
        info = [NSMutableDictionary dictionary];
        info[NSLocalizedFailureReasonErrorKey] = statusString;
        info[DAStatusErrorKey] = @(status);
    }
    else {
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptMountNotification object:(__bridge id)(context) userInfo:info];
}

void DiskUnmountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context) {
    #pragma unused(diskRef)
    NSDictionary *info = nil;
    
    if (dissenter) {
        DAReturn status = DADissenterGetStatus(dissenter);
        
        NSString *statusString = (__bridge NSString *) DADissenterGetStatusString(dissenter);
        if (!statusString)
            statusString = [NSString stringWithFormat:@"Error code: %d", status];
        
        info = @{
                 DAStatusErrorKey : @(status),
                 NSLocalizedFailureReasonErrorKey : statusString,
                 NSLocalizedRecoverySuggestionErrorKey : statusString
                 };
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptUnmountNotification object:(__bridge id)(context) userInfo:info];
}

void DiskEjectCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context) {
    #pragma unused(diskRef)
    NSDictionary *info = nil;
    
    if (dissenter) {
        DAReturn status = DADissenterGetStatus(dissenter);
        
        NSString *statusString = (__bridge NSString *) DADissenterGetStatusString(dissenter);
        if (!statusString)
            statusString = [NSString stringWithFormat:@"Error code: %d", status];
        
        info = @{
                 DAStatusErrorKey : @(status),
                 NSLocalizedFailureReasonErrorKey : statusString,
                 NSLocalizedRecoverySuggestionErrorKey : statusString
                 };
    }
    else {
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DADiskDidAttemptEjectNotification object:(__bridge id)(context) userInfo:info];
}

NSString * const DADiskDidAppearNotification = @"DADiskDidAppearNotification";
NSString * const DADiskDidDisappearNotification = @"DADiskDidDisppearNotification";
NSString * const DADiskDidChangeNotification = @"DADiskDidChangeNotification";
NSString * const DADiskDidAttemptMountNotification = @"DADiskDidAttemptMountNotification";
NSString * const DADiskDidAttemptUnmountNotification = @"DADiskDidAttemptUnmountNotification";
NSString * const DADiskDidAttemptEjectNotification = @"DADiskDidAttemptEjectNotification";

NSString * const DAStatusErrorKey = @"DAStatusErrorKey";
