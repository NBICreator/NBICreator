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

#import "NBCImagrSettingsViewController.h"

@implementation NBCSettingsController

- (NSDictionary *)createErrorInfoDictFromError:(NSArray *)error warning:(NSArray *)warning {
    NSMutableDictionary *errorInfoDict = [[NSMutableDictionary alloc] init];
    
    if ( [error count] != 0 ) {
        errorInfoDict[NBCSettingsError] = error;
    }
    
    if ( [warning count] != 0 ) {
        errorInfoDict[NBCSettingsWarning] = warning;
    }
    
    return [errorInfoDict copy];
}

- (NSDictionary *)verifySettingsDeployStudio:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsGeneral = [self verifySettingsGeneral:workflowItem];
    [settings addObject:settingsGeneral];
    
    NSDictionary *mountedVolumes = [self verifyMountedVolumeName:workflowItem];
    [settings addObject:mountedVolumes];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dict in settings) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}


- (NSDictionary *)verifySettingsNetInstall:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsGeneral = [self verifySettingsGeneral:workflowItem];
    [settings addObject:settingsGeneral];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dict in settings) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsImagr:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsGeneral = [self verifySettingsGeneral:workflowItem];
    [settings addObject:settingsGeneral];
    
    NSDictionary *settingsOptions = [self verifySettingsOptions:workflowItem];
    [settings addObject:settingsOptions];
    
    NSDictionary *settingsConfigurationURL = [self verifySettingsConfigurationURL:workflowItem];
    [settings addObject:settingsConfigurationURL];
    
    NSDictionary *settingsRemoteManagement = [self verifySettingsRemoteManagement:workflowItem];
    [settings addObject:settingsRemoteManagement];
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    for (NSDictionary *dict in settings) {
        NSArray *errorArr = dict[NBCSettingsError];
        if ( [errorArr count] != 0 ) {
            [settingsErrors addObjectsFromArray:errorArr];
        }
        
        NSArray *warningArr = dict[NBCSettingsWarning];
        if ( [warningArr count] != 0 ) {
            [settingsWarnings addObjectsFromArray:warningArr];
        }
    }
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsRemoteManagement:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsOptions:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsGeneral:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsNBINTP:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsNBIName:(NBCWorkflowItem *)workflowItem
{
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsNBIIndex:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsDestinationFolder:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifySettingsNBIURL:(NBCWorkflowItem *)workflowItem {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (NSDictionary *)verifyMountedVolumeName:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSURL *deployStudioRuntimeMountVolume = [NSURL fileURLWithPath:@"/Volumes/DeployStudioRuntime"];
    if ( [deployStudioRuntimeMountVolume checkResourceIsReachableAndReturnError:nil] ) {
        [settingsErrors addObject:@"There is already a volume mounted at the following path: /Volumes/DeployStudioRuntime.\n\nDeployStudioAssistant will fail if there is another volume mounted with the same name. Unmount the current volume and try again."];
    }
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

- (int)getFreeDiskSpaceInGBFromPath:(NSString *)path {
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
    
    NSDictionary *errorInfoDict = [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
    
    return errorInfoDict;
}

@end
