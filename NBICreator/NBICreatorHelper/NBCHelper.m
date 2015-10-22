//
//  NBCHelper.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-14.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCHelper.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperAuthorization.h"
#import "NBCMessageDelegate.h"
#import <CommonCrypto/CommonDigest.h>

#import "NBCTarget.h"
#import "NBCConstants.h"

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
    
    // This is called by the XPC listener when there is a new connection.
    [newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCMessageDelegate)]];
    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCHelperProtocol)]];
    [newConnection setExportedObject:self];
    
    
    __weak typeof(newConnection) weakConnection = newConnection;
    [newConnection setInvalidationHandler:^() {
        if ( [weakConnection isEqualTo:_relayConnection] && _resign) {
            _resign(YES);
        }
        
        [self->_connections removeObject:weakConnection];
        if ( ! [self->_connections count] ) {
            [self quitHelper:^(BOOL success){
            }];
        }
    }];
    
    [_connections addObject:newConnection];
    [newConnection resume];
    
    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCHelperProtocol methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSXPCConnection *)connection
{
    return [_connections lastObject];
}

- (void)getVersionWithReply:(void(^)(NSString *version))reply {
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

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
}

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                   authorization:(NSData *)authData
                       withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSError *error;
    error = [NBCHelperAuthorization checkAuthorization:authData command:_cmd];
    if (error != nil) {
        if (error.code == errAuthorizationCanceled) {
            reply(nil, -1);
        } else {
            reply(error, -1);
        }
        return;
    }
    
    NSTask *newTask = [[NSTask alloc] init];
    [newTask setLaunchPath:[taskCommandPath path]];
    [newTask setArguments:taskArguments];
    
    if ( stdOutFileHandleForWriting != nil ) {
        [newTask setStandardOutput:stdOutFileHandleForWriting];
    }
    
    if ( stdErrFileHandleForWriting != nil ) {
        [newTask setStandardError:stdErrFileHandleForWriting];
    }
    
    [newTask launch];
    [newTask waitUntilExit];
    
    if ( ! [newTask isRunning] ) {
        reply(nil, [newTask terminationStatus]);
    } else {
        reply(nil, -1);
    }
}

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
                currentDirectory:(NSString *)currentDirectory
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                       withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSTask *newTask = [[NSTask alloc] init];
    [newTask setLaunchPath:[taskCommandPath path]];
    [newTask setArguments:taskArguments];
    
    if ( currentDirectory != nil ) {
        [newTask setCurrentDirectoryPath:currentDirectory];
    }
    
    if ( stdOutFileHandleForWriting != nil ) {
        [newTask setStandardOutput:stdOutFileHandleForWriting];
    }
    
    if ( stdErrFileHandleForWriting != nil ) {
        [newTask setStandardError:stdErrFileHandleForWriting];
    }
    
    [newTask launch];
    [newTask waitUntilExit];
    
    if ( ! [newTask isRunning] ) {
        reply(nil, [newTask terminationStatus]);
    } else {
        reply(nil, -1);
    }
}

- (void)runTaskWithCommandAtPath:(NSURL *)taskCommandPath
                       arguments:(NSArray *)taskArguments
            environmentVariables:(NSDictionary *)environmentVariables
      stdOutFileHandleForWriting:(NSFileHandle *)stdOutFileHandleForWriting
      stdErrFileHandleForWriting:(NSFileHandle *)stdErrFileHandleForWriting
                       withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSTask *newTask = [[NSTask alloc] init];
    [newTask setLaunchPath:[taskCommandPath path]];
    //if ([[[self connection] remoteObjectProxy] respondsToSelector:@selector(updateProgress:)]) {
    //    [[[self connection] remoteObjectProxy] updateProgress:@"TESTSTSTSAKTLSJLKAJSLDKAJASD"];
    //}
    [newTask setArguments:taskArguments];
    
    if ( environmentVariables != nil ) {
        [newTask setEnvironment:environmentVariables];
    }
    
    if ( stdOutFileHandleForWriting != nil ) {
        [newTask setStandardOutput:stdOutFileHandleForWriting];
    }
    
    if ( stdErrFileHandleForWriting != nil ) {
        [newTask setStandardError:stdErrFileHandleForWriting];
    }
    
    [newTask launch];
    [newTask waitUntilExit];
    
    if ( ! [newTask isRunning] ) {
        reply(nil, [newTask terminationStatus]);
    } else {
        reply(nil, -1);
    }
}

- (void)testCommandWithReply:(NSURL *)commandURL withArguments:(NSArray *)arguments outputPipeFileHandle:(NSFileHandle *)outputPipeFileHandle withReply:(void(^)(int returnStatus))reply {
    NSTask *newTask = [[NSTask alloc] init];
    [newTask setLaunchPath:[commandURL path]];
    [newTask setArguments:arguments];
    [newTask setStandardOutput:outputPipeFileHandle];
    
    [newTask launch];
    [newTask waitUntilExit];
    
    reply([newTask terminationStatus]);
}

- (void)sendMessageToMainApplication:(NSString *)message {
    
}

- (void)removeItemAtURL:(NSURL *)itemURL
              withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSError *error;
    int replyInt = 0;
    
    if ( [[NSFileManager defaultManager] removeItemAtURL:itemURL error:&error] ) {
        replyInt = 0;
    } else {
        replyInt = 1;
    }
    
    reply(error, replyInt);
}

- (void)readSettingsFromNBI:(NSURL *)nbiVolumeURL settingsDict:(NSDictionary *)settingsDict withReply:(void(^)(NSError *error, BOOL success, NSDictionary *newSettingsDict))reply {
    BOOL retval = YES;
    NSError *err;
    NSString *userName;
    NSMutableDictionary *mutableSettingsDict = [settingsDict mutableCopy];
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
        NSLog(@"Could not get path to local user database");
        NSLog(@"Error: %@", err);
    }
    mutableSettingsDict[NBCSettingsARDLoginKey] = userName ?: @"";
    
    NSString *vncPassword;
    NSURL *vncPasswordFile = [nbiVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    if ( [vncPasswordFile checkResourceIsReachableAndReturnError:nil] ) {
        NSTask *perlTask =  [[NSTask alloc] init];
        [perlTask setLaunchPath:@"/bin/bash"];
        NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/bin/cat %@ | perl -wne 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; chomp; @p = unpack \"C*\", pack \"H*\", $_; foreach (@k) { printf \"%%c\", $_ ^ (shift @p || 0) }; print \"\n\"'", [vncPasswordFile path]]];
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
            NSLog(@"[bash] %@", stdOut);
            NSLog(@"[bash] %@", stdErr);
            NSLog(@"[ERROR] perl command failed with exit status: %d", [perlTask terminationStatus]);
            retval = NO;
        }
    }
    mutableSettingsDict[NBCSettingsARDPasswordKey] = vncPassword ?: @"";
    
    reply(nil, retval, [mutableSettingsDict copy] );
}

- (void)copyResourcesToVolume:(NSURL *)volumeURL resourcesDict:(NSDictionary *)resourcesDict
                    withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSError *error;
    BOOL verified = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *blockVolumeURL = volumeURL;
    NSArray *copyArray = resourcesDict[NBCWorkflowCopy];
    NSMutableDictionary *regexDict = [[NSMutableDictionary alloc] init];
    for ( NSDictionary *copyDict in copyArray ) {
        NSString *copyType = copyDict[NBCWorkflowCopyType];
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            if ( [targetURLString length] != 0 ) {
                targetURL = [blockVolumeURL URLByAppendingPathComponent:targetURLString];
                if ( ! [[targetURL URLByDeletingLastPathComponent] checkResourceIsReachableAndReturnError:&error] ) {
                    if ( ! [fileManager createDirectoryAtURL:[targetURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error] ) {
                        NSLog(@"Could not create target folder: %@", [targetURL URLByDeletingLastPathComponent]);
                        continue;
                    }
                }
            } else {
                NSLog(@"Target URLString is empty!");
                verified = NO;
                break;
            }
            
            NSString *sourceURLString = copyDict[NBCWorkflowCopySourceURL];
            NSURL *sourceURL = [NSURL fileURLWithPath:sourceURLString];
            
            if ( [targetURL checkResourceIsReachableAndReturnError:nil] ) {
                if ( ! [fileManager removeItemAtURL:targetURL error:&error] ) {
                    NSLog(@"Removing existing item at %@ failed!", [targetURL path]);
                    NSLog(@"[ERROR] %@", error);
                    verified = NO;
                    continue;
                }
            }
            
            if ( ! [fileManager copyItemAtURL:sourceURL toURL:targetURL error:&error] ) {
                NSLog(@"Copy failed!");
                NSLog(@"[ERROR] %@", error);
                verified = NO;
                continue;
            }
            
            NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
            
            if ( ! [fileManager setAttributes:attributes ofItemAtPath:[targetURL path] error:&error] )
            {
                NSLog(@"Changing file permissions failed on file: %@", [targetURL path]);
            }
            
        } else if ( [copyType isEqualToString:NBCWorkflowCopyRegex] ) {
            NSString *sourceFolderPath = copyDict[NBCWorkflowCopyRegexSourceFolderURL];
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            NSMutableArray *sourceFolderRegexes = [regexDict[sourceFolderPath] mutableCopy];
            if ( [sourceFolderRegexes count] != 0 ) {
                [sourceFolderRegexes addObject:regexString];
            } else {
                sourceFolderRegexes = [[NSMutableArray alloc] initWithObjects:regexString, nil];
            }
            
            regexDict[sourceFolderPath] = [sourceFolderRegexes copy];
        }
    }
    
    if ( [regexDict count] != 0 ) {
        NSArray *keys = [regexDict allKeys];
        for ( NSString *sourceFolderPath in keys ) {
            NSArray *regexArray = regexDict[sourceFolderPath];
            __block NSString *regexString = @"";
            [regexArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(stop)
                if ( idx == 0 )
                {
                    regexString = [regexString stringByAppendingString:[NSString stringWithFormat:@" -regex '%@'", obj]];
                } else {
                    regexString = [regexString stringByAppendingString:[NSString stringWithFormat:@" -o -regex '%@'", obj]];
                }
            }];
            
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
                                                // ------------------------
                                                //  Convert data to string
                                                // ------------------------
                                                NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
                                                NSString *outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                                                
                                                // -----------------------------------------------------------------------
                                                //  When output data becomes available, pass it to workflow status parser
                                                // -----------------------------------------------------------------------
                                                NSLog(@"outStr=%@", outStr);
                                                
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
                                                // ------------------------
                                                //  Convert data to string
                                                // ------------------------
                                                NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
                                                NSString *errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
                                                
                                                // -----------------------------------------------------------------------
                                                //  When error data becomes available, pass it to workflow status parser
                                                // -----------------------------------------------------------------------
                                                NSLog(@"errStr=%@", errStr);
                                                
                                                [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
                                            }];
            
            NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                               [NSString stringWithFormat:@"/usr/bin/find -E . -depth%@ | /usr/bin/cpio -admpu --quiet '%@'", regexString, [volumeURL path]],
                                               nil];
            
            NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
            //NSPipe *stdOut = [[NSPipe alloc] init];
            //NSPipe *stdErr = [[NSPipe alloc] init];
            NSTask *newTask = [[NSTask alloc] init];
            
            [newTask setLaunchPath:[commandURL path]];
            [newTask setArguments:scriptArguments];
            
            if ( [sourceFolderPath length] != 0 ) {
                [newTask setCurrentDirectoryPath:sourceFolderPath];
            }
            
            if ( stdOutFileHandle != nil ) {
                [newTask setStandardOutput:stdOutFileHandle];
            }
            
            if ( stdErrFileHandle != nil ) {
                [newTask setStandardError:stdErrFileHandle];
            }
            
            [newTask launch];
            [newTask waitUntilExit];
            
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
        }
    }
    
    reply(nil, 0);
}

- (void)modifyResourcesOnVolume:(NSURL *)volumeURL resourcesDictArray:(NSArray *)modifyDictArray withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSLog(@"modifyDictArray=%@", modifyDictArray);
    for (NSDictionary *modifyDict in modifyDictArray ) {
        NSLog(@"modifyDict=%@", modifyDict);
        NSString *filePath = modifyDict[NBCWorkflowModifyTargetURL];
        NSLog(@"filePath=%@", filePath);
        NSString *sourceFilePath = modifyDict[NBCWorkflowModifySourceURL];
        NSLog(@"sourceFilePath=%@", sourceFilePath);
        NSString *fileType = modifyDict[NBCWorkflowModifyFileType];
        NSLog(@"fileType=%@", fileType);
        if ( [filePath length] != 0 ) {
            if ( [fileType isEqualToString:NBCWorkflowModifyFileTypePlist] ) {
                NSDictionary *fileContent = modifyDict[NBCWorkflowModifyContent];
                
                if ( [fileContent writeToFile:filePath atomically:NO] ) {
                    NSDictionary *fileAttributes = modifyDict[NBCWorkflowModifyAttributes];
                    
                    if ( ! [fm setAttributes:fileAttributes ofItemAtPath:filePath error:&error] ) {
                        NSLog(@"Changing file permissions failed on file: %@", filePath);
                        NSLog(@"Error: %@", error);
                    }
                } else {
                    NSLog(@"Error while writing property list to URL: %@", filePath);
                }
            } else if ( [fileType isEqualToString:NBCWorkflowModifyFileTypeGeneric] ) {
                NSData *fileContent = modifyDict[NBCWorkflowModifyContent];
                NSDictionary *fileAttributes = modifyDict[NBCWorkflowModifyAttributes];
                
                if ( ! [fm createFileAtPath:filePath contents:fileContent attributes:fileAttributes] ) {
                    NSLog(@"Write FAILED!");
                }
            } else if ( [ fileType isEqualToString:NBCWorkflowModifyFileTypeFolder] ) {
                NSDictionary *folderAttributes = modifyDict[NBCWorkflowModifyAttributes];
                
                if ( ! [fm createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:folderAttributes error:&error] ) {
                    NSLog(@"Creating folder failed!");
                }
            } else if ( [fileType isEqualToString:NBCWorkflowModifyFileTypeDelete] ) {
                if ( ! [fm removeItemAtPath:filePath error:&error] ) {
                    NSLog(@"Error removing item!");
                }
            } else if ( [fileType isEqualToString:NBCWorkflowModifyFileTypeLink] ) {
                NSURL *sourceFileURL = [NSURL fileURLWithPath:sourceFilePath];
                if ( sourceFileURL ) {
                    if ( [sourceFileURL checkResourceIsReachableAndReturnError:nil] ) {
                        if ( ! [fm removeItemAtURL:sourceFileURL error:&error] ) {
                            NSLog(@"Remove failed!");
                            NSLog(@"%@", error);
                            continue;
                        }
                        
                        if ( ! [fm createSymbolicLinkAtPath:sourceFilePath withDestinationPath:filePath error:&error] ) {
                            NSLog(@"Create symbolic link failed!");
                            NSLog(@"%@", error);
                        }
                    }
                    
                } else {
                    NSLog(@"sourceFileURL=%@", sourceFileURL);
                }
            } else if ( [fileType isEqualToString:NBCWorkflowModifyFileTypeMove] ) {
                NSLog(@"[filePath stringByDeletingLastPathComponent]=%@", [filePath stringByDeletingLastPathComponent]);
                NSURL *targetFolderURL = [NSURL fileURLWithPath:[filePath stringByDeletingLastPathComponent]];
                NSLog(@"targetFolderURL=%@", targetFolderURL);
                if ( ! [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                    NSDictionary *defaultAttributes = @{
                                                        NSFileOwnerAccountName : @"root",
                                                        NSFileGroupOwnerAccountName : @"wheel",
                                                        NSFilePosixPermissions : @0755
                                                        };
                    NSLog(@"defaultAttributes=%@", defaultAttributes);
                    if ( ! [fm createDirectoryAtURL:targetFolderURL withIntermediateDirectories:YES attributes:defaultAttributes error:&error] ) {
                        NSLog(@"Creating target folder failed!");
                        NSLog(@"%@", error);
                        continue;
                    }
                }
                
                if ( ! [fm moveItemAtPath:sourceFilePath toPath:filePath error:&error] ) {
                    NSLog(@"Failed to move file!");
                    NSLog(@"[ERROR] %@", error);
                }
            }
        } else {
            NSLog(@"ERROR: filePath is nil!");
        }
    }
    
    reply(nil, 0);
}


// Unused atm
#define SALTED_SHA1_LEN 48
#define SALTED_SHA1_OFFSET (64 + 40 + 64)
#define SHADOW_HASH_LEN 1240

- (NSString *)calculateShadowHash:(NSString *)pwd {
    CC_SHA1_CTX ctx;
    unsigned char salted_sha1_hash[24];
    union _salt {
        unsigned char bytes[4];
        u_int32_t value;
    } *salt = (union _salt *)&salted_sha1_hash[0];
    unsigned char *hash = &salted_sha1_hash[4];
    
    // Calculate salted sha1 hash.
    CC_SHA1_Init(&ctx);
    salt->value = arc4random();
    CC_SHA1_Update(&ctx, salt->bytes, sizeof(salt->bytes));
    CC_SHA1_Update(&ctx, [pwd UTF8String], (CC_LONG)[pwd lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    CC_SHA1_Final(hash, &ctx);
    
    
    NSMutableString *shadowHash = [[NSMutableString alloc] initWithString:@""];
    // Generate new shadow hash.
    [shadowHash appendFormat:@"%0168X", 0];
    assert([shadowHash length] == SALTED_SHA1_OFFSET);
    for (int i = 0; i < sizeof(salted_sha1_hash); i++) {
        [shadowHash appendFormat:@"%02X", salted_sha1_hash[i]];
    }
    while ([shadowHash length] < SHADOW_HASH_LEN) {
        [shadowHash appendFormat:@"%064X", 0];
    }
    assert([shadowHash length] == SHADOW_HASH_LEN);
    
    return shadowHash;
}

@end
