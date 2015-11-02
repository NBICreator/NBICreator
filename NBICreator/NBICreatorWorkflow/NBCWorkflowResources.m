//
//  NBCWorkflowResources.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-01.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowResources.h"
#import "NBCWorkflowItem.h"
#import "NBCTarget.h"
#import "NBCLogging.h"
#import "NBCConstants.h"
#import "NBCSource.h"

DDLogLevel ddLogLevel;

@implementation NBCWorkflowResources

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)initWithWorkflowItem:(NBCWorkflowItem *)workflowItem {
    self = [super init];
    if (self != nil) {
        _resourcesBaseSystemModify = [[NSMutableArray alloc] init];
        _resourcesNetInstallModify = [[NSMutableArray alloc] init];
        _workflowItem = workflowItem;
    }
    return self;
} // init

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Extraction Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)extractItemsFromEssentials:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageEssentialsRegexes addObjectsFromArray:itemsArray];
    packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageEssentialsRegexes;
    sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
} // extractItemsFromEssentials

- (void)extractItemsFromAdditionalEssentials:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if ( 11 <= _sourceVersionMinor ) {
        [self extractItemsFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }
    
    NSString *packageAdditionalEssentialsPath = [NSString stringWithFormat:@"%@/Packages/AdditionalEssentials.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageAdditionalEssentialsDict = [sourceItemsDict[packageAdditionalEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageAdditionalEssentialsRegexes = [packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageAdditionalEssentialsRegexes addObjectsFromArray:itemsArray];
    packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey] = packageAdditionalEssentialsRegexes;
    sourceItemsDict[packageAdditionalEssentialsPath] = packageAdditionalEssentialsDict;
} // extractItemsFromAdditionalEssentials

- (void)extractItemsFromBSD:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if ( 11 <= _sourceVersionMinor ) {
        [self extractItemsFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }
    
    NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *packageBSDDict = [sourceItemsDict[packageBSDPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *packageBSDRegexes = [packageBSDDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [packageBSDRegexes addObjectsFromArray:itemsArray];
    packageBSDDict[NBCSettingsSourceItemsRegexKey] = packageBSDRegexes;
    sourceItemsDict[packageBSDPath] = packageBSDDict;
} // extractItemsFromBSD

- (void)extractItemsFromBaseSystemBinaries:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if ( 11 <= _sourceVersionMinor ) {
        [self extractItemsFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }
    
    NSString *baseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *baseSystemBinariesDict = [sourceItemsDict[baseSystemBinariesPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *baseSystemBinariesRegexes = [baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [baseSystemBinariesRegexes addObjectsFromArray:itemsArray];
    baseSystemBinariesDict[NBCSettingsSourceItemsRegexKey] = baseSystemBinariesRegexes;
    sourceItemsDict[baseSystemBinariesPath] = baseSystemBinariesDict;
} // extractItemsFromBaseSystemBinaries

- (void)extractItemsFromMediaFiles:(NSArray *)itemsArray sourceItemsDict:(NSMutableDictionary *)sourceItemsDict {
    if ( 11 <= _sourceVersionMinor ) {
        [self extractItemsFromEssentials:itemsArray sourceItemsDict:sourceItemsDict];
        return;
    }
    
    NSString *mediaFilesPath = [NSString stringWithFormat:@"%@/Packages/MediaFiles.pkg", [_installESDVolumeURL path]];
    NSMutableDictionary *mediaFilesDict = [sourceItemsDict[mediaFilesPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
    NSMutableArray *mediaFilesRegexes = [mediaFilesDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
    [mediaFilesRegexes addObjectsFromArray:itemsArray];
    mediaFilesDict[NBCSettingsSourceItemsRegexKey] = mediaFilesRegexes;
    sourceItemsDict[mediaFilesPath] = mediaFilesDict;
} // extractItemsFromMediaFiles

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Prepare Resources
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSMutableDictionary *)prepareResourcesToExtract:(NSMutableDictionary *)resourcesSettings {
    
    DDLogInfo(@"Preparing resources to extract..." );
    
    [self setSource:[_workflowItem source]];
    
    NSError *error;
    NSURL *installESDVolumeURL = [_source installESDVolumeURL];
    if ( [installESDVolumeURL checkResourceIsReachableAndReturnError:&error] ) {
        [self setInstallESDVolumeURL:installESDVolumeURL];
        DDLogDebug(@"[DEBUG] InstallESD volume path: %@", [_installESDVolumeURL path]);
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
        return nil;
    }
    
    [self setSourceVersionMinor:(int)[[_source expandVariables:@"%OSMINOR%"] integerValue]];
    DDLogDebug(@"[DEBUG] Source os version (minor): %d", _sourceVersionMinor);
    
    NSDictionary *userSettings = [_workflowItem userSettings];
    NSMutableDictionary *sourceItemsDict = [[resourcesSettings[NBCSettingsSourceItemsKey] mutableCopy] ?: [NSMutableDictionary alloc] init];
    
    // ---------------------------------------------------------------------------------
    //  AppleScript
    // ---------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        [self addAppleScript:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  ARD - Selected in UI (Tab: Options)
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsARDLoginKey] length] != 0 && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [self addARD:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  Casper Imaging
    // ---------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        [self addCasperImaging:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  Console.app
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
        [self addConsole:sourceItemsDict];
    }
    
    // ----------------------------------------------------------------
    //  DesktopPicture - Selected in UI (Tab: Advanced)
    // ----------------------------------------------------------------
    if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
        [self addDesktopPicture:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------
    //  Kernel - Included if selections in UI requires regenerating kernel caches
    // ---------------------------------------------------------------------------
    //if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] || [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
        [self addKernel:sourceItemsDict];
    //}
    
    // ---------------------------------------------------------------------------------
    //  libssl
    // ---------------------------------------------------------------------------------
    if ( 11 <= _sourceVersionMinor ) {
        [self addLibSsl:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  networkd
    // ---------------------------------------------------------------------------------
    if ( 11 <= _sourceVersionMinor ) {
        [self addNetworkd:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  ntp
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
        [self addNTP:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  NSURLStoraged / NSURLSessiond
    // ---------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        [self addNSURLStoraged:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  Python
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsIncludePythonKey] boolValue] ) {
        [self addPython:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  Ruby
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsIncludeRubyKey] boolValue] ) {
        [self addRuby:sourceItemsDict];
    }
    
    // --------------------------------------------------------------------------------
    //  Screen Sharing - Selected in UI (Tab: Options)
    // --------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [self addScreenSharing:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  spctl
    // ---------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        [self addSpctl:sourceItemsDict];
    }
    
    // ---------------------------------------------------------------------------------
    //  System Keychain
    // ---------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
        [self addSystemkeychain:sourceItemsDict];
    }
    
    // --------------------------------------------------------------------------------
    //  SystemUIServer - Selected in UI (Tab: Options)
    // --------------------------------------------------------------------------------
    if ( [userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
        [self addSystemUIServer:sourceItemsDict];
    }
    
    // --------------------------------------------------------------------------------
    // taskgated -
    // --------------------------------------------------------------------------------
    if ( /* DISABLES CODE */ (NO) ) {
        [self addTaskgated:sourceItemsDict];
    }
    
    resourcesSettings[NBCSettingsSourceItemsKey] = [sourceItemsDict copy];
    NSLog(@"sourceItemsDict=%@", sourceItemsDict);
    return resourcesSettings;
} // prepareItemsToInclude

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark AppleScript
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addAppleScript:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract AppleScript...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*/[Aa]pple[Ss]cript.*",
                                                                  @".*appleevents.*",
                                                                  @".*/sdef.dtd.*",
                                                                  @".*ScriptingAdditions.*",
                                                                  @".*/[Ss]ystem\\ [Ee]vents.*",
                                                                  @".*/Automator.framework.*",      // For System Events.app
                                                                  @".*/OSAKit.framework.*",         // For System Events.app
                                                                  @".*/ScriptingBridge.framework.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*/osascript.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addAppleScript

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark ARD
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addARD:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract ARD...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*/ARDAgent.app.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addARD

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Casper Imaging
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addCasperImaging:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Casper Imaging...");
    
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // ---------------------------------------------------------------------------------
    //  ~/Library/Application Support
    // ---------------------------------------------------------------------------------
    NSURL *userApplicationSupportURL = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( ! [userApplicationSupportURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }
    
    // ---------------------------------------------------------------------------------
    //  Path to CasperImaging.plist
    // ---------------------------------------------------------------------------------
    NSString *casperImagingDependenciesPathComponent = [NSString stringWithFormat:@"%@/CasperImaging.plist", NBCFolderResourcesDependencies];
    NSURL *casperImagingDependenciesURL = [userApplicationSupportURL URLByAppendingPathComponent:casperImagingDependenciesPathComponent isDirectory:YES];
    if ( ! [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:nil] ) {
        DDLogError(@"[ERROR] Could not find a downloaded resource file!");
        casperImagingDependenciesURL = [[NSBundle mainBundle] URLForResource:@"CasperImaging" withExtension:@"plist"];
    }
    DDLogDebug(@"[DEBUG] CasperImaging.plist path: %@", [casperImagingDependenciesURL path]);
    
    // ---------------------------------------------------------------------------------
    //  Read regexes from resources dict
    // ---------------------------------------------------------------------------------
    NSString *sourceOSVersion = [_source expandVariables:@"%OSVERSION%"];
    NSString *sourceOSBuild = [_source expandVariables:@"%OSBUILD%"];
    NSDictionary *buildDict;
    if ( [casperImagingDependenciesURL checkResourceIsReachableAndReturnError:&error] ) {
        
        NSDictionary *casperImagingDependenciesDict = [NSDictionary dictionaryWithContentsOfURL:casperImagingDependenciesURL];
        if ( [casperImagingDependenciesDict count] != 0 ) {
            
            NSDictionary *sourceDict = casperImagingDependenciesDict[sourceOSVersion];
            if ( [sourceDict count] != 0 ) {
                
                NSArray *sourceBuilds = [sourceDict allKeys];
                if ( [sourceBuilds containsObject:sourceOSBuild] ) {
                    buildDict = sourceDict[sourceOSBuild];
                } else {
                    DDLogError(@"[ERROR] No extrations found for current os build: %@", sourceOSBuild);
                }
            } else {
                DDLogError(@"[ERROR] No extrations found for current os version: %@", sourceOSVersion);
            }
        } else {
            DDLogError(@"[ERROR] CasperImaging.plist was empty");
        }
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:buildDict[@"Essentials"]];
    
    if ( 11 <= _sourceVersionMinor ) {
        [essentials addObjectsFromArray:@[
                                          @".*/lib/libenergytrace.dylib.*",         // For 'IOKit'
                                          @".*/Frameworks/Metal.framework.*",       // For 'CoreGraphics'
                                          @".*/Libraries/libCoreFSCache.dylib.*",   // For 'Metal'
                                          @".*/lib/libmarisa.dylib.*",              // For 'libmecabra'
                                          @".*/lib/libChineseTokenizer.dylib.*",    // For 'libmecabra'
                                          @".*/lib/libFosl_dynamic.dylib.*",        // For 'CoreImage'
                                          @".*/Libraries/libCoreVMClient.dylib.*",  // For 'libCVMSPluginSupport'
                                          @".*/lib/libScreenReader.dylib.*",        // For 'AppKit'
                                          @".*/lib/libcompression.dylib.*",         // For 'DiskImages/CoreData'
                                          @".*/Libraries/libcldcpuengine.dylib.*",
                                          
                                          /* -- BELOW ARE TESTING ONLY -- */
                                          @".*/Kernels/kernel.*",
                                          // warning, could not bind /Volumes/dmg.Zn4BY5/usr/lib/libUniversalAccess.dylib because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Libraries/libUAPreferences.dylib
                                          @".*/PrivateFrameworks/UniversalAccess.framework.*",
                                          // warning, could not bind /Volumes/dmg.Zn4BY5/System/Library/Frameworks/Automator.framework/Versions/A/Automator because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/XprotectFramework.framework/Versions/A/XprotectFramework
                                          @".*/PrivateFrameworks/XprotectFramework.framework.*",
                                          // warning, could not bind /System/Library/Frameworks/MultipeerConnectivity.framework/Versions/A/MultipeerConnectivity because realpath() failed on /Volumes/dmg.Zn4BY5/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace
                                          @".*/PrivateFrameworks/AVConference.framework.*",
                                          // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Frameworks/ViceroyTrace.framework/Versions/A/ViceroyTrace because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
                                          @".*/PrivateFrameworks/Marco.framework.*",
                                          // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoProcessing.framework/Versions/A/VideoProcessing
                                          @".*/PrivateFrameworks/VideoProcessing.framework.*",
                                          // warning, could not bind /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/AVConference.framework/Versions/A/AVConference because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices
                                          @".*/PrivateFrameworks/FTServices.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco
                                          @".*/PrivateFrameworks/FTAWD.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore
                                          @".*/PrivateFrameworks/IMCore.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/VideoConference.framework/Versions/A/VideoConference
                                          @".*/PrivateFrameworks/VideoConference.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/IMTranscoding.framework/Versions/A/IMTranscoding because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation
                                          @".*/PrivateFrameworks/IMFoundation.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/WebKit2.framework/Versions/A/WebKit2
                                          @".*/PrivateFrameworks/WebKit2.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/StoreUI.framework/Versions/A/StoreUI because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/CoreRecognition.framework/Versions/A/CoreRecognition
                                          @".*/PrivateFrameworks/CoreRecognition.framework.*",
                                          // warning, could not bind /System/Library/PrivateFrameworks/Shortcut.framework/Versions/A/Shortcut because realpath() failed on /Volumes/dmg.igPP5Y/System/Library/PrivateFrameworks/HelpData.framework/Versions/A/HelpData
                                          @".*/PrivateFrameworks/HelpData.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/FTServices.framework/Versions/A/FTServices because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDSFoundation.framework/Versions/A/IDSFoundation
                                          @".*/PrivateFrameworks/IDSFoundation.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Marco.framework/Versions/A/Marco because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/DiagnosticLogCollection.framework/Versions/A/DiagnosticLogCollection
                                          @".*/PrivateFrameworks/DiagnosticLogCollection.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IDS.framework/Versions/A/IDS
                                          @".*/PrivateFrameworks/IDS.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore because realpath() failed on /Volumes/dmg.vBWxTy/System/Library/Frameworks/InstantMessage.framework/Versions/A/InstantMessage
                                          @".*/Frameworks/InstantMessage.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/usr/lib/libtidy.A.dylib is missing arch i386
                                          @".*/lib/libtidy.A.dylib.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/CommonUtilities.framework/Versions/A/CommonUtilities is missing arch i386
                                          @".*/PrivateFrameworks/CommonUtilities.framework.*",
                                          // warning, could not bind /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/IMFoundation.framework/Versions/A/IMFoundation because /Volumes/dmg.vBWxTy/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom is missing arch i386
                                          @".*/PrivateFrameworks/Bom.framework.*",
                                          // update_dyld_shared_cache: warning can't use root '/System/Library/CoreServices/FolderActionsDispatcher.app/Contents/MacOS/FolderActionsDispatcher': file not found
                                          @".*/FolderActionsDispatcher.app.*",
                                          // update_dyld_shared_cache: warning can't use root '/System/Library/Image Capture/Support/icdd': file not found
                                          @".*/Support/icdd.*",
                                          // update_dyld_shared_cache: warning can't use root '/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/Support/suggestd': file not found
                                          @".*/PrivateFrameworks/CoreSuggestions.framework.*",
                                          // update_dyld_shared_cache: warning can't use root '/usr/libexec/symptomsd': file not found
                                          @".*/libexec/symptomsd.*",
                                          // update_dyld_shared_cache: warning can't use root '/usr/libexec/systemstats_boot': file not found
                                          @".*/libexec/systemstats_boot.*",
                                          // warning, could not bind /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/Bom.framework/Versions/A/Bom because /Volumes/dmg.JCWQr8/System/Library/PrivateFrameworks/AppleFSCompression.framework/Versions/A/AppleFSCompression is missing arch i386
                                          @".*/PrivateFrameworks/AppleFSCompression.framework.*",
                                          // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on /Volumes/dmg.IuuO1f/System/Library/Frameworks/Contacts.framework/Versions/A/Contacts
                                          @".*/Frameworks/Contacts.framework.*",
                                          // warning, could not bind /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSuggestions.framework/Versions/A/CoreSuggestions because realpath() failed on /Volumes/dmg.IuuO1f/System/Library/PrivateFrameworks/CoreSpotlight.framework/Versions/A/CoreSpotlight
                                          @".*/PrivateFrameworks/CoreSpotlight.framework.*",
                                          // update_dyld_shared_cache failed: could not bind symbol _FZAVErrorDomain in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore expected in /System/Library/PrivateFrameworks/IMCore.framework/Versions/A/IMCore in /System/Library/PrivateFrameworks/IMAVCore.framework/Versions/A/IMAVCore
                                          @".*/PrivateFrameworks/IMAVCore.framework.*",
                                          @".*/Resources/GLEngine.bundle.*",
                                          @".*/Resources/GLRendererFloat.bundle.*",
                                          @".*/PrivateFrameworks/GPUCompiler.framework.*",
                                          @".*/PrivateFrameworks/GeForceGLDriver.bundle.*"
                                          ]];
    }
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BaseSystemBinaries.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *baseSystemBinaries = [NSMutableArray arrayWithArray:buildDict[@"BaseSystemBinaries"]];
    
    // Update extraction array
    [self extractItemsFromBaseSystemBinaries:baseSystemBinaries sourceItemsDict:sourceItemsDict];
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*/bin/expect.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addCasperImaging

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Console.app
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addConsole:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Console...");
    
    // ---------------------------------------------------------------------------------
    //  AdditionalEssentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *additionalEssentials = [NSMutableArray arrayWithArray:@[
                                                                            @".*Console.app.*",
                                                                            ]];
    // Update extraction array
    [self extractItemsFromAdditionalEssentials:additionalEssentials sourceItemsDict:sourceItemsDict];
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*ShareKit.framework.*",
                                                                  @".*/Colors/System.clr.*",
                                                                  @".*ViewBridge.framework.*",
                                                                  @".*/Social.framework.*",
                                                                  @".*AccountsDaemon.framework.*",
                                                                  @".*CloudDocs.framework.*"
                                                                  ]];
    if ( 11 <= _sourceVersionMinor ) {
        [essentials addObjectsFromArray:@[
                                          @".*AccountsUI.framework.*",          // For 'ShareKit'
                                          @".*ContactsPersistence.framework.*"  // For 'AddressBook'
                                          ]];
    }
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addConsole

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Desktop Picture
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addDesktopPicture:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Desktop Picture...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    if ( 11 <= _sourceVersionMinor ) {
        NSArray *essentials;
        switch (_sourceVersionMinor) {
            case 11:
                essentials = @[ @".*Library/Desktop\\ Pictures/El\\ Capitan.jpg.*"];
                break;
            default:
                break;
        }
        
        if ( [essentials count] != 0 ) {
            
            // Update extraction array
            [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
        }
        
        // ---------------------------------------------------------------------------------
        //  MediaFiles.pkg
        // ---------------------------------------------------------------------------------
    } else {
        
        NSArray *mediaFiles;
        switch (_sourceVersionMinor) {
            case 10:
                mediaFiles = @[ @".*Library/Desktop\\ Pictures/Yosemite.jpg.*"];
                break;
            case 9:
                mediaFiles = @[ @".*Library/Desktop\\ Pictures/Wave.jpg.*"];
                break;
            case 8:
                mediaFiles = @[ @".*Library/Desktop\\ Pictures/Galaxy.jpg.*"];
                break;
            case 7:
                mediaFiles = @[ @".*Library/Desktop\\ Pictures/Lion.jpg.*"];
                break;
            default:
                break;
        }
        
        if ( [mediaFiles count] != 0 ) {
            
            // Update extraction array
            [self extractItemsFromMediaFiles:mediaFiles sourceItemsDict:sourceItemsDict];
        }
    }
} // addDesktopPicture

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Kerberos
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addKerberos:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Kerberos...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*/users/_krb.*",
                                                                  @".*/LaunchDaemons/com.apple.Kerberos.*",
                                                                  @".*Kerberos.*\\.bundle.*",
                                                                  @".*/ManagedClient.app.*",
                                                                  @".*/DirectoryServer.framework.*",
                                                                  @".*/com.apple.configureLocalKDC.*",
                                                                  @".*/lkdc_acl.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*bin/krb.*",
                                                           @".*/libexec/.*KDC.*",
                                                           @".*sbin/kdcsetup.*",
                                                           @".*sandbox/kdc.sb.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addKerberos

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Kernel
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addKernel:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Kernel...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*/Kernels/.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addKernel

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark libssl
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addLibSsl:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract libssl...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*/lib/libssl.*",
                                                                  @".*/lib/libcrypto.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addLibSsl

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark networkd
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addNetworkd:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract networkd...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*(/|com.apple.)networkd.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addNetworkd

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark ntp
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addNTP:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract ntpdate...");
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*/sbin/ntpdate.*"
                                                           ]];
    
    if ( 11 <= _sourceVersionMinor ) {
        [bsd addObjectsFromArray:@[
                                   @".*/sntp-wrapper.*"
                                   ]];
    }
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addNTP

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSURLStoraged / NSURLSessiond
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addNSURLStoraged:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract nsurlstoraged/nsurlsessiond...");
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*nsurlstoraged.*",
                                                           @".*nsurlsessiond.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    
    // Update extraction array
    [self extractItemsFromEssentials:bsd sourceItemsDict:sourceItemsDict];
} // addNSURLStoraged

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Python
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addPython:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Python...");
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*/[Pp]ython.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addPython

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Ruby
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addRuby:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Ruby...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*[Rr]uby.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    
    // Update extraction array
    [self extractItemsFromBSD:essentials sourceItemsDict:sourceItemsDict];
} // addRuby

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Screen Sharing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addScreenSharing:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract Screen Sharing...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*[Pp]erl.*",
                                                                  @".*/Preferences/com.apple.RemoteManagement.*",
                                                                  @".*/Launch(Agents|Daemons)/com.apple.screensharing.*",
                                                                  @".*/Launch(Agents|Daemons)/com.apple.RemoteDesktop.*",
                                                                  @".*/ScreensharingAgent.bundle.*",
                                                                  @".*/screensharingd.bundle.*",
                                                                  @".*[Oo]pen[Dd]irectory.*",
                                                                  @".*OpenDirectoryConfig.framework.*"
                                                                  ]];
    
    if ( 11 <= _sourceVersionMinor ) {
        [essentials addObjectsFromArray:@[
                                          @".*/AppleVNCServer.bundle.*"
                                          ]];
    }
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addScreenSharing

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark spctl
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addSpctl:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract spctl...");
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*spctl.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addSpctl

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark System Keychain
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addSystemkeychain:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract systemkeychain...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*systemkeychain.*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
    
    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*security-checksystem.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addSystemkeychain

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SystemUIServer
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addSystemUIServer:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract SystemUIServer...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*SystemUIServer.*",
                                                                  @".*MediaControlSender.framework.*",
                                                                  @".*SystemUIPlugin.framework.*",
                                                                  @".*ICANotifications.framework.*",
                                                                  @".*iPod.framework.*",
                                                                  @".*AirPlaySupport.framework.*",
                                                                  @".*CoreUtils.framework.*",
                                                                  @".*TextInput.menu.*",
                                                                  @".*Battery.menu.*",
                                                                  @".*Clock.menu.*"
                                                                  ]];
    
    if ( 11 <= _sourceVersionMinor ) {
        [essentials addObjectsFromArray:@[
                                          @".*AVFoundation.framework.*",
                                          @".*APTransport.framework.*",
                                          @".*WirelessProximity.framework.*"
                                          ]];
    }
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];
} // addSystemUIServer

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark taskgated
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)addTaskgated:(NSMutableDictionary *)sourceItemsDict {
    
    DDLogInfo(@"Adding regexes to extract taskgated...");
    
    // ---------------------------------------------------------------------------------
    //  Essentials.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *essentials = [NSMutableArray arrayWithArray:@[
                                                                  @".*taskgated.*",
                                                                  
                                                                  // For taskgated-helper
                                                                  @".*ConfigurationProfiles.framework.*",
                                                                  @".*UniversalAccess.framework.*",
                                                                  @".*ManagedClient.*",
                                                                  @".*syspolicy.*",
                                                                  
                                                                  // For CoreServicesUIAgent
                                                                  @".*CoreServicesUIAgent.*",
                                                                  @".*coreservices.uiagent.plist.*",
                                                                  @".*XprotectFramework.framework.*",
                                                                  
                                                                  // For Kernel
                                                                  @".*MobileFileIntegrity.plist*"
                                                                  ]];
    
    // Update extraction array
    [self extractItemsFromEssentials:essentials sourceItemsDict:sourceItemsDict];

    // ---------------------------------------------------------------------------------
    //  BSD.pkg
    // ---------------------------------------------------------------------------------
    NSMutableArray *bsd = [NSMutableArray arrayWithArray:@[
                                                           @".*amfid.*",
                                                           @".*syspolicy.*",
                                                           @".*taskgated.*"
                                                           ]];
    
    // Update extraction array
    [self extractItemsFromBSD:bsd sourceItemsDict:sourceItemsDict];
} // addTaskgated

@end
