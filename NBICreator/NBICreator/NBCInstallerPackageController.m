//
//  NBCInstallerPackageController.m
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

#import "NBCInstallerPackageController.h"
#import "NBCConstants.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCInstallerPackageController

- (id)initWithDelegate:(id<NBCInstallerPackageDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)installPackagesToVolume:(NSURL *)volumeURL packages:(NSArray *)packages {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"volumeURL=%@", volumeURL);
    DDLogDebug(@"packages=%@", packages);
    if ( [packages count] != 0 ) {
        [self setVolumeURL:volumeURL];
        [self setPackagesQueue:[[NSMutableArray alloc] initWithArray:packages]];
        [self runPackageQueue];
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installSuccessfulForPackage:(NSURL *)packageURL {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"%@ installed successfully!", [packageURL lastPathComponent]);
    [_packagesQueue removeObjectAtIndex:0];
    [self runPackageQueue];
}

- (void)runPackageQueue {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( [_packagesQueue count] != 0 ) {
        NSDictionary *packageDict = [_packagesQueue firstObject];
        NSLog(@"packageDict=%@", packageDict);
        if ( [packageDict count] != 0 ) {
            NSString *packageName = packageDict[NBCWorkflowInstallerName];
            NSLog(@"packageName=%@", packageName);
            NSString *packageSourcePath = packageDict[NBCWorkflowInstallerSourceURL];
            NSLog(@"packageSourcePath=%@", packageSourcePath);
            if ( [packageSourcePath length] != 0 ) {
                NSURL *packageURL = [NSURL fileURLWithPath:packageSourcePath];
                NSLog(@"packageURL=%@", packageURL);
                NSDictionary *packageChoiceChangeXML = packageDict[NBCWorkflowInstallerChoiceChangeXML];
                NSLog(@"packageChoiceChangeXML=%@", packageChoiceChangeXML);
                //[_delegate updateProgressStatus:[NSString stringWithFormat:@"Installing %@ to BaseSystem.dmg...", packageName] workflow:self];
                [self installPackageOnTargetVolume:_volumeURL packageURL:packageURL choiceChangesXML:packageChoiceChangeXML];
            }
        }
    } else {
        [_delegate installSuccessful];
    }
}

- (void)installPackageOnTargetVolume:(NSURL *)volumeURL packageURL:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"volumeURL=%@", volumeURL);
    DDLogDebug(@"packageURL=%@", packageURL);
    DDLogDebug(@"choiceChangesXML=%@", choiceChangesXML);
    DDLogInfo(@"Installing %@ on volume %@...", [packageURL lastPathComponent], [volumeURL path]);
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/installer"];
    NSMutableArray *installerArguments = [[NSMutableArray alloc] initWithObjects:
                                          @"-verboseR",
                                          @"-allowUntrusted",
                                          @"-plist",
                                          nil];

    if ( choiceChangesXML ) {
        [installerArguments addObject:@"-applyChoiceChangesXML"];
        [installerArguments addObject:choiceChangesXML];
    }
    
    if ( packageURL ) {
        [installerArguments addObject:@"-package"];
        [installerArguments addObject:[packageURL path]];
    } else {
        DDLogError(@"[ERROR] No package URL passed!");
        if ( [self->_delegate respondsToSelector:@selector(installFailed:)] ) {
            [self->_delegate installFailed:nil];
        }
        return;
    }
    
    if ( volumeURL ) {
        [installerArguments addObject:@"-target"];
        [installerArguments addObject:[volumeURL path]];
    } else {
        DDLogError(@"[ERROR] No volume URL passed!");
        [self->_delegate installFailed:nil];
        return;
    }
    
    DDLogDebug(@"%@ %@", commandURL, installerArguments);
    
    // -----------------------------------------------------------------------------------
    //  Create standard output file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                        NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        
                                        DDLogDebug(@"[installer] %@", outStr);
                                        
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // -----------------------------------------------------------------------------------
    //  Create standard error file handle and register for data available notifications.
    // -----------------------------------------------------------------------------------
    
    NSPipe *stdErr = [[NSPipe alloc] init];
    NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                        NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                        
                                        DDLogError(@"[installer][ERROR] %@", errStr);
                                        
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        DDLogError(@"[installer][ERROR] %@", proxyError);
        [nc removeObserver:stdOutObserver];
        [nc removeObserver:stdErrObserver];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:@{ NBCUserInfoNSErrorKey : proxyError }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:installerArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        DDLogDebug(@"terminationStatus=%d", terminationStatus);
        if ( terminationStatus == 0 ) {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self installSuccessfulForPackage:packageURL];
        } else {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self->_delegate installFailed:error];
        }
    }];
}

@end
