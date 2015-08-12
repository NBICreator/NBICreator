//
//  NBCTargetController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-09.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NBCSource;
@class NBCTarget;
@class NBCWorkflowItem;

@interface NBCTargetController : NSObject

// ------------------------------------------------------
//  NBI
// ------------------------------------------------------
- (BOOL)applyNBISettings:(NSURL *)nbiURL workflowItem:(NBCWorkflowItem *)workflowItem error:(NSError **)error;

// ------------------------------------------------------
//  NetInstall
// ------------------------------------------------------
- (BOOL)attachNetInstallDiskImageWithShadowFile:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error;
- (BOOL)convertNetInstallFromShadow:(NBCTarget *)target error:(NSError **)error;
- (BOOL)verifyNetInstallFromDiskImageURL:(NSURL *)netInstallDiskImageURL target:(NBCTarget *)target error:(NSError **)error;

// ------------------------------------------------------
//  BaseSystem
// ------------------------------------------------------
- (BOOL)attachBaseSystemDiskImageWithShadowFile:(NSURL *)baseSystemDiskImageURL target:(NBCTarget *)target error:(NSError **)error;
- (BOOL)convertBaseSystemFromShadow:(NBCTarget *)target error:(NSError **)error;
- (BOOL)verifyBaseSystemFromTarget:(NBCTarget *)target source:(NBCSource *)source error:(NSError **)error;

// ------------------------------------------------------
//  Copy
// ------------------------------------------------------
- (BOOL)copyResourcesToVolume:(NSURL *)volumeURL resourcesDict:(NSDictionary *)resourcesDict target:(NBCTarget *)target  error:(NSError **)error;
- (void)modifySettingsForLanguageAndKeyboardLayout:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifySettingsForSystemKeychain:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifySettingsForMenuBar:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifySettingsForVNC:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifySettingsAddFolders:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifyNBIRemoveWiFi:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;
- (void)modifyNBINTP:(NSMutableArray *)modifyDictArray workflowItem:(NBCWorkflowItem *)workflowItem;

@end
