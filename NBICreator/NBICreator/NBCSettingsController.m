//
//  NBCSharedSettingsController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-19.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCSettingsController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NBCWorkflowManager.h"

#import "NBCImagrSettingsViewController.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCSettingsController

#pragma mark -
#pragma mark
#pragma mark -

- (NSDictionary *)verifySettings:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    // ------------------------------------------------------------------------
    //  Check if current settings are equal to any currently queued workflow
    // ------------------------------------------------------------------------
    NSDictionary *settingsEqualToQueuedWorkflow = [self verifySettingsEqualToQueuedWorkflow:workflowItem];
    [settings addObject:settingsEqualToQueuedWorkflow];
    
    // ------------------------------------------------------------------------
    //  Check all settings in the tab "General"
    // ------------------------------------------------------------------------
    NSDictionary *settingsTabGeneral = [self verifySettingsTabGeneral:workflowItem];
    [settings addObject:settingsTabGeneral];
    
    switch ( [workflowItem workflowType] ) {
        case kWorkflowTypeNetInstall:
        {
            break;
        }
        case kWorkflowTypeDeployStudio:
        {
            // ----------------------------------------------------------------------------
            //  Check if any mounted volume name interferes with the DeployStudio workflow
            // ----------------------------------------------------------------------------
            NSDictionary *mountedVolumes = [self verifyMountedVolumeName:workflowItem];
            [settings addObject:mountedVolumes];
            
            break;
        }
        case kWorkflowTypeImagr:
        {
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Options"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabOptions = [self verifySettingsTabOptions:workflowItem];
            [settings addObject:settingsTabOptions];
            
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Extra"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabExtra = [self verifySettingsTabExtra:workflowItem];
            [settings addObject:settingsTabExtra];
            
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Imagr"
            // ------------------------------------------------------------------------
            NSDictionary *settingsLocalImagrURL = [self verifySettingsLocalImagrURL:workflowItem];
            [settings addObject:settingsLocalImagrURL];
            
            NSDictionary *settingsConfigurationURL = [self verifySettingsConfigurationURL:workflowItem];
            [settings addObject:settingsConfigurationURL];
            
            NSDictionary *settingsReportingURL = [self verifySettingsReportingURL:workflowItem];
            [settings addObject:settingsReportingURL];
            
            NSDictionary *settingsRemoteManagement = [self verifySettingsRemoteManagement:workflowItem];
            [settings addObject:settingsRemoteManagement];
            
            break;
        }
        default:
            break;
    }
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for ( NSDictionary *dict in settings ) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)createErrorInfoDictFromError:(NSArray *)error warning:(NSArray *)warning {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableDictionary *errorInfoDict = [[NSMutableDictionary alloc] init];
    
    if ( [error count] != 0 ) {
        errorInfoDict[NBCSettingsError] = error;
    }
    
    if ( [warning count] != 0 ) {
        errorInfoDict[NBCSettingsWarning] = warning;
    }
    
    return [errorInfoDict copy];
}

#pragma mark -
#pragma mark Settings Tabs
#pragma mark -

- (NSDictionary *)verifySettingsTabGeneral:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsNBIName = [self verifySettingsNBIName:workflowItem];
    [settings addObject:settingsNBIName];
    
    NSDictionary *settingsNBIIndex = [self verifySettingsNBIIndex:workflowItem];
    [settings addObject:settingsNBIIndex];
    
    NSDictionary *settingsNBIDestinationFolder = [self verifySettingsDestinationFolder:workflowItem];
    [settings addObject:settingsNBIDestinationFolder];
    
    NSDictionary *settingsNBIURL = [self verifySettingsNBIURL:workflowItem];
    [settings addObject:settingsNBIURL];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for ( NSDictionary *dict in settings ) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];;
} // verifySettingsTabGeneral

- (NSDictionary *)verifySettingsTabOptions:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsNBINTP = [self verifySettingsNBINTP:workflowItem];
    [settings addObject:settingsNBINTP];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for ( NSDictionary *dict in settings ) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
} // verifySettingsTabOptions

- (NSDictionary *)verifySettingsTabExtra:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsPackages = [self verifySettingsPackages:workflowItem];
    [settings addObject:settingsPackages];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for ( NSDictionary *dict in settings ) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
} // verifySettingsTabExtra

#pragma mark -
#pragma mark
#pragma mark -

- (NSDictionary *)verifySettingsPackages:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *userSettings = [[workflowItem userSettings] mutableCopy];
    
    NSArray *packages = userSettings[NBCSettingsPackages];
    
    for ( NSString *packagePath in packages ) {
        NSURL *packageURL = [NSURL fileURLWithPath:packagePath];
        if ( ! [packageURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsErrors addObject:[NSString stringWithFormat:@"Installer Package \"%@\" could not be found!", [packageURL lastPathComponent]]];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsRemoteManagement:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *userSettings = [[workflowItem userSettings] mutableCopy];
    
    BOOL ardLoginSet = NO;
    NSString *ardLogin = userSettings[NBCSettingsARDLoginKey];
    if ( [ardLogin length] != 0 ) {
        ardLoginSet = YES;
        if ( [ardLogin containsString:@"%"] ) { // Check characters
            [settingsErrors addObject:@"\"ARD Login\" contains unallowed characters"];
        }
    }
    
    BOOL ardPasswordSet = NO;
    NSString *ardPassword = userSettings[NBCSettingsARDPasswordKey];
    if ( [ardPassword length] != 0 ) {
        ardPasswordSet = YES;
        if ( [ardPassword containsString:@"%"] ) {
            // Escape password for shell?
        }
    }
    
    if ( ardLoginSet == YES && ardPasswordSet == NO ) {
        [settingsErrors addObject:@"\"ARD Password\" is not set"];
    } else if ( ardLoginSet == NO && ardPasswordSet == YES ) {
        userSettings[NBCSettingsARDLoginKey] = @"imagr";
        [workflowItem setUserSettings:[userSettings copy]];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsNBINTP:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiNTP = userSettings[NBCSettingsNetworkTimeServerKey];
    
    if ( [nbiNTP length] != 0 ) {
        NSURL *nbiNTPURL = [NSURL URLWithString:nbiNTP];
        if ( ! nbiNTPURL ) {
            [settingsErrors addObject:@"\"Network Time Server\" invalid hostname"];
        } else {
            NSTask *newTask =  [[NSTask alloc] init];
            [newTask setLaunchPath:@"/usr/bin/dig"];
            NSMutableArray *args = [NSMutableArray arrayWithObjects:
                                    @"+short",
                                    nbiNTP,
                                    nil];
            [newTask setArguments:args];
            [newTask setStandardOutput:[NSPipe pipe]];
            [newTask launch];
            [newTask waitUntilExit];
            
            NSData *newTaskStandardOutputData = [[newTask.standardOutput fileHandleForReading] readDataToEndOfFile];
            
            if ( [newTask terminationStatus] == 0 ) {
                NSString *digOutput = [[NSString alloc] initWithData:newTaskStandardOutputData encoding:NSUTF8StringEncoding];
                if ( [digOutput length] == 0 ) {
                    [settingsWarnings addObject:@"\"Network Time Server\" did not resolve"];
                }
            } else {
                [settingsWarnings addObject:@"\"Network Time Server\" did not resolve"];
            }
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsEqualToQueuedWorkflow:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [[workflowItem userSettings] mutableCopy];
    NSArray *currentWorkflowQueue = [[[NBCWorkflowManager sharedManager] workflowQueue] copy];
    
    for ( NBCWorkflowItem *queueItem in currentWorkflowQueue ) {
        NSDictionary *queueItemSettings = [queueItem userSettings];
        if ( [userSettings isEqualToDictionary:queueItemSettings] ) {
            [settingsWarnings addObject:@"Current settings are identical to an already running workflow"];
        }
    }
    
    return [self createErrorInfoDictFromError:nil warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsNBIName:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiName = [NBCVariables expandVariables:userSettings[NBCSettingsNBIName]
                                               source:[workflowItem source]
                                    applicationSource:[workflowItem applicationSource]];
    
    if ( [nbiName length] != 0 ) {
        if ( [nbiName containsString:@"%"] ) {
            [settingsWarnings addObject:@"\"Name\" might contain an uncomplete variable"];
        }
        
        [workflowItem setNbiName:[NSString stringWithFormat:@"%@.nbi", nbiName]];
    } else {
        [settingsErrors addObject:@"\"Name\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsNBIIndex:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiIndexString = [NBCVariables expandVariables:userSettings[NBCSettingsNBIIndex]
                                                      source:[workflowItem source]
                                           applicationSource:[workflowItem applicationSource]];
    
    NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
    NSNumber *nbiIndex = [nf numberFromString:nbiIndexString];
    
    if ( [nbiIndexString length] != 0 ) {
        if ( nbiIndex != nil ) {
            if ( 1 <= [nbiIndex integerValue] && [nbiIndex integerValue] <= 65535 ) {
                
            } else {
                [settingsErrors addObject:@"\"Index\" may only contain a number between 1 and 65535"];
            }
        } else {
            [settingsErrors addObject:@"\"Index\" may only contain numbers"];
        }
    } else {
        [settingsErrors addObject:@"\"Index\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsDestinationFolder:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *destinationFolderPath = [userSettings[NBCSettingsNBIDestinationFolder] stringByExpandingTildeInPath];
    NSURL *destinationFolderURL = [NSURL fileURLWithPath:destinationFolderPath];
    if ( destinationFolderPath != nil ) {
        if ( [destinationFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            int freeDiskSpace = [self getFreeDiskSpaceInGBFromPath:destinationFolderPath];
            
            NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
            NSNumber *minDiskSpaceAllowed = [nf numberFromString:NBCTargetFolderMinFreeSizeInGB];
            
            if ( freeDiskSpace < [minDiskSpaceAllowed integerValue] ) {
                [settingsErrors addObject:[NSString stringWithFormat:@"Not enough room to create NBI. Minimum space required is %ld GB, currently only %d GB is free", (long)[minDiskSpaceAllowed integerValue], freeDiskSpace]];
            }
        } else {
            [settingsWarnings addObject:@"\"Destination Folder\" doesn't exist, it will be created"];
        }
        
        NSString *nbiName = [workflowItem nbiName];
        if ( [nbiName length] != 0 ) {
            NSURL *nbiURL = [destinationFolderURL URLByAppendingPathComponent:nbiName];
            [workflowItem setDestinationFolder:destinationFolderPath];
            [workflowItem setNbiURL:nbiURL];
        }
    } else {
        [settingsErrors addObject:@"\"Destination Folder\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsNBIURL:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSURL *nbiURL = [workflowItem nbiURL];
    if ( nbiURL != nil ) {
        if ( [nbiURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsWarnings addObject:@"There already exist an item with the same name at the selected destination. If you continue, it will be overwritten."];
        }
    } else {
        [settingsErrors addObject:@"\"NBI URL\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifyMountedVolumeName:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSURL *deployStudioRuntimeMountVolume = [NSURL fileURLWithPath:@"/Volumes/DeployStudioRuntime"];
    if ( [deployStudioRuntimeMountVolume checkResourceIsReachableAndReturnError:nil] ) {
        [settingsErrors addObject:@"There is already a volume mounted at the following path: /Volumes/DeployStudioRuntime.\n\nDeployStudioAssistant will fail if there is another volume mounted with the same name. Unmount the current volume and try again."];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (int)getFreeDiskSpaceInGBFromPath:(NSString *)path {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    int freeDiskSpace = -1;
    
    NSError *error;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:&error];
    if ( fileAttributes != nil ) {
        double freeDiskSpaceBytes = [fileAttributes[NSFileSystemFreeSize] doubleValue];
        
        NSByteCountFormatter *bcf = [[NSByteCountFormatter alloc] init];
        [bcf setAllowedUnits:NSByteCountFormatterUseGB];
        [bcf setCountStyle:NSByteCountFormatterCountStyleFile];
        [bcf setAllowsNonnumericFormatting:NO];
        [bcf setIncludesCount:YES];
        [bcf setIncludesUnit:NO];
        NSString *string = [bcf stringFromByteCount:(long long)freeDiskSpaceBytes];
        
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        [nf setNumberStyle:NSNumberFormatterDecimalStyle];
        NSNumber *freeDiskSpaceDecimal = [nf numberFromString:string];
        
        if ( freeDiskSpaceDecimal != nil ) {
            freeDiskSpace = (int)[freeDiskSpaceDecimal integerValue];
        }
    } else {
        NSLog(@"Could not get fileAttributes");
        NSLog(@"Error: %@", error);
    }
    
    return freeDiskSpace;
}

- (NSDictionary *)verifySettingsConfigurationURL:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *imagrConfigurationURLString = userSettings[NBCSettingsImagrConfigurationURL];
    NSURL *imagrConfigurationURL = [NSURL URLWithString:imagrConfigurationURLString];
    if ( [imagrConfigurationURLString length] != 0 ) {
        if ( [imagrConfigurationURLString hasPrefix:@"http://"] || [imagrConfigurationURLString hasPrefix:@"https://"] ) {
            if ( imagrConfigurationURL != nil ) {
                NSString *imagrConfigurationURLHost = [imagrConfigurationURL host];
                if ( [imagrConfigurationURLHost length] == 0 ) {
                    [settingsErrors addObject:@"\"Configuration URL\" hostname or IP cannot be empty"];
                }
            } else {
                [settingsErrors addObject:@"\"Configuration URL\" is not a valid URL"];
            }
        } else {
            [settingsErrors addObject:@"\"Configuration URL\" need to use http:// or https://"];
        }
    } else {
        [settingsErrors addObject:@"\"Configuration URL\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsReportingURL:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *imagrConfigurationURLString = userSettings[NBCSettingsImagrReportingURL];
    NSURL *imagrConfigurationURL = [NSURL URLWithString:imagrConfigurationURLString];
    if ( [imagrConfigurationURLString length] != 0 ) {
        if ( [imagrConfigurationURLString hasPrefix:@"http://"] || [imagrConfigurationURLString hasPrefix:@"https://"] ) {
            if ( imagrConfigurationURL != nil ) {
                NSString *imagrConfigurationURLHost = [imagrConfigurationURL host];
                if ( [imagrConfigurationURLHost length] == 0 ) {
                    [settingsErrors addObject:@"\"Reporting URL\" hostname or IP cannot be empty"];
                }
            } else {
                [settingsErrors addObject:@"\"Reporting URL\" is not a valid URL"];
            }
        } else {
            [settingsErrors addObject:@"\"Reporting URL\" need to use http:// or https://"];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsLocalImagrURL:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    if ( [userSettings[NBCSettingsImagrUseLocalVersion] boolValue] ) {
        NSString *imagrLocalVersionURLString = userSettings[NBCSettingsImagrLocalVersionPath];
        if ( [imagrLocalVersionURLString length] != 0 ) {
            NSURL *imagrLocalVersionURL = [NSURL URLWithString:imagrLocalVersionURLString];
            if ( ! [imagrLocalVersionURL checkResourceIsReachableAndReturnError:nil] ) {
                [settingsErrors addObject:@"\"Local Version URL\" is not valid"];
            }
        } else {
            [settingsErrors addObject:@"\"Local Version URL\" cannot be empty"];
        }
    }
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

@end
