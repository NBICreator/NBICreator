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
#import "NBCVariables.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowNBIController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Starting workflow Imagr Resources...");
    
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
    
    // Imagr.app, Imagr settings, ?
    [self setResourcesCount:3];
    DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
    
    // -------------------------------------------------------
    //  Update _resourcesCount with all sourceItems
    // -------------------------------------------------------
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    DDLogDebug(@"sourceItemsDict=%@", sourceItemsDict);
    if ( [sourceItemsDict count] != 0 ) {
        NSArray *sourcePackages = [sourceItemsDict allKeys];
        DDLogDebug(@"sourcePackages=%@", sourcePackages);
        for ( NSString *packagePath in sourcePackages ) {
            DDLogDebug(@"packagePath=%@", packagePath);
            NSDictionary *packageDict = sourceItemsDict[packagePath];
            DDLogDebug(@"packageDict=%@", packageDict);
            NSDictionary *packageDictPath = packageDict[NBCSettingsSourceItemsPathKey];
            DDLogDebug(@"packageDictPath=%@", packageDictPath);
            int packageCount = (int)[packageDictPath count];
            [self setResourcesCount:( _resourcesCount + packageCount )];
            NSArray *packageRegexArray = packageDict[NBCSettingsSourceItemsRegexKey];
            DDLogDebug(@"packageRegexArray=%@", packageRegexArray);
            if ( [packageDict count] != 0 ) {
                [self setResourcesCount:( _resourcesCount + (int)[packageRegexArray count] )];
                DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
            }
        }
        NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
        DDLogDebug(@"certificatesArray=%@", certificatesArray);
        if ( [certificatesArray count] != 0 ) {
            [self setResourcesCount:( _resourcesCount + ( (int)[certificatesArray count] + 1 ) )];
            DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
        }
        NSArray *packagessArray = _resourcesSettings[NBCSettingsPackagesKey];
        DDLogDebug(@"packagessArray=%@", packagessArray);
        if ( [packagessArray count] != 0 ) {
            [self setResourcesCount:( _resourcesCount + (int)[packagessArray count] )];
            DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
        }
        if ( [_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] ) {
            [self setResourcesCount:( _resourcesCount + 1 )];
            DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
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
        
        if ( ! [self getImagrApplication:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self createImagrSettingsPlist:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self prepareDesktopViewer:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        if ( ! [self createImagrRCImaging:workflowItem] ) {
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Preparing desktop viewer...");
    BOOL retval = YES;
    NSDictionary *userSettings = [workflowItem userSettings];
    if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] ) {
        
        // NBCDesktopViewer.app
        NSURL *desktopViewerURL = [[NSBundle mainBundle] URLForResource:@"NBICreatorDesktopViewer" withExtension:@"app"];
        DDLogDebug(@"desktopViewerURL=%@", desktopViewerURL);
        NSString *desktopViewerTargetPath = [NSString stringWithFormat:@"%@/NBICreatorDesktopViewer.app", NBCApplicationsTargetPath];
        DDLogDebug(@"desktopViewerTargetPath=%@", desktopViewerTargetPath);
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
        DDLogDebug(@"desktopViewerCopySetting=%@", desktopViewerCopySetting);
        [self updateBaseSystemCopyDict:desktopViewerCopySetting];
        
        // Background Image
        if ( ! [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
            NSString *backgroundImageURL = userSettings[NBCSettingsBackgroundImageKey];
            if ( [backgroundImageURL length] != 0 ) {
                NSError *error;
                NSFileManager *fm = [NSFileManager defaultManager];
                NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
                DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
                NSURL *temporaryBackgroundImageURL = [temporaryFolderURL URLByAppendingPathComponent:[backgroundImageURL lastPathComponent]];
                DDLogDebug(@"temporaryBackgroundImageURL=%@", temporaryBackgroundImageURL);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Preparing packages...");
    BOOL retval = YES;
    NSError *error;
    NSArray *packagesArray = _resourcesSettings[NBCSettingsPackagesKey];
    DDLogDebug(@"packagesArray=%@", packagesArray);
    
    if ( [packagesArray count] != 0 ) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
        NSURL *temporaryPackageFolderURL = [temporaryFolderURL URLByAppendingPathComponent:@"Packages"];
        DDLogDebug(@"temporaryPackageFolderURL=%@", temporaryPackageFolderURL);
        if ( ! [temporaryPackageFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            if ( ! [fm createDirectoryAtURL:temporaryPackageFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
                DDLogError(@"Creating temporary package folder failed!");
                DDLogError(@"%@", error);
                return NO;
            }
        }
        
        for ( NSString *packagePath in packagesArray ) {
            NSURL *temporaryPackageURL = [temporaryPackageFolderURL URLByAppendingPathComponent:[packagePath lastPathComponent]];
            DDLogDebug(@"temporaryPackageURL=%@", temporaryPackageURL);
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

- (BOOL)prepareCertificates:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSError *error;
    NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
    DDLogDebug(@"certificatesArray=%@", certificatesArray);
    if ( [certificatesArray count] != 0 ) {
        NSURL *certificateScriptURL = [[NSBundle mainBundle] URLForResource:@"installCertificates" withExtension:@"bash"];
        DDLogDebug(@"certificateScriptURL=%@", certificateScriptURL);
        NSString *certificateScriptTargetPath;
        if ( [_target nbiNetInstallURL] ) {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsTargetPath, [certificateScriptURL lastPathComponent]];
        } else if ( [_target baseSystemURL] ) {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsNBICreatorTargetPath, [certificateScriptURL lastPathComponent]];
        }
        DDLogDebug(@"certificateScriptTargetPath=%@", certificateScriptTargetPath);
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
        DDLogDebug(@"certificateScriptCopySetting=%@", certificateScriptCopySetting);
        if ( [_target nbiNetInstallURL] ) {
            [self updateNetInstallCopyDict:certificateScriptCopySetting];
        } else if ( [_target baseSystemURL] ) {
            [self updateBaseSystemCopyDict:certificateScriptCopySetting];
        }
        
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
        NSURL *temporaryCertificateFolderURL = [temporaryFolderURL URLByAppendingPathComponent:@"Certificates"];
        DDLogDebug(@"temporaryCertificateFolderURL=%@", temporaryCertificateFolderURL);
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
            DDLogDebug(@"index=%ld", (long)index);
            NSString *temporaryCertificateName = [NSString stringWithFormat:@"certificate%ld.cer", (long)index];
            DDLogDebug(@"temporaryCertificateName=%@", temporaryCertificateName);
            NSURL *temporaryCertificateURL = [temporaryCertificateFolderURL URLByAppendingPathComponent:temporaryCertificateName];
            DDLogDebug(@"temporaryCertificateURL=%@", temporaryCertificateURL);
            if ( [certificateData writeToURL:temporaryCertificateURL atomically:YES] ) {
                NSString *certificateTargetPath;
                if ( [_target nbiNetInstallURL] != nil ) {
                    certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesTargetURL, temporaryCertificateName];
                } else if ( [_target baseSystemURL] ) {
                    certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesNBICreatorTargetURL, temporaryCertificateName];
                }
                DDLogDebug(@"certificateTargetPath=%@", certificateTargetPath);
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
                DDLogDebug(@"certificateCopySetting=%@", certificateCopySetting);
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

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // ------------------------------------------------------
    //  Extract info from downloadInfo Dict
    // ------------------------------------------------------
    NSString *resourceTag = downloadInfo[NBCDownloaderTag];
    DDLogDebug(@"resourceTag=%@", resourceTag);
    NSString *version = downloadInfo[NBCDownloaderVersion];
    DDLogDebug(@"version=%@", version);
    // ------------------------------------------------------
    //  Send command to correct copy method based on tag
    // ------------------------------------------------------
    if ( [resourceTag isEqualToString:NBCDownloaderTagImagr] ) {
        [self addImagrToResources:url version:version];
    }
} // fileDownloadCompleted:downloadInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCSettingsController
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)copySourceRegexComplete:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath resourceFolderPackageURL:(NSURL *)resourceFolderPackage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *sourceItemsResourcesDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    DDLogDebug(@"sourceItemsResourcesDict=%@", sourceItemsResourcesDict);
    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packagePath];
    DDLogDebug(@"resourcesPackageDict=%@", resourcesPackageDict);
    NSArray *regexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
    DDLogDebug(@"regexes=%@", regexes);
    for ( NSString *regex in regexes ) {
        DDLogDebug(@"regex=%@", regex);
        NSDictionary *newRegexCopySetting = @{
                                              NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                              NBCWorkflowCopyRegexSourceFolderURL : [resourceFolderPackage path],
                                              NBCWorkflowCopyRegex : regex
                                              };
        DDLogDebug(@"newRegexCopySetting=%@", newRegexCopySetting);
        [self updateBaseSystemCopyDict:newRegexCopySetting];
    }
    
    [self extractItemsFromSource:workflowItem];
} // copySourceRegexComple:packagePath:resourceFolderPackageURL

- (void)copySourceRegexFailed:(NBCWorkflowItem *)workflowItem temporaryFolderURL:(NSURL *)temporaryFolderURL {
#pragma unused(workflowItem, temporaryFolderURL)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
} // copySourceRegexFailed:temporaryFolderURL

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Get External Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)downloadResource:(NSURL *)resourceDownloadURL resourceTag:(NSString *)resourceTag version:(NSString *)version {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSDictionary *downloadInfo = @{
                                   NBCDownloaderTag : resourceTag,
                                   NBCDownloaderVersion : version
                                   };
    DDLogDebug(@"downloadInfo=%@", downloadInfo);
    NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
    [downloader downloadFileFromURL:resourceDownloadURL destinationPath:@"/tmp" downloadInfo:downloadInfo];
} // downloadResource:resourceTag:version

- (BOOL)getImagrApplication:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"");
    
    BOOL retval = YES;
    NSString *selectedImagrVersion = _userSettings[NBCSettingsImagrVersion];
    DDLogDebug(@"selectedImagrVersion=%@", selectedImagrVersion);
    NSString *imagrApplicationTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrApplicationTargetPath = NBCImagrApplicationNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrApplicationTargetPath = NBCImagrApplicationTargetURL;
    } else {
        imagrApplicationTargetPath = [[_target imagrApplicationURL] path];
        if ( [imagrApplicationTargetPath length] == 0 ) {
            DDLogError(@"Could not get path to Imagr.app from target!");
            return NO;
        }
    }
    DDLogDebug(@"imagrApplicationTargetPath=%@", imagrApplicationTargetPath);
    if ( [selectedImagrVersion length] == 0 ) {
        DDLogError(@"Could not get selected Imagr version from user settings!");
        return NO;
    } else if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        NSString *imagrLocalVersionPath = _userSettings[NBCSettingsImagrLocalVersionPath];
        DDLogDebug(@"imagrLocalVersionPath=%@", imagrLocalVersionPath);
        if ( [imagrLocalVersionPath length] != 0 ) {
            NSDictionary *imagrLocalVersionAttributes  = @{
                                                           NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0755
                                                           };
            
            NSDictionary *imagrLocalVersionCopySetting = @{
                                                           NBCWorkflowCopyType : NBCWorkflowCopy,
                                                           NBCWorkflowCopySourceURL : imagrLocalVersionPath,
                                                           NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                                           NBCWorkflowCopyAttributes : imagrLocalVersionAttributes
                                                           };
            DDLogDebug(@"imagrLocalVersionCopySetting=%@", imagrLocalVersionCopySetting);
            if ( [_target nbiNetInstallURL] ) {
                [_resourcesNetInstallCopy addObject:imagrLocalVersionCopySetting];
            } else if ( [_target baseSystemURL] ) {
                [_resourcesBaseSystemCopy addObject:imagrLocalVersionCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            DDLogError(@"[ERROR] Could not get imagrLocalVersionPath from user settings!");
            return NO;
        }
    } else {
        
        // ---------------------------------------------------------------
        //  Check if Imagr is already downloaded, then return local url.
        //  If not, download Imagr and copy to resources for future use.
        // ---------------------------------------------------------------
        if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLatest] ) {
            if ( [_resourcesSettings[NBCSettingsImagrVersion] length] == 0 ) {
                DDLogError(@"[ERROR] Imagr versions array is empty!");
                return NO;
            }
            selectedImagrVersion = _resourcesSettings[NBCSettingsImagrVersion];
            DDLogDebug(@"selectedImagrVersion=%@", selectedImagrVersion);
        }
        
        [self setImagrVersion:selectedImagrVersion];
        NSURL *imagrCachedVersionURL = [_resourcesController cachedVersionURL:selectedImagrVersion resourcesFolder:NBCFolderResourcesImagr];
        DDLogDebug(@"imagrCachedVersionURL=%@", imagrCachedVersionURL);
        if ( [imagrCachedVersionURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *imagrCachedVersionAttributes  = @{
                                                            NSFileOwnerAccountName : @"root",
                                                            NSFileGroupOwnerAccountName : @"wheel",
                                                            NSFilePosixPermissions : @0755
                                                            };
            
            NSDictionary *imagrCachedVersionCopySetting = @{
                                                            NBCWorkflowCopyType : NBCWorkflowCopy,
                                                            NBCWorkflowCopySourceURL : [imagrCachedVersionURL path],
                                                            NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                                            NBCWorkflowCopyAttributes : imagrCachedVersionAttributes
                                                            };
            DDLogDebug(@"imagrCachedVersionCopySetting=%@", imagrCachedVersionCopySetting);
            if ( [_target nbiNetInstallURL] ) {
                [_resourcesNetInstallCopy addObject:imagrCachedVersionCopySetting];
            } else if ( [_target baseSystemURL] ) {
                [_resourcesBaseSystemCopy addObject:imagrCachedVersionCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            NSString *imagrDownloadURL = _resourcesSettings[NBCSettingsImagrDownloadURL];
            DDLogDebug(@"imagrDownloadURL=%@", imagrDownloadURL);
            if ( [imagrDownloadURL length] != 0 ) {
                DDLogInfo(@"Downloading Imagr version %@", selectedImagrVersion);
                [_delegate updateProgressStatus:@"Downloading Imagr..." workflow:self];
                [self downloadResource:[NSURL URLWithString:imagrDownloadURL] resourceTag:NBCDownloaderTagImagr version:selectedImagrVersion];
            } else {
                DDLogError(@"[ERROR] Could not get Imagr download url from resources settings!");
                retval = NO;
            }
        }
    }
    return retval;
} // getImagrApplication

- (void)addImagrToResources:(NSURL *)downloadedFileURL version:(NSString *)version {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *imagrApplicationTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrApplicationTargetPath = NBCImagrApplicationNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrApplicationTargetPath = NBCImagrApplicationTargetURL;
    } else {
        imagrApplicationTargetPath = [[_target imagrApplicationURL] path];
        if ( [imagrApplicationTargetPath length] == 0 ) {
            DDLogError(@"Could not get path to Imagr.app from target!");
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
    }
    DDLogDebug(@"imagrApplicationTargetPath=%@", imagrApplicationTargetPath);
    
    // ---------------------------------------------------------------
    //  Extract Imagr from dmg and copy to resourecs for future use
    // ---------------------------------------------------------------
    NSURL *imagrDownloadedVersionURL = [_resourcesController attachDiskImageAndCopyFileToResourceFolder:downloadedFileURL
                                                                                               filePath:@"Imagr.app"
                                                                                        resourcesFolder:NBCFolderResourcesImagr
                                                                                                version:version];
    DDLogDebug(@"imagrDownloadedApplicationURL=%@", imagrDownloadedVersionURL);
    if ( imagrDownloadedVersionURL ) {
        NSDictionary *imagrDownloadedVersionAttributes  = @{
                                                            NSFileOwnerAccountName : @"root",
                                                            NSFileGroupOwnerAccountName : @"wheel",
                                                            NSFilePosixPermissions : @0755
                                                            };
        
        NSDictionary *imagrDownloadedVersionCopySettings = @{
                                                             NBCWorkflowCopyType : NBCWorkflowCopy,
                                                             NBCWorkflowCopySourceURL : [imagrDownloadedVersionURL path],
                                                             NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                                             NBCWorkflowCopyAttributes : imagrDownloadedVersionAttributes
                                                             };
        DDLogDebug(@"imagrDownloadedVersionCopySettings=%@", imagrDownloadedVersionCopySettings);
        if ( [_target nbiNetInstallURL] ) {
            [self updateNetInstallCopyDict:imagrDownloadedVersionCopySettings];
        } else if ( [_target baseSystemURL] ) {
            [self updateBaseSystemCopyDict:imagrDownloadedVersionCopySettings];
        }
        [self checkCompletedResources];
    } else {
        DDLogError(@"Got no URL to copied Imagr item, something went wrong!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // addImagrToResources:version

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Collect Resources From OS X Installer Package
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)getItemsFromSource:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *sourceBuildVersion = [[workflowItem source] sourceBuild];
    DDLogDebug(@"sourceBuildVersion=%@", sourceBuildVersion);
    if ( [sourceBuildVersion length] != 0 ) {
        
        // ---------------------------------------------------------------
        //  Check if source items are already downloaded, then return local urls.
        //  If not, extract and copy to resources for future use.
        // ---------------------------------------------------------------
        NSDictionary *sourceItemsResourcesDict = [_resourcesController getCachedSourceItemsDict:sourceBuildVersion resourcesFolder:NBCFolderResourcesSource];
        DDLogDebug(@"sourceItemsResourcesDict=%@", sourceItemsResourcesDict);
        if ( [sourceItemsResourcesDict count] != 0 ) {
            NSMutableDictionary *newSourceItemsDict = [[NSMutableDictionary alloc] init];
            NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
            DDLogDebug(@"sourceItemsDict=%@", sourceItemsDict);
            
            // -------------------------------------------------------
            //  Loop through all packages that contain required items
            // -------------------------------------------------------
            NSArray *sourcePackages = [sourceItemsDict allKeys];
            DDLogDebug(@"sourcePackages=%@", sourcePackages);
            for ( NSString *packagePath in sourcePackages ) {
                NSString *packageName = [[packagePath lastPathComponent] stringByDeletingPathExtension];
                DDLogDebug(@"packageName=%@", packageName);
                NSDictionary *packageDict = sourceItemsDict[packagePath];
                DDLogDebug(@"packageDict=%@", packageDict);
                if ( [packageDict count] != 0 ) {
                    NSMutableDictionary *newResourcesPackageDict = [[NSMutableDictionary alloc] init];
                    NSMutableArray *newRegexesArray = [[NSMutableArray alloc] init];
                    NSDictionary *resourcesPackageDict = sourceItemsResourcesDict[packageName];
                    DDLogDebug(@"resourcesPackageDict=%@", resourcesPackageDict);
                    NSArray *regexes = packageDict[NBCSettingsSourceItemsRegexKey];
                    DDLogDebug(@"regexes=%@", regexes);
                    NSArray *resourcesRegexes = resourcesPackageDict[NBCSettingsSourceItemsRegexKey];
                    DDLogDebug(@"resourcesRegexes=%@", resourcesRegexes);
                    for ( NSString *regex in regexes ) {
                        DDLogDebug(@"regex=%@", regex);
                        if ( [resourcesRegexes containsObject:regex] ) {
                            NSString *sourceFolderPath = resourcesPackageDict[NBCSettingsSourceItemsCacheFolderKey];
                            DDLogDebug(@"sourceFolderPath=%@", sourceFolderPath);
                            if ( [sourceFolderPath length] != 0 ) {
                                NSDictionary *newRegexCopySetting = @{
                                                                      NBCWorkflowCopyType : NBCWorkflowCopyRegex,
                                                                      NBCWorkflowCopyRegexSourceFolderURL : sourceFolderPath,
                                                                      NBCWorkflowCopyRegex : regex
                                                                      };
                                DDLogDebug(@"newRegexCopySetting=%@", newRegexCopySetting);
                                [self updateBaseSystemCopyDict:newRegexCopySetting];
                            } else {
                                DDLogError(@"Could not get sourceFolderPath from packageDict");
                            }
                        } else {
                            DDLogDebug(@"Adding regex to regexes to extract");
                            [newRegexesArray addObject:regex];
                        }
                    }
                    
                    if ( [newRegexesArray count] != 0 ) {
                        newResourcesPackageDict[NBCSettingsSourceItemsRegexKey] = newRegexesArray;
                        DDLogDebug(@"newResourcesPackageDict=%@", newResourcesPackageDict);
                    }
                    
                    NSMutableArray *newPathsArray = [[NSMutableArray alloc] init];
                    NSArray *paths = packageDict[NBCSettingsSourceItemsPathKey];
                    DDLogDebug(@"paths=%@", paths);
                    NSDictionary *resourcesPathsDict = resourcesPackageDict[NBCSettingsSourceItemsPathKey];
                    DDLogDebug(@"resourcesPathsDict=%@", resourcesPathsDict);
                    for ( NSString *packageItemPath in paths ) {
                        
                        // -----------------------------------------------------------------------
                        //  Check if item exists in resource folder
                        //  If it does, add it with a copySetting to _resourcesBaseSystemCopy
                        //  If it doesn't, add it to a new sourceItemsDict to pass for extraction
                        // -----------------------------------------------------------------------
                        NSString *localItemPath = resourcesPathsDict[packageItemPath];
                        DDLogDebug(@"localItemPath=%@", localItemPath);
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
                            DDLogDebug(@"newCopySetting=%@", newCopySetting);
                            [self updateBaseSystemCopyDict:newCopySetting];
                            
                        } else {
                            [newPathsArray addObject:packageItemPath];
                        }
                    }
                    
                    if ( [newPathsArray count] != 0 ) {
                        newResourcesPackageDict[NBCSettingsSourceItemsPathKey] = newPathsArray;
                        DDLogDebug(@"newResourcesPackageDict=%@", newResourcesPackageDict);
                    }
                    
                    if ( [newResourcesPackageDict count] != 0 ) {
                        newSourceItemsDict[packagePath] = newResourcesPackageDict;
                        DDLogDebug(@"newSourceItemsDict=%@", newSourceItemsDict);
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
                DDLogDebug(@"newResourcesSettings=%@", newResourcesSettings);
                newResourcesSettings[NBCSettingsSourceItemsKey] = newSourceItemsDict;
                DDLogDebug(@"newResourcesSettings=%@", newResourcesSettings);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( ! _itemsToExtractFromSource ) {
        _itemsToExtractFromSource = [[NSMutableArray alloc] init];
        NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
        DDLogDebug(@"sourceItemsDict=%@", sourceItemsDict);
        _itemsToExtractFromSource = [[sourceItemsDict allKeys] mutableCopy];
        DDLogDebug(@"_itemsToExtractFromSource=%@", _itemsToExtractFromSource);
    }
    
    if ( [_itemsToExtractFromSource count] != 0 ) {
        NSString *packagePath = [_itemsToExtractFromSource firstObject];
        DDLogDebug(@"packagePath=%@", packagePath);
        [_itemsToExtractFromSource removeObjectAtIndex:0];
        DDLogDebug(@"_itemsToExtractFromSource=%@", _itemsToExtractFromSource);
        [self extractPackageToTemporaryFolder:workflowItem packagePath:packagePath];
    } else {
        [self checkCompletedResources];
    }
} // extractItemsFromSource

- (void)extractPackageToTemporaryFolder:(NBCWorkflowItem *)workflowItem packagePath:(NSString *)packagePath {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogDebug(@"packagePath=%@", packagePath);
    DDLogInfo(@"Extracting resources from %@...", [packagePath lastPathComponent]);
    [_delegate updateProgressStatus:[NSString stringWithFormat:@"Extracting resources from %@...", [packagePath lastPathComponent]] workflow:self];
    NSURL *packageTemporaryFolder = [self getPackageTemporaryFolderURL:workflowItem];
    DDLogDebug(@"packageTemporaryFolder=%@", packageTemporaryFolder);
    if ( packageTemporaryFolder ) {
        NSURL *temporaryFolder = [workflowItem temporaryFolderURL];
        DDLogDebug(@"temporaryFolder=%@", temporaryFolder);
        if ( temporaryFolder ) {
            NSArray *scriptArguments;
            int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
            DDLogDebug(@"sourceVersionMinor=%d", sourceVersionMinor);
            if ( sourceVersionMinor <= 9 ) {
                scriptArguments = @[ @"-c",
                                     [NSString stringWithFormat:@"/usr/bin/xar -x -f \"%@\" Payload -C \"%@\"; /usr/bin/cd \"%@\"; /usr/bin/cpio -idmu -I \"%@/Payload\"", packagePath, [temporaryFolder path], [packageTemporaryFolder path], [temporaryFolder path]]
                                     ];
            } else {
                NSString *pbzxPath = [[NSBundle mainBundle] pathForResource:@"pbzx" ofType:@""];
                DDLogDebug(@"pbzxPath=%@", pbzxPath);
                scriptArguments = @[ @"-c",
                                     [NSString stringWithFormat:@"%@ %@ | /usr/bin/cpio -idmu --quiet", pbzxPath, packagePath],
                                     ];
            }
            DDLogDebug(@"scriptArguments=%@", scriptArguments);
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
                    DDLogDebug(@"terminationStatus=%d", terminationStatus);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
    NSString *packageTemporaryFolderName = [NSString stringWithFormat:@"pkg.%@", [NSString nbc_randomString]];
    DDLogDebug(@"packageTemporaryFolderName=%@", packageTemporaryFolderName);
    NSURL *packageTemporaryFolderURL = [temporaryFolderURL URLByAppendingPathComponent:packageTemporaryFolderName isDirectory:YES];
    DDLogDebug(@"packageTemporaryFolderURL=%@", packageTemporaryFolderURL);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    DDLogInfo(@"Copying extracted resources to cache folder...");
    [_delegate updateProgressStatus:@"Copying extracted resources to cache folder..." workflow:self];
    NSDictionary *sourceItemsDict = _resourcesSettings[NBCSettingsSourceItemsKey];
    DDLogDebug(@"sourceItemsDict=%@", sourceItemsDict);
    if ( packageTemporaryFolderURL != nil ) {
        NSDictionary *packageDict = sourceItemsDict[packagePath];
        DDLogDebug(@"packageDict=%@", packageDict);
        NSArray *pathsToCopy = packageDict[NBCSettingsSourceItemsPathKey];
        DDLogDebug(@"pathsToCopy=%@", pathsToCopy);
        if ( [pathsToCopy count] != 0 ) {
            for ( NSString *itemPath in pathsToCopy ) {
                NSURL *destinationURL;
                NSURL *itemSourceURL = [packageTemporaryFolderURL URLByAppendingPathComponent:itemPath];
                DDLogDebug(@"itemSourceURL=%@", itemSourceURL);
                if ( itemSourceURL ) {
                    destinationURL = [_resourcesController copySourceItemToResources:itemSourceURL
                                                                      sourceItemPath:itemPath
                                                                     resourcesFolder:NBCFolderResourcesSource
                                                                         sourceBuild:[[workflowItem source] sourceBuild]];
                    DDLogDebug(@"destinationURL=%@", destinationURL);
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
                DDLogDebug(@"newCopySetting=%@", newCopySetting);
                [self updateBaseSystemCopyDict:newCopySetting];
                [_itemsToExtractFromSource removeObject:packagePath];
            }
        }
        
        NSArray *regexArray = packageDict[NBCSettingsSourceItemsRegexKey];
        DDLogDebug(@"regexArray=%@", regexArray);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
    DDLogDebug(@"[_resourcesNetInstallCopy count]=%lu", (unsigned long)[_resourcesNetInstallCopy count]);
    DDLogDebug(@"[_resourcesBaseSystemCopy count]=%lu", (unsigned long)[_resourcesBaseSystemCopy count]);
    NSLog(@"_resourcesBaseSystemCopy=%@", _resourcesBaseSystemCopy);
    DDLogDebug(@"[_resourcesNetInstallInstall count]=%lu", (unsigned long)[_resourcesNetInstallInstall count]);
    DDLogDebug(@"[_resourcesBaseSystemInstall count]=%lu", (unsigned long)[_resourcesBaseSystemInstall count]);
    DDLogDebug(@"requiredCopyResources=%lu", requiredCopyResources);
    DDLogDebug(@"requiredInstallResources=%lu", requiredInstallResources);
    DDLogDebug(@"_resourcesCount=%d", _resourcesCount);
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    // ----------------------------------------------------------------------------------------------
    //  Create a dict for package with URL and optionally choiceChangesXML and add to resource dict
    // ----------------------------------------------------------------------------------------------
    NSString *packageName;
    NSMutableDictionary *packageDict = [[NSMutableDictionary alloc] init];
    if ( packageURL ) {
        packageName = [packageURL lastPathComponent];
        DDLogDebug(@"packageName=%@", packageName);
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
    
    DDLogDebug(@"packageDict=%@", packageDict);
    
    if ( packageName ) {
        [_resourcesBaseSystemInstall addObject:packageDict];
        DDLogDebug(@"_resourcesBaseSystemInstall=%@", _resourcesBaseSystemInstall);
    }
    
    [self checkCompletedResources];
} // updateBaseSystemInstallerDict:choiceChangesXML

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Create Imagr Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)createImagrSettingsPlist:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSString *configurationURL = _userSettings[NBCSettingsImagrConfigurationURL];
    DDLogDebug(@"configurationURL=%@", configurationURL);
    NSString *imagrConfigurationPlistTargetPath;
    if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        imagrConfigurationPlistTargetPath = NBCImagrConfigurationPlistNBICreatorTargetURL;
    } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
        imagrConfigurationPlistTargetPath = NBCImagrConfigurationPlistTargetURL;
    } else {
        imagrConfigurationPlistTargetPath = [[_target imagrConfigurationPlistURL] path];
        if ( [imagrConfigurationPlistTargetPath length] == 0 ) {
            DDLogError(@"Could not get path to Imagr.app from target!");
            return NO;
        }
    }
    DDLogDebug(@"imagrConfigurationPlistTargetPath=%@", imagrConfigurationPlistTargetPath);
    if ( configurationURL ) {
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
        if ( temporaryFolderURL ) {
            
            // ------------------------------------------------------------
            //  Create Imagr configuration plist and add to copy resources
            // ------------------------------------------------------------
            NSURL *settingsFileURL = [temporaryFolderURL URLByAppendingPathComponent:@"com.grahamgilbert.Imagr.plist"];
            DDLogDebug(@"settingsFileURL=%@", settingsFileURL);
            NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] initWithDictionary:@{ @"serverurl" : configurationURL }];
            
            NSString *reportingURL = _userSettings[NBCSettingsImagrReportingURL];
            if ( [reportingURL length] != 0 ) {
                settingsDict[@"reporturl"] = reportingURL;
            }
            
            DDLogDebug(@"settingsDict=%@", settingsDict);
            if ( [settingsDict writeToURL:settingsFileURL atomically:YES] ) {
                NSDictionary *copyAttributes  = @{
                                                  NSFileOwnerAccountName : @"root",
                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                  NSFilePosixPermissions : @0644
                                                  };
                
                NSDictionary *copySettings = @{
                                               NBCWorkflowCopyType : NBCWorkflowCopy,
                                               NBCWorkflowCopySourceURL : [settingsFileURL path],
                                               NBCWorkflowCopyTargetURL : imagrConfigurationPlistTargetPath,
                                               NBCWorkflowCopyAttributes : copyAttributes
                                               };
                DDLogDebug(@"copySettings=%@", copySettings);
                if ( [_target nbiNetInstallURL] != nil ) {
                    [_resourcesNetInstallCopy addObject:copySettings];
                } else if ( [_target baseSystemURL] ) {
                    [_resourcesBaseSystemCopy addObject:copySettings];
                }
                
                [self checkCompletedResources];
            } else {
                DDLogError(@"[ERROR] Could not write Imagr settings to url: %@", settingsFileURL);
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
} // createImagrSettingsPlist

- (BOOL)createImagrRCImaging:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = YES;
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    DDLogDebug(@"temporaryFolderURL=%@", temporaryFolderURL);
    NSString *imagrRCImagingTargetPath;
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    DDLogDebug(@"sourceVersionMinor=%d", sourceVersionMinor);
    NSString *imagrRCImagingContent = [NBCWorkflowNBIController generateImagrRCImagingForNBICreator:[workflowItem userSettings] osMinorVersion:sourceVersionMinor];
    DDLogDebug(@"imagrRCImagingContent=%@", imagrRCImagingContent);
    if ( [imagrRCImagingContent length] != 0 ) {
        if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
            imagrRCImagingTargetPath = NBCImagrRCImagingNBICreatorTargetURL;
        } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            imagrRCImagingTargetPath = NBCImagrRCImagingTargetURL;
        } else {
            if ( [_target rcImagingURL] != nil ) {
                imagrRCImagingTargetPath = [[_target rcImagingURL] path];
            } else {
                DDLogError(@"Found no rc.imaging URL from target settings!");
                return NO;
            }
            
            if ( [[_target rcImagingContent] length] != 0 ) {
                imagrRCImagingContent = [_target rcImagingContent];
            } else {
                DDLogError(@"Found no rc.imaging content form target settings!");
                return NO;
            }
        }
        DDLogDebug(@"imagrRCImagingTargetPath=%@", imagrRCImagingTargetPath);
        if ( temporaryFolderURL ) {
            // ---------------------------------------------------
            //  Create Imagr rc.imaging and add to copy resources
            // ---------------------------------------------------
            NSURL *rcImagingURL = [temporaryFolderURL URLByAppendingPathComponent:@"rc.imaging"];
            DDLogDebug(@"rcImagingURL=%@", rcImagingURL);
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
                DDLogDebug(@"copySettings=%@", copySettings);
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
} // createImagrRCImaging

@end
