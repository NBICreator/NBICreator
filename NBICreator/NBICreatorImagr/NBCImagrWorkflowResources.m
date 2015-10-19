//
//  NBCImagrWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCImagrWorkflowResources.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NBCLogging.h"
#import "NSString+randomString.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowNBIController.h"

DDLogLevel ddLogLevel;

@implementation NBCImagrWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
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
    [self setWorkflowCompleted:NO];
    [self setIsNBI:( [[[workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", ( _isNBI ) ? @"YES" : @"NO" );
    [self setSettingsChanged:[workflowItem userSettingsChanged]];
    
    DDLogDebug(@"[DEBUG] Adding static source items to resource count required...");
    if ( ! _isNBI ) {
        
        // -------------------------------------------------------
        //  Imagr.app, com.grahamgilbert.Imagr.plist, rc.imaging
        // -------------------------------------------------------
        [self setResourcesCount:3];
    } else {
        int resourcesCount = 0;
        
        // -------------------------------------------------------
        //  Imagr.app
        // -------------------------------------------------------
        if ( [_settingsChanged[NBCSettingsImagrVersion] boolValue] ) {
            resourcesCount++;
        }
        
        // -------------------------------------------------------
        //  com.grahamgilbert.Imagr.plist
        // -------------------------------------------------------
        if (
            [_settingsChanged[NBCSettingsImagrConfigurationURL] boolValue] ||
            [_settingsChanged[NBCSettingsImagrReportingURL] boolValue] ||
            [_settingsChanged[NBCSettingsImagrSyslogServerURI] boolValue]
            ) {
            resourcesCount++;
        }
        
        [self setResourcesCount:resourcesCount];
    }
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
    
    // ----------------------------------------------------------------
    //  Update _resourcesCount with all package extration source items
    // ----------------------------------------------------------------
    DDLogDebug(@"[DEBUG] Adding package extraction source items to resource count required...");
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
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
    
    // ----------------------------------------------------------
    //  Update _resourcesCount with all certificate source items
    // ----------------------------------------------------------
    DDLogDebug(@"[DEBUG] Adding certificate source items to resource count required...");
    NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
    if ( [certificatesArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + ( (int)[certificatesArray count] + 1 ) )]; // Add 1 for certificate install script
    }
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
    
    // --------------------------------------------------------------
    //  Update _resourcesCount with all package install source items
    // --------------------------------------------------------------
    DDLogDebug(@"[DEBUG] Adding package install source items to resource count required...");
    NSArray *packagesArray = _resourcesSettings[NBCSettingsPackagesKey];
    if ( [packagesArray count] != 0 ) {
        [self setResourcesCount:( _resourcesCount + (int)[packagesArray count] )];
    }
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
    
    // ---------------------------
    //  Start preparing resources
    // ---------------------------
    if ( _isNBI && [_userSettings count] != 0 ) {
        
        // ---------------------------
        //  Packages
        // ---------------------------
        if ( [packagesArray count] != 0 ) {
            if ( ! [self preparePackages:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  Certificates
        // ---------------------------
        if ( [certificatesArray count] != 0 ) {
            if ( ! [self prepareCertificates:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  Imagr.app
        // ---------------------------
        if ( [_settingsChanged[NBCSettingsImagrVersion] boolValue] ) {
            if ( ! [self getImagrApplication:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  com.grahamgilbert.Imagr.plist
        // ---------------------------
        if (
            [_settingsChanged[NBCSettingsImagrConfigurationURL] boolValue] ||
            [_settingsChanged[NBCSettingsImagrReportingURL] boolValue] ||
            [_settingsChanged[NBCSettingsImagrSyslogServerURI] boolValue]
            ) {
            if ( ! [self createImagrSettingsPlist:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  rc.imaging
        // ---------------------------
        if (
            [_settingsChanged[NBCSettingsLaunchConsoleAppKey] boolValue]
            ) {
            if ( ! [self createImagrRCImaging:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        [self checkCompletedResources];
    } else if ( _userSettings ) {
        
        DDLogDebug(@"[DEBUG] Adding background source items to resource count required...");
        if ( [_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] ) {
            [self setResourcesCount:( _resourcesCount + 1 )];
            if ( ! [_userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
                [self setResourcesCount:( _resourcesCount + 1 )];
            }
        }
        DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
        
        // ---------------------------
        //  Packages
        // ---------------------------
        if ( [packagesArray count] != 0 ) {
            if ( ! [self preparePackages:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  Certificates
        // ---------------------------
        if ( [certificatesArray count] != 0 ) {
            if ( ! [self prepareCertificates:workflowItem] ) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
                return;
            }
        }
        
        // ---------------------------
        //  Imagr.app
        // ---------------------------
        if ( ! [self getImagrApplication:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        // ---------------------------
        //  com.grahamgilbert.Imagr.plist
        // ---------------------------
        if ( ! [self createImagrSettingsPlist:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        // ---------------------------
        //  rc.imaging
        // ---------------------------
        if ( ! [self createImagrRCImaging:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        // ---------------------------
        //  DesktopViewer
        // ---------------------------
        if ( ! [self prepareDesktopViewer:workflowItem] ) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
            return;
        }
        
        [self getItemsFromSource:workflowItem];
    } else {
        DDLogError(@"[ERROR] UI settings are empty!");
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

- (BOOL)prepareCertificates:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogInfo(@"Preparing certificates...");
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
    } else {
        DDLogInfo(@"No certificates found!");
    }
    
    return retval;
} // prepareCertificates

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    // ------------------------------------------------------
    //  Extract info from downloadInfo Dict
    // ------------------------------------------------------
    NSString *resourceTag = downloadInfo[NBCDownloaderTag];
    // ------------------------------------------------------
    //  Send command to correct copy method based on tag
    // ------------------------------------------------------
    if ( [resourceTag isEqualToString:NBCDownloaderTagImagr] ) {
        NSString *version = downloadInfo[NBCDownloaderVersion];
        [self addImagrToResources:url version:version];
    } else if ( [resourceTag isEqualToString:NBCDownloaderTagImagrBranch] ) {
        NSDictionary *branchDict = downloadInfo[NBCSettingsImagrGitBranchDict];
        [self addImagrBranchToResources:url branchDict:branchDict];
    }
} // fileDownloadCompleted:downloadInfo

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

- (BOOL)getImagrApplication:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogInfo(@"Preparing Imagr.app...");
    BOOL retval = YES;
    NSString *selectedImagrVersion = _userSettings[NBCSettingsImagrVersion];
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
    
    if ( [selectedImagrVersion length] == 0 ) {
        DDLogError(@"Could not get selected Imagr version from user settings!");
        return NO;
    } else if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        NSString *imagrLocalVersionPath = _userSettings[NBCSettingsImagrLocalVersionPath];
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
    } else if ( [selectedImagrVersion isEqualToString:NBCMenuItemGitBranch] ) {
        NSString *branch = _resourcesSettings[NBCSettingsImagrGitBranch];
        NSString *sha = _resourcesSettings[NBCSettingsImagrGitBranchSHA];
        NSString *buildTarget = _resourcesSettings[NBCSettingsImagrBuildTarget];
        
        NSURL *imagrBranchCachedVersionURL = [_resourcesController cachedBranchURL:branch sha:sha resourcesFolder:NBCFolderResourcesCacheImagr];
        if ( [imagrBranchCachedVersionURL checkResourceIsReachableAndReturnError:nil] ) {
            NSString *target = _resourcesSettings[NBCSettingsImagrBuildTarget];
            NSURL *targetImagrAppURL = [imagrBranchCachedVersionURL URLByAppendingPathComponent:[NSString stringWithFormat:@"build/%@/Imagr.app", target]];
            if ( [targetImagrAppURL checkResourceIsReachableAndReturnError:nil] ) {
                
                NSDictionary *imagrCachedVersionAttributes  = @{
                                                                NSFileOwnerAccountName : @"root",
                                                                NSFileGroupOwnerAccountName : @"wheel",
                                                                NSFilePosixPermissions : @0755
                                                                };
                
                NSDictionary *imagrCachedVersionCopySetting = @{
                                                                NBCWorkflowCopyType : NBCWorkflowCopy,
                                                                NBCWorkflowCopySourceURL : [targetImagrAppURL path],
                                                                NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                                                NBCWorkflowCopyAttributes : imagrCachedVersionAttributes
                                                                };
                if ( [_target nbiNetInstallURL] ) {
                    [_resourcesNetInstallCopy addObject:imagrCachedVersionCopySetting];
                } else if ( [_target baseSystemURL] ) {
                    [_resourcesBaseSystemCopy addObject:imagrCachedVersionCopySetting];
                }
                
                [self checkCompletedResources];
            } else {
                [_resourcesController buildProjectAtURL:imagrBranchCachedVersionURL buildTarget:buildTarget];
            }
        } else {
            NSString *imagrDownloadURL = _resourcesSettings[NBCSettingsImagrDownloadURL];
            if ( [imagrDownloadURL length] != 0 ) {
                DDLogInfo(@"Downloading Imagr Git Branch %@...", branch);
                [_delegate updateProgressStatus:@"Downloading Imagr Source..." workflow:self];
                NSDictionary *branchDict = @{
                                             NBCSettingsImagrGitBranch : branch,
                                             NBCSettingsImagrGitBranchSHA : sha,
                                             NBCSettingsImagrBuildTarget : buildTarget
                                             };
                
                NSDictionary *downloadInfo = @{
                                               NBCDownloaderTag : NBCDownloaderTagImagrBranch,
                                               NBCSettingsImagrGitBranchDict : branchDict
                                               };
                NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
                [downloader downloadFileFromURL:[NSURL URLWithString:imagrDownloadURL] destinationPath:@"/tmp" downloadInfo:downloadInfo];
            } else {
                DDLogError(@"[ERROR] Could not get Imagr download url from resources settings!");
                retval = NO;
            }
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
        }
        
        [self setImagrVersion:selectedImagrVersion];
        NSURL *imagrCachedVersionURL = [_resourcesController cachedVersionURL:selectedImagrVersion resourcesFolder:NBCFolderResourcesCacheImagr];
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
            if ( [_target nbiNetInstallURL] ) {
                [_resourcesNetInstallCopy addObject:imagrCachedVersionCopySetting];
            } else if ( [_target baseSystemURL] ) {
                [_resourcesBaseSystemCopy addObject:imagrCachedVersionCopySetting];
            }
            
            [self checkCompletedResources];
        } else {
            NSString *imagrDownloadURL = _resourcesSettings[NBCSettingsImagrDownloadURL];
            if ( [imagrDownloadURL length] != 0 ) {
                DDLogInfo(@"Downloading Imagr version %@", selectedImagrVersion);
                [_delegate updateProgressStatus:@"Downloading Imagr..." workflow:self];
                NSDictionary *downloadInfo = @{
                                               NBCDownloaderTag : NBCDownloaderTagImagr,
                                               NBCDownloaderVersion : selectedImagrVersion
                                               };
                NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
                [downloader downloadFileFromURL:[NSURL URLWithString:imagrDownloadURL] destinationPath:@"/tmp" downloadInfo:downloadInfo];
            } else {
                DDLogError(@"[ERROR] Could not get Imagr download url from resources settings!");
                retval = NO;
            }
        }
    }
    return retval;
} // getImagrApplication

- (void)xcodeBuildComplete:(NSURL *)productURL {
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
    
    NSDictionary *imagrAttributes  = @{
                                       NSFileOwnerAccountName : @"root",
                                       NSFileGroupOwnerAccountName : @"wheel",
                                       NSFilePosixPermissions : @0755
                                       };
    
    NSDictionary *imagrCopySettings = @{
                                        NBCWorkflowCopyType : NBCWorkflowCopy,
                                        NBCWorkflowCopySourceURL : [productURL path],
                                        NBCWorkflowCopyTargetURL : imagrApplicationTargetPath,
                                        NBCWorkflowCopyAttributes : imagrAttributes
                                        };
    if ( [_target nbiNetInstallURL] ) {
        [self updateNetInstallCopyDict:imagrCopySettings];
    } else if ( [_target baseSystemURL] ) {
        [self updateBaseSystemCopyDict:imagrCopySettings];
    }
    [self checkCompletedResources];
}

- (void)xcodeBuildFailed:(NSString *)errorOutput {
    NSLog(@"Build Failed!");
    NSLog(@"errorOutput=%@", errorOutput);
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
}

- (void)addImagrBranchToResources:(NSURL *)downloadedFileURL branchDict:(NSDictionary *)branchDict {
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
    
    NSString *buildTarget = branchDict[NBCSettingsImagrBuildTarget];
    if ( [buildTarget length] != 0 ) {
        
        // ---------------------------------------------------------------
        //  Extract Imagr from zip and copy to resourecs for future use
        // ---------------------------------------------------------------
        NSURL *imagrProjectURL = [_resourcesController unzipAndCopyGitBranchToResourceFolder:downloadedFileURL resourcesFolder:NBCFolderResourcesCacheImagr branchDict:branchDict];
        if ( imagrProjectURL ) {
            [_resourcesController buildProjectAtURL:imagrProjectURL buildTarget:buildTarget];
        } else {
            DDLogError(@"Got no URL to copied Imagr item, something went wrong!");
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
        }
    } else {
        DDLogError(@"[ERROR] Build Target was empty!");
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
}

- (void)addImagrToResources:(NSURL *)downloadedFileURL version:(NSString *)version {
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
    
    // ---------------------------------------------------------------
    //  Extract Imagr from dmg and copy to resourecs for future use
    // ---------------------------------------------------------------
    NSURL *imagrDownloadedVersionURL = [_resourcesController attachDiskImageAndCopyFileToResourceFolder:downloadedFileURL
                                                                                               filePath:@"Imagr.app"
                                                                                        resourcesFolder:NBCFolderResourcesCacheImagr
                                                                                                version:version];
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
    NSString *sourceBuildVersion = [[workflowItem source] sourceBuild];
    if ( [sourceBuildVersion length] != 0 ) {
        
        // ---------------------------------------------------------------
        //  Check if source items are already downloaded, then return local urls.
        //  If not, extract and copy to resources for future use.
        // ---------------------------------------------------------------
        NSDictionary *sourceItemsResourcesDict = [_resourcesController getCachedSourceItemsDict:sourceBuildVersion resourcesFolder:NBCFolderResourcesCacheSource];
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
            __block BOOL openFailure = NO;
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
                                                if ( [errStr containsString:@"XAR open failure"] ) {
                                                    openFailure = YES;
                                                }
                                                
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
                        openFailure = YES;
                        userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
                    }
                    [nc removeObserver:stdOutObserver];
                    [nc removeObserver:stdErrObserver];
                    [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
                }];
                
            }] runTaskWithCommandAtPath:commandURL arguments:scriptArguments currentDirectory:[packageTemporaryFolder path] stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
#pragma unused(error)
                [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                    if ( terminationStatus == 0 && ! openFailure ) {
                        
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
                                                                     resourcesFolder:NBCFolderResourcesCacheSource
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
                                             resourcesFolder:NBCFolderResourcesCacheSource
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
    DDLogDebug(@"[DEBUG] Checking if all resources have been prepared...");
    // ----------------------------------------------------------------------------------------------
    //  Check if all resources have been prepared. If they have, post notification workflow complete
    // ----------------------------------------------------------------------------------------------
    unsigned long requiredCopyResources = ( [_resourcesNetInstallCopy count] + [_resourcesBaseSystemCopy count] );
    DDLogDebug(@"[DEBUG] Prepared resources for copy: %lu", requiredCopyResources);
    unsigned long requiredInstallResources = ( [_resourcesNetInstallInstall count] + [_resourcesBaseSystemInstall count] );
    DDLogDebug(@"[DEBUG] Prepared resources for installation: %lu", requiredInstallResources);
    DDLogDebug(@"[DEBUG] Count of resources prepared: %d", ( (int) requiredCopyResources + (int) requiredInstallResources ) );
    DDLogDebug(@"[DEBUG] Count of resources required: %d", _resourcesCount);
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
        
        if ( ! _workflowCompleted ) {
            [self setWorkflowCompleted:YES];
            [_target setResourcesNetInstallDict:_resourcesNetInstallDict];
            [_target setResourcesBaseSystemDict:_resourcesBaseSystemDict];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
        } else {
            NSLog(@"Workflow already completed!");
        }
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
#pragma mark Create Imagr Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)createImagrSettingsPlist:(NBCWorkflowItem *)workflowItem {
    DDLogInfo(@"Preparing com.grahamgilbert.Imagr.plist...");
    BOOL retval = YES;
    NSString *configurationURL = _userSettings[NBCSettingsImagrConfigurationURL];
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
    
    if ( configurationURL ) {
        NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
        if ( temporaryFolderURL ) {
            
            // ------------------------------------------------------------
            //  Create Imagr configuration plist and add to copy resources
            // ------------------------------------------------------------
            NSURL *settingsFileURL = [temporaryFolderURL URLByAppendingPathComponent:@"com.grahamgilbert.Imagr.plist"];
            NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] initWithDictionary:@{ @"serverurl" : configurationURL }];
            
            NSString *reportingURL = _userSettings[NBCSettingsImagrReportingURL];
            if ( [reportingURL length] != 0 ) {
                settingsDict[NBCSettingsImagrReportingURLKey] = reportingURL;
            }
            
            NSString *syslogServerURI = _userSettings[NBCSettingsImagrSyslogServerURI];
            if ( [syslogServerURI length] != 0 ) {
                settingsDict[NBCSettingsImagrSyslogServerURIKey] = syslogServerURI;
            }
            
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
                if ( [_target nbiNetInstallURL] ) {
                    [_resourcesNetInstallCopy addObject:copySettings];
                } else if ( [_target baseSystemURL] ) {
                    [_resourcesBaseSystemCopy addObject:copySettings];
                } else {
                    DDLogError(@"[ERROR] No target defined!");
                    return NO;
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
    DDLogInfo(@"Preparing rc.imaging...");
    BOOL retval = YES;
    NSError *error;
    NSURL *temporaryFolderURL = [workflowItem temporaryFolderURL];
    NSString *imagrRCImagingTargetPath;
    NSURL *rcImagingURL;
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    NSString *imagrRCImagingContent = [NBCWorkflowNBIController generateImagrRCImagingForNBICreator:[workflowItem userSettings] osMinorVersion:sourceVersionMinor];
    if ( [imagrRCImagingContent length] != 0 ) {
        if ( _isNBI && [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
            
            // Write directly to the volume
            rcImagingURL = [[_target nbiNetInstallVolumeURL] URLByAppendingPathComponent:NBCRCImagingTargetURL];
            DDLogDebug(@"[DEBUG] Writing rc.imaging to path: %@", [rcImagingURL path]);
            if ( [imagrRCImagingContent writeToURL:rcImagingURL atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
                [self checkCompletedResources];
            } else {
                DDLogError(@"[ERROR] Could not write rc.imaging to url: %@", [rcImagingURL path]);
                DDLogError(@"[ERROR] %@", error);
                return NO;
            }
        } else {
            if ( [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
                imagrRCImagingTargetPath = NBCRCImagingNBICreatorTargetURL;
            } else if ( [_nbiCreationTool isEqualToString:NBCMenuItemSystemImageUtility] ) {
                imagrRCImagingTargetPath = NBCRCImagingTargetURL;
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
            
            if ( temporaryFolderURL ) {
                
                // ---------------------------------------------------
                //  Create Imagr rc.imaging and add to copy resources
                // ---------------------------------------------------
                rcImagingURL = [temporaryFolderURL URLByAppendingPathComponent:@"rc.imaging"];
            } else {
                DDLogError(@"[ERROR] Could not get temporaryFolderURL from workflow item!");
                retval = NO;
            }
            
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
        }
    } else {
        DDLogError(@"[ERROR] rcImagingContent is empty!");
        retval = NO;
    }
    
    return retval;
} // createImagrRCImaging

@end
