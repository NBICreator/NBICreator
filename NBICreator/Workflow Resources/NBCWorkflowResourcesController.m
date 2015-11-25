//
//  NBCWorkflowResourcesController.m
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

#import "NBCWorkflowResourcesController.h"
#import "NBCConstants.h"
#import "NBCDiskImageController.h"
#import "NBCWorkflowItem.h"
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

+ (NSURL *)urlForResourceFolder:(NSString *)resourceFolder {
    
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

+ (NSURL *)packageTemporaryFolderURL:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    NSString *packageTemporaryFolderName = [NSString stringWithFormat:@"pkg.%@", [NSString nbc_randomString]];
    NSURL *packageTemporaryFolderURL = [temporaryFolderURL URLByAppendingPathComponent:packageTemporaryFolderName isDirectory:YES];
    if ( ! [packageTemporaryFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ( ! [fm createDirectoryAtURL:packageTemporaryFolderURL withIntermediateDirectories:NO attributes:nil error:&error] ){
            DDLogError(@"[ERROR] Could not create temporary pkg folder!");
            DDLogError(@"%@", error);
            packageTemporaryFolderURL = nil;
        }
    }
    
    return packageTemporaryFolderURL;
} // getTemporaryFolderURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Cached Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSArray *)cachedVersionsFromResourceFolder:(NSString *)resourceFolder {
    NSURL *currentResourceFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourceFolder];
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
    NSURL *currentResourceFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourceFolder];
    if ( currentResourceFolder ) {
        NSURL *currentDownloadsDictURL = [currentResourceFolder URLByAppendingPathComponent:NBCFileNameDownloadsDict];
        if ( [currentDownloadsDictURL checkResourceIsReachableAndReturnError:nil] ) {
            return [[NSDictionary alloc] initWithContentsOfURL:currentDownloadsDictURL];
        }
    }
    
    return @{};
}

- (NSURL *)cachedDownloadsDictURLFromResourceFolder:(NSString *)resourceFolder {
    NSURL *cachedDownloadsDictURL;
    NSURL *currentResourceFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourceFolder];
    if ( currentResourceFolder ) {
        return [currentResourceFolder URLByAppendingPathComponent:NBCFileNameDownloadsDict];
    }
    
    return cachedDownloadsDictURL;
}

+ (NSURL *)cachedBranchURL:(NSString *)branch sha:(NSString *)sha resourcesFolder:(NSString *)resourcesFolder {
    NSURL *cachedBranchURL;
    NSURL *currentResourcesFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourcesFolder];
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

+ (NSURL *)cachedVersionURL:(NSString *)version resourcesFolder:(NSString *)resourcesFolder {
    NSURL *cachedVersionURL;
    NSURL *currentResourcesFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourcesFolder];
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Copy Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (NSURL *)copyFileToResources:(NSURL *)fileURL resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version {
    
    NSURL *destinationURL;
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSURL *resouresFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourcesFolder];
    
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

+ (NSURL *)unzipAndCopyGitBranchToResourceFolder:(NSURL *)zipURL resourcesFolder:(NSString *)resourcesFolder branchDict:(NSDictionary *)branchDict {
    NSError *error;
    NSURL *destinationURL;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *branchName = branchDict[NBCSettingsImagrGitBranch];
    
    NSURL *resouresFolderURL = [NBCWorkflowResourcesController urlForResourceFolder:resourcesFolder];
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
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
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

+ (NSURL *)attachDiskImageAndCopyFileToResourceFolder:(NSURL *)diskImageURL filePath:(NSString *)filePath resourcesFolder:(NSString *)resourcesFolder version:(NSString *)version {
    
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
