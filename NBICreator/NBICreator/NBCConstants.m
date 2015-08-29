//
//  NBCConstants.m
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCConstants.h"

////////////////////////////////////////////////////////////////////////////////
#pragma mark Application
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCBundleIdentifier = @"com.github.NBICreator";
NSString *const NBCBundleIdentifierHelper = @"com.github.NBICreatorHelper";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Workflow Types
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCWorkflowTypeNetInstall = @"NetInstall";
NSString *const NBCWorkflowTypeDeployStudio = @"DeployStudio";
NSString *const NBCWorkflowTypeImagr = @"Imagr";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Folders
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCFolderTemplatesNetInstall = @"NBICreator/Templates/NetInstall";
NSString *const NBCFolderTemplatesDeployStudio = @"NBICreator/Templates/DeployStudio";
NSString *const NBCFolderTemplatesImagr = @"NBICreator/Templates/Imagr";
NSString *const NBCFolderTemplatesCasper = @"NBICreator/Templates/Casper";
NSString *const NBCFolderTemplatesCustom = @"NBICreator/Templates/Custom";
NSString *const NBCFolderTemplatesDisabled = @"NBICreator/Templates/Disabled";
NSString *const NBCFolderResources = @"com.github.NBICreator/Resources";
NSString *const NBCFolderResourcesDeployStudio = @"com.github.NBICreator/Resources/DeployStudio";;
NSString *const NBCFolderResourcesPython = @"com.github.NBICreator/Resources/Python";
NSString *const NBCFolderResourcesImagr = @"com.github.NBICreator/Resources/Imagr";
NSString *const NBCFolderResourcesSource = @"com.github.NBICreator/Resources/Source";

////////////////////////////////////////////////////////////////////////////////
#pragma mark File Names
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCFileNameResourcesDict = @"Resources.plist";
NSString *const NBCFileNameDownloadsDict = @"Downloads.plist";
NSString *const NBCFileNameNetInstallDefaults = @"NetInstallDefaults";
NSString *const NBCFileNameDeployStudioDefaults = @"DeployStudioDefaults";
NSString *const NBCFileNameImagrDefaults = @"ImagrDefaults";

////////////////////////////////////////////////////////////////////////////////
#pragma mark File Paths
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCFilePathNBIIconImagr = @"%APPLICATIONRESOURCESURL%/IconImagr.icns";
NSString *const NBCFilePathNBIIconNetInstall = @"%APPLICATIONRESOURCESURL%/IconNetBootNBI.icns";
NSString *const NBCFilePathNBIIconDeployStudio = @"%APPLICATIONRESOURCESURL%/IconDeployStudioNBI.icns";
NSString *const NBCFilePathPreferencesGlobal = @"/Library/Preferences/.GlobalPreferences.plist";
NSString *const NBCFilePathPreferencesHIToolbox = @"/Library/Preferences/com.apple.HIToolbox.plist";

////////////////////////////////////////////////////////////////////////////////
#pragma mark User Defaults
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCUserDefaultsIndexCounter = @"NetBootIndexCounter";
NSString *const NBCUserDefaultsNetBootSelection = @"NetBootSelection";
NSString *const NBCUserDefaultsDateFormatString = @"DateFormatString";
NSString *const NBCUserDefaultsLogLevel = @"LogLevel";
NSString *const NBCUserDefaultsCheckForUpdates = @"CheckForUpdates";
NSString *const NBCUserDefaultsUserNotificationsEnabled = @"UserNotificationsEnabled";
NSString *const NBCUserDefaultsUserNotificationsSoundEnabled = @"UserNotificationsSoundEnabled";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Menu Items
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCMenuItemUntitled = @"Untitled";
NSString *const NBCMenuItemNew = @"New";
NSString *const NBCMenuItemSave = @"Save...";
NSString *const NBCMenuItemSaveAs = @"Save As...";
NSString *const NBCMenuItemExport = @"Export...";
NSString *const NBCMenuItemRename = @"Rename...";
NSString *const NBCMenuItemDelete = @"Delete";
NSString *const NBCMenuItemShowInFinder = @"Show in Finder...";
NSString *const NBCMenuItemImagrVersionLatest = @"Latest Release";
NSString *const NBCMenuItemImagrVersionLocal = @"Local Version...";
NSString *const NBCMenuItemDeployStudioVersionLatest = @"Latest Release";
NSString *const NBCMenuItemRestoreOriginalIcon = @"Restore Original Icon";
NSString *const NBCMenuItemRestoreOriginalBackground = @"Restore Original Background";
NSString *const NBCMenuItemNoSelection = @"No Selection";
NSString *const NBCMenuItemNBICreator = @"NBICreator";
NSString *const NBCMenuItemSystemImageUtility = @"System Image Utility";
NSString *const NBCMenuItemCurrent = @"Current";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Template Values - Main
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSettingsFileVersion = @"1.0";
NSString *const NBCSettingsTypeNetInstall = @"NetInstall";
NSString *const NBCSettingsTypeDeployStudio = @"DeployStudio";
NSString *const NBCSettingsTypeImagr = @"Imagr";
NSString *const NBCSettingsTypeCasper = @"Casper";
NSString *const NBCSettingsTypeCustom = @"Custom";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Template Keys - Main
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSettingsTitleKey = @"Title";
NSString *const NBCSettingsTypeKey = @"Type";
NSString *const NBCSettingsVersionKey = @"Version";
NSString *const NBCSettingsSettingsKey = @"Settings";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Template Keys - General
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSettingsNameKey = @"Name";
NSString *const NBCSettingsIndexKey = @"Index";
NSString *const NBCSettingsProtocolKey = @"Protocol";
NSString *const NBCSettingsEnabledKey = @"Enabled";
NSString *const NBCSettingsDefaultKey = @"Default";
NSString *const NBCSettingsLanguageKey = @"Language";
NSString *const NBCSettingsTimeZoneKey = @"TimeZone";
NSString *const NBCSettingsKeyboardLayoutKey = @"KeyboardLayout";
NSString *const NBCSettingsDescriptionKey = @"Description";
NSString *const NBCSettingsDestinationFolderKey = @"DestinationFolder";
NSString *const NBCSettingsIconKey = @"Icon";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Template Keys - Options
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSettingsDisableWiFiKey = @"DisableWiFi";
NSString *const NBCSettingsDisableBluetoothKey = @"DisableBluetooth";
NSString *const NBCSettingsDisplaySleepKey = @"DisplaySleep";
NSString *const NBCSettingsDisplaySleepMinutesKey = @"DisplaySleepMinutes";
NSString *const NBCSettingsIncludeSystemUIServerKey = @"IncludeSystemUIServer";
NSString *const NBCSettingsUseVerboseBootKey = @"UseVerboseBoot";
NSString *const NBCSettingsARDLoginKey = @"ARDLogin";
NSString *const NBCSettingsARDPasswordKey = @"ARDPassword";
NSString *const NBCSettingsUseNetworkTimeServerKey = @"UseNetworkTimeServer";
NSString *const NBCSettingsNetworkTimeServerKey = @"NetworkTimeServer";

////////////////////////////////////////////////////////////////////////////////
#pragma mark Template Keys - Extra
////////////////////////////////////////////////////////////////////////////////
NSString *const NBCSettingsCertificatesKey = @"Certificates";
NSString *const NBCSettingsPackagesKey = @"Packages";






NSString *const NBCSettingsError = @"Error";
NSString *const NBCSettingsWarning = @"Warning";
NSString *const NBCSettingsSourceItemsKey = @"SourceItems";
NSString *const NBCSettingsSourceItemsPathKey = @"Path";
NSString *const NBCSettingsSourceItemsRegexKey = @"Regex";
NSString *const NBCSettingsSourceItemsCacheFolderKey = @"CacheFolder";


NSString *const NBCSettingsNBIKeyboardLayout = @"KeyboardLayout";




NSString *const NBCSettingsNBICreationToolKey = @"NBICreationTool";











// --------------------------------------------------------------
//  Template Settings Imagr
// --------------------------------------------------------------
NSString *const NBCSettingsImagrVersion = @"ImagrVersion";
NSString *const NBCSettingsImagrIncludePreReleaseVersions = @"ImagrIncludePreReleaseVersions";
NSString *const NBCSettingsImagrConfigurationURL = @"ImagrConfigurationURL";
NSString *const NBCSettingsImagrReportingURL = @"ImagrReportingURL";
NSString *const NBCSettingsImagrServerURLKey = @"serverurl";
NSString *const NBCSettingsImagrDownloadURL = @"ImagrDownloadURL";
NSString *const NBCSettingsImagrDownloadPython = @"ImagrDownloadPython";
NSString *const NBCSettingsImagrUseLocalVersion = @"ImagrUseLocalVersion";
NSString *const NBCSettingsImagrLocalVersionPath = @"ImagrLocalVersionPath";
NSString *const NBCSettingsImagrSourceIsNBI = @"IsNBI";
NSString *const NBCSettingsImagrDisableATS = @"ImagrDisableATS";
NSString *const NBCSettingsImagrVersionLatest = @"ImagrVersionLatest";

// --------------------------------------------------------------
//  Template Settings DeployStudio
// --------------------------------------------------------------
NSString *const NBCSettingsDeployStudioTimeServerKey = @"NetworkTimeServer";
NSString *const NBCSettingsDeployStudioUseCustomServersKey = @"UseCustomServers";
NSString *const NBCSettingsDeployStudioServerURL1Key = @"ServerURL1";
NSString *const NBCSettingsDeployStudioServerURL2Key = @"ServerURL2";
NSString *const NBCSettingsDeployStudioDisableVersionMismatchAlertsKey = @"DisableVersionMismatchAlerts";
NSString *const NBCSettingsDeployStudioRuntimeLoginKey = @"RuntimeLogin";
NSString *const NBCSettingsDeployStudioRuntimePasswordKey = @"RuntimePassword";
NSString *const NBCSettingsDeployStudioDisplayLogWindowKey = @"DisplayLogWindow";
NSString *const NBCSettingsDeployStudioSleepKey = @"Sleep";
NSString *const NBCSettingsDeployStudioSleepDelayKey = @"SleepDelay";
NSString *const NBCSettingsDeployStudioRebootKey = @"Reboot";
NSString *const NBCSettingsDeployStudioRebootDelayKey = @"RebootDelay";
NSString *const NBCSettingsDeployStudioIncludePythonKey = @"IncludePython";
NSString *const NBCSettingsDeployStudioIncludeRubyKey = @"IncludeRuby";
NSString *const NBCSettingsDeployStudioUseCustomTCPStackKey = @"UseCustomTCPStack";
NSString *const NBCSettingsDeployStudioDisableWirelessSupportKey = @"DisableWirelessSupport";
NSString *const NBCSettingsDeployStudioUseSMB1Key = @"UseSMB1";
NSString *const NBCSettingsDeployStudioUseCustomRuntimeTitleKey = @"UseCustomRuntimeTitle";
NSString *const NBCSettingsDeployStudioRuntimeTitleKey = @"RuntimeTitle";


NSString *const NBCSettingsUseBackgroundImageKey = @"UseBackgroundImage";
NSString *const NBCSettingsBackgroundImageKey = @"BackgroundImage";

// --------------------------------------------------------------
//  Template Settings Python
// --------------------------------------------------------------
NSString *const NBCSettingsPythonVersion = @"PythonVersion";
NSString *const NBCSettingsPythonDownloadURL = @"PythonDownloadURL";
NSString *const NBCSettingsPythonDefaultVersion = @"2.7.6";

// --------------------------------------------------------------
//  NBImageInfo
// --------------------------------------------------------------
NSString *const NBCNBImageInfoDictNameKey = @"Name";
NSString *const NBCNBImageInfoDictDescriptionKey = @"Description";
NSString *const NBCNBImageInfoDictIndexKey = @"Index";
NSString *const NBCNBImageInfoDictIsDefaultKey = @"IsDefault";
NSString *const NBCNBImageInfoDictIsEnabledKey = @"IsEnabled";
NSString *const NBCNBImageInfoDictLanguageKey = @"Language";
NSString *const NBCNBImageInfoDictProtocolKey = @"Type";


NSString *const NBCSettingsLocale = @"NBCSettingsLocale";
NSString *const NBCSettingsCountry = @"NBCSettingsCountry";


// --------------------------------------------------------------
//  Notifications
// --------------------------------------------------------------

// Workflows
NSString *const NBCNotificationAddWorkflowItemToQueue = @"addWorkflowItemToQueue";
NSString *const NBCNotificationWorkflowCompleteNBI = @"workflowCompleteNBI";
NSString *const NBCNotificationWorkflowCompleteResources = @"workflowCompleteResources";
NSString *const NBCNotificationWorkflowCompleteModifyNBI = @"workflowCompleteModifyNBI";
NSString *const NBCNotificationWorkflowFailed = @"workflowFailed";

NSString *const NBCUserInfoNSErrorKey = @"NSError";

// Workflows UserInfoKeys
NSString *const NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem = @"WorkflowItem";
NSString *const NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem = @"RemoveWorkflowItem";

// Imagr
NSString *const NBCNotificationImagrUpdateSource = @"imagrUpdateSource";
NSString *const NBCNotificationImagrRemovedSource = @"imagrRemovedSource";
NSString *const NBCNotificationImagrUpdateNBIIcon = @"imagrUpdateNBIIcon";
NSString *const NBCNotificationImagrUpdateNBIBackground = @"imagrUpdateNBIBackground";
NSString *const NBCNotificationImagrVerifyDroppedSource = @"imagrVerifyDroppedSource";

// DeployStudio
NSString *const NBCNotificationDeployStudioUpdateSource = @"deployStudioUpdateSource";
NSString *const NBCNotificationDeployStudioRemovedSource = @"deployStudioRemovedSource";
NSString *const NBCNotificationDeployStudioUpdateNBIIcon = @"deployStudioUpdateNBIIcon";
NSString *const NBCNotificationDeployStudioUpdateNBIBackground = @"deployStudioUpdateNBIBackground";
NSString *const NBCNotificationDeployStudioAddBonjourService = @"deployStudioAddBonjourService";
NSString *const NBCNotificationDeployStudioRemoveBonjourService = @"deployStudioRemoveBonjourService";
NSString *const NBCNotificationDeployStudioVerifyDroppedSource = @"deployStudioVerifyDroppedSource";

// NetInstall
NSString *const NBCNotificationNetInstallUpdateSource = @"netInstallUpdateSource";
NSString *const NBCNotificationNetInstallRemovedSource = @"netInstallRemovedSource";
NSString *const NBCNotificationNetInstallUpdateNBIIcon = @"netInstallUpdateNBIIcon";
NSString *const NBCNotificationNetInstallVerifyDroppedSource = @"netInstallVerifyDroppedSource";

// Imagr / DeployStudio / NetInstall UserInfoKeys
NSString *const NBCNotificationVerifyDroppedSourceUserInfoSourceURL = @"SourceURL";

// Update Button Build
NSString *const NBCNotificationUpdateButtonBuild = @"UpdateButtonBuild";

// Update Button Build UserInfoKeys
NSString *const NBCNotificationUpdateButtonBuildUserInfoButtonState = @"ButtonState";

// Update Source UserInfoKeys
NSString *const NBCNotificationUpdateSourceUserInfoSource = @"Source";
NSString *const NBCNotificationUpdateSourceUserInfoTarget = @"Target";

// Update NBI Icon UserInfoKeys
NSString *const NBCNotificationUpdateNBIIconUserInfoIconURL = @"IconURL";

// Update NBI Background UserInfoKeys
NSString *const NBCNotificationUpdateNBIBackgroundUserInfoIconURL = @"BackgroundURL";


NSString *const NBCNotificationStartSearchingForUpdates = @"StartSearchingForUpdates";
NSString *const NBCNotificationStopSearchingForUpdates = @"StopSearchingForUpdates";


// --------------------------------------------------------------
//  Certificate TableView Keys
// --------------------------------------------------------------
NSString *const NBCDictionaryKeyCertificate = @"Certificate";
NSString *const NBCDictionaryKeyCertificateURL = @"CertificateURL";
NSString *const NBCDictionaryKeyCertificateName = @"CertificateName";
NSString *const NBCDictionaryKeyCertificateIcon = @"CertificateIcon";
NSString *const NBCDictionaryKeyCertificateAuthority = @"CertificateAuthority";
NSString *const NBCDictionaryKeyCertificateSignature = @"CertificateSignature";
NSString *const NBCDictionaryKeyCertificateSelfSigned = @"CertificateSelfSigned";
NSString *const NBCDictionaryKeyCertificateSerialNumber = @"CertificateSerialNumber";
NSString *const NBCDictionaryKeyCertificateNotValidBeforeDate = @"CertificateNotValidBeforeDate";
NSString *const NBCDictionaryKeyCertificateNotValidAfterDate = @"CertificateNotValidAfterDate";
NSString *const NBCDictionaryKeyCertificateExpirationString = @"CertificateExpirationString";
NSString *const NBCDictionaryKeyCertificateExpired = @"CertificateExpired";

NSString *const NBCDictionaryKeyPackagePath = @"PackagePath";
NSString *const NBCDictionaryKeyPackageName = @"PackageName";

// --------------------------------------------------------------
//  Imagr
// --------------------------------------------------------------
NSString *const NBCImagrApplicationURL = @"IMApplicationURL";
NSString *const NBCImagrConfigurationPlistURL = @"IMConfigurationPlistURL";
NSString *const NBCImagrRCImagingURL = @"IMRCImagingURL";

// --------------------------------------------------------------
//  System Image Utility
// --------------------------------------------------------------
NSString *const NBCSystemImageUtilityScriptCreateCommon = @"CreateCommon";
NSString *const NBCSystemImageUtilityScriptCreateNetBoot = @"CreateNetBoot";
NSString *const NBCSystemImageUtilityScriptCreateNetInstall = @"CreateNetInstall";
NSString *const NBCSystemImageUtilityNetBootImageSize = @"7000";

// --------------------------------------------------------------
//  Source
// --------------------------------------------------------------
NSString *const NBCSourceTypeInstallESD = @"InstallESD";
NSString *const NBCSourceTypeOSXInstaller = @"OSXInstaller";

// --------------------------------------------------------------
//  Target
// --------------------------------------------------------------

// --------------------------------------------------------------
//  Alerts
// --------------------------------------------------------------
NSString *const NBCAlertTagKey = @"AlertTag";
NSString *const NBCAlertTagDeleteTemplate = @"DeleteTemplate";
NSString *const NBCAlertTagSettingsWarning = @"SettingsWarning";
NSString *const NBCAlertTagSettingsUnsaved = @"SettingsUnsaved";
NSString *const NBCAlertTagSettingsUnsavedQuit = @"SettingsUnsavedQuit";
NSString *const NBCAlertTagSettingsUnsavedBuild = @"SettingsUnsavedBuild";
NSString *const NBCAlertWorkflowItemKey = @"WorkflowItem";
NSString *const NBCAlertTagWorkflowRunningQuit = @"WorkflowRunningQuit";

NSString *const NBCAlertUserInfoSelectedTemplate = @"SelectedTemplate";
NSString *const NBCAlertUserInfoTemplateURL = @"TemplateURL";
NSString *const NBCAlertUserInfoBuildNBI = @"BuildNBI";


// --------------------------------------------------------------
//  Buttons
// --------------------------------------------------------------
NSString *const NBCButtonTitleCancel = @"Cancel";
NSString *const NBCButtonTitleContinue = @"Continue";
NSString *const NBCButtonTitleOK = @"OK";
NSString *const NBCButtonTitleSave = @"Save";
NSString *const NBCButtonTitleQuit = @"Quit";

// --------------------------------------------------------------
//  DeployStudio
// --------------------------------------------------------------
NSString *const NBCDeployStudioTabTitleRuntime = @"Runtime";
NSString *const NBCDeployStudioBackgroundDefaultPath = @"%DSADMINURL%/Contents/Applications/DeployStudio Assistant.app/Contents/Resources/sysBuilder/common/DefaultDesktop.jpg";
NSString *const NBCDeployStudioBackgroundImageDefaultPath = @"%SOURCEURL%/System/Library/CoreServices/DefaultDesktop.jpg";
NSString *const NBCDeployStudioRepository = @"http://www.deploystudio.com/Downloads";

NSString *const NBCBackgroundImageDefaultPath = @"%SOURCEURL%/System/Library/CoreServices/DefaultDesktop.jpg";

// --------------------------------------------------------------
//  Imagr
// --------------------------------------------------------------
NSString *const NBCImagrBundleIdentifier = @"com.grahamgilbert.Imagr";
NSString *const NBCImagrApplicationTargetURL = @"Packages/Imagr.app";
NSString *const NBCImagrApplicationNBICreatorTargetURL = @"Applications/Imagr.app";
NSString *const NBCImagrConfigurationPlistTargetURL = @"Packages/com.grahamgilbert.Imagr.plist";
NSString *const NBCImagrConfigurationPlistNBICreatorTargetURL = @"Library/Preferences/com.grahamgilbert.Imagr.plist";
NSString *const NBCImagrRCImagingTargetURL = @"Packages/Extras/rc.imaging";
NSString *const NBCImagrRCImagingNBICreatorTargetURL = @"etc/rc.imaging";
NSString *const NBCImagrRCInstallTargetURL = @"etc/rc.install";
NSString *const NBCImagrGitHubRepository = @"grahamgilbert/imagr";

NSString *const NBCNBICreatorGitHubRepository = @"NBICreator/NBICreator";
NSString *const NBCNBICreatorResourcesGitHubRepository = @"NBICreator/NBICreatorResources";

// --------------------------------------------------------------
//  NBCDownloader
// --------------------------------------------------------------
NSString *const NBCDownloaderTag = @"Tag";
NSString *const NBCDownloaderTagPython = @"NBCDownloaderTagPython";
NSString *const NBCDownloaderTagImagr = @"NBCDownloaderTagImagr";
NSString *const NBCDownloaderTagDeployStudio = @"NBCDownloaderTagDeployStudio";
NSString *const NBCDownloaderTagNBICreator = @"NBCDownloaderTagNBICreator";
NSString *const NBCDownloaderTagNBICreatorResources = @"NBCDownloaderTagNBICreatorResources";
NSString *const NBCDownloaderVersion = @"Version";

// --------------------------------------------------------------
//  Workflow Copy
// --------------------------------------------------------------
NSString *const NBCWorkflowCopyType = @"workflowCopyType";
NSString *const NBCWorkflowCopy = @"workflowCopy";
NSString *const NBCWorkflowCopySourceURL = @"workflowCopySourceURL";
NSString *const NBCWorkflowCopyTargetURL = @"workflowCopyTargetURL";
NSString *const NBCWorkflowCopyAttributes = @"workflowCopyAttributes";
NSString *const NBCWorkflowCopyRegex = @"workflowCopyRegex";
NSString *const NBCWorkflowCopyRegexSourceFolderURL = @"workflowCopyRegexSourceFolderURL";
NSString *const NBCWorkflowCopyRegexTargetFolderURL = @"workflowCopyRegexTargetFolderURL";

// --------------------------------------------------------------
//  Workflow Modify
// --------------------------------------------------------------
NSString *const NBCWorkflowModify = @"workflowModify";
NSString *const NBCWorkflowModifyAttributes = @"workflowModifyAttributes";
NSString *const NBCWorkflowModifyTargetURL = @"workflowModifyTargetURL";
NSString *const NBCWorkflowModifySourceURL = @"workflowModifySourceURL";
NSString *const NBCWorkflowModifyContent = @"workflowModifyContent";
NSString *const NBCWorkflowModifyFileType = @"workflowModifyFileType";
NSString *const NBCWorkflowModifyFileTypePlist = @"workflowModifyFileTypePlist";
NSString *const NBCWorkflowModifyFileTypeGeneric = @"workflowModifyFileTypeGeneric";
NSString *const NBCWorkflowModifyFileTypeFolder = @"workflowModifyFileTypeFolder";
NSString *const NBCWorkflowModifyFileTypeDelete = @"workflowModifyFileTypeDelete";
NSString *const NBCWorkflowModifyFileTypeLink = @"workflowModifyFileTypeLink";
NSString *const NBCWorkflowModifyFileTypeMove = @"workflowModifyFileTypeMove";

// --------------------------------------------------------------
//  Workflow Install
// --------------------------------------------------------------
NSString *const NBCWorkflowInstall = @"workflowInstall";
NSString *const NBCWorkflowInstallerName = @"workflowInstallerName";
NSString *const NBCWorkflowInstallerSourceURL = @"workflowInstallerSourceURL";
NSString *const NBCWorkflowInstallerChoiceChangeXML = @"workflowInstallerChoiceChangeXMLL";

// --------------------------------------------------------------
//  Workflow Types
// --------------------------------------------------------------
NSString *const NBCWorkflowNBI = @"workflowNBI";
NSString *const NBCWorkflowNBIResources = @"workflowNBIResources";
NSString *const NBCWorkflowNBIModify = @"workflowNBIModify";

// --------------------------------------------------------------
//  Python
// --------------------------------------------------------------
NSString *const NBCPythonRepositoryURL = @"https://www.python.org/downloads/mac-osx/";
NSString *const NBCPythonInstallerPathInDiskImage = @"Python.mpkg";

NSString *const NBCNetworkTimeServerDefault = @"time.euro.apple.com";

NSString *const NBCCertificatesNBICreatorTargetURL = @"usr/local/certificates";
NSString *const NBCCertificatesTargetURL = @"Packages/Certificates";
NSString *const NBCScriptsNBICreatorTargetPath = @"usr/local/scripts";
NSString *const NBCScriptsTargetPath = @"Packages/Scripts";
NSString *const NBCApplicationsTargetPath = @"Applications";

NSString *const NBCErrorDomain = @"com.gihub.NBICreator.ErrorDomain";
NSString *const NBCWorkflowNetInstallLogPrefix = @"_progress";

NSString *const NBCTargetFolderMinFreeSizeInGB = @"10";

NSString *const NBCNBIDescriptionSIU = @"Created with System Image Utility version %SIUVERSION%";
NSString *const NBCNBIDescriptionNBC = @"Created with NBICreator version %NBCVERSION%";

NSString *const NBCDiskDeviceModelDiskImage = @"Disk Image";

NSString *const NBCBonjourServiceDeployStudio = @"_deploystudio._tcp.";
NSString *const NBCDeployStudioLatestVersionURL = @"http://www.deploystudio.com/Downloads/_dss.current";

NSString *const NBCResourcesDeployStudioLatestVersionKey = @"LatestVersion";

NSString *const NBCHelpURL = @"https://github.com/NBICreator/NBICreator/wiki";

NSString *const NBCVariableIndexCounter = @"%COUNTER%";

NSString *const NBCTableViewIdentifierCertificates = @"tableViewCertificates";
NSString *const NBCTableViewIdentifierPackages = @"tableViewPackages";



