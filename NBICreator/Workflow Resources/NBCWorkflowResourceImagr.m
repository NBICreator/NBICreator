//
//  NBCWorkflowResourceImagr.m
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
#import "NBCDownloader.h"
#import "NBCError.h"
#import "NBCLogging.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowResourceImagr.h"

@implementation NBCWorkflowResourceImagr

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithDelegate:(id<NBCWorkflowResourceImagrDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
#pragma unused(url)
    // ------------------------------------------------------
    //  Extract info from downloadInfo Dict
    // ------------------------------------------------------
    NSString *resourceTag = downloadInfo[NBCDownloaderTag];

    // ------------------------------------------------------
    //  Send command to correct copy method based on tag
    // ------------------------------------------------------
    if ([resourceTag isEqualToString:NBCDownloaderTagImagr]) {
        NSString *version = downloadInfo[NBCDownloaderVersion];
        [self addDownloadedImagrToResources:url version:version];
    } else if ([resourceTag isEqualToString:NBCDownloaderTagImagrBranch]) {
        NSDictionary *branchDict = downloadInfo[NBCSettingsImagrGitBranchDict];
        [self addDownloadedImagrBranchToResources:url branchDict:branchDict];
    }
} // fileDownloadCompleted:downloadInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCWorkflowResourcesControllerDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)xcodeBuildComplete:(NSURL *)productURL {

    DDLogInfo(@"Imagr.app build completed!");

    DDLogDebug(@"[DEBUG] Imagr.app build path: %@", [productURL path]);

    NSError *error;
    if ([productURL checkResourceIsReachableAndReturnError:&error]) {
        NSDictionary *imagrBuildDict = @{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [productURL path],
            NBCWorkflowCopyTargetURL : _imagrTargetPathComponent,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        };

        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyDict:)]) {
            [_delegate imagrCopyDict:imagrBuildDict];
        }
    } else {
        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
            [_delegate imagrCopyError:[NBCError errorWithDescription:[error localizedDescription]]];
        }
    }
}

- (void)xcodeBuildFailed:(NSString *)errorOutput {
    DDLogError(@"[ERROR] Imagr.app build failed!");
    if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
        [_delegate imagrCopyError:[NBCError errorWithDescription:errorOutput]];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Add Imagr
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addCopyImagr:(NBCWorkflowItem *)workflowItem {

    DDLogInfo(@"Adding Imagr.app for copy...");

    [self setCreationTool:[workflowItem userSettings][NBCSettingsNBICreationToolKey]];

    if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
        _imagrTargetPathComponent = NBCImagrApplicationNBICreatorTargetURL;
    } else {
        _imagrTargetPathComponent = NBCImagrApplicationTargetURL;
    }
    DDLogDebug(@"[DEBUG] Imagr.app target path component: %@", _imagrTargetPathComponent);

    NSString *selectedImagrVersion = [workflowItem userSettings][NBCSettingsImagrVersion];
    DDLogDebug(@"[DEBUG] Selected Imagr version: %@", selectedImagrVersion);

    if ([selectedImagrVersion length] == 0) {
        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
            [_delegate imagrCopyError:[NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown Imagr.app version: %@", selectedImagrVersion]]];
        }
        return;
    } else if ([selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLocal]) {
        NSURL *imagrLocalURL = [NSURL fileURLWithPath:[workflowItem userSettings][NBCSettingsImagrLocalVersionPath] ?: @""];
        DDLogDebug(@"[DEBUG] Imagr.app local path: %@", [imagrLocalURL path]);

        if ([imagrLocalURL path] != 0) {
            NSDictionary *imagrLocalCopyDict = @{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : [imagrLocalURL path],
                NBCWorkflowCopyTargetURL : _imagrTargetPathComponent,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
            };

            if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyDict:)]) {
                [_delegate imagrCopyDict:imagrLocalCopyDict];
            }
        } else {
            if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
                [_delegate imagrCopyError:[NBCError errorWithDescription:@"Local path to Imagr.app was empty"]];
            }
            return;
        }
    } else if ([selectedImagrVersion isEqualToString:NBCMenuItemGitBranch]) {

        NSDictionary *resourcesSettings = [workflowItem resourcesSettings];

        NSString *branch = resourcesSettings[NBCSettingsImagrGitBranch];
        DDLogDebug(@"[DEBUG] Selected Imagr git branch: %@", branch);

        NSString *sha = resourcesSettings[NBCSettingsImagrGitBranchSHA];
        DDLogDebug(@"[DEBUG] Selected Imagr git branch SHA: %@", sha);

        NSString *buildTarget = resourcesSettings[NBCSettingsImagrBuildTarget];
        DDLogDebug(@"[DEBUG] Selected Imagr git branch build target: %@", buildTarget);

        NSURL *imagrBranchCachedVersionURL = [NBCWorkflowResourcesController cachedBranchURL:branch sha:sha resourcesFolder:NBCFolderResourcesCacheImagr];
        if ([imagrBranchCachedVersionURL checkResourceIsReachableAndReturnError:nil]) {
            DDLogDebug(@"[DEBUG] Cached download of selected branch exists at: %@", [imagrBranchCachedVersionURL path]);

            NSURL *targetImagrAppURL = [imagrBranchCachedVersionURL URLByAppendingPathComponent:[NSString stringWithFormat:@"build/%@/Imagr.app", buildTarget]];
            DDLogDebug(@"[DEBUG] Cached build of selected branch/target path: %@", [targetImagrAppURL path]);

            if ([targetImagrAppURL checkResourceIsReachableAndReturnError:nil]) {
                NSDictionary *imagrBuildCopyDict = @{
                    NBCWorkflowCopyType : NBCWorkflowCopy,
                    NBCWorkflowCopySourceURL : [targetImagrAppURL path],
                    NBCWorkflowCopyTargetURL : _imagrTargetPathComponent,
                    NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
                };

                if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyDict:)]) {
                    [_delegate imagrCopyDict:imagrBuildCopyDict];
                }
            } else {
                DDLogDebug(@"[DEBUG] No cached build of selected branch/target exists");

                if (_progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)]) {
                    [_progressDelegate updateProgressStatus:@"Building Imagr.app..."];
                }

                NBCWorkflowResourcesController *resourceController = [[NBCWorkflowResourcesController alloc] initWithDelegate:self];
                [resourceController buildProjectAtURL:imagrBranchCachedVersionURL buildTarget:buildTarget];
            }
        } else {
            DDLogDebug(@"[DEBUG] No cached download of selected branch exists");

            NSString *imagrDownloadURL = resourcesSettings[NBCSettingsImagrDownloadURL];
            DDLogDebug(@"[DEBUG] Selected Imagr branch download URL: %@", imagrDownloadURL);

            if ([imagrDownloadURL length] != 0) {
                DDLogInfo(@"Downloading Imagr git branch %@...", branch);
                if (_progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)]) {
                    [_progressDelegate updateProgressStatus:[NSString stringWithFormat:@"Downloading Imagr git branch %@...", branch] workflow:self];
                }

                NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
                [downloader downloadFileFromURL:[NSURL URLWithString:imagrDownloadURL]
                                destinationPath:@"/tmp"
                                   downloadInfo:@{
                                       NBCDownloaderTag : NBCDownloaderTagImagrBranch,
                                       NBCSettingsImagrGitBranchDict : @{NBCSettingsImagrGitBranch : branch, NBCSettingsImagrGitBranchSHA : sha, NBCSettingsImagrBuildTarget : buildTarget}
                                   }];
            } else {
                if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
                    [_delegate imagrCopyError:[NBCError errorWithDescription:@"Selected Imagr branch download URL was empty"]];
                }
            }
        }
    } else {

        if ([selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLatest]) {
            selectedImagrVersion = [workflowItem resourcesSettings][NBCSettingsImagrVersion];
            DDLogDebug(@"[DEBUG] Imagr version latest: %@", selectedImagrVersion);

            if ([selectedImagrVersion length] == 0) {
                if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
                    [_delegate imagrCopyError:[NBCError errorWithDescription:@"Found no version number for \"Latest Version\""]];
                }
                return;
            }
        }

        NSURL *imagrCachedURL = [NBCWorkflowResourcesController cachedVersionURL:selectedImagrVersion resourcesFolder:NBCFolderResourcesCacheImagr];
        DDLogDebug(@"[DEBUG] Imagr.app cache path: %@", [imagrCachedURL path]);
        if ([imagrCachedURL checkResourceIsReachableAndReturnError:nil]) {
            DDLogDebug(@"[DEBUG] Cached version of selected Imagr.app exists!");

            NSDictionary *imagrCachedCopyDict = @{
                NBCWorkflowCopyType : NBCWorkflowCopy,
                NBCWorkflowCopySourceURL : [imagrCachedURL path],
                NBCWorkflowCopyTargetURL : _imagrTargetPathComponent,
                NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
            };

            if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyDict:)]) {
                [_delegate imagrCopyDict:imagrCachedCopyDict];
            }
        } else {
            DDLogDebug(@"[DEBUG] No cached version of selected Imagr.app exists");

            NSString *imagrDownloadURL = [workflowItem resourcesSettings][NBCSettingsImagrDownloadURL];
            DDLogDebug(@"[DEBUG] Selected Imagr release download URL: %@", imagrDownloadURL);

            if ([imagrDownloadURL length] != 0) {
                DDLogInfo(@"Downloading Imagr.app release v%@...", selectedImagrVersion);
                if (_progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)]) {
                    [_progressDelegate updateProgressStatus:[NSString stringWithFormat:@"Downloading Imagr.app release v%@...", selectedImagrVersion]];
                }

                NBCDownloader *downloader = [[NBCDownloader alloc] initWithDelegate:self];
                [downloader downloadFileFromURL:[NSURL URLWithString:imagrDownloadURL]
                                destinationPath:@"/tmp"
                                   downloadInfo:@{NBCDownloaderTag : NBCDownloaderTagImagr, NBCDownloaderVersion : selectedImagrVersion}];
            } else {
                if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
                    [_delegate imagrCopyError:[NBCError errorWithDescription:@"Selected Imagr release download URL was empty"]];
                }
            }
        }
    }
}

- (void)addDownloadedImagrToResources:(NSURL *)downloadedFileURL version:(NSString *)version {

    // -------------------------------------------------------------------
    //  Extract Imagr from dmg and copy to resources cache for future use
    // -------------------------------------------------------------------
    NSError *error;

    DDLogInfo(@"Copying downloaded Imagr.app to cache...");
    NSURL *imagrDownloadedVersionURL =
        [NBCWorkflowResourcesController attachDiskImageAndCopyFileToResourceFolder:downloadedFileURL filePath:@"Imagr.app" resourcesFolder:NBCFolderResourcesCacheImagr version:version];
    DDLogDebug(@"[DEBUG] Cached Imagr.app path: %@", [imagrDownloadedVersionURL path]);

    if ([imagrDownloadedVersionURL checkResourceIsReachableAndReturnError:&error]) {
        NSDictionary *imagrDownloadedCopyDict = @{
            NBCWorkflowCopyType : NBCWorkflowCopy,
            NBCWorkflowCopySourceURL : [imagrDownloadedVersionURL path],
            NBCWorkflowCopyTargetURL : _imagrTargetPathComponent,
            NBCWorkflowCopyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        };
        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyDict:)]) {
            [_delegate imagrCopyDict:imagrDownloadedCopyDict];
        }
    } else {
        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
            [_delegate imagrCopyError:[NBCError errorWithDescription:[error localizedDescription]]];
        }
    }
} // addImagrToResources:version

- (void)addDownloadedImagrBranchToResources:(NSURL *)downloadedFileURL branchDict:(NSDictionary *)branchDict {

    NSError *error;
    NSString *buildTarget = branchDict[NBCSettingsImagrBuildTarget];
    DDLogDebug(@"[DEBUG] Imagr build target: %@", buildTarget);
    if ([buildTarget length] != 0) {

        // ---------------------------------------------------------------
        //  Extract Imagr from zip and copy to resourecs for future use
        // ---------------------------------------------------------------
        DDLogInfo(@"Copying downloaded branch to cache...");
        NSURL *imagrProjectURL = [NBCWorkflowResourcesController unzipAndCopyGitBranchToResourceFolder:downloadedFileURL resourcesFolder:NBCFolderResourcesCacheImagr branchDict:branchDict];
        DDLogDebug(@"[DEBUG] Imagr downloaded branch cache path: %@", [imagrProjectURL path]);

        if ([imagrProjectURL checkResourceIsReachableAndReturnError:&error]) {
            if (_progressDelegate && [_progressDelegate respondsToSelector:@selector(updateProgressStatus:)]) {
                [_progressDelegate updateProgressStatus:@"Building Imagr.app..."];
            }

            NBCWorkflowResourcesController *resourceController = [[NBCWorkflowResourcesController alloc] initWithDelegate:self];
            [resourceController buildProjectAtURL:imagrProjectURL buildTarget:buildTarget];
        } else {
            if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
                [_delegate imagrCopyError:[NBCError errorWithDescription:[error localizedDescription]]];
            }
        }
    } else {
        if (_delegate && [_delegate respondsToSelector:@selector(imagrCopyError:)]) {
            [_delegate imagrCopyError:[NBCError errorWithDescription:@"No Imagr.app build target specified"]];
        }
    }
}

@end
