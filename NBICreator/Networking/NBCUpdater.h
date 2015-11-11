//
//  NBCUpdater.h
//  NBICreator
//
//  Created by Erik Berglund on 16/08/15.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NBCDownloader.h"
#import "NBCDownloaderGitHub.h"

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
