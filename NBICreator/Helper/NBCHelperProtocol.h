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

- (void)disableSpotlightOnVolume:(NSString *)volumePath
                       withReply:(void (^)(NSError *, int))reply;

- (void)getVersionWithReply:(void(^)(NSString * version))reply;

- (void)installPackage:(NSString *)packagePath
          targetVolume:(NSString *)targetVolume
               choices:(NSDictionary *)choice
             withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)updateKernelCache:(NSString *)targetVolumePath
            nbiVolumePath:(NSString *)nbiVolumePath
             minorVersion:(NSString *)minorVersion
                withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)quitHelper:(void (^)(BOOL success))reply;











// OLD METHODS


- (void)runTaskWithCommand:(NSString *)command
                 arguments:(NSArray *)arguments
          currentDirectory:(NSString *)currentDirectory
      environmentVariables:(NSDictionary *)environmentVariables
                 withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                   authorization:(NSData *)authData
                       withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
                currentDirectory:(NSString *)currentDirectory
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                       withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
            environmentVariables:(NSDictionary *)environmentVariables
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                       withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)testCommandWithReply:(NSURL *)commandURL
               withArguments:(NSArray *)arguments
        outputPipeFileHandle:(NSFileHandle *)outputPipeFileHandle
                   withReply:(void(^)(int returnStatus))reply;

- (void)copyResourcesToVolume:(NSURL *)volumeURL
                    copyArray:(NSArray *)copyArray
                    withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)copyResourcesToVolume:(NSURL *)volumeURL
                resourcesDict:(NSDictionary *)resourcesDict
                    withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL
             resourcesDictArray:(NSArray *)modifyDictArray
                      withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL
             modificationsArray:(NSArray *)modificationsArray
                      withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)removeItemsAtPaths:(NSArray *)itemPaths
                 withReply:(void(^)(NSError *error, BOOL success))reply;

- (void)removeItemAtURL:(NSURL *)itemURL
              withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)readSettingsFromNBI:(NSURL *)nbiVolumeURL settingsDict:(NSDictionary *)settingsDict withReply:(void(^)(NSError *error, BOOL success, NSDictionary *newSettingsDict))reply;


@end
