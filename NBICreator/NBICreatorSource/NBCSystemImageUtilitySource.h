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

- (NSString *)expandVariables:(NSString *)string;
+ (NSArray *)systemImageUtilityVersions;

@end
