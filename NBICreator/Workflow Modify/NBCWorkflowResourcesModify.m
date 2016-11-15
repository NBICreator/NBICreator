//
//  NBCWorkflowResourcesModify.m
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

#import "NBCConstants.h"
#import "NBCError.h"
#import "NBCSource.h"
#import "NBCTarget.h"
#import "NBCWorkflowItem.h"
#import "NBCWorkflowResourcesModify.h"
#import "NSString+validIP.h"
#import "NBCLog.h"

@implementation NBCWorkflowResourcesModify

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithWorkflowItem:(NBCWorkflowItem *)workflowItem {
    self = [super init];
    if (self != nil) {
        _workflowItem = workflowItem;
    }
    return self;
} // init

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Prepare Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSArray *)prepareResourcesToModify:(NSError **)error {

    DDLogInfo(@"Preparing resources to modify...");

    NSURL *baseSystemVolumeURL = [[_workflowItem target] baseSystemVolumeURL];
    if ([baseSystemVolumeURL checkResourceIsReachableAndReturnError:error]) {
        [self setBaseSystemVolumeURL:baseSystemVolumeURL];
        DDLogDebug(@"[DEBUG] BaseSystem volume path: %@", [_baseSystemVolumeURL path]);
    } else {
        return nil;
    }

    [self setWorkflowType:[_workflowItem workflowType]];

    [self setSourceVersionMinor:(int)[[[_workflowItem source] expandVariables:@"%OSMINOR%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (minor): %d", _sourceVersionMinor);

    [self setIsNBI:([[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI]) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", (_isNBI) ? @"YES" : @"NO");

    [self setCreationTool:[_workflowItem userSettings][NBCSettingsNBICreationToolKey]];
    DDLogDebug(@"[DEBUG] Creation tool: %@", _creationTool);

    if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
        NSURL *netInstallVolumeURL = [[_workflowItem target] nbiNetInstallVolumeURL];
        if ([netInstallVolumeURL checkResourceIsReachableAndReturnError:error]) {
            [self setNetInstallVolumeURL:netInstallVolumeURL];
            DDLogDebug(@"[DEBUG] NetInstall volume path: %@", [_netInstallVolumeURL path]);
        } else {
            return nil;
        }
    }

    [self setSettingsChanged:[_workflowItem userSettingsChanged]];

    [self setUserSettings:[_workflowItem userSettings]];

    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];

    // ---------------------------------------------------------------------------------
    //  Apple Installer
    // ---------------------------------------------------------------------------------
    // NOTE - This is for testing to remove the files for the Apple Installer, when not needed.
    /*
    if ( ! _isNBI && (
                      _workflowType == kWorkflowTypeImagr ||
                      _workflowType == kWorkflowTypeCasper
                      ) ) {
        [self modifyAppleInstaller:modifyDictArray];
    }
     */
    // ---------------------------------------------------------------------------------
    //  Bluetooth
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]))) {
        if ([_userSettings[NBCSettingsDisableBluetoothKey] boolValue]) {
            [self modifyBluetooth:modifyDictArray];
        }
    }

    // ---------------------------------------------------------------------------------
    //  BootPlist (com.apple.Boot.plist)
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsUseVerboseBootKey] boolValue]))) {
        if ([_userSettings[NBCSettingsUseVerboseBootKey] boolValue]) {
            [self modifyBootPlist:modifyDictArray];
        }
    }

    // ---------------------------------------------------------------------------------
    //  Casper Imaging
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeCasper)) && [_workflowItem workflowType] == kWorkflowTypeCasper) {
        if (![self modifyCasperImaging:modifyDictArray error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  Console.app
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsIncludeConsoleAppKey] boolValue]))) {
        if ([_userSettings[NBCSettingsIncludeConsoleAppKey] boolValue]) {
            [self modifyConsole:modifyDictArray];
        }
    }

    // ----------------------------------------------------------------
    //  Desktop Picture
    // ----------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsUseBackgroundImageKey] boolValue]))) {
        if ([_userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [_userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath]) {
            [self modifyDesktopPicture:modifyDictArray];
        }
    }

    // ----------------------------------------------------------------
    //  Fonts
    // ----------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        if (11 <= _sourceVersionMinor) {
            [self modifyFonts:modifyDictArray];
        }
    }

    // ----------------------------------------------------------------
    // ImagrPlist (com.grahamgilbert.Imagr.plist)
    // ----------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr)) ||
        (_isNBI && ([_settingsChanged[NBCSettingsImagrConfigurationURL] boolValue] || [_settingsChanged[NBCSettingsImagrReportingURL] boolValue] ||
                    [_settingsChanged[NBCSettingsImagrSyslogServerURI] boolValue] || [_settingsChanged[NBCSettingsImagrBackgroundImage] boolValue]))) {
        [self modifyImagrPlist:modifyDictArray];
    }

    // ---------------------------------------------------------------------------------
    //  KextdPlist (com.apple.kextd.plist)
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) ||
        (_isNBI && ([_settingsChanged[NBCSettingsDisableWiFiKey] boolValue] || [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]))) {
        [self modifyKextdPlist:modifyDictArray];
    }

    // ----------------------------------------------------------------
    //  LaunchDaemons
    // ----------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        if (11 <= _sourceVersionMinor) {
            [self modifyLaunchDaemons:modifyDictArray];
        }
    }

    // ----------------------------------------------------------------
    //  Localization
    // ----------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) ||
        (_isNBI && ([_settingsChanged[NBCSettingsLanguageKey] boolValue] || [_settingsChanged[NBCSettingsKeyboardLayoutKey] boolValue] || [_settingsChanged[NBCSettingsTimeZoneKey] boolValue]))) {
        if (![self modifyLocalization:modifyDictArray error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  ntp
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) ||
        (_isNBI && ([_settingsChanged[NBCSettingsUseNetworkTimeServerKey] boolValue] || [_settingsChanged[NBCSettingsNetworkTimeServerKey] boolValue]))) {
        if ([_userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue]) {
            if (![self modifyNTP:modifyDictArray error:error]) {
                return nil;
            }
        }
    }

    // ---------------------------------------------------------------------------------
    //  rc.cdrom & rc.cdm.cdrom
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) ||
        (_isNBI &&
         ([_settingsChanged[NBCSettingsCertificatesKey] boolValue] || [_settingsChanged[NBCSettingsAddCustomRAMDisksKey] boolValue] || [_settingsChanged[NBCSettingsRAMDisksKey] boolValue]))) {
        if (![self modifyRCCdrom:modifyDictArray error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  rc.imaging
    // ---------------------------------------------------------------------------------
    NSString *nbiToolPath;
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr)) {
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            nbiToolPath = [NSString stringWithFormat:@"/%@", NBCImagrApplicationNBICreatorTargetURL];
        } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            nbiToolPath = [NSString stringWithFormat:@"/Volumes/Image\\ Volume/%@", NBCImagrApplicationTargetURL];
        } else {
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool for Imagr: %@", _creationTool]];
            return nil;
        }

        if (![self modifyRCImaging:modifyDictArray nbiToolPath:nbiToolPath error:error]) {
            return nil;
        }
    } else if (!_isNBI && (_workflowType == kWorkflowTypeCasper)) {
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
            nbiToolPath = [NSString stringWithFormat:@"/%@", NBCCasperImagingApplicationNBICreatorTargetURL];
        } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            nbiToolPath = [NSString stringWithFormat:@"/Volumes/Image\\ Volume/%@", NBCCasperImagingApplicationTargetURL];
        } else {
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool for Casper: %@", _creationTool]];
            return nil;
        }

        if (![self modifyRCImaging:modifyDictArray nbiToolPath:nbiToolPath error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  rc.install
    // ---------------------------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        if (11 <= _sourceVersionMinor) {
            if (![self modifyRCInstall:modifyDictArray error:error]) {
                return nil;
            }
        }
    }

    // ---------------------------------------------------------------------------------
    //  Screen Sharing
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) && [_userSettings[NBCSettingsARDPasswordKey] length] != 0) {
        if (![self modifyScreenSharing:modifyDictArray error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  Spotlight
    // ---------------------------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        [self modifySpotlight:modifyDictArray];
    }

    // ---------------------------------------------------------------------------------
    //  SystemUIServer
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr)) && [_userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue]) {
        if (![self modifySystemUIServer:modifyDictArray error:error]) {
            return nil;
        }
    }

    // ---------------------------------------------------------------------------------
    //  Utilities Menu
    // ---------------------------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        [self modifyUtilitiesMenu:modifyDictArray];
    }

    // ---------------------------------------------------------------------------------
    //  WiFi
    // ---------------------------------------------------------------------------------
    if ((!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) || (_isNBI && ([_settingsChanged[NBCSettingsDisableWiFiKey] boolValue]))) {
        if ([_userSettings[NBCSettingsDisableWiFiKey] boolValue]) {
            [self modifyWiFi:modifyDictArray];
        }
    }

    // ---------------------------------------------------------------------------------
    //  Folders (Need to be here (last) to be created first)
    // ---------------------------------------------------------------------------------
    if (!_isNBI && (_workflowType == kWorkflowTypeImagr || _workflowType == kWorkflowTypeCasper)) {
        [self modifyFolders:modifyDictArray];
    }

    return [modifyDictArray copy];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addFoldersToBaseSystem:(NSArray *)folderArray modifyDictArray:(NSMutableArray *)modifyDictArray {
    DDLogDebug(@"[DEBUG] Adding %lu folders to create in BaseSystem", (unsigned long)[folderArray count]);

    NSURL *folderURL;
    for (NSString *folderRelativePath in folderArray) {
        DDLogDebug(@"[DEBUG] Relative path to folder: %@", folderRelativePath);
        folderURL = [_baseSystemVolumeURL URLByAppendingPathComponent:folderRelativePath];
        DDLogDebug(@"[DEBUG] Full path to folder: %@", [folderURL path]);
        [modifyDictArray insertObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
            NBCWorkflowModifyTargetURL : [folderURL path],
            NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }
                              atIndex:0];
    }
}

- (void)deleteItemsFromBaseSystem:(NSArray *)itemArray modifyDictArray:(NSMutableArray *)modifyDictArray beforeModifications:(BOOL)beforeModifications {
    DDLogDebug(@"[DEBUG] Adding %lu items to delete from BaseSyste", (unsigned long)[itemArray count]);

    NSURL *itemURL;
    NSError *error = nil;

    for (NSString *itemRelativePath in itemArray) {
        DDLogDebug(@"[DEBUG] Relative path to delete: %@", itemRelativePath);
        itemURL = [_baseSystemVolumeURL URLByAppendingPathComponent:itemRelativePath];
        DDLogDebug(@"[DEBUG] Full path to delete: %@", [itemURL path]);
        if ([itemURL checkResourceIsReachableAndReturnError:&error]) {
            if (beforeModifications) {
                [modifyDictArray insertObject:@{ NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete, NBCWorkflowModifyTargetURL : [itemURL path] } atIndex:0];
            } else {
                [modifyDictArray addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete, NBCWorkflowModifyTargetURL : [itemURL path]}];
            }
        } else {
            DDLogDebug(@"[DEBUG] %@", [error localizedDescription]);
        }
    }
}

- (void)disableKernelExtensions:(NSArray *)kernelExtensions modifyDictArray:(NSMutableArray *)modifyDictArray {
    DDLogDebug(@"[DEBUG] Adding %lu kernel extensions to disable from BaseSyste", (unsigned long)[kernelExtensions count]);

    NSURL *kextURL;
    NSURL *kextTargetURL;
    NSError *error = nil;

    for (NSString *kextRelativePath in kernelExtensions) {
        DDLogDebug(@"[DEBUG] Relative path to kernel extension: %@", kextRelativePath);
        kextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:kextRelativePath];
        DDLogDebug(@"[DEBUG] Full path to kernel extension: %@", [kextURL path]);
        if ([kextURL checkResourceIsReachableAndReturnError:&error]) {
            kextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:[NSString stringWithFormat:@"System/Library/ExtensionsDisabled/%@", [kextURL lastPathComponent]]];

            // Update modification array
            [modifyDictArray addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove, NBCWorkflowModifySourceURL : [kextURL path], NBCWorkflowModifyTargetURL : [kextTargetURL path]}];
        } else {
            DDLogDebug(@"[DEBUG] %@", [error localizedDescription]);
        }
    }
} // disableLaunchDaemons:modifyDictArray

- (void)disableLaunchDaemons:(NSArray *)launchDaemons modifyDictArray:(NSMutableArray *)modifyDictArray {

    NSError *error = nil;

    // ------------------------------------------------------------------
    //  /System/Library/LaunchDaemons
    //  /System/Library/LaunchDaemonsDisabled
    // ------------------------------------------------------------------
    NSURL *launchDaemonsURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons" isDirectory:YES];
    NSURL *launchDaemonsTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemonsDisabled" isDirectory:YES];
    ;
    NSURL *launchDaemonURL;
    NSURL *launchDaemonTargetURL;

    for (NSString *launchDaemon in launchDaemons) {
        launchDaemonURL = [launchDaemonsURL URLByAppendingPathComponent:launchDaemon];
        launchDaemonTargetURL = [launchDaemonsTargetURL URLByAppendingPathComponent:launchDaemon];

        if (![launchDaemonURL checkResourceIsReachableAndReturnError:&error]) {
            DDLogDebug(@"[DEBUG] %@", error.localizedDescription);
        } else {
            // Update modification array
            [modifyDictArray
                addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove, NBCWorkflowModifySourceURL : [launchDaemonURL path], NBCWorkflowModifyTargetURL : [launchDaemonTargetURL path]}];
        }
    }
} // disableLaunchDaemons:modifyDictArray

- (NSNumber *)keyboardLayoutIDFromSourceID:(NSString *)sourceID {
#pragma unused(sourceID)
    // +IMPROVEMENT Have not found a reliable way to get the current ID for a keyboard, so for now just sets 7 ( Swedish-Pro ) as it doesn't seem to matter if the source ID exists.
    return @7;
} // keyboardLayoutIDFromSourceID

- (BOOL)verifyNTPServer:(NSString *)ntpServer error:(NSError **)error {

    DDLogDebug(@"[DEBUG] Verifying NTP server: %@...", ntpServer);

    NSTask *digTask = [[NSTask alloc] init];
    [digTask setLaunchPath:@"/usr/bin/dig"];
    [digTask setArguments:@[ @"+short", ntpServer ]];
    [digTask setStandardOutput:[NSPipe pipe]];
    [digTask setStandardError:[NSPipe pipe]];
    [digTask launch];
    [digTask waitUntilExit];

    NSData *stdOutData = [[[digTask standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];

    NSData *stdErrData = [[[digTask standardError] fileHandleForReading] readDataToEndOfFile];
    NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];

    if ([digTask terminationStatus] == 0) {
        NSString *digOutput = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        if ([digOutput length] != 0) {

            NSArray *ntpServerArray = [digOutput componentsSeparatedByString:@"\n"];
            ntpServer = [NSString stringWithFormat:@"server %@", ntpServer];
            for (NSString *host in ntpServerArray) {
                if ([host length] != 0) {
                    if ([host isValidIPAddress]) {
                        DDLogDebug(@"[DEBUG] NTP server host: %@", host);
                        ntpServer = [ntpServer stringByAppendingString:[NSString stringWithFormat:@"\nserver %@", host]];
                    } else {
                        *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"NTP server host is invalid: %@", host]];
                        return NO;
                    }
                }
            }

            if ([ntpServer length] != 0) {
                return YES;
            } else {
                *error = [NBCError errorWithDescription:@"NTP server ip was empty"];
                return NO;
            }
        } else {
            // Add to warning report!
            DDLogWarn(@"[WARN] Could not resolve ntp server!");
            return YES;
        }
    } else {
        // Add to warning report!
        DDLogWarn(@"[dig][stdout] %@", stdOut);
        DDLogWarn(@"[dig][stderr] %@", stdErr);
        DDLogWarn(@"[WARN] Got no output from dig!");
        return YES;
    }
} // verifyNTPServer

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Modify
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyAppleInstaller:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for AppleInstaller...");

    // --------------------------------------------------------------
    //  /Install OS X ... .app
    // --------------------------------------------------------------
    NSError *error = nil;
    NSArray *rootItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_baseSystemVolumeURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];

    __block NSString *installerPath;
    if ([rootItems count] == 0 && error) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    } else {
        NSArray *itemsFiltered = [rootItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'app'"]];
        [itemsFiltered enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger __unused idx, BOOL *_Nonnull stop) {
          NSString *itemName = [obj lastPathComponent];
          if (([itemName hasPrefix:@"Install OS X"] || [itemName hasPrefix:@"Install macOS"]) && [itemName hasSuffix:@".app"]) {
              installerPath = [obj lastPathComponent];
              DDLogDebug(@"[DEBUG] Installer path: %@", installerPath);
              *stop = YES;
              ;
          }
        }];
    }

    // --------------------------------------------------------------
    //  Delete installer items
    // --------------------------------------------------------------
    [self deleteItemsFromBaseSystem:@[ installerPath ?: @"", @"Safari.app", @"System/Installation/CDIS" ] modifyDictArray:modifyDictArray beforeModifications:YES];

    // --------------------------------------------------------------
    //  Disable installer LaunchDaemons
    // --------------------------------------------------------------
    [self disableLaunchDaemons:@[
        @"com.apple.installer.instlogd.plist",
        @"com.apple.recovery.storeassetd.plist",
        @"com.apple.recovery.storeaccountd.plist",
        @"com.apple.recovery.storedownloadd.plist",
        @"com.apple.recovery.storeuid.plist",
        @"com.apple.storereceiptinstaller.plist"
    ]
               modifyDictArray:modifyDictArray];
}

- (void)modifyBluetooth:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Bluetooth...");

    [self disableKernelExtensions:@[
        @"System/Library/Extensions/IOBluetoothFamily.kext",
        @"System/Library/Extensions/IOBluetoothHIDDriver.kext",
        @"System/Library/Extensions/AppleBluetoothHIDMouse.kext",
        @"System/Library/Extensions/AppleBluetoothHIDKeyboard.kext",
        @"System/Library/Extensions/AppleBluetoothMultitouch.kext"
    ]
                  modifyDictArray:modifyDictArray];

    /* Testing only, renders their parent kexts left out of prelinked kernel because of invalid signing when modified
     [self disableKernelExtensions:@[
     @"System/Library/Extensions/AppleHIDMouse.kext/Contents/PlugIns/AppleBluetoothHIDMouse.kext",
     @"System/Library/Extensions/AppleHIDKeyboard.kext/Contents/PlugIns/AppleBluetoothHIDKeyboard.kext",
     @"System/Library/Extensions/AppleTopCase.kext/Contents/PlugIns/AppleHSBluetoothDriver.kext"
     ] modifyDictArray:modifyDictArray];
     */

    [self disableLaunchDaemons:@[ @"com.apple.bluetoothReporter.plist", @"com.apple.blued.plist" ] modifyDictArray:modifyDictArray];
}

+ (void)modifyBootPlistForUSB:(NSMutableArray *)modifyDictArray
       netInstallDiskImageURL:(NSURL *)netInstallDiskImageURL
       netInstallIsBaseSystem:(BOOL)netInstallIsBaseSystem
                 usbVolumeURL:(NSURL *)usbVolumeURL {

    DDLogInfo(@"Preparing modifications for USB com.apple.Boot.plist...");

    NSURL *comAppleBootPlistURLBootFiles = [usbVolumeURL URLByAppendingPathComponent:@".NBIBootFiles/com.apple.Boot.plist"];
    NSURL *comAppleBootPlistURL = [usbVolumeURL URLByAppendingPathComponent:@"Library/Preferences/SystemConfiguration/com.apple.Boot.plist"];
    NSMutableDictionary *comAppleBootPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:comAppleBootPlistURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comAppleBootPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comAppleBootPlistURL path] error:nil]
                                                    ?: @{ NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644 };
    // Kernel Flags
    NSString *kernelFlagsRootDMG;
    if (netInstallIsBaseSystem) {
        kernelFlagsRootDMG = [NSString stringWithFormat:@"root-dmg=file:///%@", [netInstallDiskImageURL lastPathComponent]];
    } else {
        kernelFlagsRootDMG = [NSString stringWithFormat:@"container-dmg=file:///%@ root-dmg=file:///BaseSystem.dmg", [netInstallDiskImageURL lastPathComponent]];
    }

    if ([comAppleBootPlistDict[@"Kernel Flags"] length] != 0) {
        NSString *kernelFlags = comAppleBootPlistDict[@"Kernel Flags"];
        comAppleBootPlistDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ %@", kernelFlagsRootDMG, kernelFlags];
    } else {
        comAppleBootPlistDict[@"Kernel Flags"] = kernelFlagsRootDMG;
    }

    // Kernel Cache
    comAppleBootPlistDict[@"Kernel Cache"] = @"/.NBIBootFiles/prelinkedkernel";

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : comAppleBootPlistDict,
        NBCWorkflowModifyAttributes : comAppleBootPlistAttributes,
        NBCWorkflowModifyTargetURL : [comAppleBootPlistURLBootFiles path]
    }];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : comAppleBootPlistDict,
        NBCWorkflowModifyAttributes : comAppleBootPlistAttributes,
        NBCWorkflowModifyTargetURL : [comAppleBootPlistURL path]
    }];
}

- (void)modifyBootPlist:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for com.apple.Boot.plist...");

    NSURL *nbiURL = [_workflowItem temporaryNBIURL];

    // ---------------------------------------------------------------
    //  /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
    // ---------------------------------------------------------------
    NSURL *comAppleBootPlistURL = [nbiURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    NSMutableDictionary *comAppleBootPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:comAppleBootPlistURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comAppleBootPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comAppleBootPlistURL path] error:nil]
                                                    ?: @{ NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644 };

    if ([comAppleBootPlistDict[@"Kernel Flags"] length] != 0) {
        NSString *kernelFlags = comAppleBootPlistDict[@"Kernel Flags"];
        if (![kernelFlags containsString:@"-v"]) {
            comAppleBootPlistDict[@"Kernel Flags"] = [NSString stringWithFormat:@"%@ -v", kernelFlags];
        } else {
            DDLogInfo(@"com.apple.Boot.plist already includes kernel flag '-v'");
            return;
        }
    } else {
        comAppleBootPlistDict[@"Kernel Flags"] = @"-v";
    }

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : comAppleBootPlistDict,
        NBCWorkflowModifyAttributes : comAppleBootPlistAttributes,
        NBCWorkflowModifyTargetURL : [comAppleBootPlistURL path]
    }];
} // modifySettingsForBootPlist

- (BOOL)modifyCasperImaging:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for Casper Imaging...");

    // ---------------------------------------------------------------
    //  /var/root/Library/Preferences/com.jamfsoftware.jss
    //  This is written to: /usr/local/preferences/com.jamfsoftware.jss.plist and copied to the correct path by the rc-scripts to make it read/writeable
    // ---------------------------------------------------------------
    NSURL *comJamfsoftwareJSSURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/preferences/com.jamfsoftware.jss.plist"];
    NSMutableDictionary *comJamfsoftwareJSSDict = [NSMutableDictionary dictionaryWithContentsOfURL:comJamfsoftwareJSSURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comJamfsoftwareJSSAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comJamfsoftwareJSSURL path] error:nil]
                                                     ?: @{ NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644 };

    comJamfsoftwareJSSDict[@"allowInvalidCertificate"] = @NO;

    // Update com.jamfsoftware.jss with user settings (Optional)
    NSString *jssURLString = [_workflowItem userSettings][NBCSettingsCasperJSSURLKey];
    DDLogDebug(@"[DEBUG] JSS URL: %@", jssURLString);

    if ([jssURLString length] != 0) {
        NSURL *jssURL = [NSURL URLWithString:jssURLString];
        comJamfsoftwareJSSDict[@"url"] = jssURLString ?: @"";

        comJamfsoftwareJSSDict[@"secure"] = [[jssURL scheme] isEqualTo:@"https"] ? @YES : @NO;
        DDLogDebug(@"[DEBUG] JSS Secure: %@", [[jssURL scheme] isEqualTo:@"https"] ? @"YES" : @"NO");

        comJamfsoftwareJSSDict[@"address"] = [jssURL host] ?: @"";
        DDLogDebug(@"[DEBUG] JSS Address: %@", [jssURL host]);

        NSNumber *port = @80;
        if ([jssURL port] == nil && [[jssURL scheme] isEqualTo:@"https"]) {
            port = @443;
        } else if ([jssURL port] != nil) {
            port = [jssURL port];
        }
        comJamfsoftwareJSSDict[@"port"] = [port stringValue] ?: @"";
        DDLogDebug(@"[DEBUG] JSS Port: %@", [port stringValue]);

        comJamfsoftwareJSSDict[@"path"] = [jssURL path] ?: @"";
        DDLogDebug(@"[DEBUG] JSS Path: %@", [jssURL path]);
    } else {
        DDLogInfo(@"No JSS URL was entered");
    }

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : comJamfsoftwareJSSDict,
        NBCWorkflowModifyAttributes : comJamfsoftwareJSSAttributes,
        NBCWorkflowModifyTargetURL : [comJamfsoftwareJSSURL path]
    }];

    // --------------------------------------------------------------
    // Casper Imaging Debug
    // --------------------------------------------------------------
    NSURL *casperImagingURL;
    if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
        casperImagingURL = [_baseSystemVolumeURL URLByAppendingPathComponent:NBCCasperImagingApplicationNBICreatorTargetURL];
    } else {
        casperImagingURL = [_netInstallVolumeURL URLByAppendingPathComponent:NBCCasperImagingApplicationTargetURL];
    }
    DDLogDebug(@"[DEBUG] Casper Imaging path: %@", [casperImagingURL path]);

    if (![_creationTool isEqualToString:NBCMenuItemNBICreator] || [casperImagingURL checkResourceIsReachableAndReturnError:error]) {
        NSURL *casperImagingDebugURL = [casperImagingURL URLByAppendingPathComponent:@"Contents/Support/debug" isDirectory:YES];

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
            NBCWorkflowModifyTargetURL : [casperImagingDebugURL path],
            NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
        }];
    } else {
        return NO;
    }

    // --------------------------------------------------------------
    // /var/root/.CFUserTextEncoding
    // --------------------------------------------------------------
    NSURL *varRootCFUserTextEncodingURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"var/root/.CFUserTextEncoding"];
    NSString *varRootCFUserTextEncodingContentString = @"0:0";
    NSData *varRootCFUserTextEncodingContentData = [varRootCFUserTextEncodingContentString dataUsingEncoding:NSUTF8StringEncoding];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
        NBCWorkflowModifyContent : varRootCFUserTextEncodingContentData,
        NBCWorkflowModifyTargetURL : [varRootCFUserTextEncodingURL path],
        NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
    }];

    return YES;
} // modifyCasperImaging

- (void)modifyConsole:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Console...");

    // ---------------------------------------------------------------------------------
    //  /System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist
    // ---------------------------------------------------------------------------------
    NSURL *utilitiesPlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist"];
    if ([utilitiesPlistURL checkResourceIsReachableAndReturnError:nil]) {
        NSMutableDictionary *utilitiesPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:utilitiesPlistURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *utilitiesPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[utilitiesPlistURL path] error:nil]
                                                     ?: @{ NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644 };

        // Add console to Installer utilities menu
        NSMutableArray *menuArray = [[NSMutableArray alloc] initWithArray:utilitiesPlistDict[@"Menu"]] ?: [[NSMutableArray alloc] init];
        ;
        [menuArray addObject:@{ @"BundlePath" : @"/Applications/Utilities/Console.app", @"Path" : @"/Applications/Utilities/Console.app/Contents/MacOS/Console", @"TitleKey" : @"Console" }];
        utilitiesPlistDict[@"Menu"] = menuArray;

        // Add console to Installer buttons
        NSMutableArray *buttonsArray = [[NSMutableArray alloc] initWithArray:utilitiesPlistDict[@"Buttons"]] ?: [[NSMutableArray alloc] init];
        ;

        [buttonsArray addObject:@{
            @"BundlePath" : @"/Applications/Utilities/Console.app",
            @"Path" : @"/Applications/Utilities/Console.app/Contents/MacOS/Console",
            @"TitleKey" : @"Console",
            @"DescriptionKey" : @"Show Logs"
        }];
        utilitiesPlistDict[@"Buttons"] = buttonsArray;

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : utilitiesPlistDict,
            NBCWorkflowModifyAttributes : utilitiesPlistAttributes,
            NBCWorkflowModifyTargetURL : [utilitiesPlistURL path]
        }];
    }

    // ----------------------------------------------
    //  /Library/Preferences/com.apple.Console.plist
    // ----------------------------------------------
    NSURL *consolePlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.Console.plist"];
    NSMutableDictionary *consolePlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:consolePlistURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *consolePlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[consolePlistURL path] error:nil]
                                               ?: @{ NSFileOwnerAccountName : @"root",
                                                     NSFileGroupOwnerAccountName : @"wheel",
                                                     NSFilePosixPermissions : @0644 };

    // Hide log list
    consolePlistDict[@"LogOutlineViewVisible"] = @NO;

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : consolePlistDict,
        NBCWorkflowModifyAttributes : consolePlistAttributes,
        NBCWorkflowModifyTargetURL : [consolePlistURL path]
    }];
} // modifyConsole

- (BOOL)modifyDesktopPicture:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Desktop Picture...");

    // ------------------------------------------------------------------
    //  /Library/Desktop Pictures/...
    // ------------------------------------------------------------------
    NSString *desktopPictureDefaultPath;
    switch (_sourceVersionMinor) {
    case 11:
        desktopPictureDefaultPath = @"Library/Desktop Pictures/El Capitan.jpg";
        break;
    case 10:
        desktopPictureDefaultPath = @"Library/Desktop Pictures/Yosemite.jpg";
        break;
    case 9:
        desktopPictureDefaultPath = @"Library/Desktop Pictures/Wave.jpg";
        break;
    case 8:
        desktopPictureDefaultPath = @"Library/Desktop Pictures/Galaxy.jpg";
        break;
    case 7:
        desktopPictureDefaultPath = @"Library/Desktop Pictures/Lion.jpg";
        break;
    default:
        DDLogError(@"[ERROR] Unsupported os version: %d", _sourceVersionMinor);
        return NO;
        break;
    }

    NSURL *desktopPictureURL = [_baseSystemVolumeURL URLByAppendingPathComponent:desktopPictureDefaultPath];
    NSURL *desktopPictureTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/DefaultDesktop.jpg"];

    // Update modification array
    [modifyDictArray
        addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove, NBCWorkflowModifySourceURL : [desktopPictureURL path], NBCWorkflowModifyTargetURL : [desktopPictureTargetURL path]}];

    return YES;
} // modifyDesktopPicture

- (void)modifyFonts:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Fonts...");

    // --------------------------------------------------------------
    //  /Library/Application Support/Apple/Fonts/Language Support
    // --------------------------------------------------------------
    NSURL *languageSupportURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Application Support/Apple/Fonts/Language Support" isDirectory:YES];
    if ([languageSupportURL checkResourceIsReachableAndReturnError:nil]) {

        NSURL *systemLibraryFontURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Fonts"];

        // ---------------------------------------------------------------------
        //  Get all contents of language support folder
        // ---------------------------------------------------------------------
        NSArray *languageSupportContents =
            [[NSFileManager defaultManager] contentsOfDirectoryAtURL:languageSupportURL includingPropertiesForKeys:@[] options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];

        // ---------------------------------------------------------------------
        //  Create a move modification for all fonts ending in .ttf
        // ---------------------------------------------------------------------
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension='ttf'"];
        for (NSURL *fontURL in [languageSupportContents filteredArrayUsingPredicate:predicate]) {

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                NBCWorkflowModifySourceURL : [fontURL path],
                NBCWorkflowModifyTargetURL : [[systemLibraryFontURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@", [fontURL lastPathComponent]]] path]
            }];
        }

        // ---------------------------------------------------------------------
        //  Clean up by removing empty folder
        // ---------------------------------------------------------------------
        [self deleteItemsFromBaseSystem:@[ @"Library/Application Support/Apple/Fonts" ] modifyDictArray:modifyDictArray beforeModifications:NO];
    }
}

- (void)modifyFolders:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for folders...");

    [self addFoldersToBaseSystem:@[
        @"usr/local",
        @"Library/LaunchAgents",
        @"Library/LaunchDaemons",
        @"Library/Application Support",
        @"System/Library/Caches/com.apple.kext.caches/Directories/System/Library/Extensions",
        @"System/Library/Caches/com.apple.kext.caches/Startup"
    ]
                 modifyDictArray:modifyDictArray];
} // modifyFolders

- (BOOL)modifyFolderPackages:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for folder Packages...");

    // --------------------------------------------------------------
    //  .../Packages
    // --------------------------------------------------------------
    NSURL *packagesFolderURL = [[[_workflowItem target] nbiNetInstallVolumeURL] URLByAppendingPathComponent:@"Packages"];
    DDLogDebug(@"[DEBUG] Packages folder path: %@", [packagesFolderURL path]);
    if (![packagesFolderURL checkResourceIsReachableAndReturnError:error]) {

        [modifyDictArray insertObject:@{ NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeDelete, NBCWorkflowModifyTargetURL : [packagesFolderURL path] } atIndex:0];

    } else {
        return NO;
    }

    // --------------------------------------------------------------
    //  .../Packages/Extras
    // --------------------------------------------------------------
    NSURL *extrasFolderURL = [packagesFolderURL URLByAppendingPathComponent:@"Extras"];
    DDLogDebug(@"[DEBUG] Extras folder path: %@", [extrasFolderURL path]);

    [modifyDictArray insertObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeFolder,
        NBCWorkflowModifyTargetURL : [extrasFolderURL path],
        NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0755}
    }
                          atIndex:0];

    return YES;
} // modifyFolderPackages

- (void)modifyImagrPlist:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for com.grahamgilbert.Imagr.plist...");

    // ------------------------------------------------------------------
    //  /Library/Preferences/com.grahamgilbert.Imagr.plist
    // ------------------------------------------------------------------
    NSString *comGrahamgilbertImagrPlistTargetPath;
    NSURL *comGrahamgilbertImagrPlistTargetURL;
    if ([_creationTool isEqualToString:NBCMenuItemNBICreator]) {
        comGrahamgilbertImagrPlistTargetPath = NBCImagrConfigurationPlistNBICreatorTargetURL;
        comGrahamgilbertImagrPlistTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:comGrahamgilbertImagrPlistTargetPath];
    } else {
        comGrahamgilbertImagrPlistTargetPath = NBCImagrConfigurationPlistTargetURL;
        comGrahamgilbertImagrPlistTargetURL = [_netInstallVolumeURL URLByAppendingPathComponent:comGrahamgilbertImagrPlistTargetPath];
    }
    DDLogDebug(@"[DEBUG] com.grahamgilbert.Imagr.plist path: %@", [comGrahamgilbertImagrPlistTargetURL path]);

    NSMutableDictionary *comGrahamgilbertImagrPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:comGrahamgilbertImagrPlistTargetURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comGrahamgilbertImagrPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comGrahamgilbertImagrPlistTargetURL path] error:nil]
                                                             ?: @{ NSFileOwnerAccountName : @"root",
                                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                                   NSFilePosixPermissions : @0644 };
    // Setting 'serverurl'
    NSString *configurationURL = _userSettings[NBCSettingsImagrConfigurationURL];
    if ([configurationURL length] != 0) {
        DDLogDebug(@"[DEBUG] Setting Imagr configuration URL: %@", configurationURL);
        comGrahamgilbertImagrPlistDict[@"serverurl"] = configurationURL;
    }

    // Setting 'background_window'
    NSString *backgroundImage = _userSettings[NBCSettingsImagrBackgroundImage];
    if ([backgroundImage length] != 0) {
        DDLogDebug(@"[DEBUG] Setting Imagr background image: %@", backgroundImage);
        comGrahamgilbertImagrPlistDict[NBCSettingsImagrBackgroundImageKey] = [backgroundImage lowercaseString];
    }

    // Setting 'reporting'
    NSString *reportingURL = _userSettings[NBCSettingsImagrReportingURL];
    if ([reportingURL length] != 0) {
        DDLogDebug(@"[DEBUG] Setting Imagr reporting URL: %@", reportingURL);
        comGrahamgilbertImagrPlistDict[NBCSettingsImagrReportingURLKey] = _userSettings[NBCSettingsImagrReportingURL];
    }

    // Setting 'syslog'
    NSString *syslogServerURI = _userSettings[NBCSettingsImagrSyslogServerURI];
    if ([syslogServerURI length] != 0) {
        DDLogDebug(@"[DEBUG] Setting Imagr syslog URI: %@", syslogServerURI);
        comGrahamgilbertImagrPlistDict[NBCSettingsImagrSyslogServerURIKey] = syslogServerURI;
    }

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : comGrahamgilbertImagrPlistDict,
        NBCWorkflowModifyAttributes : comGrahamgilbertImagrPlistAttributes,
        NBCWorkflowModifyTargetURL : [comGrahamgilbertImagrPlistTargetURL path]
    }];
} // modifyImagrPlist

- (void)modifyKextdPlist:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for com.apple.kextd.plist...");

    // ------------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.kextd.plist
    // ------------------------------------------------------------------
    NSURL *kextdLaunchDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.kextd.plist"];
    NSMutableDictionary *kextdLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:kextdLaunchDaemonURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *kextdLaunchDaemonAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[kextdLaunchDaemonURL path] error:nil]
                                                    ?: @{ NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644 };

    // Add '-no-caches' to ProgramArguments
    NSMutableArray *kextdProgramArguments = [NSMutableArray arrayWithArray:kextdLaunchDaemonDict[@"ProgramArguments"]];
    if (![kextdProgramArguments containsObject:@"-no-caches"]) {
        [kextdProgramArguments addObject:@"-no-caches"];
        kextdLaunchDaemonDict[@"ProgramArguments"] = kextdProgramArguments;

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : kextdLaunchDaemonDict,
            NBCWorkflowModifyAttributes : kextdLaunchDaemonAttributes,
            NBCWorkflowModifyTargetURL : [kextdLaunchDaemonURL path]
        }];
    } else {
        DDLogInfo(@"com.apple.kextd.plist already includes argument '-no-caches'");
    }
} // modifyKextd

- (void)modifyLaunchDaemons:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for launch daemons...");

    [self disableLaunchDaemons:@[
        @"com.apple.alf.agent.plist",
        @"com.apple.familycontrols.plist",
        @"com.apple.findmymac.plist",
        @"com.apple.findmymacmessenger.plist",
        @"com.apple.ftp-proxy.plist",
        @"com.apple.icloud.findmydeviced.FMM_recovery.plist",
        @"com.apple.locationd.plist",
        //@"com.apple.lsd.plist",
        @"com.apple.ocspd.plist",
        @"com.apple.scrod.plist",
        @"com.apple.speech.speechsynthesisd.plist",
        @"com.apple.tccd.system.plist",
        @"com.apple.VoiceOver.plist",
        @"com.apple.webcontentfilter.RecoveryOS.plist",
        @"org.ntp.sntp.plist",
        @"ssh.plist"
    ]
               modifyDictArray:modifyDictArray];

    [self deleteItemsFromBaseSystem:@[ @"Library/Managed Preferences/root" ] modifyDictArray:modifyDictArray beforeModifications:YES];

} // modifyLaunchDaemons

- (BOOL)modifyLocalization:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for localization...");

    NSFileManager *fm = [NSFileManager defaultManager];

    // ------------------------------------------------------------------
    //  /Library/Preferences/com.apple.HIToolbox.plist (Keyboard Layout)
    // ------------------------------------------------------------------
    NSURL *hiToolboxPreferencesURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.HIToolbox.plist"];
    DDLogDebug(@"[DEBUG] com.apple.HIToolbox.plist path: %@", [hiToolboxPreferencesURL path]);

    NSMutableDictionary *hiToolboxPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:hiToolboxPreferencesURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *hiToolboxPreferencesAttributes = [fm attributesOfItemAtPath:[hiToolboxPreferencesURL path] error:nil]
                                                       ?: @{ NSFileOwnerAccountName : @"root",
                                                             NSFileGroupOwnerAccountName : @"wheel",
                                                             NSFilePosixPermissions : @0644 };

    NSString *selectedKeyboardLayoutSourceID = [_workflowItem resourcesSettings][NBCSettingsKeyboardLayoutID];
    DDLogDebug(@"[DEBUG] Selected keyboard layout source id: %@", selectedKeyboardLayoutSourceID);

    NSString *selectedKeyboardName = [_workflowItem resourcesSettings][NBCSettingsKeyboardLayoutKey];
    DDLogDebug(@"[DEBUG] Selected keyboard name: %@", selectedKeyboardName);

    NSNumber *keyboardLayoutID = [self keyboardLayoutIDFromSourceID:selectedKeyboardLayoutSourceID];
    DDLogDebug(@"[DEBUG] Keyboard layout ID from source id: %@", [keyboardLayoutID stringValue]);

    NSDictionary *keyboardDict = @{ @"InputSourceKind" : @"Keyboard Layout", @"KeyboardLayout ID" : keyboardLayoutID, @"KeyboardLayout Name" : selectedKeyboardName };

    hiToolboxPreferencesDict[@"AppleCurrentKeyboardLayoutInputSourceID"] = selectedKeyboardLayoutSourceID;
    hiToolboxPreferencesDict[@"AppleDefaultAsciiInputSource"] = keyboardDict;
    hiToolboxPreferencesDict[@"AppleEnabledInputSources"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleInputSourceHistory"] = @[ keyboardDict ];
    hiToolboxPreferencesDict[@"AppleSelectedInputSources"] = @[ keyboardDict ];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : hiToolboxPreferencesDict,
        NBCWorkflowModifyAttributes : hiToolboxPreferencesAttributes,
        NBCWorkflowModifyTargetURL : [hiToolboxPreferencesURL path]
    }];

    // --------------------------------------------------------------
    //  /Library/Preferences/.GlobalPreferences.plist (Language)
    // --------------------------------------------------------------
    NSURL *globalPreferencesRootURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/.GlobalPreferences.plist"];
    DDLogDebug(@"[DEBUG] .GlobalPreferences.plist user path: %@", [globalPreferencesRootURL path]);

    NSURL *globalPreferencesURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/.GlobalPreferences.plist"];
    DDLogDebug(@"[DEBUG] .GlobalPreferences.plist shared path: %@", [globalPreferencesURL path]);

    NSMutableDictionary *globalPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:globalPreferencesURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *globalPreferencesAttributes = [fm attributesOfItemAtPath:[globalPreferencesURL path] error:nil]
                                                    ?: @{ NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644 };

    // Add 'Language
    NSString *selectedLanguage = [_workflowItem resourcesSettings][NBCSettingsLanguageKey];
    if ([selectedLanguage length] != 0) {
        globalPreferencesDict[@"AppleLanguages"] = @[ selectedLanguage ];
    } else {
        *error = [NBCError errorWithDescription:@"Localization language was empty!"];
        return NO;
    }

    // Add 'Country'
    if ([[_workflowItem resourcesSettings][NBCSettingsCountry] length] != 0) {
        globalPreferencesDict[@"Country"] = [_workflowItem resourcesSettings][NBCSettingsCountry];

    } else if ([globalPreferencesDict[@"AppleLocale"] containsString:@"_"]) {
        globalPreferencesDict[@"Country"] = [globalPreferencesDict[@"AppleLocale"] componentsSeparatedByString:@"_"][2];
    }

    // Add 'Locale'
    if ([[_workflowItem resourcesSettings][NBCSettingsLocale] length] != 0) {
        globalPreferencesDict[@"AppleLocale"] = [_workflowItem resourcesSettings][NBCSettingsLocale];
    } else {
        globalPreferencesDict[@"AppleLocale"] = selectedLanguage;
    }

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : globalPreferencesDict,
        NBCWorkflowModifyAttributes : globalPreferencesAttributes,
        NBCWorkflowModifyTargetURL : [globalPreferencesURL path]
    }];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : globalPreferencesDict,
        NBCWorkflowModifyAttributes : globalPreferencesAttributes,
        NBCWorkflowModifyTargetURL : [globalPreferencesRootURL path]
    }];

    // --------------------------------------------------------------
    //  /private/var/log/CDIS.custom (Setup Assistant Language)
    // --------------------------------------------------------------
    NSURL *csdisURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"private/var/log/CDIS.custom"];
    DDLogDebug(@"[DEBUG] CDIS.custom path: %@", [csdisURL path]);

    NSString *canonicalLanguage = [NSLocale canonicalLanguageIdentifierFromString:selectedLanguage];
    DDLogDebug(@"[DEBUG] Canonical language identifier for %@: %@", selectedLanguage, canonicalLanguage);

    if ([canonicalLanguage length] != 0) {

        // Convert string to data
        NSData *cdisContentData = [canonicalLanguage dataUsingEncoding:NSUTF8StringEncoding];

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
            NBCWorkflowModifyContent : cdisContentData,
            NBCWorkflowModifyTargetURL : [csdisURL path],
            NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
        }];
    } else {
        *error = [NBCError errorWithDescription:@"Unable to get canonical language identifier!"];
        return NO;
    }

    return YES;
} // modifySettingsForLanguageAndKeyboardLayout

- (BOOL)modifyNetBootServers:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for NetBoot Servers...");

    // --------------------------------------------------------------
    //  /usr/local/bsdpSources.txt
    // --------------------------------------------------------------
    NSArray *bsdpSourcesArray = [_workflowItem resourcesSettings][NBCSettingsTrustedNetBootServersKey];
    if ([bsdpSourcesArray count] != 0) {
        NSURL *usrLocalBsdpSourcesURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/bsdpSources.txt"];
        DDLogDebug(@"[DEBUG] bsdpSources.txt path: %@", [usrLocalBsdpSourcesURL path]);

        // Create file contents by looping array of user selected IPs
        NSMutableString *bsdpSourcesContent = [[NSMutableString alloc] init];
        for (NSString *ip in bsdpSourcesArray) {
            if ([ip isValidIPAddress]) {
                DDLogDebug(@"[DEBUG] Adding netboot server ip: %@", ip);
                [bsdpSourcesContent appendString:[NSString stringWithFormat:@"%@\n", ip]];
            } else {
                *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Invalid netboot server ip: %@ ", ip]];
                return NO;
            }
        }

        if ([bsdpSourcesContent length] != 0) {

            // Convert content string to data
            NSData *bsdpSourcesData = [bsdpSourcesContent dataUsingEncoding:NSUTF8StringEncoding];

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                NBCWorkflowModifyContent : bsdpSourcesData,
                NBCWorkflowModifyTargetURL : [usrLocalBsdpSourcesURL path],
                NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
            }];
            return YES;
        } else {
            *error = [NBCError errorWithDescription:@"Selected NetBoot Servers list was empty after loop!"];
            return NO;
        }
    } else {
        *error = [NBCError errorWithDescription:@"Selected NetBoot Servers list was empty!"];
        return NO;
    }
} // modifyNetBootServers

- (BOOL)modifyNTP:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for NTP...");

    // --------------------------------------------------------------
    //  /etc/ntp.conf
    // --------------------------------------------------------------
    NSString *ntpServerString = [_workflowItem userSettings][NBCSettingsNetworkTimeServerKey] ?: NBCNetworkTimeServerDefault;

    if ([ntpServerString length] != 0) {

        // --------------------------------------------------------------
        //  Split string into array
        // --------------------------------------------------------------
        NSArray *ntpHostArray = [ntpServerString componentsSeparatedByString:@","];
        NSMutableString *ntpHostContentString = [[NSMutableString alloc] init];

        for (NSString *ntpHostString in ntpHostArray) {

            // --------------------------------------------------------------
            //  Remove leading and trailing whitespace from host string
            // --------------------------------------------------------------
            NSString *ntpHost = [ntpHostString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

            DDLogDebug(@"[DEBUG] Verifying ntp host: %@", ntpHost);

            // --------------------------------------------------------------
            //  Easy check if host string can be initialized by NSURL
            // --------------------------------------------------------------
            NSURL *ntpHostURL = [NSURL URLWithString:ntpHost];
            if (!ntpHostURL) {
                DDLogWarn(@"[WARN] NTP host: %@ is invalid!", ntpHost);
            } else {

                // --------------------------------------------------------------
                //  If host string can be resolved, continue
                // --------------------------------------------------------------
                if ([ntpHost isValidHostname]) {
                    [ntpHostContentString appendString:[NSString stringWithFormat:@"server %@\n", ntpHost]];
                    continue;
                }

                // --------------------------------------------------------------
                //  If host string is a valid IP address, continue
                // --------------------------------------------------------------
                if ([ntpHost isValidIPAddress]) {
                    [ntpHostContentString appendString:[NSString stringWithFormat:@"server %@\n", ntpHost]];
                    continue;
                }

                // -----------------------------------------------------------------------
                //  If both of the above checks fail, add warning
                // -----------------------------------------------------------------------
                DDLogWarn(@"[WARN] NTP host: %@ could not be verified!", ntpHost);
            }
        }

        if ([ntpHostContentString length] == 0) {
            DDLogWarn(@"[WARN] No ntp server was verified!");
        }

        NSURL *ntpConfURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];

        // Convert string to data
        NSData *ntpConfContentData = [ntpHostContentString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *ntpConfAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[ntpConfURL path] error:nil]
                                              ?: @{ NSFileOwnerAccountName : @"root",
                                                    NSFileGroupOwnerAccountName : @"wheel",
                                                    NSFilePosixPermissions : @0644 };

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
            NBCWorkflowModifyContent : ntpConfContentData,
            NBCWorkflowModifyTargetURL : [ntpConfURL path],
            NBCWorkflowModifyAttributes : ntpConfAttributes
        }];
        return YES;
    } else {
        *error = [NBCError errorWithDescription:@"NTP server info was empty"];
        return NO;
    }
} // modifyNTP

- (BOOL)modifyRAMDiskFolders:(NSMutableArray *)modifyDictArray rcFile:(NSString *)rcFile error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for RAMDisk folders...");

    if ([rcFile length] != 0) {
        [rcFile enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
#pragma unused(stop)

          if ([line hasPrefix:@"RAMDisk"]) {

              // ---------------------------------------------------------------------------------------
              //  Only get the RAMDisk path from line by removing first (RAMDisk) and last (Size) words
              // ---------------------------------------------------------------------------------------
              NSMutableArray *lineArray = [NSMutableArray arrayWithArray:[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
              if (2 < [lineArray count]) {
                  [lineArray removeObjectAtIndex:0];
                  [lineArray removeLastObject];
                  line = [lineArray componentsJoinedByString:@" "];
                  line = [line stringByReplacingOccurrencesOfString:@"'" withString:@""];

                  if ([line hasPrefix:@"/"]) {
                      [self addFoldersToBaseSystem:@[ [line substringFromIndex:1] ] modifyDictArray:modifyDictArray];
                  }
              }
          }
        }];

        return YES;
    } else {
        *error = [NBCError errorWithDescription:@"rc file passed was empty!"];
        return NO;
    }
}

- (BOOL)modifyRCCdrom:(NSMutableArray *)modifyDictArray error:(NSError **)error {
#pragma unused(modifyDictArray)

    DDLogInfo(@"Preparing modifications for rc.cdrom...");

    // --------------------------------------------------------------
    //  /etc/rc.cdrom & /etc/rc.cdm.cdrom
    // --------------------------------------------------------------
    NSURL *rcCdromURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/rc.cdrom"];
    DDLogDebug(@"[DEBUG] rc.cdrom path: %@", [rcCdromURL path]);

    NSURL *rcCdmCdromURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/rc.cdm.cdrom"];
    DDLogDebug(@"[DEBUG] rc.cdm.cdrom path: %@", [rcCdmCdromURL path]);

    if ([rcCdromURL checkResourceIsReachableAndReturnError:error]) {
        NSString *rcCdromOriginal = [NSString stringWithContentsOfURL:rcCdromURL encoding:NSUTF8StringEncoding error:error];
        if ([rcCdromOriginal length] == 0) {
            return NO;
        }

        __block NSMutableString *rcCdmCdrom = [[NSMutableString alloc] init];
        __block NSMutableString *rcCdromNew = [[NSMutableString alloc] init];
        __block BOOL copyNextLine = NO;
        __block BOOL copyComplete = NO;
        __block BOOL inspectNextLine = NO;

        // --------------------------------------------------------------
        //  Loop through each line in rc.cdrom and make required changes
        // --------------------------------------------------------------
        [rcCdromOriginal enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
#pragma unused(stop)

          // ------------------------------------------------------------------------------
          //  Add quotes around mountpoint variable to enble using spaces in RAMDisk paths
          // ------------------------------------------------------------------------------
          if ([line containsString:@"/usr/bin/stat"]) {
              [rcCdromNew appendString:@"    eval `/usr/bin/stat -s \"$mntpt\"`\n"];
              return;
          } else if ([line containsString:@"mount -t hfs -o union -o nobrowse $dev $mntpt"]) {
              [rcCdromNew appendString:@"    mount -t hfs -o union -o nobrowse $dev \"$mntpt\"\n"];
              return;
          } else if ([line containsString:@"chown $st_uid:$st_gid $mntpt"]) {
              [rcCdromNew appendString:@"    chown $st_uid:$st_gid \"$mntpt\"\n"];
              return;
          } else if ([line containsString:@"chmod $st_mode $mntpt"]) {
              [rcCdromNew appendString:@"    chmod $st_mode \"$mntpt\"\n"];
              return;
          } else {
              [rcCdromNew appendString:[NSString stringWithFormat:@"%@\n", line]];
          }

          // ------------------------------------------------------------------------------------------
          //  Copy each line including RAMDisk to the file rc.cdm.cdrom that will be sourced if exists
          // ------------------------------------------------------------------------------------------
          if (copyNextLine && !copyComplete) {

              // ----------------------------------------------------------------------------------------
              //  When looking for RAMDisks, after encountering the first 'fi', stop looking for RAMDisk
              // ----------------------------------------------------------------------------------------
              if ([line hasPrefix:@"fi"]) {
                  copyComplete = YES;
                  return;
              }

              // ----------------------------------------------------------------------------------------
              //  Remove any leading whitespaces
              // ----------------------------------------------------------------------------------------
              NSRange range = [line rangeOfString:@"^\\s*" options:NSRegularExpressionSearch];
              line = [line stringByReplacingCharactersInRange:range withString:@""];

              // ------------------------------------------------------------------------------
              //  Modify sizes of default RAM Disks
              // ------------------------------------------------------------------------------
              if ([line hasPrefix:@"RAMDisk"]) {
                  NSMutableArray *lineArray = [NSMutableArray arrayWithArray:[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                  NSString *path = lineArray[1];

                  if ([path isEqualToString:@"/Volumes"]) {
                      lineArray[2] = @"1024";
                  } else if ([path isEqualToString:@"/var/tmp"]) {
                      if ([self->_workflowItem workflowType] == kWorkflowTypeCasper) {
                          lineArray[1] = @"/tmp";
                      }
                      lineArray[2] = @"32768";
                  } else if ([path isEqualToString:@"/var/run"]) {
                      lineArray[2] = @"1024";
                  } else if ([path isEqualToString:@"/var/db"]) {
                      lineArray[2] = @"4096";
                  } else if ([path isEqualToString:@"/var/root/Library"]) {
                      lineArray[2] = @"4096";
                  } else if ([path isEqualToString:@"/Library/ColorSync/Profiles/Displays"]) {
                      lineArray[2] = @"4096";
                  } else if ([path isEqualToString:@"/Library/Preferences"]) {
                      lineArray[2] = @"1024";
                  } else if ([path isEqualToString:@"/Library/Preferences/SystemConfiguration"]) {
                      lineArray[2] = @"1024";
                  }

                  line = [lineArray componentsJoinedByString:@" "];
              }
              [rcCdmCdrom appendString:[NSString stringWithFormat:@"%@\n", line]];
              return;
          }

          if (inspectNextLine) {

              // ----------------------------------------------------------------------------------------------------------------
              //  When looking for RAMDisks, after encountering the first 'else', start looking for lines beginning with RAMDisk
              // ----------------------------------------------------------------------------------------------------------------
              if ([line hasPrefix:@"else"]) {
                  copyNextLine = YES;
                  return;
              }
          }

          // ------------------------------------------------------------------------------
          //  Start looking for RAMDisks after this line
          // ------------------------------------------------------------------------------
          if ([line hasPrefix:@"if [ -f \"/etc/rc.cdm.cdrom\" ]; then"]) {
              inspectNextLine = YES;
          }
        }];

        // ------------------------------------------------------------------------------
        //  Add NBICreator static RAMDisks
        // ------------------------------------------------------------------------------
        if ([rcCdmCdrom length] != 0) {
            [rcCdmCdrom appendString:@"RAMDisk /tmp 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /System/Library/Caches 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /System/Library/Caches/com.apple.CVMS 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/lsd 2048\n"];
            //[rcCdmCdrom appendString:@"RAMDisk /var/db/crls 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/launchd.db/com.apple.launchd 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/db/dslocal/nodes/Default/users 2048\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Caches 32768\n"];
            //[rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Caches/ocspd 32768\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs 16384\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Logs/DiagnosticReports 4096\n"];
            [rcCdmCdrom appendString:@"RAMDisk /Library/Caches 65536\n"];

            if ([_userSettings[NBCSettingsCertificatesKey] count] != 0) {
                [rcCdmCdrom appendString:@"RAMDisk '/Library/Security/Trust Settings' 2048\n"];
            }

            // ------------------------------------------------------------------------------
            //  Add workflow static RAMDisks
            // ------------------------------------------------------------------------------
            switch ([_workflowItem workflowType]) {
            case kWorkflowTypeNetInstall: {
                break;
            }
            case kWorkflowTypeDeployStudio: {
                break;
            }
            case kWorkflowTypeImagr: {
                break;
            }
            case kWorkflowTypeCasper: {
                [rcCdmCdrom appendString:@"RAMDisk /System/Library/Caches/com.apple.kext.caches/Startup 49152\n"];
                [rcCdmCdrom appendString:@"RAMDisk /.vol 1024\n"];
                [rcCdmCdrom appendString:@"RAMDisk /var/netboot 2048\n"];
                [rcCdmCdrom appendString:@"RAMDisk /var/root/Library/Preferences 2048\n"];
                [rcCdmCdrom appendString:@"RAMDisk '/Library/Application Support' 16384\n"];

                // Copy com.jamfsoftware.jss.plist after creating the RAMDisks instead of writing it in place, so it will become writeabe.
                [rcCdmCdrom appendString:@"/bin/cp /usr/local/preferences/com.jamfsoftware.jss.plist /var/root/Library/Preferences/com.jamfsoftware.jss.plist\n"];
                [rcCdmCdrom appendString:@"/bin/chmod 777 /tmp\n"];
                [rcCdmCdrom appendString:@"RAMDisk /var/log 8192\n"];
                [rcCdmCdrom appendString:@"RAMDisk /etc 1024\n"];
                break;
            }
            default:
                break;
            }

            // ------------------------------------------------------------------------------
            //  Add user configured RAMDisks
            // ------------------------------------------------------------------------------
            if ([_userSettings[NBCSettingsAddCustomRAMDisksKey] boolValue] && [[_workflowItem resourcesSettings][NBCSettingsRAMDisksKey] count] != 0) {
                [rcCdmCdrom appendString:@"\n### CUSTOM RAM DISKS ###\n"];
                for (NSDictionary *ramDiskDict in [_workflowItem resourcesSettings][NBCSettingsRAMDisksKey]) {
                    NSString *ramDiskSizeMB = ramDiskDict[@"size"];
                    if ([ramDiskSizeMB length] != 0) {

                        // Uses 1024 instead of 1000
                        NSString *ramDiskSizekB = [@(([ramDiskSizeMB intValue] * 1024)) stringValue];
                        [rcCdmCdrom appendString:[NSString stringWithFormat:@"RAMDisk %@ %@\n", ramDiskDict[@"path"], ramDiskSizekB]];
                    }
                }
            }
        } else {
            *error = [NBCError errorWithDescription:@"rc.cdm.cdrom empty after loop!"];
            return NO;
        }

        // Convert string content to data
        NSData *rcCdmCdromData = [rcCdmCdrom dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *rcCdmCdromDict = @{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
            NBCWorkflowModifyContent : rcCdmCdromData,
            NBCWorkflowModifyTargetURL : [rcCdmCdromURL path],
            NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0555}
        };

        // Update modification array
        [modifyDictArray addObject:rcCdmCdromDict];

        // Convert string content to data
        NSData *rcCdromNewData = [rcCdromNew dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *rcCdromNewDict = @{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
            NBCWorkflowModifyContent : rcCdromNewData,
            NBCWorkflowModifyTargetURL : [rcCdromURL path],
            NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0555}
        };

        // Update modification array
        [modifyDictArray addObject:rcCdromNewDict];

        return [self modifyRAMDiskFolders:modifyDictArray rcFile:[rcCdmCdrom copy] error:error];
    } else {
        return NO;
    }
} // modifyRCCdrom

- (BOOL)modifyRCImaging:(NSMutableArray *)modifyDictArray nbiToolPath:(NSString *)nbiToolPath error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for rc.imaging...");

    NSMutableString *rcImaging = [[NSMutableString alloc] initWithString:@"#!/bin/bash\n"];

    // ------------------------------------------------------------------
    //  DesktopViewer
    // ------------------------------------------------------------------
    if ([_userSettings[NBCSettingsUseBackgroundImageKey] boolValue]) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Start NBICreatorDesktopViewer\n"
                                                            "###\n"
                                                            "/Applications/NBICreatorDesktopViewer.app/Contents/MacOS/NBICreatorDesktopViewer &\n"]];
    }

    // ------------------------------------------------------------------
    //  Trusted NetBoot Servers
    // ------------------------------------------------------------------
    if (11 <= _sourceVersionMinor) {
        if ([_userSettings[NBCSettingsAddTrustedNetBootServersKey] boolValue]) {
            [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                                "###\n"
                                                                "### Add Trusted NetBoot Servers\n"
                                                                "###\n"
                                                                "if [[ -f /usr/bin/csrutil ]] && [[ -f /usr/local/bsdpSources.txt ]]; then\n"
                                                                "\twhile read netBootServer\n"
                                                                "\tdo\n"
                                                                "\t\t/usr/bin/csrutil netboot add \"${netBootServer}\"\n"
                                                                "\tdone < \"/usr/local/bsdpSources.txt\"\n"
                                                                "fi\n"]];
        }
    }

    // ------------------------------------------------------------------
    //  ntp
    // ------------------------------------------------------------------
    if ([_userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue]) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
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
                                                            "fi\n"]];
    }

    // ------------------------------------------------------------------
    //  spctl
    // ------------------------------------------------------------------
    /* Why is this uncommented, is this not needed? DS does this.
     [rcImaging appendString:[NSString stringWithFormat:@"\n"
     "###\n"
     "### Disable Gatekeeper\n"
     "###\n"
     "if [ -e /usr/sbin/spctl ]; then\n"
     "\t/usr/sbin/spctl --master-disable\n"
     "fi\n"]];
     */

    // ------------------------------------------------------------------
    //  Screen Sharing
    // ------------------------------------------------------------------
    if (_userSettings[NBCSettingsARDPasswordKey]) {
        if (_sourceVersionMinor <= 7) {
            [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                                "### \n"
                                                                "### Start Screensharing\n"
                                                                "###\n"
                                                                "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                                                "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.agent.plist\n"
                                                                "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist\n"
                                                                "fi\n"]];
        } else if (8 <= _sourceVersionMinor) {
            [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                                "### \n"
                                                                "### Start Screensharing\n"
                                                                "###\n"
                                                                "if [ -e /Library/Preferences/com.apple.VNCSettings.txt ]; then\n"
                                                                "\t/bin/launchctl load /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist\n"
                                                                "fi\n"]];
        }
    }

    // ------------------------------------------------------------------
    //  Display Sleep
    // ------------------------------------------------------------------
    NSString *displaySleepMinutes;
    if ([_userSettings[NBCSettingsDisplaySleepKey] boolValue]) {
        displaySleepMinutes = [_userSettings[NBCSettingsDisplaySleepMinutesKey] stringValue];
    } else {
        displaySleepMinutes = @"0";
    }

    if (_sourceVersionMinor <= 8) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Set power management policy\n"
                                                            "###\n"
                                                            "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 powerbutton 0 disksleep 0 ) &\n",
                                                           displaySleepMinutes]];
    } else {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Set power management policy\n"
                                                            "###\n"
                                                            "(sleep 30; /usr/bin/pmset force -a sleep 0 displaysleep %@ lessbright 0 disksleep 0 ) &\n",
                                                           displaySleepMinutes]];
    }

    // ------------------------------------------------------------------
    //  Hostname
    // ------------------------------------------------------------------
    [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                        "###\n"
                                                        "### Set Temporary Hostname\n"
                                                        "###\n"
                                                        "computer_name=Mac-$( /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk -F'\"' '/IOPlatformSerialNumber/ { print $4 }' )\n"
                                                        "if [[ -n ${computer_name} ]]; then\n"
                                                        "\tcomputer_hostname=$( /usr/bin/tr '[:upper:]' '[:lower:]' <<< \"${computer_name}\" )\n"
                                                        "\t/usr/sbin/scutil --set ComputerName  \"${computer_name}\"\n"
                                                        "\t/usr/sbin/scutil --set LocalHostName \"${computer_hostname}\"\n"
                                                        "fi\n"]];

    /* +IMPROVEMENT Will probably make hostname a setting between serialnumber or netboot-server machine-name
     [rcImaging appendString:[NSString stringWithFormat:@"\n"
     "###\n"
     "### Set Temporary Hostname\n"
     "###\n"
     "computer_name=$( ipconfig netbootoption machine_name 2>&1 )\n"
     "if [[ ${?} -eq 0 ]] && [[ -n ${computer_name} ]]; then\n"
     "\tcomputer_hostname=$( /usr/bin/tr '[:upper:]' '[:lower:]' <<< \"${computer_name}\" )\n"
     "\t/usr/sbin/scutil --set ComputerName  \"${computer_name}\"\n"
     "\t/usr/sbin/scutil --set LocalHostName \"${computer_hostname}\"\n"
     "fi\n"]];
     */

    // ------------------------------------------------------------------
    //  DiskUtility Debug Menu (10.7-10.10)
    // ------------------------------------------------------------------
    if (_sourceVersionMinor <= 10) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Enable DiskUtility Debug menu\n"
                                                            "###\n"
                                                            "/usr/bin/defaults write com.apple.DiskUtility DUShowEveryPartition -bool YES\n"]];
    }

    // ------------------------------------------------------------------
    //  Certificates
    // ------------------------------------------------------------------
    if ([_userSettings[NBCSettingsCertificatesKey] count] != 0) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Add Certificates\n"
                                                            "###\n"
                                                            "if [ -e /usr/local/certificates ]; then\n"
                                                            "\t/usr/local/scripts/installCertificates.bash\n"
                                                            "fi\n"]];
    }
    
    // ------------------------------------------------------------------
    //  Console
    // ------------------------------------------------------------------
    if ([_userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] && [_userSettings[NBCSettingsLaunchConsoleAppKey] boolValue]) {
        
        // ---------------------------------------------------------------------
        //  Show private data (10.12+)
        // ---------------------------------------------------------------------
        if (12 <= _sourceVersionMinor) {
            [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                     "###\n"
                                     "### Show Privata Data in Log\n"
                                     "###\n"
                                     "log config --mode \"private_data:on\"\n"]];
        }        
        
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Start Console\n"
                                                            "###\n"
                                                            "/Applications/Utilities/Console.app/Contents/MacOS/Console /var/log/system.log &\n"]];
    }

    // ------------------------------------------------------------------
    //  NBI Tool
    // ------------------------------------------------------------------
    NSString *nbiToolExecutablePath;
    if ([[nbiToolPath pathExtension] isEqualToString:@"app"]) {
        nbiToolExecutablePath = [nbiToolPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Contents/MacOS/%@", [[nbiToolPath lastPathComponent] stringByDeletingPathExtension]]];
    } else {
        nbiToolExecutablePath = nbiToolPath;
    }
    DDLogDebug(@"[DEBUG] NBI Tool executable path: %@", nbiToolExecutablePath);

    [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                        "###\n"
                                                        "### Start %@\n"
                                                        "###\n"
                                                        "%@\n",
                                                       [nbiToolPath lastPathComponent], nbiToolExecutablePath]];

    // ------------------------------------------------------------------
    //  SystemUIServer
    // ------------------------------------------------------------------
    if ([_userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue]) {
        [rcImaging appendString:[NSString stringWithFormat:@"\n"
                                                            "###\n"
                                                            "### Stop SystemUIServer\n"
                                                            "###\n"
                                                            "/bin/launchctl unload /System/Library/LaunchDaemons/com.apple.SystemUIServer.plist\n"]];
    }

    // ------------------------------------------------------------------
    //  Determine rc.imaging path
    // ------------------------------------------------------------------
    if ([rcImaging length] != 0) {
        NSURL *rcImagingURL;
        if ([_creationTool isEqualToString:NBCMenuItemNBICreator] || [_creationTool isEqualToString:NBCMenuItemDeployStudioAssistant]) {
            rcImagingURL = [_baseSystemVolumeURL URLByAppendingPathComponent:NBCRCImagingNBICreatorTargetURL];
        } else if ([_creationTool isEqualToString:NBCMenuItemSystemImageUtility]) {
            rcImagingURL = [_netInstallVolumeURL URLByAppendingPathComponent:NBCRCImagingTargetURL];
        } else {
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Unknown creation tool: %@", _creationTool]];
            return NO;
        }
        DDLogDebug(@"[DEBUG] rc.imaging path: %@", [rcImagingURL path]);

        // Convert string to data
        NSData *rcImagingData = [rcImaging dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *rcImagingAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[rcImagingURL path] error:nil]
                                                ?: @{ NSFileOwnerAccountName : @"root",
                                                      NSFileGroupOwnerAccountName : @"wheel",
                                                      NSFilePosixPermissions : @0755 };

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
            NBCWorkflowModifyContent : rcImagingData,
            NBCWorkflowModifyAttributes : rcImagingAttributes,
            NBCWorkflowModifyTargetURL : [rcImagingURL path]
        }];

        return YES;
    } else {
        *error = [NBCError errorWithDescription:@"Generated rc.imaging content was empty"];
        return NO;
    }
}

- (BOOL)modifyRCInstall:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for rc.install...");

    // ------------------------------------------------------------------
    //  /etc/rc.install
    // ------------------------------------------------------------------
    NSURL *rcInstallURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/rc.install"];
    DDLogDebug(@"[DEBUG] rc.install path: %@", [rcInstallURL path]);

    NSString *rcInstallContentStringOriginal = [NSMutableString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:error];
    if ([rcInstallContentStringOriginal length] != 0) {

        // Loop through rc.install and comment out line with Installer Progress.app (10.11)
        NSMutableString *rcInstallContentString = [[NSMutableString alloc] init];
        NSArray *rcInstallContentArray = [rcInstallContentStringOriginal componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in rcInstallContentArray) {
            if ([line containsString:@"/System/Library/CoreServices/Installer\\ Progress.app"] || [line containsString:@"/System/Installation/CDIS/launchprogresswindow"]) {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"#%@\n", line]];
            } else if (12 <= _sourceVersionMinor && [line containsString:@"/usr/bin/security unlock-keychain"]) {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"%@\n", line]];
                [rcInstallContentString appendString:[NSString stringWithFormat:@"\n#\n"
                                                                                @"# Source the system imaging extras files if present\n"
                                                                                @"#\n"
                                                                                @"if [ -x /etc/rc.imaging ]; then\n"
                                                                                @"/etc/rc.imaging\n"
                                                                                @"fi\n\n"
                                                                                @"if [ -x /System/Installation/Packages/Extras/rc.imaging ]; then\n"
                                                                                @"/System/Installation/Packages/Extras/rc.imaging\n"
                                                                                @"fi\n"]];
            } else {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"%@\n", line]];
            }
        }

        if ([rcInstallContentString length] != 0) {

            // Convert string to data
            NSData *rcInstallData = [rcInstallContentString dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *rcInstallAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[rcInstallURL path] error:nil]
                                                    ?: @{ NSFileOwnerAccountName : @"root",
                                                          NSFileGroupOwnerAccountName : @"wheel",
                                                          NSFilePosixPermissions : @0644 };

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                NBCWorkflowModifyContent : rcInstallData,
                NBCWorkflowModifyAttributes : rcInstallAttributes,
                NBCWorkflowModifyTargetURL : [rcInstallURL path]
            }];

            return YES;
        } else {
            *error = [NBCError errorWithDescription:@"Modification of rc.install failed!"];
            return NO;
        }
    } else {
        return NO;
    }
}

- (BOOL)modifyScreenSharing:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for Screen Sharing...");

    NSFileManager *fm = [NSFileManager defaultManager];

    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteManagement.plist
    // --------------------------------------------------------------
    NSURL *remoteManagementURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteManagement.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteManagement.plist path: %@", [remoteManagementURL path]);

    NSMutableDictionary *remoteManagementDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteManagementURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *remoteManagementAttributes = [fm attributesOfItemAtPath:[remoteManagementURL path] error:nil]
                                                   ?: @{ NSFileOwnerAccountName : @"root",
                                                         NSFileGroupOwnerAccountName : @"wheel",
                                                         NSFilePosixPermissions : @0644 };

    remoteManagementDict[@"ARD_AllLocalUsers"] = @YES;
    remoteManagementDict[@"ARD_AllLocalUsersPrivs"] = @-1073741569;
    remoteManagementDict[@"LoadRemoteManagementMenuExtra"] = @NO;
    remoteManagementDict[@"DisableKerberos"] = @NO;
    remoteManagementDict[@"ScreenSharingReqPermEnabled"] = @NO;
    remoteManagementDict[@"VNCLegacyConnectionsEnabled"] = @YES;

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : remoteManagementDict,
        NBCWorkflowModifyAttributes : remoteManagementAttributes,
        NBCWorkflowModifyTargetURL : [remoteManagementURL path]
    }];

    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.screensharing.plist
    // --------------------------------------------------------------
    NSURL *screensharingLaunchDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.screensharing.plist"];
    DDLogDebug(@"[DEBUG] com.apple.screensharing.plist path: %@", [screensharingLaunchDaemonURL path]);

    if ([screensharingLaunchDaemonURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *screensharingLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingLaunchDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *screensharingLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingLaunchDaemonURL path] error:nil]
                                                                ?: @{ NSFileOwnerAccountName : @"root",
                                                                      NSFileGroupOwnerAccountName : @"wheel",
                                                                      NSFilePosixPermissions : @0644 };

        // Run launchdaemon as root
        screensharingLaunchDaemonDict[@"UserName"] = @"root";
        screensharingLaunchDaemonDict[@"GroupName"] = @"wheel";

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : screensharingLaunchDaemonDict,
            NBCWorkflowModifyTargetURL : [screensharingLaunchDaemonURL path],
            NBCWorkflowModifyAttributes : screensharingLaunchDaemonAttributes
        }];
    } else {
        return NO;
    }

    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopPrivilegeProxyDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteDesktop.PrivilegeProxy.plist path: %@", [remoteDesktopPrivilegeProxyDaemonURL path]);

    if ([remoteDesktopPrivilegeProxyDaemonURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *remoteDesktopPrivilegeProxyLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopPrivilegeProxyDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *remoteDesktopPrivilegeProxyLaunchDaemonAttributes = [fm attributesOfItemAtPath:[remoteDesktopPrivilegeProxyDaemonURL path] error:nil]
                                                                              ?: @{ NSFileOwnerAccountName : @"root",
                                                                                    NSFileGroupOwnerAccountName : @"wheel",
                                                                                    NSFilePosixPermissions : @0644 };

        // Run launchdaemon as root
        remoteDesktopPrivilegeProxyLaunchDaemonDict[@"UserName"] = @"root";
        remoteDesktopPrivilegeProxyLaunchDaemonDict[@"GroupName"] = @"wheel";

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : remoteDesktopPrivilegeProxyLaunchDaemonDict,
            NBCWorkflowModifyTargetURL : [remoteDesktopPrivilegeProxyDaemonURL path],
            NBCWorkflowModifyAttributes : remoteDesktopPrivilegeProxyLaunchDaemonAttributes
        }];
    } else {
        return NO;
    }

    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.agent.plist
    // --------------------------------------------------------------
    NSURL *screensharingAgentDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.agent.plist"];
    DDLogDebug(@"[DEBUG] com.apple.screensharing.agent.plist path: %@", [screensharingAgentDaemonURL path]);

    if ([screensharingAgentDaemonURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *screensharingAgentLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingAgentDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *screensharingAgentLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:nil]
                                                                     ?: @{ NSFileOwnerAccountName : @"root",
                                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                                           NSFilePosixPermissions : @0644 };

        // Remove LimitLoadToSessionType to run in NetInstall
        [screensharingAgentLaunchDaemonDict removeObjectForKey:@"LimitLoadToSessionType"];

        //+ TESTING: TO EXCLUDE
        // screensharingAgentLaunchDaemonDict[@"RunAtLoad"] = @YES;

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : screensharingAgentLaunchDaemonDict,
            NBCWorkflowModifyTargetURL : [screensharingAgentDaemonURL path],
            NBCWorkflowModifyAttributes : screensharingAgentLaunchDaemonAttributes
        }];
    }

    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist
    // --------------------------------------------------------------
    if (7 < _sourceVersionMinor) {
        NSURL *screensharingMessagesAgentDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist"];
        DDLogDebug(@"[DEBUG] com.apple.screensharing.MessagesAgent.plist path: %@", [screensharingMessagesAgentDaemonURL path]);

        if ([screensharingMessagesAgentDaemonURL checkResourceIsReachableAndReturnError:error]) {
            NSMutableDictionary *screensharingMessagesAgentLaunchAgentDict =
                [NSMutableDictionary dictionaryWithContentsOfURL:screensharingMessagesAgentDaemonURL] ?: [[NSMutableDictionary alloc] init];
            NSDictionary *screensharingMessagesAgentLaunchAgentAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:nil]
                                                                                ?: @{ NSFileOwnerAccountName : @"root",
                                                                                      NSFileGroupOwnerAccountName : @"wheel",
                                                                                      NSFilePosixPermissions : @0644 };
            // Set launch daemon to run at load
            screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                NBCWorkflowModifyContent : screensharingMessagesAgentLaunchAgentDict,
                NBCWorkflowModifyTargetURL : [screensharingMessagesAgentDaemonURL path],
                NBCWorkflowModifyAttributes : screensharingMessagesAgentLaunchAgentAttributes
            }];
        } else if (7 < _sourceVersionMinor) {
            /* FIXME - Why is this uncommented, isn't it needed? And why is the if statement checking the same thing twice?
             screensharingMessagesAgentLaunchAgentDict = [[NSMutableDictionary alloc] init];
             screensharingMessagesAgentLaunchAgentDict[@"EnableTransactions"] = @YES;
             screensharingMessagesAgentLaunchAgentDict[@"Label"] = @"com.apple.screensharing.MessagesAgent";
             screensharingMessagesAgentLaunchAgentDict[@"ProgramArguments"] = @[ @"/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/MacOS/AppleVNCServer" ];
             screensharingMessagesAgentLaunchAgentDict[@"MachServices"] = @{ @"com.apple.screensharing.MessagesAgent" : @YES };
             screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;
             */
        } else {
            return NO;
        }
    } else {
        DDLogDebug(@"MessagesAgent isn't available in 10.7 or lower.");
    }

    // --------------------------------------------------------------
    //  /etc/com.apple.screensharing.agent.launchd
    // --------------------------------------------------------------
    NSURL *etcScreensharingAgentLaunchdURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/com.apple.screensharing.agent.launchd"];
    DDLogDebug(@"[DEBUG] com.apple.screensharing.agent.launchd path: %@", [etcScreensharingAgentLaunchdURL path]);

    // Set content of file to the string 'enabled'
    NSString *etcScreensharingAgentLaunchdContentString = @"enabled\n";
    NSData *etcScreensharingAgentLaunchdContentData = [etcScreensharingAgentLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
        NBCWorkflowModifyContent : etcScreensharingAgentLaunchdContentData,
        NBCWorkflowModifyTargetURL : [etcScreensharingAgentLaunchdURL path],
        NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
    }];

    // --------------------------------------------------------------
    //  /Library/Application Support/Apple/Remote Desktop
    // --------------------------------------------------------------
    [self addFoldersToBaseSystem:@[ @"Library/Application Support/Apple/Remote Desktop" ] modifyDictArray:modifyDictArray];

    // --------------------------------------------------------------
    //  /etc/RemoteManagement.launchd
    // --------------------------------------------------------------
    NSURL *etcRemoteManagementLaunchdURL;
    if (11 <= _sourceVersionMinor) {
        etcRemoteManagementLaunchdURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Application Support/Apple/Remote Desktop/RemoteManagement.launchd"];
    } else {
        etcRemoteManagementLaunchdURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/RemoteManagement.launchd"];
    }
    DDLogDebug(@"[DEBUG] RemoteManagement.launchd path: %@", [etcRemoteManagementLaunchdURL path]);

    // Set content of file to the string 'enabled'
    NSString *etcRemoteManagementLaunchdContentString = @"enabled\n";
    NSData *etcRemoteManagementLaunchdContentData = [etcRemoteManagementLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
        NBCWorkflowModifyContent : etcRemoteManagementLaunchdContentData,
        NBCWorkflowModifyTargetURL : [etcRemoteManagementLaunchdURL path],
        NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
    }];

    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopLaunchAgentURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.RemoteDesktop.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteDesktop.plist path: %@", [remoteDesktopLaunchAgentURL path]);

    if ([remoteDesktopLaunchAgentURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *remoteDesktopLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopLaunchAgentURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *remoteDesktopLaunchAgentAttributes = [fm attributesOfItemAtPath:[remoteDesktopLaunchAgentURL path] error:nil]
                                                               ?: @{ NSFileOwnerAccountName : @"root",
                                                                     NSFileGroupOwnerAccountName : @"wheel",
                                                                     NSFilePosixPermissions : @0644 };

        // Remove LimitLoadToSessionType to run in NetInstall
        [remoteDesktopLaunchAgentDict removeObjectForKey:@"LimitLoadToSessionType"];

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : remoteDesktopLaunchAgentDict,
            NBCWorkflowModifyTargetURL : [remoteDesktopLaunchAgentURL path],
            NBCWorkflowModifyAttributes : remoteDesktopLaunchAgentAttributes
        }];
    }

    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteDesktop.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteDesktop.plist path: %@", remoteDesktopURL);

    NSMutableDictionary *remoteDesktopDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *remoteDesktopAttributes = [fm attributesOfItemAtPath:[remoteDesktopURL path] error:nil]
                                                ?: @{ NSFileOwnerAccountName : @"root",
                                                      NSFileGroupOwnerAccountName : @"wheel",
                                                      NSFilePosixPermissions : @0644 };

    // Configure remote desktop to allow full access to all users
    remoteDesktopDict[@"DOCAllowRemoteConnections"] = @YES;
    remoteDesktopDict[@"RestrictedFeatureList"] = @[
        @NO,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @YES,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
        @NO,
    ];
    remoteDesktopDict[@"Text1"] = @"";
    remoteDesktopDict[@"Text2"] = @"";
    remoteDesktopDict[@"Text3"] = @"";
    remoteDesktopDict[@"Text4"] = @"";

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : remoteDesktopDict,
        NBCWorkflowModifyTargetURL : [remoteDesktopURL path],
        NBCWorkflowModifyAttributes : remoteDesktopAttributes
    }];

    return [self modifyVNCPasswordHash:modifyDictArray error:error];
} // modifySettingsForVNC:workflowItem

- (void)modifySpotlight:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Spotlight...");

    // --------------------------------------------------------------
    //  /.Spotlight-V100/_IndexPolicy.plist
    // --------------------------------------------------------------
    NSURL *spotlightIndexingSettingsURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@".Spotlight-V100/_IndexPolicy.plist"];
    NSMutableDictionary *spotlightIndexingSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:spotlightIndexingSettingsURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *spotlightIndexingSettingsAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[spotlightIndexingSettingsURL path] error:nil]
                                                            ?: @{ NSFileOwnerAccountName : @"root",
                                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                                  NSFilePosixPermissions : @0600 };

    // Set policy to '3' (Disabled)
    spotlightIndexingSettingsDict[@"Policy"] = @3;

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : spotlightIndexingSettingsDict,
        NBCWorkflowModifyAttributes : spotlightIndexingSettingsAttributes,
        NBCWorkflowModifyTargetURL : [spotlightIndexingSettingsURL path]
    }];
} // modifySpotlight

- (BOOL)modifySystemUIServer:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogInfo(@"Preparing modifications for SystemUIServer...");

    NSFileManager *fm = [NSFileManager defaultManager];

    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.systemuiserver.plist
    // --------------------------------------------------------------
    NSURL *systemUIServerPreferencesURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.systemuiserver.plist"];
    DDLogDebug(@"[DEBUG] com.apple.systemuiserver.plist path: %@", [systemUIServerPreferencesURL path]);

    NSMutableDictionary *systemUIServerPreferencesDict = [NSMutableDictionary dictionaryWithContentsOfURL:systemUIServerPreferencesURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *systemUIServerPreferencesAttributes = [fm attributesOfItemAtPath:[systemUIServerPreferencesURL path] error:nil]
                                                            ?: @{ NSFileOwnerAccountName : @"root",
                                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                                  NSFilePosixPermissions : @0644 };

    // Setup items to be shown in status bar
    systemUIServerPreferencesDict[@"menuExtras"] =
        @[ @"/System/Library/CoreServices/Menu Extras/TextInput.menu", @"/System/Library/CoreServices/Menu Extras/Battery.menu", @"/System/Library/CoreServices/Menu Extras/Clock.menu" ];

    // Update modification array
    [modifyDictArray addObject:@{
        NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
        NBCWorkflowModifyContent : systemUIServerPreferencesDict,
        NBCWorkflowModifyAttributes : systemUIServerPreferencesAttributes,
        NBCWorkflowModifyTargetURL : [systemUIServerPreferencesURL path]
    }];

    // --------------------------------------------------------------
    //  /Library/LaunchAgents/com.apple.SystemUIServer.plist
    // --------------------------------------------------------------
    NSURL *systemUIServerLaunchAgentURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.SystemUIServer.plist"];
    DDLogDebug(@"[DEBUG] com.apple.SystemUIServer.plist path: %@", [systemUIServerLaunchAgentURL path]);

    if ([systemUIServerLaunchAgentURL checkResourceIsReachableAndReturnError:error]) {
        NSMutableDictionary *systemUIServerDict = [NSMutableDictionary dictionaryWithContentsOfURL:systemUIServerLaunchAgentURL];
        NSDictionary *systemUIServerAttributes = [fm attributesOfItemAtPath:[systemUIServerLaunchAgentURL path] error:nil]
                                                     ?: @{ NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644 };

        NSMutableDictionary *machServices = systemUIServerDict[@"MachServices"];
        [machServices removeObjectForKey:@"com.apple.ipodserver"];
        [machServices removeObjectForKey:@"com.apple.systemuiserver.screencapture"];
        [machServices removeObjectForKey:@"com.apple.dockextra.server"];
        [machServices removeObjectForKey:@"com.apple.dockling.server"];

        // Change settings to run as daemon
        systemUIServerDict[@"RunAtLoad"] = @YES;
        systemUIServerDict[@"Disabled"] = @NO;
        systemUIServerDict[@"POSIXSpawnType"] = @"Interactive";
        [systemUIServerDict removeObjectForKey:@"KeepAlive"];

        NSURL *systemUIServerLaunchDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.SystemUIServer.plist"];
        DDLogDebug(@"[DEBUG] com.apple.SystemUIServer.plist path: %@", [systemUIServerLaunchDaemonURL path]);

        // Update modification array
        [modifyDictArray addObject:@{
            NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
            NBCWorkflowModifyContent : systemUIServerDict,
            NBCWorkflowModifyAttributes : systemUIServerAttributes,
            NBCWorkflowModifyTargetURL : [systemUIServerLaunchDaemonURL path]
        }];

        // Update modification array
        [self deleteItemsFromBaseSystem:@[ [systemUIServerLaunchAgentURL path] ] modifyDictArray:modifyDictArray beforeModifications:NO];
    } else {
        return NO;
    }

    // --------------------------------------------------------------
    //  /etc/localtime -> /usr/share/zoneinfo/...
    // --------------------------------------------------------------
    NSURL *localtimeURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/localtime"];
    DDLogDebug(@"[DEBUG] localtime path: %@", [localtimeURL path]);

    NSString *selectedTimeZone = [_workflowItem resourcesSettings][NBCSettingsTimeZoneKey];

    if ([selectedTimeZone length] != 0) {
        NSURL *localtimeTargetURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/usr/share/zoneinfo/%@", selectedTimeZone]];
        DDLogDebug(@"[DEBUG] localtime symlink target path: %@", [localtimeTargetURL path]);

        // Update modification array
        [modifyDictArray
            addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeLink, NBCWorkflowModifySourceURL : [localtimeURL path], NBCWorkflowModifyTargetURL : [localtimeTargetURL path]}];
    } else {
        *error = [NBCError errorWithDescription:@"Selected TimeZone was empty!"];
        return NO;
    }

    return YES;
} // modifySettingsForMenuBar

- (void)modifyUtilitiesMenu:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for Console...");

    // ---------------------------------------------------------------------------------
    //  /System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist
    // ---------------------------------------------------------------------------------
    NSURL *utilitiesPlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist"];
    if ([utilitiesPlistURL checkResourceIsReachableAndReturnError:nil]) {
        NSMutableDictionary *utilitiesPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:utilitiesPlistURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *utilitiesPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[utilitiesPlistURL path] error:nil]
                                                     ?: @{ NSFileOwnerAccountName : @"root",
                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                           NSFilePosixPermissions : @0644 };

        // Add console to Installer utilities menu
        NSMutableArray *buttonsArray = [[NSMutableArray alloc] initWithArray:utilitiesPlistDict[@"Buttons"]] ?: [[NSMutableArray alloc] init];
        ;

        NSUInteger installerIndex = [buttonsArray indexOfObjectPassingTest:^BOOL(NSDictionary *item, NSUInteger __unused idx, BOOL *_Nonnull __unused stop) {
          return ([item[@"IsInstallAssistant"] boolValue]);
        }];

        if (installerIndex != NSNotFound) {
            [buttonsArray removeObjectAtIndex:installerIndex];

            utilitiesPlistDict[@"Buttons"] = buttonsArray;

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypePlist,
                NBCWorkflowModifyContent : utilitiesPlistDict,
                NBCWorkflowModifyAttributes : utilitiesPlistAttributes,
                NBCWorkflowModifyTargetURL : [utilitiesPlistURL path]
            }];
        }
    }
} // modifyUtilitiesMenu

- (BOOL)modifyVNCPasswordHash:(NSMutableArray *)modifyDictArray error:(NSError **)error {

    DDLogDebug(@"[DEBUG] Generating password hash for com.apple.VNCSettings.txt...");

    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.VNCSettings.txt
    // --------------------------------------------------------------
    NSURL *vncSettingsURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    DDLogDebug(@"[DEBUG] com.apple.VNCSettings.txt path: %@", [vncSettingsURL path]);

    NSString *vncPasswordString = [_workflowItem userSettings][NBCSettingsARDPasswordKey];
    if ([vncPasswordString length] != 0) {

        NSTask *perlTask = [[NSTask alloc] init];
        [perlTask setLaunchPath:@"/bin/bash"];
        NSArray *args = @[
            @"-c",
            [NSString stringWithFormat:@"/bin/echo %@ | perl -we 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack \"C*\", "
                                       @"$_; foreach (@k) { printf \"%%02X\", $_ ^ (shift @p || 0) }; print \"\n\"'",
                                       vncPasswordString]
        ];
        [perlTask setArguments:args];
        [perlTask setStandardOutput:[NSPipe pipe]];
        [perlTask setStandardError:[NSPipe pipe]];
        [perlTask launch];
        [perlTask waitUntilExit];

        NSData *stdOutData = [[[perlTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];

        NSData *stdErrData = [[[perlTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];

        if ([perlTask terminationStatus] == 0) {

            // Set perl command output to content string
            NSString *vncPasswordHash = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            NSData *vncSettingsContentData = [vncPasswordHash dataUsingEncoding:NSUTF8StringEncoding];

            // Update modification array
            [modifyDictArray addObject:@{
                NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                NBCWorkflowModifyContent : vncSettingsContentData,
                NBCWorkflowModifyTargetURL : [vncSettingsURL path],
                NBCWorkflowModifyAttributes : @{NSFileOwnerAccountName : @"root", NSFileGroupOwnerAccountName : @"wheel", NSFilePosixPermissions : @0644}
            }];
            return YES;
        } else {
            DDLogError(@"[perl][stdout] %@", stdOut);
            DDLogError(@"[perl][stderr] %@", stdErr);
            *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"perl command failed with exit status: %d", [perlTask terminationStatus]]];
            return NO;
        }
    } else {
        *error = [NBCError errorWithDescription:@"VNC password was empty!"];
        return NO;
    }
} // modifyVNCPasswordHash

- (void)modifyWiFi:(NSMutableArray *)modifyDictArray {

    DDLogInfo(@"Preparing modifications for WiFi...");

    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    NSURL *wifiKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    NSURL *wifiKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IO80211Family.kext"];

    // Update modification array
    [modifyDictArray addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove, NBCWorkflowModifySourceURL : [wifiKextURL path], NBCWorkflowModifyTargetURL : [wifiKextTargetURL path]}];

    // --------------------------------------------------------------
    //  /System/Library/CoreServices/Menu Extras/AirPort.menu
    // --------------------------------------------------------------
    NSURL *airPortMenuURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras/AirPort.menu"];
    NSURL *airPortMenuTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras Disabled/AirPort.menu"];

    // Update modification array
    [modifyDictArray
        addObject:@{NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove, NBCWorkflowModifySourceURL : [airPortMenuURL path], NBCWorkflowModifyTargetURL : [airPortMenuTargetURL path]}];

    // --------------------------------------------------------------
    //  Disable AirPort LaunchDaemons
    // --------------------------------------------------------------
    [self disableLaunchDaemons:@[ @"com.apple.airport.wps.plist", @"com.apple.airportd.plist" ] modifyDictArray:modifyDictArray];

} // modifyWiFi

@end
