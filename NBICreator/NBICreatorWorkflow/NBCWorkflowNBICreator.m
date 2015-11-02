//
//  NBCWorkflowNBICreator.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowNBICreator.h"
#import "NBCWorkflowItem.h"

#import "NBCError.h"
#import "NBCConstants.h"
#import "NBCLogging.h"

#import "NBCDiskImageController.h"

@implementation NBCWorkflowNBICreator

- (id)initWithDelegate:(id<NBCWorkflowProgressDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)createNBI:(NBCWorkflowItem *)workflowItem {
    
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // -------------------------------------------------------------
    //  Get BaseSystem disk image size for copy progress bar
    // -------------------------------------------------------------
    DDLogInfo(@"Getting size of BaseSystem disk image...");
    
    NSURL *baseSystemDiskImageURL = [[workflowItem source] baseSystemDiskImageURL];
    DDLogDebug(@"[DEBUG] BaseSystem disk image path: %@", [baseSystemDiskImageURL path]);
    
    if ( [baseSystemDiskImageURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *volumeAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[baseSystemDiskImageURL path] error:&error];
        if ( [volumeAttributes count] != 0 ) {
            double fileSize = [volumeAttributes[NSFileSize] doubleValue];
            DDLogDebug(@"[DEBUG] BaseSystem disk image size: %f", fileSize);
            
            [self setTemporaryNBIBaseSystemSize:fileSize];
        } else {
            DDLogError(@"[ERROR] No attributes returned for BaseSystem disk image");
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"BaseSystem disk image doesn't exist"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Create temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Creating temporary NBI folder...");
    
    NSURL *temporaryNBIx86FolderURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/x86_64"];
    DDLogDebug(@"[DEBUG] Temporary NBI x86_64 folder path: %@", [temporaryNBIx86FolderURL path]);
    
    if ( ! [fm createDirectoryAtURL:temporaryNBIx86FolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Unable to create temporary NBI folders"] }];
        return;
    }
    
    // -------------------------------------------------------------
    //  Copy BaseSystem disk image to temporary NBI Folder
    // -------------------------------------------------------------
    DDLogInfo(@"Copying BaseSystem disk image from source...");
    
    NSURL *baseSystemTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"BaseSystem.dmg"];
    DDLogDebug(@"[DEBUG] BaseSystem disk image target path: %@", [baseSystemTargetURL path]);
    
    [self setCopyComplete:NO];
    [self setTemporaryNBIBaseSystemPath:[baseSystemTargetURL path]];
    [[workflowItem target] setBaseSystemURL:baseSystemTargetURL];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(taskQueue, ^{
        
        NSError *blockError = nil;
        if ( [fm copyItemAtURL:baseSystemDiskImageURL toURL:baseSystemTargetURL error:&blockError] ) {
            DDLogDebug(@"[DEBUG] Copy complete!");
            [self setCopyComplete:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self createNBIFilesNBICreator:workflowItem baseSystemTemporaryURL:baseSystemTargetURL];
            });
        } else {
            DDLogError(@"[ERROR] Copy failed!");
            [self setCopyComplete:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : blockError ?: [NBCError errorWithDescription:@"BaseSystem disk image copy failed"] }];
                return;
            });
        }
    });
    
    // --------------------------------------------------------------------------
    //  Loop to check size of BaseSystem.dmg during copy and update progress bar
    // --------------------------------------------------------------------------
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(checkCopyProgressBaseSystem:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)createNBIFilesNBICreator:(NBCWorkflowItem *)workflowItem baseSystemTemporaryURL:(NSURL *)baseSystemTemporaryURL {
    
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    // --------------------------------------------------------------------------
    //  Resize BaseSystem disk image and mount with shadow file
    // --------------------------------------------------------------------------
    if ( [NBCDiskImageController resizeAndMountBaseSystemWithShadow:baseSystemTemporaryURL target:[workflowItem target] error:&error] ) {
        NSURL *baseSystemTemporaryVolumeURL = [[workflowItem target] baseSystemVolumeURL];
        DDLogDebug(@"[DEBUG] NBI BaseSystem volume path: %@", [baseSystemTemporaryVolumeURL path]);
        
        if ( [baseSystemTemporaryVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
            DDLogDebug(@"[DEBUG] NBI BaseSystem volume IS mounted");
            
            // --------------------------------------------------------------------------
            //  Copy booter
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying booter...");
            if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Copying booter file..." workflow:self];
            }
            
            NSURL *booterSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/boot.efi"];
            NSURL *booterTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/booter"];
            
            if ( [fm copyItemAtURL:booterSourceURL toURL:booterTargetURL error:&error] ) {
                if ( ! [fm setAttributes:@{ NSFileImmutable : @NO } ofItemAtPath:[booterTargetURL path] error:&error] ) {
                    DDLogWarn(@"[WARN] Unable to unlock booter file!");
                    DDLogWarn(@"[WARN] %@", [error localizedDescription] );
                }
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"booter copy failed"] }];
                return;
            }
            
            // --------------------------------------------------------------------------
            //  Copy PlatformSupport.plist
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying PlatformSupport.plist...");
            if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Copying PlatformSupport.plist..." workflow:self];
            }
            
            NSURL *platformSupportSourceURL;
            NSURL *platformSupportTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/PlatformSupport.plist"];
            
            if ( [[[workflowItem source] sourceVersion] containsString:@"10.7"] ) {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/com.apple.recovery.boot/PlatformSupport.plist"];
            } else {
                platformSupportSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/PlatformSupport.plist"];
            }
            
            if ( ! [fm copyItemAtURL:platformSupportSourceURL toURL:platformSupportTargetURL error:&error] ) {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"PlatformSupport.plist copy failed"] }];
                return;
            }
            
            // --------------------------------------------------------------------------
            //  Copy kernelcache
            // --------------------------------------------------------------------------
            DDLogInfo(@"Copying kernelcache...");
            if ( _delegate && [_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                [_delegate updateProgressStatus:@"Copying kernel cache files..." workflow:self];
            }
                
            NSURL *kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/PrelinkedKernels/prelinkedkernel"];
            NSURL *kernelCacheTargetURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"i386/x86_64/kernelcache"];
            
            if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:nil] ) {
                kernelCacheSourceURL = [baseSystemTemporaryVolumeURL URLByAppendingPathComponent:@"System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"];
                
                if ( ! [kernelCacheSourceURL checkResourceIsReachableAndReturnError:&error] ) {
                    DDLogError(@"[ERROR] Found no prelinked kernelcache");
                    [nc postNotificationName:NBCNotificationWorkflowFailed
                                      object:self
                                    userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Found no prelinked kernelcache"] }];
                    return;
                }
            }
            
            if ( [fm copyItemAtURL:kernelCacheSourceURL toURL:kernelCacheTargetURL error:&error] ) {
                [nc postNotificationName:NBCNotificationWorkflowCompleteNBI object:self userInfo:nil];
            } else {
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"kenelcache copy failed"] }];
                return;
            }
        } else {
            DDLogDebug(@"[DEBUG] NBI BaseSystem volume is NOT mounted");
            [nc postNotificationName:NBCNotificationWorkflowFailed
                              object:self
                            userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"NBI BaseSystem volume not mounted"] }];
            return;
        }
    } else {
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:@{ NBCUserInfoNSErrorKey : error ?: [NBCError errorWithDescription:@"Resizing NBI BaseSystem failed"] }];
        return;
    }
} // createNBIFilesNBICreator

-(void)checkCopyProgressBaseSystem:(NSTimer *)timer {
    
    // -------------------------------------------------
    //  Get attributes for target BaseSystem.dmg
    // -------------------------------------------------
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:_temporaryNBIBaseSystemPath error:&error];
    if ( [fileAttributes count] != 0 ) {
        double fileSize = [fileAttributes[NSFileSize] doubleValue];
        NSString *fileSizeString = [NSByteCountFormatter stringFromByteCount:(long long)fileSize countStyle:NSByteCountFormatterCountStyleDecimal];
        NSString *fileSizeOriginal = [NSByteCountFormatter stringFromByteCount:(long long)_temporaryNBIBaseSystemSize countStyle:NSByteCountFormatterCountStyleDecimal];
        
        if ( _temporaryNBIBaseSystemSize <= fileSize || _copyComplete == YES ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( self->_delegate && [self->_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                    [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                }
            });
            [timer invalidate];
            timer = nil;
        } else {
            double percentage = (((100 * fileSize)/_temporaryNBIBaseSystemSize));
            double percentageSlice = ( percentage * 0.9 );
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( self->_delegate && [self->_delegate respondsToSelector:@selector(updateProgressStatus:workflow:)] ) {
                    [self->_delegate updateProgressStatus:[NSString stringWithFormat:@"Copying BaseSystem.dmg... %@/%@", fileSizeString, fileSizeOriginal] workflow:self];
                }
                
                if ( self->_delegate && [self->_delegate respondsToSelector:@selector(updateProgressBar:)] ) {
                    [self->_delegate updateProgressBar:percentageSlice];
                }
            });
        }
    } else {
        [timer invalidate];
        timer = nil;
        
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }
} // checkCopyProgress

@end
