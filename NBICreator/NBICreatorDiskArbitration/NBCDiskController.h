//
//  NBCDiskController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-29.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCDisk;
@class NBCSource;

@interface NBCDiskController : NSObject

+ (BOOL)verifySystemDisk:(NBCDisk *)disk source:(NBCSource *)source requireRecoveryPartition:(BOOL)requireRecoveryPartition error:(NSError **)error;
+ (NSString *)getRecoveryPartitionIdentifierFromVolumeURL:(NSURL *)volumeURL;
+ (BOOL)mountAtPath:(NSString *)path arguments:(NSArray *)args diskIdentifier:(NSString *)diskIdentifier;

+ (NSArray *)mountedDiskUUUIDs;
+ (NBCDisk *)diskFromBSDName:(NSString *)bsdName;
+ (NBCDisk *)diskFromVolumeURL:(NSURL *)volumeURL;

@end
