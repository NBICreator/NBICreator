//
//  NBCWorkflowNBIController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-11.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowNBIController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowNBIController

+ (NSArray *)generateScriptArgumentsForCreateRestoreFromSources:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *createRestoreFromSourcesArguments = [[NSMutableArray alloc] init];
    
    // -------------------------------------------------------------------
    //  Add non-optional values to createRestoreFromSourcesArguments
    // -------------------------------------------------------------------
    NSString *createRestoreFromSourcesPath = [[[workflowItem applicationSource] createRestoreFromSourcesURL] path];
    if ( [createRestoreFromSourcesPath length] != 0 ) {
        [createRestoreFromSourcesArguments addObject:createRestoreFromSourcesPath];
    } else {
        NSLog(@"Could not get createRestoreFromSourcesPath from workflow Item!");
        return nil;
    }
    
    NSString *temporaryNBIPath = [[workflowItem temporaryNBIURL] path];
    if ( [temporaryNBIPath length] != 0 ) {
        [createRestoreFromSourcesArguments addObject:temporaryNBIPath];
    } else {
        NSLog(@"Could not get temporaryNBIURL from workflow Item!");
        return nil;
    }
    
    [createRestoreFromSourcesArguments addObject:NBCSystemImageUtilityNetBootImageSize];
    
    return [createRestoreFromSourcesArguments copy];
    
} // generateSysBuilderArgumentsFromSettingsDict

+ (NSArray *)generateScriptArgumentsForCreateNetInstall:(NBCWorkflowItem *)workflowItem {
    NSMutableArray *createNetInstallArguments = [[NSMutableArray alloc] init];
    
    // -------------------------------------------------------------------
    //  Add non-optional values to createNetInstallArguments
    // -------------------------------------------------------------------
    NSString *createNetInstallPath = [[[workflowItem applicationSource] createNetInstallURL] path];
    if ( [createNetInstallPath length] != 0 ) {
        [createNetInstallArguments addObject:createNetInstallPath];
    } else {
        NSLog(@"Could not get createNetInstallPath from workflow Item!");
        return nil;
    }
    
    NSString *temporaryNBIPath = [[workflowItem temporaryNBIURL] path];
    if ( [temporaryNBIPath length] != 0 ) {
        [createNetInstallArguments addObject:temporaryNBIPath];
    } else {
        NSLog(@"Could not get temporaryNBIURL from workflow Item!");
        return nil;
    }
    
    [createNetInstallArguments addObject:NBCSystemImageUtilityNetBootImageSize];
    
    return [createNetInstallArguments copy];
    
} // generateSysBuilderArgumentsFromSettingsDict

+ (BOOL)generateEnvironmentVariablesForCreateRestoreFromSources:(NBCWorkflowItem *)workflowItem {
    BOOL retval = YES;
    NSMutableString *environmentVariablesContent = [[NSMutableString alloc] init];
    
    // --------------------------------------------------------------
    //  Get current user UID and GUI.
    // --------------------------------------------------------------
    uid_t uid;
    uid_t gid;
    SCDynamicStoreCopyConsoleUser(NULL, &uid, &gid);
    NSString *uidString = [NSString stringWithFormat:@"%u", uid];
    NSString *gidString = [NSString stringWithFormat:@"%u", gid];
    
    NSURL *createVariablesURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"createVariables.sh"];
    
    [environmentVariablesContent appendString:@"#!/bin/sh -p\n\nset +xv\n"];
    [environmentVariablesContent appendString:[NSString stringWithFormat:@"progressPrefix=\"%@\"\n", NBCWorkflowNetInstallLogPrefix]];
    [environmentVariablesContent appendString:@"scriptsDebugKey=\"DEBUG\"\n"];
    [environmentVariablesContent appendString:@"imageIsUDIFKey=\"1\"\n"];
    [environmentVariablesContent appendString:@"imageFormatKey=\"UDZO\"\n"];
    [environmentVariablesContent appendString:@"mountPoint=\"\"\n"];
    [environmentVariablesContent appendString:[NSString stringWithFormat:@"ownershipInfoKey=\"%@:%@\"\n", uidString, gidString]];
    [environmentVariablesContent appendString:@"sourceVol=\"/\"\n"];
    [environmentVariablesContent appendString:@"asrSource=\"ASRInstall.pkg\"\n"];
    [environmentVariablesContent appendString:@"dmgTarget=\"NetInstall\"\n"];
    
    // -------------------------------------------------------------------
    //  Add destPath
    // -------------------------------------------------------------------
    NSString *destinationPath = [[workflowItem temporaryNBIURL] path];
    if ( [destinationPath length] != 0 ) {
        [environmentVariablesContent appendString:[NSString stringWithFormat:@"destPath=\"%@\"\n", destinationPath]];
    } else {
        NSLog(@"Could not get destinationPath from workflowItem");
        return NO;
    }
    
    // -------------------------------------------------------------------
    //  Add potentialRecoveryDevice
    // -------------------------------------------------------------------
    NSString *potentialRecoveryDeviceDev = [[workflowItem source] recoveryVolumeBSDIdentifier];
    NSString *potentialRecoveryDevice = [potentialRecoveryDeviceDev stringByReplacingOccurrencesOfString:@"/dev/" withString:@""];
    if ( [potentialRecoveryDevice length] != 0 ) {
        [environmentVariablesContent appendString:[NSString stringWithFormat:@"potentialRecoveryDevice=\"%@\"\n", potentialRecoveryDevice]];
    } else {
        NSLog(@"Could not get potentialRecoveryDevice from source");
        return NO;
    }
    
    // -------------------------------------------------------------------
    //  Write createVariables.sh to temporary nbi folder
    // -------------------------------------------------------------------
    if ( [environmentVariablesContent writeToURL:createVariablesURL atomically:NO encoding:NSUTF8StringEncoding error:nil] ) {
        NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
        if ( ! temporaryItemsNBI ) {
            temporaryItemsNBI = [NSMutableArray arrayWithObject:createVariablesURL];
        } else {
            [temporaryItemsNBI addObject:createVariablesURL];
        }
        
        [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    } else {
        NSLog(@"Could not create createVariables.sh at: %@", [createVariablesURL path]);
        retval = NO;
    }
    
    return retval;
} // generateEnvironmentVariablesForCreateNetInstall

+ (NSDictionary *)generateEnvironmentVariablesForCreateNetInstall:(NBCWorkflowItem *)workflowItem {
    
    NSMutableDictionary *environmentVariables = [[NSMutableDictionary alloc] init];
    NSString *envVariablesContent;
    
    // --------------------------------------------------------------
    //  Get current user UID and GUI.
    // --------------------------------------------------------------
    uid_t uid;
    uid_t gid;
    SCDynamicStoreCopyConsoleUser(NULL, &uid, &gid);
    NSString *uidString = [NSString stringWithFormat:@"%u", uid];
    NSString *gidString = [NSString stringWithFormat:@"%u", gid];
    
    NSURL *createVariablesURL = [[workflowItem temporaryNBIURL] URLByAppendingPathComponent:@"createVariables.sh"];
    
    envVariablesContent = @"#!/bin/sh -p\n\nset +xv\n";
    envVariablesContent = [NSString stringWithFormat:@"%@\nprogressPrefix=\"%@\"", envVariablesContent, NBCWorkflowNetInstallLogPrefix];
    envVariablesContent = [NSString stringWithFormat:@"%@\ndestVolFSType=\"HFS+\"", envVariablesContent];
    envVariablesContent = [NSString stringWithFormat:@"%@\ndmgTarget=\"NetInstall\"", envVariablesContent];
    envVariablesContent = [NSString stringWithFormat:@"%@\nscriptsDebugKey=\"DEBUG\"", envVariablesContent];
    envVariablesContent = [NSString stringWithFormat:@"%@\nownershipInfoKey=\"%@:%@\"", envVariablesContent, uidString, gidString];
    envVariablesContent = [NSString stringWithFormat:@"%@\nimageIsUDIFKey=\"1\"", envVariablesContent];
    envVariablesContent = [NSString stringWithFormat:@"%@\nimageFormatKey=\"UDZO\"", envVariablesContent];
    
    // -------------------------------------------------------------------
    //  Add destPath
    // -------------------------------------------------------------------
    NSString *destinationPath = [[workflowItem temporaryNBIURL] path];
    if ( [destinationPath length] != 0 ) {
        envVariablesContent = [NSString stringWithFormat:@"%@\ndestPath=\"%@\"", envVariablesContent, destinationPath];
    } else {
        NSLog(@"Could not get destinationPath from workflowItem");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add dmgVolName
    // -------------------------------------------------------------------
    NSString *nbiName = [[workflowItem nbiName] stringByDeletingPathExtension];
    if ( [nbiName length] != 0 ) {
        envVariablesContent = [NSString stringWithFormat:@"%@\ndmgVolName=\"%@\"", envVariablesContent, nbiName];
    } else {
        NSLog(@"Could not get nbiName from workflowItem");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add installSource
    // -------------------------------------------------------------------
    NSString *installESDVolumePath = [[[workflowItem source] installESDVolumeURL] path];
    if ( [installESDVolumePath length] != 0 ) {
        envVariablesContent = [NSString stringWithFormat:@"%@\ninstallSource=\"%@\"", envVariablesContent, installESDVolumePath];
    } else {
        NSLog(@"Could not get installESDVolumePath from source");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Write createVariables.sh to temporary nbi folder
    // -------------------------------------------------------------------
    if ( [envVariablesContent writeToURL:createVariablesURL atomically:NO encoding:NSUTF8StringEncoding error:nil] ) {
        NSMutableArray *temporaryItemsNBI = [[workflowItem temporaryItemsNBI] mutableCopy];
        if ( ! temporaryItemsNBI ) {
            temporaryItemsNBI = [NSMutableArray arrayWithObject:createVariablesURL];
        } else {
            [temporaryItemsNBI addObject:createVariablesURL];
        }
        
        [workflowItem setTemporaryItemsNBI:temporaryItemsNBI];
    } else {
        NSLog(@"Could not create createVariables.sh at: %@", [createVariablesURL path]);
        return nil;
    }
    
    return environmentVariables;
} // generateEnvironmentVariablesForCreateNetInstall

+ (NSArray *)generateScriptArgumentsForSysBuilder:(NBCWorkflowItem *)workflowItem {
    
    NSMutableArray *sysBuilderArguments = [[NSMutableArray alloc] init];
    // -------------------------------------------------------------------
    //  Retrieve user settings from workflowItem
    // -------------------------------------------------------------------
    NSDictionary *userSettings = [workflowItem userSettings];
    if ( [userSettings count] == 0 ) {
        NSLog(@"Could not get userSettings from workflow Item!");
        return nil;
    }
    // -------------------------------------------------------------------
    //  Add sysBuilder.sh path
    // -------------------------------------------------------------------
    NSString *sysBuilderPath;
    if ( 11 <= (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue] ) {
        sysBuilderPath = [[[workflowItem applicationSource] sysBuilderScriptRp] path];
    } else {
        sysBuilderPath = [[[workflowItem applicationSource] sysBuilderScript] path];
    }
    
    if ( [sysBuilderPath length] != 0 ) {
        [sysBuilderArguments addObject:sysBuilderPath];
    } else {
        NSLog(@"Could not get sysBuilderPath from deployStudioSource!");
        return nil;
    }
    // -------------------------------------------------------------------
    //  Add -basesystem
    // -------------------------------------------------------------------
    NSString *systemVolumePath = [[[workflowItem source] systemVolumeURL] path];
    if ( [systemVolumePath length] != 0 ) {
        [sysBuilderArguments addObject:@"-basesystem"];
        [sysBuilderArguments addObject:[systemVolumePath lastPathComponent]];
    } else {
        NSLog(@"Could not get systemVolumePath from source!");
    }
    
    // -------------------------------------------------------------------
    //  Add -type
    // -------------------------------------------------------------------
    [sysBuilderArguments addObject:@"-type"];
    [sysBuilderArguments addObject:@"netboot"];
    
    // -------------------------------------------------------------------
    //  Add -id
    // -------------------------------------------------------------------
    
    NSString *nbiIndex = [NBCVariables expandVariables:userSettings[NBCSettingsIndexKey]
                                                source:[workflowItem source]
                                     applicationSource:[workflowItem applicationSource]];
    if ( [nbiIndex length] != 0 ) {
        [sysBuilderArguments addObject:@"-id"];
        [sysBuilderArguments addObject:nbiIndex];
    } else {
        NSLog(@"Could not get nbiIndex from userSettings!");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add -name
    // -------------------------------------------------------------------
    NSString *nbiName = [NBCVariables expandVariables:[workflowItem nbiName]
                                               source:[workflowItem source]
                                    applicationSource:[workflowItem applicationSource]];
    if ( [nbiName length] != 0 ) {
        [sysBuilderArguments addObject:@"-name"];
        [sysBuilderArguments addObject:[nbiName stringByDeletingPathExtension]];
    } else {
        NSLog(@"Could not get nbiName form workflowItem!");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add -dest
    // -------------------------------------------------------------------
    NSString *temporaryFolderPath = [[[workflowItem temporaryFolderURL] path] stringByExpandingTildeInPath];
    if ( [temporaryFolderPath length] != 0 ) {
        [sysBuilderArguments addObject:@"-dest"];
        [sysBuilderArguments addObject:temporaryFolderPath];
    } else {
        NSLog(@"Could not get temporaryFolderURL from workflowItem");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add -protocol
    // -------------------------------------------------------------------
    NSString *nbiProtocol = userSettings[NBCSettingsProtocolKey];
    if ( [nbiProtocol length] != 0 ) {
        [sysBuilderArguments addObject:@"-protocol"];
        [sysBuilderArguments addObject:nbiProtocol];
    } else {
        NSLog(@"Could not get nbiProtocol from userSettings");
        return nil;
    }
    
    // -------------------------------------------------------------------
    //  Add -loc
    // -------------------------------------------------------------------
    NSString *nbiLanguage = userSettings[NBCSettingsLanguageKey];
    if ( [nbiLanguage length] != 0 ) {
        [sysBuilderArguments addObject:@"-loc"];
        [sysBuilderArguments addObject:nbiLanguage];
    } else {
        NSLog(@"Could not get nbiLanguage from userSettings");
        return nil;
    }
    
    // ------------------------------------------------------
    //  Optional Settings
    // ------------------------------------------------------
    
    // ------------------------------------------------------
    //  TabView Runtime
    // ------------------------------------------------------
    
    // -------------------------------------------------------------------
    //  Add -serverurl
    // -------------------------------------------------------------------
    BOOL useCustomServers = [userSettings[NBCSettingsDeployStudioUseCustomServersKey] boolValue];
    if ( useCustomServers == YES ) {
        BOOL serverAdded = NO;
        NSString *serverURL1 = userSettings[NBCSettingsDeployStudioServerURL1Key];
        if ( [serverURL1 length] != 0 ) {
            [sysBuilderArguments addObject:@"-serverurl"];
            [sysBuilderArguments addObject:userSettings[NBCSettingsDeployStudioServerURL1Key]];
            serverAdded = YES;
        }
        
        NSString *serverURL2 = userSettings[NBCSettingsDeployStudioServerURL2Key];
        if ( [serverURL2 length] != 0 ) {
            [sysBuilderArguments addObject:@"-serverurl2"];
            [sysBuilderArguments addObject:userSettings[NBCSettingsDeployStudioServerURL2Key]];
            serverAdded = YES;
        }
        
        if ( serverAdded == NO ) {
            NSLog(@"Could not get any serverURL from userSettings!");
            return nil;
        }
    }
    
    // -------------------------------------------------------------------
    //  Add -customtitle
    // -------------------------------------------------------------------
    BOOL useCustonRuntimeTitle = [userSettings[NBCSettingsDeployStudioUseCustomRuntimeTitleKey] boolValue];
    if ( useCustonRuntimeTitle == YES ) {
        NSString *customRuntimeTitle = [NBCVariables expandVariables:userSettings[NBCSettingsDeployStudioRuntimeTitleKey]
                                                              source:[workflowItem source]
                                                   applicationSource:[workflowItem applicationSource]];
        if ( [customRuntimeTitle length] != 0 ) {
            [sysBuilderArguments addObject:@"-customtitle"];
            [sysBuilderArguments addObject:customRuntimeTitle];
        } else {
            NSLog(@"Could not get customRuntimeTitle from userSettings!");
            return nil;
        }
    }
    
    // -------------------------------------------------------------------
    //  Add -disableversionsmismatchalerts
    // -------------------------------------------------------------------
    BOOL disableVersionMismatchAlerts = [userSettings[NBCSettingsDeployStudioDisableVersionMismatchAlertsKey] boolValue];
    if ( disableVersionMismatchAlerts == YES ) {
        [sysBuilderArguments addObject:@"-disableversionsmismatchalerts"];
    }
    
    // -------------------------------------------------------------------
    //  Add -displaylogs
    // -------------------------------------------------------------------
    BOOL displayLogWindow = [userSettings[NBCSettingsDeployStudioDisplayLogWindowKey] boolValue];
    if ( displayLogWindow == YES ) {
        [sysBuilderArguments addObject:@"-displaylogs"];
    }
    
    // -------------------------------------------------------------------
    //  Add -displaysleep
    // -------------------------------------------------------------------
    BOOL sleepDisplay = [userSettings[NBCSettingsDeployStudioSleepKey] boolValue];
    if ( sleepDisplay == YES ) {
        NSString *sleepDisplayDelay = userSettings[NBCSettingsDeployStudioSleepDelayKey];
        if ( [sleepDisplayDelay length] != 0 ) {
            [sysBuilderArguments addObject:@"-displaysleep"];
            [sysBuilderArguments addObject:sleepDisplayDelay];
        } else {
            NSLog(@"Could not get sleepDelay from userSettings!");
            return nil;
        }
    }
    
    // -------------------------------------------------------------------
    //  Add -timeout
    // -------------------------------------------------------------------
    BOOL reboot = [userSettings[NBCSettingsDeployStudioRebootKey] boolValue];
    if ( reboot == YES ) {
        NSString *rebootDelay = userSettings[NBCSettingsDeployStudioRebootDelayKey];
        if ( [rebootDelay length] != 0 ) {
            [sysBuilderArguments addObject:@"-timeout"];
            [sysBuilderArguments addObject:rebootDelay];
        } else {
            NSLog(@"Could not get rebootDelay from userSettings!");
            return nil;
        }
    }
    
    // ------------------------------------------------------
    //  TabView Authentication
    // ------------------------------------------------------
    
    // -------------------------------------------------------------------
    //  Add -timeout, -password
    // -------------------------------------------------------------------
    NSString *runtimeLogin = userSettings[NBCSettingsDeployStudioRuntimeLoginKey];
    if ( [runtimeLogin length] != 0 ) {
        [sysBuilderArguments addObject:@"-login"];
        [sysBuilderArguments addObject:runtimeLogin];
        
        NSString *runtimePassword = userSettings[NBCSettingsDeployStudioRuntimePasswordKey];
        if ( [runtimePassword length] != 0 ) {
            [sysBuilderArguments addObject:@"-password"];
            [sysBuilderArguments addObject:runtimePassword];
        }
    }
    
    // -------------------------------------------------------------------
    //  Add -ardlogin, -ardpassword
    // -------------------------------------------------------------------
    NSString *ardLogin = userSettings[NBCSettingsARDLoginKey];
    if ( [ardLogin length] != 0 ) {
        [sysBuilderArguments addObject:@"-ardlogin"];
        [sysBuilderArguments addObject:ardLogin];
        
        NSString *ardPassword = userSettings[NBCSettingsARDPasswordKey];
        if ( [ardPassword length] != 0 ) {
            [sysBuilderArguments addObject:@"-ardpassword"];
            [sysBuilderArguments addObject:ardPassword];
        }
    }
    
    // -------------------------------------------------------------------
    //  Add -ntp
    // -------------------------------------------------------------------
    NSString *timeServer = userSettings[NBCSettingsDeployStudioTimeServerKey];
    if ( [timeServer length] != 0 ) {
        [sysBuilderArguments addObject:@"-ntp"];
        [sysBuilderArguments addObject:timeServer];
    }
    
    // ------------------------------------------------------
    //  TabView Options
    // ------------------------------------------------------
    
    // -------------------------------------------------------------------
    //  Add -enablepython
    // -------------------------------------------------------------------
    BOOL includePython = [userSettings[NBCSettingsDeployStudioIncludePythonKey] boolValue];
    if ( includePython == YES ) {
        [sysBuilderArguments addObject:@"-enablepython"];
    }
    
    // -------------------------------------------------------------------
    //  Add -enableruby
    // -------------------------------------------------------------------
    BOOL includeRuby = [userSettings[NBCSettingsDeployStudioIncludeRubyKey] boolValue];
    if ( includeRuby == YES ) {
        [sysBuilderArguments addObject:@"-enableruby"];
    }
    
    // -------------------------------------------------------------------
    //  Add -enablecustomtcpstacksettings
    // -------------------------------------------------------------------
    BOOL useCustomTCPStack = [userSettings[NBCSettingsDeployStudioUseCustomTCPStackKey] boolValue];
    if ( useCustomTCPStack == YES ) {
        [sysBuilderArguments addObject:@"-enablecustomtcpstacksettings"];
    }
    
    // -------------------------------------------------------------------
    //  Add -disablewirelesssupport
    // -------------------------------------------------------------------
    BOOL disableWirelessSupport = [userSettings[NBCSettingsDeployStudioDisableWirelessSupportKey] boolValue];
    if ( disableWirelessSupport == YES ) {
        [sysBuilderArguments addObject:@"-disablewirelesssupport"];
    }
    
    // -------------------------------------------------------------------
    //  Add -smb1only
    // -------------------------------------------------------------------
    BOOL useSMB1 = [userSettings[NBCSettingsDeployStudioUseSMB1Key] boolValue];
    if ( useSMB1 == YES ) {
        [sysBuilderArguments addObject:@"-smb1only"];
    }
    
    // -------------------------------------------------------------------
    //  Add -custombackground
    // -------------------------------------------------------------------
    BOOL useCustomBackground = [userSettings[NBCSettingsUseBackgroundImageKey] boolValue];
    if ( useCustomBackground == YES ) {
        NSString *customBackgroundPath = userSettings[NBCSettingsBackgroundImageKey];
        if ( [customBackgroundPath length] != 0 ) {
            [sysBuilderArguments addObject:@"-custombackground"];
            [sysBuilderArguments addObject:customBackgroundPath];
        } else {
            NSLog(@"Could not get customBackgroundPath from userSettings!");
            return nil;
        }
    }
    
    return [sysBuilderArguments copy];
    
} // generateScriptArgumentsForSysBuilder

+ (NSString *)generateImagrRCImagingForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion {
    NSString *rcImaging = [NSString stringWithFormat:@"#!/bin/bash\n"];
    if ( 11 <= osMinorVersion ) {
        if ( [settingsDict[NBCSettingsAddTrustedNetBootServersKey] boolValue] ) {
            NSString *setAddTrustedNetBootServers = [NSString stringWithFormat:@"\n"
                                                     "###\n"
                                                     "### Add Trusted NetBoot Servers\n"
                                                     "###\n"
                                                     "if [[ -f /usr/bin/csrutil ]] && [[ -f /usr/local/bsdpSources.txt ]]; then\n"
                                                     "\twhile read netBootServer\n"
                                                     "\tdo\n"
                                                     "\t\t/usr/bin/csrutil netboot add \"${netBootServer}\"\n"
                                                     "\tdone < \"/usr/local/bsdpSources.txt\"\n"
                                                     "fi\n"];
            rcImaging = [rcImaging stringByAppendingString:setAddTrustedNetBootServers];
        }
    }
    
    if ( [settingsDict[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
        NSString *setDate = [NSString stringWithFormat:@"\n"
                             "###\n"
                             "### Set Date\n"
                             "###\n"
                             "if [ -e /etc/ntp.conf ]; then\n"
                             "{"
                             "\tNTP_SERVERS=$( /usr/bin/awk '{ print $NF }' /etc/ntp.conf )\n"
                             "\tfor NTP_SERVER in ${NTP_SERVERS}; do\n"
                             "\t\t/usr/sbin/ntpdate -u \"${NTP_SERVER}\" 2>/dev/null\n"
                             "\t\tif [ ${?} -eq 0 ]; then\n"
                             "\t\t\tbreak\n"
                             "\t\tfi\n"
                             "\tdone\n"
                             "} &\n"
                             "fi\n"];
        
        rcImaging = [rcImaging stringByAppendingString:setDate];
    }
    
    NSString *disableGatekeeper = [NSString stringWithFormat:@"\n"
                                   "###\n"
                                   "### Disable Gatekeeper\n"
                                   "###\n"
                                   "if [ -e /usr/sbin/spctl ]; then\n"
                                   "\t/usr/sbin/spctl --master-disable\n"
                                   "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:disableGatekeeper];
    
    if ( settingsDict[NBCSettingsARDPasswordKey] ) {
        NSString *startScreensharing;
        if ( osMinorVersion <= 7 ) {
            startScreensharing = [NSString stringWithFormat:@"\n"
                                  "### \n"
                                  "### Start Screensharing\n"
                                  "###\n"
                                  "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.agent.plist\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist\n"
                                  "fi\n"];
        } else if ( 8 <= osMinorVersion ) {
            startScreensharing = [NSString stringWithFormat:@"\n"
                                  "### \n"
                                  "### Start Screensharing\n"
                                  "###\n"
                                  "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist\n"
                                  "fi\n"];
        }
        
        rcImaging = [rcImaging stringByAppendingString:startScreensharing];
    }
    
    NSString *displaySleepMinutes;
    if ( [settingsDict[NBCSettingsDisplaySleepKey] boolValue] ) {
        displaySleepMinutes = [settingsDict[NBCSettingsDisplaySleepMinutesKey] stringValue];
    } else {
        displaySleepMinutes = @"0";
    }
    
    NSString *powerManagement = @"";
    if ( osMinorVersion <= 8 ) {
        powerManagement = [NSString stringWithFormat:@"\n"
                           "###\n"
                           "### Set power management policy\n"
                           "###\n"
                           "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 powerbutton 0 disksleep 0 ) &\n", displaySleepMinutes];
    } else {
        powerManagement = [NSString stringWithFormat:@"\n"
                           "###\n"
                           "### Set power management policy\n"
                           "###\n"
                           "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 disksleep 0 ) &\n", displaySleepMinutes];
    }
    
    rcImaging = [rcImaging stringByAppendingString:powerManagement];
    
    NSString *hostname = [NSString stringWithFormat:@"\n"
                          "###\n"
                          "### Set Temporary Hostname\n"
                          "###\n"
                          "computer_name=Mac-$( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'\"' '/IOPlatformSerialNumber/ { print $4 }' )\n"
                          "if [[ -n ${computer_name} ]]; then\n"
                          "\tcomputer_hostname=$( /usr/bin/tr '[:upper:]' '[:lower:]' <<< \"${computer_name}\" )\n"
                          "\t/usr/sbin/scutil --set ComputerName  \"${computer_name}\"\n"
                          "\t/usr/sbin/scutil --set LocalHostName \"${computer_hostname}\"\n"
                          "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:hostname];
    
    NSString *enableDiskUtilDebugMenu = [NSString stringWithFormat:@"\n"
                                         "###\n"
                                         "### Enable DiskUtility Debug menu\n"
                                         "###\n"
                                         "/usr/bin/defaults write com.apple.DiskUtility DUShowEveryPartition -bool YES\n"];
    rcImaging = [rcImaging stringByAppendingString:enableDiskUtilDebugMenu];
    
    if ( [settingsDict[NBCSettingsCertificatesKey] count] != 0 ) {
        NSString *addCertificates = [NSString stringWithFormat:@"\n"
                                     "###\n"
                                     "### Add Certificates\n"
                                     "###\n"
                                     "if [ -e /usr/local/certificates ]; then\n"
                                     "\t/usr/local/scripts/installCertificates.bash\n"
                                     "fi\n"];
        rcImaging = [rcImaging stringByAppendingString:addCertificates];
    }
    
    
    if ( [settingsDict[NBCSettingsUseBackgroundImageKey] boolValue] ) {
        NSString *startDesktopViewer = [NSString stringWithFormat:@"\n"
                                        "###\n"
                                        "### Start NBICreatorDesktopViewer\n"
                                        "###\n"
                                        "/Applications/NBICreatorDesktopViewer.app/Contents/MacOS/NBICreatorDesktopViewer &\n"];
        rcImaging = [rcImaging stringByAppendingString:startDesktopViewer];
    }

    if ( [settingsDict[NBCSettingsIncludeConsoleAppKey] boolValue] && [settingsDict[NBCSettingsLaunchConsoleAppKey] boolValue] ) {
        NSString *startConsole = [NSString stringWithFormat:@"\n"
                                  "###\n"
                                  "### Start Console\n"
                                  "###\n"
                                  "/Applications/Utilities/Console.app/Contents/MacOS/Console /var/log/system.log&\n"];
        rcImaging = [rcImaging stringByAppendingString:startConsole];
    }
    
    NSString *startImagr;
    if ( [settingsDict[NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemNBICreator] ) {
        startImagr = [NSString stringWithFormat:@"\n"
                      "###\n"
                      "### Start Imagr\n"
                      "###\n"
                      "/Applications/Imagr.app/Contents/MacOS/Imagr\n"];
    } else if ( [settingsDict[NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
        startImagr = [NSString stringWithFormat:@"\n"
                      "###\n"
                      "### Start Imagr\n"
                      "###\n"
                      "/Volumes/Image\\ Volume/Packages/Imagr.app/Contents/MacOS/Imagr\n"];
    }
    rcImaging = [rcImaging stringByAppendingString:startImagr];
    
    if ( [settingsDict[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
        NSString *stopSystemUIServer = [NSString stringWithFormat:@"\n"
                                        "###\n"
                                        "### Stop SystemUIServer\n"
                                        "###\n"
                                        "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.SystemUIServer.plist\n"];
        rcImaging = [rcImaging stringByAppendingString:stopSystemUIServer];
    }
    
    return rcImaging;
}


+ (NSString *)generateCasperRCCdromPreWSForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion {
#pragma unused(settingsDict)
    NSString *rcImaging = [NSString stringWithFormat:@"#!/bin/bash\n"];
    
    if ( 11 <= osMinorVersion ) {
        
    }
    
    NSString *setMountDisks = [NSString stringWithFormat:@"\n"
                               "###\n"
                               "### Mount Local Disks\n"
                               "###\n"
                               "for disk in $( ls /dev/disk* | grep -v disk[0-9]s[0-9]+ ); do\n"
                               "\t/usr/sbin/diskutil mount $disk &\n"
                               "done\n"];
    
    rcImaging = [rcImaging stringByAppendingString:setMountDisks];
    
    return rcImaging;
}

+ (NSString *)generateCasperRCImagingForNBICreator:(NSDictionary *)settingsDict osMinorVersion:(int)osMinorVersion {
    
    NSString *rcImaging = [NSString stringWithFormat:@"#!/bin/bash\n"];
    
    if ( 11 <= osMinorVersion ) {
        if ( [settingsDict[NBCSettingsAddTrustedNetBootServersKey] boolValue] ) {
            NSString *setAddTrustedNetBootServers = [NSString stringWithFormat:@"\n"
                                                     "###\n"
                                                     "### Add Trusted NetBoot Servers\n"
                                                     "###\n"
                                                     "if [[ -f /usr/bin/csrutil ]] && [[ -f /usr/local/bsdpSources.txt ]]; then\n"
                                                     "\twhile read netBootServer\n"
                                                     "\tdo\n"
                                                     "\t\t/usr/bin/csrutil netboot add \"${netBootServer}\"\n"
                                                     "\tdone < \"/usr/local/bsdpSources.txt\"\n"
                                                     "fi\n"];
            rcImaging = [rcImaging stringByAppendingString:setAddTrustedNetBootServers];
        }
    }
    
    if ( [settingsDict[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
        NSString *setDate = [NSString stringWithFormat:@"\n"
                             "###\n"
                             "### Set Date\n"
                             "###\n"
                             "if [ -e /etc/ntp.conf ]; then\n"
                             "{"
                             "\tNTP_SERVERS=$( /usr/bin/awk '{ print $NF }' /etc/ntp.conf )\n"
                             "\tfor NTP_SERVER in ${NTP_SERVERS}; do\n"
                             "\t\t/usr/sbin/ntpdate -u \"${NTP_SERVER}\" 2>/dev/null\n"
                             "\t\tif [ ${?} -eq 0 ]; then\n"
                             "\t\t\tbreak\n"
                             "\t\tfi\n"
                             "\tdone\n"
                             "} &\n"
                             "fi\n"];
        
        rcImaging = [rcImaging stringByAppendingString:setDate];
    }
    
    NSString *disableGatekeeper = [NSString stringWithFormat:@"\n"
                                   "###\n"
                                   "### Disable Gatekeeper\n"
                                   "###\n"
                                   "if [ -e /usr/sbin/spctl ]; then\n"
                                   "\t/usr/sbin/spctl --master-disable\n"
                                   "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:disableGatekeeper];
    
    NSString *loadSystemUIServer = [NSString stringWithFormat:@"\n"
                                    "###\n"
                                    "### Load SystemUIServerAgent\n"
                                    "###\n"
                                    "if [ -e /System/Library/LaunchAgents/com.apple.coreservices.uiagent.plist ]; then\n"
                                    "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.coreservices.uiagent.plist\n"
                                    "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:loadSystemUIServer];
    
    /*
    // Tests!!
    NSString *loadCvmsCompAgents = [NSString stringWithFormat:@"\n"
                                    "###\n"
                                    "### Load cvmsCompAgents\n"
                                    "###\n"
                                    "/bin/launchctl load /System/Library/LaunchAgents/com.apple.cvmsCompAgent*\n"];
    rcImaging = [rcImaging stringByAppendingString:loadCvmsCompAgents];
    */
    if ( settingsDict[NBCSettingsARDPasswordKey] ) {
        NSString *startScreensharing;
        if ( osMinorVersion <= 7 ) {
            startScreensharing = [NSString stringWithFormat:@"\n"
                                  "### \n"
                                  "### Start Screensharing\n"
                                  "###\n"
                                  "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.agent.plist\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist\n"
                                  "fi\n"];
        } else if ( 8 <= osMinorVersion ) {
            startScreensharing = [NSString stringWithFormat:@"\n"
                                  "### \n"
                                  "### Start Screensharing\n"
                                  "###\n"
                                  "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                  "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist\n"
                                  "fi\n"];
        }
        
        rcImaging = [rcImaging stringByAppendingString:startScreensharing];
    }
    
    NSString *displaySleepMinutes;
    if ( [settingsDict[NBCSettingsDisplaySleepKey] boolValue] ) {
        displaySleepMinutes = [settingsDict[NBCSettingsDisplaySleepMinutesKey] stringValue];
    } else {
        displaySleepMinutes = @"0";
    }
    
    NSString *powerManagement = @"";
    if ( osMinorVersion <= 8 ) {
        powerManagement = [NSString stringWithFormat:@"\n"
                           "###\n"
                           "### Set power management policy\n"
                           "###\n"
                           "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 powerbutton 0 disksleep 0 ) &\n", displaySleepMinutes];
    } else {
        powerManagement = [NSString stringWithFormat:@"\n"
                           "###\n"
                           "### Set power management policy\n"
                           "###\n"
                           "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 disksleep 0 ) &\n", displaySleepMinutes];
    }
    
    rcImaging = [rcImaging stringByAppendingString:powerManagement];
    
    NSString *hostname = [NSString stringWithFormat:@"\n"
                          "###\n"
                          "### Set Temporary Hostname\n"
                          "###\n"
                          "computer_name=$( ipconfig netbootoption machine_name 2>&1 )\n"
                          "if [[ ${?} -eq 0 ]] && [[ -n ${computer_name} ]]; then\n"
                          "\tcomputer_hostname=$( /usr/bin/tr '[:upper:]' '[:lower:]' <<< \"${computer_name}\" )\n"
                          "\t/usr/sbin/scutil --set ComputerName  \"${computer_name}\"\n"
                          "\t/usr/sbin/scutil --set LocalHostName \"${computer_hostname}\"\n"
                          "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:hostname];
    
    NSString *enableDiskUtilDebugMenu = [NSString stringWithFormat:@"\n"
                                         "###\n"
                                         "### Enable DiskUtility Debug menu\n"
                                         "###\n"
                                         "/usr/bin/defaults write com.apple.DiskUtility DUShowEveryPartition -bool YES\n"];
    rcImaging = [rcImaging stringByAppendingString:enableDiskUtilDebugMenu];
    
    if ( [settingsDict[NBCSettingsCertificatesKey] count] != 0 ) {
        NSString *addCertificates = [NSString stringWithFormat:@"\n"
                                     "###\n"
                                     "### Add Certificates\n"
                                     "###\n"
                                     "if [ -e /usr/local/certificates ]; then\n"
                                     "\t/usr/local/scripts/installCertificates.bash\n"
                                     "fi\n"];
        rcImaging = [rcImaging stringByAppendingString:addCertificates];
    }
    
    
    if ( [settingsDict[NBCSettingsUseBackgroundImageKey] boolValue] ) {
        NSString *startDesktopViewer = [NSString stringWithFormat:@"\n"
                                        "###\n"
                                        "### Start NBICreatorDesktopViewer\n"
                                        "###\n"
                                        "/Applications/NBICreatorDesktopViewer.app/Contents/MacOS/NBICreatorDesktopViewer &\n"];
        rcImaging = [rcImaging stringByAppendingString:startDesktopViewer];
    }
    
    if ( [settingsDict[NBCSettingsIncludeConsoleAppKey] boolValue] && [settingsDict[NBCSettingsLaunchConsoleAppKey] boolValue] ) {
        NSString *startConsole = [NSString stringWithFormat:@"\n"
                                  "###\n"
                                  "### Start Console\n"
                                  "###\n"
                                  "/Applications/Utilities/Console.app/Contents/MacOS/Console /var/log/system.log&\n"];
        rcImaging = [rcImaging stringByAppendingString:startConsole];
    }
    
    NSString *startCasperImaging;
    if ( [settingsDict[NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemNBICreator] ) {
        startCasperImaging = [NSString stringWithFormat:@"\n"
                              "###\n"
                              "### Start Casper Imaging\n"
                              "###\n"
                              "/Applications/Casper\\ Imaging.app/Contents/MacOS/Casper\\ Imaging\n"];
    } else if ( [settingsDict[NBCSettingsNBICreationToolKey] isEqualToString:NBCMenuItemSystemImageUtility] ) {
        startCasperImaging = [NSString stringWithFormat:@"\n"
                              "###\n"
                              "### Start Casper Imaging\n"
                              "###\n"
                              "/Volumes/Image\\ Volume/Packages/Casper\\ Imaging.app/Contents/MacOS/Casper\\ Imaging\n"];
    }
    rcImaging = [rcImaging stringByAppendingString:startCasperImaging];
    
    if ( [settingsDict[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
        NSString *stopSystemUIServer = [NSString stringWithFormat:@"\n"
                                        "###\n"
                                        "### Stop SystemUIServer\n"
                                        "###\n"
                                        "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.SystemUIServer.plist\n"];
        rcImaging = [rcImaging stringByAppendingString:stopSystemUIServer];
    }
    
    return rcImaging;
} // generateCasperRCImagingForNBICreator


@end
