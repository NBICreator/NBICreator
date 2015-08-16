//
//  NBCPreferences.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-08.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCPreferences.h"
#import "NBCLogging.h"
#import "NBCConstants.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

DDLogLevel ddLogLevel;

@interface NBCPreferences ()

@end

@implementation NBCPreferences

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib {
    
    // --------------------------------------------------------------
    //  Add KVO Observers
    // --------------------------------------------------------------
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:NBCUserDefaultsLogLevel options:NSKeyValueObservingOptionNew context:nil];
    
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

#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( [keyPath isEqualToString:NBCUserDefaultsLogLevel] ) {
        NSNumber *logLevel = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsLogLevel];
        if ( logLevel ) {
            ddLogLevel = (DDLogLevel)[logLevel intValue];
            [self updateLogWarningLabel];
        }
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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
    [_buttonClearCache setEnabled:NO];
    [_buttonShowCache setEnabled:NO];
    
    NSURL *currentResourceFolder = [self cacheFolderURL];
    if ( [currentResourceFolder checkPromisedItemIsReachableAndReturnError:nil] ) {
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        dispatch_async(taskQueue, ^{
            unsigned long long int folderSize = [self folderSize:[currentResourceFolder path]];
            if ( folderSize ) {
                NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)folderSize countStyle:NSByteCountFormatterCountStyleDecimal];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldCacheFolderSize setStringValue:fileSizeString];
                    [self->_buttonClearCache setEnabled:YES];
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
                //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self updateDatePreview];
}

- (IBAction)buttonClearCache:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self cleanCacheFolder];
}

- (IBAction)buttonShowCache:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSURL *cacheFolderURL = [self cacheFolderURL];
    if ( [cacheFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        NSArray *currentTemplateURLArray = @[ cacheFolderURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:currentTemplateURLArray];
    }
    
}

@end
