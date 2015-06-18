//
//  NBCHelperProtocol.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-17.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

@class NBCTarget;

@protocol NBCHelperProtocol

@required

- (void)getVersionWithReply:(void(^)(NSString * version))reply;

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
                resourcesDict:(NSDictionary *)resourcesDict
                    withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL
             resourcesDictArray:(NSArray *)modifyDictArray
                      withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)removeItemAtURL:(NSURL *)itemURL
              withReply:(void(^)(NSError *error, int terminationStatus))reply;

- (void)registerMainApplication:(void (^)(BOOL resign))resign;

- (void)sendMessageToMainApplication:(NSString *)message;

- (void)readSettingsFromNBI:(NSURL *)nbiVolumeURL settingsDict:(NSDictionary *)settingsDict withReply:(void(^)(NSError *error, BOOL success, NSDictionary *newSettingsDict))reply;

- (void)quitHelper:(void (^)(BOOL success))reply;
@end
