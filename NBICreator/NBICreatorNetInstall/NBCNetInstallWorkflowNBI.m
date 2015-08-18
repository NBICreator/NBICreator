//
//  NBCWorkflowNetInstall.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-01.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallWorkflowNBI.h"
#import "NBCConstants.h"

#import "NBCController.h"
#import "NBCWorkflowNBIController.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallWorkflowNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Run Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSError *err;
    __unsafe_unretained typeof(self) weakSelf = self;
    _nbiVolumeName = [[workflowItem nbiName] stringByDeletingPathExtension];
    //_progressView = [workflowItem progressView];
    _temporaryNBIPath = [[workflowItem temporaryNBIURL] path];
    NBCWorkflowNBIController *nbiController = [[NBCWorkflowNBIController alloc] init];
        
    // -------------------------------------------------------------
    //  Get used space on InstallESD source volume for progress bar
    // -------------------------------------------------------------
    NSString *installESDVolumePath = [[[workflowItem source] installESDVolumeURL] path];
    if ( [installESDVolumePath length] != 0 ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:installESDVolumePath error:&err];
        if ( [volumeAttributes count] != 0 ) {
            double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
            double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
            _netInstallVolumeSize = ( maxSize - freeSize );
        } else {
            NSLog(@"Error getting volumeAttributes from InstallESD Volume");
            NSLog(@"Error: %@", err);
        }
    } else {
        NSLog(@"Error getting installESDVolumePath from source");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create arguments array for createNetInstall.sh
    // -------------------------------------------------------------
    NSArray *createNetInstallArguments = [nbiController generateScriptArgumentsForCreateNetInstall:workflowItem];
    if ( [createNetInstallArguments count] != 0 ) {
        [workflowItem setScriptArguments:createNetInstallArguments];
    } else {
        NSLog(@"Error, no argumets for createNetInstall");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create environment variables for createNetInstall.sh
    // -------------------------------------------------------------
    NSDictionary *environmentVariables = [nbiController generateEnvironmentVariablesForCreateNetInstall:workflowItem];
    if ( [environmentVariables count] != 0 ) {
        [workflowItem setScriptEnvironmentVariables:environmentVariables];
    } else {
        // ------------------------------------------------------------------
        //  Using environment variables file instead of passing them to task
        // ------------------------------------------------------------------
        //NSLog(@"Warning, no environment variables dict for createNetInstall");
    }
    
    // -------------------------------------------------------------
    //  Copy required files to NBI folder
    // -------------------------------------------------------------
    NSURL *createCommonURL = [[workflowItem applicationSource] createCommonURL];
    if ( createCommonURL != nil ) {
        if ( ! [self prepareDestinationFolder:[workflowItem temporaryNBIURL] createCommonURL:createCommonURL workflowItem:workflowItem error:&err] ) {
            NSLog(@"Errror preparing destination folder");
            NSLog(@"Error: %@", err);
            return;
        }
    } else {
        NSLog(@"Error getting create Common URL from workflow item");
        return;
    }
    
    // ------------------------------------------
    //  Setup command to run createNetInstall.sh
    // ------------------------------------------
    NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/sh"];
    
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
                    [weakSelf updateNetInstallWorkflowStatus:outStr stdErr:nil];
                    
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
                    [weakSelf updateNetInstallWorkflowStatus:nil stdErr:errStr];
                    
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
            //  If task failed, post workflow failed notification (This catches too much errors atm, investigate why execution never leaves block until all child methods are completed.)
            // ------------------------------------------------------------------
            NSLog(@"ProxyError? %@", proxyError);
            [nc removeObserver:stdOutObserver];
            [nc removeObserver:stdErrObserver];
            NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : proxyError };
            [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }];
        
    }] runTaskWithCommandAtPath:commandURL arguments:createNetInstallArguments environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
        #pragma unused(error)
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            
            if ( terminationStatus == 0 )
            {
                // ------------------------------------------------------------------
                //  If task exited successfully, post workflow complete notification
                // ------------------------------------------------------------------
                [self removeTemporaryItems:workflowItem];
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
            } else {
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                [nc removeObserver:stdOutObserver];
                [nc removeObserver:stdErrObserver];
                NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
                [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
            }
        }];
    }];
} // runWorkflow

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Pre-/Post Workflow Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)prepareDestinationFolder:(NSURL *)destinationFolderURL createCommonURL:(NSURL *)createCommonURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    BOOL retval = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // ------------------------------------------------------------------
    //  Create array for temporary items to be deleted at end of workflow
    // ------------------------------------------------------------------
    NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
    if ( ! temporaryItemsNBI ) {
        temporaryItemsNBI = [[NSMutableArray alloc] init];
    }
    
    // ------------------------------------------------------------------
    //  Save URL for NBI NetInstall.dmg
    // ------------------------------------------------------------------
    NSURL *nbiNetInstallURL = [destinationFolderURL URLByAppendingPathComponent:@"NetInstall.dmg"];
    [[workflowItem target] setNbiNetInstallURL:nbiNetInstallURL];
    
    // -------------------------------------------------------------------------------------
    //  Copy createCommon.sh to NBI folder for createNetInstall.sh to use when building NBI
    // -------------------------------------------------------------------------------------
    NSURL *createCommonDestinationURL = [destinationFolderURL URLByAppendingPathComponent:@"createCommon.sh"];
    if ( [fileManager isReadableFileAtPath:[createCommonURL path]] ) {
        if ( [fileManager copyItemAtURL:createCommonURL toURL:createCommonDestinationURL error:error] ) {
            
            if ([[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                NSString *createCommon = [[NSString alloc] initWithContentsOfURL:createCommonDestinationURL encoding:NSUTF8StringEncoding error:error];
                NSString *updatedCreateCommon = [createCommon stringByReplacingOccurrencesOfString:@"CoreServices/PlatformSupport.plist"
                                                                                        withString:@"CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
                if ( ! [updatedCreateCommon writeToURL:createCommonDestinationURL atomically:YES encoding:NSUTF8StringEncoding error:error] ) {
                    NSLog(@"Could no write updated CreateCommon file to path %@", createCommonDestinationURL);
                }
            }
            
            [temporaryItemsNBI addObject:createCommonDestinationURL];
            
            retval = YES;
        } else {
            NSLog(@"Error while copying createCommon.sh");
            NSLog(@"Error: %@", *error);
        }
    } else {
        NSLog(@"Could not read createCommon.sh to copy to tmp folder");
    }
    
    [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    
    return retval;
} // prepareDestinationFolder:createCommonURL:workflowItem:error

- (void)removeTemporaryItems:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -------------------------------------------------------------
    //  Delete all items in temporaryItems array at end of workflow
    // -------------------------------------------------------------
    NSError *error;
    NSArray *temporaryItemsNBI = [workflowItem temporaryItemsNBI];
    for ( NSURL *temporaryItemURL in temporaryItemsNBI ) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ( ! [fileManager removeItemAtURL:temporaryItemURL error:&error] ) {
            NSLog(@"Failed Deleting file: %@", [temporaryItemURL path] );
            NSLog(@"Error: %@", error);
        }
    }
} // removeTemporaryItems

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Progress Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateNetInstallWorkflowStatus:(NSString *)outStr stdErr:(NSString *)stdErr {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -------------------------------------------------------------
    //  Check if string begins with chosen prefix or with PERCENT:
    // -------------------------------------------------------------
    if ( [outStr hasPrefix:NBCWorkflowNetInstallLogPrefix] ) {
        // ----------------------------------------------------------------------------------------------
        //  Check for build steps in output, then try to update UI with a meaningful message or progress
        // ----------------------------------------------------------------------------------------------
        NSString *buildStep = [outStr componentsSeparatedByString:@"_"][2];
        
        // -------------------------------------------------------------
        //  "creatingImage", update progress bar from PERCENT: output
        // -------------------------------------------------------------
        if ( [buildStep isEqualToString:@"creatingImage"] ) {
            if ( [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Creating disk image..." workflow:self];
            }
            
            // --------------------------------------------------------------------------------------
            //  "copyingSource", update progress bar from looping current file size of target volume
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"copyingSource"] ) {
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc addObserver:self selector:@selector(checkDiskVolumeName:) name:DADiskDidAppearNotification object:nil];
            [nc addObserver:self selector:@selector(checkDiskVolumeName:) name:DADiskDidChangeNotification object:nil];
            
            // --------------------------------------------------------------------------------------
            //  "buildingBooter", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"buildingBooter"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setCopyComplete:YES];
                [self->_delegate updateProgressStatus:@"Preparing the kernel and boot loader for the boot image..." workflow:self];
                [self->_delegate updateProgressBar:80];
            });
            
            // --------------------------------------------------------------------------------------
            //  "finishingUp", update progress bar with static value
            // --------------------------------------------------------------------------------------
        } else if ( [buildStep isEqualToString:@"finishingUp"] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:@"Performing post install cleanup..." workflow:self];
                [self->_delegate updateProgressBar:85];
            });
        }
        
        // ---------------------------------------------------------
        //  Read percent value from output and pass to progress bar
        // ---------------------------------------------------------
    } else if ( [outStr containsString:@"PERCENT:"] ) {
        NSString *progressPercentString = [outStr componentsSeparatedByString:@":"][1] ;
        double progressPercent = [progressPercentString doubleValue];
        [self updateProgressBar:progressPercent];
    }
    
    if ( [stdErr length] != 0 )
    {
        NSLog(@"stdErr: %@", stdErr);
    }
} // updateNetInstallWorkflowStatus:stdErr

- (void)checkDiskVolumeName:(id)sender {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // --------------------------------------------------------------------------------
    //  Verify that the volumeName is the expected NBI volume name.
    //  Verify that the disk that's mounting has mounted completely (have a volumeURL)
    // --------------------------------------------------------------------------------
    NBCDisk *disk = [sender object];
    if ( [[disk volumeName] isEqualToString:_nbiVolumeName] ) {
        NSURL *diskVolumeURL = [disk volumeURL];
        if ( diskVolumeURL != nil ) {
            [self setCopyComplete:NO];
            [self setDiskVolumePath:[[disk volumeURL] path]];
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc removeObserver:self name:DADiskDidAppearNotification object:nil];
            [nc removeObserver:self name:DADiskDidChangeNotification object:nil];
            
            [self updateProgressBarCopy];
        }
    }
} // checkDiskVolumeName

- (void)updateProgressBarCopy {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // ---------------------------------------------------
    //  Loop to check volume size and update progress bar
    // ---------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgress:)
                                   userInfo:nil
                                    repeats:YES];
} // updateProgressBarCopy

-(void)checkCopyProgress:(NSTimer *)timer {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    // -------------------------------------------------
    //  Get attributes for volume URL mounted by script
    // -------------------------------------------------
    NSError *error;
    NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:_diskVolumePath error:&error];
    if ( [volumeAttributes count] != 0 ) {
        // -------------------------------------------------
        //  Calculate used size and update progress bar
        // -------------------------------------------------
        double maxSize = [volumeAttributes[NSFileSystemSize] doubleValue];
        double freeSize = [volumeAttributes[NSFileSystemFreeSize] doubleValue];
        double volumeCurrentSize = ( maxSize - freeSize );
        NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)volumeCurrentSize countStyle:NSByteCountFormatterCountStyleDecimal];
        NSString *fileSizeOriginal = [NSByteCountFormatter stringFromByteCount:(long long)_netInstallVolumeSize countStyle:NSByteCountFormatterCountStyleDecimal];
        
        if ( _netInstallVolumeSize <= volumeCurrentSize || _copyComplete == YES ) {
            [timer invalidate];
            timer = NULL;
        } else {
            double precentage = (((40 * volumeCurrentSize)/_netInstallVolumeSize) + 40);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                [self->_delegate updateProgressBar:precentage];
            });
        }
    } else {
        [timer invalidate];
        timer = NULL;
        
        NSLog(@"Could not get file attributes for volume: %@", _diskVolumePath);
        NSLog(@"Error: %@", error);
    }
} // checkCopyProgress

- (void)updateProgressBar:(double)value {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));

    if ( value <= 0 ) {
        return;
    }
    
    double precentage = (40 * value)/[@100 doubleValue];
    [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Creating disk image... %d%%", (int)value] workflow:self];
    [self->_delegate updateProgressBar:precentage];

} // updateProgressBar

@end
