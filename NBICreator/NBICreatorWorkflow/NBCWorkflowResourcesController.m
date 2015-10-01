//
//  NBCWorkflowResourcesController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowResourcesController.h"
#import "NBCConstants.h"
#import "NBCDiskImageController.h"
#import "NBCWorkflowItem.h"

#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"
#import "NBCLogging.h"
#import "NSString+randomString.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowResourcesController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCResourcesControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (NSURL *)urlForResourceFolder:(NSString *)resourceFolder {
    
    NSURL *resourceFolderURL;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *urls = [fm URLsForDirectory:NSCachesDirectory
                               inDomains:NSUserDomainMask];
    
    NSURL *userCachesDirectory = [urls firstObject];
    if ( userCachesDirectory != nil ) {
        resourceFolderURL = [userCachesDirectory URLByAppendingPathComponent:resourceFolder];
    }
    
    return resourceFolderURL;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Cached Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSArray *)cachedVersionsFromResourceFolder:(NSString *)resourceFolder {
    NSURL *currentResourceFolder = [self urlForResourceFolder:resourceFolder];
    if ( currentResourceFolder ) {
        NSURL *currentResourceDictURL = [currentResourceFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        if ( [currentResourceDictURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *resourceDict = [[NSDictionary alloc] initWithContentsOfURL:currentResourceDictURL];
            if ( resourceDict ) {
                return [resourceDict allKeys];
            }
        }
    }
    
    return @[];
}

- (NSDictionary *)cachedDownloadsDictFromResourceFolder:(NSString *)resourceFolder {
    NSURL *currentResourceFolder = [self urlForResourceFolder:resourceFolder];
    if ( currentResourceFolder ) {
        NSURL *currentDownloadsDictURL = [currentResourceFolder URLByAppendingPathComponent:NBCFileNameDownloadsDict];
        if ( [currentDownloadsDictURL checkResourceIsReachableAndReturnError:nil] ) {
            return [[NSDictionary alloc] initWithContentsOfURL:currentDownloadsDictURL];
        }
    }
    
    return @{};
}

- (NSURL *)cachedDownloadsDictURLFromResourceFolder:(NSString *)resourceFolder {
    
    DDLogDebug(@"resourceFolder=%@", resourceFolder);
    NSURL *cachedDownloadsDictURL;
    NSURL *currentResourceFolder = [self urlForResourceFolder:resourceFolder];
    DDLogDebug(@"currentResourceFolder=%@", currentResourceFolder);
    if ( currentResourceFolder ) {
        return [currentResourceFolder URLByAppendingPathComponent:NBCFileNameDownloadsDict];
    }
    
    return cachedDownloadsDictURL;
}

- (NSURL *)cachedBranchURL:(NSString *)branch sha:(NSString *)sha resourcesFolder:(NSString *)resourcesFolder {
    NSURL *cachedBranchURL;
    NSURL *currentResourcesFolder = [self urlForResourceFolder:resourcesFolder];
    if ( [currentResourcesFolder checkResourceIsReachableAndReturnError:nil] ) {
        NSURL *currentResourcesDictURL = [currentResourcesFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        if ( [currentResourcesDictURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *resourcesDict = [[NSDictionary alloc] initWithContentsOfURL:currentResourcesDictURL];
            if ( [resourcesDict count] != 0 ) {
                NSDictionary *branchDict = resourcesDict[branch];
                if ( [branchDict count] != 0 ) {
                    NSString *cachedBranchSHA = branchDict[@"sha"];
                    NSString *cachedBranchPath = branchDict[@"url"];
                    if ( [cachedBranchSHA isEqualToString:sha] && [cachedBranchPath length] != 0 ) {
                        cachedBranchURL = [NSURL fileURLWithPath:cachedBranchPath];
                    } else {
                        DDLogDebug(@"[DEBUG] Resource path is empty!");
                    }
                }
            }
        }
    }
    
    return cachedBranchURL;
}

- (NSURL *)cachedVersionURL:(NSString *)version resourcesFolder:(NSString *)resourcesFolder {
    NSURL *cachedVersionURL;
    NSURL *currentResourcesFolder = [self urlForResourceFolder:resourcesFolder];
    if ( [currentResourcesFolder checkResourceIsReachableAndReturnError:nil] ) {
        NSURL *currentResourcesDictURL = [currentResourcesFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        if ( [currentResourcesDictURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *resourcesDict = [[NSDictionary alloc] initWithContentsOfURL:currentResourcesDictURL];
            if ( [resourcesDict count] != 0 ) {
                NSString *resourcePath = resourcesDict[version];
                if ( [resourcePath length] != 0 ) {
                    cachedVersionURL = [NSURL fileURLWithPath:resourcePath];
                } else {
                    DDLogDebug(@"[DEBUG] Resource path is empty!");
                }
            }
        }
    }
    
    return cachedVersionURL;
}

- (NSDictionary *)getCachedSourceItemsDict:(NSString *)buildVersion resourcesFolder:(NSString *)resourcesFolder {
    
    NSDictionary *cachedSourceItemsDict;
    NSURL *currentResourcesFolder = [self urlForResourceFolder:resourcesFolder];
    
    if ( currentResourcesFolder != nil ) {
        NSDictionary *resourcesDict;
        NSURL *currentResourcesDictURL = [currentResourcesFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        if ( [currentResourcesDictURL checkResourceIsReachableAndReturnError:nil] ) {
            resourcesDict = [[NSDictionary alloc] initWithContentsOfURL:currentResourcesDictURL];
            if ( resourcesDict ) {
                cachedSourceItemsDict = resourcesDict[buildVersion];
            }
        }
    }
    return cachedSourceItemsDict;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Copy Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSURL *)copyFileToResources:(NSURL *)fileURL resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version {
    
    NSURL *destinationURL;
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *resouresFolder = [self urlForResourceFolder:resourcesFolder];
    
    // Create resource folder if it does not exist
    NSURL *resourceFolderVersion = [resouresFolder URLByAppendingPathComponent:version];
    if ( ! [resourceFolderVersion checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [fileManager createDirectoryAtURL:resourceFolderVersion withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Creating version resource folder failed: %@", error);
        }
    }
    
    // Delete file if it exists
    NSString *fileName = [fileURL lastPathComponent];
    NSURL *targetFileURL = [resourceFolderVersion URLByAppendingPathComponent:fileName];
    if ( [targetFileURL checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [fileManager removeItemAtURL:targetFileURL error:&error] ) {
            NSLog(@"Could not delete file: %@", error);
        }
    }
    
    // Copy file
    if ( [fileManager copyItemAtURL:fileURL toURL:targetFileURL error:&error] ) {
        destinationURL = targetFileURL;
        NSURL *resourcesDictURL = [resouresFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        NSMutableDictionary *resourceDict = [[[NSDictionary alloc] initWithContentsOfURL:resourcesDictURL] mutableCopy];
        if ( resourceDict ) {
            resourceDict[version] = [targetFileURL path];
        } else {
            resourceDict = [[NSMutableDictionary alloc] init];
            resourceDict[version] = [targetFileURL path];
        }
        
        if ( [resourceDict writeToURL:resourcesDictURL atomically:YES] ) {
            if ( ! [[fileURL path] hasPrefix:@"/Volumes"] ) {
                if ( ! [fileManager removeItemAtURL:fileURL error:&error] ) {
                    DDLogWarn(@"Could not delete %@!", [fileURL lastPathComponent]);
                    DDLogError(@"[ERROR] %@", error);
                }
            }
        } else {
            NSLog(@"Could Not Write Resource Dict at: %@", resourcesDictURL);
        }
    } else {
        NSLog(@"Copy to resource folder failed: %@", error);
    }
    
    return destinationURL;
}

- (NSURL *)copySourceItemToResources:(NSURL *)fileURL sourceItemPath:(NSString *)sourceItemPath resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild {
    
    NSURL *destinationURL;
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *resouresFolder = [self urlForResourceFolder:resourcesFolder];
    
    // Create resource folder if it does not exist
    NSURL *resourceFolderBuildVersion = [resouresFolder URLByAppendingPathComponent:sourceBuild];
    if ( ! [resourceFolderBuildVersion checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fileManager createDirectoryAtURL:resourceFolderBuildVersion withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Creating version resource folder failed: %@", error);
        }
    }
    
    // Delete file if it exists
    NSURL *targetItemURL = [resourceFolderBuildVersion URLByAppendingPathComponent:sourceItemPath];
    if ( [targetItemURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fileManager removeItemAtURL:targetItemURL error:&error] ) {
            NSLog(@"Could not delete file: %@", error);
        }
    }
    
    // Create sourceItemPath intermediate folders if they dont exist
    NSURL *targetItemURLPath = [targetItemURL URLByDeletingLastPathComponent];
    if ( ! [targetItemURLPath checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fileManager createDirectoryAtURL:targetItemURLPath withIntermediateDirectories:YES attributes:nil error:&error] ) {
            NSLog(@"Creating sourceItemPath intermediate folders failed: %@", error);
        }
    }
    
    // Copy file
    if ( [fileManager copyItemAtURL:fileURL toURL:targetItemURL error:&error] ) {
        destinationURL = targetItemURL;
        NSURL *resourcesDictURL = [resouresFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
        NSMutableDictionary *sourceDict;
        NSMutableDictionary *resourceDict = [[[NSDictionary alloc] initWithContentsOfURL:resourcesDictURL] mutableCopy];
        if ( [resourceDict count] != 0 ) {
            sourceDict = [resourceDict[sourceBuild] mutableCopy];
            if ( [sourceDict count] == 0 ) {
                sourceDict = [[NSMutableDictionary alloc] init];
            }
            sourceDict[sourceItemPath] = [destinationURL path];
        } else {
            resourceDict = [[NSMutableDictionary alloc] init];
            sourceDict = [[NSMutableDictionary alloc] init];
            sourceDict[sourceItemPath] = [destinationURL path];
        }
        
        resourceDict[sourceBuild] = sourceDict;
        
        if ( [fileManager isWritableFileAtPath:[[resourcesDictURL path] stringByDeletingLastPathComponent]] ) {
            if ( ! [resourceDict writeToURL:resourcesDictURL atomically:YES] ) {
                NSLog(@"Could Not Write Resource Dict at: %@", resourcesDictURL);
            }
        } else {
            NSLog(@"Don't have write persmissions to folder: %@", [[resourcesDictURL path] stringByDeletingLastPathComponent]);
        }
    } else {
        NSLog(@"Copy to resource folder failed: %@", error);
    }
    
    return destinationURL;
}

- (void)copySourceRegexToResources:(NBCWorkflowItem *)workflowItem regexArray:(NSArray *)regexArray packagePath:(NSString *)packagePath sourceFolder:(NSString *)sourceFolder resourcesFolder:(NSString *)resourcesFolder sourceBuild:(NSString *)sourceBuild {
    
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
    
    NSError *err;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *resouresFolder = [self urlForResourceFolder:resourcesFolder];
    
    // Create resource folder if it does not exist
    NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
    NSString *resourceFolderPathComponent;
    if ( [packageName length] != 0 && [sourceBuild length] != 0 ) {
        resourceFolderPathComponent = [NSString stringWithFormat:@"%@/%@", sourceBuild, packageName];
    } else {
        NSLog(@"Could not get packageName or sourceBuild!");
        return;
    }
    NSURL *resourceFolderPackage = [resouresFolder URLByAppendingPathComponent:resourceFolderPathComponent];
    if ( ! [resourceFolderPackage checkResourceIsReachableAndReturnError:&err] ) {
        if ( ! [fileManager createDirectoryAtURL:resourceFolderPackage withIntermediateDirectories:YES attributes:nil error:&err] ) {
            NSLog(@"Creating version resource folder failed: %@", err);
        }
    }
    
    // ------------------------------------------
    //  Setup command to run createNetInstall.sh
    // ------------------------------------------
    NSMutableArray *scriptArguments = [NSMutableArray arrayWithObjects:@"-c",
                                       [NSString stringWithFormat:@"/usr/bin/find -E . -depth%@ | /usr/bin/cpio -admp --quiet '%@'", regexString, [resourceFolderPackage path]],
                                       nil];
    
    // ------------------------------------------
    //  Setup command to run createNetInstall.sh
    // ------------------------------------------
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
    
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
    
    // -----------------------------------------------
    //  Connect to helper and run createNetInstall.sh
    // -----------------------------------------------
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            // ------------------------------------------------------------------
            //  If task failed, post workflow failed notification
            // ------------------------------------------------------------------
            NSDictionary *userInfo = nil;
            if ( proxyError ) {
                DDLogError(@"[ERROR] %@", proxyError);
                userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
            }
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:scriptArguments currentDirectory:sourceFolder stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            if ( terminationStatus == 0 )
            {
                // ------------------------------------------------------------------
                //  If task exited successfully, post workflow complete notification
                // ------------------------------------------------------------------
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self copySourceRegexToResourcesComplete:workflowItem regexArray:regexArray packagePath:packagePath resourcesFolder:resouresFolder resourceFolderPackage:resourceFolderPackage sourceBuild:sourceBuild];
            } else {
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                NSLog(@"Extracting package failed!");
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [self->_delegate copySourceRegexFailed:workflowItem temporaryFolderURL:resourceFolderPackage];
            }
        }];
    }];
}

- (void)copySourceRegexToResourcesComplete:(NBCWorkflowItem *)workflowItem regexArray:(NSArray *)regexArray packagePath:(NSString *)packagePath resourcesFolder:(NSURL *)resourcesFolder resourceFolderPackage:(NSURL *)resourceFolderPackage sourceBuild:(NSString *)sourceBuild {
    
    NSURL *resourcesDictURL = [resourcesFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
    NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
    NSMutableDictionary *sourceDict;
    NSMutableDictionary *packageDict;
    NSMutableArray *regexArrayDict;
    NSMutableDictionary *resourceDict = [[[NSDictionary alloc] initWithContentsOfURL:resourcesDictURL] mutableCopy];
    if ( [resourceDict count] != 0 ) {
        sourceDict = [resourceDict[sourceBuild] mutableCopy];
        if ( [sourceDict count] == 0 ) {
            sourceDict = [[NSMutableDictionary alloc] init];
        }
        packageDict = [sourceDict[packageName] mutableCopy];
        if ( [packageDict count] == 0 ) {
            packageDict = [[NSMutableDictionary alloc] init];
        }
        regexArrayDict = [packageDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
        if ( [regexArrayDict count] == 0 ) {
            regexArrayDict = [[NSMutableArray alloc] init];
        }
    } else {
        resourceDict = [[NSMutableDictionary alloc] init];
        sourceDict = [[NSMutableDictionary alloc] init];
        packageDict = [[NSMutableDictionary alloc] init];
        regexArrayDict = [[NSMutableArray alloc] init];
    }
    for ( NSString *regex in regexArray ) {
        [regexArrayDict addObject:regex];
    }
    packageDict[NBCSettingsSourceItemsRegexKey] = regexArrayDict;
    if ( resourceFolderPackage != nil ) {
        packageDict[NBCSettingsSourceItemsCacheFolderKey] = [resourceFolderPackage path];
    }
    sourceDict[packageName] = packageDict;
    resourceDict[sourceBuild] = sourceDict;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ( [fm isWritableFileAtPath:[[resourcesDictURL path] stringByDeletingLastPathComponent]] ) {
        if ( ! [resourceDict writeToURL:resourcesDictURL atomically:YES] ) {
            NSLog(@"Could Not Write Resource Dict at: %@", resourcesDictURL);
        }
    } else {
        NSLog(@"Don't have write persmissions to folder: %@", [[resourcesDictURL path] stringByDeletingLastPathComponent]);
    }
    
    [_delegate copySourceRegexComplete:workflowItem packagePath:packagePath resourceFolderPackageURL:resourceFolderPackage];
}

- (NSURL *)unzipAndCopyGitBranchToResourceFolder:(NSURL *)zipURL resourcesFolder:(NSString *)resourcesFolder branchDict:(NSDictionary *)branchDict {
    NSError *error;
    NSURL *destinationURL;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *branchName = branchDict[NBCSettingsImagrGitBranch];
    
    NSURL *resouresFolderURL = [self urlForResourceFolder:resourcesFolder];
    NSURL *targetFolderURL = [resouresFolderURL URLByAppendingPathComponent:branchName];
    NSURL *xcodeProjectFolderTargetURL = [targetFolderURL URLByAppendingPathComponent:@"Imagr"];
    if ( [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        if ( ! [fm removeItemAtURL:targetFolderURL error:&error] ) {
            DDLogError(@"[ERROR] Could not remove folder");
            DDLogError(@"[ERROR] %@", error);
            return nil;
        }
    }
    
    if ( ! [fm createDirectoryAtURL:targetFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
        DDLogError(@"[ERROR] Could not create folder");
        DDLogError(@"[ERROR] %@", error);
        return nil;
    }
    
    // Unzip Archive
    NSString *tmpFolderPath = [NSString stringWithFormat:@"/tmp/zip.%@", [NSString nbc_randomString]];
    NSURL *unzippedImagrProjectRootURL;
    NSURL *xcodeProjectFolderSourceURL;
    if ( [Main unzipFileAtPath:[zipURL path] toDestination:tmpFolderPath] ) {
        NSArray *unzippedRootItems = [fm contentsOfDirectoryAtPath:tmpFolderPath error:NULL];
        for ( NSString *itemName in unzippedRootItems ) {
            NSString *path = [tmpFolderPath stringByAppendingPathComponent:itemName];
            BOOL isDir = NO;
            [fm fileExistsAtPath:path isDirectory:( &isDir )];
            if ( [itemName containsString:@"imagr"] && isDir ) {
                unzippedImagrProjectRootURL = [NSURL fileURLWithPath:path];
                xcodeProjectFolderSourceURL = [unzippedImagrProjectRootURL URLByAppendingPathComponent:@"Imagr"];
                if ( ! [xcodeProjectFolderSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                    xcodeProjectFolderSourceURL = nil;
                }
            }
        }
        
        if ( unzippedImagrProjectRootURL == nil || xcodeProjectFolderSourceURL == nil ) {
            DDLogError(@"[ERROR] Could not get path to Imgr Project Root after unzipping!");
            return nil;
        }
        
        if ( ! [fm moveItemAtURL:xcodeProjectFolderSourceURL toURL:xcodeProjectFolderTargetURL  error:&error] ) {
            DDLogError(@"[ERROR] Could not move unzipped Imagr Project to destinaion folder!");
            DDLogError(@"[ERROR] %@", error);
            return nil;
        }
        
        NSURL *xcodeProjectSourceURL = [unzippedImagrProjectRootURL URLByAppendingPathComponent:@"Imagr.xcodeproj"];
        NSURL *xcodeProjectTargetURL = [targetFolderURL URLByAppendingPathComponent:@"Imagr.xcodeproj"];
        
        if ( ! [fm moveItemAtURL:xcodeProjectSourceURL toURL:xcodeProjectTargetURL error:&error] ) {
            DDLogError(@"[ERROR] Could not move project file!");
            DDLogError(@"[ERROR] %@", error);
            return nil;
        }
        
        if ( [targetFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            destinationURL = targetFolderURL;
            
            NSString *branchSHA = branchDict[NBCSettingsImagrGitBranchSHA];
            NSURL *resourcesDictURL = [resouresFolderURL URLByAppendingPathComponent:NBCFileNameResourcesDict];
            NSMutableDictionary *resourceDict = [[[NSDictionary alloc] initWithContentsOfURL:resourcesDictURL] mutableCopy];
            NSDictionary *resourcesBranchDict = @{
                                                  @"url" : [targetFolderURL path],
                                                  @"sha" : branchSHA
                                                  };
            if ( resourceDict ) {
                resourceDict[branchName] = resourcesBranchDict;
            } else {
                resourceDict = [[NSMutableDictionary alloc] init];
                resourceDict[branchName] = resourcesBranchDict;
            }
            
            if ( ! [resourceDict writeToURL:resourcesDictURL atomically:YES] ) {
                DDLogError(@"[ERROR] Could Not Write Resource Dict at: %@", resourcesDictURL);
            }
        } else {
            DDLogError(@"[ERROR] Imagr Root Path doesn't exist somehow.");
        }
    }
    
    return destinationURL;
}

- (void)buildProjectAtURL:(NSURL *)projectURL buildTarget:(NSString *)buildTarget {
    
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        NSURL *productURL;
        NSTask *newTask =  [[NSTask alloc] init];
        [newTask setLaunchPath:@"/usr/bin/xcodebuild"];
        [newTask setArguments:@[ @"-configuration", buildTarget ]];
        [newTask setCurrentDirectoryPath:[projectURL path]];
        [newTask setStandardOutput:[NSPipe pipe]];
        [newTask setStandardError:[NSPipe pipe]];
        [newTask launch];
        [newTask waitUntilExit];
        
        //  NSData *newTaskStandardOutputData = [[[newTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        //  NSString *stdOut = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
        NSData *newTaskStandardErrorData = [[[newTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:newTaskStandardErrorData encoding:NSUTF8StringEncoding];
        
        if ( [newTask terminationStatus] == 0 ) {
            productURL = [projectURL URLByAppendingPathComponent:[NSString stringWithFormat:@"build/%@/Imagr.app", buildTarget]];
            if ( [productURL checkResourceIsReachableAndReturnError:nil] ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate xcodeBuildComplete:productURL];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate xcodeBuildFailed:@"Could not find product after build!"];
                });
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate xcodeBuildFailed:stdErr];
            });
            DDLogError(@"[ERROR] %@", stdErr);
        }
    });
}

- (NSURL *)attachDiskImageAndCopyFileToResourceFolder:(NSURL *)diskImageURL filePath:(NSString *)filePath resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version {
    
    NSURL *destinationURL;
    
    NSError *error;
    NSURL *volumeURL;
    NSDictionary *diskImageDict;
    NSArray *hdiutilOptions = @[
                                @"-mountRandom", @"/Volumes",
                                @"-nobrowse",
                                @"-noverify",
                                @"-plist",
                                ];
    
    if ( [NBCDiskImageController attachDiskImageAndReturnPropertyList:&diskImageDict
                                                              dmgPath:diskImageURL
                                                              options:hdiutilOptions
                                                                error:&error] ) {
        if ( diskImageDict ) {
            volumeURL = [NBCDiskImageController getMountURLFromHdiutilOutputPropertyList:diskImageDict];
            NSURL *imagrApplicationURL = [volumeURL URLByAppendingPathComponent:filePath];
            destinationURL = [self copyFileToResources:imagrApplicationURL resourcesFolder:resourcesFolder version:version];
            if ( ! destinationURL ) {
                NSLog(@"Copy Failed!");
            }
            
            if ( [NBCDiskImageController detachDiskImageAtPath:[volumeURL path]] ) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ( ! [fileManager removeItemAtURL:diskImageURL error:&error] ) {
                    NSLog(@"Removing Disk Image Failed! = %@", error);
                }
            } else {
                NSLog(@"Detaching Disk Image Failed!");
            }
        } else {
            NSLog(@"Got no DiskImageDict!");
        }
    } else {
        NSLog(@"Error: %@", error);
    }
    
    return destinationURL;
}

@end
