//
//  NBCWorkflowPostWorkflowTaskController.m
//  NBICreator
//
//  Created by Erik Berglund on 2016-01-11.
//  Copyright © 2016 NBICreator. All rights reserved.
//

#import "NBCWorkflowPostWorkflowTaskController.h"
#import "NBCWorkflowItem.h"
#import "NBCConstants.h"
#import "NBCLogging.h"
#import "NBCError.h"
#import "NBCDiskController.h"
#import "NBCDiskArbitrationPrivateFunctions.h"
#import "NBCHelperAuthorization.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"
#import "NBCWorkflowResources.h"
#import "NBCWorkflowResourcesModify.h"
#import "NBCDiskImageController.h"

@implementation NBCWorkflowPostWorkflowTaskController

- (id)initWithDelegate:(id<NBCWorkflowPostWorkflowTaskControllerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)runPostWorkflowTasks:(NSDictionary *)postWorkflowTasks workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Starting Post-Workflow tasks...");
    [_progressDelegate updateProgressStatus:@"Starting Post-Workflow tasks..." workflow:self];
    
    if ( [postWorkflowTasks[@"CreateUSBDevice"] boolValue] ) {
        NSDictionary *userSettings = [workflowItem userSettings];
        NSString *usbVolumeBSDName = userSettings[NBCSettingsUSBBSDNameKey] ?: @"";
        DDLogDebug(@"[DEBUG] Selected USB volume BSD Name: %@", usbVolumeBSDName);
        
        if ( [usbVolumeBSDName length] == 0 ) {
            [_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"USB device could not be found!"]];
            return;
        } else {
            NBCDisk *usbDisk = [[NBCDiskController diskFromBSDName:usbVolumeBSDName] parent];
            if ( ! usbDisk ) {
                [_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"USB device could not be found!"]];
                return;
            } else {
                
                DDLogInfo(@"Unmounting USB device...");
                [_progressDelegate updateProgressStatus:@"Unmounting USB device..." workflow:self];
                
                // Unmount USB Disk
                [usbDisk unmountWithOptions:kDiskUnmountOptionWhole];
                
                NSString *usbDeviceBSDName = [usbDisk BSDName];
                DDLogDebug(@"[DEBUG] Selected USB device BSD Name: %@", usbDeviceBSDName);
                
                [self partitionUSBDiskWithBSDName:usbDeviceBSDName volumeName:@"ImagrUSB" workflowItem:workflowItem];
            }
        }
    } else {
        [_delegate postWorkflowTasksCompleted];
    }
}

- (void)partitionUSBDiskWithBSDName:(NSString *)bsdName volumeName:(NSString *)volumeName workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Erasing USB device...");
    [_progressDelegate updateProgressStatus:@"Erasing USB device..." workflow:self];
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSError *err = nil;
    NSData *authData = [workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper:&err];
        if ( err ) {
            DDLogError(@"[ERROR] %@", [err localizedDescription]);
        }
        [workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:[workflowItem progressView]];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate postWorkflowTasksFailedWithError:proxyError];
            });
        }] partitionDiskWithBSDName:bsdName volumeName:volumeName authorization:authData withReply:^(NSError *error, int terminationStatus) {
            if ( terminationStatus == 0 ) {
                NBCDisk *usbDisk = [NBCDiskController diskFromBSDName:bsdName];
                if ( ! usbDisk ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"USB device could not be found after erase"]];
                    });
                } else {
                    NBCDisk *usbVolume = nil;
                    for ( NBCDisk *disk in [usbDisk children] ) {
                        if ( [[disk volumeName] isEqualToString:volumeName] ) {
                            usbVolume = disk;
                            break;
                        }
                    }
                    
                    if ( usbVolume ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self copyNBIToUSBDisk:usbVolume workflowItem:workflowItem];
                        });
                    } else {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self->_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"USB volume could not be found after erase"]];
                        });
                    }
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate postWorkflowTasksFailedWithError:error];
                });
            }
        }];
    });
}

- (void)copyNBIToUSBDisk:(NBCDisk *)usbVolumeDisk workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Copying files to USB device...");
    [_progressDelegate updateProgressStatus:@"Copying files to USB device..." workflow:self];
    
    if ( ! [usbVolumeDisk isMounted] ) {
        DDLogDebug(@"[DEBUG] Mounting USB volume...");
        [usbVolumeDisk mount];
        if ( ! [usbVolumeDisk isMounted] ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"USB volume could not mounted"]];
            });
            return;
        }
    }
    
    NSURL *usbVolumeURL = [usbVolumeDisk volumeURL];
    NSURL *nbiURL = [workflowItem temporaryNBIURL];
    
    NBCWorkflowResources *resources = [[NBCWorkflowResources alloc] init];
    NSArray *usbResources = [resources prepareResourcesToUSBFromNBI:nbiURL];
    
    if ( [usbResources count] != 0 ) {
        
        // --------------------------------
        //  Get Authorization
        // --------------------------------
        NSError *err = nil;
        NSData *authData = [workflowItem authData];
        if ( ! authData ) {
            authData = [NBCHelperAuthorization authorizeHelper:&err];
            if ( err ) {
                DDLogError(@"[ERROR] %@", [err localizedDescription]);
            }
            [workflowItem setAuthData:authData];
        }
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:[workflowItem progressView]];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate postWorkflowTasksFailedWithError:proxyError];
                });
            }] copyResourcesToVolume:usbVolumeURL copyArray:usbResources authorization:authData withReply:^(NSError *error, int terminationStatus) {
                if ( terminationStatus == 0 ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self mountNetInstallDiskImage:workflowItem usbVolumeURL:usbVolumeURL];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_delegate postWorkflowTasksFailedWithError:error];
                    });
                }
            }];
        });
    } else {
        
    }
} // copyFilesToUSBVolume

- (void)mountNetInstallDiskImage:(NBCWorkflowItem *)workflowItem usbVolumeURL:(NSURL *)usbVolumeURL {
    
    NSError *err = nil;
    NSURL *nbiURL = [workflowItem temporaryNBIURL];
    
    NSString *netInstallRootPath = [NSDictionary dictionaryWithContentsOfURL:[nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"]][@"RootPath"] ?: @"";
    DDLogDebug(@"[DEBUG] NBImageInfo RootPath: %@", netInstallRootPath);
    if ( [netInstallRootPath length] == 0 ) {
        [_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"Could not get the root path from NBImageInfo.plist"]];
    }
    
    NSString *netInstallDMGPath = [[[nbiURL URLByAppendingPathComponent:netInstallRootPath] path] stringByResolvingSymlinksInPath];
    DDLogDebug(@"[DEBUG] NetInstall DMG path: %@", netInstallDMGPath);
    NSURL *netInstallDMGURL = [NSURL fileURLWithPath:netInstallDMGPath];
    if ( ! [netInstallDMGURL checkResourceIsReachableAndReturnError:&err] ) {
        [_delegate postWorkflowTasksFailedWithError:err];
        return;
    }
    
    NSMutableArray *modifyDictArray = [NSMutableArray array];
    NBCSource *tmpSource = [[NBCSource alloc] init];
    BOOL isBaseSystem = [NBCDiskImageController verifyBaseSystemDiskImage:netInstallDMGURL source:tmpSource error:nil];
    [tmpSource detachAll];
    DDLogDebug(@"[DEBUG] NetInstall is BaseSystem: %@", ( isBaseSystem ) ? @"YES" : @"NO");
    [NBCWorkflowResourcesModify modifyBootPlistForUSB:modifyDictArray netInstallDiskImageURL:netInstallDMGURL netInstallIsBaseSystem:isBaseSystem usbVolumeURL:usbVolumeURL];
    
    if ( [modifyDictArray count] != 0 ) {
        
        DDLogInfo(@"Applying modifications to volume...");
        [_progressDelegate updateProgressStatus:@"Applying modifications to volume..." workflow:self];
        
        // --------------------------------
        //  Get Authorization
        // --------------------------------
        NSData *authData = [workflowItem authData];
        if ( ! authData ) {
            authData = [NBCHelperAuthorization authorizeHelper:&err];
            if ( err ) {
                DDLogError(@"[ERROR] %@", [err localizedDescription]);
            }
            [workflowItem setAuthData:authData];
        }
        
        dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(taskQueue, ^{
            
            NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
            [helperConnector connectToHelper];
            [[helperConnector connection] setExportedObject:[workflowItem progressView]];
            [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
            [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate postWorkflowTasksFailedWithError:proxyError];
                });
            }] modifyResourcesOnVolume:usbVolumeURL modificationsArray:modifyDictArray authorization:authData withReply:^(NSError *error, int terminationStatus) {
                if ( terminationStatus == 0 ) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self blessUSBVolumeAtURL:usbVolumeURL workflowItem:workflowItem];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_delegate postWorkflowTasksFailedWithError:error];
                    });
                }
            }];
        });
    }
}

- (void)blessUSBVolumeAtURL:(NSURL *)usbVolumeURL workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Blessing USB volume...");
    [_progressDelegate updateProgressStatus:@"Blessing USB volume..." workflow:self];
    
    NSError *err = nil;
    
    NSString *label = @"ImagrUSB";
    
    // --------------------------------
    //  Get Authorization
    // --------------------------------
    NSData *authData = [workflowItem authData];
    if ( ! authData ) {
        authData = [NBCHelperAuthorization authorizeHelper:&err];
        if ( err ) {
            DDLogError(@"[ERROR] %@", [err localizedDescription]);
        }
        [workflowItem setAuthData:authData];
    }
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:[workflowItem progressView]];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_delegate postWorkflowTasksFailedWithError:proxyError];
            });
        }] blessUSBVolumeAtURL:usbVolumeURL label:label authorization:authData withReply:^(NSError *error, int terminationStatus) {
            if ( terminationStatus == 0 ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finalizeCreateUSBDevice:usbVolumeURL workflowItem:workflowItem];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_delegate postWorkflowTasksFailedWithError:error];
                });
            }
        }];
    });
}

- (void)finalizeCreateUSBDevice:(NSURL *)usbVolumeURL workflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Finalizing USB volume...");
    [_progressDelegate updateProgressStatus:@"Finalizing USB volume..." workflow:self];
    
    NSError *error = nil;
    NSURL *nbiURL = [workflowItem temporaryNBIURL];
    
    NSString *netInstallRootPath = [NSDictionary dictionaryWithContentsOfURL:[nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"]][@"RootPath"] ?: @"";
    DDLogDebug(@"[DEBUG] NBImageInfo RootPath: %@", netInstallRootPath);
    if ( [netInstallRootPath length] == 0 ) {
        [_delegate postWorkflowTasksFailedWithError:[NBCError errorWithDescription:@"Could not get the root path from NBImageInfo.plist"]];
    }
    
    NSString *netInstallDMGPath = [[[nbiURL URLByAppendingPathComponent:netInstallRootPath] path] stringByResolvingSymlinksInPath];
    DDLogDebug(@"[DEBUG] NetInstall DMG path: %@", netInstallDMGPath);
    NSURL *netInstallDMGURL = [NSURL fileURLWithPath:netInstallDMGPath];
    if ( ! [netInstallDMGURL checkResourceIsReachableAndReturnError:&error] ) {
        [_delegate postWorkflowTasksFailedWithError:error];
        return;
    }
    
    NSArray *usbVolumeRootContent = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:usbVolumeURL
                                                                  includingPropertiesForKeys:@[ (NSString *)kCFURLIsDirectoryKey ]
                                                                                     options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                       error:nil];
    
    NSNumber *isDirectory = nil;
    NSString *netInstallDiskImageName = [netInstallDMGURL lastPathComponent];
    DDLogDebug(@"[DEBUG] Hiding system folders in USB volume root...");
    
    // Hide all folders except the NetInstall disk image
    for ( NSURL *url in usbVolumeRootContent ) {
        [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error];
        if ( [isDirectory boolValue] && ! [[url lastPathComponent] isEqualToString:netInstallDiskImageName] ) {
            if ( ! [url setResourceValue:@YES forKey:NSURLIsHiddenKey error:&error] ) {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
        }
    }
    
    [_delegate postWorkflowTasksCompleted];
}

@end
