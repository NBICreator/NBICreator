//
//  NBCDiskArbitrator.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-06.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <DiskArbitration/DiskArbitration.h>
#import <Foundation/Foundation.h>

// Mount Modes
#define MM_BLOCK 0
#define MM_READONLY 1

@interface NBCDiskArbitrator : NSObject

@property (strong) NSMutableSet *disks;
@property (readonly) NSSet *wholeDisks;
@property NSInteger mountMode;

- (BOOL)registerSession;
- (void)unregisterSession;
+ (id)sharedArbitrator;

@end
