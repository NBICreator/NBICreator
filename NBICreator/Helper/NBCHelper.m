//
//  NBCHelper.m
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

#import "NBCHelper.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperAuthorization.h"
#import "NBCWorkflowProgressDelegate.h"
#import "SNTCodesignChecker.h"
#import <CommonCrypto/CommonDigest.h>
#import <syslog.h>
#import "NBCTarget.h"
#import "NBCConstants.h"
#import "FileHash.h"

static const NSTimeInterval kHelperCheckInterval = 1.0;

@interface NBCHelper () <NSXPCListenerDelegate, NBCHelperProtocol>

@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (readonly) NSXPCConnection *connection;
@property (weak) NSXPCConnection *relayConnection;
@property (strong, nonatomic) NSMutableArray *connections;
@property (nonatomic, assign) BOOL helperToolShouldQuit;

@end

@implementation NBCHelper {
    void (^_resign)(BOOL);
}

- (id)init {
    self = [super init];
    if (self != nil) {
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:NBCBundleIdentifierHelper];
        self->_listener.delegate = self;
        self->_connections = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)run {
    [_listener resume];
    while ( ! _helperToolShouldQuit ) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSXPCConnectionDelegate methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
#pragma unused(listener)
    
    // ----------------------------------------------------------------------------------------------------
    //  Only accept new connections from applications using the same codesigning certificate as the helper
    // ----------------------------------------------------------------------------------------------------
    if ( ! [self connectionIsValid:newConnection] ) {
        return NO;
    }
    
    // This is called by the XPC listener when there is a new connection.
    [newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCHelperProtocol)]];
    [newConnection setExportedObject:self];
    
    __weak typeof(newConnection) weakConnection = newConnection;
    [newConnection setInvalidationHandler:^() {
        if ( [weakConnection isEqualTo:_relayConnection] && _resign) {
            _resign(YES);
        }
        
        [self->_connections removeObject:weakConnection];
        if ( ! [self->_connections count] ) {
            [self quitHelper:^(BOOL success) {
            }];
        }
    }];
    
    [_connections addObject:newConnection];
    [newConnection resume];
    
    return YES;
} // listener

- (NSXPCConnection *)connection {
    return [_connections lastObject];
} // connection

- (BOOL)connectionIsValid:(NSXPCConnection *)connection {
    
    // --------------------------------------------
    //  Get PID of remote application (NBICreator)
    // --------------------------------------------
    pid_t pid = [connection processIdentifier];
    
    // --------------------------------------------------------------
    //  Instantiate codesign check for helper and remote application
    // --------------------------------------------------------------
    SNTCodesignChecker *selfCS = [[SNTCodesignChecker alloc] initWithSelf];
    SNTCodesignChecker *remoteCS = [[SNTCodesignChecker alloc] initWithPID:pid];
    
    // ---------------------------------------
    //  Get remote application using it's PID
    // ---------------------------------------
    NSRunningApplication *remoteApp = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    //syslog(0, "Remote App: %s", remoteApp.description.UTF8String);
    
    // ------------------------------------------------------------------------
    //  Verify that helper and remote application has matching code signatures
    // ------------------------------------------------------------------------
    return remoteApp && [remoteCS signingInformationMatches:selfCS];
} // connectionIsValid:

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSRunningApplication *)remoteApplication {
    return [NSRunningApplication runningApplicationWithProcessIdentifier:[[self connection] processIdentifier]];
} // remoteApplication

- (NSString *)remoteBundlePath {
    return [[[self remoteApplication] bundleURL] path];
} // remoteBundlePath

- (NSString *)remoteBundleResouresPath {
    return [[self remoteBundlePath] stringByAppendingPathComponent:@"Contents/Resources"];
} // remoteBundleResouresPath

- (NSString *)remoteBundleScriptsPath {
    return [[self remoteBundleResouresPath] stringByAppendingPathComponent:@"Scripts"];
} // remoteBundleScriptsPath

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCHelperProtocol methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addUsersToVolumeAtPath:(NSString *)nbiVolumePath
                 userShortName:(NSString *)userShortName
                  userPassword:(NSString *)userPassword
                     withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSError *err = nil;
    
    // -----------------------------------------------------------------------------------
    //  Verify script
    // -----------------------------------------------------------------------------------
    NSString *scriptPath = [[self remoteBundleScriptsPath] stringByAppendingPathComponent:@"createUser.bash"];
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying script path: %@", scriptPath]];
    if ( ! [[NSURL fileURLWithPath:scriptPath] checkResourceIsReachableAndReturnError:&err] ) {
        return reply(err, -1);
    }
    
    NSString *scriptMD5 = [FileHash md5HashOfFileAtPath:scriptPath];
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying script md5: %@", scriptMD5]];
    
    NSString *command = @"/bin/bash";
    NSArray *arguments = @[ scriptPath, nbiVolumePath, userShortName, userPassword, @"501", @"admin" ];
    
    [self runTaskWithCommand:command arguments:arguments currentDirectory:nil environmentVariables:nil withReply:reply];
} // addUsersToVolumeAtPath:userShortName:userPassword:withReply

- (void)copyExtractedResourcesToCache:(NSString *)cachePath
                         regexString:(NSString *)regexString
                     temporaryFolder:(NSString *)temporaryFolder
                           withReply:(void(^)(NSError *error, int terminationStatus))reply {
        
    NSString *command = @"/bin/bash";
    NSArray *arguments = @[ @"-c", [NSString stringWithFormat:@"/usr/bin/find -E . -depth %@ | /usr/bin/cpio -admp --quiet '%@'", regexString, cachePath]];
    
    [self runTaskWithCommand:command arguments:arguments currentDirectory:temporaryFolder environmentVariables:nil withReply:reply];
} // copyExtractedResourcesToCache:regexString:temporaryFolder:withReply

- (void)copyResourcesToVolume:(NSURL *)volumeURL
                    copyArray:(NSArray *)copyArray
                    withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary *regexDict = [[NSMutableDictionary alloc] init];
    
    for ( NSDictionary *copyDict in copyArray ) {
        
        // ----------------------------------------------------------------------
        //  Examine dict NBCWorkflowCopyType and proceed accordingly
        //
        //  Available copy types are:
        //
        //      NBCWorkflowCopy      = Standard source to target path copy
        //      NBCWorkflowCopyRegex = Copy all files matching regex from source
        // ----------------------------------------------------------------------
        NSString *copyType = copyDict[NBCWorkflowCopyType] ?: @"";
        
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            
            // ----------------------------------------------------------------------
            //  Remove item at target path if it exist
            //  Create target path if it doesn't exist
            // ----------------------------------------------------------------------
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            if ( [targetURLString length] != 0 ) {
                targetURL = [volumeURL URLByAppendingPathComponent:targetURLString];
                [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying target path: %@", [targetURL path]]];
                
                if ( [targetURL checkResourceIsReachableAndReturnError:nil] ) {
                    if ( ! [fm removeItemAtURL:targetURL error:&error] ) {
                        reply(error, 1);
                    }
                } else if ( ! [[targetURL URLByDeletingLastPathComponent] checkResourceIsReachableAndReturnError:nil] ) {
                    if ( ! [fm createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error] ) {
                        reply(error, 1);
                    }
                }
            } else {
                reply(nil, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Verify item exists
            // ----------------------------------------------------------------------
            NSURL *sourceURL = [NSURL fileURLWithPath:copyDict[NBCWorkflowCopySourceURL] ?: @""];
            [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying source path: %@", [sourceURL path]]];
            if ( ! [sourceURL checkResourceIsReachableAndReturnError:&error] ) {
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Copy item
            // ----------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Copying %@...", [sourceURL lastPathComponent]]];
            if ( ! [fm copyItemAtURL:sourceURL toURL:targetURL error:&error] ) {
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Update permissions and attributes for item
            // ----------------------------------------------------------------------
            NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
            if ( [attributes count] != 0 ) {
                [[[self connection] remoteObjectProxy] logDebug:@"Updating permissions and attributes..."];
                if ( ! [fm setAttributes:attributes ofItemAtPath:[targetURL path] error:&error] ) {
                    reply(error, 1);
                }
            }
            
        } else if ( [copyType isEqualToString:NBCWorkflowCopyRegex] ) {
            
            // ----------------------------------------------------------------------
            //  Verify item exists
            // ----------------------------------------------------------------------
            NSURL *sourceFolderURL = [NSURL fileURLWithPath:copyDict[NBCWorkflowCopyRegexSourceFolderURL] ?: @""];
            [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying source folder: %@", [sourceFolderURL path]]];
            if ( ! [sourceFolderURL checkResourceIsReachableAndReturnError:&error] ) {
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Verify regex isn't empty
            // ----------------------------------------------------------------------
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying regex: %@", regexString]];
            if ( [regexString length] == 0 ) {
                reply(nil, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Add regex to regex array
            // ----------------------------------------------------------------------
            NSMutableArray *sourceFolderRegexes = [regexDict[[sourceFolderURL path]] mutableCopy] ?: [[NSMutableArray alloc] init];
            [sourceFolderRegexes addObject:regexString];
            regexDict[[sourceFolderURL path]] = [sourceFolderRegexes copy];
        } else {
            [[[self connection] remoteObjectProxy] logError:[NSString stringWithFormat:@"Unknown copy type: %@", copyType]];
            reply(nil, 1);
        }
    }
    
    // ---------------------------------------------------------------------------------------------------------
    //  If any regexes were added to array, loop through each source folder and create a single regex from array
    //  Then copy all files using cpio
    // ---------------------------------------------------------------------------------------------------------
    double sourceCount = (double)[[regexDict allKeys] count];
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Sources to copy: %f", sourceCount]];
    
    double sourceProgressIncrementStep = ( 10.0 / ( sourceCount + 1.0 ));
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Source progress increment step: %f", sourceProgressIncrementStep]];
    
    double sourceProgressIncrement = 0.0;
    
    if ( [regexDict count] != 0 ) {
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        for ( NSString *sourceFolderPath in [regexDict allKeys] ) {
            
            sourceProgressIncrement += sourceProgressIncrementStep;
            
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Copying items extracted from %@...", [sourceFolderPath lastPathComponent]]];
            [[[self connection] remoteObjectProxy] incrementProgressBar:sourceProgressIncrement];
            
            NSArray *regexArray = regexDict[sourceFolderPath];
            __block NSString *regexString = @"";
            [regexArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(stop)
                if ( idx == 0 ) {
                    regexString = [regexString stringByAppendingString:[NSString stringWithFormat:@"-regex '%@'", obj]];
                } else {
                    regexString = [regexString stringByAppendingString:[NSString stringWithFormat:@" -o -regex '%@'", obj]];
                }
            }];
            
            // -----------------------------------------------------------------------------------
            //  Create stdout and stderr file handles and send all output to remoteObjectProxy
            // -----------------------------------------------------------------------------------
            NSPipe *stdOut = [[NSPipe alloc] init];
            [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
            id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                                object:[stdOut fileHandleForReading]
                                                 queue:nil
                                            usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                                NSData *stdOutData = [[stdOut fileHandleForReading] availableData];
                                                NSString *stdOutString = [[[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                                if ( [stdOutString length] != 0 ) {
                                                    [[[self connection] remoteObjectProxy] logStdOut:stdOutString];
                                                }
                                                [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                            }];
            
            NSPipe *stdErr = [[NSPipe alloc] init];
            [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
            id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                                object:[stdErr fileHandleForReading]
                                                 queue:nil
                                            usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                                NSData *stdErrData = [[stdErr fileHandleForReading] availableData];
                                                NSString *stdErrString = [[[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                                if ( [stdErrString length] != 0 ) {
                                                    [[[self connection] remoteObjectProxy] logStdErr:stdErrString];
                                                }
                                                [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                            }];
            
            // ------------------------
            //  Setup task
            // ------------------------
            NSTask *task = [[NSTask alloc] init];
            [task setLaunchPath:@"/bin/bash"];
            [task setArguments:@[
                                 @"-c",
                                 [NSString stringWithFormat:@"/usr/bin/find -E . -depth %@ | /usr/bin/cpio -admpu --quiet '%@'", regexString, [volumeURL path]]
                                 ]];
            [task setStandardOutput:stdOut];
            [task setStandardError:stdErr];
            [task setCurrentDirectoryPath:sourceFolderPath];
            
            // ------------------------
            //  Launch task
            // ------------------------
            [task launch];
            [task waitUntilExit];
            
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            
            if ( [task terminationStatus] == 0 ) {
                [[[self connection] remoteObjectProxy] logDebug:@"Copy items successful!"];
            } else {
                reply(nil, -1);
            }
        }
    }
    
    reply(nil, 0);
} // copyResourcesToVolume:copyArray:withReply

- (void)disableSpotlightOnVolume:(NSString *)volumePath
                       withReply:(void (^)(NSError *, int))reply {
    
    NSString *command = @"/usr/bin/mdutil";
    NSArray *agruments = @[ @"-Edi", @"off", volumePath];
    
    [self runTaskWithCommand:command arguments:agruments currentDirectory:nil environmentVariables:nil withReply:reply];
} // disableSpotlightOnVolume:withReply

- (void)extractResourcesFromPackageAtPath:(NSString *)packagePath
                             minorVersion:(NSInteger)minorVersion
                          temporaryFolder:(NSString *)temporaryFolder
                   temporaryPackageFolder:(NSString *)temporaryPackageFolder
                                withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSError *err = nil;
    NSString *command = @"/bin/bash";
    NSArray *arguments = nil;
    
    // ---------------------------------------------------------------------------------
    //  Choose extract method depending on os version, new package archive in 10.10+
    // ---------------------------------------------------------------------------------
    if ( minorVersion <= 9 ) {
        NSString *formatString = @"/usr/bin/xar -x -f \"%@\" Payload -C \"%@\"; /usr/bin/cd \"%@\"; /usr/bin/cpio -idmu -I \"%@/Payload\"";
        arguments = @[ @"-c", [NSString stringWithFormat:formatString, packagePath, temporaryFolder, temporaryPackageFolder, temporaryFolder] ];
    } else {
        NSString *pbxPath = [[self remoteBundleResouresPath] stringByAppendingPathComponent:@"pbzx"];
        
        [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying pbzx binary path: %@", pbxPath]];
        if ( ! [[NSURL fileURLWithPath:pbxPath] checkResourceIsReachableAndReturnError:&err] ) {
            return reply(err, -1) ;
        }
        arguments = @[ @"-c", [NSString stringWithFormat:@"%@ %@ | /usr/bin/cpio -idmu --quiet", pbxPath, packagePath]];
    }
    
    [self runTaskWithCommand:command arguments:arguments currentDirectory:temporaryPackageFolder environmentVariables:@{} withReply:reply];
} // extractResourcesFromPackageAtPath:minorVersion:temporaryFolder:temporaryPackageFolder:withReply

- (void)getVersionWithReply:(void(^)(NSString *version))reply {
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
} // getVersionWithReply

- (void)installPackage:(NSString *)packagePath
          targetVolume:(NSString *)targetVolumePath
               choices:(NSDictionary *)choices
             withReply:(void (^)(NSError *, int))reply {
    
    NSError *err = nil;
    
    NSString *command = @"/usr/sbin/installer";
    NSMutableArray *installerArguments = [[NSMutableArray alloc] initWithObjects:
                                          @"-verboseR",
                                          @"-allowUntrusted",
                                          @"-plist",
                                          nil];
    
    if ( [choices count] != 0 ) {
        [installerArguments addObject:@"-applyChoiceChangesXML"];
        [installerArguments addObject:choices];
    }
    
    // -----------------------------------------------------------------------------------
    //  Verify package path
    // -----------------------------------------------------------------------------------
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying package path: %@", packagePath]];
    if ( [[NSURL fileURLWithPath:packagePath] checkResourceIsReachableAndReturnError:&err] ) {
        [installerArguments addObject:@"-package"];
        [installerArguments addObject:packagePath];
    } else {
        return reply(err, -1);
    }
    
    // -----------------------------------------------------------------------------------
    //  Verify target volume path
    // -----------------------------------------------------------------------------------
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying target volume path: %@", targetVolumePath]];
    if ( [[NSURL fileURLWithPath:targetVolumePath] checkResourceIsReachableAndReturnError:&err] ) {
        [installerArguments addObject:@"-target"];
        [installerArguments addObject:targetVolumePath];
    } else {
        return reply(err, -1);
    }
    
    [self runTaskWithCommand:command arguments:installerArguments currentDirectory:nil environmentVariables:nil withReply:reply];
} // installPackage:targetVolume:choices:withReply

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL
             modificationsArray:(NSArray *)modificationsArray
                      withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for ( NSDictionary *modificationsDict in modificationsArray ) {
        
        NSURL *targetURL = [NSURL fileURLWithPath:modificationsDict[NBCWorkflowModifyTargetURL] ?: @""];
        [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Item target path: %@", [targetURL path]]];
        
        // ----------------------------------------------------------------------
        //  Examine modifications dict and proceed accordingly
        //
        //  Available modification types are:
        //
        //      NBCWorkflowModifyFileTypePlist      = Write included plist content to targetURL
        //      NBCWorkflowModifyFileTypeGeneric    = Write included file contents to targetURL
        //      NBCWorkflowModifyFileTypeFolder     = Create folder at targetURL
        //      NBCWorkflowModifyFileTypeDelete     = Delete item at targetURL
        //      NBCWorkflowModifyFileTypeMove       = Move item at source URL to target URL
        //      NBCWorkflowModifyFileTypeLink       = Create symlink at source URL to target URL
        // ----------------------------------------------------------------------
        
        NSString *modificationType = modificationsDict[NBCWorkflowModifyFileType];
        
        // ----------------------------------------------------------------------
        //  NBCWorkflowModifyFileTypePlist
        // ----------------------------------------------------------------------
        if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypePlist] ) {
            
            // ----------------------------------------------------------------------
            //  Create target folder if it doesn't exist
            // ----------------------------------------------------------------------
            NSURL *targetFolderURL = [targetURL URLByDeletingLastPathComponent];
            if ( ! [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                if ( ! [fm createDirectoryAtURL:targetFolderURL withIntermediateDirectories:YES
                                     attributes:@{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0755
                                                  }
                                          error:&error] ) {
                    [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  Write included plist content to target URL
            // ----------------------------------------------------------------------
            NSDictionary *plistContent = modificationsDict[NBCWorkflowModifyContent];
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Writing plist %@...", [targetURL lastPathComponent]]];
            if ( ! [plistContent writeToURL:targetURL atomically:NO] ) {
                [[[self connection] remoteObjectProxy] logError:@"Writing plist failed"];
                reply(nil, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Update permissions and attributes for item
            // ----------------------------------------------------------------------
            NSDictionary *attributes = modificationsDict[NBCWorkflowModifyAttributes];
            if ( [attributes count] != 0 ) {
                [[[self connection] remoteObjectProxy] logDebug:@"Updating permissions and attributes..."];
                if ( ! [fm setAttributes:attributes ofItemAtPath:[targetURL path] error:&error] ) {
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  NBCWorkflowModifyFileTypeGeneric
            // ----------------------------------------------------------------------
        } else if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypeGeneric] ) {
            
            NSData *fileContent = modificationsDict[NBCWorkflowModifyContent];
            if ( ! fileContent ) {
                [[[self connection] remoteObjectProxy] logError:@"File contents were empty"];
                reply(nil, 1);
            }
            
            NSDictionary *attributes = modificationsDict[NBCWorkflowModifyAttributes];
            if ( [attributes count] == 0 ) {
                [[[self connection] remoteObjectProxy] logError:@"File attributes were empty"];
                reply(nil, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Create target folder if it doesn't exist
            // ----------------------------------------------------------------------
            NSURL *targetFolderURL = [targetURL URLByDeletingLastPathComponent];
            if ( ! [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                if ( ! [fm createDirectoryAtURL:targetFolderURL withIntermediateDirectories:YES
                                     attributes:@{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0755
                                                  }
                                          error:&error] ) {
                    [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  Write included file contents to target URL (and set attributes)
            // ----------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Writing file %@...", [targetURL lastPathComponent]]];
            if ( ! [fm createFileAtPath:[targetURL path] contents:fileContent attributes:attributes] ) {
                [[[self connection] remoteObjectProxy] logError:@"Creating file failed"];
                reply(nil, 1);
            }
            
            // ----------------------------------------------------------------------
            //  NBCWorkflowModifyFileTypeFolder
            // ----------------------------------------------------------------------
        } else if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypeFolder] ) {
            
            NSDictionary *attributes = modificationsDict[NBCWorkflowModifyAttributes];
            if ( [attributes count] == 0 ) {
                [[[self connection] remoteObjectProxy] logError:@"File attributes were empty"];
                reply(nil, 1);
            }
            
            // ------------------------------------------------------------------------------------
            //  Create directory (and intermediate directories) at target URL (and set attributes)
            // ------------------------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Creating directory %@...", [targetURL path]]];
            if ( ! [fm createDirectoryAtURL:targetURL withIntermediateDirectories:YES attributes:attributes error:&error] ) {
                [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  NBCWorkflowModifyFileTypeDelete
            // ----------------------------------------------------------------------
        } else if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypeDelete] ) {
            
            // ------------------------------------------------------------------------------------
            //  Delete item at target URL
            // ------------------------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Deleting item %@...", [targetURL lastPathComponent]]];
            if ( ! [fm removeItemAtURL:targetURL error:&error] ) {
                [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  NBCWorkflowModifyFileTypeMove
            // ----------------------------------------------------------------------
        } else if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypeMove] ) {
            
            // ----------------------------------------------------------------------
            //  Verify source item exists
            // ----------------------------------------------------------------------
            NSURL *sourceURL = [NSURL fileURLWithPath:modificationsDict[NBCWorkflowModifySourceURL] ?: @""];
            [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Item source path: %@", [sourceURL path]]];
            if ( ! [sourceURL checkResourceIsReachableAndReturnError:&error] ) {
                [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  Remove target item if it already exists
            // ----------------------------------------------------------------------
            if ( [targetURL checkResourceIsReachableAndReturnError:&error] ) {
                if ( ! [fm removeItemAtURL:targetURL error:&error] ) {
                    [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  Create target folder if it doesn't exist
            // ----------------------------------------------------------------------
            NSURL *targetFolderURL = [targetURL URLByDeletingLastPathComponent];
            if ( ! [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                if ( ! [fm createDirectoryAtURL:targetFolderURL withIntermediateDirectories:YES
                                     attributes:@{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0755
                                                  }
                                          error:&error] ) {
                    [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  Move item
            // ----------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Moving %@ to %@", [sourceURL lastPathComponent], [[targetFolderURL path] lastPathComponent]]];
            if ( ! [fm moveItemAtURL:sourceURL toURL:targetURL error:&error] ) {
                [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                reply(error, 1);
            }
            
            // ----------------------------------------------------------------------
            //  NBCWorkflowModifyFileTypeLink
            // ----------------------------------------------------------------------
        } else if ( [modificationType isEqualToString:NBCWorkflowModifyFileTypeLink] ) {
            
            // ----------------------------------------------------------------------
            //  Remove source item if it already exists
            // ----------------------------------------------------------------------
            NSURL *sourceURL = [NSURL fileURLWithPath:modificationsDict[NBCWorkflowModifySourceURL] ?: @""];
            [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Item source path: %@", [targetURL path]]];
            if ( [sourceURL checkResourceIsReachableAndReturnError:&error] ) {
                if ( ! [fm removeItemAtURL:sourceURL error:&error] ) {
                    [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                    reply(error, 1);
                }
            }
            
            // ----------------------------------------------------------------------
            //  Create symbolic link
            // ----------------------------------------------------------------------
            [[[self connection] remoteObjectProxy] updateProgressStatus:[NSString stringWithFormat:@"Creating symlink to %@", [targetURL path]]];
            if ( ! [fm createSymbolicLinkAtURL:sourceURL withDestinationURL:targetURL error:&error] ) {
                [[[self connection] remoteObjectProxy] logError:[error localizedDescription]];
                reply(error, 1);
            }
        } else {
            [[[self connection] remoteObjectProxy] logError:[NSString stringWithFormat:@"Unknown modification type: %@", modificationType]];
            reply(nil, 1);
        }
    }
    reply(nil, 0);
} // modifyResourcesOnVolume:modificationsArray:withReply

- (void)readSettingsFromNBI:(NSURL *)nbiVolumeURL
               settingsDict:(NSDictionary *)settingsDict
                  withReply:(void(^)(NSError *error, BOOL success, NSDictionary *newSettingsDict))reply {
    
    BOOL retval = YES;
    NSError *err;
    NSString *userName;
    NSMutableDictionary *mutableSettingsDict = [settingsDict mutableCopy];
    
    // -------------------------------------------------------------------------------
    //  Screen Sharing - User login
    // -------------------------------------------------------------------------------
    NSURL *dsLocalUsersURL = [nbiVolumeURL URLByAppendingPathComponent:@"var/db/dslocal/nodes/Default/users"];
    if ( [dsLocalUsersURL checkResourceIsReachableAndReturnError:&err] ) {
        NSArray *userFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dsLocalUsersURL path] error:nil];
        NSMutableArray *userFilesFiltered = [[userFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (self BEGINSWITH '_')"]] mutableCopy];
        [userFilesFiltered removeObjectsInArray:@[ @"daemon.plist", @"nobody.plist", @"root.plist" ]];
        if ( [userFilesFiltered count] != 0 ) {
            NSString *firstUser = userFilesFiltered[0];
            NSURL *firstUserPlistURL = [dsLocalUsersURL URLByAppendingPathComponent:firstUser];
            NSDictionary *firstUserDict = [NSDictionary dictionaryWithContentsOfURL:firstUserPlistURL];
            if ( firstUserDict ) {
                NSArray *userNameArray = firstUserDict[@"name"];
                userName = userNameArray[0];
            }
        }
    } else {
        [[[self connection] remoteObjectProxy] logWarn:[err localizedDescription]];
    }
    mutableSettingsDict[NBCSettingsARDLoginKey] = userName ?: @"";
    
    // -------------------------------------------------------------------------------
    //  Screen Sharing - User password
    // -------------------------------------------------------------------------------
    NSString *vncPassword;
    NSURL *vncPasswordFile = [nbiVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    if ( [vncPasswordFile checkResourceIsReachableAndReturnError:nil] ) {
        NSTask *perlTask =  [[NSTask alloc] init];
        [perlTask setLaunchPath:@"/bin/bash"];
        NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/bin/cat %@ | perl -wne 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; chomp; @p = unpack \"C*\", pack \"H*\", $_; foreach (@k) { printf \"%%c\", $_ ^ (shift @p || 0) }'", [vncPasswordFile path]]];
        [perlTask setArguments:args];
        [perlTask setStandardOutput:[NSPipe pipe]];
        [perlTask setStandardError:[NSPipe pipe]];
        [perlTask launch];
        [perlTask waitUntilExit];
        
        NSData *stdOutData = [[[perlTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        
        NSData *stdErrData = [[[perlTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
        
        if ( [perlTask terminationStatus] == 0 ) {
            if ( [stdOut length] != 0 ) {
                vncPassword = stdOut;
            }
            retval = YES;
        } else {
            [[[self connection] remoteObjectProxy] logStdOut:stdOut];
            [[[self connection] remoteObjectProxy] logStdErr:stdErr];
            [[[self connection] remoteObjectProxy] logError:[NSString stringWithFormat:@"perl command failed with exit status: %d", [perlTask terminationStatus]]];
            retval = NO;
        }
    }
    mutableSettingsDict[NBCSettingsARDPasswordKey] = vncPassword ?: @"";
    
    reply(nil, retval, [mutableSettingsDict copy] );
} // readSettingsFromNBI:settingsDict:withReply

- (void)removeItemsAtPaths:(NSArray *)itemPaths
                 withReply:(void(^)(NSError *error, BOOL success))reply {
    
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    // ----------------------------------------------------------
    // Loop through each path in array and remove it recursively
    // ----------------------------------------------------------
    for ( NSString *itemPath in itemPaths ) {
        [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Removing item at path: %@", itemPath]];
        if ( ! [fm removeItemAtPath:itemPath error:&error] ) {
            reply(error, NO);
        }
    }
    
    reply(error, YES);
} // removeItemsAtPaths

- (void)runTaskWithCommand:(NSString *)command
                 arguments:(NSArray *)arguments
          currentDirectory:(NSString *)currentDirectory
      environmentVariables:(NSDictionary *)environmentVariables
                 withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // -----------------------------------------------------------------------------------
    //  Create stdout and stderr file handles and send all output to remoteObjectProxy
    // -----------------------------------------------------------------------------------
    NSPipe *stdOut = [[NSPipe alloc] init];
    [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
    id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdOut fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        NSData *stdOutData = [[stdOut fileHandleForReading] availableData];
                                        NSString *stdOutString = [[[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        if ( [stdOutString length] != 0 ) {
                                            [[[self connection] remoteObjectProxy] logStdOut:stdOutString];
                                        }
                                        [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    NSPipe *stdErr = [[NSPipe alloc] init];
    [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
    id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
                                        object:[stdErr fileHandleForReading]
                                         queue:nil
                                    usingBlock:^(NSNotification *notification){
#pragma unused(notification)
                                        NSData *stdErrData = [[stdErr fileHandleForReading] availableData];
                                        NSString *stdErrString = [[[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                        if ( [stdErrString length] != 0 ) {
                                            [[[self connection] remoteObjectProxy] logStdErr:stdErrString];
                                        }
                                        [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                    }];
    
    // ------------------------
    //  Setup task
    // ------------------------
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:command];
    [task setArguments:arguments];
    [task setStandardOutput:stdOut];
    [task setStandardError:stdErr];
    
    if ( [currentDirectory length] != 0 ) {
        [task setCurrentDirectoryPath:currentDirectory];
    }
    
    if ( [environmentVariables count] != 0 ) {
        [task setEnvironment:environmentVariables];
    }
    
    // ------------------------
    //  Launch task
    // ------------------------
    [task launch];
    [task waitUntilExit];
    
    [nc removeObserver:stdOutObserver];
    [nc removeObserver:stdErrObserver];
    if ( ! [task isRunning] ) {
        reply(nil, [task terminationStatus]);
    } else {
        reply(nil, -1);
    }
} // runTaskWithCommand:arguments:currentDirectory:environmentVariables:withReply

- (void)updateKernelCache:(NSString *)targetVolumePath
            nbiVolumePath:(NSString *)nbiVolumePath
             minorVersion:(NSString *)minorVersion
                withReply:(void(^)(NSError *error, int terminationStatus))reply {
    
    NSError *err = nil;
    
    // -----------------------------------------------------------------------------------
    //  Verify target volume path
    // -----------------------------------------------------------------------------------
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying target volume path: %@", targetVolumePath]];
    if ( ! [[NSURL fileURLWithPath:targetVolumePath] checkResourceIsReachableAndReturnError:&err] ) {
        return reply(err, -1);
    }
    
    // -----------------------------------------------------------------------------------
    //  Verify nbi volume path
    // -----------------------------------------------------------------------------------
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying nbi volume path: %@", nbiVolumePath]];
    if ( ! [[NSURL fileURLWithPath:nbiVolumePath] checkResourceIsReachableAndReturnError:&err] ) {
        return reply(err, -1);
    }
    
    // -----------------------------------------------------------------------------------
    //  Verify minorVersion is a number
    // -----------------------------------------------------------------------------------
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying minor version: %@", minorVersion]];
    NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ( ! [minorVersion rangeOfCharacterFromSet:notDigits].location == NSNotFound ) {
        return reply( [NSError errorWithDomain:NBCErrorDomain
                                          code:-1
                                      userInfo:@{ NSLocalizedDescriptionKey : @"Minor version is not a number" }], -1);
    }
    
    // -----------------------------------------------------------------------------------
    //  Verify script
    // -----------------------------------------------------------------------------------
    NSString *scriptPath = [[self remoteBundleScriptsPath] stringByAppendingPathComponent:@"generateKernelCache.bash"];
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying script path: %@", scriptPath]];
    if ( ! [[NSURL fileURLWithPath:scriptPath] checkResourceIsReachableAndReturnError:&err] ) {
        return reply(err, -1);
    }
    
    NSString *scriptMD5 = [FileHash md5HashOfFileAtPath:scriptPath];
    [[[self connection] remoteObjectProxy] logDebug:[NSString stringWithFormat:@"Verifying script md5: %@", scriptMD5]];
    
    NSString *command = @"/bin/bash";
    NSArray *arguments = @[ scriptPath, targetVolumePath, nbiVolumePath, minorVersion ];
    
    [self runTaskWithCommand:command arguments:arguments currentDirectory:nil environmentVariables:nil withReply:reply];
} // updateKernelCache:tmpNBI:minorVersion:withReply

- (void)quitHelper:(void (^)(BOOL success))reply {
    for ( NSXPCConnection *connection in _connections ) {
        [connection invalidate];
    }
    
    if ( _resign ) {
        _resign(YES);
    }
    
    [_connections removeAllObjects];
    [self setHelperToolShouldQuit:YES];
    reply(YES);
} // quitHelper

@end
