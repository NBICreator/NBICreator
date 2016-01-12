//
//  NBCDiskImageController.h
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <Foundation/Foundation.h>
@class NBCDisk;
@class NBCTarget;
@class NBCSource;

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
+ (BOOL)attachNetInstallDiskImageWithShadowFile:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error;
+ (BOOL)attachBaseSystemDiskImageWithShadowFile:(NSURL *)baseSystemDiskImageURL target:(NBCTarget *)target error:(NSError **)error;
+ (BOOL)attachDiskImageAtURL:(NSURL *)diskImageURL shadowPath:(NSString *)shadowPath error:(NSError **)error;

// Verifying
+ (BOOL)verifyInstallESDDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source error:(NSError **)error;
+ (BOOL)verifyBaseSystemDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source error:(NSError **)error;
+ (BOOL)verifySystemDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source requireRecoveryPartition:(BOOL)requireRecoveryPartition error:(NSError **)error;
+ (BOOL)verifyNBINetInstallDiskImage:(NSURL *)diskImageURL source:(NBCSource *)source target:(NBCTarget *)target error:(NSError **)error;

// Mounting
+ (BOOL)mountDiskImageVolumeByDeviceAndReturnMountURL:(id *)mountURL deviceName:(NSString *)devName error:(NSError **)error;

// Detaching
+ (BOOL)detachDiskImageAtPath:(NSString *)mountPath;
+ (BOOL)detachDiskImageDevice:(NSString *)devName;

// Unmounting
+ (BOOL)unmountVolumeAtPath:(NSString *)mountPath;

// Resizing
+ (BOOL)resizeDiskImageAtURL:(NSURL *)diskImageURL diskImageSize:(NSNumber *)size shadowImagePath:(NSString *)shadowImagePath error:(NSError **)error;
+ (BOOL)resizeAndMountBaseSystemWithShadow:(NSURL *)baseSystemURL target:(NBCTarget *)target error:(NSError **)error;

// Converting
+ (BOOL)convertDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath format:(NSString *)format destinationPath:(NSString *)destinationPath;
+ (BOOL)compactDiskImageAtPath:(NSString *)diskImagePath shadowImagePath:(NSString *)shadowImagePath;

// Getting information
+ (BOOL)getOffsetForRecoveryPartitionOnImageDevice:(id *)offset diskIdentifier:(NSString *)diskIdentifier;
+ (NSURL *)getMountURLFromHdiutilOutputPropertyList:(NSDictionary *)propertyList;
+ (NSString *)getRecoveryPartitionIdentifierFromHdiutilOutputPropertyList:(NSDictionary *)propertyList;
+ (NSURL *)getDiskImageURLFromMountURL:(NSURL *)mountURL;
+ (NBCDisk *)checkDiskImageAlreadyMounted:(NSURL *)diskImageURL imageType:(NSString *)imageType;
+ (NSURL *)installESDURLfromInstallerApplicationURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error;
+ (NSURL *)netInstallURLFromNBI:(NSURL *)nbiURL source:(NBCSource *)source error:(NSError **)error;

@end
