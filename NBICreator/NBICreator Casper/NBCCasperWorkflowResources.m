//
//  NBCCasperWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCCasperWorkflowResources.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NBCLogging.h"

#import "NSString+randomString.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

#import "NBCWorkflowNBIController.h"

DDLogLevel ddLogLevel;

@implementation NBCCasperWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Starting workflow Casper Resources...");
    
    _resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
    _resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
    _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
    _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
    _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
    _resourcesController = [[NBCWorkflowResourcesController alloc] initWithDelegate:self];
    
    [self setTarget:[workflowItem target]];
    [self setUserSettings:[workflowItem userSettings]];
    [self setNbiCreationTool:_userSettings[NBCSettingsNBICreationToolKey]];
    [self setResourcesSettings:[workflowItem resourcesSettings]];
    
    // Casper Imaging.app, JSS Preferences
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
        NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
        if ( [certificatesArray count] != 0 ) {
            [self setResourcesCount:( _resourcesCount + ( (int)[certificatesArray count] + 1 ) )];
        }
        NSArray *packagessArray = _resourcesSettings[NBCSettingsPackagesKey];
        if ( [packagessArray count] != 0 ) {
            [self setResourcesCount:( _resourcesCount + (int)[packagessArray count] )];
        }
        if ( [_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] ) {
            [self setResourcesCount:( _resourcesCount + 1 )];
            if ( ! [_userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
                [self setResourcesCount:( _resourcesCount + 1 )];
            }
        }
    }
    
    if ( _userSettings ) {
        if ( ! [self preparePackages:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self prepareCertificates:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self prepareCasperImagingApplication:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self createJSSPreferencePlist:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self prepareDesktopViewer:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self createCasperRCImaging:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        [self getItemsFromSource:workflowItem];
    } else {
        DDLogError(@"[ERROR] Settings are empty!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

- (BOOL)prepareDesktopViewer:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Preparing desktop viewer...");
    BOOL retval = YES;
    NSDictionary *userSettings = [workflowItem userSettings];
    if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] ) {
        
        // NBCDesktopViewer.app
        NSURL *desktopViewerURL = [[NSBundle mainBundle] URLForResource:@"NBICreatorDesktopViewer" withExtension:@"app"];
        NSString *desktopViewerTargetPath = [NSString stringWithFormat:@"%@/NBICreatorDesktopViewer.app", NBCApplicationsTargetPath];
        NSDictionary *desktopViewerAttributes  = @{
                                                   NSFileOwnerAccountName : @"root",
                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                   NSFilePosixPermissions : @0755
                                                   };
        
        NSDictionary *desktopViewerCopySetting = @{
                                                   NBCWorkflowCopyType : NBCWorkflowCopy,
                                                   NBCWorkflowCopySourceURL : [desktopViewerURL path],
                                                   NBCWorkflowCopyTargetURL : desktopViewerTargetPath,
                                                   NBCWorkflowCopyAttributes : desktopViewerAttributes
                                                   };
        [self updateBaseSystemCopyDict:desktopViewerCopySetting];
        
        // Background Image
        if ( ! [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
            NSString *backgroundImageURL = userSettings[NBCSettingsBackgroundImageKey];
            if ( [backgroundImageURL length] != 0 ) {
                NSError *error;
                NSFileManager *fm = [NSFileManager defaultManager];
                NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
                NSURL *temporaryBackgroundImageURL = [temporaryFolderURL URLByAppendingPathComponent:[backgroundImageURL lastPathComponent]];
                if ( [fm copyItemAtURL:[NSURL fileURLWithPath:backgroundImageURL] toURL:temporaryBackgroundImageURL error:&error] ) {
                    NSString *backgroundTargetPath;
                    if ( [_target nbiNetInstallURL] ) {
                        backgroundTargetPath = @"Packages/Background.jpg";
                    } else if ( [_target baseSystemURL] ) {
                        backgroundTargetPath = @"Library/Application Support/NBICreator/Background.jpg";
                    }
                    DDLogDebug(@"backgroundTargetPath=%@", backgroundTargetPath);
                    NSDictionary *backgroundImageAttributes  = @{
                                                                 NSFileOwnerAccountName : @"root",
                                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                                 NSFilePosixPermissions : @0644
                                                                 };
                    
                    NSDictionary *backgroundImageCopySetting = @{
                                                                 NBCWorkflowCopyType : NBCWorkflowCopy,
                                                                 NBCWorkflowCopySourceURL : [temporaryBackgroundImageURL path],
                                                                 NBCWorkflowCopyTargetURL : backgroundTargetPath,
                                                                 NBCWorkflowCopyAttributes : backgroundImageAttributes
                                                                 };
                    if ( [_target nbiNetInstallURL] != nil ) {
                        [self updateNetInstallCopyDict:backgroundImageCopySetting];
                    } else if ( [_target baseSystemURL] ) {
                        [self updateBaseSystemCopyDict:backgroundImageCopySetting];
                    }
                } else {
                    DDLogError(@"Could not copy %@ to temporary folder at path %@", [backgroundImageURL lastPathComponent], [temporaryBackgroundImageURL path]);
                    DDLogError(@"%@", error);
                    retval = NO;
                }
            } else {
                DDLogError(@"[ERROR] backgroundImageURL was empty!");
                retval = NO;
            }
        }
    } else {
        DDLogInfo(@"Use background not selected!");
    }
    
    return retval;
}

- (BOOL)preparePackages:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogInfo(@"Preparing packages...");
    BOOL retval = YES;
    NSError *error;
    NSArray *packagesArray = _resourcesSettings[NBCSettingsPackagesKey];
    
    if ( [packagesArray count] != 0 ) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        NSURL *temporaryPackageFolderURL = [temporaryFolderURL URLByAppendingPathComponent:@"Packages"];
        if ( ! [temporaryPackageFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            if ( ! [fm createDirectoryAtURL:temporaryPackageFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                DDLogError(@"Creating temporary package folder failed!");
                DDLogError(@"%@", error);
                return NO;
            }
        }
        
        for ( NSString *packagePath in packagesArray ) {
            NSURL *temporaryPackageURL = [temporaryPackageFolderURL URLByAppendingPathComponent:[packagePath lastPathComponent]];
            if ( [fm copyItemAtURL:[NSURL fileURLWithPath:packagePath] toURL:temporaryPackageURL error:&error] ) {
                [self updateBaseSystemInstallerDict:temporaryPackageURL choiceChangesXML:nil];
            } else {
                DDLogError(@"Could not copy %@ to temporary folder at path %@", [packagePath lastPathComponent], [temporaryPackageURL path]);
                DDLogError(@"%@", error);
                retval = NO;
            }
        }
    } else {
        DDLogInfo(@"No packages found!");
    }
    return retval;
} // preparePackages

- (BOOL)prepareCasperImagingApplication:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    BOOL retval = YES;
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *casperImagingPath = userSettings[NBCSettingsCasperImagingPathKey];
    if ( [casperImagingPath length] != 0 ) {
        NSString *casperImagingTargetPath;
        if ( [_target nbiNetInstallURL] ) {
            casperImagingTargetPath = NBCCasperImagingApplicationTargetURL;
        } else if ( [_target baseSystemURL] ) {
            casperImagingTargetPath = NBCCasperImagingApplicationNBICreatorTargetURL;
        }
        NSDictionary *casperImagingAttributes  = @{
                                                       NSFileOwnerAccountName : @"root",
                                                       NSFileGroupOwnerAccountName : @"wheel",
                                                       NSFilePosixPermissions : @0755
                                                       };
        
        NSDictionary *casperImagingSetting = @{
                                                       NBCWorkflowCopyType : NBCWorkflowCopy,
                                                       NBCWorkflowCopySourceURL : casperImagingPath,
                                                       NBCWorkflowCopyTargetURL : casperImagingTargetPath,
                                                       NBCWorkflowCopyAttributes : casperImagingAttributes
                                                       };
        
        if ( [_target nbiNetInstallURL] ) {
            [self updateNetInstallCopyDict:casperImagingSetting];
        } else if ( [_target baseSystemURL] ) {
            [self updateBaseSystemCopyDict:casperImagingSetting];
        }
    }
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/usr/bin/xattr"];
    NSMutableArray *args = [NSMutableArray arrayWithArray:@[
                                                            @"-d", @"com.apple.quarantine",
                                                            casperImagingPath
                                                            ]];
    [newTask setArguments:args];
    [newTask setStandardOutput:[NSPipe pipe]];
    [newTask setStandardError:[NSPipe pipe]];
    
    // Launch Task
    [newTask launch];
    [newTask waitUntilExit];
    
    //newTaskOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
    //NSString *standardOutput = [[NSString alloc] initWithData:newTaskOutputData encoding:NSUTF8StringEncoding];
    
    NSData *newTaskErrorData = [[newTask.standardError fileHandleForReading] readDataToEndOfFile];
    NSString *standardError = [[NSString alloc] initWithData:newTaskErrorData encoding:NSUTF8StringEncoding];
    
    if ( [newTask terminationStatus] == 0 || [standardError containsString:@"No such xattr: com.apple.quarantine"] ) {
        retval = YES;
    } else {
        DDLogError(@"[ERROR] Removing Quarantine Failed!");
        DDLogError(@"[ERROR] %@", standardError);
        retval = NO;
    }

    return retval;
}

- (BOOL)prepareCertificates:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    BOOL retval = YES;
    NSError *error;
    NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
    if ( [certificatesArray count] != 0 ) {
        NSURL *certificateScriptURL = [[NSBundle mainBundle] URLForResource:@"installCertificates" withExtension:@"bash"];
        NSString *certificateScriptTargetPath;
        if ( [_target nbiNetInstallURL] ) {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsTargetPath, [certificateScriptURL lastPathComponent]];
        } else if ( [_target baseSystemURL] ) {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsNBICreatorTargetPath, [certificateScriptURL lastPathComponent]];
        }
        NSDictionary *certificateScriptAttributes  = @{
                                                       NSFileOwnerAccountName : @"root",
                                                       NSFileGroupOwnerAccountName : @"wheel",
                                                       NSFilePosixPermissions : @0755
                                                       };
        
        NSDictionary *certificateScriptCopySetting = @{
                                                       NBCWorkflowCopyType : NBCWorkflowCopy,
                                                       NBCWorkflowCopySourceURL : [certificateScriptURL path],
                                                       NBCWorkflowCopyTargetURL : certificateScriptTargetPath,
                                                       NBCWorkflowCopyAttributes : certificateScriptAttributes
                                                       };
        if ( [_target nbiNetInstallURL] ) {
            [self updateNetInstallCopyDict:certificateScriptCopySetting];
        } else if ( [_target baseSystemURL] ) {
            [self updateBaseSystemCopyDict:certificateScriptCopySetting];
        }
        
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        NSURL *temporaryCertificateFolderURL = [temporaryFolderURL URLByAppendingPathComponent:@"Certificates"];
        if ( ! [temporaryCertificateFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            NSFileManager *fm = [NSFileManager defaultManager];
            if ( ! [fm createDirectoryAtURL:temporaryCertificateFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                DDLogError(@"Creating temporary certificate folder failed!");
                DDLogError(@"%@", error);
                return NO;
            }
        }
        
        NSInteger index = 0;
        for ( NSData *certificateData in certificatesArray ) {
            NSString *temporaryCertificateName = [NSString stringWithFormat:@"certificate%ld.cer", (long)index];
            NSURL *temporaryCertificateURL = [temporaryCertificateFolderURL URLByAppendingPathComponent:temporaryCertificateName];
            if ( [certificateData writeToURL:temporaryCertificateURL atomically:YES] ) {
                NSString *certificateTargetPath;
                if ( [_target nbiNetInstallURL] != nil ) {
                    certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesTargetURL, temporaryCertificateName];
                } else if ( [_target baseSystemURL] ) {
                    certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesNBICreatorTargetURL, temporaryCertificateName];
                }
                NSDictionary *certificateAttributes  = @{
                                                         NSFileOwnerAccountName : @"root",
                                                         NSFileGroupOwnerAccountName : @"wheel",
                                                         NSFilePosixPermissions : @0644
                                                         };
                
                NSDictionary *certificateCopySetting = @{
                                                         NBCWorkflowCopyType : NBCWorkflowCopy,
                                                         NBCWorkflowCopySourceURL : [temporaryCertificateURL path],
                                                         NBCWorkflowCopyTargetURL : certificateTargetPath,
                                                         NBCWorkflowCopyAttributes : certificateAttributes
                                                         };
                if ( [_target nbiNetInstallURL] != nil ) {
                    [self updateNetInstallCopyDict:certificateCopySetting];
                } else if ( [_target baseSystemURL] ) {
                    [self updateBaseSystemCopyDict:certificateCopySetting];
                }
            } else {
                DDLogError(@"Unable to write certificate to temporary folder!");
                retval = NO;
            }
            index++;
        }
    }
    return retval;
} // prepareCertificates

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -
////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCSettingsController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)copySourceRegexComplete:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath resourceFolderPackageURL:(NSURL *)resourceFolderPackage {
    NSDictionary *sourceItemsResourcesDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packagePath];
    NSArray *regexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
    for ( NSString *regex in regexes ) {
        NSDictionary *newRegexCopySetting = @{
                                              NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                              NBCWorkflowCopyRegexSourceFolderURL : [resourceFolderPackage path],
                                              NBCWorkflowCopyRegex : regex
                                              };
        [self updateBaseSystemCopyDict:newRegexCopySetting];
    }
    
    [self extractItemsFromSource:workflowItem];
} // copySourceRegexComple:packagePath:resourceFolderPackageURL

- (void)copySourceRegexFailed:(NBCWorkflowItem *)workflowItem temporaryFolderURL:(NSURL *)temporaryFolderURL {
#pragma unused(workflowItem, temporaryFolderURL)
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
} // copySourceRegexFailed:temporaryFolderURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get External Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)downloadResource:(NSURL *)resourceDownloadURL resourceTag:(NSString *)resourceTag version:(NSString *)version {
    NSDictionary *downloadInfo = @{
                                   NBCDownloaderTag : resourceTag,
                                   NBCDownloaderVersion : version
                                   };
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadFileFromURL:resourceDownloadURL destinationPath:@"/tmp" downloadInfo:downloadInfo];
} // downloadResource:resourceTag:version

/*
- (BOOL)getCasperApplication:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    BOOL retval = YES;
    NSString *selectedCasperVersion = _userSettings[NBCSettingsCasperVersion];
    NSString *CasperApplicationTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        CasperApplicationTargetPath = NBCCasperApplicationNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        CasperApplicationTargetPath = NBCCasperApplicationTargetURL;
    } else {
        CasperApplicationTargetPath = [[_target CasperApplicationURL] path];
        if ( [CasperApplicationTargetPath length] == 0 ) {
            DDLogError(@"Could not get path to Casper.app from target!");
            return NO;
        }
    }
    if ( [selectedCasperVersion length] == 0 ) {
        DDLogError(@"Could not get selected Casper version from user settings!");
        return NO;
    } else if ( [selectedCasperVersion isEqualToString:NBCMenuItemCasperVersionLocal] ) {
        NSString *CasperLocalVersionPath = _userSettings[NBCSettingsCasperLocalVersionPath];
        if ( [CasperLocalVersionPath length] != 0 ) {
            NSDictionary *CasperLocalVersionAttributes  = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0755
                                                           };
            
            NSDictionary *CasperLocalVersionCopySetting = @{
                                                           NBCWorkflowCopyType : NBCWorkflowCopy,
                                                           NBCWorkflowCopySourceURL : CasperLocalVersionPath,
                                                           NBCWorkflowCopyTargetURL : CasperApplicationTargetPath,
                                                           NBCWorkflowCopyAttributes : CasperLocalVersionAttributes
                                                           };
            if ( [_target nbiNetInstallURL] ) {
                [_resourcesNetInstallCopy addObject:CasperLocalVersionCopySetting];
            } else if ( [_target baseSystemURL] ) {
                [_resourcesBaseSystemCopy addObject:CasperLocalVersionCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            DDLogError(@"[ERROR] Could not get CasperLocalVersionPath from user settings!");
            return NO;
        }
    } else {
        
        // ---------------------------------------------------------------
        //  Check if Casper is already downloaded, then return local url.
        //  If not, download Casper and copy to resources for future use.
        // ---------------------------------------------------------------
        if ( [selectedCasperVersion isEqualToString:NBCMenuItemCasperVersionLatest] ) {
            if ( [_resourcesSettings[NBCSettingsCasperVersion] length] == 0 ) {
                DDLogError(@"[ERROR] Casper versions array is empty!");
                return NO;
            }
            selectedCasperVersion = _resourcesSettings[NBCSettingsCasperVersion];
            DDLogDebug(@"selectedCasperVersion=%@", selectedCasperVersion);
        }
        
        [self setCasperVersion:selectedCasperVersion];
        NSURL *CasperCachedVersionURL = [_resourcesController cachedVersionURL:selectedCasperVersion resourcesFolder:NBCFolderResourcesCasper];
        if ( [CasperCachedVersionURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *CasperCachedVersionAttributes  = @{
                                                            NSFileOwnerAccountName : @"root",
                                                            NSFileGroupOwnerAccountName : @"wheel",
                                                            NSFilePosixPermissions : @0755
                                                            };
            
            NSDictionary *CasperCachedVersionCopySetting = @{
                                                            NBCWorkflowCopyType : NBCWorkflowCopy,
                                                            NBCWorkflowCopySourceURL : [CasperCachedVersionURL path],
                                                            NBCWorkflowCopyTargetURL : CasperApplicationTargetPath,
                                                            NBCWorkflowCopyAttributes : CasperCachedVersionAttributes
                                                            };
            if ( [_target nbiNetInstallURL] ) {
                [_resourcesNetInstallCopy addObject:CasperCachedVersionCopySetting];
            } else if ( [_target baseSystemURL] ) {
                [_resourcesBaseSystemCopy addObject:CasperCachedVersionCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            NSString *CasperDownloadURL = _resourcesSettings[NBCSettingsCasperDownloadURL];
            if ( [CasperDownloadURL length] != 0 ) {
                DDLogInfo(@"Downloading Casper version %@", selectedCasperVersion);
                [_delegate updateProgressStatus:@"Downloading Casper..." workflow:self];
                [self downloadResource:[NSURL URLWithString:CasperDownloadURL] resourceTag:NBCDownloaderTagCasper version:selectedCasperVersion];
            } else {
                DDLogError(@"[ERROR] Could not get Casper download url from resources settings!");
                retval = NO;
            }
        }
    }
    return retval;
} // getCasperApplication
*/

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Collect Resources From OS X Installer Package
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)getItemsFromSource:(NBCWorkflowItem *)workflowItem {
    NSString *sourceBuildVersion = [[workflowItem source] sourceBuild];
    if ( [sourceBuildVersion length] != 0 ) {
        
        // ---------------------------------------------------------------
        //  Check if source items are already downloaded, then return local urls.
        //  If not, extract and copy to resources for future use.
        // ---------------------------------------------------------------
        NSDictionary *sourceItemsResourcesDict = [_resourcesController getCachedSourceItemsDict:sourceBuildVersion resourcesFolder:NBCFolderResourcesSource];
        if ( [sourceItemsResourcesDict count] != 0 ) {
            NSMutableDictionary *newSourceItemsDict = [[NSMutableDictionary alloc] init];
            NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
            
            // -------------------------------------------------------
            //  Loop through all packages that contain required items
            // -------------------------------------------------------
            NSArray *sourcePackages = [sourceItemsDict allKeys];
            for ( NSString *packagePath in sourcePackages ) {
                NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
                NSDictionary *packageDict = sourceItemsDict[packagePath];
                if ( [packageDict count] != 0 ) {
                    NSMutableDictionary *newResourcesPackageDict = [[NSMutableDictionary alloc] init];
                    NSMutableArray *newRegexesArray = [[NSMutableArray alloc] init];
                    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packageName];
                    NSArray *regexes = packageDict[NBCSettingsSourceItemsRegexKey];
                    NSArray *resourcesRegexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
                    for ( NSString *regex in regexes ) {
                        if ( [resourcesRegexes containsObject:regex] ) {
                            NSString *sourceFolderPath = resourcesPackageDict[NBCSettingsSourceItemsCacheFolderKey];
                            if ( [sourceFolderPath length] != 0 ) {
                                NSDictionary *newRegexCopySetting = @{
                                                                      NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                                                      NBCWorkflowCopyRegexSourceFolderURL : sourceFolderPath,
                                                                      NBCWorkflowCopyRegex : regex
                                                                      };
                                [self updateBaseSystemCopyDict:newRegexCopySetting];
                            } else {
                                DDLogError(@"Could not get sourceFolderPath from packageDict");
                            }
                        } else {
                            [newRegexesArray addObject:regex];
                        }
                    }
                    
                    if ( [newRegexesArray count] != 0 ) {
                        newResourcesPackageDict[NBCSettingsSourceItemsRegexKey] = newRegexesArray;
                    }
                    
                    NSMutableArray *newPathsArray = [[NSMutableArray alloc] init];
                    NSArray *paths = packageDict[NBCSettingsSourceItemsPathKey];
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
                    
                    if ( [newResourcesPackageDict count] != 0 ) {
                        newSourceItemsDict[packagePath] = newResourcesPackageDict;
                    }
                } else {
                    DDLogError(@"[ERROR] Package dict was empty!");
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
                [self extractItemsFromSource:workflowItem];
            } else {
                [self checkCompletedResources];
            }
        } else {
            [self extractItemsFromSource:workflowItem];
        }
    } else {
        DDLogError(@"[ERROR] Could not get source build version from source!");
    }
} // getItemsFromSource

- (void)extractItemsFromSource:(NBCWorkflowItem *)workflowItem {
    if ( ! _itemsToExtractFromSource ) {
        _itemsToExtractFromSource = [[NSMutableArray alloc] init];
        NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
        [self setItemsToExtractFromSource:[[sourceItemsDict allKeys] mutableCopy]];
    }
    
    if ( [_itemsToExtractFromSource count] != 0 ) {
        NSString *packagePath = [_itemsToExtractFromSource firstObject];
        [_itemsToExtractFromSource removeObjectAtIndex:0];
        [self extractPackageToTemporaryFolder:workflowItem packagePath:packagePath];
    } else {
        [self checkCompletedResources];
    }
} // extractItemsFromSource

- (void)extractPackageToTemporaryFolder:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath {
    DDLogInfo(@"Extracting resources from %@...", [packagePath lastPathComponent]);
    [_delegate updateProgressStatus:[NSString stringWithFormat:@"Extracting resources from %@...", [packagePath lastPathComponent]] workflow:self];
    NSURL *packageTemporaryFolder = [self getPackageTemporaryFolderURL:workflowItem];
    if ( packageTemporaryFolder ) {
        NSURL *temporaryFolder = [workflowItem temporaryFolderURL];
        if ( temporaryFolder ) {
            NSArray *scriptArguments;
            int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
            if ( sourceVersionMinor <= 9 ) {
                scriptArguments = @[ @"-c",
                                     [NSString stringWithFormat:@"/usr/bin/xar -x -f \"%@\" Payload -C \"%@\"; /usr/bin/cd \"%@\"; /usr/bin/cpio -idmu -I \"%@/Payload\"", packagePath, [temporaryFolder path], [packageTemporaryFolder path], [temporaryFolder path]]
                                     ];
            } else {
                NSString *pbzxPath = [[NSBundle mainBundle] pathForResource:@"pbzx" ofType:@""];
                scriptArguments = @[ @"-c",
                                     [NSString stringWithFormat:@"%@ %@ | /usr/bin/cpio -idmu --quiet", pbzxPath, packagePath],
                                     ];
            }
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
                                                DDLogDebug(@"%@", outStr);
                                                
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
                                                DDLogError(@"[ERROR] %@", errStr);
                                                
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
                
            }] runTaskWithCommandAtPath:commandURL arguments:scriptArguments currentDirectory:[packageTemporaryFolder path] stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
                [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                    if ( terminationStatus == 0 ) {
                        
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
                        DDLogError(@"[ERROR] Extraction failed!");
                        NSDictionary *userInfo = nil;
                        if ( error ) {
                            DDLogError(@"[ERROR] %@", error);
                            userInfo = @{ NBCUserInfoNSErrorKey : error };
                        }
                        [nc removeObserver:stdOutObserver];
                        [nc removeObserver:stdErrObserver];
                        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                    }
                }];
            }];
        } else {
            DDLogError(@"[ERROR] Could not get Temporary Folder!");
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        DDLogError(@"[ERROR] Could not get Package Temporary Folder!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
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
            DDLogError(@"[ERROR] Could not create temporary pkg folder!");
            DDLogError(@"%@", error);
            packageTemporaryFolderURL = nil;
        }
    }
    
    return packageTemporaryFolderURL;
} // getTemporaryFolderURL

- (void)copySourceItemsToResources:(NSURL *)packageTemporaryFolderURL packagePath:(NSString *)packagePath workflowItem:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Copying extracted resources to cache folder...");
    [_delegate updateProgressStatus:@"Copying extracted resources to cache folder..." workflow:self];
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    if ( packageTemporaryFolderURL != nil ) {
        NSDictionary *packageDict = sourceItemsDict[packagePath];
        NSArray *pathsToCopy = packageDict[NBCSettingsSourceItemsPathKey];
        if ( [pathsToCopy count] != 0 ) {
            for ( NSString *itemPath in pathsToCopy ) {
                NSURL *destinationURL;
                NSURL *itemSourceURL = [packageTemporaryFolderURL URLByAppendingPathComponent:itemPath];
                if ( itemSourceURL ) {
                    destinationURL = [_resourcesController copySourceItemToResources:itemSourceURL
                                                                      sourceItemPath:itemPath
                                                                     resourcesFolder:NBCFolderResourcesSource
                                                                         sourceBuild:[[workflowItem source] sourceBuild]];
                } else {
                    DDLogError(@"[ERROR] Could not get itemSourceURL for itemPath=%@", itemPath);
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
        DDLogError(@"[ERROR] packageTemporaryFolderURL is nil");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // copySourceItemsToResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Update Resource Dicts
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)checkCompletedResources {
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
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
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
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
        DDLogError(@"[ERROR] No packageURL passed!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        return;
    }
    
    if ( choiceChangesXML ) {
        packageDict[NBCWorkflowInstallerChoiceChangeXML] = choiceChangesXML;
    }
    
    if ( packageName ) {
        [_resourcesBaseSystemInstall addObject:packageDict];
    }
    
    [self checkCompletedResources];
} // updateBaseSystemInstallerDict:choiceChangesXML

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Create Casper Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)createJSSPreferencePlist:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSString *jssURLString = _userSettings[NBCSettingsCasperJSSURLKey];
    NSString *jssPreferencePlistTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        jssPreferencePlistTargetPath = NBCJSSPreferencePlistNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        jssPreferencePlistTargetPath = NBCJSSPreferencePlistTargetURL;
    } else {
        jssPreferencePlistTargetPath = [[_target casperJSSPreferencePlistURL] path];
        if ( [jssPreferencePlistTargetPath length] == 0 ) {
            DDLogError(@"Could not get path to Casper.app from target!");
            return NO;
        }
    }
    
    if ( jssURLString ) {
        NSURL *jssURL = [NSURL URLWithString:jssURLString];
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        if ( temporaryFolderURL ) {
            
            // ------------------------------------------------------------
            //  Create Casper configuration plist and add to copy resources
            // ------------------------------------------------------------
            NSURL *jssPreferencePlistTargetURL = [temporaryFolderURL URLByAppendingPathComponent:@"com.jamfsoftware.jss.plist"];
            
            NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] initWithDictionary:@{ @"url" : [jssURL absoluteString] }];
            
            NSString *jssHost = [jssURL host];
            if ( [jssHost length] != 0 ) {
                settingsDict[@"address"] = jssHost;
            }
            
            NSString *jssURLScheme = [jssURL scheme];
            if ( [jssURLScheme length] != 0 ) {
                settingsDict[@"secure"] = [[jssURL scheme] isEqualToString:@"https"] ? @YES : @NO;
            }
            
            NSString *jssPort = [[jssURL port] stringValue];
            if ( [jssPort length] != 0 ) {
                settingsDict[@"port"] = jssPort;
            } else {
                settingsDict[@"port"] = [[jssURL scheme] isEqualToString:@"https"] ? @"443" : @"80";
            }
            
            NSString *jssPath = [jssURL path];
            if ( [jssPath length] != 0 ) {
                settingsDict[@"path"] = jssPath;
            }
            
            settingsDict[@"allowInvalidCertificate"] = [_userSettings[NBCSettingsCasperAllowInvalidCertificateKey] boolValue] ? @YES : @NO;

            if ( [settingsDict writeToURL:jssPreferencePlistTargetURL atomically:YES] ) {
                NSDictionary *copyAttributes  = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0644
                                                  };
                
                NSDictionary *copySettings = @{
                                               NBCWorkflowCopyType : NBCWorkflowCopy,
                                               NBCWorkflowCopySourceURL : [jssPreferencePlistTargetURL path],
                                               NBCWorkflowCopyTargetURL : jssPreferencePlistTargetPath,
                                               NBCWorkflowCopyAttributes : copyAttributes
                                               };
                if ( [_target nbiNetInstallURL] != nil ) {
                    [_resourcesNetInstallCopy addObject:copySettings];
                } else if ( [_target baseSystemURL] ) {
                    [_resourcesBaseSystemCopy addObject:copySettings];
                }
                
                [self checkCompletedResources];
            } else {
                DDLogError(@"[ERROR] Could not write Casper settings to url: %@", jssPreferencePlistTargetURL);
                retval = NO;
            }
        } else {
            DDLogError(@"[ERROR] Could not get temporaryFolderURL from workflow item!");
            retval = NO;
        }
    } else {
        DDLogError(@"[ERROR] No configurationURL in user settings!");
        retval = NO;
    }
    return retval;
} // createCasperSettingsPlist

- (BOOL)createCasperRCImaging:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    NSString *CasperRCImagingTargetPath;
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    NSString *CasperRCImagingContent = [NBCWorkflowNBIController generateCasperRCImagingForNBICreator:[workflowItem userSettings] osMinorVersion:sourceVersionMinor];
    if ( [CasperRCImagingContent length] != 0 ) {
        if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
            CasperRCImagingTargetPath = NBCRCImagingNBICreatorTargetURL;
        } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            CasperRCImagingTargetPath = NBCRCImagingTargetURL;
        } else {
            if ( [_target rcImagingURL] != nil ) {
                CasperRCImagingTargetPath = [[_target rcImagingURL] path];
            } else {
                DDLogError(@"Found no rc.imaging URL from target settings!");
                return NO;
            }
            
            if ( [[_target rcImagingContent] length] != 0 ) {
                CasperRCImagingContent = [_target rcImagingContent];
            } else {
                DDLogError(@"Found no rc.imaging content form target settings!");
                return NO;
            }
        }
        
        if ( temporaryFolderURL ) {
            // ---------------------------------------------------
            //  Create Casper rc.imaging and add to copy resources
            // ---------------------------------------------------
            NSURL *rcImagingURL = [temporaryFolderURL URLByAppendingPathComponent:@"rc.imaging"];
            if ( [CasperRCImagingContent writeToURL:rcImagingURL atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
                NSDictionary *copyAttributes  = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0755
                                                  };
                
                NSDictionary *copySettings = @{
                                               NBCWorkflowCopyType : NBCWorkflowCopy,
                                               NBCWorkflowCopySourceURL : [rcImagingURL path],
                                               NBCWorkflowCopyTargetURL : CasperRCImagingTargetPath,
                                               NBCWorkflowCopyAttributes : copyAttributes
                                               };
                if ( [_target nbiNetInstallURL] != nil ) {
                    [_resourcesNetInstallCopy addObject:copySettings];
                } else if ( [_target baseSystemURL] ) {
                    [_resourcesBaseSystemCopy addObject:copySettings];
                }
                
                [self checkCompletedResources];
            } else {
                DDLogError(@"[ERROR] Could not write rc.imaging to url: %@", rcImagingURL);
                DDLogError(@"%@", error);
                retval = NO;
            }
        } else {
            DDLogError(@"[ERROR] Could not get temporaryFolderURL from workflow item!");
            retval = NO;
        }
    } else {
        DDLogError(@"[ERROR] rcImagingContent is empty!");
        retval = NO;
    }
    return retval;
} // createCasperRCImaging

@end
