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

- (NSArray *)generateScriptArgumentsForCreateNetInstall:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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

- (NSDictionary *)generateEnvironmentVariablesForCreateNetInstall:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
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

- (NSArray *)generateScriptArgumentsForSysBuilder:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSMutableArray *sysBuilderArguments = [[NSMutableArray alloc] init];
    NSLog(@"sysBuilderArguments=%@", sysBuilderArguments);
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
    NSString *sysBuilderPath = [[[workflowItem applicationSource] sysBuilderScript] path];
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
        [sysBuilderArguments addObject:systemVolumePath];
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
    
    NSString *nbiIndex = [NBCVariables expandVariables:userSettings[NBCSettingsNBIIndex]
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
    NSLog(@"sysBuilderArgumentsAAA=%@", sysBuilderArguments);
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
    NSString *nbiProtocol = userSettings[NBCSettingsNBIProtocol];
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
    NSString *nbiLanguage = userSettings[NBCSettingsNBILanguage];
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
    NSLog(@"sysBuilderArgumentsBBB=%@", sysBuilderArguments);
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
    BOOL useCustomBackground = [userSettings[NBCSettingsDeployStudioUseCustomBackgroundImageKey] boolValue];
    if ( useCustomBackground == YES ) {
        NSString *customBackgroundPath = userSettings[NBCSettingsDeployStudioCustomBackgroundImageKey];
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
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *rcImaging = [NSString stringWithFormat:@"#!/bin/bash\n"];
    
    NSString *setDate = [NSString stringWithFormat:@"\n"
                         "###\n"
                         "### Set Date\n"
                         "###\n"
                         "if [ -e /etc/ntp.conf ]; then\n"
                         "\tNTP_SERVERS=$( /bin/cat /etc/ntp.conf | /usr/bin/awk '{ print $NF }' )\n"
                         "\tfor NTP_SERVER in ${NTP_SERVERS}; do\n"
                         "\t\t/usr/sbin/ntpdate -u \"${NTP_SERVER}\" 2>/dev/null\n"
                         "\t\tif [ ${?} -eq 0 ]; then\n"
                         "\t\t\tbreak\n"
                         "\t\tfi\n"
                         "\tdone\n"
                         "fi\n"];
    rcImaging = [rcImaging stringByAppendingString:setDate];
    
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
        } else if ( osMinorVersion >= 8 ) {
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
    
    if ( settingsDict[NBCSettingsDisplaySleepKey] ) {
        NSString *displaySleep = settingsDict[NBCSettingsDisplaySleepMinutesKey];
        NSString *powerManagement = @"";
        if ( osMinorVersion <= 8 ) {
            powerManagement = [NSString stringWithFormat:@"\n"
                               "###\n"
                               "### Set power management policy\n"
                               "###\n"
                               "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 powerbutton 0 disksleep 0 ) &\n", displaySleep];
        } else {
            powerManagement = [NSString stringWithFormat:@"\n"
                               "###\n"
                               "### Set power management policy\n"
                               "###\n"
                               "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 disksleep 0 ) &\n", displaySleep];
        }
        rcImaging = [rcImaging stringByAppendingString:powerManagement];
    }
    
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
    
    if ( [settingsDict[NBCSettingsCertificates] count] != 0 ) {
        NSString *createSystemKeychain = [NSString stringWithFormat:@"\n"
                                          "###\n"
                                          "### Create System Keychain\n"
                                          "###\n"
                                          "if [ -e /usr/sbin/systemkeychain ]; then\n"
                                          "\t/usr/sbin/systemkeychain -fcC\n"
                                          "fi\n"];
        rcImaging = [rcImaging stringByAppendingString:createSystemKeychain];
        
        NSString *addCertificates = [NSString stringWithFormat:@"\n"
                                     "###\n"
                                     "### Add Certificates\n"
                                     "###\n"
                                     "if [ -e /usr/local/certificates ]; then\n"
                                     "\t/usr/local/scripts/installCertificates.bash\n"
                                     "fi\n"];
        rcImaging = [rcImaging stringByAppendingString:addCertificates];
    }
    
    NSString *startImagr = [NSString stringWithFormat:@"\n"
                            "###\n"
                            "### Start Imagr\n"
                            "###\n"
                            "/Applications/Imagr.app/Contents/MacOS/Imagr\n"];
    rcImaging = [rcImaging stringByAppendingString:startImagr];
    
    if ( [settingsDict[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
        
        NSString *stopSystemUIServer = [NSString stringWithFormat:@"\n"
                                        "###\n"
                                        "### Stop systemUIServer\n"
                                        "###\n"
                                        "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.SystemUIServer.plist\n"];
        rcImaging = [rcImaging stringByAppendingString:stopSystemUIServer];
    }
    
    return rcImaging;
}

@end
