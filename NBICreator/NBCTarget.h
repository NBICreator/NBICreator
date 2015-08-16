//
//  NBCTarget.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NBCDisk.h"

@interface NBCTarget : NSObject

@property NSDictionary *resourcesNetInstallDict;
@property NSDictionary *resourcesBaseSystemDict;

@property NSString *creationTool;

@property NSURL *nbiURL;
@property BOOL imagrApplicationExistOnTarget;
@property NSURL *imagrApplicationURL;
@property NSURL *imagrConfigurationPlistURL;
@property NSURL *rcImagingURL;
@property NSString *rcImagingContent;

// Source NBI NetInstall
@property NBCDisk *nbiNetInstallDisk;
@property NSURL *nbiNetInstallURL;
@property NSString *nbiNetInstallShadowPath;
@property NSURL *nbiNetInstallVolumeURL;
@property NSDictionary *nbiNetInstallDiskImageDict;
@property NSString *nbiNetInstallVolumeBSDIdentifier;

// Soruce NBI BaseSystem
@property NBCDisk *baseSystemDisk;
@property NSURL *baseSystemURL;
@property NSString *baseSystemShadowPath;
@property NSURL *baseSystemVolumeURL;
@property NSDictionary *baseSystemDiskImageDict;
@property NSString *baseSystemVolumeBSDIdentifier;

- (void)printAllVariables;

@end
