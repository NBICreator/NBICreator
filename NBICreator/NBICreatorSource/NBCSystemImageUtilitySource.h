//
//  NBCSystemImageUtilitySource.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-15.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCSystemImageUtilitySource : NSObject

@property NSString *systemImageUtilityVersion;
@property NSString *siuFoundationVersion;
@property NSString *siuAgentVersion;

@property NSString *selectedVersion;

@property NSURL *systemImageUtilityURL;
@property NSURL *siuFoundationFrameworkURL;
@property NSURL *siuAgentXPCURL;

@property NSURL *createCommonURL;
@property NSURL *createNetBootURL;
@property NSURL *createNetInstallURL;
@property NSURL *createRestoreFromSourcesURL;
@property NSURL *addBSDPSourcesURL;
@property NSURL *asrInstallPkgURL;
@property NSURL *asrFromVolumeURL;
@property NSURL *installConfigurationProfiles;
@property NSURL *netInstallConfigurationProfiles;
@property NSURL *postInstallPackages;
@property NSURL *preserveInstallLog;
@property NSURL *netBootClientHelper;
@property NSURL *netBootClientHelperPlist;

- (NSString *)expandVariables:(NSString *)string;
+ (NSArray *)systemImageUtilityVersions;

@end
