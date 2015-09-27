//
//  NBCWorkflowNetInstallModifyNBI.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCNetInstallWorkflowModifyNBI.h"
#import "NBCConstants.h"
#import "NSString+randomString.h"

#import "NBCWorkflowItem.h"

#import "NBCTargetController.h"

#import "NBCDisk.h"
#import "NBCDiskImageController.h"
#import "NBCLogging.h"
#import "NBCTarget.h"
#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

DDLogLevel ddLogLevel;

@implementation NBCNetInstallWorkflowModifyNBI

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Workflow
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)runWorkflow:(NBCWorkflowItem *)workflowItem {
    
    NSError *error;
    [self setWorkflowItem:workflowItem];
    [self setTarget:[workflowItem target]];
    _targetController = [[NBCTargetController alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_delegate updateProgressStatus:@"Adding resources to NBI" workflow:self];
        [self->_delegate updateProgressBar:91];
    });
    
    NSURL *temporaryNBIURL = [workflowItem temporaryNBIURL];
    if ( temporaryNBIURL ) {
        // ---------------------------------------------------------------
        //  Apply all settings to NBImageInfo.plist in NBI
        // ---------------------------------------------------------------
        if ( [_targetController applyNBISettings:temporaryNBIURL workflowItem:workflowItem error:&error] ) {
            [self modifyNetInstall];
        } else {
            NSLog(@"Error when applying NBImageInfo settings");
            NSLog(@"Error: %@", error);
            
            NSDictionary *userInfo = @{ NBCUserInfoNSErrorKey : error };
            [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:userInfo];
        }
    } else {
        NSLog(@"Could not get temporary NBI url from workflowItem");
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
    }
} // runWorkflow

- (BOOL)modifyNetInstall {
    BOOL verified = YES;
    NSError *error;
    
    NSURL *nbiNetInstallURL = [_target nbiNetInstallURL];
    if ( nbiNetInstallURL ) {
        
        // ------------------------------------------------------------------
        //  Attach NetInstall disk image using a shadow image to make it r/w
        // ------------------------------------------------------------------
        if ( [_targetController attachNetInstallDiskImageWithShadowFile:nbiNetInstallURL target:_target error:&error] ) {
            [self->_delegate updateProgressBar:92];
            
            [self copyFilesToNetInstall];
            
        } else {
            DDLogError(@"[ERROR] Attaching NetInstall Failed!");
            DDLogError(@"%@", error);
            verified = NO;
        }
    } else {
        DDLogError(@"[ERROR] Could not get netInstallURL from target!");
        verified = NO;
    }
    
    return verified;
} // modifyNetInstall

- (void)copyFilesToNetInstall {
    DDLogInfo(@"Copying files to NetInstall volume...");
    [_delegate updateProgressStatus:@"Copying files to NetInstall..." workflow:self];
    
    // ---------------------------------------------------------
    //  Copy all files in resourcesBaseSystemDict to BaseSystem
    // ---------------------------------------------------------
    NSDictionary *resourcesNetInstallDict = [_target resourcesNetInstallDict];
    NSLog(@"resourcesNetInstallDict=%@", resourcesNetInstallDict);
    NSURL *volumeURL = [_target nbiNetInstallVolumeURL];
    
    NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
    [helperConnector connectToHelper];
    
    [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            [self copyFailed:proxyError];
        }];
        
    }] copyResourcesToVolume:volumeURL resourcesDict:resourcesNetInstallDict withReply:^(NSError *error, int terminationStatus) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if ( terminationStatus == 0 ) {
                [self finalizeWorkflow];
            } else {
                DDLogError(@"[ERROR] Error while copying resources to NetInstall volume!");
                [self copyFailed:error];
            }
        }];
    }];
} // copyFilesToNetInstall

- (void)copyFailed:(NSError *)error {
    DDLogError(@"[ERROR] Copy Failed!");
    if ( error ) {
        DDLogError(@"[ERROR] %@", error);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed object:self userInfo:nil];
} // copyFailed

- (void)finalizeWorkflow {
    NSError *error;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSURL *baseSystemDiskImageURL = [_target baseSystemURL];
    
    // ------------------------------------------------------
    //  Convert and rename NetInstall image from shadow file
    // ------------------------------------------------------
    if ( [_targetController convertNetInstallFromShadow:_workflowItem error:&error] ) {
        if ( ! [userSettings[NBCSettingsDiskImageReadWriteKey] boolValue] ) {
            [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                              object:self
                            userInfo:nil];
            return;
        } else {
            if ( [self createSymlinkToSparseimageAtURL:[_target nbiNetInstallURL]] ) {
                [baseSystemDiskImageURL setResourceValue:@YES forKey:NSURLIsHiddenKey error:NULL];
                [nc postNotificationName:NBCNotificationWorkflowCompleteModifyNBI
                                  object:self
                                userInfo:nil];
                return;
            } else {
                DDLogError(@"[ERROR] Could not create synmlink for sparseimage");
                [nc postNotificationName:NBCNotificationWorkflowFailed
                                  object:self
                                userInfo:nil];
                return;
            }
        }
    } else {
        DDLogError(@"[ERROR] Converting NetIstall from shadow failed!");
        NSDictionary *userInfo = nil;
        if ( error ) {
            DDLogError(@"[ERROR] %@", error);
            userInfo = @{ NBCUserInfoNSErrorKey : error };
        }
        [nc postNotificationName:NBCNotificationWorkflowFailed
                          object:self
                        userInfo:userInfo];
        return;
    }
} // finalizeWorkflow

- (BOOL)createSymlinkToSparseimageAtURL:(NSURL *)sparseImageURL {
    BOOL retval = NO;
    
    NSString *sparseImageFolderPath = [[sparseImageURL URLByDeletingLastPathComponent] path];
    NSString *sparseImageName = [[sparseImageURL lastPathComponent] stringByDeletingPathExtension];
    NSString *sparseImagePath = [NSString stringWithFormat:@"%@.sparseimage", sparseImageName];
    NSString *dmgLinkPath = [NSString stringWithFormat:@"%@.dmg", sparseImageName];
    
    NSTask *newTask =  [[NSTask alloc] init];
    [newTask setLaunchPath:@"/bin/ln"];
    NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-s", sparseImagePath, dmgLinkPath, nil];
    if ( [sparseImageFolderPath length] != 0 ) {
        [newTask setCurrentDirectoryPath:sparseImageFolderPath];
        [newTask setArguments:args];
        [newTask launch];
        [newTask waitUntilExit];
        
        if ( [newTask terminationStatus] == 0 ) {
            retval = YES;
        } else {
            retval = NO;
        }
    } else {
        retval = NO;
    }
    
    return retval;
} // createSymlinkToSparseimageAtURL

@end
