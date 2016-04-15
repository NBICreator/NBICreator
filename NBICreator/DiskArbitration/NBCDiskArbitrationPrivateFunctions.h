//
//  NBCDiskArbitrationPrivateFunctions.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  This is an ARC version of DiskArbitrationPrivateFunctions.h created by Aaron Burghardt
//  https://github.com/aburgh/Disk-Arbitrator

#import "NBCDisk.h"
#import <DiskArbitration/DiskArbitration.h>
#import <Foundation/Foundation.h>

void InitializeDiskArbitration(void);
BOOL NBCDiskValidate(DADiskRef diskRef);
void DiskAppearedCallback(DADiskRef diskRef, void *context);
void DiskDisappearedCallback(DADiskRef diskRef, void *context);
void DiskDescriptionChangedCallback(DADiskRef diskRef, CFArrayRef keys, void *context);
void DiskMountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context);
void DiskUnmountCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context);
void DiskEjectCallback(DADiskRef diskRef, DADissenterRef dissenter, void *context);

@interface NBCDisk (DiskPrivate)

+ (id)uniqueDiskForDADisk:(DADiskRef)diskRef create:(BOOL)create;

- (id)initWithDADisk:(DADiskRef)diskRef shouldCreateParent:(BOOL)shouldCreateParent;
- (void)refreshFromDescription;
- (void)diskDidDisappear;

@end

extern NSMutableSet *uniqueDisks;
