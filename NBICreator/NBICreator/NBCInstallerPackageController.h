//
//  NBCInstallerPackageController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NBCInstallerPackageDelegate
- (void)installSuccessful;
- (void)installFailed;
@end

@interface NBCInstallerPackageController : NSObject

@property id delegate;

@property NSURL *volumeURL;
@property NSMutableArray *packagesQueue;

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate;
- (void)installPackagesToVolume:(NSURL *)volumeURL packages:(NSArray *)packages;

@end
