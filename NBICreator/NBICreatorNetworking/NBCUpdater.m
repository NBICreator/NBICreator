//
//  NBCUpdater.m
//  NBICreator
//
//  Created by Erik Berglund on 16/08/15.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCUpdater.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

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
    if ( [downloadTag isEqualToString:NBCDownloaderTagNBICreator] ) {
        [_textFieldTitle setStringValue:@"Download Complete!"];
        [_textFieldMessage setStringValue:@"Quit NBICreator and install the downloaded version!"];
        [_buttonDownload setTitle:@"Show In Finder"];
        [self setIsDownloading:NO];
        if ( url ) {
            [self setTargetURL:url];
            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _targetURL ]];
        }
        [self setDownloader:nil];
    }
} // fileDownloadCompleted

- (void)downloadCanceled:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagNBICreator] ) {
        [self setIsDownloading:NO];
        [self setDownloader:nil];
        [_textFieldTitle setStringValue:@"Download Canceled!"];
        [_textFieldMessage setStringValue:_updateMessage];
    }
} // downloadCanceled

- (void)updateProgressBytesRecieved:(float)bytesRecieved expectedLength:(long long)expectedLength downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagNBICreator] ) {
        if ( _windowUpdates ) {
            NSString *downloaded = [NSByteCountFormatter stringFromByteCount:(long long)bytesRecieved countStyle:NSByteCountFormatterCountStyleDecimal];
            NSString *downloadMax = [NSByteCountFormatter stringFromByteCount:expectedLength countStyle:NSByteCountFormatterCountStyleDecimal];
            
            //float percentComplete = (bytesRecieved/(float)expectedLength)*(float)100.0;
            //[_progressIndicatorDeployStudioDownloadProgress setDoubleValue:percentComplete];
            [_textFieldMessage setStringValue:[NSString stringWithFormat:@"%@ / %@", downloaded, downloadMax]];
        }
    }
} // updateProgressBytesRecieved

- (void)checkForUpdates {
    DDLogInfo(@"Checking for application updates!");
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationStartSearchingForUpdates object:self userInfo:nil];
    [self getNBICreatorVersions];
} // checkForUpdates

- (void)getNBICreatorVersions {
    NBCDownloaderGitHub *downloader =  [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCNBICreatorGitHubRepository
                                                 downloadInfo:@{ NBCDownloaderTag : NBCDownloaderTagNBICreator }];
} // getNBICreatorVersions

- (void)getNBICreatorResourcesVersions {
    NBCDownloaderGitHub *downloader =  [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCNBICreatorResourcesGitHubRepository
                                                 downloadInfo:@{ NBCDownloaderTag : NBCDownloaderTagNBICreatorResources }];
} // getNBICreatorVersions

- (void)githubReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagNBICreator] ) {
        [self compareCurrentVersionToLatest:[versionsArray firstObject] downloadDict:downloadDict];
    } else if ( [downloadTag isEqualToString:NBCDownloaderTagNBICreatorResources] ) {
        
    }
} // githubReleaseVersionsArray:downloadDict:downloadInfo

- (void)compareCurrentVersionToLatest:(NSString *)latestVersion downloadDict:(NSDictionary *)downloadDict {
    if ( [latestVersion length] != 0 ) {
        [self setLatestVersion:latestVersion];
    } else {
        DDLogError(@"[ERROR] No version tag was passed, can't continue without.");
        return;
    }
    NSString *currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    if ( [latestVersion containsString:@"beta"] ) {
        NSString *latestVersionGitHub = [[latestVersion componentsSeparatedByString:@"-"] firstObject];
        NSString *latestBuildGitHub = [[latestVersion componentsSeparatedByString:@"."] lastObject];
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        if ( ! [currentVersion isEqualToString:latestVersionGitHub] || ! [currentBuild isEqualToString:latestBuildGitHub] ) {
            _updateMessage = [NSString stringWithFormat:@"Version %@ is available on GitHub!", latestVersion];
            [_textFieldMessage setStringValue:_updateMessage];
            [_textFieldTitle setStringValue:@"An update to NBICreator is available!"];
            
            DDLogInfo(@"Version %@ is available for download!", latestVersion);
            
            userInfo[@"UpdateAvailable"] = @YES;
            userInfo[@"LatestVersion"] = latestVersion;
            [self setDownloadURL:downloadDict[latestVersion]];
            if ( _downloadURL ) {
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
        
    }
} // compareCurrentVersionToLatest

- (IBAction)buttonDownload:(id)sender {
#pragma unused(sender)
    if ( [[_buttonDownload title] isEqualToString:@"Download"] ) {
        NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
        
        // --------------------------------------------------------------
        //  Setup open dialog to only allow one folder to be chosen.
        // --------------------------------------------------------------
        [chooseDestionation setTitle:@"Choose Destination Folder"];
        [chooseDestionation setPrompt:@"Download"];
        [chooseDestionation setCanChooseFiles:NO];
        [chooseDestionation setCanChooseDirectories:YES];
        [chooseDestionation setCanCreateDirectories:YES];
        [chooseDestionation setAllowsMultipleSelection:NO];
        
        if ( [chooseDestionation runModal] == NSModalResponseOK ) {
            // -------------------------------------------------------------------------
            //  Get first item in URL array returned (should only be one) and update UI
            // -------------------------------------------------------------------------
            NSArray *selectedURLs = [chooseDestionation URLs];
            NSURL *selectedURL = [selectedURLs firstObject];
            
            if ( [_downloadURL length] != 0 ) {
                NSString *fileName = [_downloadURL lastPathComponent];
                _targetURL = [selectedURL URLByAppendingPathComponent:fileName];
                
                if ( [_targetURL checkResourceIsReachableAndReturnError:nil] ) {
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:NBCButtonTitleCancel];
                    [alert addButtonWithTitle:@"Overwrite"];
                    [alert setMessageText:@"File already exist"];
                    [alert setInformativeText:[NSString stringWithFormat:@"%@ already exists in the chosen folder, do you want to overwrite it?", fileName]];
                    [alert setAlertStyle:NSCriticalAlertStyle];
                    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode) {
#pragma unused(returnCode)
                        if ( returnCode == NSAlertSecondButtonReturn ) {
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
    } else if ( [[_buttonDownload title] isEqualToString:@"Show In Finder"] ) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _targetURL ]];
    }
    
}

- (void)downloadUpdateToFolder:(NSURL *)targetFolderURL {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setIsDownloading:YES];
        [self->_textFieldTitle setStringValue:[NSString stringWithFormat:@"Downloading NBICreator version %@", self->_latestVersion]];
        [self->_textFieldMessage setStringValue:@"Preparing download..."];
    });
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagNBICreator };
    
    if ( self->_downloader ) {
        [self setDownloader:nil];
    }
    [self setDownloader:[[NBCDownloader alloc] initWithDelegate:self]];
    [self->_downloader downloadFileFromURL:[NSURL URLWithString:self->_downloadURL]
                           destinationPath:[targetFolderURL path]
                              downloadInfo:downloadInfo];
}

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    if ( _isDownloading ) {
        if ( _downloader != nil ) {
            [_downloader cancelDownload];
        }
    } else {
        [_windowUpdates close];
    }
}

@end
