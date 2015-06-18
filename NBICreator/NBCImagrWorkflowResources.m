//
//  NBCImagrWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowResources.h"
#import "NBCConstants.h"
#import "NSString+randomString.h"

#import "NBCDiskImageController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowNBIController.h"

@implementation NBCImagrWorkflowResources

#pragma mark -
#pragma mark Run Workflow
#pragma mark -

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    _target = [workflowItem target];
    _resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
    _resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
    _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
    _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
    _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
    [self setUserSettings:[workflowItem userSettings]];
    [self setNbiCreationTool:_userSettings[NBCSettingsNBICreationToolKey]];
    [self setResourcesSettings:[workflowItem resourcesSettings]];
    _resourcesController = [[NBCWorkflowResourcesController alloc] initWithDelegate:self];
    [self setResourcesCount:3];
    
    // -------------------------------------------------------
    //  Update _resourcesCount with all sourceItems
    // -------------------------------------------------------
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    if ( [sourceItemsDict count] != 0 ) {
        NSArray *sourcePackages = [sourceItemsDict allKeys];
        for ( NSString *packagePath in sourcePackages ) {
            NSDictionary *packageDict = sourceItemsDict[packagePath];
            NSDictionary *packageDictPath = packageDict[NBCSettingsSourceItemsPathKey];
            int packageCount = (int)[packageDictPath count];
            [self setResourcesCount:( _resourcesCount + packageCount )];
            NSArray *packageRegexArray = packageDict[NBCSettingsSourceItemsRegexKey];
            if ( [packageDict count] != 0 ) {
                [self setResourcesCount:( _resourcesCount + (int)[packageRegexArray count] )];
            }
        }
    }
    
    if ( _userSettings ) {
        [self getItemsFromSource:workflowItem];
        [self getImagrApplication:workflowItem];
        [self createImagrSettingsPlist:workflowItem];
        [self createImagrRCImaging:workflowItem];
    } else {
        NSLog(@"Could not get user settings!");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    // ------------------------------------------------------
    //  Extract info from downloadInfo Dict
    // ------------------------------------------------------
    NSString *resourceTag = downloadInfo[NBCDownloaderTag];
    NSString *version = downloadInfo[NBCDownloaderVersion];
    
    // ------------------------------------------------------
    //  Send command to correct copy method based on tag
    // ------------------------------------------------------
    if ( [resourceTag isEqualToString:NBCDownloaderTagImagr] ) {
        [self addImagrToResources:url version:version];
    } else if ( [resourceTag isEqualToString:NBCDownloaderTagPython] ) {
        [self addPythonToResources:url version:version];
    }
} // fileDownloadCompleted:downloadInfo

#pragma mark -
#pragma mark Delegate Methods NBCSettingsController
#pragma mark -

- (void)copySourceRegexComplete:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath resourceFolderPackageURL:(NSURL *)resourceFolderPackage {
    NSLog(@"copySourceRegexComplete");
    NSLog(@"packagePath=%@", packagePath);
    NSDictionary *sourceItemsResourcesDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    NSLog(@"sourceItemsResourcesDict=%@", sourceItemsResourcesDict);
    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packagePath];
    NSLog(@"resourcesPackageDict=%@", resourcesPackageDict);
    NSArray *regexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
    NSLog(@"regexes=%@", regexes);
    NSLog(@"resourceFolderPackage=%@", resourceFolderPackage);
    for ( NSString *regex in regexes ) {
        NSDictionary *newRegexCopySetting = @{
                                              NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                              NBCWorkflowCopyRegexSourceFolderURL : [resourceFolderPackage path],
                                              NBCWorkflowCopyRegex : regex
                                              };
        
        [self updateBaseSystemCopyDict:newRegexCopySetting];
    }
    
    [self extractItemsFromSource:workflowItem];
}

- (void)copySourceRegexFailed:(NBCWorkflowItem *)workflowItem temporaryFolderURL:(NSURL *)temporaryFolderURL {
#pragma unused(workflowItem, temporaryFolderURL)
    NSLog(@"copySourceRegexFailed!");
}

#pragma mark -
#pragma mark Get External Resources
#pragma mark -

- (void)downloadResource:(NSURL *)resourceDownloadURL resourceTag:(NSString *)resourceTag version:(NSString *)version {
    NSDictionary *downloadInfo = @{
                                   NBCDownloaderTag : resourceTag,
                                   NBCDownloaderVersion : version
                                   };
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadFileFromURL:resourceDownloadURL destinationPath:@"/tmp" downloadInfo:downloadInfo];
} // downloadResource:resourceTag:version

- (void)getPython:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    NSString *selectedPythonVersion = _userSettings[NBCSettingsPythonVersion];
    
    if ( selectedPythonVersion ) {
        // ---------------------------------------------------------------
        //  Check if python is already downloaded, then return local url.
        //  If not, download python and copy to resources for future use.
        // ---------------------------------------------------------------
        [self setPythonVersion:selectedPythonVersion];
        NSURL *pythonURLLocal = [_resourcesController cachedVersionURL:selectedPythonVersion resourcesFolder:NBCFolderResourcesPython];
        if ( pythonURLLocal != nil ) {
            [self updateBaseSystemInstallerDict:pythonURLLocal choiceChangesXML:nil];
        } else {
            NSString *pythonDownloadURL = _resourcesSettings[NBCSettingsPythonDownloadURL];
            if ( [pythonDownloadURL length] != 0 ) {
                [self downloadResource:[NSURL URLWithString:pythonDownloadURL] resourceTag:NBCDownloaderTagPython version:selectedPythonVersion];
            } else {
                NSLog(@"Could not get python download url from resources settings!");
            }
        }
    } else {
        NSLog(@"Could not get selected python version from user settings!");
    }
} // getPython

- (void)addPythonToResources:(NSURL *)downloadedFileURL version:(NSString *)version {
    
    NSURL *destinationURL;
    NSString *downloadedFileExtension = [downloadedFileURL pathExtension];
    
    // --------------------------------------------------------------------------------------------------------------
    //  Check extension of downloaded item and copy python package using required steps depending on downloaded item
    // --------------------------------------------------------------------------------------------------------------
    if ( [downloadedFileExtension isEqualToString:@"dmg"] ) {
        destinationURL = [_resourcesController attachDiskImageAndCopyFileToResourceFolder:downloadedFileURL
                                                                                 filePath:@"Python.mpkg"
                                                                          resourcesFolder:NBCFolderResourcesPython
                                                                                  version:version];
        
    } else if ( [downloadedFileExtension isEqualToString:@"pkg"] || [downloadedFileExtension isEqualToString:@"mpkg"] ) {
        destinationURL = [_resourcesController copyFileToResources:downloadedFileURL
                                                   resourcesFolder:NBCFolderResourcesPython
                                                           version:version];
    }
    
    if ( destinationURL ) {
        [self updateBaseSystemInstallerDict:destinationURL choiceChangesXML:nil];
    } else {
        NSLog(@"Got no URL to copied python item, something went wrong!");
    }
} // addPythonToResources:version

- (void)getImagrApplication:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    NSString *selectedImagrVersion = _userSettings[NBCSettingsImagrVersion];
    NSString *imagrApplicationTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrApplicationTargetPath = NBCImagrApplicationNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrApplicationTargetPath = NBCImagrApplicationTargetURL;
    }
    
    if ( selectedImagrVersion == nil ) {
        NSLog(@"Could not get selected Imagr version from user settings!");
    } else if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        NSString *imagrLocalVersionPath = _userSettings[NBCSettingsImagrLocalVersionPath];
        if ( [imagrLocalVersionPath length] != 0 ) {
            NSDictionary *newCopyAttributes  = @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0755
                                                 };
            
            NSDictionary *newCopySetting = @{
                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                             NBCWorkflowCopySourceURL : imagrLocalVersionPath,
                                             NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                             NBCWorkflowCopyAttributes : newCopyAttributes
                                             };
            
            if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                [_resourcesBaseSystemCopy addObject:newCopySetting];
            } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                [_resourcesNetInstallCopy addObject:newCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            NSLog(@"could not get imagrLocalVersionPath from user settings!");
        }
    } else {
        // ---------------------------------------------------------------
        //  Check if Imagr is already downloaded, then return local url.
        //  If not, download Imagr and copy to resources for future use.
        // ---------------------------------------------------------------
        [self setImagrVersion:selectedImagrVersion];
        NSURL *imagrURLLocal = [_resourcesController cachedVersionURL:selectedImagrVersion resourcesFolder:NBCFolderResourcesImagr];
        if ( imagrURLLocal != nil ) {
            NSDictionary *newCopyAttributes  = @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0755
                                                 };
            
            NSDictionary *newCopySetting = @{
                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                             NBCWorkflowCopySourceURL : [imagrURLLocal path],
                                             NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                             NBCWorkflowCopyAttributes : newCopyAttributes
                                             };
            
            if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                [_resourcesBaseSystemCopy addObject:newCopySetting];
            } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                [_resourcesNetInstallCopy addObject:newCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            NSString *imagrDownloadURL = _resourcesSettings[NBCSettingsImagrDownloadURL];
            if ( [imagrDownloadURL length] != 0 ) {
                [self downloadResource:[NSURL URLWithString:imagrDownloadURL] resourceTag:NBCDownloaderTagImagr version:selectedImagrVersion];
            } else {
                NSLog(@"Could not get Imagr download url from resources settings!");
            }
        }
    }
} // getImagrApplication

- (void)addImagrToResources:(NSURL *)downloadedFileURL version:(NSString *)version {
    NSString *imagrApplicationTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrApplicationTargetPath = NBCImagrApplicationNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrApplicationTargetPath = NBCImagrApplicationTargetURL;
    }
    
    // ---------------------------------------------------------------
    //  Extract Imagr from dmg and copy to resourecs for future use
    // ---------------------------------------------------------------
    NSURL *destinationURL = [_resourcesController attachDiskImageAndCopyFileToResourceFolder:downloadedFileURL
                                                                                    filePath:@"Imagr.app"
                                                                             resourcesFolder:NBCFolderResourcesImagr
                                                                                     version:version];
    if ( destinationURL ) {
        NSDictionary *copyAttributes  = @{
                                          NSFileOwnerAccountName : @"root",
                                          NSFileGroupOwnerAccountName : @"wheel",
                                          NSFilePosixPermissions : @0755
                                          };
        
        NSDictionary *copySettings = @{
                                       NBCWorkflowCopyType : NBCWorkflowCopy,
                                       NBCWorkflowCopySourceURL : [destinationURL path],
                                       NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                       NBCWorkflowCopyAttributes : copyAttributes
                                       };
        
        if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
            [self updateBaseSystemCopyDict:copySettings];
        } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            [self updateNetInstallCopyDict:copySettings];
        }
    } else {
        NSLog(@"Got no URL to copied Imagr item, something went wrong!");
    }
} // addImagrToResources:version

#pragma mark -
#pragma mark Collect Resources From OS X Installer Package
#pragma mark -

- (void)getItemsFromSource:(NBCWorkflowItem *)workflowItem {
    
    NSString *sourceBuildVersion = [[workflowItem source] sourceBuild];
    
    if ( [sourceBuildVersion length] != 0 ) {
        // ---------------------------------------------------------------
        //  Check if source items are already downloaded, then return local urls.
        //  If not, extract and copy to resources for future use.
        // ---------------------------------------------------------------
        NSDictionary *sourceItemsResourcesDict = [_resourcesController getCachedSourceItemsDict:sourceBuildVersion resourcesFolder:NBCFolderResourcesSource];
        if ( [sourceItemsResourcesDict count] != 0 ) {
            NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
            NSMutableDictionary *newSourceItemsDict = [[NSMutableDictionary alloc] init];
            
            // -------------------------------------------------------
            //  Loop through all packages that contain required items
            // -------------------------------------------------------
            NSArray *sourcePackages = [sourceItemsDict allKeys];
            for ( NSString *packagePath in sourcePackages ) {
                NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
                NSDictionary *packageDict = sourceItemsDict[packagePath];
                if ( [packageDict count] != 0 ) {
                    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packageName];
                    NSMutableDictionary *newResourcesPackageDict = [[NSMutableDictionary alloc] init];
                    
                    NSArray *regexes = packageDict[NBCSettingsSourceItemsRegexKey];
                    NSMutableArray *newRegexesArray = [[NSMutableArray alloc] init];
                    NSArray *resourcesRegexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
                    for ( NSString *regex in regexes ) {
                        NSLog(@"regex=%@", regex);
                        if ( [resourcesRegexes containsObject:regex] ) {
                            NSString *sourceFolderPath = resourcesPackageDict[NBCSettingsSourceItemsCacheFolderKey];
                            NSLog(@"sourceFolderPath=%@", sourceFolderPath);
                            if ( [sourceFolderPath length] != 0 ) {
                                NSDictionary *newRegexCopySetting = @{
                                                                      NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                                                      NBCWorkflowCopyRegexSourceFolderURL : sourceFolderPath,
                                                                      NBCWorkflowCopyRegex : regex
                                                                      };
                                
                                [self updateBaseSystemCopyDict:newRegexCopySetting];
                            } else {
                                NSLog(@"Could not get sourceFolderPath from packageDict");
                            }
                        } else {
                            [newRegexesArray addObject:regex];
                        }
                    }
                    
                    if ( [newRegexesArray count] != 0 ) {
                        newResourcesPackageDict[NBCSettingsSourceItemsRegexKey] = newRegexesArray;
                    }
                    
                    NSArray *paths = packageDict[NBCSettingsSourceItemsPathKey];
                    NSLog(@"paths=%@", paths);
                    NSMutableArray *newPathsArray = [[NSMutableArray alloc] init];
                    NSDictionary *resourcesPathsDict = resourcesPackageDict[NBCSettingsSourceItemsPathKey];
                    for ( NSString *packageItemPath in paths ) {
                        // -----------------------------------------------------------------------
                        //  Check if item exists in resource folder
                        //  If it does, add it with a copySetting to _resourcesBaseSystemCopy
                        //  If it doesn't, add it to a new sourceItemsDict to pass for extraction
                        // -----------------------------------------------------------------------
                        NSString *localItemPath = resourcesPathsDict[packageItemPath];
                        if ( [localItemPath length] != 0 ) {
                            NSDictionary *newCopyAttributes  = @{
                                                                 NSFileOwnerAccountName : @"root",
                                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                                 NSFilePosixPermissions : @0755
                                                                 };
                            
                            NSDictionary *newCopySetting = @{
                                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                                             NBCWorkflowCopySourceURL : localItemPath,
                                                             NBCWorkflowCopyTargetURL : packageItemPath,
                                                             NBCWorkflowCopyAttributes : newCopyAttributes
                                                             };
                            
                            [self updateBaseSystemCopyDict:newCopySetting];
                            
                        } else {
                            [newPathsArray addObject:packageItemPath];
                        }
                    }
                    
                    if ( [newPathsArray count] != 0 ) {
                        newResourcesPackageDict[NBCSettingsSourceItemsPathKey] = newPathsArray;
                    }
                    
                    if ( [newResourcesPackageDict count] != 0 )
                    {
                        newSourceItemsDict[packagePath] = newResourcesPackageDict;
                    }
                }
            }
            
            // ------------------------------------------------------------------------------------
            //  If all items existed in resource, this would be empty and nothing needs extracion.
            //  If any item was added to newSourceItemsDict, pass it along for extraction
            // ------------------------------------------------------------------------------------
            if ( [newSourceItemsDict count] != 0 ) {
                NSMutableDictionary *newResourcesSettings = [_resourcesSettings mutableCopy];
                newResourcesSettings[NBCSettingsSourceItemsKey] = newSourceItemsDict;
                [self setResourcesSettings:[newResourcesSettings copy]];
                NSLog(@"_resourcesSettings=%@", _resourcesSettings);
                [self extractItemsFromSource:workflowItem];
            } else {
                NSLog(@"_resourcesSettings=%@", _resourcesSettings);
                [self checkCompletedResources];
            }
        } else {
            [self extractItemsFromSource:workflowItem];
        }
    } else {
        NSLog(@"Could not get source build version from source!");
    }
} // getItemsFromSource


- (void)extractItemsFromSource:(NBCWorkflowItem *)workflowItem {
    NSLog(@"extractItemsFromSource");
    if ( ! _itemsToExtractFromSource ) {
        _itemsToExtractFromSource = [[NSMutableArray alloc] init];
        NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
        _itemsToExtractFromSource = [[sourceItemsDict allKeys] mutableCopy];
    }
    
    if ( [_itemsToExtractFromSource count] != 0 ) {
        NSLog(@"_itemsToExtractFromSource=%@", _itemsToExtractFromSource);
        NSString *packagePath = [_itemsToExtractFromSource firstObject];
        [_itemsToExtractFromSource removeObjectAtIndex:0];
        [self extractPackageToTemporaryFolder:workflowItem packagePath:packagePath];
    } else {
        [self checkCompletedResources];
    }
}

- (void)extractPackageToTemporaryFolder:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath {
    NSLog(@"extractPackageToTemporaryFolder");
    NSURL *packageTemporaryFolder = [self getPackageTemporaryFolderURL:workflowItem];
    NSURL *tempoararyFolder = [workflowItem temporaryFolderURL];
    if ( packageTemporaryFolder ) {
        NSArray *scriptArguments;
        int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
        if ( sourceVersionMinor <= 9 ) {
            scriptArguments = @[ @"-c",
                                 [NSString stringWithFormat:@"/usr/bin/xar -x -f \"%@\" Payload -C \"%@\"; /usr/bin/cd \"%@\"; /usr/bin/cpio -idmu --quiet -I \"%@/Payload\"", packagePath, [tempoararyFolder path], [packageTemporaryFolder path], [tempoararyFolder path]]
                                 ];
        } else {
            NSString *pbzxPath = [[NSBundle mainBundle] pathForResource:@"pbzx" ofType:@""];
            scriptArguments = @[ @"-c",
                                 [NSString stringWithFormat:@"%@ %@ | /usr/bin/cpio -idmu --quiet", pbzxPath, packagePath],
                                 ];
        }
        
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
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            }];
            
        }] runTaskWithCommandAtPath:commandURL arguments:scriptArguments currentDirectory:[packageTemporaryFolder path] stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                if ( terminationStatus == 0 )
                {
                    // ------------------------------------------------------------------
                    //  If task exited successfully, post workflow complete notification
                    // ------------------------------------------------------------------
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [self copySourceItemsToResources:packageTemporaryFolder packagePath:packagePath workflowItem:workflowItem];
                } else {
                    
                    // ------------------------------------------------------------------
                    //  If task failed, post workflow failed notification
                    // ------------------------------------------------------------------
                    NSLog(@"Extracting package failed!");
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                }
            }];
        }];
        
    } else {
        NSLog(@"Could not get Package Temporary Folder!");
    }
} // extractPackageToTemporaryFolder

- (NSURL *)getPackageTemporaryFolderURL:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    NSString *packageTemporaryFolderName = [NSString stringWithFormat:@"pkg.%@", [NSString nbc_randomString]];
    NSURL *packageTemporaryFolderURL = [temporaryFolderURL URLByAppendingPathComponent:packageTemporaryFolderName isDirectory:YES];
    
    if ( ! [packageTemporaryFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ( ! [fm createDirectoryAtURL:packageTemporaryFolderURL withIntermediateDirectories:NO attributes:nil error:&error] ){
            NSLog(@"Could not create temporary pkg folder!");
            NSLog(@"Error: %@", error);
            packageTemporaryFolderURL = nil;
        }
    }
    
    return packageTemporaryFolderURL;
} // getTemporaryFolderURL

- (void)copySourceItemsToResources:(NSURL *)packageTemporaryFolderURL packagePath:(NSString *)packagePath workflowItem:(NBCWorkflowItem *)workflowItem {
    NSLog(@"copySourceItemsToResources");
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    if ( packageTemporaryFolderURL != nil ) {
        NSDictionary *packageDict = sourceItemsDict[packagePath];
        NSLog(@"packageDict=%@", packageDict);
        NSArray *pathsToCopy = packageDict[NBCSettingsSourceItemsPathKey];
        NSLog(@"pathsToCopy=%@", pathsToCopy);
        if ( [pathsToCopy count] != 0 ) {
            for (NSString *itemPath in pathsToCopy) {
                NSURL *destinationURL;
                NSURL *itemSourceURL = [packageTemporaryFolderURL URLByAppendingPathComponent:itemPath];
                
                if ( itemSourceURL ) {
                    NSLog(@"itemSourceURL=%@", itemSourceURL);
                    destinationURL = [_resourcesController copySourceItemToResources:itemSourceURL
                                                                      sourceItemPath:itemPath
                                                                     resourcesFolder:NBCFolderResourcesSource
                                                                         sourceBuild:[[workflowItem source] sourceBuild]];
                } else {
                    NSLog(@"Could not get itemSourceURL for itemPath=%@", itemPath);
                    return;
                }
                
                NSDictionary *newCopyAttributes  = @{
                                                     NSFileOwnerAccountName : @"root",
                                                     NSFileGroupOwnerAccountName : @"wheel",
                                                     NSFilePosixPermissions : @0755
                                                     };
                
                NSDictionary *newCopySetting = @{
                                                 NBCWorkflowCopyType : NBCWorkflowCopy,
                                                 NBCWorkflowCopySourceURL : [destinationURL path],
                                                 NBCWorkflowCopyTargetURL : itemPath,
                                                 NBCWorkflowCopyAttributes : newCopyAttributes
                                                 };
                
                NSLog(@"newCopySetting=%@", newCopySetting);
                [self updateBaseSystemCopyDict:newCopySetting];
                [_itemsToExtractFromSource removeObject:packagePath];
            }
        }
        
        NSArray *regexArray = packageDict[NBCSettingsSourceItemsRegexKey];
        if ( [regexArray count] != 0 ) {
            [_resourcesController copySourceRegexToResources:workflowItem
                                                  regexArray:regexArray
                                                 packagePath:packagePath
                                                sourceFolder:[packageTemporaryFolderURL path]
                                             resourcesFolder:NBCFolderResourcesSource
                                                 sourceBuild:[[workflowItem source] sourceBuild]];
        }
        
    } else {
        NSLog(@"packageTemporaryFolderURL is nil");
    }
} // copySourceItemsToResources

#pragma mark -
#pragma mark Update Resource Dicts
#pragma mark -

- (void)checkCompletedResources {
    NSLog(@"checkCompletedResources");
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
    
    NSLog(@"_resourcesNetInstallCopy=%@", _resourcesNetInstallCopy);
    NSLog(@"_resourcesBaseSystemCopy=%@", _resourcesBaseSystemCopy);
    NSLog(@"_resourcesNetInstallInstall=%@", _resourcesNetInstallInstall);
    NSLog(@"_resourcesBaseSystemInstall=%@", _resourcesBaseSystemInstall);
    
    NSLog(@"resourcesDone: %lu", ( requiredCopyResources + requiredInstallResources ));
    
    if ( ( (int) requiredCopyResources + (int) requiredInstallResources ) == _resourcesCount ) {
        if ( [_resourcesNetInstallCopy count] != 0 ) {
            _resourcesNetInstallDict[NBCWorkflowCopy] = _resourcesNetInstallCopy;
        }
        
        if ( [_resourcesNetInstallInstall count] != 0 ) {
            _resourcesNetInstallDict[NBCWorkflowInstall] = _resourcesNetInstallInstall;
        }
        
        if ( [_resourcesBaseSystemCopy count] != 0 ) {
            _resourcesBaseSystemDict[NBCWorkflowCopy] = _resourcesBaseSystemCopy;
        }
        
        if ( [_resourcesBaseSystemInstall count] != 0 ) {
            _resourcesBaseSystemDict[NBCWorkflowInstall] = _resourcesBaseSystemInstall;
        }
        
        [_target setResourcesNetInstallDict:_resourcesNetInstallDict];
        [_target setResourcesBaseSystemDict:_resourcesBaseSystemDict];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
    }
} // checkCompletedResources

- (void)updateNetInstallCopyDict:(NSDictionary *)copyAttributes {
    [_resourcesNetInstallCopy addObject:copyAttributes];
} // updateNetInstallCopyDict:copyAttributes

- (void)updateBaseSystemCopyDict:(NSDictionary *)copyAttributes {
    [_resourcesBaseSystemCopy addObject:copyAttributes];
} // updateBaseSystemCopyDict:copyAttributes

- (void)updateBaseSystemInstallerDict:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML {
    // ----------------------------------------------------------------------------------------------
    //  Create a dict for package with URL and optionally choiceChangesXML and add to resource dict
    // ----------------------------------------------------------------------------------------------
    NSString *packageName;
    NSMutableDictionary *packageDict = [[NSMutableDictionary alloc] init];
    if ( packageURL ) {
        packageName = [packageURL lastPathComponent];
        packageDict[NBCWorkflowInstallerName] = packageName;
        packageDict[NBCWorkflowInstallerSourceURL] = [packageURL path];
    } else {
        NSLog(@"No packageURL passed!");
    }
    
    if ( choiceChangesXML ) {
        packageDict[NBCWorkflowInstallerChoiceChangeXML] = choiceChangesXML;
    }
    
    if ( packageName ) {
        [_resourcesBaseSystemInstall addObject:packageDict];
    }
    
    [self checkCompletedResources];
} // updateBaseSystemInstallerDict:choiceChangesXML

#pragma mark -
#pragma mark Create Imagr Resources
#pragma mark -

- (void)createImagrSettingsPlist:(NBCWorkflowItem *)workflowItem {
    NSString *configurationURL = _userSettings[NBCSettingsImagrConfigurationURL];
    
    NSString *imagrConfigurationPlistTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrConfigurationPlistTargetPath = NBCImagrConfigurationPlistNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrConfigurationPlistTargetPath = NBCImagrConfigurationPlistTargetURL;
    }
    
    if ( configurationURL ) {
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        if ( temporaryFolderURL ) {
            // ------------------------------------------------------------
            //  Create Imagr configuration plist and add to copy resources
            // ------------------------------------------------------------
            NSURL *settingsFileURL = [temporaryFolderURL URLByAppendingPathComponent:@"com.grahamgilbert.Imagr.plist"];
            NSDictionary *settingsDict = @{ @"serverurl" : configurationURL };
            if ( [settingsDict writeToURL:settingsFileURL atomically:YES] ) {
                NSDictionary *copyAttributes  = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0755
                                                  };
                
                NSDictionary *copySettings = @{
                                               NBCWorkflowCopyType : NBCWorkflowCopy,
                                               NBCWorkflowCopySourceURL : [settingsFileURL path],
                                               NBCWorkflowCopyTargetURL : imagrConfigurationPlistTargetPath,
                                               NBCWorkflowCopyAttributes : copyAttributes
                                               };
                
                if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                    [_resourcesBaseSystemCopy addObject:copySettings];
                } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                    [_resourcesNetInstallCopy addObject:copySettings];
                }
                
                [self checkCompletedResources];
            } else {
                NSLog(@"Could not write Imagr settings to url: %@", settingsFileURL);
            }
        } else {
            NSLog(@"Could not get temporaryFolderURL from workflow item!");
        }
    } else {
        NSLog(@"No configurationURL in user settings!");
    }
} // createImagrSettingsPlist

- (void)createImagrRCImaging:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    
    NSString *imagrRCImagingContent;
    NSString *imagrRCImagingTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrRCImagingTargetPath = NBCImagrRCImagingNBICreatorTargetURL;
        imagrRCImagingContent = [NBCWorkflowNBIController generateImagrRCImagingForNBICreator:[workflowItem userSettings]];
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrRCImagingTargetPath = NBCImagrRCImagingTargetURL;
        imagrRCImagingContent = NBCSettingsImagrRCImaging;
    }
    
    if ( temporaryFolderURL ) {
        // ---------------------------------------------------
        //  Create Imagr rc.imaging and add to copy resources
        // ---------------------------------------------------
        NSURL *rcImagingURL = [temporaryFolderURL URLByAppendingPathComponent:@"rc.imaging"];
        
        if ( [imagrRCImagingContent writeToURL:rcImagingURL atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
            NSDictionary *copyAttributes  = @{
                                              NSFileOwnerAccountName : @"root",
                                              NSFileGroupOwnerAccountName : @"wheel",
                                              NSFilePosixPermissions : @0755
                                              };
            
            NSDictionary *copySettings = @{
                                           NBCWorkflowCopyType : NBCWorkflowCopy,
                                           NBCWorkflowCopySourceURL : [rcImagingURL path],
                                           NBCWorkflowCopyTargetURL : imagrRCImagingTargetPath,
                                           NBCWorkflowCopyAttributes : copyAttributes
                                           };
            
            if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                [_resourcesBaseSystemCopy addObject:copySettings];
            } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                [_resourcesNetInstallCopy addObject:copySettings];
            }
            
            [self checkCompletedResources];
        } else {
            NSLog(@"Could not write rc.imaging to url: %@", rcImagingURL);
            NSLog(@"Error: %@", error);
        }
    } else {
        NSLog(@"Could not get temporaryFolderURL from workflow item!");
    }
} // createImagrRCImaging

@end
