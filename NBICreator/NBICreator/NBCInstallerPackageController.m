//
//  NBCInstallerPackageController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

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
    NSLog(@"installPackagesToVolume");
    NSLog(@"volumeURL=%@", volumeURL);
    NSLog(@"packages=%@", packages);
    if ( [packages count] != 0 ) {
        [self setVolumeURL:volumeURL];
        _packagesQueue = [[NSMutableArray alloc] initWithArray:packages];
        [self runPackageQueue];
    }
}

- (void)installSuccessfulForPackage:(NSURL *)packageURL {
    DDLogInfo(@"%@ installed successfully!", [packageURL lastPathComponent]);
    [_packagesQueue removeObjectAtIndex:0];
    [self runPackageQueue];
}

- (void)runPackageQueue {
    NSLog(@"runPackageQueue");
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
    NSLog(@"installPackageOnTargetVolume");
    BOOL verified = YES;
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/usr/sbin/installer"];
    
    NSLog(@"commandURL=%@", commandURL);
    
    NSMutableArray *installerArguments;
    installerArguments = [[NSMutableArray alloc] initWithObjects:
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
        NSLog(@"No package URL passed!");
        verified = NO;
    }
    
    if ( volumeURL ) {
        [installerArguments addObject:@"-target"];
        [installerArguments addObject:[volumeURL path]];
    } else {
        NSLog(@"No volume URL passed!");
        verified = NO;
    }
    
    NSLog(@"installerArguments=%@", installerArguments);
    
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
                                                      
                                                      NSLog(@"stdout: %@", outStr);
                                                      
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
                                                      
                                                      NSLog(@"stderr: %@", errStr);
                                                      
                                                      [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                                  }];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        NSLog(@"ProxyError? %@", proxyError);
        [nc removeObserver:stdOutObserver];
        [nc removeObserver:stdErrObserver];
        NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        
    }] runTaskWithCommandAtPath:commandURL arguments:installerArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        
        if ( terminationStatus == 0 ) {
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [self installSuccessfulForPackage:packageURL];
            
        } else {
            NSLog(@"Pkg install failed!");
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            if ( [self->_delegate respondsToSelector:@selector(installFailed)] ) {
                [self->_delegate installFailed];
            }
        }
    }];
}

@end
