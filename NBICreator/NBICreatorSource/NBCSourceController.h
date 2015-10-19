//
//  NBCSourceController.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NBCDisk;
@class NBCSource;
@class NBCWorkflowItem;

@protocol NBCSourceControllerDelegate
- (void)dependencyCheckComplete:(NSDictionary *)sourceItemsDict workflowItem:(NBCWorkflowItem *)workflowItem;
@end

@interface NBCSourceController : NSObject

@property (nonatomic, weak) id delegate;

- (id)initWithDelegate:(id<NBCSourceControllerDelegate>)delegate;

// ------------------------------------------------------
//  Drop Destination
// ------------------------------------------------------
- (BOOL)getInstallESDURLfromSourceURL:(NSURL *)sourceURL source:(NBCSource *)source error:(NSError **)error;

// ------------------------------------------------------
//  System
// ------------------------------------------------------
- (BOOL)verifySystemFromDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error;
- (BOOL)verifySystemFromDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error;

// ------------------------------------------------------
//  Recovery Partition
// ------------------------------------------------------
- (BOOL)verifyRecoveryPartitionFromSystemDisk:(NBCDisk *)systemDisk source:(NBCSource *)source error:(NSError **)error;
- (BOOL)verifyRecoveryPartitionFromSystemDiskImageURL:(NSURL *)systemDiskImageURL source:(NBCSource *)source error:(NSError **)error;

// ------------------------------------------------------
//  Base System
// ------------------------------------------------------
- (BOOL)verifyBaseSystemFromSource:(NBCSource *)source error:(NSError **)error;

// ------------------------------------------------------
//  InstallESD
// ------------------------------------------------------
- (BOOL)verifyInstallESDFromDiskImageURL:(NSURL *)installESDDiskImageURL source:(NBCSource *)source error:(NSError **)error;

- (BOOL)verifySourceIsMountedInstallESD:(NBCSource *)source;
- (BOOL)verifySourceIsMountedOSVolume:(NBCSource *)source;

// ------------------------------------------------------
//  Prepare Workflow
// ------------------------------------------------------
- (void)addDependenciesForBinaryAtPath:(NSString *)binaryPath sourceItemsDict:(NSMutableDictionary *)sourceItemsDict workflowItem:(NBCWorkflowItem *)workflowItem;
+ (void)addCasperImaging:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addLibSsl:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addDesktopPicture:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addNetworkd:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addKernel:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addSystemUIServer:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addSystemkeychain:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addSpctl:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addTaskgated:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addDtrace:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addAppleScript:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addConsole:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addRuby:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addNSURLStoraged:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addPython:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addNTP:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addVNC:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addARD:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;
+ (void)addKerberos:(NSMutableDictionary *)sourceItemsDict source:(NBCSource *)source;

@end
