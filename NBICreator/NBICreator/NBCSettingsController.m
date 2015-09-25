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

#import "NBCImagrSettingsViewController.h"
#import "NBCLogging.h"
#import "NBCXcodeSource.h"

DDLogLevel ddLogLevel;

@implementation NBCSettingsController

#pragma mark -
#pragma mark
#pragma mark -

- (NSDictionary *)verifySettings:(NBCWorkflowItem *)workflowItem {
    
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
    
    if ( ! [NBCXcodeSource isInstalled] ) {
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



@end
