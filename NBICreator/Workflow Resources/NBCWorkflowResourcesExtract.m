//
//  NBCWorkflowResourcesExtract.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-04.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowResourcesExtract.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCWorkflowItem.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowResourcesExtract

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCWorkflowResourcesExtractDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
} // initWithDelegate

- (void)addItemToCopyToBaseSystem:(NSDictionary *)itemDict {
    [_resourcesBaseSystemCopy addObject:itemDict];
} // addItemToCopyToBaseSystem

- (void)extractResources:(NSDictionary *)resourcesToExtract workflowItem:(NBCWorkflowItem *)workflowItem {
    
    [self setWorkflowItem:workflowItem];
    [self setSource:[_workflowItem source]];
    [self setResourcesBaseSystemCopy:[[NSMutableArray alloc] init]];
    
    NSError *error;
    
    if (
        [[_source sourceType] isEqualToString:NBCSourceTypeInstallESDDiskImage] ||
        [[_source sourceType] isEqualToString:NBCSourceTypeInstallerApplication]
        ) {
        
        NSURL *installESDVolumeURL = [_source installESDVolumeURL];
        if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
            [self setInstallESDVolumeURL:installESDVolumeURL];
            DDLogDebug(@"[DEBUG] InstallESD volume path: %@", [_installESDVolumeURL path]);
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Path to InstallESD volume was empty"]}];
            return;
        }
    }
    
    [self setSourceVersionMinor:(int)[[_source expandVariables:@"%OSMINOR%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (minor): %d", _sourceVersionMinor);
    
    NSString *sourceOSBuild = [[_workflowItem source] sourceBuild];
    DDLogDebug(@"[DEBUG] Source os build version: %@", sourceOSBuild);
    if ( [sourceOSBuild length] != 0 ) {
        [self setSourceOSBuild:sourceOSBuild];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Source os build was empty"]}];
        return;
    }
    
    [self checkExtractedItems:resourcesToExtract];
}

- (NSURL *)cachedResourcesDictForResourceFolderURL:(NSString *)resourceFolder {
    NSURL *currentResourceFolder = [NBCWorkflowResourcesController urlForResourceFolder:resourceFolder];
    if ( [currentResourceFolder checkResourceIsReachableAndReturnError:nil] ) {
        return [currentResourceFolder URLByAppendingPathComponent:NBCFileNameResourcesDict];
    } else {
        return nil;
    }
} // cachedSourceItemsDict

- (NSDictionary *)cachedResourcesDictForResourceFolder:(NSString *)resourcesFolder {
    NSURL *currentResourcesDictURL = [self cachedResourcesDictForResourceFolderURL:resourcesFolder];
    if ( [currentResourcesDictURL checkResourceIsReachableAndReturnError:nil] ) {
        return [[NSDictionary alloc] initWithContentsOfURL:currentResourcesDictURL];
    } else {
        return nil;
    }
} // cachedSourceItemsDict

- (void)checkExtractedItems:(NSDictionary *)resourcesToCheck {
    
    DDLogInfo(@"Checking cached resources...");
    
    // ---------------------------------------------------------------
    //  Check if source items are already downloaded, then return local urls.
    //  If not, extract and copy to resources for future use.
    // ---------------------------------------------------------------
    if ( [resourcesToCheck count] != 0 ) {
        
        NSDictionary *cachedResourcesDict = [self cachedResourcesDictForResourceFolder:NBCFolderResourcesCacheSource];
        NSDictionary *cachedResourcesForBuildDict = cachedResourcesDict[_sourceOSBuild];
        if ( [cachedResourcesForBuildDict count] != 0 ) {
            NSMutableDictionary *resourcesToExtract = [[NSMutableDictionary alloc] init];
            
            // --------------------------------------------------------------------------------------
            //  Loop through all packages and their regexes to see which have already been extracted
            // --------------------------------------------------------------------------------------
            for ( NSString *packagePath in [resourcesToCheck allKeys] ) {
                DDLogInfo(@"Checking cached resources for %@", [packagePath lastPathComponent]);
                
                NSDictionary *packageDict = resourcesToCheck[packagePath];
                NSDictionary *cachedPackageDict = cachedResourcesForBuildDict[[[packagePath lastPathComponent] stringByDeletingPathExtension]];
                if ( [packageDict count] != 0 ) {
                    NSMutableDictionary *newPackageDict = [[NSMutableDictionary alloc] init];
                    NSMutableArray *newRegexArray = [[NSMutableArray alloc] init];
                    NSURL *cacheFolderURL = [NSURL fileURLWithPath:cachedPackageDict[NBCSettingsSourceItemsCacheFolderKey] ?: @""];
                    DDLogDebug(@"[DEBUG] Cached resources %@ folder path: %@", [packagePath lastPathComponent], [cacheFolderURL path]);
                    
                    if ( ! [cacheFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                        [newRegexArray addObjectsFromArray:packageDict[NBCSettingsSourceItemsRegexKey]];
                    } else {
                        for ( NSString *regex in packageDict[NBCSettingsSourceItemsRegexKey] ?: @[] ) {
                            if ( [cachedPackageDict[NBCSettingsSourceItemsRegexKey] ?: @[] containsObject:regex] ) {
                                DDLogDebug(@"[DEBUG] Regex: %@ IS cached!", regex);
                                [self addItemToCopyToBaseSystem:@{
                                                                  NBCWorkflowCopyType :                 NBCWorkflowCopyRegex,
                                                                  NBCWorkflowCopyRegexSourceFolderURL : [cacheFolderURL path],
                                                                  NBCWorkflowCopyRegex :                regex
                                                                  }];
                            } else {
                                DDLogDebug(@"[DEBUG] Regex: %@ is NOT cached!", regex);
                                [newRegexArray addObject:regex];
                            }
                        }
                    }
                    
                    if ( [newRegexArray count] != 0 ) {
                        newPackageDict[NBCSettingsSourceItemsRegexKey] = newRegexArray;
                    }
                    
                    if ( [newPackageDict count] != 0 ) {
                        resourcesToExtract[packagePath] = newPackageDict;
                    }
                } else {
                    DDLogWarn(@"[WARN] No regexes was passed for %@", [packagePath lastPathComponent]);
                }
            }
            
            // ------------------------------------------------------------------------------------
            //  If all items was cached, resourcesToExtract should be empty.
            //  If any item was added to resourcesToExtract, pass it along for extraction
            // ------------------------------------------------------------------------------------
            if ( [resourcesToExtract count] != 0 ) {
                [self extractResources:resourcesToExtract];
            } else {
                DDLogDebug(@"[DEBUG] No resource need extraction");
                if ( _delegate && [_delegate respondsToSelector:@selector(resourceExtractionComplete:)] ) {
                    [_delegate resourceExtractionComplete:_resourcesBaseSystemCopy];
                }
            }
        } else {
            DDLogInfo(@"No cached resources found for os build: %@", _sourceOSBuild);
            [self extractResources:[resourcesToCheck mutableCopy]];
        }
    } else {
        DDLogInfo(@"No resources to extract");
        if ( _delegate && [_delegate respondsToSelector:@selector(resourceExtractionComplete:)] ) {
            [_delegate resourceExtractionComplete:_resourcesBaseSystemCopy];
        }
    }
} // checkExtractedItems

- (void)extractResources:(NSMutableDictionary *)resourcesToExtract {
    
    NSError *err = nil;
    
    if ( [resourcesToExtract count] != 0 ) {
        NSString *packagePath = [[resourcesToExtract allKeys] firstObject];
        
        if ( _progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)] ) {
            [_progressDelegate updateProgressStatus:[NSString stringWithFormat:@"Extracting resources from %@...", [packagePath lastPathComponent]]];
        }
        
        NSURL *temporaryFolderURL = [_workflowItem temporaryFolderURL];
        DDLogDebug(@"[DEBUG] Temporary folder path: %@", [temporaryFolderURL path]);
        if ( [temporaryFolderURL checkResourceIsReachableAndReturnError:&err] ) {
            
            NSURL *temporaryPackageFolderURL = [NBCWorkflowResourcesController packageTemporaryFolderURL:_workflowItem];
            DDLogDebug(@"[DEBUG] Temporary package folder path: %@", [temporaryPackageFolderURL path]);
            if ( [temporaryPackageFolderURL checkResourceIsReachableAndReturnError:&err] ) {
                
                // ---------------------------------------------------------------------------------
                //  Choose extract method depending on os version, new package archive in 10.10+
                // ---------------------------------------------------------------------------------
                
                NSString *command = @"/bin/bash";
                NSArray *arguments;
                if ( _sourceVersionMinor <= 9 ) {
                    arguments = @[ @"-c", [NSString stringWithFormat:@"/usr/bin/xar -x -f \"%@\" Payload -C \"%@\"; /usr/bin/cd \"%@\"; /usr/bin/cpio -idmu -I \"%@/Payload\"", packagePath, [temporaryFolderURL path], [temporaryPackageFolderURL path], [temporaryFolderURL path]] ];
                } else {
                    NSURL *pbzxURL = [[NSBundle mainBundle] URLForResource:@"pbzx" withExtension:@""];
                    if ( [pbzxURL checkResourceIsReachableAndReturnError:&err] ) {
                        arguments = @[ @"-c", [NSString stringWithFormat:@"%@ %@ | /usr/bin/cpio -idmu --quiet", [pbzxURL path], packagePath], ];
                    } else {
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Could not find binary pbzx!"] }];
                        return;
                    }
                }
                
                // ---------------------------------------------------------------------------------
                //  Run extract task from helper
                // ---------------------------------------------------------------------------------
                
                dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
                dispatch_async(taskQueue, ^{
                    
                    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
                    [helperConnector connectToHelper];
                    [[helperConnector connection] setExportedObject:[self->_workflowItem progressView]];
                    [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
                    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                object:self
                                                                              userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Extracting resources from %@ failed", [packagePath lastPathComponent]]]}];
                        });
                        return;
                    }] runTaskWithCommand:command arguments:arguments currentDirectory:[temporaryPackageFolderURL path] environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
                        if ( terminationStatus == 0 ) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self copyExtractedResourcesToCache:resourcesToExtract packagePath:packagePath temporaryPackagePath:[temporaryPackageFolderURL path]];
                            });
                        } else {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                                    object:self
                                                                                  userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Extracting resources from %@ failed", [packagePath lastPathComponent]]]}];
                            });
                            return;
                        }
                    }];
                });
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Package temporary folder doesn't exist!"] }];
            }
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Temporary folder doesn't exist!"] }];
        }
    } else {
        DDLogInfo(@"No more resources need extracting");
        if ( _delegate && [_delegate respondsToSelector:@selector(resourceExtractionComplete:)] ) {
            [_delegate resourceExtractionComplete:_resourcesBaseSystemCopy];
        }
    }
} // extractResources

- (void)copyExtractedResourcesToCache:(NSMutableDictionary *)resourcesToExtract packagePath:(NSString *)packagePath temporaryPackagePath:(NSString *)temporaryPackagePath  {
    
    if ( _progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)] ) {
        [_progressDelegate updateProgressStatus:@"Copying extracted resources to cache folder..."];
    }
    
    NSError *err;
    
    // ---------------------------------------------------------------------------------
    //  Create single regex string for '/usr/bin/find' from array of regexes
    // ---------------------------------------------------------------------------------
    NSArray *regexArray = resourcesToExtract[packagePath][NBCSettingsSourceItemsRegexKey];
    if ( [regexArray count] != 0 ) {
        __block NSMutableString *regexString = [[NSMutableString alloc] init];
        [regexArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(stop)
            if ( idx == 0 ) {
                [regexString appendString:[NSString stringWithFormat:@"-regex '%@'", obj]];
            } else {
                [regexString appendString:[NSString stringWithFormat:@" -o -regex '%@'", obj]];
            }
        }];
        
        // ---------------------------------------------------------------------------------
        //  Create package cache folder if it doesn't already exist
        // ---------------------------------------------------------------------------------
        NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
        NSString *resourceFolderPathComponent = [NSString stringWithFormat:@"%@/%@", _sourceOSBuild, packageName];
        
        NSURL *resourcesCacheFolderURL = [NBCWorkflowResourcesController urlForResourceFolder:NBCFolderResourcesCacheSource];
        NSURL *resourcesCacheFolderPackageURL = [resourcesCacheFolderURL URLByAppendingPathComponent:resourceFolderPathComponent];
        DDLogDebug(@"[DEBUG] Cache folder for package path: %@", [resourcesCacheFolderPackageURL path]);
        
        if ( ! [resourcesCacheFolderPackageURL checkResourceIsReachableAndReturnError:&err] ) {
            if ( ! [[NSFileManager defaultManager] createDirectoryAtURL:resourcesCacheFolderPackageURL withIntermediateDirectories:YES attributes:nil error:&err] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{ NBCUserInfoNSErrorKey : err ?: [NBCError errorWithDescription:@"Creating temporary folder failed!"] }];
                return;
            }
        }
        
        NSString *command = @"/bin/bash";
        NSArray *arguments = @[ @"-c", [NSString stringWithFormat:@"/usr/bin/find -E . -depth %@ | /usr/bin/cpio -admp --quiet '%@'", regexString, [resourcesCacheFolderPackageURL path]]];
        
        // ---------------------------------------------------------------------------------
        //  Run copy task from helper
        // ---------------------------------------------------------------------------------
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:[self->_workflowItem progressView]];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                        object:self
                                                                      userInfo:@{ NBCUserInfoNSErrorKey : proxyError ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Copying resources to %@ cache failed", [packagePath lastPathComponent]]]}];
                });
                return;
            }] runTaskWithCommand:command arguments:arguments currentDirectory:temporaryPackagePath environmentVariables:@{} withReply:^(NSError *error, int terminationStatus) {
                if ( terminationStatus == 0 ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self copyExtractedResourcesComplete:resourcesToExtract resourcesRegexArray:regexArray packagePath:packagePath packageCacheFolderPath:[resourcesCacheFolderPackageURL path]];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                            object:self
                                                                          userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:[NSString stringWithFormat:@"Copying resources to %@ cache failed", [packagePath lastPathComponent]]]}];
                    });
                }
            }];
        });
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"No regexes passed to copy step!"]}];
    }
    
} // copyExtractedResourcesToCache

- (void)copyExtractedResourcesComplete:(NSMutableDictionary *)resourcesToExtract resourcesRegexArray:(NSArray *)resourcesRegexArray packagePath:(NSString *)packagePath packageCacheFolderPath:(NSString *)packageCacheFolderPath {
    
    DDLogDebug(@"[DEBUG] Copy complete!");
    
    NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
    NSMutableDictionary *cachedResourcesDict = [[self cachedResourcesDictForResourceFolder:NBCFolderResourcesCacheSource] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableDictionary *cachedResourcesForBuildDict = [cachedResourcesDict[_sourceOSBuild] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableDictionary *cachedResourcesForPackageDict = [cachedResourcesForBuildDict[packageName] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *cachedPackageRegexArray = [cachedResourcesForPackageDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    
    // ---------------------------------------------------------------------------------
    //  Add the newly cached regexes to array
    // ---------------------------------------------------------------------------------
    [cachedPackageRegexArray addObjectsFromArray:resourcesRegexArray];
    
    // ---------------------------------------------------------------------------------
    //  Update resource dict with the newly added items
    // ---------------------------------------------------------------------------------
    cachedResourcesForPackageDict[NBCSettingsSourceItemsRegexKey] =         cachedPackageRegexArray;
    cachedResourcesForPackageDict[NBCSettingsSourceItemsCacheFolderKey] =   packageCacheFolderPath;
    cachedResourcesForBuildDict[packageName] =                              cachedResourcesForPackageDict;
    cachedResourcesDict[_sourceOSBuild] =                                   cachedResourcesForBuildDict;
    
    DDLogDebug(@"[DEBUG] Updating cached resources plist...");
    
    // ---------------------------------------------------------------------------------
    //  Write updated plist to disk
    // ---------------------------------------------------------------------------------
    NSURL *cachedResourcesDictURL = [self cachedResourcesDictForResourceFolderURL:NBCFolderResourcesCacheSource];
    DDLogDebug(@"[DEBUG] Cached resources plist path: %@", [cachedResourcesDictURL path]);
    
    if ( [[NSFileManager defaultManager] isWritableFileAtPath:[[cachedResourcesDictURL path] stringByDeletingLastPathComponent]] ) {
        if ( ! [cachedResourcesDict writeToURL:cachedResourcesDictURL atomically:YES] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Saving updated cache dict failed!"]}];
            return;
        }
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{ NBCUserInfoNSErrorKey : [NBCError errorWithDescription:[NSString stringWithFormat:@"You don't have write permissions to folder: %@", [cachedResourcesDictURL path]]]}];
        return;
    }
    
    // ---------------------------------------------------------------------------------
    //  Update modification dict with the newly cached regexes
    // ---------------------------------------------------------------------------------
    for ( NSString *regex in resourcesRegexArray ) {
        [self addItemToCopyToBaseSystem:@{
                                          NBCWorkflowCopyType :                  NBCWorkflowCopyRegex,
                                          NBCWorkflowCopyRegexSourceFolderURL :  packageCacheFolderPath,
                                          NBCWorkflowCopyRegex :                 regex
                                          }];
    }
    
    // -------------------------------------------------------------------------------------------------------------
    //  Remove current package from array and run extractResources for the remaining packages in resourcesToExtract
    // -------------------------------------------------------------------------------------------------------------
    [resourcesToExtract removeObjectForKey:packagePath];
    [self extractResources:resourcesToExtract];
}

@end
