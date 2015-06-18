//
//  NBCInstallerPackageController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NBCInstallerPackageDelegate
@optional
- (void)installSuccessful;
- (void)installFailed;
@end

@interface NBCInstallerPackageController : NSObject <NBCInstallerPackageDelegate> {
    id _delegate;
}

// -------------------------------------------------------------
//  Public Methods
// -------------------------------------------------------------
- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate;
- (BOOL)installPackageOnTargetVolume:(NSURL *)volumeURL packageURL:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML error:(NSError **)retError;

@end
