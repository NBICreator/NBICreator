//
//  NBCDiskImageController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-25.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCDisk;

@protocol NBCDiskImageDelegate
@optional
- (void)diskImageOperationStatus:(BOOL)status imageInfo:(NSDictionary *)imageInfo;
@end

@interface NBCDiskImageController : NSObject {
    id _delegate;
}

- (id)initWithDelegate:(id<NBCDiskImageDelegate>)delegate;

// Attaching
+ (BOOL)attachDiskImageAndReturnPropertyList:(id *)propertyList dmgPath:(NSURL *)dmgPath options:(NSArray *)options error:(NSError **)error;
+ (BOOL)attachDiskImageVolumeByOffsetAndReturnPropertyList:(id *)propertyList dmgPath:(NSURL *)dmgPath options:(NSArray *)options offset:(NSString *)offset error:(NSError **)error;

// Mounting
+ (BOOL)mountDiskImageVolumeByDeviceAndReturnMountURL:(id *)mountURL deviceName:(NSString *)devName error:(NSError **)error;

// Detaching
+ (BOOL)detachDiskImageAtPath:(NSString *)mountPath;
+ (BOOL)detachDiskImageDevice:(NSString *)devName;

// Unmounting
+ (BOOL)unmountVolumeAtPath:(NSString *)mountPath;

// Resizing
+ (BOOL)resizeDiskImageAtURL:(NSURL *)diskImageURL shadowImagePath:(NSString *)shadowImagePath;

// Converting
+ (BOOL)convertDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath;
+ (BOOL)compactDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath;

// Getting information
+ (BOOL)getOffsetForRecoveryPartitionOnImageDevice:(id *)offset diskIdentifier:(NSString *)diskIdentifier;
+ (NSURL *)getMountURLFromHdiutilOutputPropertyList:(NSDictionary *)propertyList;
+ (NSString *)getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:(NSDictionary *)propertyList;
+ (NSString *)getRecoveryPartitionIdentifierFromVolumeMountURL:(NSURL *)mountURL;
+ (BOOL)mountAtPath:(NSString *)path withArguments:(NSArray *)args forDisk:(NSString *)diskID;
+ (NSURL *)getDiskImageURLFromMountURL:(NSURL *)mountURL;
+ (NBCDisk *)checkDiskImageAlreadyMounted:(NSURL *)diskImageURL imageType:(NSString *)imageType;

@end
