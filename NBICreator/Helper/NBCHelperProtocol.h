//
//  NBCHelperProtocol.h
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

@class NBCTarget;

@protocol NBCHelperProtocol <NSObject>

@required

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCHelperProtocol Workflow Authorization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)authorizeWorkflowCasper:(NSData *)authData withReply:(void (^)(NSError *error))reply;

- (void)authorizeWorkflowDeployStudio:(NSData *)authData withReply:(void (^)(NSError *error))reply;

- (void)authorizeWorkflowImagr:(NSData *)authData withReply:(void (^)(NSError *error))reply;

- (void)authorizeWorkflowNetInstall:(NSData *)authData withReply:(void (^)(NSError *error))reply;

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCHelperProtocol Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addUsersToVolumeAtPath:(NSString *)nbiVolumePath
                 userShortName:(NSString *)userShortName
                  userPassword:(NSString *)userPassword
                 authorization:(NSData *)authData
                     withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)blessUSBVolumeAtURL:(NSURL *)usbVolumeURL label:(NSString *)label authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)copyExtractedResourcesToCache:(NSString *)cachePath
                          regexString:(NSString *)regexString
                      temporaryFolder:(NSString *)temporaryFolder
                        authorization:(NSData *)authData
                            withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)copyResourcesToVolume:(NSURL *)volumeURL copyArray:(NSArray *)copyArray authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)createNetInstallWithArguments:(NSArray *)arguments authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)createRestoreFromSourcesWithArguments:(NSArray *)arguments authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)disableSpotlightOnVolume:(NSString *)volumePath authorization:(NSData *)authData withReply:(void (^)(NSError *, int))reply;

- (void)extractResourcesFromPackageAtPath:(NSString *)packagePath
                             minorVersion:(NSInteger)minorVersion
                          temporaryFolder:(NSString *)temporaryFolder
                   temporaryPackageFolder:(NSString *)temporaryPackageFolder
                            authorization:(NSData *)authData
                                withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)getVersionWithReply:(void (^)(NSString *version))reply;

- (void)installPackage:(NSString *)packagePath
      targetVolumePath:(NSString *)targetVolumePath
               choices:(NSDictionary *)choices
         authorization:(NSData *)authData
             withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL modificationsArray:(NSArray *)modificationsArray authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)partitionDiskWithBSDName:(NSString *)bsdName volumeName:(NSString *)volumeName authorization:(NSData *)authData withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)readSettingsFromNBI:(NSURL *)nbiVolumeURL settingsDict:(NSDictionary *)settingsDict withReply:(void (^)(NSError *error, BOOL success, NSDictionary *newSettingsDict))reply;

- (void)removeItemsAtPaths:(NSArray *)itemPaths withReply:(void (^)(NSError *error, BOOL success))reply;

- (void)sysBuilderWithArguments:(NSArray *)arguments
             sourceVersionMinor:(int)sourceVersionMinor
                selectedVersion:(NSString *)selectedVersion
                  authorization:(NSData *)authData
                      withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)updateKernelCache:(NSString *)targetVolumePath
            nbiVolumePath:(NSString *)nbiVolumePath
             minorVersion:(NSString *)minorVersion
            authorization:(NSData *)authData
                withReply:(void (^)(NSError *error, int terminationStatus))reply;

- (void)quitHelper:(void (^)(BOOL success))reply;

@end
