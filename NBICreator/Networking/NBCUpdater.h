//
//  NBCUpdater.h
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

#import "NBCDownloader.h"
#import "NBCDownloaderGitHub.h"
#import <Cocoa/Cocoa.h>

@interface NBCUpdater : NSWindowController <NBCDownloaderDelegate, NBCDownloaderGitHubDelegate>

// -------------------------------------------------------------
//  Class Methods
// -------------------------------------------------------------
+ (id)sharedUpdater;

@property NSString *latestVersion;
@property NSString *downloadURL;
@property NSURL *targetURL;
@property NBCDownloader *downloader;
@property NBCDownloader *downloaderResources;
@property BOOL isDownloading;
@property NSString *updateMessage;

- (void)checkForUpdates;

@property (strong) IBOutlet NSWindow *windowUpdates;

@property (weak) IBOutlet NSButton *buttonDownload;
- (IBAction)buttonDownload:(id)sender;

@property (weak) IBOutlet NSButton *buttonCancel;
- (IBAction)buttonCancel:(id)sender;

@property (weak) IBOutlet NSTextField *textFieldTitle;
@property (weak) IBOutlet NSTextField *textFieldMessage;

@end
