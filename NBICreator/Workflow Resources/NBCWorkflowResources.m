//
//  NBCWorkflowResources.m
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

#import "NBCConstants.h"
#import "NBCError.h"
#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowResources.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCLog.h"

@implementation NBCWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _resourcesBaseSystemCopy = [[NSMutableArray alloc] init];
        _resourcesNetInstallCopy = [[NSMutableArray alloc] init];
        _resourcesBaseSystemInstall = [[NSMutableArray alloc] init];
        _resourcesNetInstallInstall = [[NSMutableArray alloc] init];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Prepare Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)prepareResources:(NBCWorkflowItem *)workflowItem {

    DDLogInfo(@"Preparing resources...");

    [self setWorkflowItem:workflowItem];
    [self setWorkflowType:[_workflowItem workflowType]];
    [self setSource:[_workflowItem source]];
    [self setUserSettings:[_workflowItem userSettings]];
    [self setResourcesSettings:[_workflowItem resourcesSettings]];

    [self setIsNBI:([[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI]) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", (_isNBI) ? @"YES" : @"NO");

    [self setSettingsChanged:[_workflowItem userSettingsChanged]];

    if ([[_source sourceType] isEqualToString:NBCSourceTypeInstallESDDiskImage] || [[_source sourceType] isEqualToString:NBCSourceTypeInstallerApplication]) {
        NSError *error;
        NSURL *installESDVolumeURL = [_source installESDVolumeURL];
        if ([installESDVolumeURL checkResourceIsReachableAndReturnError:&error]) {
            [self setInstallESDVolumeURL:installESDVolumeURL];
            DDLogDebug(@"[DEBUG] InstallESD volume path: %@", [_installESDVolumeURL path]);
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{
                                                                  NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Path to InstallESD volume was empty"]
                                                              }];
            return;
        }
    }

    [self setSourceVersionMinor:(int)[[_source expandVariables:@"%OSMINOR%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (minor): %d", _sourceVersionMinor);

    [self setSourceVersionPatch:(int)[[_source expandVariables:@"%OSPATCH%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (patch): %d", _sourceVersionMinor);
    
    NSString *sourceOSBuild = [[_workflowItem source] sourceBuild];
    if ([sourceOSBuild length] != 0) {
        [self setSourceOSBuild:sourceOSBuild];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{
                                                              NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Source os build was empty"]
                                                          }];
        return;
    }

    NSString *creationTool = _userSettings[NBCSettingsNBICreationToolKey];
    if ([creationTool length] != 0) {
        [self setCreationTool:creationTool];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{
                                                              NBCUserInfoNSErrorKey : [NBCError errorWithDescription:@"Unable to get creation tool"]
                                                          }];
        return;
    }

    [self prepareResourcesToInstall];
} // prepareResources

- (void)prepareResourcesToInstall {

    DDLogInfo(@"Preparing resources to install...");

    NSError *error = nil;

    // --------------------------------------------------------------------------------
    // Packages
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        NSArray *packagesArray = _resourcesSettings[NBCSettingsPackagesKey];
        if ([packagesArray count] != 0) {
            if (![self addInstallPackages:packagesArray error:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing packages for installation failed"]
                                                                  }];
                return;
            }
        }
    }

    // --------------------------------------------------------------------------------
    // Packages NetInstall
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeNetInstall) {
        NSArray *packagesArrayNetInstall = _resourcesSettings[NBCSettingsNetInstallPackagesKey];
        if ([packagesArrayNetInstall count] != 0) {
            if (![self addInstallPackagesNetInstall:packagesArrayNetInstall error:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing NetInstall packages for installation failed"]
                                                                  }];
                return;
            }
        }
    }

    [self prepareResourcesToCopy];
} // prepareResourcesToInstall

- (void)prepareResourcesToCopy {

    DDLogInfo(@"Preparing resources to copy...");

    NSError *error = nil;

    // --------------------------------------------------------------------------------
    // Certificates
    // --------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsCertificatesKey] boolValue]))) {
        NSArray *certificatesArray = _resourcesSettings[NBCSettingsCertificatesKey];
        if ([certificatesArray count] != 0) {
            if (![self addCopyCertificateScript:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing installCertificates.bash failed"]
                                                                  }];
                return;
            }

            if (![self addCopyCertificates:certificatesArray error:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing certificates failed"]
                                                                  }];
                return;
            }
        }
    }

    // --------------------------------------------------------------------------------
    // ConfigurationProfiles NetInstall
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeNetInstall) {
        NSArray *configurationProfilesArray = _resourcesSettings[NBCSettingsConfigurationProfilesNetInstallKey];
        if ([configurationProfilesArray count] != 0) {
            if (![self addCopyConfigurationProfilesNetInstall:configurationProfilesArray error:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing NetInstall configuration profiles failed"]
                                                                  }];
                return;
            }
        }
    }

    // --------------------------------------------------------------------------------
    // Desktop Picture (Custom)
    // --------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) ||
        (_isNBI && ([_settingsChanged[NBCSettingsUseBackgroundImageKey] boolValue] || [_settingsChanged[NBCSettingsBackgroundImageKey] boolValue]))) {
        if ([_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && ![_userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath]) {
            if (![self addCopyDesktopPictureCustom:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing custom desktop picture failed"]
                                                                  }];
                return;
            }
        }
    }

    // --------------------------------------------------------------------------------
    // NBICreatorDesktopViewer.app
    // --------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsUseBackgroundImageKey] boolValue]))) {
        if ([_userSettings[NBCSettingsUseBackgroundImageKey] boolValue]) {
            if (![self addCopyDesktopViewer:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing NBICreatorDesktopViewer.app failed"]
                                                                  }];
                return;
            }
        }
    }

    if (_workflowType == kWorkflowTypeImagr) {

        // --------------------------------------------------------------------------------
        // Imagr.app
        // --------------------------------------------------------------------------------
        if (!_isNBI || (_isNBI && ([_settingsChanged[NBCSettingsImagrVersion] boolValue]))) {
            NBCWorkflowResourceImagr *workflowResourceImagr = [[NBCWorkflowResourceImagr alloc] initWithDelegate:self];
            [workflowResourceImagr setProgressDelegate:_delegate];
            [workflowResourceImagr addCopyImagr:_workflowItem];
        } else {
            [self prepareResourcesComplete];
        }
    } else if (_workflowType == kWorkflowTypeCasper) {

        // --------------------------------------------------------------------------------
        // Casper Imaging.app
        // --------------------------------------------------------------------------------
        if (![self addCopyCasperImaging:&error]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                object:self
                                                              userInfo:@{
                                                                  NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing Casper Imaging.app failed"]
                                                              }];
            return;
        }
        [self prepareResourcesToExtract];
    } else if (_workflowType == kWorkflowTypeDeployStudio) {

        // --------------------------------------------------------------------------------
        // DeployStudio Admin.app
        // --------------------------------------------------------------------------------
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            if (![self addCopyDeployStudioAdmin:&error]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                                    object:self
                                                                  userInfo:@{
                                                                      NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing DeployStudio Admin.app failed"]
                                                                  }];
                return;
            }
        }

        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self prepareResourcesToExtract];
        } else {
            [self prepareResourcesComplete];
        }
    } else {
        [self prepareResourcesToExtract];
    }
} // prepareResourcesToCopy

- (void)prepareResourcesToExtract {

    DDLogInfo(@"Preparing resources to extract...");

    NSMutableDictionary *sourceItemsDict = [[NSMutableDictionary alloc] init];

    // ---------------------------------------------------------------------------------
    //  AppleScript
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeCasper) {
        [self addExtractAppleScript:sourceItemsDict];
    }

    // ---------------------------------------------------------------------------------
    //  ARD
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsARDLoginKey] length] != 0 && [_userSettings[NBCSettingsARDPasswordKey] length] != 0) {
            [self addExtractARD:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  Casper Imaging
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeCasper) {
        [self addExtractCasperImaging:sourceItemsDict];
    }

    // ---------------------------------------------------------------------------------
    //  Console.app
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsIncludeConsoleAppKey] boolValue]) {
            [self addExtractConsole:sourceItemsDict];
        }
    }

    // ----------------------------------------------------------------
    //  Desktop Picture (Default)
    // ----------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [_userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath]) {
            [self addExtractDesktopPictureDefault:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------
    //  Kernel - Included if selections in UI requires regenerating kernel caches
    // ---------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsDisableWiFiKey] boolValue] || [_userSettings[NBCSettingsDisableBluetoothKey] boolValue]) {
            [self addExtractKernel:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  libssl
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if (11 <= _sourceVersionMinor) {
            [self addExtractLibSsl:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  networkd
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if (11 <= _sourceVersionMinor) {
            [self addExtractNetworkd:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  ntp
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue]) {
            [self addExtractNTP:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  NSURLStoraged / NSURLSessiond
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if (/* DISABLES CODE */ (NO)) {
            [self addExtractNSURLStoraged:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  Python
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsIncludePythonKey] boolValue] || _workflowType == kWorkflowTypeImagr) {
            [self addExtractPython:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  Ruby
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsIncludeRubyKey] boolValue]) {
            [self addExtractRuby:sourceItemsDict];
        }
    }

    // --------------------------------------------------------------------------------
    //  Screen Sharing
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsARDPasswordKey] length] != 0) {
            [self addExtractScreenSharing:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  spctl
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if (/* DISABLES CODE */ (NO)) {
            [self addExtractSpctl:sourceItemsDict];
        }
    }

    // ---------------------------------------------------------------------------------
    //  System Keychain
    // ---------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if ([_userSettings[NBCSettingsCertificatesKey] count] != 0) {
            [self addExtractSystemkeychain:sourceItemsDict];
        }
    }

    // --------------------------------------------------------------------------------
    //  SystemUIServer
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr) {
        if ([_userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue]) {
            [self addExtractSystemUIServer:sourceItemsDict];
        }
    }

    // --------------------------------------------------------------------------------
    // taskgated
    // --------------------------------------------------------------------------------
    if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
        if (/* DISABLES CODE */ (NO)) {
            [self addExtractTaskgated:sourceItemsDict];
        }
    }

    if ([sourceItemsDict count] != 0) {

        // -------------------------------------------------------------------------------------
        // Fonts and CTPresetFallbacks.plist (10.11+)
        // Only add if anything else was added for extraction
        // -------------------------------------------------------------------------------------
        if (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper) {
            if (11 <= _sourceVersionMinor) {
                [self addExtractFonts:sourceItemsDict];
            }
        }

        // --------------------------------------------------------------------------------
        // Extract added regexes from installer packages
        // --------------------------------------------------------------------------------
        NBCWorkflowResourcesExtract *workflowResourcesExtract = [[NBCWorkflowResourcesExtract alloc] initWithDelegate:self];
        [workflowResourcesExtract setProgressDelegate:_delegate];
        [workflowResourcesExtract extractResources:[sourceItemsDict copy] workflowItem:_workflowItem];
    } else {
        [self prepareResourcesComplete];
    }
} // prepareResourcesToExtract

- (NSArray *)prepareResourcesToUSBFromNBI:(NSURL *)nbiURL {

    [self setResourcesUSBCopy:[[NSMutableArray alloc] init]];

    NSError *error = nil;

    if (![self addCopyUSBResourcesFromNBI:nbiURL error:&error]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                            object:self
                                                          userInfo:@{
                                                              NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Preparing USB resources failed"]
                                                          }];
        return nil;
    }

    return [_resourcesUSBCopy copy];
}

- (void)prepareResourcesComplete {

    if ([_resourcesNetInstallCopy count] != 0 || [_resourcesNetInstallInstall count] != 0) {
        NSMutableDictionary *resourcesNetInstallDict = [[NSMutableDictionary alloc] init];
        resourcesNetInstallDict[NBCWorkflowCopy] = _resourcesNetInstallCopy ?: @{};
        DDLogDebug(@"[DEBUG] %lu resources added for copy to NetInstall volume", (unsigned long)[_resourcesNetInstallCopy count]);

        resourcesNetInstallDict[NBCWorkflowInstall] = _resourcesNetInstallInstall ?: @{};
        DDLogDebug(@"[DEBUG] %lu resources added for install to NetInstall volume", (unsigned long)[_resourcesNetInstallInstall count]);

        [[_workflowItem target] setResourcesNetInstallDict:resourcesNetInstallDict ?: @{}];
    } else {
        DDLogDebug(@"[DEBUG] No resources added for NetInstall volume");
    }

    if ([_resourcesBaseSystemCopy count] != 0 || [_resourcesBaseSystemInstall count] != 0) {
        NSMutableDictionary *resourcesBaseSystemDict = [[NSMutableDictionary alloc] init];
        resourcesBaseSystemDict[NBCWorkflowCopy] = _resourcesBaseSystemCopy ?: @{};
        DDLogDebug(@"[DEBUG] %lu resources added for copy to BaseSystem volume", (unsigned long)[_resourcesBaseSystemCopy count]);

        resourcesBaseSystemDict[NBCWorkflowInstall] = _resourcesBaseSystemInstall ?: @{};
        DDLogDebug(@"[DEBUG] %lu resources added for install to BaseSystem volume", (unsigned long)[_resourcesBaseSystemInstall count]);

        [[_workflowItem target] setResourcesBaseSystemDict:resourcesBaseSystemDict ?: @{}];
    } else {
        DDLogDebug(@"[DEBUG] No resources added for BaseSystem volume");
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowCompleteResources object:self userInfo:nil];
} // prepareResourcesComplete

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Install
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addItemToInstallToBaseSystem:(NSDictionary *)itemDict {
    [_resourcesBaseSystemInstall addObject:itemDict];
} // addItemToInstallToBaseSystem

- (void)addItemToInstallToNetInstall:(NSDictionary *)itemDict {
    [_resourcesNetInstallInstall addObject:itemDict];
} // addItemToInstallToNetInstall

- (BOOL)updateBaseSystemInstallerDict:(NSURL *)packageURL choiceChangesXML:(NSDictionary *)choiceChangesXML error:(NSError **)error {

    // ----------------------------------------------------------------------------------------------
    //  Create a dict for package with URL and optionally choiceChangesXML and add to resource dict
    // ----------------------------------------------------------------------------------------------
    NSString *packageName;
    NSMutableDictionary *packageDict = [[NSMutableDictionary alloc] init];
    if ([packageURL checkResourceIsReachableAndReturnError:error]) {
        packageName = [packageURL lastPathComponent];
        packageDict[NBCWorkflowInstallerName] = packageName;
        packageDict[NBCWorkflowInstallerSourceURL] = [packageURL path];
    } else {
        return NO;
    }

    if ([choiceChangesXML count] != 0) {
        packageDict[NBCWorkflowInstallerChoiceChangeXML] = choiceChangesXML;
    }

    if ([packageName length] != 0) {
        [_resourcesBaseSystemInstall addObject:packageDict];
        return YES;
    } else {
        *error = [NBCError errorWithDescription:@"Package name was empty!"];
        return NO;
    }
} // updateBaseSystemInstallerDict

- (BOOL)addInstallPackages:(NSArray *)packagesArray error:(NSError **)error {

    DDLogInfo(@"Adding %lu package(s) for installation...", (unsigned long)[packagesArray count]);

    NSURL *temporaryFolderURL = [_workflowItem temporaryFolderURL];
    NSURL *temporaryPackageFolderURL = [temporaryFolderURL URLByAppendingPathComponent:@"Packages"];
    if (![temporaryPackageFolderURL checkResourceIsReachableAndReturnError:nil]) {

        DDLogDebug(@"[DEBUG] Creating temporary packages folder...");
        if (![[NSFileManager defaultManager] createDirectoryAtURL:temporaryPackageFolderURL withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }

    for (NSString *packagePath in packagesArray) {
        DDLogDebug(@"[DEBUG] Copying package at path: %@", packagePath);

        NSURL *temporaryPackageURL = [temporaryPackageFolderURL URLByAppendingPathComponent:[packagePath lastPathComponent]];
        if ([[NSFileManager defaultManager] copyItemAtURL:[NSURL fileURLWithPath:packagePath] toURL:temporaryPackageURL error:error]) {
            if (![self updateBaseSystemInstallerDict:temporaryPackageURL choiceChangesXML:nil error:error]) {
                return NO;
            }
        } else {
            return NO;
        }
    }

    return YES;
} // addInstallPackages

- (BOOL)addInstallPackagesNetInstall:(NSArray *)packagesArray error:(NSError **)error {

    DDLogInfo(@"Adding %lu package(s) for NetInstall installation...", (unsigned long)[packagesArray count]);

    for (NSString *packagePath in packagesArray) {
        DDLogDebug(@"[DEBUG] NetInstall package path: %@", packagePath);

        if ([[NSURL fileURLWithPath:packagePath] checkResourceIsReachableAndReturnError:error]) {
            NSString *targetPackagePath = [NBCFolderPathNetInstallPackages stringByAppendingPathComponent:[packagePath lastPathComponent]];
            DDLogDebug(@"[DEBUG] NetInstall package target path: %@", targetPackagePath);

            [self addItemToCopyToNetInstall:@{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : packagePath,
                NBCWorkflowCopyTargetURL : targetPackagePath,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
            }];
        } else {
            return NO;
        }
    }

    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Copy
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addItemToCopyToBaseSystem:(NSDictionary *)itemDict {
    [_resourcesBaseSystemCopy addObject:itemDict];
} // addItemToCopyToBaseSystem

- (void)addItemToCopyToNetInstall:(NSDictionary *)itemDict {
    [_resourcesNetInstallCopy addObject:itemDict];
} // addItemToCopyToNetInstall

- (void)addItemToCopyToUSB:(NSDictionary *)itemDict {
    [_resourcesUSBCopy addObject:itemDict];
} // addItemToCopyToUSB

- (void)imagrCopyDict:(NSDictionary *)copyDict {
    DDLogDebug(@"[DEBUG] Imagr.app copy added!");
    if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
        [self addItemToCopyToBaseSystem:copyDict];
    } else {
        [self addItemToCopyToNetInstall:copyDict];
    }

    if (!_isNBI) {
        [self prepareResourcesToExtract];
    } else {
        [self prepareResourcesComplete];
    }
} // imagrCopyDict

- (void)imagrCopyError:(NSError *)error {
    DDLogError(@"[ERROR] Imagr.app copy failed!");
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{
                                                          NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Copying Imagr.app failed"]
                                                      }];
} // imagrCopyError

- (BOOL)addCopyCasperImaging:(NSError **)error {

    DDLogInfo(@"Adding Casper Imaging.app for copy...");

    NSURL *casperImagingURL = [NSURL fileURLWithPath:_userSettings[NBCSettingsCasperImagingPathKey] ?: @""];
    DDLogDebug(@"[DEBUG] Casper Imaging.app path: %@", [casperImagingURL path]);

    if ([casperImagingURL checkResourceIsReachableAndReturnError:error]) {
        NSString *casperImagingTargetPath;
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            casperImagingTargetPath = NBCCasperImagingApplicationNBICreatorTargetURL;
        } else {
            casperImagingTargetPath = NBCCasperImagingApplicationTargetURL;
        }
        DDLogDebug(@"[DEUBG] Casper Imaging.app target path component: %@", casperImagingTargetPath);

        NSDictionary *casperImagingCopyDict = @{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [casperImagingURL path],
            NBCWorkflowCopyTargetURL : casperImagingTargetPath,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        };

        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self addItemToCopyToBaseSystem:casperImagingCopyDict];
        } else {
            [self addItemToCopyToNetInstall:casperImagingCopyDict];
        }
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)addCopyCertificates:(NSArray *)certificatesArray error:(NSError **)error {

    DDLogInfo(@"Adding %lu certificate(s) for copy...", (unsigned long)[certificatesArray count]);

    NSURL *temporaryCertificateFolderURL = [[_workflowItem temporaryFolderURL] URLByAppendingPathComponent:@"Certificates"];
    DDLogDebug(@"[DEBUG] Certificates temporary folder path: %@", [temporaryCertificateFolderURL path]);

    if (![temporaryCertificateFolderURL checkResourceIsReachableAndReturnError:nil]) {

        DDLogDebug(@"[DEBUG] Creating temporary certificates folder...");
        if (![[NSFileManager defaultManager] createDirectoryAtURL:temporaryCertificateFolderURL withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }

    NSInteger index = 0;
    for (NSData *certificateData in certificatesArray) {
        NSString *temporaryCertificateName = [NSString stringWithFormat:@"certificate%ld.cer", (long)index];
        DDLogDebug(@"[DEBUG] Temporary certificate name: %@", temporaryCertificateName);

        NSURL *temporaryCertificateURL = [temporaryCertificateFolderURL URLByAppendingPathComponent:temporaryCertificateName];
        DDLogDebug(@"[DEBUG] Temporary certificate path: %@", [temporaryCertificateURL path]);
        if ([certificateData writeToURL:temporaryCertificateURL atomically:YES]) {

            NSString *certificateTargetPath;
            if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
                certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesNBICreatorTargetURL, temporaryCertificateName];
            } else {
                certificateTargetPath = [NSString stringWithFormat:@"%@/%@", NBCCertificatesTargetURL, temporaryCertificateName];
            }
            DDLogDebug(@"[DEBUG] Temporary certificate target path component: %@", certificateTargetPath);

            NSDictionary *certificateCopyDict = @{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : [temporaryCertificateURL path],
                NBCWorkflowCopyTargetURL : certificateTargetPath,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
            };

            if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
                [self addItemToCopyToBaseSystem:certificateCopyDict];
            } else {
                [self addItemToCopyToNetInstall:certificateCopyDict];
            }
        } else {
            *error = [NBCError errorWithDescription:@"Writing certificates to temporary folder failed"];
            return NO;
        }
        index++;
    }

    return YES;
} // addCopyCertificates

- (BOOL)addCopyCertificateScript:(NSError **)error {

    DDLogInfo(@"Adding installCertificates.bash for copy...");

    NSURL *certificateScriptURL = [[NSBundle mainBundle] URLForResource:@"installCertificates" withExtension:@"bash" subdirectory:@"Scripts"];
    DDLogDebug(@"[DEBUG] installCertificates.bash path: %@", [certificateScriptURL path]);

    if ([certificateScriptURL checkResourceIsReachableAndReturnError:error]) {
        NSString *certificateScriptTargetPath;
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsNBICreatorTargetPath, [certificateScriptURL lastPathComponent]];
        } else {
            certificateScriptTargetPath = [NSString stringWithFormat:@"%@/%@", NBCScriptsTargetPath, [certificateScriptURL lastPathComponent]];
        }
        DDLogDebug(@"[DEUBG] installCertificates.bash target path component: %@", certificateScriptTargetPath);

        NSDictionary *certificateScriptCopyDict = @{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [certificateScriptURL path],
            NBCWorkflowCopyTargetURL : certificateScriptTargetPath,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        };

        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            [self addItemToCopyToBaseSystem:certificateScriptCopyDict];
        } else {
            [self addItemToCopyToNetInstall:certificateScriptCopyDict];
        }

        return YES;
    } else {
        return NO;
    }
} // addCopyCertificateScript

- (BOOL)addCopyConfigurationProfilesNetInstall:(NSArray *)configurationProfilesArray error:(NSError **)error {

    DDLogInfo(@"Adding NetInstall configuration profiles for copy...");

    for (NSString *configurationProfilePath in configurationProfilesArray) {
        DDLogDebug(@"[DEBUG] Configuration profile path: %@", configurationProfilePath);

        if ([[NSURL fileURLWithPath:configurationProfilePath] checkResourceIsReachableAndReturnError:error]) {
            NSString *configurationProfileTargetPath = [NBCFolderPathNetInstallConfigurationProfiles stringByAppendingPathComponent:[configurationProfilePath lastPathComponent]];
            DDLogDebug(@"[DEBUG] Configuration profile target path: %@", configurationProfileTargetPath);

            [self addItemToCopyToNetInstall:@{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : configurationProfilePath,
                NBCWorkflowCopyTargetURL : configurationProfileTargetPath,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
            }];
        } else {
            return NO;
        }
    }

    NSURL *installConfigurationProfilesScriptURL = [[_workflowItem applicationSource] installConfigurationProfilesURL];
    DDLogDebug(@"[DEBUG] installConfigurationProfiles.sh path: %@", [installConfigurationProfilesScriptURL path]);

    if ([installConfigurationProfilesScriptURL checkResourceIsReachableAndReturnError:error]) {
        NSString *installConfigurationProfilesScriptTargetPath = NBCFilePathNetInstallInstallConfigurationProfiles;
        DDLogDebug(@"[DEBUG] installConfigurationProfiles.sh target path: %@", installConfigurationProfilesScriptTargetPath);

        [self addItemToCopyToNetInstall:@{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [installConfigurationProfilesScriptURL path],
            NBCWorkflowCopyTargetURL : installConfigurationProfilesScriptTargetPath,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }];

        return YES;
    } else {
        return NO;
    }
} // addCopyConfigurationProfilesNetInstall

- (BOOL)addCopyDeployStudioAdmin:(NSError **)error {

    DDLogInfo(@"Adding DeployStudio Admin.app for copy...");

    // ------------------------------------------------------
    //  Determine source URL
    // ------------------------------------------------------
    NSURL *deployStudioAdminSourceURL = [[_workflowItem applicationSource] dsAdminURL];
    if ([deployStudioAdminSourceURL checkResourceIsReachableAndReturnError:error]) {

        // ------------------------------------------------------
        //  Add item to copy
        // ------------------------------------------------------
        [self addItemToCopyToBaseSystem:@{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [deployStudioAdminSourceURL path],
            NBCWorkflowCopyTargetURL : @"/Applications/Utilities/DeployStudio Admin.app",
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }];
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)addCopyDesktopPictureCustom:(NSError **)error {

    DDLogInfo(@"Adding custom desktop picture for copy...");

    NSString *desktopPicturePath = _userSettings[NBCSettingsBackgroundImageKey];
    DDLogDebug(@"[DEBUG] Custom desktop picture path: %@", desktopPicturePath);

    if ([desktopPicturePath length] != 0) {
        NSURL *desktopPictureURL = [NSURL fileURLWithPath:desktopPicturePath];
        NSURL *temporaryDesktopPictureURL = [[_workflowItem temporaryFolderURL] URLByAppendingPathComponent:[desktopPictureURL lastPathComponent]];
        DDLogDebug(@"[DEBUG] Custom desktop picture temporary path: %@", [temporaryDesktopPictureURL path]);

        DDLogDebug(@"[DEBUG] Copying custom desktop picture to temporary folder...");
        if ([[NSFileManager defaultManager] copyItemAtURL:desktopPictureURL toURL:temporaryDesktopPictureURL error:error]) {

            NSString *desktopPictureTargetPath;
            if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
                desktopPictureTargetPath = @"Library/Application Support/NBICreator/Background.jpg";
            } else {
                desktopPictureTargetPath = @"Packages/Background.jpg";
            }
            DDLogDebug(@"[DEBUG] Custom desktop picture target path component: %@", desktopPictureTargetPath);

            NSDictionary *desktopPictureCopyDict = @{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : [temporaryDesktopPictureURL path],
                NBCWorkflowCopyTargetURL : desktopPictureTargetPath,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
            };

            if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
                [self addItemToCopyToBaseSystem:desktopPictureCopyDict];
            } else {
                [self addItemToCopyToNetInstall:desktopPictureCopyDict];
            }

            return YES;
        } else {
            return NO;
        }
    } else {
        *error = [NBCError errorWithDescription:@"Background image path was empty"];
        return NO;
    }
} // addCopyDesktopPictureCustom

- (BOOL)addCopyDesktopViewer:(NSError **)error {

    DDLogInfo(@"Adding NBICreatorDesktopViewer.app for copy...");

    NSURL *desktopViewerURL = [[NSBundle mainBundle] URLForResource:@"NBICreatorDesktopViewer" withExtension:@"app"];
    DDLogDebug(@"[DEBUG] NBICreatorDesktopViewer.app path: %@", [desktopViewerURL path]);

    if ([desktopViewerURL checkResourceIsReachableAndReturnError:error]) {
        NSString *desktopViewerTargetPath = [NSString stringWithFormat:@"%@/NBICreatorDesktopViewer.app", NBCApplicationsTargetPath];
        DDLogDebug(@"[DEBUG] NBICreatorDesktopViewer.app target path: %@", desktopViewerTargetPath);

        // Update copy array
        [self addItemToCopyToBaseSystem:@{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [desktopViewerURL path],
            NBCWorkflowCopyTargetURL : desktopViewerTargetPath,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }];
        return YES;
    } else {
        return NO;
    }
} // addCopyDesktopViewer

- (BOOL)addCopyUSBResourcesFromNBI:(NSURL *)nbiURL error:(NSError **)error {

    DDLogInfo(@"Adding USB resources for copy...");

    NSString *netInstallRootPath = [NSDictionary dictionaryWithContentsOfURL:[nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"]][@"RootPath"] ?: @"";
    DDLogDebug(@"[DEBUG] NBImageInfo RootPath: %@", netInstallRootPath);
    if ([netInstallRootPath length] == 0) {
        *error = [NBCError errorWithDescription:@"Could not get the root path from NBImageInfo.plist"];
        return NO;
    }

    NSString *netInstallDMGPath = [[[nbiURL URLByAppendingPathComponent:netInstallRootPath] path] stringByResolvingSymlinksInPath];
    DDLogDebug(@"[DEBUG] NetInstall DMG path: %@", netInstallDMGPath);
    NSURL *netInstallDMGURL = [NSURL fileURLWithPath:netInstallDMGPath];
    if (![netInstallDMGURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : netInstallDMGPath,
        NBCWorkflowCopyTargetURL : [netInstallDMGPath lastPathComponent],
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSURL *platformSupportURL = [nbiURL URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
    if (![platformSupportURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    NSString *platformSupportTargetPathBootFiles = @".NBIBootFiles/PlatformSupport.plist";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [platformSupportURL path],
        NBCWorkflowCopyTargetURL : platformSupportTargetPathBootFiles,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSString *platformSupportTargetPath = @"System/Library/CoreServices/PlatformSupport.plist";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [platformSupportURL path],
        NBCWorkflowCopyTargetURL : platformSupportTargetPath,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSURL *comAppleBootPlistURL = [nbiURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    if ([comAppleBootPlistURL checkResourceIsReachableAndReturnError:error]) {

        NSString *comAppleBootPlistTargetPath = @".NBIBootFiles/com.apple.Boot.plist";

        // Update copy array
        [self addItemToCopyToUSB:@{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [comAppleBootPlistURL path],
            NBCWorkflowCopyTargetURL : comAppleBootPlistTargetPath,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }];
    }

    NSURL *prelinkedKernelURL = [nbiURL URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
    if (![prelinkedKernelURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    NSString *prelinkedKernelTargetPathBootFiles = @".NBIBootFiles/prelinkedkernel";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [prelinkedKernelURL path],
        NBCWorkflowCopyTargetURL : prelinkedKernelTargetPathBootFiles,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSString *prelinkedKernelTargetPath = @"System/Library/Caches/com.apple.kext.caches/Startup/prelinkedkernel";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [prelinkedKernelURL path],
        NBCWorkflowCopyTargetURL : prelinkedKernelTargetPath,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSURL *bootEfiURL = [nbiURL URLByAppendingPathComponent:@"i386/booter"];
    if (![bootEfiURL checkResourceIsReachableAndReturnError:error]) {
        return NO;
    }

    NSString *bootEfiTargetPathBootFiles = @".NBIBootFiles/boot.efi";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [bootEfiURL path],
        NBCWorkflowCopyTargetURL : bootEfiTargetPathBootFiles,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSString *bootEfiTargetPathStandalone = @"usr/standalone/i386/boot.efi";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [bootEfiURL path],
        NBCWorkflowCopyTargetURL : bootEfiTargetPathStandalone,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    NSString *bootEfiTargetPath = @"System/Library/CoreServices/boot.efi";

    // Update copy array
    [self addItemToCopyToUSB:@{
        NBCWorkflowCopyType : NBCWorkflowCopy,
        NBCWorkflowCopySourceURL : [bootEfiURL path],
        NBCWorkflowCopyTargetURL : bootEfiTargetPath,
        NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }];

    return YES;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Extract
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addItemsToExtractFromEssentials:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageEssentialsRegexes addObjectsFromArray:itemsArray];
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
} // addItemsToExtractFromEssentials

- (void)addItemsToExtractFromAdditionalEssentials:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if (11 <= _sourceVersionMinor) {
        [self addItemsToExtractFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }

    NSString *packageAdditionalEssentialsPath = [NSString stringWithFormat:@"%@/Packages/AdditionalEssentials.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageAdditionalEssentialsDict = [sourceItemsDict[packageAdditionalEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageAdditionalEssentialsRegexes = [packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageAdditionalEssentialsRegexes addObjectsFromArray:itemsArray];
    packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageAdditionalEssentialsRegexes;
    sourceItemsDict[packageAdditionalEssentialsPath] = packageAdditionalEssentialsDict;
} // addItemsToExtractFromAdditionalEssentials

- (void)addItemsToExtractFromBSD:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if (11 <= _sourceVersionMinor) {
        [self addItemsToExtractFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }

    NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageBSDDict = [sourceItemsDict[packageBSDPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageBSDRegexes = [packageBSDDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageBSDRegexes addObjectsFromArray:itemsArray];
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
} // addItemsToExtractFromBSD

- (void)addItemsToExtractFromBaseSystemBinaries:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if (11 <= _sourceVersionMinor) {
        [self addItemsToExtractFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }

    NSString *baseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *baseSystemBinariesDict = [sourceItemsDict[baseSystemBinariesPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *baseSystemBinariesRegexes = [baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [baseSystemBinariesRegexes addObjectsFromArray:itemsArray];
    baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] = baseSystemBinariesRegexes;
    sourceItemsDict[baseSystemBinariesPath] = baseSystemBinariesDict;
} // addItemsToExtractFromBaseSystemBinaries

- (void)addItemsToExtractFromMediaFiles:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if (11 <= _sourceVersionMinor) {
        [self addItemsToExtractFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }

    NSString *mediaFilesPath = [NSString stringWithFormat:@"%@/Packages/MediaFiles.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *mediaFilesDict = [sourceItemsDict[mediaFilesPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *mediaFilesRegexes = [mediaFilesDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [mediaFilesRegexes addObjectsFromArray:itemsArray];
    mediaFilesDict[NBCSettingsSourceItemsRegexKey] = mediaFilesRegexes;
    sourceItemsDict[mediaFilesPath] = mediaFilesDict;
} // addItemsToExtractFromMediaFiles

- (void)resourceExtractionComplete:(NSArray *)resourcesToCopy {
    int extractedResourcesCount = (int)[resourcesToCopy count];
    DDLogDebug(@"[DEBUG] Resurce extraction complete, adding %d regex items to copy", extractedResourcesCount);

    if (extractedResourcesCount != 0) {
        [_resourcesBaseSystemCopy addObjectsFromArray:resourcesToCopy];
    }

    [self prepareResourcesComplete];
} // resourceExtractionComplete

- (void)resourceExtractionFailed {
    DDLogError(@"resourceExtractionFailed");
} // resourceExtractionFailed

- (void)addExtractAppleScript:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract AppleScript...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
        @".*/[Aa]pple[Ss]cript.*",
        @".*appleevents.*",
        @".*/sdef.dtd.*",
        @".*ScriptingAdditions.*",
        @".*/[Ss]ystem\\ [Ee]vents.*",
        @".*/Automator.framework.*", // For System Events.app
        @".*/OSAKit.framework.*",    // For System Events.app
        @".*/ScriptingBridge.framework.*"
    ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*/osascript.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addAppleScript

- (void)addExtractARD:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract ARD...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*/ARDAgent.app.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addARD

- (void)addExtractCasperImaging:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Casper Imaging dependencies...");

    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];

    // ---------------------------------------------------------------------------------
    //  ~/Library/Application Support
    // ---------------------------------------------------------------------------------
    NSURL *userApplicationSupportURL = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if (![userApplicationSupportURL checkResourceIsReachableAndReturnError:&error]) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }

    // ---------------------------------------------------------------------------------
    //  Path to CasperImaging.plist
    // ---------------------------------------------------------------------------------
    NSString *casperImagingDependenciesPathComponent = [NSString stringWithFormat:@"%@/CasperImaging.plist", NBCFolderResourcesDependencies];
    NSURL *casperImagingDependenciesURL = [userApplicationSupportURL URLByAppendingPathComponent:casperImagingDependenciesPathComponent isDirectory:YES];
    if (![casperImagingDependenciesURL checkResourceIsReachableAndReturnError:nil]) {
        DDLogError(@"[ERROR] Could not find a downloaded resource file!");
        casperImagingDependenciesURL = [[NSBundle mainBundle] URLForResource:@"CasperImaging" withExtension:@"plist"];
    }
    DDLogDebug(@"[DEBUG] CasperImaging.plist path: %@", [casperImagingDependenciesURL path]);

    // ---------------------------------------------------------------------------------
    //  Read regexes from resources dict
    // ---------------------------------------------------------------------------------
    NSString *sourceOSVersion = [_source expandVariables:@"%OSVERSION%"];
    NSDictionary *buildDict;
    if ([casperImagingDependenciesURL checkResourceIsReachableAndReturnError:&error]) {

        NSDictionary *casperImagingDependenciesDict = [NSDictionary dictionaryWithContentsOfURL:casperImagingDependenciesURL];
        if ([casperImagingDependenciesDict count] != 0) {

            NSDictionary *sourceDict = casperImagingDependenciesDict[sourceOSVersion];
            if ([sourceDict count] != 0) {

                NSArray *sourceBuilds = [sourceDict allKeys];
                if ([sourceBuilds containsObject:_sourceOSBuild]) {
                    buildDict = sourceDict[_sourceOSBuild];
                } else {
                    DDLogError(@"[ERROR] No extrations found for current os build: %@", _sourceOSBuild);
                }
            } else {
                DDLogError(@"[ERROR] No extrations found for current os version: %@", sourceOSVersion);
            }
        } else {
            DDLogError(@"[ERROR] CasperImaging.plist was empty");
        }
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:buildDict[@"Essentials"]];

    if (11 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[
            @".*/lib/libenergytrace.dylib.*",        // For 'IOKit'
            @".*/Frameworks/Metal.framework.*",      // For 'CoreGraphics'
            @".*/Libraries/libCoreFSCache.dylib.*",  // For 'Metal'
            @".*/lib/libmarisa.dylib.*",             // For 'libmecabra'
            @".*/lib/libChineseTokenizer.dylib.*",   // For 'libmecabra'
            @".*/lib/libFosl_dynamic.dylib.*",       // For 'CoreImage'
            @".*/Libraries/libCoreVMClient.dylib.*", // For 'libCVMSPluginSupport'
            @".*/lib/libScreenReader.dylib.*",       // For 'AppKit'
            @".*/lib/libcompression.dylib.*",        // For 'DiskImages/CoreData'
            @".*/Libraries/libcldcpuengine.dylib.*",

            /* -- BELOW ARE TESTING ONLY -- */
            @".*/Kernels/kernel.*",
            // warning, could not bind /Volumes/dmg.Zn4BY5/usr/lib/libUniversalAccess.dylib because realpath() failed on
            // /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Libraries/libUAPreferences.dylib
            @".*/PrivateFrameworks/UniversalAccess.framework.*",
            // warning, could not bind /Volumes/dmg.Zn4BY5/System/Library/Frameworks/Automator.framework/Versions/A/Automator because realpath() failed on
            // /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/XprotectFramework.framework/Versions/A/XprotectFramework
            @".*/PrivateFrameworks/XprotectFramework.framework.*",
            // warning, could not bind /System/Library/Frameworks/MultipeerConnectivity.framework/Versions/A/MultipeerConnectivity because realpath() failed on
            // /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace
            @".*/PrivateFrameworks/AVConference.framework.*",
            // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace because realpath() failed
            // on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
            @".*/PrivateFrameworks/Marco.framework.*",
            // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/VideoProcessing
            @".*/PrivateFrameworks/VideoProcessing.framework.*",
            // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices
            @".*/PrivateFrameworks/FTServices.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
            @".*/PrivateFrameworks/FTAWD.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore
            @".*/PrivateFrameworks/IMCore.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoConference.framework/Versions/A/VideoConference
            @".*/PrivateFrameworks/VideoConference.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/IMTranscoding.framework/Versions/A/IMTranscoding because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation
            @".*/PrivateFrameworks/IMFoundation.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/WebKit2
            @".*/PrivateFrameworks/WebKit2.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/CoreRecognition.framework/Versions/A/CoreRecognition
            @".*/PrivateFrameworks/CoreRecognition.framework.*",
            // warning, could not bind /System/Library/PrivateFrameworks/Shortcut.framework/Versions/A/Shortcut because realpath() failed on
            // /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/HelpData.framework/Versions/A/HelpData
            @".*/PrivateFrameworks/HelpData.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices because realpath() failed on
            // /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDSFoundation.framework/Versions/A/IDSFoundation
            @".*/PrivateFrameworks/IDSFoundation.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco because realpath() failed on
            // /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/DiagnosticLogCollection.framework/Versions/A/DiagnosticLogCollection
            @".*/PrivateFrameworks/DiagnosticLogCollection.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on
            // /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDS.framework/Versions/A/IDS
            @".*/PrivateFrameworks/IDS.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on
            // /Volumes/dmg.vBWxTy/System/Library/Frameworks/InstantMessage.framework/Versions/A/InstantMessage
            @".*/Frameworks/InstantMessage.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/usr/lib/libtidy.A.dylib is
            // missing arch i386
            @".*/lib/libtidy.A.dylib.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because
            // /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/CommonUtilities.framework/Versions/A/CommonUtilities is missing arch i386
            @".*/PrivateFrameworks/CommonUtilities.framework.*",
            // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because
            // /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom is missing arch i386
            @".*/PrivateFrameworks/Bom.framework.*",
            // update_dyld_shared_cache: warning can't use root '/System/Library/CoreServices/FolderActionsDispatcher.app/Contents/MacOS/FolderActionsDispatcher': file not found
            @".*/FolderActionsDispatcher.app.*",
            // update_dyld_shared_cache: warning can't use root '/System/Library/Image Capture/Support/icdd': file not found
            @".*/Support/icdd.*",
            // update_dyld_shared_cache: warning can't use root '/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/Support/suggestd': file not found
            @".*/PrivateFrameworks/CoreSuggestions.framework.*",
            // update_dyld_shared_cache: warning can't use root '/usr/libexec/symptomsd': file not found
            @".*/libexec/symptomsd.*",
            // update_dyld_shared_cache: warning can't use root '/usr/libexec/systemstats_boot': file not found
            @".*/libexec/systemstats_boot.*",
            // warning, could not bind /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom because
            // /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/AppleFSCompression.framework/Versions/A/AppleFSCompression is missing arch i386
            @".*/PrivateFrameworks/AppleFSCompression.framework.*",
            // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on
            // /Volumes/dmg.IuuO1f/System/Library/Frameworks/Contacts.framework/Versions/A/Contacts
            @".*/Frameworks/Contacts.framework.*",
            // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on
            // /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSpotlight.framework/Versions/A/CoreSpotlight
            @".*/PrivateFrameworks/CoreSpotlight.framework.*",
            // update_dyld_shared_cache failed: could not bind symbol _FZAVErrorDomain in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore expected in
            // /System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore
            @".*/PrivateFrameworks/IMAVCore.framework.*",
            @".*/Resources/GLEngine.bundle.*",
            @".*/Resources/GLRendererFloat.bundle.*",
            @".*/PrivateFrameworks/GPUCompiler.framework.*",
            @".*/PrivateFrameworks/GeForceGLDriver.bundle.*"
        ]];
    }

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BaseSystemBinaries.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *baseSystemBinaries = [NSMutableArray arrayWithArray:buildDict[@"BaseSystemBinaries"]];

    // Update extraction array
    [self addItemsToExtractFromBaseSystemBinaries:baseSystemBinaries sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*/bin/expect.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addCasperImaging

- (void)addExtractConsole:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Console...");

    // ---------------------------------------------------------------------------------
    //  AdditionalEssentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *additionalEssentials = [NSMutableArray arrayWithArray:@[
        @".*Console.app.*",
    ]];

    // Update extraction array
    [self addItemsToExtractFromAdditionalEssentials:additionalEssentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray
        arrayWithArray:@[ @".*ShareKit.framework.*", @".*/Colors/System.clr.*", @".*ViewBridge.framework.*", @".*/Social.framework.*", @".*AccountsDaemon.framework.*", @".*CloudDocs.framework.*" ]];

    if (11 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[
            @".*AccountsUI.framework.*",         // For 'ShareKit'
            @".*ContactsPersistence.framework.*" // For 'AddressBook'
        ]];
    }

    if (12 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[ @".*ConsoleKit.framework.*" ]];
        [essentials addObjectsFromArray:@[ @".*LoggingSupport.framework.*" ]];
        [essentials addObjectsFromArray:@[ @".*usr/bin/log" ]];
        
        // This is for Quartz.framework, unsure if all are really needed:
        //[essentials addObjectsFromArray:@[ @".*/Quartz.framework.*" ]];
        
        //[essentials addObjectsFromArray:@[ @".*/CoreAVCHD.framework/Versions/A/CoreAVCHD.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/CoreWiFi.framework/Versions/A/CoreWiFi.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/FaceCore.framework/Versions/A/FaceCore.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/GPUCompiler.framework/libmetal_timestamp.dylib.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/IntlPreferences.framework/Versions/A/IntlPreferences.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/Mangrove.framework/Versions/A/Mangrove.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/MetalPerformanceShaders.framework/Versions/A/MetalPerformanceShaders.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/MobileKeyBag.framework/Versions/A/MobileKeyBag.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/QuickLookThumbnailing.framework/Versions/A/QuickLookThumbnailing.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/SpeechRecognitionCore.framework/Versions/A/SpeechRecognitionCore.*" ]];
        //[essentials addObjectsFromArray:@[ @".*/libOpenScriptingUtil.dylib.*" ]];
    }

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addConsole

- (void)addExtractFonts:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Fonts...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*CoreText.framework.*CTPresetFallbacks.plist", @".*Fonts.*NotoSans.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addExtractCTPresetFallbacks

- (void)addExtractDesktopPictureDefault:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Desktop Picture...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    if (11 <= _sourceVersionMinor) {
        NSArray *essentials;
        switch (_sourceVersionMinor) {
        case 11:
            essentials = @[ @".*Library/Desktop\\ Pictures/El\\ Capitan.jpg.*" ];
            break;
        default:
            break;
        }

        if ([essentials count] != 0) {

            // Update extraction array
            [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
        }

        // ---------------------------------------------------------------------------------
        //  MediaFiles.pkg
        // ---------------------------------------------------------------------------------
    } else {

        NSArray *mediaFiles;
        switch (_sourceVersionMinor) {
        case 10:
            mediaFiles = @[ @".*Library/Desktop\\ Pictures/Yosemite.jpg.*" ];
            break;
        case 9:
            mediaFiles = @[ @".*Library/Desktop\\ Pictures/Wave.jpg.*" ];
            break;
        case 8:
            mediaFiles = @[ @".*Library/Desktop\\ Pictures/Galaxy.jpg.*" ];
            break;
        case 7:
            mediaFiles = @[ @".*Library/Desktop\\ Pictures/Lion.jpg.*" ];
            break;
        default:
            break;
        }

        if ([mediaFiles count] != 0) {

            // Update extraction array
            [self addItemsToExtractFromMediaFiles:mediaFiles sourceItemsDict:sourceItemsDict];
        }
    }
} // addDesktopPictureDefault

- (void)addExtractKerberos:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Kerberos...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
        @".*/users/_krb.*",
        @".*/LaunchDaemons/com.apple.Kerberos.*",
        @".*Kerberos.*\\.bundle.*",
        @".*/ManagedClient.app.*",
        @".*/DirectoryServer.framework.*",
        @".*/com.apple.configureLocalKDC.*",
        @".*/lkdc_acl.*"
    ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*bin/krb.*", @".*/libexec/.*KDC.*", @".*sbin/kdcsetup.*", @".*sandbox/kdc.sb.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addKerberos

- (void)addExtractKernel:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Kernel...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*/Kernels/.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addKernel

- (void)addExtractLibSsl:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract libssl...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*/lib/libssl.*", @".*/lib/libcrypto.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addLibSsl

- (void)addExtractNetworkd:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract networkd...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*(/|com.apple.)networkd.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addNetworkd

- (void)addExtractNTP:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract ntpdate...");

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*/sbin/ntpdate.*" ]];

    if (11 <= _sourceVersionMinor) {
        [bsd addObjectsFromArray:@[ @".*/sntp-wrapper.*" ]];
    }

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addNTP

- (void)addExtractNSURLStoraged:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract nsurlstoraged/nsurlsessiond...");

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*nsurlstoraged.*", @".*nsurlsessiond.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------

    // Update extraction array
    [self addItemsToExtractFromEssentials:bsd sourceItemsDict:sourceItemsDict];
} // addNSURLStoraged

- (void)addExtractPython:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Python...");

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*/[Pp]ython.*" ]];

    if (12 <= _sourceVersionMinor) {
        [bsd addObjectsFromArray:@[ @".*/usr/lib/libffi.dylib.*", @".*/usr/lib/libexpat.1.dylib.*" ]];
    }

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addPython

- (void)addExtractRuby:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Ruby...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*[Rr]uby.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------

    // Update extraction array
    [self addItemsToExtractFromBSD:essentials sourceItemsDict:sourceItemsDict];
} // addRuby

- (void)addExtractScreenSharing:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract Screen Sharing...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
        @".*/[Pp]erl.*",
        @".*/Preferences/com.apple.RemoteManagement.*",
        @".*/Launch(Agents|Daemons)/com.apple.screensharing.*",
        @".*/Launch(Agents|Daemons)/com.apple.RemoteDesktop.*",
        @".*/ScreensharingAgent.bundle.*",
        @".*/screensharingd.bundle.*",
        @".*[Oo]pen[Dd]irectory.*",
        @".*OpenDirectoryConfig.framework.*"
    ]];

    if (11 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[ @".*/AppleVNCServer.bundle.*" ]];
    }

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addScreenSharing

- (void)addExtractSpctl:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract spctl...");

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*spctl.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addSpctl

- (void)addExtractSystemkeychain:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract systemkeychain...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[ @".*systemkeychain.*" ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*security-checksystem.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addSystemkeychain

- (void)addExtractSystemUIServer:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract SystemUIServer...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
        @".*SystemUIServer.*",
        @".*MediaControlSender.framework.*",
        @".*SystemUIPlugin.framework.*",
        @".*ICANotifications.framework.*",
        @".*iPod.framework.*",
        @".*AirPlaySupport.framework.*",
        @".*CoreUtils.framework.*",
        @".*TextInput.menu.*",
        @".*Battery.menu.*",
        @".*Clock.menu.*"
    ]];

    if (11 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[ @".*AVFoundation.framework.*", @".*APTransport.framework.*", @".*WirelessProximity.framework.*" ]];
    }

    if (12 <= _sourceVersionMinor) {
        [essentials addObjectsFromArray:@[ @".*WirelessDiagnostics.framework.*", @".*libTelephonyUtilDynamic.dylib.*", @".*BatteryUIKit.framework.*" ]];
        
        if (1 <= _sourceVersionPatch) {
            [essentials addObjectsFromArray:@[ @".*ImageKit.framework.*", @".*PDFKit.framework.*", @".*QuicklookUI.framework.*" ]];
        }
    }

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addSystemUIServer

- (void)addExtractTaskgated:(NSMutableDictionary *)sourceItemsDict {

    DDLogInfo(@"Adding regexes to extract taskgated...");

    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
        @".*taskgated.*",

        // For taskgated-helper
        @".*ConfigurationProfiles.framework.*",
        @".*UniversalAccess.framework.*",
        @".*ManagedClient.*",
        @".*syspolicy.*",

        // For CoreServicesUIAgent
        @".*CoreServicesUIAgent.*",
        @".*coreservices.uiagent.plist.*",
        @".*XprotectFramework.framework.*",

        // For Kernel
        @".*MobileFileIntegrity.plist*"
    ]];

    // Update extraction array
    [self addItemsToExtractFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[ @".*amfid.*", @".*syspolicy.*", @".*taskgated.*" ]];

    // Update extraction array
    [self addItemsToExtractFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addTaskgated

@end
