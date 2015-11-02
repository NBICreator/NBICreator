//
//  NBCWorkflowResourcesModify.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-01.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowResourcesModify.h"
#import "NBCWorkflowItem.h"
#import "NBCTarget.h"
#import "NBCLogging.h"
#import "NBCConstants.h"
#import "NBCSource.h"
#import "NSString+validIP.h"
#import "NBCError.h"

DDLogLevel ddLogLevel;

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

- (NSArray *)prepareResourcesToModify {
    
    DDLogInfo(@"Preparing resources to modify..." );
    
    NSError *error;
    NSURL *baseSystemVolumeURL = [[_workflowItem target] baseSystemVolumeURL];
    if ( [baseSystemVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setBaseSystemVolumeURL:[[_workflowItem target] baseSystemVolumeURL]];
        DDLogDebug(@"[DEBUG] BaseSystem volume path: %@", [_baseSystemVolumeURL path]);
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        return nil;
    }
    
    [self setSourceVersionMinor:(int)[[[_workflowItem source] expandVariables:@"%OSMINOR%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (minor): %d", _sourceVersionMinor);
    
    [self setIsNBI:( [[[_workflowItem source] sourceType] isEqualToString:NBCSourceTypeNBI] ) ? YES : NO];
    DDLogDebug(@"[DEBUG] Source is NBI: %@", ( _isNBI ) ? @"YES" : @"NO" );
    
    [self setCreationTool:[_workflowItem userSettings][NBCSettingsNBICreationToolKey]];
    DDLogDebug(@"[DEBUG] Creation tool: %@", _creationTool);
    
    [self setSettingsChanged:[_workflowItem userSettingsChanged]];
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSMutableArray *modifyDictArray = [[NSMutableArray alloc] init];
    
    // ---------------------------------------------------------------------------------
    //  Bluetooth
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                  ) ) ) {
        if ( [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
            [self modifyBluetooth:modifyDictArray];
        }
    }
    
    // ---------------------------------------------------------------------------------
    //  Casper Imaging
    // ---------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        if ( ! [self modifyCasperImaging:modifyDictArray error:&error] ) {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
            return nil;
        }
    }
    
    // ---------------------------------------------------------------------------------
    //  com.apple.Boot.plist
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsUseVerboseBootKey] boolValue]
                                  ) ) ) {
        if ( [userSettings[NBCSettingsUseVerboseBootKey] boolValue] ) {
            [self modifyBootPlist:modifyDictArray];
        }
    }
    
    // ---------------------------------------------------------------------------------
    //  com.apple.kextd.plist
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableWiFiKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsDisableBluetoothKey] boolValue]
                                  ) ) ) {
        [self modifyKextd:modifyDictArray];
    }
    
    // ---------------------------------------------------------------------------------
    //  Console.app
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsIncludeConsoleAppKey] boolValue]
                                  ) ) ) {
        if ( [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
            [self modifyConsole:modifyDictArray];
        }
    }
    
    
    // ----------------------------------------------------------------
    //  DesktopPicture - Selected in UI (Tab: Advanced)
    // ----------------------------------------------------------------
    if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
        [self modifyDesktopPicture:modifyDictArray];
    }
    
    // ---------------------------------------------------------------------------------
    //  ntp
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsUseNetworkTimeServerKey] boolValue] ||
                                  [_settingsChanged[NBCSettingsNetworkTimeServerKey] boolValue]
                                  ) ) ) {
        if ( [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
            [self modifyNTP:modifyDictArray];
        }
    }
    
    // ---------------------------------------------------------------------------------
    //  rc.install
    // ---------------------------------------------------------------------------------
    if ( 11 <= _sourceVersionMinor ) {
        [self modifyRCInstall:modifyDictArray];
    }
    
    // ---------------------------------------------------------------------------------
    //  Spotlight
    // ---------------------------------------------------------------------------------
    [self modifySpotlight:modifyDictArray];
    
    // ---------------------------------------------------------------------------------
    //  Screen Sharing
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        if ( ! [self modifyScreenSharing:modifyDictArray error:&error] ) {
            DDLogError(@"[ERROR] %@", [error localizedDescription]);
            return nil;
        }
    }
    
    // ---------------------------------------------------------------------------------
    //  WiFi
    // ---------------------------------------------------------------------------------
    if ( ! _isNBI || ( _isNBI && (
                                  [_settingsChanged[NBCSettingsDisableWiFiKey] boolValue]
                                  ) ) ) {
        if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] ) {
            [self modifyWiFi:modifyDictArray];
        }
    }
    
    return [modifyDictArray copy];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Bluetooth
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyBluetooth:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for Bluetooth...");
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IOBluetoothFamily.kext
    // --------------------------------------------------------------
    NSURL *bluetoothKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothFamily.kext"];
    NSURL *bluetoothKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IOBluetoothFamily.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothKextURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IOBluetoothHIDDriver.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDDriverKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothHIDDriver.kext"];
    NSURL *bluetoothHIDDriverKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IOBluetoothHIDDriver.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothHIDDriverKextURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothHIDDriverKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothHIDMouse.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDMouseKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothHIDMouse.kext"];
    NSURL *bluetoothHIDMouseKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothHIDMouse.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothHIDMouseKextURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothHIDMouseKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothHIDKeyboard.kext
    // --------------------------------------------------------------
    NSURL *bluetoothHIDKeyboardKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothHIDKeyboard.kext"];
    NSURL *bluetoothHIDKeyboardKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothHIDKeyboard.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothHIDKeyboardKextURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothHIDKeyboardKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/AppleBluetoothMultitouch.kext
    // --------------------------------------------------------------
    NSURL *bluetoothMultitouchKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/AppleBluetoothMultitouch.kext"];
    NSURL *bluetoothMultitouchKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/AppleBluetoothMultitouch.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothMultitouchKextURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothMultitouchKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.bluetoothReporter.plist
    // --------------------------------------------------------------
    NSURL *bluetoothReporterPlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.bluetoothReporter.plist"];
    NSURL *bluetoothReporterPlistTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemonsDisabled/com.apple.bluetoothReporter.plist"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothReporterPlistURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothReporterPlistTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.blued.plist
    // --------------------------------------------------------------
    NSURL *bluetoothBluedPlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.blued.plist"];
    NSURL *bluetoothBluedPlistTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemonsDisabled/com.apple.blued.plist"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [bluetoothBluedPlistURL path],
                                 NBCWorkflowModifyTargetURL : [bluetoothBluedPlistTargetURL path]
                                 }];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Casper Imaging
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyCasperImaging:(NSMutableArray *)modifyDictArray error:(NSError **)error {
    
    DDLogInfo(@"Preparing modifications for Casper Imaging...");
    
    // ---------------------------------------------------------------
    //  /var/root/Library/Preferences/com.jamfsoftware.jss
    // ---------------------------------------------------------------
    NSURL *comJamfsoftwareJSSURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"var/root/Library/Preferences/com.jamfsoftware.jss"];
    NSMutableDictionary *comJamfsoftwareJSSDict = [NSMutableDictionary dictionaryWithContentsOfURL:comJamfsoftwareJSSURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comJamfsoftwareJSSAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comJamfsoftwareJSSURL path] error:nil] ?: @{
                                                                                                                                                     NSFileOwnerAccountName :       @"root",
                                                                                                                                                     NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                                     NSFilePosixPermissions :       @0644
                                                                                                                                                     };
    
    
    comJamfsoftwareJSSDict[@"allowInvalidCertificate"] = @NO;
    
    // Update com.jamfsoftware.jss with user settings (Optional)
    NSString *jssURLString = [_workflowItem userSettings][NBCSettingsCasperJSSURLKey];
    DDLogDebug(@"[DEBUG] JSS URL: %@", jssURLString);
    
    if ( [jssURLString length] != 0 ) {
        NSURL *jssURL = [NSURL URLWithString:jssURLString];
        comJamfsoftwareJSSDict[@"url"] = jssURLString ?: @"";
        
        comJamfsoftwareJSSDict[@"secure"] = [[jssURL scheme] isEqualTo:@"https"] ? @YES : @NO;
        DDLogDebug(@"[DEBUG] JSS Secure: %@", [[jssURL scheme] isEqualTo:@"https"] ? @"YES" : @"NO" );
        
        comJamfsoftwareJSSDict[@"address"] = [jssURL host] ?: @"";
        DDLogDebug(@"[DEBUG] JSS Address: %@", [jssURL host]);
        
        NSNumber *port = @80;
        if ( [jssURL port] == nil && [[jssURL scheme] isEqualTo:@"https"] ) {
            port = @443;
        } else if ( [jssURL port] != nil) {
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
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     comJamfsoftwareJSSDict,
                                 NBCWorkflowModifyAttributes :  comJamfsoftwareJSSAttributes,
                                 NBCWorkflowModifyTargetURL :   [comJamfsoftwareJSSURL path]
                                 }];
    
    // --------------------------------------------------------------
    // Casper Imaging Debug
    // --------------------------------------------------------------
    NSString *casperImagingPath;
    if ( [_creationTool isEqualToString:NBCMenuItemNBICreator] ) {
        casperImagingPath = NBCCasperImagingApplicationNBICreatorTargetURL;
    } else {
        casperImagingPath = NBCCasperImagingApplicationTargetURL;
    }
    NSURL *casperImagingURL = [NSURL fileURLWithPath:casperImagingPath];
    DDLogDebug(@"[DEBUG] Casper Imaging path: %@", [casperImagingURL path]);
    
    if ( [casperImagingURL checkResourceIsReachableAndReturnError:error]  ) {
        NSURL *casperImagingDebugURL = [casperImagingURL URLByAppendingPathComponent:@"Contents/Support/debug" isDirectory:YES];
        NSDictionary *casperImagingDebugAttributes = @{
                                                       NSFileOwnerAccountName :      @"root",
                                                       NSFileGroupOwnerAccountName : @"wheel",
                                                       NSFilePosixPermissions :      @0755
                                                       };
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeFolder,
                                     NBCWorkflowModifyTargetURL :   [casperImagingDebugURL path],
                                     NBCWorkflowModifyAttributes :  casperImagingDebugAttributes
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
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                 NBCWorkflowModifyContent :     varRootCFUserTextEncodingContentData,
                                 NBCWorkflowModifyTargetURL :   [varRootCFUserTextEncodingURL path],
                                 NBCWorkflowModifyAttributes :  @{
                                         NSFileOwnerAccountName :        @"root",
                                         NSFileGroupOwnerAccountName :   @"wheel",
                                         NSFilePosixPermissions :        @0644
                                         }}];
    
    return YES;
} // modifyCasperImaging

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Console.app
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyConsole:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for Console...");
    
    // ---------------------------------------------------------------------------------
    //  /System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist
    // ---------------------------------------------------------------------------------
    NSURL *utilitiesPlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Installation/CDIS/OS X Utilities.app/Contents/Resources/Utilities.plist"];
    if ( [utilitiesPlistURL checkResourceIsReachableAndReturnError:nil] ) {
        NSMutableDictionary *utilitiesPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:utilitiesPlistURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *utilitiesPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[utilitiesPlistURL path] error:nil] ?: @{
                                                                                                                                                 NSFileOwnerAccountName :       @"root",
                                                                                                                                                 NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                                 NSFilePosixPermissions :       @0644
                                                                                                                                                 };
        
        // Add console to Installer utilities menu
        NSMutableArray *menuArray = [[NSMutableArray alloc] initWithArray:utilitiesPlistDict[@"Menu"]] ?: [[NSMutableArray alloc] init];;
        [menuArray addObject:@{
                               @"BundlePath" :  @"/Applications/Utilities/Console.app",
                               @"Path" :        @"/Applications/Utilities/Console.app/Contents/MacOS/Console",
                               @"TitleKey" :    @"Console"
                               }];
        utilitiesPlistDict[@"Menu"] = menuArray;
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                     NBCWorkflowModifyContent :     utilitiesPlistDict,
                                     NBCWorkflowModifyAttributes :  utilitiesPlistAttributes,
                                     NBCWorkflowModifyTargetURL :   [utilitiesPlistURL path]
                                     }];
    }
    
    // ----------------------------------------------
    //  /Library/Preferences/com.apple.Console.plist
    // ----------------------------------------------
    NSURL *consolePlistURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.Console.plist"];
    NSMutableDictionary *consolePlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:consolePlistURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *consolePlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[consolePlistURL path] error:nil] ?: @{
                                                                                                                                         NSFileOwnerAccountName :       @"root",
                                                                                                                                         NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                         NSFilePosixPermissions :       @0644
                                                                                                                                         };
    
    // Hide log list
    consolePlistDict[@"LogOutlineViewVisible"] = @NO;
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     consolePlistDict,
                                 NBCWorkflowModifyAttributes :  consolePlistAttributes,
                                 NBCWorkflowModifyTargetURL :   [consolePlistURL path]
                                 }];
} // modifyConsole

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Desktop Picture
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyDesktopPicture:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for Desktop Picture...");
    
    // ------------------------------------------------------------------
    //  /Library/Desktop Pictures/...
    // ------------------------------------------------------------------
    NSString *desktopPictureDefaultPath;
    switch ( _sourceVersionMinor ) {
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
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [desktopPictureURL path],
                                 NBCWorkflowModifyTargetURL : [desktopPictureTargetURL path]
                                 }];
    
    return YES;
} // modifyDesktopPicture

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark com.apple.Boot.plist
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyBootPlist:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for com.apple.Boot.plist...");
    
    NSURL *nbiURL = [_workflowItem temporaryNBIURL];
    
    // ---------------------------------------------------------------
    //  /Library/Preferences/SystemConfiguration/com.apple.Boot.plist
    // ---------------------------------------------------------------
    NSURL *comAppleBootPlistURL = [nbiURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
    NSMutableDictionary *comAppleBootPlistDict = [NSMutableDictionary dictionaryWithContentsOfURL:comAppleBootPlistURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *comAppleBootPlistAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[comAppleBootPlistURL path] error:nil] ?: @{
                                                                                                                                                   NSFileOwnerAccountName :         @"root",
                                                                                                                                                   NSFileGroupOwnerAccountName :    @"wheel",
                                                                                                                                                   NSFilePosixPermissions :         @0644
                                                                                                                                                   };
    
    if ( [comAppleBootPlistDict[@"Kernel Flags"] length] != 0 ) {
        NSString *kernelFlags = comAppleBootPlistDict[@"Kernel Flags"];
        if ( ! [kernelFlags containsString:@"-v"] ) {
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
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     comAppleBootPlistDict,
                                 NBCWorkflowModifyAttributes :  comAppleBootPlistAttributes,
                                 NBCWorkflowModifyTargetURL :   [comAppleBootPlistURL path]
                                 }];
} // modifySettingsForBootPlist

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NetBoot Servers
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyNetBootServers:(NSMutableArray *)modifyDictArray error:(NSError **)error {
    
    DDLogInfo(@"Preparing modifications for NetBoot Servers...");
    
    // --------------------------------------------------------------
    //  /usr/local/bsdpSources.txt
    // --------------------------------------------------------------
    NSArray *bsdpSourcesArray = [_workflowItem resourcesSettings][NBCSettingsTrustedNetBootServersKey];
    if ( [bsdpSourcesArray count] != 0 ) {
        NSURL *usrLocalBsdpSourcesURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/bsdpSources.txt"];
        DDLogDebug(@"[DEBUG] bsdpSources.txt path: %@", [usrLocalBsdpSourcesURL path]);
        
        // Create file contents by looping array of user selected IPs
        NSMutableString *bsdpSourcesContent = [[NSMutableString alloc] init];
        for ( NSString *ip in bsdpSourcesArray ) {
            if ( [ip isValidIPAddress] ) {
                DDLogDebug(@"[DEBUG] Adding netboot server ip: %@", ip);
                [bsdpSourcesContent appendString:[NSString stringWithFormat:@"%@\n", ip]];
            } else {
                *error = [NBCError errorWithDescription:[NSString stringWithFormat:@"Invalid netboot server ip: %@ ", ip]];
                return NO;
            }
        }
        
        if ( [bsdpSourcesContent length] != 0 ) {
            
            // Convert content string to data
            NSData *bsdpSourcesData = [bsdpSourcesContent dataUsingEncoding:NSUTF8StringEncoding];
            
            // Update modification array
            [modifyDictArray addObject:@{
                                         NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                         NBCWorkflowModifyContent :     bsdpSourcesData,
                                         NBCWorkflowModifyTargetURL :   [usrLocalBsdpSourcesURL path],
                                         NBCWorkflowModifyAttributes :  @{
                                                 NSFileOwnerAccountName :      @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions :      @0644
                                                 }
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
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark com.apple.kextd.plist
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyKextd:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for com.apple.kextd.plist...");
    
    // ------------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.kextd.plist
    // ------------------------------------------------------------------
    NSURL *kextdLaunchDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.kextd.plist"];
    NSMutableDictionary *kextdLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:kextdLaunchDaemonURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *kextdLaunchDaemonAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[kextdLaunchDaemonURL path] error:nil] ?: @{
                                                                                                                                                   NSFileOwnerAccountName :      @"root",
                                                                                                                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                                                   NSFilePosixPermissions :      @0644
                                                                                                                                                   };
    
    // Add '-no-caches' to ProgramArguments
    NSMutableArray *kextdProgramArguments = [NSMutableArray arrayWithArray:kextdLaunchDaemonDict[@"ProgramArguments"]];
    if ( ! [kextdProgramArguments containsObject:@"-no-caches"] ) {
        [kextdProgramArguments addObject:@"-no-caches"];
        kextdLaunchDaemonDict[@"ProgramArguments"] = kextdProgramArguments;
        
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                     NBCWorkflowModifyContent :     kextdLaunchDaemonDict,
                                     NBCWorkflowModifyAttributes :  kextdLaunchDaemonAttributes,
                                     NBCWorkflowModifyTargetURL :   [kextdLaunchDaemonURL path]
                                     }];
    } else {
        DDLogInfo(@"com.apple.kextd.plist already includes argument '-no-caches'");
    }
} // modifyKextd

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NTP
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyNTP:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for NTP...");
    
    // --------------------------------------------------------------
    //  /etc/ntp.conf
    // --------------------------------------------------------------
    NSString *ntpServer = [_workflowItem userSettings][NBCSettingsNetworkTimeServerKey] ?: NBCNetworkTimeServerDefault;
    
    // Verify that server resolves
    if ( [self verifyNTPServer:ntpServer] ) {
        NSURL *ntpConfURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];
        
        // Convert string to data
        NSData *ntpConfContentData = [ntpServer dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *ntpConfAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[ntpConfURL path] error:nil] ?: @{
                                                                                                                                   NSFileOwnerAccountName :       @"root",
                                                                                                                                   NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                   NSFilePosixPermissions :       @0644
                                                                                                                                   };
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                     NBCWorkflowModifyContent :     ntpConfContentData,
                                     NBCWorkflowModifyTargetURL :   [ntpConfURL path],
                                     NBCWorkflowModifyAttributes :  ntpConfAttributes
                                     }];
        return YES;
    } else {
        return NO;
    }
} // modifyNTP

- (BOOL)verifyNTPServer:(NSString *)ntpServer {
    
    DDLogInfo(@"[DEBUG] Verifying NTP server: %@...", ntpServer);
    
    NSTask *digTask =  [[NSTask alloc] init];
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
    
    if ( [digTask terminationStatus] == 0 ) {
        NSString *digOutput = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        if ( [digOutput length] != 0 ) {
            
            NSArray *ntpServerArray = [digOutput componentsSeparatedByString:@"\n"];
            ntpServer = [NSString stringWithFormat:@"server %@", ntpServer];
            for ( NSString *ip in ntpServerArray ) {
                if ( [ip isValidIPAddress] ) {
                    DDLogInfo(@"NTP server ip address: %@", ip);
                    ntpServer = [ntpServer stringByAppendingString:[NSString stringWithFormat:@"\nserver %@", ip]];
                } else {
                    DDLogError(@"[ERROR] NTP server ip address invalid: %@", ip);
                    return NO;
                }
            }
            
            if ( [ntpServer length] != 0 ) {
                return YES;
            } else {
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
#pragma mark rc.install
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyRCInstall:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for rc.install...");
    
    NSError *error;
    
    // ------------------------------------------------------------------
    //  /etc/rc.install
    // ------------------------------------------------------------------
    NSURL *rcInstallURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/rc.install"];
    
    NSString *rcInstallContentStringOriginal = [NSMutableString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:&error];
    if ( ! error && [rcInstallContentStringOriginal length] != 0 ) {
        
        // Loop through rc.install and comment out line with Installer Progress.app (10.11)
        NSMutableString *rcInstallContentString = [[NSMutableString alloc] init];
        NSArray *rcInstallContentArray = [rcInstallContentStringOriginal componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for ( NSString *line in rcInstallContentArray ) {
            if ( [line containsString:@"/System/Library/CoreServices/Installer\\ Progress.app"] ) {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"#%@\n", line]];
            } else {
                [rcInstallContentString appendString:[NSString stringWithFormat:@"%@\n", line]];
            }
        }
        
        if ( [rcInstallContentString length] != 0 ) {
            
            // Convert string to data
            NSData *rcInstallData = [rcInstallContentString dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *rcInstallAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[rcInstallURL path] error:nil] ?: @{
                                                                                                                                           NSFileOwnerAccountName :       @"root",
                                                                                                                                           NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                           NSFilePosixPermissions :       @0644
                                                                                                                                           };
            
            // Update modification array
            [modifyDictArray addObject:@{
                                         NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                         NBCWorkflowModifyContent :     rcInstallData,
                                         NBCWorkflowModifyAttributes :  rcInstallAttributes,
                                         NBCWorkflowModifyTargetURL :   [rcInstallURL path]
                                         }];
            
            return YES;
        } else {
            DDLogError(@"[ERROR] Modification of rc.install failed!");
            return NO;
        }
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        return NO;
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Spotlight
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifySpotlight:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for Spotlight...");
    
    // --------------------------------------------------------------
    //  /.Spotlight-V100/_IndexPolicy.plist
    // --------------------------------------------------------------
    NSURL *spotlightIndexingSettingsURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@".Spotlight-V100/_IndexPolicy.plist"];
    NSMutableDictionary *spotlightIndexingSettingsDict = [NSMutableDictionary dictionaryWithContentsOfURL:spotlightIndexingSettingsURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *spotlightIndexingSettingsAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[spotlightIndexingSettingsURL path] error:nil] ?: @{
                                                                                                                                                                   NSFileOwnerAccountName : @"root",
                                                                                                                                                                   NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                                                                   NSFilePosixPermissions : @0600
                                                                                                                                                                   };
    
    // Set policy to '3' (Disabled)
    spotlightIndexingSettingsDict[@"Policy"] = @3;
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     spotlightIndexingSettingsDict,
                                 NBCWorkflowModifyAttributes :  spotlightIndexingSettingsAttributes,
                                 NBCWorkflowModifyTargetURL :   [spotlightIndexingSettingsURL path]
                                 }];
} // modifySpotlight

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark ScreenSharing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)modifyScreenSharing:(NSMutableArray *)modifyDictArray error:(NSError **)error {
    
    DDLogInfo(@"Preparing modifications for Screen Sharing...");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.RemoteManagement.plist
    // --------------------------------------------------------------
    NSURL *remoteManagementURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.RemoteManagement.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteManagement.plist path: %@", [remoteManagementURL path]);
    
    NSMutableDictionary *remoteManagementDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteManagementURL] ?: [[NSMutableDictionary alloc] init];
    NSDictionary *remoteManagementAttributes = [fm attributesOfItemAtPath:[remoteManagementURL path] error:nil] ?: @{
                                                                                                                     NSFileOwnerAccountName :      @"root",
                                                                                                                     NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                     NSFilePosixPermissions :      @0644
                                                                                                                     };
    
    remoteManagementDict[@"ARD_AllLocalUsers"] =              @YES;
    remoteManagementDict[@"ARD_AllLocalUsersPrivs"] =         @-1073741569;
    remoteManagementDict[@"LoadRemoteManagementMenuExtra"] =  @NO;
    remoteManagementDict[@"DisableKerberos"] =                @NO;
    remoteManagementDict[@"ScreenSharingReqPermEnabled"] =    @NO;
    remoteManagementDict[@"VNCLegacyConnectionsEnabled"] =    @YES;
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     remoteManagementDict,
                                 NBCWorkflowModifyAttributes :  remoteManagementAttributes,
                                 NBCWorkflowModifyTargetURL :   [remoteManagementURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.screensharing.plist
    // --------------------------------------------------------------
    NSURL *screensharingLaunchDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.screensharing.plist"];
    DDLogDebug(@"[DEBUG] com.apple.screensharing.plist path: %@", [screensharingLaunchDaemonURL path]);
    
    if ( [screensharingLaunchDaemonURL checkResourceIsReachableAndReturnError:error] ) {
        NSMutableDictionary *screensharingLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingLaunchDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *screensharingLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingLaunchDaemonURL path] error:nil] ?: @{
                                                                                                                                           NSFileOwnerAccountName :      @"root",
                                                                                                                                           NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                                           NSFilePosixPermissions :      @0644
                                                                                                                                           };
        
        // Run launchdaemon as root
        screensharingLaunchDaemonDict[@"UserName"] = @"root";
        screensharingLaunchDaemonDict[@"GroupName"] = @"wheel";
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                     NBCWorkflowModifyContent :     screensharingLaunchDaemonDict,
                                     NBCWorkflowModifyTargetURL :   [screensharingLaunchDaemonURL path],
                                     NBCWorkflowModifyAttributes :  screensharingLaunchDaemonAttributes
                                     }];
    } else {
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopPrivilegeProxyDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.RemoteDesktop.PrivilegeProxy.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteDesktop.PrivilegeProxy.plist path: %@", [remoteDesktopPrivilegeProxyDaemonURL path]);
    
    if ( [remoteDesktopPrivilegeProxyDaemonURL checkResourceIsReachableAndReturnError:error] ) {
        NSMutableDictionary *remoteDesktopPrivilegeProxyLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopPrivilegeProxyDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *remoteDesktopPrivilegeProxyLaunchDaemonAttributes = [fm attributesOfItemAtPath:[remoteDesktopPrivilegeProxyDaemonURL path] error:nil] ?: @{
                                                                                                                                                                 NSFileOwnerAccountName :      @"root",
                                                                                                                                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                                                                 NSFilePosixPermissions :      @0644
                                                                                                                                                                 };
        
        // Run launchdaemon as root
        remoteDesktopPrivilegeProxyLaunchDaemonDict[@"UserName"] =  @"root";
        remoteDesktopPrivilegeProxyLaunchDaemonDict[@"GroupName"] = @"wheel";
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                     NBCWorkflowModifyContent :     remoteDesktopPrivilegeProxyLaunchDaemonDict,
                                     NBCWorkflowModifyTargetURL :   [remoteDesktopPrivilegeProxyDaemonURL path],
                                     NBCWorkflowModifyAttributes :  remoteDesktopPrivilegeProxyLaunchDaemonAttributes
                                     }];
    } else {
        return NO;
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.agent.plist
    // --------------------------------------------------------------
    NSURL *screensharingAgentDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.agent.plist"];
    DDLogDebug(@"[DEBUG] com.apple.screensharing.agent.plist path: %@", [screensharingAgentDaemonURL path]);
    
    if ( [screensharingAgentDaemonURL checkResourceIsReachableAndReturnError:error] ) {
        NSMutableDictionary *screensharingAgentLaunchDaemonDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingAgentDaemonURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *screensharingAgentLaunchDaemonAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:nil] ?: @{
                                                                                                                                               NSFileOwnerAccountName :      @"root",
                                                                                                                                               NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                                               NSFilePosixPermissions :      @0644
                                                                                                                                               };
        
        // Remove LimitLoadToSessionType to run in NetInstall
        [screensharingAgentLaunchDaemonDict removeObjectForKey:@"LimitLoadToSessionType"];
        
        //+ TESTING: TO EXCLUDE
        //screensharingAgentLaunchDaemonDict[@"RunAtLoad"] = @YES;
        
        // Update modification array
        [modifyDictArray addObject:@{
                                     NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                     NBCWorkflowModifyContent :     screensharingAgentLaunchDaemonDict,
                                     NBCWorkflowModifyTargetURL :   [screensharingAgentDaemonURL path],
                                     NBCWorkflowModifyAttributes :  screensharingAgentLaunchDaemonAttributes
                                     }];
    }
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist
    // --------------------------------------------------------------
    if ( 7 < _sourceVersionMinor ) {
        NSURL *screensharingMessagesAgentDaemonURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.screensharing.MessagesAgent.plist"];
        DDLogDebug(@"[DEBUG] com.apple.screensharing.MessagesAgent.plist path: %@", [screensharingMessagesAgentDaemonURL path]);
        
        if ( [screensharingMessagesAgentDaemonURL checkResourceIsReachableAndReturnError:error] ) {
            NSMutableDictionary * screensharingMessagesAgentLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:screensharingMessagesAgentDaemonURL] ?: [[NSMutableDictionary alloc] init];
            NSDictionary * screensharingMessagesAgentLaunchAgentAttributes = [fm attributesOfItemAtPath:[screensharingAgentDaemonURL path] error:nil] ?: @{
                                                                                                                                                           NSFileOwnerAccountName :       @"root",
                                                                                                                                                           NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                                           NSFilePosixPermissions :       @0644
                                                                                                                                                           };
            // Set launch daemon to run at load
            screensharingMessagesAgentLaunchAgentDict[@"RunAtLoad"] = @YES;
            
            // Update modification array
            [modifyDictArray addObject:@{
                                         NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                         NBCWorkflowModifyContent :     screensharingMessagesAgentLaunchAgentDict,
                                         NBCWorkflowModifyTargetURL :   [screensharingMessagesAgentDaemonURL path],
                                         NBCWorkflowModifyAttributes :  screensharingMessagesAgentLaunchAgentAttributes
                                         }];
        } else if ( 7 < _sourceVersionMinor ) {
            /*
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
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                 NBCWorkflowModifyContent :     etcScreensharingAgentLaunchdContentData,
                                 NBCWorkflowModifyTargetURL :   [etcScreensharingAgentLaunchdURL path],
                                 NBCWorkflowModifyAttributes :  @{
                                         NSFileOwnerAccountName :       @"root",
                                         NSFileGroupOwnerAccountName :  @"wheel",
                                         NSFilePosixPermissions :       @0644
                                         }
                                 }];
    
    // --------------------------------------------------------------
    //  /etc/RemoteManagement.launchd
    // --------------------------------------------------------------
    NSURL *etcRemoteManagementLaunchdURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"etc/RemoteManagement.launchd"];
    DDLogDebug(@"[DEBUG] RemoteManagement.launchd path: %@", [etcRemoteManagementLaunchdURL path]);
    
    
    // Set content of file to the string 'enabled'
    NSString *etcRemoteManagementLaunchdContentString = @"enabled\n";
    NSData *etcRemoteManagementLaunchdContentData = [etcRemoteManagementLaunchdContentString dataUsingEncoding:NSUTF8StringEncoding];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypeGeneric,
                                 NBCWorkflowModifyContent :     etcRemoteManagementLaunchdContentData,
                                 NBCWorkflowModifyTargetURL :   [etcRemoteManagementLaunchdURL path],
                                 NBCWorkflowModifyAttributes :  @{
                                         NSFileOwnerAccountName :       @"root",
                                         NSFileGroupOwnerAccountName :  @"wheel",
                                         NSFilePosixPermissions :       @0644
                                         }
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/LaunchAgents/com.apple.RemoteDesktop.plist
    // --------------------------------------------------------------
    NSURL *remoteDesktopLaunchAgentURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchAgents/com.apple.RemoteDesktop.plist"];
    DDLogDebug(@"[DEBUG] com.apple.RemoteDesktop.plist path: %@", [remoteDesktopLaunchAgentURL path]);
    
    if ( [remoteDesktopLaunchAgentURL checkResourceIsReachableAndReturnError:error] ) {
        NSMutableDictionary *remoteDesktopLaunchAgentDict = [NSMutableDictionary dictionaryWithContentsOfURL:remoteDesktopLaunchAgentURL] ?: [[NSMutableDictionary alloc] init];
        NSDictionary *remoteDesktopLaunchAgentAttributes = [fm attributesOfItemAtPath:[remoteDesktopLaunchAgentURL path] error:nil] ?: @{
                                                                                                                                         NSFileOwnerAccountName :       @"root",
                                                                                                                                         NSFileGroupOwnerAccountName :  @"wheel",
                                                                                                                                         NSFilePosixPermissions :       @0644
                                                                                                                                         };
        
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
    NSDictionary *remoteDesktopAttributes = [fm attributesOfItemAtPath:[remoteDesktopURL path] error:nil] ?: @{
                                                                                                                  NSFileOwnerAccountName : @"root",
                                                                                                                  NSFileGroupOwnerAccountName : @"wheel",
                                                                                                                  NSFilePosixPermissions : @0644
                                                                                                                  };
    
    // Configure remote desktop to allow full access to all users
    remoteDesktopDict[@"DOCAllowRemoteConnections"] = @YES;
    remoteDesktopDict[@"RestrictedFeatureList"] =     @[
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
    remoteDesktopDict[@"Text1"] =                     @"";
    remoteDesktopDict[@"Text2"] =                     @"";
    remoteDesktopDict[@"Text3"] =                     @"";
    remoteDesktopDict[@"Text4"] =                     @"";
    

    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType :    NBCWorkflowModifyFileTypePlist,
                                 NBCWorkflowModifyContent :     remoteDesktopDict,
                                 NBCWorkflowModifyTargetURL :   [remoteDesktopURL path],
                                 NBCWorkflowModifyAttributes :  remoteDesktopAttributes
                                 }];
    
    return [self addVNCPasswordHash:modifyDictArray error:error];
} // modifySettingsForVNC:workflowItem

- (BOOL)addVNCPasswordHash:(NSMutableArray *)modifyDictArray error:(NSError **)error {
    
    DDLogDebug(@"[DEBUG] Generating password hash for com.apple.VNCSettings.txt...");
    
    // --------------------------------------------------------------
    //  /Library/Preferences/com.apple.VNCSettings.txt
    // --------------------------------------------------------------
    NSURL *vncSettingsURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
    DDLogDebug(@"[DEBUG] com.apple.VNCSettings.txt path: %@", [vncSettingsURL path]);
    
    NSString *vncPasswordString = [_workflowItem userSettings][NBCSettingsARDPasswordKey];
    if ( [vncPasswordString length] != 0 ) {
        
        NSTask *perlTask =  [[NSTask alloc] init];
        [perlTask setLaunchPath:@"/bin/bash"];
        NSArray *args = @[ @"-c", [NSString stringWithFormat:@"/bin/echo %@ | perl -we 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; $_ = <>; chomp; s/^(.{8}).*/$1/; @p = unpack \"C*\", $_; foreach (@k) { printf \"%%02X\", $_ ^ (shift @p || 0) }; print \"\n\"'", vncPasswordString]];
        [perlTask setArguments:args];
        [perlTask setStandardOutput:[NSPipe pipe]];
        [perlTask setStandardError:[NSPipe pipe]];
        [perlTask launch];
        [perlTask waitUntilExit];
        
        NSData *stdOutData = [[[perlTask standardOutput] fileHandleForReading] readDataToEndOfFile];
        NSString *stdOut = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
        
        NSData *stdErrData = [[[perlTask standardError] fileHandleForReading] readDataToEndOfFile];
        NSString *stdErr = [[NSString alloc] initWithData:stdErrData encoding:NSUTF8StringEncoding];
        
        if ( [perlTask terminationStatus] == 0 ) {
            
            // Set perl command output to content string
            NSString *vncPasswordHash = [[NSString alloc] initWithData:stdOutData encoding:NSUTF8StringEncoding];
            NSData *vncSettingsContentData = [vncPasswordHash dataUsingEncoding:NSUTF8StringEncoding];
            
            // Update modification array
            [modifyDictArray addObject:@{
                                         NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeGeneric,
                                         NBCWorkflowModifyContent : vncSettingsContentData,
                                         NBCWorkflowModifyTargetURL : [vncSettingsURL path],
                                         NBCWorkflowModifyAttributes : @{
                                                 NSFileOwnerAccountName : @"root",
                                                 NSFileGroupOwnerAccountName : @"wheel",
                                                 NSFilePosixPermissions : @0644
                                                 }
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
} // addVNCPasswordHash

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark WiFi
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)modifyWiFi:(NSMutableArray *)modifyDictArray {
    
    DDLogInfo(@"Preparing modifications for WiFi...");
    
    // --------------------------------------------------------------
    //  /System/Library/Extensions/IO80211Family.kext
    // --------------------------------------------------------------
    NSURL *wifiKextURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
    NSURL *wifiKextTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/ExtensionsDisabled/IO80211Family.kext"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [wifiKextURL path],
                                 NBCWorkflowModifyTargetURL : [wifiKextTargetURL path]
                                 }];
    
    // --------------------------------------------------------------
    //  /System/Library/CoreServices/Menu Extras/AirPort.menu
    // --------------------------------------------------------------
    NSURL *airPortMenuURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras/AirPort.menu"];
    NSURL *airPortMenuTargetURL = [_baseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/Menu Extras Disabled/AirPort.menu"];
    
    // Update modification array
    [modifyDictArray addObject:@{
                                 NBCWorkflowModifyFileType : NBCWorkflowModifyFileTypeMove,
                                 NBCWorkflowModifySourceURL : [airPortMenuURL path],
                                 NBCWorkflowModifyTargetURL : [airPortMenuTargetURL path]
                                 }];
} // modifyWiFi

@end
