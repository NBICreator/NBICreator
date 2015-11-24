//
//  NBCSharedSettingsController.m
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

#import "NBCSettingsController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import "NBCWorkflowManager.h"
#import "NSString+validIP.h"
#import "NBCWorkflowItem.h"
#import "NBCImagrSettingsViewController.h"
#import "NBCLogging.h"
#import "NBCApplicationSourceXcode.h"
#import "NBCSource.h"
#import "NBCError.h"
#import "NSString+SymlinksAndAliases.h"
#import "NBCHelperProtocol.h"
#import "NBCHelperConnection.h"
#import "NBCDiskImageController.h"
#import "NBCTarget.h"

DDLogLevel ddLogLevel;

@implementation NBCSettingsController

- (id)initWithDelegate:(id<NBCSettingsDelegate>)delegate {
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
    }
    return self;
} // init

#pragma mark -
#pragma mark
#pragma mark -

- (NSDictionary *)verifySettingsForWorkflowItem:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    NSDictionary *userSettings = [workflowItem userSettings];
    
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
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Post-Install"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabPostInstall = [self verifySettingsTabPostInstall:workflowItem];
            [settings addObject:settingsTabPostInstall];
            
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Advanced"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabAdvanced = [self verifySettingsTabAdvanced:workflowItem];
            [settings addObject:settingsTabAdvanced];
            
            break;
        }
        case kWorkflowTypeDeployStudio:
        {
            // ----------------------------------------------------------------------------
            //  Check if any mounted volume name interferes with the DeployStudio workflow
            // ----------------------------------------------------------------------------
            NSDictionary *mountedVolumes = [self verifyMountedVolumeName:workflowItem];
            [settings addObject:mountedVolumes];
            
            // ----------------------------------------------------------------------------
            //  Check that OS Version is working with current DeployStudio version
            // ----------------------------------------------------------------------------
            NSDictionary *osVersionForDeployStudio = [self verifySettingsOsVersionForDeployStudio:workflowItem];
            [settings addObject:osVersionForDeployStudio];
            
            break;
        }
        case kWorkflowTypeImagr:
        {
            // ------------------------------------------------------------------------
            //  Check that OS Version isn't lower than source for System Image Utility
            // ------------------------------------------------------------------------
            NSDictionary *osVersionForSystemImageUtility = [self verifySettingsOsVersionForSystemImageUtility:workflowItem];
            [settings addObject:osVersionForSystemImageUtility];
            
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
            //  Check all settings in the tab "Advanced"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabAdvanced = [self verifySettingsTabAdvanced:workflowItem];
            [settings addObject:settingsTabAdvanced];
            
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Imagr"
            // ------------------------------------------------------------------------
            NSDictionary *settingsLocalImagrURL = [self verifySettingsImagrLocalImagrURL:workflowItem];
            [settings addObject:settingsLocalImagrURL];
            
            NSDictionary *settingsConfigurationURL = [self verifySettingsImagrConfigurationURL:workflowItem];
            [settings addObject:settingsConfigurationURL];
            
            NSDictionary *settingsReportingURL = [self verifySettingsImagrReportingURL:workflowItem];
            [settings addObject:settingsReportingURL];
            
            if ( [userSettings[NBCSettingsImagrUseGitBranch] boolValue] ) {
                NSDictionary *settingsXcodeToolsInstalled = [self verifySettingsXcodeToolsInstalled];
                [settings addObject:settingsXcodeToolsInstalled];
            }
            
            break;
        }
        case kWorkflowTypeCasper:
        {
            // ------------------------------------------------------------------------
            //  Check that OS Version isn't lower than source for System Image Utility
            // ------------------------------------------------------------------------
            NSDictionary *osVersion = [self verifySettingsOsVersionForSystemImageUtility:workflowItem];
            [settings addObject:osVersion];
            
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
            //  Check all settings in the tab "Advanced"
            // ------------------------------------------------------------------------
            NSDictionary *settingsTabAdvanced = [self verifySettingsTabAdvanced:workflowItem];
            [settings addObject:settingsTabAdvanced];
            
            // ------------------------------------------------------------------------
            //  Check all settings in the tab "Casper"
            // ------------------------------------------------------------------------
            NSDictionary *settingsCasperImagingPath = [self verifySettingsCasperImagingPath:workflowItem];
            [settings addObject:settingsCasperImagingPath];
            
            NSDictionary *settingsCasperJSSURL = [self verifySettingsCasperJSSURL:workflowItem];
            [settings addObject:settingsCasperJSSURL];
            
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
    
    NSMutableDictionary *errorInfoDict = [[NSMutableDictionary alloc] init];
    
    if ( [error count] != 0 ) {
        errorInfoDict[NBCSettingsError] = error;
    }
    
    if ( [warning count] != 0 ) {
        errorInfoDict[NBCSettingsWarning] = warning;
    }
    
    return [errorInfoDict copy];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tabs
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsTabGeneral:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsNBIName = [self verifySettingsNBIName:workflowItem];
    [settings addObject:settingsNBIName];
    
    NSDictionary *settingsNBIIndex = [self verifySettingsNBIIndex:workflowItem];
    [settings addObject:settingsNBIIndex];
    
    if ( [[[workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        NSDictionary *settingsNBISource = [self verifySettingsNBISource:workflowItem];
        [settings addObject:settingsNBISource];
    } else {
        NSDictionary *settingsNBIDestinationFolder = [self verifySettingsDestinationFolder:workflowItem];
        [settings addObject:settingsNBIDestinationFolder];
        
        NSDictionary *settingsNBIURL = [self verifySettingsNBIURL:workflowItem];
        [settings addObject:settingsNBIURL];
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
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];;
} // verifySettingsTabGeneral

- (NSDictionary *)verifySettingsTabOptions:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    if ( [[workflowItem userSettings][NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
        NSDictionary *settingsNBINTP = [self verifySettingsNBINTP:workflowItem];
        [settings addObject:settingsNBINTP];
    }
    
    NSDictionary *settingsRemoteManagement = [self verifySettingsRemoteManagement:workflowItem];
    [settings addObject:settingsRemoteManagement];
    
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

- (NSDictionary *)verifySettingsTabAdvanced:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    if ( 11 <= sourceVersionMinor && [userSettings[NBCSettingsAddTrustedNetBootServersKey] boolValue] ) {
        NSDictionary *settingsTrustedNetBootServers = [self verifySettingsTrustedNetBootServers:workflowItem];
        [settings addObject:settingsTrustedNetBootServers];
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
} // verifySettingsTabAdvanced

- (NSDictionary *)verifySettingsTabPostInstall:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settings = [[NSMutableArray alloc] init];
    
    NSDictionary *settingsPackagesNetInstall = [self verifySettingsPackagesNetInstall:workflowItem];
    [settings addObject:settingsPackagesNetInstall];
    
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

/*
 - (NSDictionary *)verifySettingsTabDebug:(NBCWorkflowItem *)workflowItem {
 
 NSMutableArray *settings = [[NSMutableArray alloc] init];
 
 
 
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
 } // verifySettingsTabDebug
 */

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab General
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsNBIName:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiName = [NBCVariables expandVariables:userSettings[NBCSettingsNameKey]
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
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *nbiIndexString = [NBCVariables expandVariables:userSettings[NBCSettingsIndexKey]
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
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *destinationFolderPath = [userSettings[NBCSettingsDestinationFolderKey] stringByExpandingTildeInPath];
    if ( [destinationFolderPath length] != 0 ) {
        NSURL *destinationFolderURL = [NSURL fileURLWithPath:destinationFolderPath];
        if ( [destinationFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            int freeDiskSpace = [self getFreeDiskSpaceInGBFromPath:destinationFolderPath];
            
            NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
            NSNumber *minDiskSpaceAllowed = [nf numberFromString:NBCTargetFolderMinFreeSizeInGB];
            
            if ( freeDiskSpace < [minDiskSpaceAllowed integerValue] ) {
                [settingsErrors addObject:[NSString stringWithFormat:@"Not enough room to create NBI. Minimum space required is %ld GB, currently only %d GB is free", (long)[minDiskSpaceAllowed integerValue], freeDiskSpace]];
            }
            
            if ( ! [[NSFileManager defaultManager] isWritableFileAtPath:[destinationFolderURL path]] ) {
                [settingsErrors addObject:@"\"Destination Folder\" is read only. Please select a folder where you have write permissions"];
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

- (NSDictionary *)verifySettingsNBISource:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *destinationFolderPath = [userSettings[NBCSettingsDestinationFolderKey] stringByExpandingTildeInPath];
    if ( [destinationFolderPath length] != 0 ) {
        NSURL *destinationFolderURL = [NSURL fileURLWithPath:destinationFolderPath];
        if ( [destinationFolderURL checkResourceIsReachableAndReturnError:&error] ) {
            [workflowItem setDestinationFolder:destinationFolderPath];
            [workflowItem setNbiURL:destinationFolderURL];
            
            if ( ! [[NSFileManager defaultManager] isWritableFileAtPath:[destinationFolderURL path]] ) {
                [settingsErrors addObject:@"\"Destination Folder\" is read only, please move your NBI to a location where NBICreator have write permissions."];
            }
        } else {
            [settingsErrors addObject:[NSString stringWithFormat:@"%@", [error localizedDescription]]];
        }
    } else {
        [settingsErrors addObject:@"\"Destination Folder\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsNBIURL:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSURL *nbiURL = [workflowItem nbiURL];
    if ( nbiURL != nil ) {
        if ( [nbiURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsWarnings addObject:@"An item already exists with the same name at the selected destination. If you continue, it will be overwritten."];
        }
    } else {
        [settingsErrors addObject:@"\"NBI URL\" cannot be empty"];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Options
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

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
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Extra
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsPackages:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSArray *packages = [workflowItem userSettings][NBCSettingsPackagesKey];
    
    for ( NSString *packagePath in packages ) {
        NSURL *packageURL = [NSURL fileURLWithPath:packagePath];
        if ( ! [packageURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsErrors addObject:[NSString stringWithFormat:@"Installer Package \"%@\" could not be found!", [packageURL lastPathComponent]]];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Advanced
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsTrustedNetBootServers:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSArray *trustedNetBootServers = [workflowItem userSettings][NBCSettingsTrustedNetBootServersKey];
    
    if ( [trustedNetBootServers count] != 0 ) {
        
        NSMutableArray *invalidNetBootServers = [[NSMutableArray alloc] init];
        for ( NSString *netBootServer in trustedNetBootServers ) {
            if ( ! [netBootServer isValidIPAddress] ) {
                [invalidNetBootServers addObject:netBootServer];
            }
        }
        
        if ( [invalidNetBootServers count] != 0 ) {
            [settingsErrors addObject:[NSString stringWithFormat:@"\"Trusted NetBoot Servers\" contains %lu invalid IP addresses!", (unsigned long)[invalidNetBootServers count]]];
        }
    } else {
        [settingsErrors addObject:[NSString stringWithFormat:@"\"Add Trusted NetBoot Servers\" is enabled but you have not entered any IP addresses"]];
    }
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Debug
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Post-Install
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsPackagesNetInstall:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSArray *packages = [workflowItem userSettings][NBCSettingsNetInstallPackagesKey];
    
    for ( NSString *packagePath in packages ) {
        NSURL *packageURL = [NSURL fileURLWithPath:packagePath];
        if ( ! [packageURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsErrors addObject:[NSString stringWithFormat:@"Installer Package \"%@\" could not be found!", [packageURL lastPathComponent]]];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Imagr
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsImagrConfigurationURL:(NBCWorkflowItem *)workflowItem {
    
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

- (NSDictionary *)verifySettingsImagrReportingURL:(NBCWorkflowItem *)workflowItem {
    
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

- (NSDictionary *)verifySettingsImagrLocalImagrURL:(NBCWorkflowItem *)workflowItem {
    NSError *error;
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    if ( [userSettings[NBCSettingsImagrUseLocalVersion] boolValue] ) {
        NSString *imagrLocalVersionURLString = userSettings[NBCSettingsImagrLocalVersionPath];
        if ( [imagrLocalVersionURLString length] != 0 ) {
            NSURL *imagrLocalVersionURL = [NSURL fileURLWithPath:imagrLocalVersionURLString];
            if ( [imagrLocalVersionURL checkResourceIsReachableAndReturnError:&error] ) {
                NSBundle *bundle = [NSBundle bundleWithURL:imagrLocalVersionURL];
                if ( bundle != nil ) {
                    NSString *bundleIdentifier = [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
                    if ( ! [bundleIdentifier isEqualToString:NBCImagrBundleIdentifier] ) {
                        [settingsErrors addObject:[NSString stringWithFormat:@"\"Local Path\" - CFBundleIdentifier is %@. It should be %@", bundleIdentifier, NBCImagrBundleIdentifier]];
                    }
                } else {
                    [settingsErrors addObject:@"\"Local Path\" - Could not get bundle from path!"];
                }
            } else {
                [settingsErrors addObject:[NSString stringWithFormat:@"\"Local Path\" - %@", [error localizedDescription]]];
            }
        } else {
            [settingsErrors addObject:@"\"Local Path\" cannot be empty"];
        }
    }
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Tab Casper
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsCasperImagingPath:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *casperImagingPathString = userSettings[NBCSettingsCasperImagingPathKey];
    if ( [casperImagingPathString length] != 0 ) {
        NSURL *casperImagingURL = [NSURL fileURLWithPath:casperImagingPathString];
        if ( ! [casperImagingURL checkResourceIsReachableAndReturnError:nil] ) {
            [settingsErrors addObject:@"\"Casper Imaging App\" did not exist"];
        }
    } else {
        [settingsErrors addObject:@"\"Casper Imaging App\" cannot be empty"];
    }
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsCasperJSSURL:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSDictionary *userSettings = [workflowItem userSettings];
    NSString *casperJSSURLString = userSettings[NBCSettingsImagrReportingURL];
    NSURL *casperJSSURL = [NSURL URLWithString:casperJSSURLString];
    if ( [casperJSSURLString length] != 0 ) {
        if ( [casperJSSURLString hasPrefix:@"http://"] || [casperJSSURLString hasPrefix:@"https://"] ) {
            if ( casperJSSURL != nil ) {
                NSString *casperJSSURLHost = [casperJSSURL host];
                if ( [casperJSSURLHost length] == 0 ) {
                    [settingsErrors addObject:@"\"JSS URL\" hostname or IP cannot be empty"];
                }
            } else {
                [settingsErrors addObject:@"\"JSS URL\" is not a valid URL"];
            }
        } else {
            [settingsErrors addObject:@"\"JSS URL\" need to use http:// or https://"];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings Other
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)verifySettingsXcodeToolsInstalled {
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    if ( ! [NBCApplicationSourceXcode isInstalled] ) {
        [settingsErrors addObject:@"Xcode is not installed. You cannot compile Imagr from Git Branch until the required tools are installed."];
    } else {
        NSTask *newTask =  [[NSTask alloc] init];
        [newTask setLaunchPath:@"/usr/bin/xcodebuild"];
        [newTask setArguments:@[ @"-showsdks" ]];
        [newTask setStandardOutput:[NSPipe pipe]];
        [newTask setStandardError:[NSPipe pipe]];
        [newTask launch];
        [newTask waitUntilExit];
        
        if ( [newTask terminationStatus] == 69 ) {
            [settingsErrors addObject:@"Xcode licese have not been accepted. You need to open Xcode and accept the license agreement."];
        }
    }
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsOsVersionForDeployStudio:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSString *deployStudioVersion = [[workflowItem applicationSource] dsAdminVersion];
    int deployStudioVersionInt = [[deployStudioVersion stringByReplacingOccurrencesOfString:@"." withString:@""] intValue];
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    
    if ( 11 <= sourceVersionMinor ) {
        if ( deployStudioVersionInt <= 1616 ) {
            NSString *errorMessage = [NSString stringWithFormat:@"OS X %@ is not supported by DeployStudio version %@. Please upgrade DeployStudio to create a working NetInstall set.", [[workflowItem source] baseSystemOSVersion], deployStudioVersion];
            [settingsErrors addObject:errorMessage];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsOsVersionForSystemImageUtility:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    if ( [[[workflowItem userSettings] objectForKey:NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        int osVersionMinor = (int)version.minorVersion;
        int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
        if ( osVersionMinor < sourceVersionMinor ) {
            NSString *osVersionString = [NSString stringWithFormat:@"%ld.%ld.%ld", version.majorVersion, version.minorVersion, version.patchVersion];
            NSString *errorMessage = [NSString stringWithFormat:@"Source Version Mismatch.\nThis source contains OS X %@.\nYou are currently booted on OS X %@\n\nYou cannot create a NetInstall image using System Image Utility from sources with higher OS Minor Versions than your booted system.\n\nUse NBICreator as NetBoot creation tool instead, or use this software on a computer running %@", [[workflowItem source] baseSystemOSVersion], osVersionString, [[workflowItem source] baseSystemOSVersion]];
            [settingsErrors addObject:errorMessage];
        }
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
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
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
}

- (NSDictionary *)verifySettingsEqualToQueuedWorkflow:(NBCWorkflowItem *)workflowItem {
    
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

- (NSDictionary *)verifyMountedVolumeName:(NBCWorkflowItem *)workflowItem {
#pragma unused(workflowItem)
    
    NSMutableArray *settingsErrors = [[NSMutableArray alloc] init];
    NSMutableArray *settingsWarnings = [[NSMutableArray alloc] init];
    
    NSURL *deployStudioRuntimeMountVolume = [NSURL fileURLWithPath:@"/Volumes/DeployStudioRuntime"];
    if ( [deployStudioRuntimeMountVolume checkResourceIsReachableAndReturnError:nil] ) {
        [settingsErrors addObject:@"There is already a volume mounted at the following path: /Volumes/DeployStudioRuntime.\n\nDeployStudioAssistant will fail if there is another volume mounted with the same name. Unmount the current volume and try again."];
    }
    
    return [self createErrorInfoDictFromError:settingsErrors warning:settingsWarnings];
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Read Settings: NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)readSettingsFromNBI:(NBCSource *)source target:(NBCTarget *)target workflowType:(int)workflowType {
    
    DDLogInfo(@"Reading settings from NBI...");
    
    NSError *error;
    
    // -------------------------------------------------------------------------------
    //  NBI Path
    // -------------------------------------------------------------------------------
    NSURL *nbiURL = [source sourceURL];
    DDLogDebug(@"[DEBUG] NBI path: %@", [nbiURL path]);
    
    if ( ! [nbiURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  NBImageInfo path
    // -------------------------------------------------------------------------------
    NSURL *nbImageInfoURL = [source nbImageInfoURL];
    DDLogDebug(@"[DEBUG] NBImageInfo.plist path: %@", [nbImageInfoURL path]);
    
    if ( ! [nbImageInfoURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    if ( [nbiNetInstallVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
        
        // -------------------------------------------------------------------------------
        //  NBI Creation Tool
        // -------------------------------------------------------------------------------
        settingsDict[NBCSettingsNBICreationToolKey] = NBCMenuItemSystemImageUtility;
    } else if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
        
        // -------------------------------------------------------------------------------
        //  NBI Creation Tool
        // -------------------------------------------------------------------------------
        settingsDict[NBCSettingsNBICreationToolKey] = NBCMenuItemNBICreator;
    }
    
    // -------------------------------------------------------------------------------
    //  Static Values
    // -------------------------------------------------------------------------------
    settingsDict[NBCSettingsSourceIsNBI] =              @YES;
    settingsDict[NBCSettingsEnableLaunchdLoggingKey] =  @NO;
    
    // -------------------------------------------------------------------------------
    //  NBI Icon
    // -------------------------------------------------------------------------------
    NSImage *nbiIcon = [[NSWorkspace sharedWorkspace] iconForFile:[nbiURL path]];
    if ( nbiIcon ) {
        NSData *nbiIconData = [nbiIcon TIFFRepresentation];
        
        NSString *applicationTemporaryFolderPath = [NSTemporaryDirectory() stringByAppendingPathComponent:NBCBundleIdentifier];
        DDLogDebug(@"[DEBUG] Application temporary folder path: %@", applicationTemporaryFolderPath);
        
        if ( [applicationTemporaryFolderPath length] != 0 ) {
            NSURL *applicationTemporaryFolderURL = [NSURL fileURLWithPath:applicationTemporaryFolderPath];
            if ( ! [applicationTemporaryFolderURL checkResourceIsReachableAndReturnError:nil] ) {
                if ( ! [[NSFileManager defaultManager] createDirectoryAtURL:applicationTemporaryFolderURL withIntermediateDirectories:YES attributes:@{} error:&error] ) {
                    DDLogError(@"[ERROR] %@", [error localizedDescription]);
                }
            }
            
            NSURL *iconTmpStoreURL = [applicationTemporaryFolderURL URLByAppendingPathComponent:@"icns"];
            if ( [[NSFileManager defaultManager] createDirectoryAtURL:iconTmpStoreURL withIntermediateDirectories:YES attributes:@{} error:&error] ) {
                NSURL *iconTmpURL = [iconTmpStoreURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.icns", [[NSUUID UUID] UUIDString]]];
                DDLogDebug(@"[DEBUG] Icon temporary path: %@", iconTmpURL);
                
                if ( [nbiIconData writeToURL:iconTmpURL atomically:NO] ) {
                    settingsDict[NBCSettingsIconKey] = [iconTmpURL path] ?: @"";
                } else {
                    DDLogError(@"[ERROR] Failed storing temporary nbi icon");
                }
            } else {
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
            }
        } else {
            DDLogError(@"[ERROR] Temporary folder path was empty");
        }
    }
    
    if ( [settingsDict[NBCSettingsIconKey] length] == 0 ) {
        DDLogDebug(@"[DEBUG] Icon path was empty, setting default path...");
        
        NSString *defaulNbiIconPath;
        switch (workflowType) {
            case kWorkflowTypeNetInstall:
                defaulNbiIconPath = NBCFilePathNBIIconNetInstall;
                break;
            case kWorkflowTypeDeployStudio:
                defaulNbiIconPath = NBCFilePathNBIIconDeployStudio;
                break;
            case kWorkflowTypeImagr:
                defaulNbiIconPath = NBCFilePathNBIIconImagr;
                break;
            case kWorkflowTypeCasper:
                defaulNbiIconPath = NBCFilePathNBIIconCasper;
                break;
            default:
                DDLogError(@"[ERROR] Unknown workflow type: %d", workflowType);
                break;
        }
        
        settingsDict[NBCSettingsIconKey] = defaulNbiIconPath ?: @"";
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: NBImageInfo
    // -------------------------------------------------------------------------------
    if ( ! [self readNBImageInfoSettingsFromURL:nbImageInfoURL settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Tab General
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsTabGeneralFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Tab Options
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsTabOptionsFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Tab Extra
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsTabExtraFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Tab Advanced
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsTabAdvancedFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Tab Debug
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsTabDebugFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading rc.* files
    // -------------------------------------------------------------------------------
    if ( ! [self readSettingsRCFilesFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings: Imagr
    // -------------------------------------------------------------------------------
    if ( ! [self readImagrSettingsFromTarget:target settingsDict:settingsDict error:&error] ) {
        if ( _delegate && [_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
            [_delegate readingSettingsFailedWithError:error];
        }
        return;
    }
    
    // -------------------------------------------------------------------------------
    //  Reading Settings using Helper
    // -------------------------------------------------------------------------------
    [self readSettingsUsingHelperFromTarget:target settingsDict:settingsDict];
}

- (BOOL)readNBImageInfoSettingsFromURL:(NSURL *)nbImageInfoURL settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Reading settings for NBImageInfo.plist...");
    
    NSDictionary *nbImageInfoDict = [[NSDictionary alloc] initWithContentsOfURL:nbImageInfoURL];
    if ( [nbImageInfoDict count] != 0 ) {
        
        // -------------------------------------------------------------------------------
        //  NBI Name
        // -------------------------------------------------------------------------------
        NSString *nbiName = nbImageInfoDict[NBCNBImageInfoDictNameKey];
        settingsDict[NBCSettingsNameKey] = nbiName ?: @"";
        
        // -------------------------------------------------------------------------------
        //  NBI Index
        // -------------------------------------------------------------------------------
        NSNumber *nbiIndex;
        if ( [nbImageInfoDict[NBCNBImageInfoDictIndexKey] isKindOfClass:[NSNumber class]] ) {
            nbiIndex = nbImageInfoDict[NBCNBImageInfoDictIndexKey];
        } else if ( [nbImageInfoDict[NBCNBImageInfoDictIndexKey] isKindOfClass:[NSString class]] ) {
            DDLogWarn(@"[WARN] Index: Incorrect value type: %@", [nbImageInfoDict[NBCNBImageInfoDictIndexKey] class]);
            DDLogWarn(@"[WARN] Should be: %@", [NSNumber class]);
            nbiIndex = @( [nbImageInfoDict[NBCNBImageInfoDictIndexKey] integerValue] );
        } else {
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Index: Unknown value type: %@", [nbImageInfoDict[NBCNBImageInfoDictIndexKey] class]]];
            return NO;
        }
        settingsDict[NBCSettingsIndexKey] = [nbiIndex stringValue] ?: NBCVariableIndexCounter;
        
        // -------------------------------------------------------------------------------
        //  NBI Protocol
        // -------------------------------------------------------------------------------
        NSString *nbiProtocol = nbImageInfoDict[NBCNBImageInfoDictProtocolKey];
        settingsDict[NBCSettingsProtocolKey] = nbiProtocol ?: @"NFS";
        
        // -------------------------------------------------------------------------------
        //  NBI Language
        // -------------------------------------------------------------------------------
        NSString *nbiLanguage = nbImageInfoDict[NBCNBImageInfoDictLanguageKey];
        settingsDict[NBCSettingsLanguageKey] = ( [nbiLanguage isEqualToString:@"Default"] ) ? NBCMenuItemCurrent : nbiLanguage ?: NBCMenuItemCurrent ;
        
        // -------------------------------------------------------------------------------
        //  NBI Enabled
        // -------------------------------------------------------------------------------
        BOOL nbiEnabled = [nbImageInfoDict[NBCNBImageInfoDictIsEnabledKey] boolValue];
        settingsDict[NBCSettingsEnabledKey] = @(nbiEnabled) ?: @NO;
        
        // -------------------------------------------------------------------------------
        //  NBI Default
        // -------------------------------------------------------------------------------
        BOOL nbiDefault = [nbImageInfoDict[NBCNBImageInfoDictIsDefaultKey] boolValue];
        settingsDict[NBCSettingsDefaultKey] = @(nbiDefault) ?: @NO;
        
        // -------------------------------------------------------------------------------
        //  NBI Description
        // -------------------------------------------------------------------------------
        NSString *nbiDescription = nbImageInfoDict[NBCNBImageInfoDictDescriptionKey];
        settingsDict[NBCSettingsDescriptionKey] = nbiDescription ?: @"";
        
        return YES;
    } else {
        *error = [NBCError errorWithDescription:@"NBI NBImageInfo.plist was empty!"];
        return NO;
    }
}

- (BOOL)readImagrSettingsFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Reading settings for Imagr...");
    
    // -------------------------------------------------------------------------------
    //  Static Values
    // -------------------------------------------------------------------------------
    settingsDict[NBCSettingsImagrDisableATS] =       @NO;
    settingsDict[NBCSettingsImagrUseLocalVersion] =  @NO;
    settingsDict[NBCSettingsImagrLocalVersionPath] = @"";
    settingsDict[NBCSettingsImagrUseGitBranch] =     @NO;
    settingsDict[NBCSettingsImagrGitBranch] =        @"Master";
    settingsDict[NBCSettingsImagrBuildTarget] =      @"Release";
    
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    if ( [nbiNetInstallVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
        
        // -------------------------------------------------------------------------------
        //  Imagr.app Configuration
        // -------------------------------------------------------------------------------
        NSURL *nbiImagrConfigurationDictURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrConfigurationPlistTargetURL];
        
        NSDictionary *nbiImagrConfigurationDict;
        if ( [nbiImagrConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
            nbiImagrConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiImagrConfigurationDictURL];
        }
        
        NSString *imagrConfigurationURL = nbiImagrConfigurationDict[NBCSettingsImagrServerURLKey];
        settingsDict[NBCSettingsImagrConfigurationURL] = imagrConfigurationURL ?: @"";
        settingsDict[NBCSettingsImagrSyslogServerURI] =  nbiImagrConfigurationDict[NBCSettingsImagrSyslogServerURIKey] ?: @"";
        settingsDict[NBCSettingsImagrReportingURL] =     nbiImagrConfigurationDict[NBCSettingsImagrReportingURLKey] ?: @"";
        if ( [imagrConfigurationURL length] != 0 ) {
            [target setImagrConfigurationPlistURL:nbiImagrConfigurationDictURL];
        }
        
        // -------------------------------------------------------------------------------
        //  Imagr.app
        // -------------------------------------------------------------------------------
        NSURL *nbiApplicationURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrApplicationTargetURL];
        DDLogDebug(@"[DEBUG] Imagr.app path: %@", [nbiApplicationURL path]);
        
        NSString *nbiImagrVersion;
        if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
            nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        }
        
        if ( [nbiImagrVersion length] != 0 ) {
            [target setImagrApplicationExistOnTarget:YES];
            [target setImagrApplicationURL:nbiApplicationURL];
            settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion ?: @"";
        } else {
            settingsDict[NBCSettingsImagrVersion] = NBCMenuItemImagrVersionLatest;
        }
        
        return YES;
    } else if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:error] ) {
        
        // -------------------------------------------------------------------------------
        //  Imagr.app Configuration
        // -------------------------------------------------------------------------------
        NSURL *nbiImagrConfigurationDictURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrConfigurationPlistNBICreatorTargetURL];
        NSDictionary *nbiImagrConfigurationDict;
        if ( [nbiImagrConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
            nbiImagrConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiImagrConfigurationDictURL];
        }
        
        NSString *imagrConfigurationURL = nbiImagrConfigurationDict[NBCSettingsImagrServerURLKey];
        settingsDict[NBCSettingsImagrConfigurationURL] = imagrConfigurationURL ?: @"";
        settingsDict[NBCSettingsImagrSyslogServerURI] =  nbiImagrConfigurationDict[NBCSettingsImagrSyslogServerURIKey] ?: @"";
        settingsDict[NBCSettingsImagrReportingURL] =     nbiImagrConfigurationDict[NBCSettingsImagrReportingURLKey] ?: @"";
        if ( [imagrConfigurationURL length] != 0 ) {
            [target setImagrConfigurationPlistURL:nbiImagrConfigurationDictURL];
        }
        
        // -------------------------------------------------------------------------------
        //  Imagr.app
        // -------------------------------------------------------------------------------
        NSURL *nbiApplicationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrApplicationNBICreatorTargetURL];
        DDLogDebug(@"[DEBUG] Imagr.app path: %@", [nbiApplicationURL path]);
        
        NSString *nbiImagrVersion;
        if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
            nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        }
        
        if ( [nbiImagrVersion length] != 0 ) {
            [target setImagrApplicationExistOnTarget:YES];
            [target setImagrApplicationURL:nbiApplicationURL];
            settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion ?: @"";
        } else {
            settingsDict[NBCSettingsImagrVersion] = NBCMenuItemImagrVersionLatest;
        }
        
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)readSettingsTabGeneralFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for settings tab: General");
    
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  Most settings in Tab: General is read in ( readNBImageInfoSettingsFromURL )
    // -------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------
    //  Time Zone
    // -------------------------------------------------------------------------------
    NSURL *localtime = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"private/etc/localtime"];
    if ( [localtime checkResourceIsReachableAndReturnError:nil] ) {
        NSString *localtimeTarget = [[localtime path] stringByResolvingSymlink];
        if ( [localtimeTarget length] != 0 ) {
            NSString *timeZone = [localtimeTarget stringByReplacingOccurrencesOfString:@"/usr/share/zoneinfo/" withString:@""];
            if ( [timeZone length] != 0 ) {
                NSString *timeZoneSetting;
                for ( NSString *availableTimeZones in @[] ) {
                    if ( [timeZone hasPrefix:availableTimeZones] ) {
                        timeZoneSetting = timeZone;
                        break;
                    }
                }
                settingsDict[NBCSettingsTimeZoneKey] = timeZoneSetting ?: NBCMenuItemCurrent;
            } else {
                settingsDict[NBCSettingsTimeZoneKey] = NBCMenuItemCurrent;
            }
        } else {
            settingsDict[NBCSettingsTimeZoneKey] = NBCMenuItemCurrent;
        }
    } else {
        settingsDict[NBCSettingsTimeZoneKey] = NBCMenuItemCurrent;
    }
    
    // -------------------------------------------------------------------------------
    //  Keyboard Layout
    // -------------------------------------------------------------------------------
    NSURL *hiToolboxPlistURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.HIToolbox.plist"];
    if ( [hiToolboxPlistURL checkResourceIsReachableAndReturnError:nil] ) {
        NSDictionary *hiToolboxPlist = [NSDictionary dictionaryWithContentsOfURL:hiToolboxPlistURL];
        if ( [hiToolboxPlist count] != 0 ) {
            NSDictionary *defaultInputSource = hiToolboxPlist[@"AppleDefaultAsciiInputSource"];
            if ( [defaultInputSource count] != 0 ) {
                NSString *keyboardLayoutName = defaultInputSource[@"KeyboardLayout Name"];
                settingsDict[NBCSettingsKeyboardLayoutKey] = keyboardLayoutName ?: NBCMenuItemCurrent;
            }
        } else {
            settingsDict[NBCSettingsKeyboardLayoutKey] = NBCMenuItemCurrent;
        }
    } else {
        settingsDict[NBCSettingsKeyboardLayoutKey] = NBCMenuItemCurrent;
    }
    
    // -------------------------------------------------------------------------------
    //  NBI Destination Folder
    // -------------------------------------------------------------------------------
    NSString *currentUserHome = NSHomeDirectory();
    if ( [[target nbiURL] checkResourceIsReachableAndReturnError:nil] ) {
        NSString *destinationFolder = [[target nbiURL] path];
        if ( [destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolderPath ?: @"~/Desktop";
        } else {
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolder ?: @"~/Desktop";
        }
    } else {
        settingsDict[NBCSettingsDestinationFolderKey] = @"~/Desktop";
    }
    
    return YES;
}

- (BOOL)readSettingsTabOptionsFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for settings tab: Options");
    
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  Disable WiFi
    // -------------------------------------------------------------------------------
    NSURL *wifiKext = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    if ( [wifiKext checkResourceIsReachableAndReturnError:nil] ) {
        settingsDict[NBCSettingsDisableWiFiKey] = @NO;
    } else {
        settingsDict[NBCSettingsDisableWiFiKey] = @YES;
    }
    
    // -------------------------------------------------------------------------------
    //  Disable Bluetooth
    // -------------------------------------------------------------------------------
    NSURL *ioBluetoothFamilyURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothFamily.kext"];
    if ( [ioBluetoothFamilyURL checkResourceIsReachableAndReturnError:nil] ) {
        settingsDict[NBCSettingsDisableBluetoothKey] = @NO;
    } else {
        settingsDict[NBCSettingsDisableBluetoothKey] = @YES;
    }
    
    // -------------------------------------------------------------------------------
    //  Include Ruby
    // -------------------------------------------------------------------------------
    NSURL *rubyURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/bin/ruby"];
    if ( [rubyURL checkResourceIsReachableAndReturnError:nil] ) {
        settingsDict[NBCSettingsIncludeRubyKey] = @YES;
    } else {
        settingsDict[NBCSettingsIncludeRubyKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Include Python
    // -------------------------------------------------------------------------------
    // +IMPROVEMENT NEED TO FIX
    
    // -------------------------------------------------------------------------------
    //  Include SystemUIServer
    // -------------------------------------------------------------------------------
    NSURL *systemUIServerLaunchdURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.SystemUIServer.plist"];
    if ( [systemUIServerLaunchdURL checkResourceIsReachableAndReturnError:nil] ) {
        settingsDict[NBCSettingsIncludeSystemUIServerKey] = @YES;
    } else {
        settingsDict[NBCSettingsIncludeSystemUIServerKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Display Sleep - ( readSettingsRCFilesFromTarget )
    // -------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------
    //  Screen Sharing - ( readSettingsUsingHelperFromTarget )
    // -------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------
    //  Use a Network Time Server
    // -------------------------------------------------------------------------------
    NSString *ntpServer;
    NSURL *ntpConfigurationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"private/etc/ntp.conf"];
    if ( [ntpConfigurationURL checkResourceIsReachableAndReturnError:nil] ) {
        NSString *ntpConfiguration = [NSString stringWithContentsOfURL:ntpConfigurationURL encoding:NSUTF8StringEncoding error:nil];
        NSArray *ntpConfigurationArray = [ntpConfiguration componentsSeparatedByString:@"\n"];
        NSString *ntpConfigurationFirstLine = ntpConfigurationArray[0];
        if ( [ntpConfigurationFirstLine containsString:@"server"] ) {
            ntpServer = [ntpConfigurationFirstLine componentsSeparatedByString:@" "][1];
        }
    }
    
    if ( [ntpServer length] != 0 ) {
        settingsDict[NBCSettingsUseNetworkTimeServerKey] =  @YES;
        settingsDict[NBCSettingsNetworkTimeServerKey] =     ntpServer ?: @"time.apple.com";
    } else {
        settingsDict[NBCSettingsUseNetworkTimeServerKey] =  @NO;
        settingsDict[NBCSettingsNetworkTimeServerKey] =     @"time.apple.com";
    }
    
    return YES;
}

- (BOOL)readSettingsTabExtraFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for settings tab: Extra");
    
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  Certificates
    // -------------------------------------------------------------------------------
    NSURL *certificatesFolderURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/certificates"];
    if ( ! [certificatesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        certificatesFolderURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"Packages/certificates"];
    }
    
    if ( [certificatesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
        NSMutableArray *certificatesArray = [[NSMutableArray alloc] init];
        NSArray *certificates = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:certificatesFolderURL includingPropertiesForKeys:@[] options:0 error:error];
        if ( [certificates count] != 0 ) {
            [certificates enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
#pragma unused(idx, stop)
                NSData *certificateData = [[NSData alloc] initWithContentsOfURL:obj];
                [certificatesArray addObject:certificateData];
            }];
            settingsDict[NBCSettingsCertificatesKey] = certificatesArray ?: @[];
        } else {
            settingsDict[NBCSettingsCertificatesKey] = @[];
        }
    } else {
        settingsDict[NBCSettingsCertificatesKey] = @[];
    }
    
    // -------------------------------------------------------------------------------
    //  Packages
    // -------------------------------------------------------------------------------
    settingsDict[NBCSettingsPackagesKey] = @[];
    
    return YES;
}

- (BOOL)readSettingsTabAdvancedFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for settings tab: Advanced");
    
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  Trusted NetBoot Servers
    // -------------------------------------------------------------------------------
    NSURL *bsdpSourcesURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/bsdpSources.txt"];
    if ( [bsdpSourcesURL checkResourceIsReachableAndReturnError:nil] ) {
        NSString *bsdpSourcesContent = [[NSString alloc] initWithContentsOfURL:bsdpSourcesURL encoding:NSUTF8StringEncoding error:error];
        if ( [bsdpSourcesContent length] != 0 ) {
            NSMutableArray *bsdpArray = [[bsdpSourcesContent componentsSeparatedByString:@"\n"] mutableCopy];
            [bsdpArray removeObject:@""];
            settingsDict[NBCSettingsTrustedNetBootServersKey] =    bsdpArray ?: @[];
            settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @YES;
        } else {
            settingsDict[NBCSettingsTrustedNetBootServersKey] =    @[];
            settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @NO;
        }
    } else {
        settingsDict[NBCSettingsTrustedNetBootServersKey] =    @[];
        settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Custom RAMDisks ( readSettingsRCFilesFromTarget )
    // -------------------------------------------------------------------------------
    
    // -------------------------------------------------------------------------------
    //  Background Image
    // -------------------------------------------------------------------------------
    NSURL *nbiCreatorDesktopViewerURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Applications/NBICreatorDesktopViewer.app"];
    if ( [nbiCreatorDesktopViewerURL checkResourceIsReachableAndReturnError:nil] ) {
        NSURL *defaultDesktopURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/DefaultDesktop.jpg"];
        if ( [defaultDesktopURL checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsUseBackgroundImageKey] = @YES;
            settingsDict[NBCSettingsBackgroundImageKey] =    [defaultDesktopURL path];
        } else {
            settingsDict[NBCSettingsUseBackgroundImageKey] = @NO;
            settingsDict[NBCSettingsBackgroundImageKey] =    NBCBackgroundImageDefaultPath;
        }
    } else {
        settingsDict[NBCSettingsUseBackgroundImageKey] = @NO;
        settingsDict[NBCSettingsBackgroundImageKey] =    NBCBackgroundImageDefaultPath;
    }
    
    return YES;
}

- (BOOL)readSettingsTabDebugFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for settings tab: Debug");
    
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  Always boot in verbose mode
    // -------------------------------------------------------------------------------
    NSURL *comAppleBootPlistURL = [[target nbiURL] URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    if ( [comAppleBootPlistURL checkResourceIsReachableAndReturnError:nil] ) {
        NSDictionary *comAppleBootPlist = [NSDictionary dictionaryWithContentsOfURL:comAppleBootPlistURL];
        if ( [comAppleBootPlist count] != 0 ) {
            NSString *kernelFlags = comAppleBootPlist[@"Kernel Flags"];
            if ( [kernelFlags containsString:@"-v"] ) {
                settingsDict[NBCSettingsUseVerboseBootKey] = @YES;
            } else {
                settingsDict[NBCSettingsUseVerboseBootKey] = @NO;
            }
        } else {
            settingsDict[NBCSettingsUseVerboseBootKey] = @NO;
        }
    } else {
        settingsDict[NBCSettingsUseVerboseBootKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Make NetInstall images Read/Write
    // -------------------------------------------------------------------------------
    NSString *netInstallPath = [[[target nbiURL] URLByAppendingPathComponent:@"NetInstall.dmg"] path];
    NSString *netInstallPathResolved = [netInstallPath stringByResolvingSymlink];
    if ( [netInstallPathResolved isEqualToString:netInstallPath] ) {
        settingsDict[NBCSettingsDiskImageReadWriteKey] = @NO;
    } else {
        settingsDict[NBCSettingsDiskImageReadWriteKey] = @YES;
    }
    
    // -------------------------------------------------------------------------------
    //  Rename sparseimage to dmg instead of creating a symbolic link
    // -------------------------------------------------------------------------------
    // +IMPROVEMENT Need to check with disk or hdiutil if .dmg is writeable
    settingsDict[NBCSettingsDiskImageReadWriteRenameKey] = @NO;
    
    // -------------------------------------------------------------------------------
    //  Include Console.app
    // -------------------------------------------------------------------------------
    NSURL *consoleURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Applications/Utilities/Console.app"];
    if ( [consoleURL checkResourceIsReachableAndReturnError:nil] ) {
        settingsDict[NBCSettingsIncludeConsoleAppKey] = @YES;
    } else {
        settingsDict[NBCSettingsIncludeConsoleAppKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Launch behind main application ( readSettingsRCFilesFromTarget )
    // -------------------------------------------------------------------------------
    
    return YES;
}

- (BOOL)readSettingsRCFilesFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict error:(NSError **)error {
#pragma unused(error)
    
    DDLogDebug(@"[DEBUG] Reading settings for rc.* files...");
    
    NSURL *nbiNetInstallVolumeURL = [target nbiNetInstallVolumeURL];
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    // -------------------------------------------------------------------------------
    //  rc.install
    // -------------------------------------------------------------------------------
    NSString *rcInstall;
    NSURL *rcInstallURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrRCInstallTargetURL];
    if ( [rcInstallURL checkResourceIsReachableAndReturnError:nil] ) {
        rcInstall = [NSString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:error];
    }
    
    // -------------------------------------------------------------------------------
    //  rc.imaging
    // -------------------------------------------------------------------------------
    NSString *rcImaging;
    NSURL *rcImagingURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCRCImagingTargetURL];
    if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
        rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:error];
        
    } else {
        rcImagingURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCRCImagingNBICreatorTargetURL];
        if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
            rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:error];
        }
    }
    
    [target setRcImagingContent:rcImaging];
    [target setRcImagingURL:rcImagingURL];
    NSString *rcFiles = [NSString stringWithFormat:@"%@\n%@", rcInstall, rcImaging];
    
    // -------------------------------------------------------------------------------
    //  Settings Tab: Debug - Launch behind main application
    // -------------------------------------------------------------------------------
    if ( [rcImaging containsString:@"/Applications/Utilities/Console.app/Contents/MacOS/Console"] ) {
        settingsDict[NBCSettingsLaunchConsoleAppKey] = @YES;
    } else {
        settingsDict[NBCSettingsLaunchConsoleAppKey] = @NO;
    }
    
    // -------------------------------------------------------------------------------
    //  Settings Tab: Options - Display Sleep
    // -------------------------------------------------------------------------------
    NSString *displaySleepTime;
    if ( [rcFiles length] != 0 ) {
        NSArray *rcFilesArray = [rcFiles componentsSeparatedByString:@"\n"];
        for ( NSString *line in rcFilesArray ) {
            if ( [line containsString:@"pmset"] && [line containsString:@"displaysleep"] ) {
                NSError* regexError = nil;
                NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"displaysleep [0-9]+"
                                                                                       options:0
                                                                                         error:&regexError];
                
                if ( regex == nil ) {
                    DDLogError(@"[ERROR] Regex creation failed with error: %@", [regexError description]);
                }
                
                NSArray *matches = [regex matchesInString:line
                                                  options:NSMatchingWithoutAnchoringBounds
                                                    range:NSMakeRange(0, line.length)];
                
                for (NSTextCheckingResult *entry in matches) {
                    NSString *text = [line substringWithRange:entry.range];
                    if ( [text length] != 0 ) {
                        displaySleepTime = [text componentsSeparatedByString:@" "][1];
                    }
                }
            }
        }
    }
    
    if ( [displaySleepTime length] != 0 ) {
        if ( [displaySleepTime integerValue] == 0 ) {
            settingsDict[NBCSettingsDisplaySleepKey] =        @NO;
            settingsDict[NBCSettingsDisplaySleepMinutesKey] = @120;
        } else {
            settingsDict[NBCSettingsDisplaySleepKey] =        @YES;
            settingsDict[NBCSettingsDisplaySleepMinutesKey] = @([displaySleepTime intValue]);
        }
    } else {
        settingsDict[NBCSettingsDisplaySleepKey] =        @YES;
        settingsDict[NBCSettingsDisplaySleepMinutesKey] = @30;
    }
    
    // -------------------------------------------------------------------------------
    //  rc.cdm.cdrom
    // -------------------------------------------------------------------------------
    NSURL *rcCdmCdromURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"private/etc/rc.cdm.cdrom"];
    if ( [rcCdmCdromURL checkResourceIsReachableAndReturnError:nil] ) {
        
        // -------------------------------------------------------------------------------
        //  Settings Tab: Advanced - RAMDisks
        // -------------------------------------------------------------------------------
        NSString *rcCdmCdromContent = [NSString stringWithContentsOfURL:rcCdmCdromURL encoding:NSUTF8StringEncoding error:error];
        __block BOOL inspectNextLine = NO;
        __block NSMutableArray *customRamDisks = [[NSMutableArray alloc] init];
        [rcCdmCdromContent enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
#pragma unused(stop)
            if ( inspectNextLine ) {
                if ( [line hasPrefix:@"RAMDisk"] ) {
                    NSMutableArray *lineArray = [NSMutableArray arrayWithArray:[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    NSString *path = lineArray[1];
                    NSString *size = lineArray[2];
                    NSString *ramDiskSize = [@(( [size intValue] / 1024 )) stringValue];
                    [customRamDisks addObject:@{
                                                @"path" : path,
                                                @"size" : ramDiskSize
                                                }];
                }
            }
            
            if ( [line hasPrefix:@"### CUSTOM RAM DISKS ###"] ) {
                inspectNextLine = YES;
            }
        }];
        if ( [customRamDisks count] != 0 ) {
            settingsDict[NBCSettingsAddCustomRAMDisksKey] = @YES;
            settingsDict[NBCSettingsRAMDisksKey] =          customRamDisks;
        } else {
            settingsDict[NBCSettingsAddCustomRAMDisksKey] = @NO;
            settingsDict[NBCSettingsRAMDisksKey] =          @[];
        }
    } else {
        settingsDict[NBCSettingsAddCustomRAMDisksKey] = @NO;
        settingsDict[NBCSettingsRAMDisksKey] =          @[];
    }
    
    return YES;
}

- (void)readSettingsUsingHelperFromTarget:(NBCTarget *)target settingsDict:(NSMutableDictionary *)settingsDict {
    
    DDLogDebug(@"[DEBUG] Reading settings from NBI using helper...");
    
    NSURL *nbiBaseSystemVolumeURL = [target baseSystemVolumeURL];
    
    dispatch_queue_t taskQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(taskQueue, ^{
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        [[helperConnector connection] setExportedObject:self];
        [[helperConnector connection] setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCWorkflowProgressDelegate)]];
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if ( self->_delegate && [self->_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
                    [self->_delegate readingSettingsFailedWithError:proxyError];
                }
            });
            if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
                [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]];
            }
        }] readSettingsFromNBI:nbiBaseSystemVolumeURL settingsDict:[settingsDict copy] withReply:^(NSError *error, BOOL success, NSDictionary *newSettingsDict) {
            if ( success ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( self->_delegate && [self->_delegate respondsToSelector:@selector(readingSettingsComplete:)] ) {
                        [self->_delegate readingSettingsComplete:newSettingsDict];
                    }
                });
                
                if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
                    [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]];
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ( self->_delegate && [self->_delegate respondsToSelector:@selector(readingSettingsFailedWithError:)] ) {
                        [self->_delegate readingSettingsFailedWithError:error];
                    }
                });
                
                if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
                    [NBCDiskImageController detachDiskImageAtPath:[nbiBaseSystemVolumeURL path]];
                }
            }
        }];
    });
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCWorkflowProgressDelegate
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
#pragma unused(statusMessage, workflow)
}
- (void)updateProgressStatus:(NSString *)statusMessage {
#pragma unused(statusMessage)
}
- (void)updateProgressBar:(double)value {
#pragma unused(value)
}
- (void)incrementProgressBar:(double)value {
#pragma unused(value)
}
- (void)logDebug:(NSString *)logMessage {
    DDLogDebug(@"[DEBUG] %@", logMessage);
}
- (void)logInfo:(NSString *)logMessage {
    DDLogInfo(@"%@", logMessage);
}
- (void)logWarn:(NSString *)logMessage {
    DDLogWarn(@"[WARN] %@", logMessage);
}
- (void)logError:(NSString *)logMessage {
    DDLogError(@"[ERROR] %@", logMessage);
}
- (void)logStdOut:(NSString *)stdOutString {
    DDLogDebug(@"[DEBUG][stdout] %@", stdOutString);
}
- (void)logStdErr:(NSString *)stdErrString {
    DDLogDebug(@"[DEBUG][stderr] %@", stdErrString);
}

@end
