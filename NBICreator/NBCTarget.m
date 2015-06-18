//
//  NBCTarget.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCTarget.h"

@implementation NBCTarget

- (void)printAllVariables
{
    NSLog(@"resourcesNetInstallDict=%@", _resourcesNetInstallDict);
    NSLog(@"resourcesBaseSystemDict=%@", _resourcesBaseSystemDict);
    NSLog(@"nbiNetInstallDisk=%@", _nbiNetInstallDisk);
    NSLog(@"nbiNetInstallURL=%@", _nbiNetInstallURL);
    NSLog(@"nbiNetInstallVolumeURL=%@", _nbiNetInstallVolumeURL);
    NSLog(@"nbiNetInstallDiskImageDict=%@", _nbiNetInstallDiskImageDict);
    NSLog(@"nbiNetInstallVolumeBSDIdentifier=%@", _nbiNetInstallVolumeBSDIdentifier);
    NSLog(@"baseSystemDisk=%@", _baseSystemDisk);
    NSLog(@"baseSystemURL=%@", _baseSystemURL);
    NSLog(@"baseSystemVolumeURL=%@", _baseSystemVolumeURL);
    NSLog(@"baseSystemDiskImageDict=%@", _baseSystemDiskImageDict);
    NSLog(@"baseSystemVolumeBSDIdentifier=%@", _baseSystemVolumeBSDIdentifier);
}

@end
