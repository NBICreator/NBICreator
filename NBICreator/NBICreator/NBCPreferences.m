//
//  NBCPreferences.m
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

#import "NBCPreferences.h"
#import "NBCLogging.h"
#import "NBCConstants.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCController.h"
#import "NBCUpdater.h"
#import "NBCWorkflowManager.h"

DDLogLevel ddLogLevel;

@interface NBCPreferences ()

@end

@implementation NBCPreferences

- (id)initWithWindowNibName:(NSString *)windowNibName {
    self = [super initWithWindowNibName:windowNibName];
    if (self != nil) {
        [self window];
        
    }
    return self;
}

- (void)awakeFromNib {
    
    // --------------------------------------------------------------
    //  Add KVO Observers
    // --------------------------------------------------------------
    [[NBCWorkflowManager sharedManager] addObserver:self forKeyPath:@"workflowRunning" options:NSKeyValueObservingOptionNew context:nil];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:NBCUserDefaultsLogLevel options:NSKeyValueObservingOptionNew context:nil];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(startSearchingForUpdates:) name:NBCNotificationStartSearchingForUpdates object:nil];
    [center addObserver:self selector:@selector(stopSearchingForUpdates:) name:NBCNotificationStopSearchingForUpdates object:nil];
    
    [self createPopUpButtonDateFormats];
    [self updateLogWarningLabel];
    [self updateCacheFolderSize];
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)controlTextDidChange:(NSNotification *)sender {
    if ( [sender object] == _comboBoxDateFormat ) {
        [self updateDatePreview];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    
    if ( [keyPath isEqualToString:NBCUserDefaultsLogLevel] ) {
        NSNumber *logLevel = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsLogLevel];
        if ( logLevel ) {
            ddLogLevel = (DDLogLevel)[logLevel intValue];
            [self updateLogWarningLabel];
        }
    } else if ( [keyPath isEqualToString:@"workflowRunning"] ) {
        [_buttonClearCache setEnabled:![[NBCWorkflowManager sharedManager] workflowRunning]];
    }
} // observeValueForKeyPath:ofObject:change:context

- (void)updateLogWarningLabel {
    if ( (int)ddLogLevel == (int)DDLogLevelDebug ) {
        [_imageViewLogWarning setHidden:NO];
        [_textFieldLogWarning setHidden:NO];
    } else {
        [_imageViewLogWarning setHidden:YES];
        [_textFieldLogWarning setHidden:YES];
    }
}

- (void)createPopUpButtonDateFormats {
    
    NSMutableArray *dateFormats = [[NSMutableArray alloc] init];
    [dateFormats addObject:@"yyyy-MM-dd"];
    [dateFormats addObject:@"yyMMdd"];
    [dateFormats addObject:@"yyyyMMdd"];
    [dateFormats addObject:@"MMddyy"];
    [dateFormats addObject:@"MMddyyyy"];
    
    [_comboBoxDateFormat addItemsWithObjectValues:dateFormats];
    [self updateDatePreview];
}

- (void)updateDatePreview {
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSString *dateFormat = [_comboBoxDateFormat stringValue];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:dateFormat];
    NSDate *date = [NSDate date];
    NSString *formattedDate = [dateFormatter stringFromDate:date];
    [_textFieldDatePreview setStringValue:formattedDate];
}

- (NSURL *)cacheFolderURL {
    NBCWorkflowResourcesController *resourcesController = [[NBCWorkflowResourcesController alloc] init];
    return [resourcesController urlForResourceFolder:NBCFolderResources];
}

- (void)updateCacheFolderSize {
    [_textFieldCacheFolderSize setStringValue:@"Calculating…"];
    
    NSURL *currentResourceFolder = [self cacheFolderURL];
    if ( [currentResourceFolder checkPromisedItemIsReachableAndReturnError:nil] ) {
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            unsigned long long int folderSize = [self folderSize:[currentResourceFolder path]];
            if ( folderSize ) {
                NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)folderSize countStyle:NSByteCountFormatterCountStyleDecimal];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldCacheFolderSize setStringValue:fileSizeString];
                    [self->_buttonClearCache setEnabled:![[NBCWorkflowManager sharedManager] workflowRunning]];
                    [self->_buttonShowCache setEnabled:YES];
                });
            }
        });
    } else {
        [_textFieldCacheFolderSize setStringValue:@"Zero bytes"];
        [_buttonShowCache setEnabled:NO];
    }
}

- (unsigned long long int)folderSize:(NSString *)folderPath {
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:folderPath error:nil];
    NSEnumerator *filesEnumerator = [filesArray objectEnumerator];
    NSString *fileName;
    unsigned long long int fileSize = 0;
    while (fileName = [filesEnumerator nextObject]) {
        NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:fileName] error:nil];
        fileSize += [fileDictionary fileSize];
    }
    
    return fileSize;
}

- (void)cleanCacheFolder {
    [_buttonClearCache setEnabled:NO];
    [_buttonShowCache setEnabled:NO];
    NSURL *cacheFolderURL = [self cacheFolderURL];
    if ( [cacheFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification  
                // ------------------------------------------------------------------
                NSLog(@"ProxyError? %@", proxyError);
            }];
            
        }] removeItemAtURL:cacheFolderURL withReply:^(NSError *error, int terminationStatus) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                if ( terminationStatus != 0 ) {
                    NSLog(@"Delete Cache folder Failed");
                    NSLog(@"Error: %@", error);
                }
                [self updateCacheFolderSize];
            }];
        }];
    } else {
        NSLog(@"Cache folder doesn't exist!");
    }
}

- (IBAction)comboBoxDateFormat:(id)sender {
#pragma unused(sender)
    
    [self updateDatePreview];
}

- (IBAction)buttonClearCache:(id)sender {
#pragma unused(sender)
    
    [self cleanCacheFolder];
}

- (IBAction)buttonShowCache:(id)sender {
#pragma unused(sender)
    
    NSURL *cacheFolderURL = [self cacheFolderURL];
    if ( [cacheFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        NSArray *currentTemplateURLArray = @[ cacheFolderURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:currentTemplateURLArray];
    }
    
}

- (void)startSearchingForUpdates:(NSNotification *)notification {
#pragma unused(notification)
    [self setCheckingForApplicationUpdates:YES];
    [_textFieldUpdateStatus setStringValue:@"Searching..."];
}

- (void)stopSearchingForUpdates:(NSNotification *)notification {
    [self setCheckingForApplicationUpdates:NO];
    
    NSDictionary *userInfo = [notification userInfo];
    if ( [userInfo[@"UpdateAvailable"] boolValue] ) {
        NSString *latestVersion = userInfo[@"LatestVersion"];
        DDLogInfo(@"latestVersion=%@", latestVersion);
        [_textFieldUpdateStatus setStringValue:@"There is an update available!"];
    } else {
        [_textFieldUpdateStatus setStringValue:@"You already have the latest version."];
    }
}

- (IBAction)buttonCheckForUpdatesNow:(id)sender {
#pragma unused(sender)
    [[NBCUpdater sharedUpdater] checkForUpdates];
}

@end
