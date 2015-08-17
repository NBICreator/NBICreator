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
        
        // Set up the XPC listener to handle incoming requests.
        
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:NBCBundleIdentifierHelper];
        [self->_listener setDelegate:self];
        self->_connections = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)run {
    
    // Tell the XPC listener to start processing requests.
    
    [_listener resume];

    while ( ! _helperToolShouldQuit ) {
        NSLog(@"_helperToolShouldQuit=%hhd", _helperToolShouldQuit);
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
    
    [newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCHelperProtocol)]];
    
    NBCHelper *ncHelper = [[NBCHelper alloc] init];
    [newConnection setExportedObject:ncHelper];
    
    // Start connection
    
    [newConnection resume];
    [_connections addObject:newConnection];
    
    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCHelperProtocol methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)getVersionWithReply:(void(^)(NSString *version))reply {
    
    // Return bundle version of NBICreatorHelper
    
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

- (void)quitHelper:(void (^)(BOOL success))reply {
    NSLog(@"quitHelper");
    for ( NSXPCConnection *connection in _connections ) {
        NSLog(@"connection=%@", connection);
        [connection invalidate];
    }
    
    if (_resign) {
        _resign(YES);
    }
    
    [_connections removeAllObjects];
    NSLog(@"setting helperToolShouldQuit");
    NSLog(@"_helperToolShouldQuit=%hhd", _helperToolShouldQuit);
    [self setHelperToolShouldQuit:YES];
    NSLog(@"_helperToolShouldQuit=%hhd", _helperToolShouldQuit);
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
- (void)registerMainApplication:(void (^)(BOOL resign))resign; {
    if(!self.relayConnection){
        self.relayConnection = self.connection;
        self.relayConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(NBCMessageDelegate)];
        _resign = resign;
    } else {
        resign(YES);
    }
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
    NSMutableDictionary *mutableSettingsDict = [settingsDict mutableCopy];
    
    NSURL *dsLocalUsersURL = [nbiVolumeURL URLByAppendingPathComponent:@"var/db/dslocal/nodes/Default/users"];
    NSLog(@"dsLocalUsersURL=%@", dsLocalUsersURL);
    if ( [dsLocalUsersURL checkResourceIsReachableAndReturnError:&err] ) {
        NSLog(@"URL ok");
        NSArray *userFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dsLocalUsersURL path] error:nil];
        NSMutableArray *userFilesFiltered = [[userFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (self BEGINSWITH '_')"]] mutableCopy];
        [userFilesFiltered removeObjectsInArray:@[ @"daemon.plist", @"nobody.plist", @"root.plist" ]];
        NSLog(@"userFilesFiltered=%@", userFilesFiltered);
        if ( [userFilesFiltered count] != 0 ) {
            NSString *firstUser = userFilesFiltered[0];
            NSURL *firstUserPlistURL = [dsLocalUsersURL URLByAppendingPathComponent:firstUser];
            NSLog(@"firstUserPlistURL=%@", firstUserPlistURL);
            NSDictionary *firstUserDict = [NSDictionary dictionaryWithContentsOfURL:firstUserPlistURL];
            if ( firstUserDict ) {
                NSArray *userNameArray = firstUserDict[@"name"];
                NSString *userName = userNameArray[0];
                if ( [userName length] != 0 ) {
                    mutableSettingsDict[NBCSettingsARDLoginKey] = userName;
                }
            }
        }
    } else {
        NSLog(@"Could not get path to local user database");
        NSLog(@"Error: %@", err);
    }
    
    NSLog(@"mutableSettingsDict=%@", mutableSettingsDict);
    
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
    NSURL *vncPasswordFile = [nbiVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    NSMutableArray *scriptArguments;
    if ( [vncPasswordFile checkResourceIsReachableAndReturnError:nil] ) {
        scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                           [NSString stringWithFormat:@"/bin/cat %@ | perl -wne 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; chomp; @p = unpack \"C*\", pack \"H*\", $_; foreach (@k) { printf \"%%c\", $_ ^ (shift @p || 0) }; print \"\n\"'", [vncPasswordFile path]],
                           nil];
        NSPipe *stdOut = [[NSPipe alloc] init];
        NSPipe *stdErr = [[NSPipe alloc] init];
        NSTask *newTask = [[NSTask alloc] init];
        
        [newTask setLaunchPath:[commandURL path]];
        [newTask setArguments:scriptArguments];
        
        if ( stdOut != nil ) {
            [newTask setStandardOutput:stdOut];
        }
        
        if ( stdErr != nil ) {
            [newTask setStandardError:stdErr];
        }
        
        [newTask launch];
        [newTask waitUntilExit];
        
        NSData *newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
        NSString *outStr = [[[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        
        if ( [outStr length] != 0 ) {
            mutableSettingsDict[NBCSettingsARDPasswordKey] = outStr;
        }
        
        if ( [newTask terminationStatus] == 0 ) {
            retval = YES;
        } else {
            retval = NO;
        }
    }
    
    NSLog(@"mutableSettingsDict=%@", mutableSettingsDict);
    
    reply(nil, retval, [mutableSettingsDict copy] );
}

- (void)copyResourcesToVolume:(NSURL *)volumeURL resourcesDict:(NSDictionary *)resourcesDict
                    withReply:(void(^)(NSError *error, int terminationStatus))reply {
    NSError *error;
    BOOL verified = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *blockVolumeURL = volumeURL;
    NSArray *copyArray = resourcesDict[NBCWorkflowCopy];
    for ( NSDictionary *copyDict in copyArray ) {
        
        NSString *copyType = copyDict[NBCWorkflowCopyType];
        
        if ( [copyType isEqualToString:NBCWorkflowCopy] ) {
            NSURL *targetURL;
            NSString *targetURLString = copyDict[NBCWorkflowCopyTargetURL];
            NSLog(@"targetURLString=%@", targetURLString);
            if ( [targetURLString length] != 0 ) {
                targetURL = [blockVolumeURL URLByAppendingPathComponent:targetURLString];
                NSLog(@"targetURL=%@", targetURL);
                if ( ! [[targetURL URLByDeletingLastPathComponent] checkResourceIsReachableAndReturnError:&error] ) {
                    NSLog(@"Folder: %@ not found!", [targetURL URLByDeletingLastPathComponent]);
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
            NSLog(@"sourceURLString=%@", sourceURLString);
            NSURL *sourceURL = [NSURL fileURLWithPath:sourceURLString];
            NSLog(@"sourceURL=%@", sourceURL);
            
            if ( ! [fileManager copyItemAtURL:sourceURL toURL:targetURL error:&error] ) {
                if ( ! [fileManager moveItemAtURL:targetURL toURL:[targetURL URLByAppendingPathExtension:@"bak"] error:&error] ) {
                    NSLog(@"Copy Resource Failed!");
                    NSLog(@"Error: %@", error);
                    
                    verified = NO;
                    continue;
                } else {
                    if ( ! [fileManager copyItemAtURL:sourceURL toURL:targetURL error:&error] ) {
                        NSLog(@"Copy Resource Failed!");
                        NSLog(@"Error: %@", error);
                        
                        verified = NO;
                        continue;
                    }
                }
            }
            
            NSDictionary *attributes = copyDict[NBCWorkflowCopyAttributes];
            
            if ( ! [fileManager setAttributes:attributes ofItemAtPath:[targetURL path] error:&error] )
            {
                NSLog(@"Changing file permissions failed on file: %@", [targetURL path]);
            }
            
        } else if ( [copyType isEqualToString:NBCWorkflowCopyRegex] ) {
            NSString *sourceFolderPath = copyDict[NBCWorkflowCopyRegexSourceFolderURL];
            NSString *regexString = copyDict[NBCWorkflowCopyRegex];
            NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                               [NSString stringWithFormat:@"/usr/bin/find -E . -depth -regex '%@' | /usr/bin/cpio -admp --quiet '%@'", regexString, [volumeURL path]],
                                               nil];
            NSLog(@"scriptArguments=%@", scriptArguments);
            NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
            NSPipe *stdOut = [[NSPipe alloc] init];
            NSPipe *stdErr = [[NSPipe alloc] init];
            NSTask *newTask = [[NSTask alloc] init];
            
            [newTask setLaunchPath:[commandURL path]];
            [newTask setArguments:scriptArguments];
            
            if ( [sourceFolderPath length] != 0 ) {
                [newTask setCurrentDirectoryPath:sourceFolderPath];
            }
            
            if ( stdOut != nil ) {
                [newTask setStandardOutput:stdOut];
            }
            
            if ( stdErr != nil ) {
                [newTask setStandardError:stdErr];
            }
            
            [newTask launch];
            [newTask waitUntilExit];
            
            NSLog(@"EXIT: %d", [newTask terminationStatus]);
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
        NSString *fileType = modifyDict[NBCWorkflowModifyFileType];
        NSLog(@"fileType=%@", fileType);
        if ( [filePath length] != 0 ) {
            NSString *fileType = modifyDict[NBCWorkflowModifyFileType];
            
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
            }
        } else {
            NSLog(@"ERROR: filePath is nil!");
        }
    }
    
    reply(nil, 0);
}

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
