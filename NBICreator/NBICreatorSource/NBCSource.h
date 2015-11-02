//
//  NBCSource.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-25.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCDisk.h"

// ------------------------------------------------------
//  Source Type Constants
// ------------------------------------------------------
extern NSString *const NBCSourceTypeInstallerApplication;
extern NSString *const NBCSourceTypeInstallESDDiskImage;
extern NSString *const NBCSourceTypeSystemDiskImage;
extern NSString *const NBCSourceTypeSystemDisk;
extern NSString *const NBCSourceTypeNBI;
extern NSString *const NBCSourceTypeUnknown;

@interface NBCSource : NSObject

// ------------------------------------------------------
//  Source
// ------------------------------------------------------
@property NSURL *sourceURL;
@property NSString *sourceVersion;
@property NSString *sourceBuild;
@property NSString *sourceType;
@property NSString *sourceMenuName;

// Installer Application
@property NSURL *osxInstallerURL;           // Path to installer application .app
@property NSURL *osxInstallerIconURL;

// Source System
@property NBCDisk *systemDisk;
@property NSURL *systemDiskImageURL;        // Path to system disk image .dmg
@property NSURL *systemVolumeURL;           // Path to mounted system volume
@property NSDictionary *systemDiskImageDict;
@property NSString *systemOSVersion;
@property NSString *systemOSBuild;
@property NSString *systemVolumeBSDIdentifier;

// Source Recovery
@property NBCDisk *recoveryDisk;
@property NSURL *recoveryDiskImageURL;        // Path to system disk image .dmg
@property NSURL *recoveryVolumeURL;         // Path to mounted recovery volume
@property NSDictionary *recoveryDiskImageDict;
@property NSString *recoveryVolumeBSDIdentifier;

// Source BaseSystem
@property NBCDisk *baseSystemDisk;
@property NSURL *baseSystemDiskImageURL;             // Path to BaseSystem.dmg
@property NSURL *baseSystemVolumeURL;       // Path to mounted base system volume
@property NSDictionary *baseSystemDiskImageDict;
@property NSString *baseSystemOSVersion;
@property NSString *baseSystemOSBuild;
@property NSString *baseSystemVolumeBSDIdentifier;

// Disk Image ESD
@property NBCDisk *installESDDisk;
@property NSURL *installESDDiskImageURL;    // Path to disk image esd .dmg
@property NSURL *installESDVolumeURL;
@property NSDictionary *installESDDiskImageDict;
@property NSString *installESDVolumeBSDIdentifier;

// NBI
@property NSDictionary *nbImageInfo;
@property NSURL *nbImageInfoURL;

// Methods
- (id)initWithSourceType:(NSString *)sourceType;
- (BOOL)detachImage;
- (BOOL)unmountImage;
- (BOOL)detachRecoveryHD;
- (BOOL)unmountRecoveryHD;
- (BOOL)detachBaseSystem;
- (BOOL)unmountBaseSystem;
- (BOOL)detachAll;
- (void)printAllVariables;
- (NSString *)expandVariables:(NSString *)string;
- (NSImage *)productImageForOSVersion:(NSString *)osVersion;

@end
