//
//  NBCUpdater.m
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

#import "Main.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCUpdater.h"
#import "NSString+randomString.h"

@interface NBCUpdater ()

@end

@implementation NBCUpdater

+ (id)sharedUpdater {
    static NBCUpdater *sharedUpdater = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedUpdater = [[self alloc] initWithWindowNibName:@"NBCUpdater"];
    });
    return sharedUpdater;
} // sharedUpdater

- (id)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    if (self != nil) {
        [self window];
    }
    return self;
} // initWithWindowNibName

- (void)windowDidLoad {
    [super windowDidLoad];
} // windowDidLoad

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloader
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)fileDownloadCompleted:(NSURL *)url downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ([downloadTag isEqualToString:NBCDownloaderTagNBICreator]) {
        [_textFieldTitle setStringValue:@"Download Complete!"];
        [_textFieldMessage setStringValue:@"Quit NBICreator and install the downloaded version!"];
        [_buttonDownload setTitle:@"Show In Finder"];
        [self setIsDownloading:NO];
        if (url) {
            [self setTargetURL:url];
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _targetURL ]];
        }
        [self setDownloader:nil];
    } else if ([downloadTag isEqualToString:NBCDownloaderTagNBICreatorResources]) {
        [self unzipAndCopyToSupportFolder:url version:downloadInfo[@"Version"]];
    }
} // fileDownloadCompleted

- (void)downloadCanceled:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ([downloadTag isEqualToString:NBCDownloaderTagNBICreator]) {
        [self setIsDownloading:NO];
        [self setDownloader:nil];
        [_textFieldTitle setStringValue:@"Download Canceled!"];
        [_textFieldMessage setStringValue:_updateMessage];
    }
} // downloadCanceled

- (void)updateProgressBytesRecieved:(float)bytesRecieved expectedLength:(long long)expectedLength downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ([downloadTag isEqualToString:NBCDownloaderTagNBICreator]) {
        if (_windowUpdates) {
            NSString *downloaded = [NSByteCountFormatter stringFromByteCount:(long long)bytesRecieved countStyle:NSByteCountFormatterCountStyleDecimal];
            NSString *downloadMax = [NSByteCountFormatter stringFromByteCount:expectedLength countStyle:NSByteCountFormatterCountStyleDecimal];

            // float percentComplete = (bytesRecieved/(float)expectedLength)*(float)100.0;
            //[_progressIndicatorDeployStudioDownloadProgress setDoubleValue:percentComplete];
            [_textFieldMessage setStringValue:[NSString stringWithFormat:@"%@ / %@", downloaded, downloadMax]];
        }
    }
} // updateProgressBytesRecieved

- (void)checkForUpdates {
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationStartSearchingForUpdates object:self userInfo:nil];
    [self getNBICreatorVersions];
    [self getNBICreatorResourcesVersions];
} // checkForUpdates

- (void)getNBICreatorVersions {
    DDLogDebug(@"[DEBUG] Checking for application updates!");
    NBCDownloaderGitHub *downloader = [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCNBICreatorGitHubRepository downloadInfo:@{NBCDownloaderTag : NBCDownloaderTagNBICreator}];
} // getNBICreatorVersions

- (void)getNBICreatorResourcesVersions {
    DDLogDebug(@"[DEBUG] Checking for resources updates!");
    NBCDownloaderGitHub *downloader = [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCNBICreatorResourcesGitHubRepository downloadInfo:@{NBCDownloaderTag : NBCDownloaderTagNBICreatorResources}];
} // getNBICreatorVersions

- (void)githubReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ([downloadTag isEqualToString:NBCDownloaderTagNBICreator]) {
        [self compareCurrentVersionToLatest:[versionsArray firstObject] downloadDict:downloadDict];
    } else if ([downloadTag isEqualToString:NBCDownloaderTagNBICreatorResources]) {
        [self compareResourcesVersionToLocal:[versionsArray firstObject] downloadDict:downloadDict];
    }
} // githubReleaseVersionsArray:downloadDict:downloadInfo

- (void)compareResourcesVersionToLocal:(NSString *)latestVersion downloadDict:(NSDictionary *)downloadDict {
    NSURL *resourcesFolderURL = [self resourcesFolder:NBCFolderResources];
    NSURL *resourcesVersionDictURL = [resourcesFolderURL URLByAppendingPathComponent:@"ResourcesVersion.plist"];
    NSDictionary *resourcesVersionDict = [NSDictionary dictionaryWithContentsOfURL:resourcesVersionDictURL];
    if ([resourcesVersionDict count] != 0) {
        NSString *localVersion = resourcesVersionDict[@"Version"];
        if (![latestVersion isEqualToString:localVersion]) {
            NSString *downloadURLString = downloadDict[latestVersion];
            if ([downloadURLString length] != 0) {
                NSError *error;
                NSURL *downloadFolderURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/tmp/download.%@", [NSString nbc_randomString]]];
                if ([[NSFileManager defaultManager] createDirectoryAtURL:downloadFolderURL withIntermediateDirectories:YES attributes:@{} error:&error]) {
                    [self downloadResourcesToFolder:downloadURLString targetFolderPath:[downloadFolderURL path] version:latestVersion];
                } else {
                    DDLogError(@"[ERROR] Could not create download folder!");
                    DDLogError(@"[ERROR] %@", error);
                }
            } else {
                DDLogError(@"[ERROR] Got no download URL!");
            }
        } else {
            NSMutableDictionary *resourcesVersionDictMutable = [[NSMutableDictionary alloc] initWithContentsOfURL:resourcesVersionDictURL];
            if ([resourcesVersionDictMutable count] == 0) {
                resourcesVersionDictMutable = [[NSMutableDictionary alloc] init];
            }

            resourcesVersionDictMutable[@"LastCheck"] = [NSDate date] ?: @"";

            [resourcesVersionDictMutable writeToURL:resourcesVersionDictURL atomically:YES];
        }
    } else {
        NSString *downloadURLString = downloadDict[latestVersion];
        if ([downloadURLString length] != 0) {
            NSError *error;
            NSURL *downloadFolderURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/tmp/download.%@", [NSString nbc_randomString]]];
            if ([[NSFileManager defaultManager] createDirectoryAtURL:downloadFolderURL withIntermediateDirectories:YES attributes:@{} error:&error]) {
                [self downloadResourcesToFolder:downloadURLString targetFolderPath:[downloadFolderURL path] version:latestVersion];
            } else {
                DDLogError(@"[ERROR] Could not create download folder!");
                DDLogError(@"[ERROR] %@", error);
            }
        } else {
            DDLogError(@"[ERROR] Got no download URL!");
        }
    }
}

- (void)compareCurrentVersionToLatest:(NSString *)latestVersion downloadDict:(NSDictionary *)downloadDict {
    if ([latestVersion length] != 0) {
        [self setLatestVersion:latestVersion];
    } else {
        DDLogError(@"[ERROR] No version tag was passed, can't continue without.");
        return;
    }

    int latestVersionInt = [[latestVersion stringByReplacingOccurrencesOfString:@"." withString:@""] intValue];

    NSString *currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if ([latestVersion containsString:@"beta"]) {
        NSString *latestVersionGitHub = [[latestVersion componentsSeparatedByString:@"-"] firstObject];
        NSString *latestBuildGitHub = [[latestVersion componentsSeparatedByString:@"."] lastObject];
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        if (![currentVersion isEqualToString:latestVersionGitHub] || ![currentBuild isEqualToString:latestBuildGitHub]) {
            _updateMessage = [NSString stringWithFormat:@"Version %@ is available on GitHub!", latestVersion];
            [_textFieldMessage setStringValue:_updateMessage];
            [_textFieldTitle setStringValue:@"An update to NBICreator is available!"];

            DDLogInfo(@"Version %@ is available for download!", latestVersion);

            userInfo[@"UpdateAvailable"] = @YES;
            userInfo[@"LatestVersion"] = latestVersion;
            [self setDownloadURL:downloadDict[latestVersion]];
            if (_downloadURL) {
                [_buttonDownload setEnabled:YES];
            } else {
                DDLogError(@"[ERROR] DownloadURL was empty!");
                [_buttonDownload setEnabled:NO];
            }
            [self setIsDownloading:NO];
            [_buttonDownload setTitle:@"Download"];
            [_windowUpdates makeKeyAndOrderFront:self];

        } else {
            userInfo[@"UpdateAvailable"] = @NO;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationStopSearchingForUpdates object:self userInfo:userInfo];
    } else {
        int currentVersionInt = [[currentVersion stringByReplacingOccurrencesOfString:@"." withString:@""] intValue];
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        if (currentVersionInt < latestVersionInt) {
            _updateMessage = [NSString stringWithFormat:@"Version %@ is available on GitHub!", latestVersion];
            [_textFieldMessage setStringValue:_updateMessage];
            [_textFieldTitle setStringValue:@"An update to NBICreator is available!"];

            DDLogInfo(@"Version %@ is available for download!", latestVersion);

            userInfo[@"UpdateAvailable"] = @YES;
            userInfo[@"LatestVersion"] = latestVersion;
            [self setDownloadURL:downloadDict[latestVersion]];
            if (_downloadURL) {
                [_buttonDownload setEnabled:YES];
            } else {
                DDLogError(@"[ERROR] DownloadURL was empty!");
                [_buttonDownload setEnabled:NO];
            }
            [self setIsDownloading:NO];
            [_buttonDownload setTitle:@"Download"];
            [_windowUpdates makeKeyAndOrderFront:self];
        } else {
            userInfo[@"UpdateAvailable"] = @NO;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationStopSearchingForUpdates object:self userInfo:userInfo];
    }
} // compareCurrentVersionToLatest

- (IBAction)buttonDownload:(id)sender {
#pragma unused(sender)
    if ([[_buttonDownload title] isEqualToString:@"Download"]) {
        NSOpenPanel *chooseDestionation = [NSOpenPanel openPanel];

        // --------------------------------------------------------------
        //  Setup open dialog to only allow one folder to be chosen.
        // --------------------------------------------------------------
        [chooseDestionation setTitle:@"Choose Destination Folder"];
        [chooseDestionation setPrompt:@"Download"];
        [chooseDestionation setCanChooseFiles:NO];
        [chooseDestionation setCanChooseDirectories:YES];
        [chooseDestionation setCanCreateDirectories:YES];
        [chooseDestionation setAllowsMultipleSelection:NO];

        if ([chooseDestionation runModal] == NSModalResponseOK) {
            // -------------------------------------------------------------------------
            //  Get first item in URL array returned (should only be one) and update UI
            // -------------------------------------------------------------------------
            NSArray *selectedURLs = [chooseDestionation URLs];
            NSURL *selectedURL = [selectedURLs firstObject];

            if ([_downloadURL length] != 0) {
                NSString *fileName = [_downloadURL lastPathComponent];
                _targetURL = [selectedURL URLByAppendingPathComponent:fileName];

                if ([_targetURL checkResourceIsReachableAndReturnError:nil]) {
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:NBCButtonTitleCancel];
                    [alert addButtonWithTitle:@"Overwrite"];
                    [alert setMessageText:@"File already exist"];
                    [alert setInformativeText:[NSString stringWithFormat:@"%@ already exists in the chosen folder, do you want to overwrite it?", fileName]];
                    [alert setAlertStyle:NSCriticalAlertStyle];
                    [alert beginSheetModalForWindow:[self window]
                                  completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
                                    if (returnCode == NSAlertSecondButtonReturn) {
                                        [self downloadUpdateToFolder:selectedURL];
                                    }
                                  }];
                } else {
                    [self downloadUpdateToFolder:selectedURL];
                }
            } else {
                DDLogError(@"[ERROR] Could not get download url!");
            }
        }
    } else if ([[_buttonDownload title] isEqualToString:@"Show In Finder"]) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _targetURL ]];
    }
}

- (void)downloadUpdateToFolder:(NSURL *)targetFolderURL {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self setIsDownloading:YES];
      [self->_textFieldTitle setStringValue:[NSString stringWithFormat:@"Downloading NBICreator version %@", self->_latestVersion]];
      [self->_textFieldMessage setStringValue:@"Preparing download..."];
    });
    NSDictionary *downloadInfo = @{NBCDownloaderTag : NBCDownloaderTagNBICreator};

    if (self->_downloader) {
        [self setDownloader:nil];
    }
    [self setDownloader:[[NBCDownloader alloc] initWithDelegate:self]];
    [self->_downloader downloadFileFromURL:[NSURL URLWithString:self->_downloadURL] destinationPath:[targetFolderURL path] downloadInfo:downloadInfo];
}

- (void)downloadResourcesToFolder:(NSString *)url targetFolderPath:(NSString *)targetFolderPath version:(NSString *)version {
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagNBICreatorResources, @"Version" : version };

    if (self->_downloaderResources) {
        [self setDownloaderResources:nil];
    }
    [self setDownloaderResources:[[NBCDownloader alloc] initWithDelegate:self]];
    [self->_downloaderResources downloadFileFromURL:[NSURL URLWithString:url] destinationPath:targetFolderPath downloadInfo:downloadInfo];
}

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    if (_isDownloading) {
        if (_downloader != nil) {
            [_downloader cancelDownload];
        }
    } else {
        [_windowUpdates close];
    }
}

- (NSURL *)resourcesFolder:(NSString *)resourcesFolder {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if (![userApplicationSupport checkResourceIsReachableAndReturnError:&error]) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }

    return [userApplicationSupport URLByAppendingPathComponent:resourcesFolder isDirectory:YES];
}

- (void)unzipAndCopyToSupportFolder:(NSURL *)zipURL version:(NSString *)version {
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSURL *resourcesFolderURL = [self resourcesFolder:NBCFolderResources];
    if (![resourcesFolderURL checkResourceIsReachableAndReturnError:nil]) {
        if (![fm createDirectoryAtURL:resourcesFolderURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogError(@"[ERROR] Could not create folder");
            DDLogError(@"[ERROR] %@", error);
            return;
        }
    }

    // Unzip Archive
    NSString *tmpFolderPath = [NSString stringWithFormat:@"/tmp/zip.%@", [NSString nbc_randomString]];
    if ([Main unzipFileAtPath:[zipURL path] toDestination:tmpFolderPath]) {
        NSArray *unzippedRootItems = [fm contentsOfDirectoryAtPath:tmpFolderPath error:NULL];
        for (NSString *itemName in unzippedRootItems) {
            if ([itemName isEqualToString:@"__MACOSX"]) {
                continue;
            }

            NSURL *sourceURL = [NSURL fileURLWithPath:[tmpFolderPath stringByAppendingPathComponent:itemName]];
            NSURL *targetURL = [resourcesFolderURL URLByAppendingPathComponent:itemName];
            if ([targetURL checkResourceIsReachableAndReturnError:&error]) {
                if (![fm removeItemAtURL:targetURL error:&error]) {
                    DDLogError(@"[ERROR] Could not resource folder: %@", [targetURL path]);
                    DDLogError(@"[ERROR] %@", error);
                    return;
                }
            }

            if (![fm moveItemAtURL:sourceURL toURL:targetURL error:&error]) {
                DDLogError(@"[ERROR] Could not create resource folder: %@", [targetURL path]);
                DDLogError(@"[ERROR] %@", error);
                return;
            }
        }

        NSURL *resourcesVersionDictURL = [resourcesFolderURL URLByAppendingPathComponent:@"ResourcesVersion.plist"];
        NSMutableDictionary *resourcesVersionDict = [[NSMutableDictionary alloc] initWithContentsOfURL:resourcesVersionDictURL];
        if ([resourcesVersionDict count] == 0) {
            resourcesVersionDict = [[NSMutableDictionary alloc] init];
        }

        resourcesVersionDict[@"Version"] = version ?: @0;
        resourcesVersionDict[@"DownloadDate"] = [NSDate date] ?: @"";
        resourcesVersionDict[@"LastCheck"] = [NSDate date] ?: @"";

        [resourcesVersionDict writeToURL:resourcesVersionDictURL atomically:YES];
    }

    if (![fm removeItemAtPath:tmpFolderPath error:&error]) {
        DDLogError(@"[ERROR] Could not remove temporary zip folder");
        DDLogError(@"[ERROR] %@", error);
    }

    if (![fm removeItemAtURL:[zipURL URLByDeletingLastPathComponent] error:&error]) {
        DDLogError(@"[ERROR] Could not remove temporary download folder");
        DDLogError(@"[ERROR] %@", error);
    }
}

@end
