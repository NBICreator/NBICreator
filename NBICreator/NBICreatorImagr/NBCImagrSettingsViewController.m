//
//  NBCIMSettingsViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-29.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Carbon/Carbon.h>
#import "NBCImagrSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"

#import "NBCWorkflowItem.h"
#import "NBCSettingsController.h"
#import "NBCSourceController.h"
#import "NBCController.h"

#import "NBCImagrWorkflowNBI.h"
#import "NBCImagrWorkflowResources.h"
#import "NBCImagrWorkflowModifyNBI.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

#import "Reachability.h"
#import "NBCLogging.h"
#import "NBCCertificateTableCellView.h"
#import "NBCPackageTableCellView.h"
#import "NBCImagrTrustedNetBootServerCellView.h"
#import "NBCDesktopEntity.h"
#import "NSString+validIP.h"
#import "NBCImagrRAMDiskPathCellView.h"
#import "NBCImagrRAMDiskSizeCellView.h"
#import "NBCOverlayViewController.h"
#import "NBCXcodeSource.h"
#import "NSString+SymlinksAndAliases.h"
#import "NBCDiskImageController.h"
#import "NBCWorkflowModifyNBI.h"
#import "NBCWorkflowResources.h"

DDLogLevel ddLogLevel;

@interface NBCImagrSettingsViewController () {
    Reachability *_internetReachableFoo;
}

@end

@implementation NBCImagrSettingsViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCImagrSettingsViewController" bundle:nil];
    if (self != nil) {
        _templates = [[NBCTemplatesController alloc] initWithSettingsViewController:self templateType:NBCSettingsTypeImagr delegate:self];
    }
    return self;
} // init

- (void)awakeFromNib {
    [_tableViewCertificates registerForDraggedTypes:@[ NSURLPboardType ]];
    [_tableViewPackages registerForDraggedTypes:@[ NSURLPboardType ]];
} // awakeFromNib

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
} // dealloc

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _keyboardLayoutDict = [[NSMutableDictionary alloc] init];
    _certificateTableViewContents = [[NSMutableArray alloc] init];
    _packagesTableViewContents = [[NSMutableArray alloc] init];
    _trustedServers = [[NSMutableArray alloc] init];
    _ramDisks = [[NSMutableArray alloc] init];
    
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateSource:) name:NBCNotificationImagrUpdateSource object:nil];
    [nc addObserver:self selector:@selector(removedSource:) name:NBCNotificationImagrRemovedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIIcon:) name:NBCNotificationImagrUpdateNBIIcon object:nil];
    [nc addObserver:self selector:@selector(updateNBIBackground:) name:NBCNotificationImagrUpdateNBIBackground object:nil];
    [nc addObserver:self selector:@selector(editingDidEnd:) name:NSControlTextDidEndEditingNotification object:nil];
    
    // --------------------------------------------------------------
    //  Add KVO Observers
    // --------------------------------------------------------------
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:NBCUserDefaultsIndexCounter options:NSKeyValueObservingOptionNew context:nil];
    
    // --------------------------------------------------------------
    //  Initialize Properties
    // --------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *userApplicationSupport = [fm URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    if ( userApplicationSupport ) {
        _templatesFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesImagr isDirectory:YES];
    } else {
        DDLogError(@"[ERROR]: %@", [error localizedDescription]);
        // Should display error dialog
    }
    
    _siuSource = [[NBCSystemImageUtilitySource alloc] init];
    _templatesDict = [[NSMutableDictionary alloc] init];
    [self setShowARDPassword:NO];
    [self initializeTableViewOverlays];
    [self checkIfXcodeIsInstalled];
    
    // --------------------------------------------------------------
    //  Test Internet Connectivity
    // --------------------------------------------------------------
    [self testInternetConnection];
    
    [self populatePopUpButtonTimeZone];
    [self populatePopUpButtonLanguage];
    [self populatePopUpButtonKeyboardLayout];
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI Icon image view to allow to restore original icon.
    // ------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *restoreView = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalIcon action:@selector(restoreNBIIcon:) keyEquivalent:@""];
    [restoreView setTarget:self];
    [menu addItem:restoreView];
    [_imageViewIcon setMenu:menu];
    
    // --------------------------------------------------------------
    //  Load saved templates and create the template menu
    // --------------------------------------------------------------
    [self updatePopUpButtonTemplates];
    
    // ------------------------------------------------------------------------------------------
    //  Add contextual menu to NBI background image view to allow to restore original background.
    // ------------------------------------------------------------------------------------------
    NSMenu *backgroundImageMenu = [[NSMenu alloc] init];
    NSMenuItem *restoreViewBackground = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalBackground action:@selector(restoreNBIBackground:) keyEquivalent:@""];
    [backgroundImageMenu addItem:restoreViewBackground];
    [_imageViewBackgroundImage setMenu:backgroundImageMenu];
    
    // -------------------------------------------------------------------------------
    //
    // -------------------------------------------------------------------------------
    [self updateSettingVisibility];
    
    // -------------------------------------------------------------------------------
    //  Verify build button so It's not enabled by mistake
    // -------------------------------------------------------------------------------
    [self verifyBuildButton];
    
} // viewDidLoad

- (void)initializeTableViewOverlays {
    if ( ! _viewOverlayPackages ) {
        NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypePackages];
        _viewOverlayPackages = [vc view];
    }
    [self addOverlayViewToView:_superViewPackages overlayView:_viewOverlayPackages];
    
    if ( ! _viewOverlayCertificates ) {
        NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypeCertificates];
        _viewOverlayCertificates = [vc view];
    }
    [self addOverlayViewToView:_superViewCertificates overlayView:_viewOverlayCertificates];
} // initializeTableViewOverlays

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSTableView DataSource Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
        return (NSInteger)[_certificateTableViewContents count];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        return (NSInteger)[_packagesTableViewContents count];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierImagrTrustedServers] ) {
        return (NSInteger)[_trustedServers count];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierImagrRAMDisks] ) {
        return (NSInteger)[_ramDisks count];
    } else {
        return 0;
    }
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
#pragma unused(row)
    if ( dropOperation == NSTableViewDropAbove ) {
        if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
            if ( [self containsAcceptableCertificateURLsFromPasteboard:[info draggingPasteboard]] ) {
                [info setAnimatesToDestination:YES];
                return NSDragOperationCopy;
            }
        } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
            if ( [self containsAcceptablePackageURLsFromPasteboard:[info draggingPasteboard]] ) {
                [info setAnimatesToDestination:YES];
                return NSDragOperationCopy;
            }
        }
    }
    return NSDragOperationNone;
}

- (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
        NSArray *classes = @[ [NBCDesktopCertificateEntity class], [NSPasteboardItem class] ];
        __block NBCCertificateTableCellView *certCellView = [tableView makeViewWithIdentifier:@"CertificateCellView" owner:self];
        __block NSInteger validCount = 0;
        [draggingInfo enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                             usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                                 if ( [[draggingItem item] isKindOfClass:[NBCDesktopCertificateEntity class]] ) {
                                                     NBCDesktopCertificateEntity *entity = (NBCDesktopCertificateEntity *)[draggingItem item];
                                                     [draggingItem setDraggingFrame:[certCellView frame]];
                                                     [draggingItem setImageComponentsProvider:^NSArray * {
                                                         if ( [entity isKindOfClass:[NBCDesktopCertificateEntity class]] ) {
                                                             NSData *certificateData = [entity certificate];
                                                             NSDictionary *certificateDict = [self examineCertificate:certificateData];
                                                             if ( [certificateDict count] != 0 ) {
                                                                 certCellView = [self populateCertificateCellView:certCellView certificateDict:certificateDict];
                                                             }
                                                         }
                                                         [[certCellView textFieldCertificateName] setStringValue:[entity name]];
                                                         return [certCellView draggingImageComponents];
                                                     }];
                                                     validCount++;
                                                 } else {
                                                     [draggingItem setImageComponentsProvider:nil];
                                                 }
                                             }];
        [draggingInfo setNumberOfValidItemsForDrop:validCount];
        [draggingInfo setDraggingFormation:NSDraggingFormationList];
        
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        NSArray *classes = @[ [NBCDesktopPackageEntity class], [NSPasteboardItem class] ];
        __block NBCPackageTableCellView *packageCellView = [tableView makeViewWithIdentifier:@"PackageCellView" owner:self];
        __block NSInteger validCount = 0;
        [draggingInfo enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                             usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                                 if ( [[draggingItem item] isKindOfClass:[NBCDesktopPackageEntity class]] ) {
                                                     NBCDesktopPackageEntity *entity = (NBCDesktopPackageEntity *)[draggingItem item];
                                                     [draggingItem setDraggingFrame:[packageCellView frame]];
                                                     [draggingItem setImageComponentsProvider:^NSArray * {
                                                         if ( [entity isKindOfClass:[NBCDesktopPackageEntity class]] ) {
                                                             NSDictionary *packageDict = [self examinePackageAtURL:[entity fileURL]];
                                                             if ( [packageDict count] != 0 ) {
                                                                 packageCellView = [self populatePackageCellView:packageCellView packageDict:packageDict];
                                                             }
                                                         }
                                                         [[packageCellView textFieldPackageName] setStringValue:[entity name]];
                                                         return [packageCellView draggingImageComponents];
                                                     }];
                                                     validCount++;
                                                 } else {
                                                     [draggingItem setImageComponentsProvider:nil];
                                                 }
                                             }];
        [draggingInfo setNumberOfValidItemsForDrop:validCount];
        [draggingInfo setDraggingFormation:NSDraggingFormationList];
    }
}

- (void)insertCertificatesInTableView:(NSTableView *)tableView draggingInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[ [NBCDesktopCertificateEntity class] ];
    __block NSInteger insertionIndex = row;
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                 usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                     NBCDesktopCertificateEntity *entity = (NBCDesktopCertificateEntity *)[draggingItem item];
                                     if ( [entity isKindOfClass:[NBCDesktopCertificateEntity class]] ) {
                                         NSData *certificateData = [entity certificate];
                                         NSDictionary *certificateDict = [self examineCertificate:certificateData];
                                         if ( [certificateDict count] != 0 ) {
                                             
                                             for ( NSDictionary *certDict in self->_certificateTableViewContents ) {
                                                 if ( [certificateDict[NBCDictionaryKeyCertificateSignature] isEqualToData:certDict[NBCDictionaryKeyCertificateSignature]] ) {
                                                     if ( [certificateDict[NBCDictionaryKeyCertificateSerialNumber] isEqualToString:certDict[NBCDictionaryKeyCertificateSerialNumber]] ) {
                                                         DDLogWarn(@"Certificate %@ is already added!", certificateDict[NBCDictionaryKeyCertificateName]);
                                                         return;
                                                     }
                                                 }
                                             }
                                             
                                             [self->_certificateTableViewContents insertObject:certificateDict atIndex:(NSUInteger)insertionIndex];
                                             [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
                                             [draggingItem setDraggingFrame:[tableView frameOfCellAtColumn:0 row:insertionIndex]];
                                             insertionIndex++;
                                             [self->_viewOverlayCertificates setHidden:YES];
                                         }
                                     }
                                 }];
}

- (void)insertPackagesInTableView:(NSTableView *)tableView draggingInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[ [NBCDesktopPackageEntity class] ];
    __block NSInteger insertionIndex = row;
    [info enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:@{}
                                 usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                                     NBCDesktopPackageEntity *entity = (NBCDesktopPackageEntity *)[draggingItem item];
                                     if ( [entity isKindOfClass:[NBCDesktopPackageEntity class]] ) {
                                         NSDictionary *packageDict = [self examinePackageAtURL:[entity fileURL]];
                                         if ( [packageDict count] != 0 ) {
                                             
                                             NSString *packagePath = packageDict[NBCDictionaryKeyPackagePath];
                                             for ( NSDictionary *pkgDict in self->_packagesTableViewContents ) {
                                                 if ( [packagePath isEqualToString:pkgDict[NBCDictionaryKeyPackagePath]] ) {
                                                     DDLogWarn(@"Package %@ is already added!", [packagePath lastPathComponent]);
                                                     return;
                                                 }
                                             }
                                             
                                             [self->_packagesTableViewContents insertObject:packageDict atIndex:(NSUInteger)insertionIndex];
                                             [tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
                                             [draggingItem setDraggingFrame:[tableView frameOfCellAtColumn:0 row:insertionIndex]];
                                             insertionIndex++;
                                             [self->_viewOverlayPackages setHidden:YES];
                                         }
                                     }
                                 }];
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
#pragma unused(dropOperation)
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
        [self insertCertificatesInTableView:_tableViewCertificates draggingInfo:info row:row];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        [self insertPackagesInTableView:_tableViewPackages draggingInfo:info row:row];
    }
    return NO;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSTableView Delegate Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NBCCertificateTableCellView *)populateCertificateCellView:(NBCCertificateTableCellView *)cellView certificateDict:(NSDictionary *)certificateDict {
    NSMutableAttributedString *certificateName;
    NSMutableAttributedString *certificateExpirationString;
    if ( [certificateDict[NBCDictionaryKeyCertificateExpired] boolValue] ) {
        certificateName = [[NSMutableAttributedString alloc] initWithString:certificateDict[NBCDictionaryKeyCertificateName]];
        [certificateName addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[certificateName length])];
        
        certificateExpirationString = [[NSMutableAttributedString alloc] initWithString:certificateDict[NBCDictionaryKeyCertificateExpirationString]];
        [certificateExpirationString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[certificateExpirationString length])];
    }
    
    // --------------------------------------------
    //  Certificate Icon
    // --------------------------------------------
    NSImage *certificateIcon;
    NSURL *certificateIconURL;
    
    if ( [certificateDict[NBCDictionaryKeyCertificateSelfSigned] boolValue] ) {
        certificateIconURL = [[NSBundle mainBundle] URLForResource:@"IconCertRoot" withExtension:@"png"];
    } else {
        certificateIconURL = [[NSBundle mainBundle] URLForResource:@"IconCertStandard" withExtension:@"png"];
    }
    
    if ( [certificateIconURL checkResourceIsReachableAndReturnError:nil] ) {
        certificateIcon = [[NSImage alloc] initWithContentsOfURL:certificateIconURL];
        [[cellView imageViewCertificateIcon] setImage:certificateIcon];
    }
    
    // --------------------------------------------
    //  Certificate Name
    // --------------------------------------------
    if ( [certificateName length] != 0 ) {
        [[cellView textFieldCertificateName] setAttributedStringValue:certificateName];
    } else {
        [[cellView textFieldCertificateName] setStringValue:certificateDict[NBCDictionaryKeyCertificateName]];
    }
    
    // --------------------------------------------
    //  Certificate Expiration String
    // --------------------------------------------
    if ( [certificateExpirationString length] != 0 ) {
        [[cellView textFieldCertificateExpiration] setAttributedStringValue:certificateExpirationString];
    } else {
        [[cellView textFieldCertificateExpiration] setStringValue:certificateDict[NBCDictionaryKeyCertificateExpirationString]];
    }
    
    return cellView;
}

- (NBCPackageTableCellView *)populatePackageCellView:(NBCPackageTableCellView *)cellView packageDict:(NSDictionary *)packageDict {
    NSMutableAttributedString *packageName;
    NSImage *packageIcon;
    NSURL *packageURL = [NSURL fileURLWithPath:packageDict[NBCDictionaryKeyPackagePath]];
    if ( [packageURL checkResourceIsReachableAndReturnError:nil] ) {
        [[cellView textFieldPackageName] setStringValue:packageDict[NBCDictionaryKeyPackageName]];
        packageIcon = [[NSWorkspace sharedWorkspace] iconForFile:[packageURL path]];
        [[cellView imageViewPackageIcon] setImage:packageIcon];
    } else {
        packageName = [[NSMutableAttributedString alloc] initWithString:packageDict[NBCDictionaryKeyPackageName]];
        [packageName addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[packageName length])];
        [[cellView textFieldPackageName] setAttributedStringValue:packageName];
    }
    
    return cellView;
}

- (NBCImagrTrustedNetBootServerCellView *)populateTrustedNetBootServerCellView:(NBCImagrTrustedNetBootServerCellView *)cellView netBootServerIP:(NSString *)netBootServerIP row:(NSInteger)row {
    NSMutableAttributedString *netBootServerIPMutable;
    [[cellView textFieldTrustedNetBootServer] setTag:row];
    if ( [netBootServerIP isValidIPAddress] ) {
        [[cellView textFieldTrustedNetBootServer] setStringValue:netBootServerIP];
    } else {
        netBootServerIPMutable = [[NSMutableAttributedString alloc] initWithString:netBootServerIP];
        [netBootServerIPMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[netBootServerIPMutable length])];
        [[cellView textFieldTrustedNetBootServer] setAttributedStringValue:netBootServerIPMutable];
    }
    
    return cellView;
}

- (NBCImagrRAMDiskPathCellView *)populateRAMDiskPathCellView:(NBCImagrRAMDiskPathCellView *)cellView ramDiskDict:(NSDictionary *)ramDiskDict row:(NSInteger)row {
    NSString *ramDiskPath = ramDiskDict[@"path"] ?: @"";
    [[cellView textFieldRAMDiskPath] setStringValue:ramDiskPath];
    [[cellView textFieldRAMDiskPath] setTag:row];
    /*
     NSMutableAttributedString *ramDiskMutable;
     if ( [netBootServerIP isValidIPAddress] ) {
     [[cellView textFieldTrustedNetBootServer] setStringValue:netBootServerIP];
     } else {
     netBootServerIPMutable = [[NSMutableAttributedString alloc] initWithString:netBootServerIP];
     [netBootServerIPMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[netBootServerIPMutable length])];
     [[cellView textFieldTrustedNetBootServer] setAttributedStringValue:netBootServerIPMutable];
     }
     */
    return cellView;
}

- (NBCImagrRAMDiskSizeCellView *)populateRAMDiskSizeCellView:(NBCImagrRAMDiskSizeCellView *)cellView ramDiskDict:(NSDictionary *)ramDiskDict row:(NSInteger)row {
    NSString *ramDiskSize = ramDiskDict[@"size"] ?: @"1";
    [[cellView textFieldRAMDiskSize] setStringValue:ramDiskSize];
    [[cellView textFieldRAMDiskSize] setTag:row];
    /*
     NSMutableAttributedString *ramDiskMutable;
     if ( [netBootServerIP isValidIPAddress] ) {
     [[cellView textFieldTrustedNetBootServer] setStringValue:netBootServerIP];
     } else {
     netBootServerIPMutable = [[NSMutableAttributedString alloc] initWithString:netBootServerIP];
     [netBootServerIPMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[netBootServerIPMutable length])];
     [[cellView textFieldTrustedNetBootServer] setAttributedStringValue:netBootServerIPMutable];
     }
     */
    return cellView;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
        NSDictionary *certificateDict = _certificateTableViewContents[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"CertificateTableColumn"] ) {
            NBCCertificateTableCellView *cellView = [tableView makeViewWithIdentifier:@"CertificateCellView" owner:self];
            return [self populateCertificateCellView:cellView certificateDict:certificateDict];
        }
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        NSDictionary *packageDict = _packagesTableViewContents[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"PackageTableColumn"] ) {
            NBCPackageTableCellView *cellView = [tableView makeViewWithIdentifier:@"PackageCellView" owner:self];
            return [self populatePackageCellView:cellView packageDict:packageDict];
        }
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierImagrTrustedServers] ) {
        [self updateTrustedNetBootServersCount];
        NSString *trustedServer = _trustedServers[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"ImagrTrustedNetBootTableColumn"] ) {
            NBCImagrTrustedNetBootServerCellView *cellView = [tableView makeViewWithIdentifier:@"ImagrNetBootServerCellView" owner:self];
            return [self populateTrustedNetBootServerCellView:cellView netBootServerIP:trustedServer row:row];
        }
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierImagrRAMDisks] ) {
        [self updateRAMDisksCount];
        NSDictionary *ramDiskDict = _ramDisks[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"ImagrRAMDiskPathTableColumn"] ) {
            NBCImagrRAMDiskPathCellView *cellView = [tableView makeViewWithIdentifier:@"ImagrRAMDiskPathCellView" owner:self];
            return [self populateRAMDiskPathCellView:cellView ramDiskDict:ramDiskDict row:row];
        } else if ( [[tableColumn identifier] isEqualToString:@"ImagrRAMDiskSizeTableColumn"] ) {
            NBCImagrRAMDiskSizeCellView *cellView = [tableView makeViewWithIdentifier:@"ImagrRAMDiskSizeCellView" owner:self];
            return [self populateRAMDiskSizeCellView:cellView ramDiskDict:ramDiskDict row:row];
        }
    }
    return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSTableView Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)pasteboardReadingOptionsCertificates {
    return @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
              NSPasteboardURLReadingContentsConformToTypesKey : @[ @"public.x509-certificate" ] };
}

- (NSDictionary *)pasteboardReadingOptionsPackages {
    return @{ NSPasteboardURLReadingFileURLsOnlyKey : @YES,
              NSPasteboardURLReadingContentsConformToTypesKey : @[ @"com.apple.installer-package-archive" ] };
}

- (BOOL)containsAcceptableCertificateURLsFromPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadObjectForClasses:@[[NSURL class]]
                                       options:[self pasteboardReadingOptionsCertificates]];
}

- (BOOL)containsAcceptablePackageURLsFromPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadObjectForClasses:@[[NSURL class]]
                                       options:[self pasteboardReadingOptionsPackages]];
}

- (NSDictionary *)examinePackageAtURL:(NSURL *)packageURL {
    
    NSMutableDictionary *newPackageDict = [[NSMutableDictionary alloc] init];
    
    newPackageDict[NBCDictionaryKeyPackagePath] = [packageURL path];
    newPackageDict[NBCDictionaryKeyPackageName] = [packageURL lastPathComponent];
    
    return newPackageDict;
}

- (NSDictionary *)examineCertificate:(NSData *)certificateData {
    
    NSMutableDictionary *newCertificateDict = [[NSMutableDictionary alloc] init];
    
    SecCertificateRef certificate = nil;
    NSString *certificateName;
    NSString *certificateExpirationString;
    NSString *certificateSerialNumber;
    NSDate *certificateNotValidBeforeDate;
    NSDate *certificateNotValidAfterDate;
    BOOL isSelfSigned = NO;
    BOOL certificateExpired = NO;
    
    certificate = SecCertificateCreateWithData(NULL, CFBridgingRetain(certificateData));
    
    if ( ! certificate ) {
        DDLogError(@"[ERROR] Could not get certificate from data!");
        return nil;
    }
    
    CFErrorRef *error = nil;
    NSDictionary *certificateValues = (__bridge NSDictionary *)(SecCertificateCopyValues(certificate, (__bridge CFArrayRef)@[
                                                                                                                             (__bridge id)kSecOIDX509V1ValidityNotBefore,
                                                                                                                             (__bridge id)kSecOIDX509V1ValidityNotAfter,
                                                                                                                             (__bridge id)kSecOIDX509V1Signature,
                                                                                                                             (__bridge id)kSecOIDX509V1SerialNumber,
                                                                                                                             (__bridge id)kSecOIDTitle
                                                                                                                             ], error));
    if ( [certificateValues count] != 0 ) {
        // --------------------------------------------
        //  Certificate IsSelfSigned
        // --------------------------------------------
        CFDataRef issuerData = SecCertificateCopyNormalizedIssuerContent(certificate, error);
        CFDataRef subjectData = SecCertificateCopyNormalizedSubjectContent(certificate, error);
        
        if ( [(__bridge NSData*)issuerData isEqualToData:(__bridge NSData*)subjectData] ) {
            isSelfSigned = YES;
        }
        newCertificateDict[NBCDictionaryKeyCertificateSelfSigned] = @(isSelfSigned);
        
        // --------------------------------------------
        //  Certificate Name
        // --------------------------------------------
        certificateName = (__bridge NSString *)(SecCertificateCopySubjectSummary(certificate));
        if ( [certificateName length] != 0 ) {
            newCertificateDict[NBCDictionaryKeyCertificateName] = certificateName ?: @"";
        } else {
            DDLogError(@"[ERROR] Could not get certificateName!");
            return nil;
        }
        
        // --------------------------------------------
        //  Certificate NotValidBefore
        // --------------------------------------------
        if ( certificateValues[(__bridge id)kSecOIDX509V1ValidityNotBefore] ) {
            NSDictionary *notValidBeforeDict = certificateValues[(__bridge id)kSecOIDX509V1ValidityNotBefore];
            NSNumber *notValidBefore = notValidBeforeDict[@"value"];
            certificateNotValidBeforeDate = CFBridgingRelease(CFDateCreate(kCFAllocatorDefault, [notValidBefore doubleValue]));
            
            if ( [certificateNotValidBeforeDate compare:[NSDate date]] == NSOrderedDescending ) {
                certificateExpired = YES;
                certificateExpirationString = [NSString stringWithFormat:@"Not valid before %@", certificateNotValidBeforeDate];
            }
            
            newCertificateDict[NBCDictionaryKeyCertificateNotValidBeforeDate] = certificateNotValidBeforeDate;
        }
        
        // --------------------------------------------
        //  Certificate NotValidAfter
        // --------------------------------------------
        if ( certificateValues[(__bridge id)kSecOIDX509V1ValidityNotAfter] ) {
            NSDictionary *notValidAfterDict = certificateValues[(__bridge id)kSecOIDX509V1ValidityNotAfter];
            NSNumber *notValidAfter = notValidAfterDict[@"value"];
            certificateNotValidAfterDate = CFBridgingRelease(CFDateCreate(kCFAllocatorDefault, [notValidAfter doubleValue]));
            
            if ( [certificateNotValidAfterDate compare:[NSDate date]] == NSOrderedAscending && ! certificateExpired ) {
                certificateExpired = YES;
                certificateExpirationString = [NSString stringWithFormat:@"Expired %@", certificateNotValidAfterDate];
            } else {
                certificateExpirationString = [NSString stringWithFormat:@"Expires %@", certificateNotValidAfterDate];
            }
            
            newCertificateDict[NBCDictionaryKeyCertificateNotValidAfterDate] = certificateNotValidAfterDate;
        }
        
        // --------------------------------------------
        //  Certificate Expiration String
        // --------------------------------------------
        newCertificateDict[NBCDictionaryKeyCertificateExpirationString] = certificateExpirationString;
        
        // --------------------------------------------
        //  Certificate Expired
        // --------------------------------------------
        newCertificateDict[NBCDictionaryKeyCertificateExpired] = @(certificateExpired);
        
        // --------------------------------------------
        //  Certificate Serial Number
        // --------------------------------------------
        if ( certificateValues[(__bridge id)kSecOIDX509V1SerialNumber] ) {
            NSDictionary *serialNumber = certificateValues[(__bridge id)kSecOIDX509V1SerialNumber];
            certificateSerialNumber = serialNumber[@"value"];
            
            newCertificateDict[NBCDictionaryKeyCertificateSerialNumber] = certificateSerialNumber;
        }
        
        // --------------------------------------------
        //  Certificate Signature
        // --------------------------------------------
        if ( certificateValues[(__bridge id)kSecOIDX509V1Signature] ) {
            NSDictionary *signatureDict = certificateValues[(__bridge id)kSecOIDX509V1Signature];
            newCertificateDict[NBCDictionaryKeyCertificateSignature] = signatureDict[@"value"];
        }
        
        // --------------------------------------------
        //  Add Certificate
        // --------------------------------------------
        newCertificateDict[NBCDictionaryKeyCertificate] = certificateData;
        
        return [newCertificateDict copy];
    } else {
        DDLogError(@"[ERROR] SecCertificateCopyValues returned nil, possibly PEM-encoded?");
        return nil;
    }
}

- (void)insertCertificateInTableView:(NSDictionary *)certificateDict {
    for ( NSDictionary *certDict in _certificateTableViewContents ) {
        if ( [certificateDict[NBCDictionaryKeyCertificateSignature] isEqualToData:certDict[NBCDictionaryKeyCertificateSignature]] ) {
            if ( [certificateDict[NBCDictionaryKeyCertificateSerialNumber] isEqualToString:certDict[NBCDictionaryKeyCertificateSerialNumber]] ) {
                DDLogWarn(@"Certificate %@ is already added!", certificateDict[NBCDictionaryKeyCertificateName]);
                return;
            }
        }
    }
    
    NSInteger index = [_tableViewCertificates selectedRow];
    index++;
    [_tableViewCertificates beginUpdates];
    [_tableViewCertificates insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewCertificates scrollRowToVisible:index];
    [_certificateTableViewContents insertObject:certificateDict atIndex:(NSUInteger)index];
    [_viewOverlayCertificates setHidden:YES];
    [_tableViewCertificates endUpdates];
}

- (void)insertPackageInTableView:(NSDictionary *)packageDict {
    NSString *packagePath = packageDict[NBCDictionaryKeyPackagePath];
    for ( NSDictionary *pkgDict in _packagesTableViewContents ) {
        if ( [packagePath isEqualToString:pkgDict[NBCDictionaryKeyPackagePath]] ) {
            DDLogWarn(@"Package %@ is already added!", [packagePath lastPathComponent]);
            return;
        }
    }
    
    NSInteger index = [_tableViewPackages selectedRow];
    index++;
    [_tableViewPackages beginUpdates];
    [_tableViewPackages insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewPackages scrollRowToVisible:index];
    [_packagesTableViewContents insertObject:packageDict atIndex:(NSUInteger)index];
    [_viewOverlayPackages setHidden:YES];
    [_tableViewPackages endUpdates];
}

- (NSInteger)insertNetBootServerIPInTableView:(NSString *)netBootServerIP {
    NSInteger index = [_tableViewTrustedServers selectedRow];
    index++;
    [_tableViewTrustedServers beginUpdates];
    [_tableViewTrustedServers insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewTrustedServers scrollRowToVisible:index];
    [_trustedServers insertObject:netBootServerIP atIndex:(NSUInteger)index];
    [_tableViewTrustedServers endUpdates];
    return index;
}

- (NSInteger)insertRAMDiskInTableView:(NSDictionary *)ramDiskDict {
    NSInteger index = [_tableViewRAMDisks selectedRow];
    index++;
    [_tableViewRAMDisks beginUpdates];
    [_tableViewRAMDisks insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewRAMDisks scrollRowToVisible:index];
    [_ramDisks insertObject:ramDiskDict atIndex:(NSUInteger)index];
    [_tableViewRAMDisks endUpdates];
    return index;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Reachability
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)testInternetConnection {
    
    _internetReachableFoo = [Reachability reachabilityWithHostname:@"github.com"];
    __unsafe_unretained typeof(self) weakSelf = self;
    
    // Internet is reachable
    _internetReachableFoo.reachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf getImagrVersions];
            [weakSelf getImagrBranches];
        });
    };
    
    // Internet is not reachable
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf updatePopUpButtonImagrVersionsLocal];
        });
    };
    
    [_internetReachableFoo startNotifier];
} // testInternetConnection

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods PopUpButton
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    
    BOOL retval = YES;
    
    if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalIcon] ) {
        
        // -------------------------------------------------------------
        //  No need to restore original icon if it's already being used
        // -------------------------------------------------------------
        if ( [_nbiIconPath isEqualToString:NBCFilePathNBIIconImagr] ) {
            retval = NO;
        }
        return retval;
    } else if ( [[menuItem title] isEqualToString:NBCMenuItemRestoreOriginalBackground] ) {
        // -------------------------------------------------------------------
        //  No need to restore original background if it's already being used
        // -------------------------------------------------------------------
        if ( [_imageBackgroundURL isEqualToString:NBCBackgroundImageDefaultPath] ) {
            retval = NO;
        }
        return retval;
    }
    
    return YES;
} // validateMenuItem

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods TextField
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)controlTextDidChange:(NSNotification *)sender {
    if ( [[[sender object] class] isSubclassOfClass:[NSTextField class]] ) {
        NSTextField *textField = [sender object];
        if ( [[[textField superview] class] isSubclassOfClass:[NBCImagrTrustedNetBootServerCellView class]] ) {
            NSNumber *textFieldTag = [NSNumber numberWithInteger:[textField tag]];
            if ( textFieldTag != nil ) {
                if ( [sender object] == [[_tableViewTrustedServers viewAtColumn:[_tableViewTrustedServers selectedColumn] row:[textFieldTag integerValue] makeIfNecessary:NO] textFieldTrustedNetBootServer] ) {
                    NSDictionary *userInfo = [sender userInfo];
                    NSString *inputText = [[userInfo valueForKey:@"NSFieldEditor"] string];
                    
                    // Only allow numers and periods
                    NSCharacterSet *allowedCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
                    if ( [[inputText stringByTrimmingCharactersInSet:allowedCharacters] length] != 0 ) {
                        [textField setStringValue:[inputText stringByTrimmingCharactersInSet:[allowedCharacters invertedSet]]];
                        return;
                    }
                    
                    [_trustedServers replaceObjectAtIndex:(NSUInteger)[textFieldTag integerValue] withObject:[inputText copy]];
                }
            }
        }
        
        // --------------------------------------------------------------------
        //  Expand variables for the NBI preview text fields
        // --------------------------------------------------------------------
        if ( textField == _textFieldNBIName ) {
            if ( [_nbiName length] == 0 ) {
                [_textFieldNBINamePreview setStringValue:@""];
            } else {
                NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_siuSource];
                [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
            }
        } else if ( textField == _textFieldIndex ) {
            if ( [_nbiIndex length] == 0 ) {
                [_textFieldIndexPreview setStringValue:@""];
            } else {
                NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
                [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
            }
        } else if ( textField == _textFieldNBIDescription ) {
            if ( [_nbiDescription length] == 0 ) {
                [_textFieldNBIDescriptionPreview setStringValue:@""];
            } else {
                NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_siuSource];
                [_textFieldNBIDescriptionPreview setStringValue:nbiDescription];
            }
        } else if ( textField == _textFieldDestinationFolder ) {
            // --------------------------------------------------------------------
            //  Expand tilde for destination folder if tilde is used in settings
            // --------------------------------------------------------------------
            if ( [_destinationFolder length] == 0 ) {
                [self setDestinationFolder:@""];
            } else if ( [_destinationFolder hasPrefix:@"~"] ) {
                NSString *destinationFolder = [_destinationFolder stringByExpandingTildeInPath];
                [self setDestinationFolder:destinationFolder];
            }
        }
        
        // --------------------------------------------------------------------
        //  Continuously verify build button
        // --------------------------------------------------------------------
        [self verifyBuildButton];
    }
    
} // controlTextDidChange

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCDownloaderGitHub
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
- (void)githubReleaseVersionsArray:(NSArray *)versionsArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagImagr] ) {
        [self setImagrVersions:versionsArray];
        [self setImagrVersionsDownloadLinks:downloadDict];
        [self updatePopUpButtonImagrVersions];
        [self updateCachedImagrVersions:downloadDict];
    }
} // githubReleaseVersionsArray:downloadDict:downloadInfo

- (void)githubBranchesArray:(NSArray *)branchesArray downloadDict:(NSDictionary *)downloadDict downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagImagr] ) {
        [self setImagrBranches:branchesArray];
        [self setImagrBranchesDownloadLinks:downloadDict];
        [self updatePopUpButtonImagrBranches];
        [self updatePopUpButtonImagrBranchesBuildTarget];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Delegate Methods NBCAlert
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo {
    
    NSString *alertTag = alertInfo[NBCAlertTagKey];
    if ( [alertTag isEqualToString:NBCAlertTagSettingsWarning] ) {
        if ( returnCode == NSAlertSecondButtonReturn ) {        // Continue
            NBCWorkflowItem *workflowItem = alertInfo[NBCAlertWorkflowItemKey];
            [self prepareWorkflowItem:workflowItem];
        }
    }
    
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsaved] ) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save
            [self saveUISettingsWithName:_selectedTemplate atUrl:_templatesDict[_selectedTemplate]];
            [self setSelectedTemplate:selectedTemplate];
            [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
            [self expandVariablesForCurrentSettings];
            return;
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Discard
            [self setSelectedTemplate:selectedTemplate];
            [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
            [self expandVariablesForCurrentSettings];
            return;
        } else {                                                // Cancel
            [_popUpButtonTemplates selectItemWithTitle:_selectedTemplate];
            return;
        }
    }
    
    if ( [alertTag isEqualToString:NBCAlertTagSettingsUnsavedBuild] ) {
        NSString *selectedTemplate = alertInfo[NBCAlertUserInfoSelectedTemplate];
        NSDictionary *preWorkflowTasks = alertInfo[NBCAlertUserInfoPreWorkflowTasks];
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save and Continue
            if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
                [_templates showSheetSaveUntitled:selectedTemplate buildNBI:YES preWorkflowTasks:preWorkflowTasks];
                return;
            } else {
                [self saveUISettingsWithName:_selectedTemplate atUrl:_templatesDict[_selectedTemplate]];
                [self setSelectedTemplate:selectedTemplate];
                [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
                [self expandVariablesForCurrentSettings];
                [self verifySettings:preWorkflowTasks];
                return;
            }
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Continue
            [self verifySettings:preWorkflowTasks];
            return;
        } else {                                                // Cancel
            [_popUpButtonTemplates selectItemWithTitle:_selectedTemplate];
            return;
        }
    }
} // alertReturnCode:alertInfo

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Notification Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateSettingVisibility {
    if ( _source != nil ) {
        int sourceVersionMinor = (int)[[_source expandVariables:@"%OSMINOR%"] integerValue];
        if ( _source != nil && 11 <= sourceVersionMinor ) {
            [self setSettingDisableATSVisible:YES];
            [self setSettingTrustedNetBootServersVisible:YES];
        } else {
            [self setSettingDisableATSVisible:NO];
            [self setSettingTrustedNetBootServersVisible:NO];
        }
    } else {
        [self setSettingDisableATSVisible:NO];
        [self setSettingTrustedNetBootServersVisible:NO];
    }
}

- (void)updateSource:(NSNotification *)notification {
    
    NBCSource *source = [notification userInfo][NBCNotificationUpdateSourceUserInfoSource];
    if ( source != nil ) {
        DDLogDebug(@"[DEBUG] Updating source...");
        [self setSource:source];
    } else {
        
    }
    
    [self updateSettingVisibility];
    
    NSString *currentBackgroundImageURL = _imageBackgroundURL;
    if ( [currentBackgroundImageURL isEqualToString:NBCBackgroundImageDefaultPath] ) {
        [self setImageBackground:@""];
        [self setImageBackground:NBCBackgroundImageDefaultPath];
        [self setImageBackgroundURL:NBCBackgroundImageDefaultPath];
    }
    
    NBCTarget *target = [notification userInfo][NBCNotificationUpdateSourceUserInfoTarget];
    if ( target != nil ) {
        DDLogDebug(@"[DEBUG] Updating target...");
        [self setTarget:target];
    }
    
    if ( [[source sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        
        // If current source is NBI, remove current template.
        if ( _isNBI ) {
            NSURL *selectedTemplate = _templatesDict[_selectedTemplate];
            if ( [selectedTemplate checkResourceIsReachableAndReturnError:nil] ) {
                [_templates deleteTemplateAtURL:selectedTemplate updateTemplateList:NO];
            }
        }
        
        [self setIsNBI:YES];
        NSURL *nbiURL = [source sourceURL];
        [self createSettingsFromNBI:nbiURL];
    } else {
        if ( _isNBI ) {
            NSURL *selectedTemplate = _templatesDict[_selectedTemplate];
            if ( [selectedTemplate checkResourceIsReachableAndReturnError:nil] ) {
                [_templates deleteTemplateAtURL:selectedTemplate updateTemplateList:YES];
            }
        }
        
        [self setNbiSourceSettings:nil];
        [self setIsNBI:NO];
        [self updateUIForSourceType:[source sourceType] settings:nil];
        [self expandVariablesForCurrentSettings];
        [self verifyBuildButton];
    }
    
    [self updatePopOver];
} // updateSource

- (void)removedSource:(NSNotification *)notification {
#pragma unused(notification)
    if ( _source ) {
        [self setSource:nil];
    }
    
    [self updateSettingVisibility];
    
    NSString *currentBackgroundImageURL = _imageBackgroundURL;
    if ( [currentBackgroundImageURL isEqualToString:NBCBackgroundImageDefaultPath] ) {
        [self setImageBackground:@""];
        [self setImageBackground:NBCBackgroundImageDefaultPath];
        [self setImageBackgroundURL:NBCBackgroundImageDefaultPath];
    }
    
    if ( _isNBI ) {
        NSURL *selectedTemplate = _templatesDict[_selectedTemplate];
        if ( [selectedTemplate checkResourceIsReachableAndReturnError:nil] ) {
            [_templates deleteTemplateAtURL:selectedTemplate updateTemplateList:YES];
        }
    }
    
    [self setIsNBI:NO];
    [self setNbiSourceSettings:nil];
    [self updateUIForSourceType:NBCSourceTypeInstallerApplication settings:nil];
    [self expandVariablesForCurrentSettings];
    [self verifyBuildButton];
    [self updatePopOver];
} // removedSource

- (void)updateNBIIcon:(NSNotification *)notification {
    
    NSURL *nbiIconURL = [notification userInfo][NBCNotificationUpdateNBIIconUserInfoIconURL];
    if ( nbiIconURL != nil )
    {
        // To get the view to update I have to first set the nbiIcon property to @""
        // It only happens when it recieves a dropped image, not when setting in code.
        [self setNbiIcon:@""];
        [self setNbiIconPath:[nbiIconURL path]];
    }
} // updateNBIIcon

- (void)restoreNBIIcon:(NSNotification *)notification {
#pragma unused(notification)
    
    [self setNbiIconPath:NBCFilePathNBIIconImagr];
    [self expandVariablesForCurrentSettings];
} // restoreNBIIcon

- (void)updateNBIBackground:(NSNotification *)notification {
    NSURL *nbiBackgroundURL = [notification userInfo][NBCNotificationUpdateNBIBackgroundUserInfoIconURL];
    if ( nbiBackgroundURL != nil ) {
        // To get the view to update I have to first set the nbiIcon property to @""
        // It only happens when it recieves a dropped image, not when setting in code.
        [self setImageBackground:@""];
        [self setImageBackgroundURL:[nbiBackgroundURL path]];
    }
} // updateImageBackground

- (void)restoreNBIBackground:(NSNotification *)notification {
#pragma unused(notification)
    
    [self setImageBackground:@""];
    [self setImageBackgroundURL:NBCBackgroundImageDefaultPath];
    [self expandVariablesForCurrentSettings];
} // restoreNBIBackground

- (void)editingDidEnd:(NSNotification *)notification {
    if ( [[[notification object] class] isSubclassOfClass:[NSTextField class]] ) {
        NSTextField *textField = [notification object];
        if ( [[[textField superview] class] isSubclassOfClass:[NBCImagrTrustedNetBootServerCellView class]] ) {
            [self updateTrustedNetBootServersCount];
        } else if ( [[[textField superview] class] isSubclassOfClass:[NBCImagrRAMDiskPathCellView class]] ) {
            NSString *newPath = [textField stringValue];
            NSNumber *textFieldTag = [NSNumber numberWithInteger:[textField tag]];
            if ( textFieldTag != nil ) {
                NSMutableDictionary *ramDiskDict = [NSMutableDictionary dictionaryWithDictionary:[_ramDisks objectAtIndex:(NSUInteger)[textFieldTag integerValue]]];
                ramDiskDict[@"path"] = newPath ?: @"";
                [_ramDisks replaceObjectAtIndex:(NSUInteger)[textFieldTag integerValue] withObject:[ramDiskDict copy]];
                [self updateRAMDisksCount];
            }
        } else if ( [[[textField superview] class] isSubclassOfClass:[NBCImagrRAMDiskSizeCellView class]] ) {
            NSString *newSize = [[notification object] stringValue];
            NSNumber *textFieldTag = [NSNumber numberWithInteger:[textField tag]];
            if ( textFieldTag != nil ) {
                NSMutableDictionary *ramDiskDict = [NSMutableDictionary dictionaryWithDictionary:[_ramDisks objectAtIndex:(NSUInteger)[textFieldTag integerValue]]];
                ramDiskDict[@"size"] = newSize ?: @"";
                [_ramDisks replaceObjectAtIndex:(NSUInteger)[textFieldTag integerValue] withObject:[ramDiskDict copy]];
                [self updateRAMDisksCount];
            }
        }
    }
} // editingDidEnd

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Key/Value Observing
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
#pragma unused(object, change, context)
    
    if ( [keyPath isEqualToString:NBCUserDefaultsIndexCounter] ) {
        NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
        [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    }
} // observeValueForKeyPath:ofObject:change:context

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Settings
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updateUISettingsFromDict:(NSDictionary *)settingsDict {
    [self setNbiCreationTool:settingsDict[NBCSettingsNBICreationToolKey]];
    [self setNbiName:settingsDict[NBCSettingsNameKey]];
    [self setNbiIndex:settingsDict[NBCSettingsIndexKey]];
    [self setNbiProtocol:settingsDict[NBCSettingsProtocolKey]];
    [self setNbiEnabled:[settingsDict[NBCSettingsEnabledKey] boolValue]];
    [self setNbiDefault:[settingsDict[NBCSettingsDefaultKey] boolValue]];
    [self setNbiLanguage:settingsDict[NBCSettingsLanguageKey]];
    [self setNbiKeyboardLayout:settingsDict[NBCSettingsKeyboardLayoutKey]];
    [self setNbiDescription:settingsDict[NBCSettingsDescriptionKey]];
    [self setDestinationFolder:settingsDict[NBCSettingsDestinationFolderKey]];
    [self setNbiIconPath:settingsDict[NBCSettingsIconKey]];
    [self setDisableWiFi:[settingsDict[NBCSettingsDisableWiFiKey] boolValue]];
    [self setDisableBluetooth:[settingsDict[NBCSettingsDisableBluetoothKey] boolValue]];
    [self setIncludeSystemUIServer:[settingsDict[NBCSettingsIncludeSystemUIServerKey] boolValue]];
    [self setArdLogin:settingsDict[NBCSettingsARDLoginKey]];
    [self setArdPassword:settingsDict[NBCSettingsARDPasswordKey]];
    [self setUseNetworkTimeServer:[settingsDict[NBCSettingsUseNetworkTimeServerKey] boolValue]];
    [self setNetworkTimeServer:settingsDict[NBCSettingsNetworkTimeServerKey]];
    [self setImagrVersion:settingsDict[NBCSettingsImagrVersion]];
    [self setImagrConfigurationURL:settingsDict[NBCSettingsImagrConfigurationURL]];
    [self setImagrReportingURL:settingsDict[NBCSettingsImagrReportingURL]];
    [self setImagrUseLocalVersion:[settingsDict[NBCSettingsImagrUseLocalVersion] boolValue]];
    [self setImagrLocalVersionPath:settingsDict[NBCSettingsImagrLocalVersionPath]];
    [self setIsNBI:[settingsDict[NBCSettingsImagrSourceIsNBI] boolValue]];
    [self setUseBackgroundImage:[settingsDict[NBCSettingsUseBackgroundImageKey] boolValue]];
    [self setImageBackgroundURL:settingsDict[NBCSettingsBackgroundImageKey]];
    [self setUseVerboseBoot:[settingsDict[NBCSettingsUseVerboseBootKey] boolValue]];
    [self setDiskImageReadWrite:[settingsDict[NBCSettingsDiskImageReadWriteKey] boolValue]];
    [self setDiskImageReadWriteRename:[settingsDict[NBCSettingsDiskImageReadWriteRenameKey] boolValue]];
    [self setIncludeConsoleApp:[settingsDict[NBCSettingsIncludeConsoleAppKey] boolValue]];
    [self setDisableATS:[settingsDict[NBCSettingsImagrDisableATS] boolValue]];
    [self setEnableLaunchdLogging:[settingsDict[NBCSettingsEnableLaunchdLoggingKey] boolValue]];
    [self setLaunchConsoleApp:[settingsDict[NBCSettingsLaunchConsoleAppKey] boolValue]];
    [self setAddCustomRAMDisks:[settingsDict[NBCSettingsAddCustomRAMDisksKey] boolValue]];
    [self setImagrSyslogServerURI:settingsDict[NBCSettingsImagrSyslogServerURI]];
    [self setIncludeRuby:[settingsDict[NBCSettingsIncludeRubyKey] boolValue]];
    [self setAddTrustedNetBootServers:[settingsDict[NBCSettingsAddTrustedNetBootServersKey] boolValue]];
    [self setImagrUseGitBranch:[settingsDict[NBCSettingsImagrUseGitBranch] boolValue]];
    [self setImagrGitBranch:settingsDict[NBCSettingsImagrGitBranch]];
    [self setImagrBuildTarget:settingsDict[NBCSettingsImagrBuildTarget]];
    
    if ( [_imagrVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        [self showImagrLocalVersionInput];
    } else if ( [_imagrVersion isEqualToString:NBCMenuItemGitBranch] ) {
        [self showImagrBranchSelection];
    } else {
        [self hideImagrBranchSelection];
        [self hideImagrLocalVersionInput];
    }
    
    NSNumber *displaySleepMinutes = settingsDict[NBCSettingsDisplaySleepMinutesKey];
    int displaySleepMinutesInteger = 20;
    if ( displaySleepMinutes != nil ) {
        displaySleepMinutesInteger = [displaySleepMinutes intValue];
        [self setDisplaySleepMinutes:displaySleepMinutesInteger];
    } else {
        [self setDisplaySleepMinutes:displaySleepMinutesInteger];
    }
    
    [_sliderDisplaySleep setIntegerValue:displaySleepMinutesInteger];
    [self updateSliderPreview:displaySleepMinutesInteger];
    if ( displaySleepMinutesInteger < 120 ) {
        [self setDisplaySleep:NO];
    } else {
        [self setDisplaySleep:YES];
    }
    
    [self uppdatePopUpButtonTool];
    
    if ( _nbiCreationTool == nil || [_nbiCreationTool isEqualToString:NBCMenuItemNBICreator] ) {
        [self hideSystemImageUtilityVersion];
    } else {
        [self showSystemImageUtilityVersion];
    }
    
    [_certificateTableViewContents removeAllObjects];
    [_tableViewCertificates reloadData];
    if ( [settingsDict[NBCSettingsCertificatesKey] count] != 0 ) {
        NSArray *certificatesArray = settingsDict[NBCSettingsCertificatesKey];
        for ( NSData *certificate in certificatesArray ) {
            NSDictionary *certificateDict = [self examineCertificate:certificate];
            if ( [certificateDict count] != 0 ) {
                [self insertCertificateInTableView:certificateDict];
            }
        }
    } else {
        [_viewOverlayCertificates setHidden:NO];
    }
    
    [_packagesTableViewContents removeAllObjects];
    [_tableViewPackages reloadData];
    if ( [settingsDict[NBCSettingsPackagesKey] count] != 0 ) {
        NSArray *packagesArray = settingsDict[NBCSettingsPackagesKey];
        for ( NSString *packagePath in packagesArray ) {
            NSURL *packageURL = [NSURL fileURLWithPath:packagePath];
            NSDictionary *packageDict = [self examinePackageAtURL:packageURL];
            if ( [packageDict count] != 0 ) {
                [self insertPackageInTableView:packageDict];
            }
        }
    } else {
        [_viewOverlayPackages setHidden:NO];
    }
    
    [_trustedServers removeAllObjects];
    [_tableViewTrustedServers reloadData];
    if ( [settingsDict[NBCSettingsTrustedNetBootServersKey] count] != 0 ) {
        NSArray *trustedServersArray = settingsDict[NBCSettingsTrustedNetBootServersKey];
        if ( [trustedServersArray count] != 0 ) {
            for ( NSString *trustedServer in trustedServersArray ) {
                [self insertNetBootServerIPInTableView:trustedServer];
            }
        } else {
            [self updateTrustedNetBootServersCount];
        }
    } else {
        [self updateTrustedNetBootServersCount];
    }
    
    [_ramDisks removeAllObjects];
    [_tableViewRAMDisks reloadData];
    if ( [settingsDict[NBCSettingsRAMDisksKey] count] != 0 ) {
        NSArray *ramDisksArray = settingsDict[NBCSettingsRAMDisksKey];
        for ( NSDictionary *ramDiskDict in ramDisksArray ) {
            if ( [ramDiskDict count] != 0 ) {
                [self insertRAMDiskInTableView:ramDiskDict];
            }
        }
    }
    
    NSString *selectedTimeZone = settingsDict[NBCSettingsTimeZoneKey];
    if ( [selectedTimeZone length] == 0 || [selectedTimeZone isEqualToString:NBCMenuItemCurrent] ) {
        [self selectTimeZone:[_popUpButtonTimeZone itemWithTitle:NBCMenuItemCurrent]];
    } else {
        NSString *selectedTimeZoneRegion = [selectedTimeZone componentsSeparatedByString:@"/"][0];
        DDLogDebug(@"[DEBUG] TimeZone Region: %@", selectedTimeZoneRegion);
        NSString *selectedTimeZoneCity = [selectedTimeZone componentsSeparatedByString:@"/"][1];
        DDLogDebug(@"[DEBUG] TimeZone City: %@", selectedTimeZoneCity);
        NSArray *regionArray = [[[_popUpButtonTimeZone itemWithTitle:selectedTimeZoneRegion] submenu] itemArray];
        for ( NSMenuItem *menuItem in regionArray ) {
            if ( [[menuItem title] isEqualToString:selectedTimeZoneCity] ) {
                DDLogDebug(@"[DEBUG] Selecting menu item: %@", [menuItem title]);
                [self selectTimeZone:menuItem];
                break;
            }
        }
    }
    
    [self expandVariablesForCurrentSettings];
    
    if ( _isNBI ) {
        [self updateUIForSourceType:NBCSourceTypeNBI settings:settingsDict];
    } else {
        [self updateUIForSourceType:NBCSourceTypeInstallerApplication settings:settingsDict]; // Doesn't matter as long as it's not NBI
    }
    
    /*/////////////////////////////////////////////////////////////////////////
     /// TEMPORARY FIX WHEN CHANGING KEY FOR KEYBOARD_LAYOUT IN TEMPLATE    ///
     ////////////////////////////////////////////////////////////////////////*/
    if ( [settingsDict[NBCSettingsKeyboardLayoutKey] length] == 0 ) {
        NSString *valueFromOldKeyboardLayoutKey = settingsDict[@"KeyboardLayoutName"];
        if ( [valueFromOldKeyboardLayoutKey length] != 0 ) {
            [self setNbiKeyboardLayout:valueFromOldKeyboardLayoutKey];
        }
    }
    /* --------------------------------------------------------------------- */
} // updateUISettingsFromDict

- (void)updateUIForSourceType:(NSString *)sourceType settings:(NSDictionary *)settingsDict{
    
    // -------------------------------------------------------------------------------
    //  If source is NBI, disable all settings that require extraction from OS Source.
    // -------------------------------------------------------------------------------
    if ( [sourceType isEqualToString:NBCSourceTypeNBI] ) {
        
        [_popUpButtonTool setEnabled:NO];
        [_popUpButtonTemplates setEnabled:NO];
        
        // Tab Bar: General
        [_textFieldDestinationFolder setEnabled:NO];
        [_buttonChooseDestinationFolder setEnabled:NO];
        
        // Tab Bar: Options
        if ( [settingsDict[NBCSettingsDisableWiFiKey] boolValue] ) {
            [_checkboxDisableWiFi setEnabled:NO];
        } else {
            [_checkboxDisableWiFi setEnabled:YES];
        }
        
        if ( [settingsDict[NBCSettingsDisableBluetoothKey] boolValue] ) {
            [_checkboxDisableBluetooth setEnabled:NO];
        } else {
            [_checkboxDisableBluetooth setEnabled:YES];
        }
        
        [_checkboxIncludeRuby setEnabled:NO];
        [_checkboxIncludeSystemUIServer setEnabled:NO];
        
        if ( [settingsDict[NBCSettingsARDLoginKey] length] != 0 ) {
            [_textFieldARDLogin setEnabled:YES];
            [_textFieldARDPassword setEnabled:YES];
            [_secureTextFieldARDPassword setEnabled:YES];
            [_checkboxARDPasswordShow setEnabled:YES];
        } else {
            [_textFieldARDLogin setEnabled:NO];
            [_textFieldARDPassword setEnabled:NO];
            [_secureTextFieldARDPassword setEnabled:NO];
            [_checkboxARDPasswordShow setEnabled:NO];
        }
        
        if ( [settingsDict[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
            [_checkboxUseNetworkTimeServer setEnabled:YES];
        } else {
            [_checkboxUseNetworkTimeServer setEnabled:NO];
        }
        
        // Tab Bar: Advanced
        [_checkboxAddBackground setEnabled:NO];
        
        // Tab Bar: Debug
        [_checkboxIncludeConsole setEnabled:NO];
        if ( [settingsDict[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
            [_checkboxConsoleLaunchBehindApp setEnabled:YES];
        } else {
            [_checkboxConsoleLaunchBehindApp setEnabled:NO];
        }
    } else {
        [_popUpButtonTool setEnabled:YES];
        [_popUpButtonTemplates setEnabled:YES];
        
        // Tab Bar: General
        [_textFieldDestinationFolder setEnabled:YES];
        [_buttonChooseDestinationFolder setEnabled:YES];
        
        // Tab Bar: Options
        [_checkboxDisableWiFi setEnabled:YES];
        [_checkboxDisableBluetooth setEnabled:YES];
        [_checkboxIncludeRuby setEnabled:YES];
        [_checkboxIncludeSystemUIServer setEnabled:YES];
        [_textFieldARDLogin setEnabled:YES];
        [_textFieldARDPassword setEnabled:YES];
        [_secureTextFieldARDPassword setEnabled:YES];
        [_checkboxARDPasswordShow setEnabled:YES];
        [_checkboxUseNetworkTimeServer setEnabled:YES];
        
        // Tab Bar: Advanced
        [_checkboxAddBackground setEnabled:YES];
        
        // Tab Bar: Debug
        [_checkboxIncludeConsole setEnabled:YES];
        [_checkboxConsoleLaunchBehindApp setEnabled:YES];
    }
}

- (void)updateUISettingsFromURL:(NSURL *)url {
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    if ( mainDict ) {
        NSDictionary *settingsDict = mainDict[NBCSettingsSettingsKey];
        if ( settingsDict ) {
            [self updateUISettingsFromDict:settingsDict];
        } else {
            DDLogError(@"[ERROR] No key named Settings i plist at URL: %@", url);
        }
    } else {
        DDLogError(@"[ERROR] Could not read plist at URL: %@", url);
    }
} // updateUISettingsFromURL

- (NSDictionary *)returnSettingsFromUI {
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    settingsDict[NBCSettingsNBICreationToolKey] = _nbiCreationTool ?: NBCMenuItemNBICreator;
    settingsDict[NBCSettingsNameKey] = _nbiName ?: @"";
    settingsDict[NBCSettingsIndexKey] = _nbiIndex ?: @"1";
    settingsDict[NBCSettingsProtocolKey] = _nbiProtocol ?: @"NFS";
    settingsDict[NBCSettingsLanguageKey] = _nbiLanguage ?: NBCMenuItemCurrent;
    settingsDict[NBCSettingsKeyboardLayoutKey] = _nbiKeyboardLayout ?: NBCMenuItemCurrent;
    settingsDict[NBCSettingsEnabledKey] = @(_nbiEnabled) ?: @NO;
    settingsDict[NBCSettingsDefaultKey] = @(_nbiDefault) ?: @NO;
    settingsDict[NBCSettingsDescriptionKey] = _nbiDescription ?: @"";
    if ( _destinationFolder != nil ) {
        NSString *currentUserHome = NSHomeDirectory();
        if ( [_destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [_destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolderPath ?: @"~/Desktop";
        } else {
            settingsDict[NBCSettingsDestinationFolderKey] = _destinationFolder ?: @"~/Desktop"; }
    }
    settingsDict[NBCSettingsIconKey] = _nbiIconPath ?: @"%APPLICATIONRESOURCESURL%/IconImagr.icns";
    settingsDict[NBCSettingsDisableWiFiKey] = @(_disableWiFi) ?: @NO;
    settingsDict[NBCSettingsDisableBluetoothKey] = @(_disableBluetooth) ?: @NO;
    settingsDict[NBCSettingsDisplaySleepMinutesKey] = @(_displaySleepMinutes) ?: @30;
    settingsDict[NBCSettingsDisplaySleepKey] = ( _displaySleepMinutes == 120 ) ? @NO : @YES;
    settingsDict[NBCSettingsIncludeSystemUIServerKey] = @(_includeSystemUIServer) ?: @NO;
    settingsDict[NBCSettingsImagrVersion] = _imagrVersion ?: NBCMenuItemImagrVersionLatest;
    settingsDict[NBCSettingsImagrConfigurationURL] = _imagrConfigurationURL ?: @"";
    settingsDict[NBCSettingsImagrReportingURL] = _imagrReportingURL ?: @"";
    settingsDict[NBCSettingsImagrUseLocalVersion] = @(_imagrUseLocalVersion) ?: @NO;
    settingsDict[NBCSettingsImagrLocalVersionPath] = _imagrLocalVersionPath ?: @"";
    settingsDict[NBCSettingsARDLoginKey] = _ardLogin ?: @"";
    settingsDict[NBCSettingsARDPasswordKey] = _ardPassword ?: @"";
    settingsDict[NBCSettingsUseNetworkTimeServerKey] = @(_useNetworkTimeServer) ?: @NO;
    settingsDict[NBCSettingsNetworkTimeServerKey] = _networkTimeServer ?: @"time.apple.com";
    settingsDict[NBCSettingsImagrSourceIsNBI] = @(_isNBI) ?: @NO;
    settingsDict[NBCSettingsUseBackgroundImageKey] = @(_useBackgroundImage) ?: @NO;
    settingsDict[NBCSettingsBackgroundImageKey] = _imageBackgroundURL ?: @"%SOURCEURL%/System/Library/CoreServices/DefaultDesktop.jpg";
    settingsDict[NBCSettingsUseVerboseBootKey] = @(_useVerboseBoot) ?: @NO;
    settingsDict[NBCSettingsImagrDisableATS] = @(_disableATS) ?: @NO;
    settingsDict[NBCSettingsDiskImageReadWriteKey] = @(_diskImageReadWrite) ?: @NO;
    settingsDict[NBCSettingsDiskImageReadWriteRenameKey] = @(_diskImageReadWriteRename) ?: @NO;
    settingsDict[NBCSettingsIncludeConsoleAppKey] = @(_includeConsoleApp) ?: @NO;
    settingsDict[NBCSettingsEnableLaunchdLoggingKey] = @(_enableLaunchdLogging) ?: @NO;
    settingsDict[NBCSettingsLaunchConsoleAppKey] = @(_launchConsoleApp) ?: @NO;
    settingsDict[NBCSettingsAddCustomRAMDisksKey] = @(_addCustomRAMDisks) ?: @NO;
    settingsDict[NBCSettingsImagrSyslogServerURI] = _imagrSyslogServerURI ?: @"";
    settingsDict[NBCSettingsIncludeRubyKey] = @(_includeRuby) ?: @NO;
    settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @(_addTrustedNetBootServers) ?: @NO;
    settingsDict[NBCSettingsImagrUseGitBranch] = @(_imagrUseGitBranch) ?: @NO;
    settingsDict[NBCSettingsImagrGitBranch] = _imagrGitBranch ?: @"";
    settingsDict[NBCSettingsImagrBuildTarget] = _imagrBuildTarget ?: @"";
    
    NSString *selectedGitBranch = [_popUpButtonImagrGitBranch titleOfSelectedItem];
    if ( [selectedGitBranch length] != 0 && [_imagrGitBranch length] != 0 ) {
        if ( ! [_imagrGitBranch isEqualToString:selectedGitBranch] ) {
            settingsDict[NBCSettingsImagrGitBranch] = selectedGitBranch ?: @"";
        }
    }
    
    NSString *selectedBuildTarget = [_popUpButtonImagrGitBranchBuildTarget titleOfSelectedItem];
    if ( [selectedBuildTarget length] != 0 && [_imagrBuildTarget length] != 0 ) {
        if ( ! [_imagrBuildTarget isEqualToString:selectedBuildTarget] ) {
            settingsDict[NBCSettingsImagrBuildTarget] = selectedBuildTarget ?: @"";
        }
    }
    
    NSMutableArray *certificateArray = [[NSMutableArray alloc] init];
    for ( NSDictionary *certificateDict in _certificateTableViewContents ) {
        NSData *certificateData = certificateDict[NBCDictionaryKeyCertificate];
        if ( certificateData != nil ) {
            [certificateArray insertObject:certificateData atIndex:0];
        }
    }
    settingsDict[NBCSettingsCertificatesKey] = certificateArray ?: @[];
    
    NSMutableArray *packageArray = [[NSMutableArray alloc] init];
    for ( NSDictionary *packageDict in _packagesTableViewContents ) {
        NSString *packagePath = packageDict[NBCDictionaryKeyPackagePath];
        if ( [packagePath length] != 0 ) {
            [packageArray insertObject:packagePath atIndex:0];
        }
    }
    settingsDict[NBCSettingsPackagesKey] = packageArray ?: @[];
    
    NSMutableArray *trustedNetBootServersArray = [[NSMutableArray alloc] init];
    for ( NSString *trustedNetBootServer in _trustedServers ) {
        if ( [trustedNetBootServer length] != 0 ) {
            [trustedNetBootServersArray insertObject:trustedNetBootServer atIndex:0];
        }
    }
    settingsDict[NBCSettingsTrustedNetBootServersKey] = trustedNetBootServersArray ?: @[];
    
    NSMutableArray *ramDisksArray = [[NSMutableArray alloc] init];
    for ( NSDictionary *ramDiskDict in _ramDisks ) {
        if ( [ramDiskDict count] != 0 ) {
            [ramDisksArray insertObject:ramDiskDict atIndex:0];
        }
    }
    settingsDict[NBCSettingsRAMDisksKey] = ramDisksArray ?: @[];
    
    NSString *selectedTimeZone;
    NSString *selectedTimeZoneCity = [_selectedMenuItem title];
    if ( [selectedTimeZoneCity isEqualToString:NBCMenuItemCurrent] ) {
        selectedTimeZone = selectedTimeZoneCity;
    } else {
        NSString *selectedTimeZoneRegion = [[_selectedMenuItem menu] title];
        selectedTimeZone = [NSString stringWithFormat:@"%@/%@", selectedTimeZoneRegion, selectedTimeZoneCity];
    }
    settingsDict[NBCSettingsTimeZoneKey] = selectedTimeZone ?: NBCMenuItemCurrent;
    
    return [settingsDict copy];
} // returnSettingsFromUI

- (void)createSettingsFromNBI:(NSURL *)nbiURL {
    
    NSError *err;
    
    DDLogDebug(@"[DEBUG] Creating template from NBI...");
    
    DDLogDebug(@"[DEBUG] NBI path: %@", [nbiURL path]);
    if ( ! [nbiURL checkResourceIsReachableAndReturnError:&err] ) {
        DDLogError(@"[ERROR] %@", [err localizedDescription]);
        return;
    }
    
    NSURL *nbImageInfoURL = [_source nbImageInfoURL];
    DDLogDebug(@"[DEBUG] NBImageInfo.plist path: %@", [nbImageInfoURL path]);
    if ( ! [nbImageInfoURL checkResourceIsReachableAndReturnError:&err] ) {
        DDLogError(@"[ERROR] %@", [err localizedDescription]);
        return;
    }
    
    NSDictionary *nbImageInfoDict = [[NSDictionary alloc] initWithContentsOfURL:nbImageInfoURL];
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    
    // -------------------------------------------------------------------------------
    //  Static Values
    // -------------------------------------------------------------------------------
    settingsDict[NBCSettingsImagrSourceIsNBI] = @YES;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrSourceIsNBI, settingsDict[NBCSettingsImagrSourceIsNBI]);
    
    settingsDict[NBCSettingsPackagesKey] = @[];
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsPackagesKey, settingsDict[NBCSettingsPackagesKey]);
    
    settingsDict[NBCSettingsEnableLaunchdLoggingKey] = @NO;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsEnableLaunchdLoggingKey, settingsDict[NBCSettingsEnableLaunchdLoggingKey]);
    
    settingsDict[NBCSettingsImagrDisableATS] = @NO;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrDisableATS, settingsDict[NBCSettingsImagrDisableATS]);
    
    // -------------------------------------------------------------------------------
    //  NBI Name
    // -------------------------------------------------------------------------------
    NSString *nbiName = nbImageInfoDict[NBCNBImageInfoDictNameKey];
    settingsDict[NBCSettingsNameKey] = nbiName ?: @"";
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsNameKey, settingsDict[NBCSettingsNameKey]);
    
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
        DDLogError(@"[ERROR] Index: Unknown value type: %@", [nbImageInfoDict[NBCNBImageInfoDictIndexKey] class] );
        return;
    }
    settingsDict[NBCSettingsIndexKey] = [nbiIndex stringValue] ?: NBCVariableIndexCounter;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsIndexKey, settingsDict[NBCSettingsIndexKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Protocol
    // -------------------------------------------------------------------------------
    NSString *nbiProtocol = nbImageInfoDict[NBCNBImageInfoDictProtocolKey];
    settingsDict[NBCSettingsProtocolKey] = nbiProtocol ?: @"NFS";
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsProtocolKey, settingsDict[NBCSettingsProtocolKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Language
    // -------------------------------------------------------------------------------
    NSString *nbiLanguage = nbImageInfoDict[NBCNBImageInfoDictLanguageKey];
    settingsDict[NBCSettingsLanguageKey] = ( [nbiLanguage isEqualToString:@"Default"] ) ? NBCMenuItemCurrent : nbiLanguage ?: NBCMenuItemCurrent ;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsLanguageKey, settingsDict[NBCSettingsLanguageKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Enabled
    // -------------------------------------------------------------------------------
    BOOL nbiEnabled = [nbImageInfoDict[NBCNBImageInfoDictIsEnabledKey] boolValue];
    settingsDict[NBCSettingsEnabledKey] = @(nbiEnabled) ?: @NO;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsEnabledKey, settingsDict[NBCSettingsEnabledKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Default
    // -------------------------------------------------------------------------------
    BOOL nbiDefault = [nbImageInfoDict[NBCNBImageInfoDictIsDefaultKey] boolValue];
    settingsDict[NBCSettingsDefaultKey] = @(nbiDefault) ?: @NO;
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDefaultKey, settingsDict[NBCSettingsDefaultKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Description
    // -------------------------------------------------------------------------------
    NSString *nbiDescription = nbImageInfoDict[NBCNBImageInfoDictDescriptionKey];
    settingsDict[NBCSettingsDescriptionKey] = nbiDescription ?: @"";
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDescriptionKey, settingsDict[NBCSettingsDescriptionKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Destination Folder
    // -------------------------------------------------------------------------------
    NSString *currentUserHome = NSHomeDirectory();
    if ( [nbiURL checkResourceIsReachableAndReturnError:nil] ) {
        NSString *destinationFolder = [nbiURL path];
        if ( [destinationFolder hasPrefix:currentUserHome] ) {
            NSString *destinationFolderPath = [destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolderPath ?: @"~/Desktop";
        } else {
            settingsDict[NBCSettingsDestinationFolderKey] = destinationFolder ?: @"~/Desktop";
        }
    } else {
        settingsDict[NBCSettingsDestinationFolderKey] = @"~/Desktop";
    }
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDestinationFolderKey, settingsDict[NBCSettingsDestinationFolderKey]);
    
    // -------------------------------------------------------------------------------
    //  NBI Icon
    // -------------------------------------------------------------------------------
    //NSImage *nbiIcon = [[NSWorkspace sharedWorkspace] iconForFile:[nbiURL path]]; // To be fixed later
    settingsDict[NBCSettingsIconKey] = _nbiIconPath ?: @"";
    DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsIconKey, settingsDict[NBCSettingsIconKey]);
    
    if ( _target ) {
        
        NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
        NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
        
        if ( [nbiNetInstallVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
            
            // -------------------------------------------------------------------------------
            //  NBI Creation Tool
            // -------------------------------------------------------------------------------
            settingsDict[NBCSettingsNBICreationToolKey] = NBCMenuItemSystemImageUtility;
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsNBICreationToolKey, NBCMenuItemSystemImageUtility);
            
            // -------------------------------------------------------------------------------
            //  Imagr.app Configuration
            // -------------------------------------------------------------------------------
            NSURL *nbiImagrConfigurationDictURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrConfigurationPlistTargetURL];
            DDLogDebug(@"[DEBUG] com.grahamgilbert.imagr.plist path: %@", [nbiImagrConfigurationDictURL path]);
            NSDictionary *nbiImagrConfigurationDict;
            if ( [nbiImagrConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
                nbiImagrConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiImagrConfigurationDictURL];
            }
            
            NSString *imagrConfigurationURL = nbiImagrConfigurationDict[NBCSettingsImagrServerURLKey];
            settingsDict[NBCSettingsImagrConfigurationURL] = imagrConfigurationURL ?: @"";
            settingsDict[NBCSettingsImagrSyslogServerURI] = nbiImagrConfigurationDict[NBCSettingsImagrSyslogServerURIKey] ?: @"";
            settingsDict[NBCSettingsImagrReportingURL] = nbiImagrConfigurationDict[NBCSettingsImagrReportingURLKey] ?: @"";
            if ( [imagrConfigurationURL length] != 0 ) {
                [_target setImagrConfigurationPlistURL:nbiImagrConfigurationDictURL];
            }
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrConfigurationURL, settingsDict[NBCSettingsImagrConfigurationURL]);
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrReportingURL, settingsDict[NBCSettingsImagrReportingURL]);
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrSyslogServerURI, settingsDict[NBCSettingsImagrSyslogServerURI]);
            
            // -------------------------------------------------------------------------------
            //  Imagr.app
            // -------------------------------------------------------------------------------
            NSURL *nbiApplicationURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCImagrApplicationTargetURL];
            NSString *nbiImagrVersion;
            if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
                nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            }
            
            if ( [nbiImagrVersion length] != 0 ) {
                [_target setImagrApplicationExistOnTarget:YES];
                [_target setImagrApplicationURL:nbiApplicationURL];
                settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion ?: @"";
            } else {
                settingsDict[NBCSettingsImagrVersion] = NBCMenuItemImagrVersionLatest;
            }
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrVersion, settingsDict[NBCSettingsImagrVersion]);
            
        } else if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
            
            // -------------------------------------------------------------------------------
            //  NBI Creation Tool
            // -------------------------------------------------------------------------------
            settingsDict[NBCSettingsNBICreationToolKey] = NBCMenuItemNBICreator;
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsNBICreationToolKey, NBCMenuItemNBICreator);
            
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
            settingsDict[NBCSettingsImagrSyslogServerURI] = nbiImagrConfigurationDict[NBCSettingsImagrSyslogServerURIKey] ?: @"";
            settingsDict[NBCSettingsImagrReportingURL] = nbiImagrConfigurationDict[NBCSettingsImagrReportingURLKey] ?: @"";
            if ( [imagrConfigurationURL length] != 0 ) {
                [_target setImagrConfigurationPlistURL:nbiImagrConfigurationDictURL];
            }
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrConfigurationURL, settingsDict[NBCSettingsImagrConfigurationURL]);
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrReportingURL, settingsDict[NBCSettingsImagrReportingURL]);
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrSyslogServerURI, settingsDict[NBCSettingsImagrSyslogServerURI]);
            
            // -------------------------------------------------------------------------------
            //  Imagr.app
            // -------------------------------------------------------------------------------
            NSURL *nbiApplicationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrApplicationNBICreatorTargetURL];
            NSString *nbiImagrVersion;
            if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
                nbiImagrVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
            }
            
            if ( [nbiImagrVersion length] != 0 ) {
                [_target setImagrApplicationExistOnTarget:YES];
                [_target setImagrApplicationURL:nbiApplicationURL];
                settingsDict[NBCSettingsImagrVersion] = nbiImagrVersion ?: @"";
            } else {
                settingsDict[NBCSettingsImagrVersion] = NBCMenuItemImagrVersionLatest;
            }
            DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrVersion, settingsDict[NBCSettingsImagrVersion]);
        }
        
        settingsDict[NBCSettingsImagrUseLocalVersion] = @NO;
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrUseLocalVersion, settingsDict[NBCSettingsImagrUseLocalVersion]);
        
        settingsDict[NBCSettingsImagrLocalVersionPath] = @"";
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrLocalVersionPath, settingsDict[NBCSettingsImagrLocalVersionPath]);
        
        settingsDict[NBCSettingsImagrUseGitBranch] = @NO;
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrUseGitBranch, settingsDict[NBCSettingsImagrUseGitBranch]);
        
        settingsDict[NBCSettingsImagrGitBranch] = @"Master";
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrGitBranch, settingsDict[NBCSettingsImagrGitBranch]);
        
        settingsDict[NBCSettingsImagrBuildTarget] = @"Release";
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsImagrBuildTarget, settingsDict[NBCSettingsImagrBuildTarget]);
        
        NSURL *comAppleBootPlistURL = [nbiURL URLByAppendingPathComponent:@"i386/com.apple.Boot.plist"];
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
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsUseVerboseBootKey, settingsDict[NBCSettingsUseVerboseBootKey]);
        
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
            settingsDict[NBCSettingsUseNetworkTimeServerKey] = @YES;
            settingsDict[NBCSettingsNetworkTimeServerKey] = ntpServer ?: @"time.apple.com";
        } else {
            settingsDict[NBCSettingsUseNetworkTimeServerKey] = @NO;
            settingsDict[NBCSettingsNetworkTimeServerKey] = @"time.apple.com";
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsUseNetworkTimeServerKey, settingsDict[NBCSettingsUseNetworkTimeServerKey]);
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsNetworkTimeServerKey, settingsDict[NBCSettingsNetworkTimeServerKey]);
        
        NSURL *consoleURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Applications/Utilities/Console.app"];
        if ( [consoleURL checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsIncludeConsoleAppKey] = @YES;
        } else {
            settingsDict[NBCSettingsIncludeConsoleAppKey] = @NO;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsIncludeConsoleAppKey, settingsDict[NBCSettingsIncludeConsoleAppKey]);
        
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
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsKeyboardLayoutKey, settingsDict[NBCSettingsKeyboardLayoutKey]);
        
        NSString *netInstallPath = [[nbiURL URLByAppendingPathComponent:@"NetInstall.dmg"] path];
        NSString *netInstallPathResolved = [netInstallPath stringByResolvingSymlink];
        if ( [netInstallPathResolved isEqualToString:netInstallPath] ) {
            settingsDict[NBCSettingsDiskImageReadWriteKey] = @NO;
        } else {
            settingsDict[NBCSettingsDiskImageReadWriteKey] = @YES;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDiskImageReadWriteKey, settingsDict[NBCSettingsDiskImageReadWriteKey]);
        
        settingsDict[NBCSettingsDiskImageReadWriteRenameKey] = @NO;
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDiskImageReadWriteRenameKey, settingsDict[NBCSettingsDiskImageReadWriteRenameKey]);
        
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
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsTimeZoneKey, settingsDict[NBCSettingsTimeZoneKey]);
        
        NSURL *nbiCreatorDesktopViewerURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Applications/NBICreatorDesktopViewer.app"];
        if ( [nbiCreatorDesktopViewerURL checkResourceIsReachableAndReturnError:nil] ) {
            NSURL *defaultDesktopURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/CoreServices/DefaultDesktop.jpg"];
            if ( [defaultDesktopURL checkResourceIsReachableAndReturnError:nil] ) {
                settingsDict[NBCSettingsUseBackgroundImageKey] = @YES;
                settingsDict[NBCSettingsBackgroundImageKey] = [defaultDesktopURL path];
            } else {
                settingsDict[NBCSettingsUseBackgroundImageKey] = @NO;
                settingsDict[NBCSettingsBackgroundImageKey] = NBCBackgroundImageDefaultPath;
            }
        } else {
            settingsDict[NBCSettingsUseBackgroundImageKey] = @NO;
            settingsDict[NBCSettingsBackgroundImageKey] = NBCBackgroundImageDefaultPath;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsUseBackgroundImageKey, settingsDict[NBCSettingsUseBackgroundImageKey]);
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsBackgroundImageKey, settingsDict[NBCSettingsBackgroundImageKey]);
        
        NSString *rcInstall;
        NSURL *rcInstallURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCImagrRCInstallTargetURL];
        if ( [rcInstallURL checkResourceIsReachableAndReturnError:nil] ) {
            rcInstall = [NSString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:&err];
        }
        
        NSString *rcImaging;
        NSURL *rcImagingURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCRCImagingTargetURL];
        if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
            rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
            
        } else {
            rcImagingURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCRCImagingNBICreatorTargetURL];
            if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
                rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
            }
        }
        
        if ( [rcImaging containsString:@"/Applications/Utilities/Console.app/Contents/MacOS/Console"] ) {
            settingsDict[NBCSettingsLaunchConsoleAppKey] = @YES;
        } else {
            settingsDict[NBCSettingsLaunchConsoleAppKey] = @NO;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsLaunchConsoleAppKey, settingsDict[NBCSettingsLaunchConsoleAppKey]);
        
        NSURL *systemUIServerLaunchdURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/LaunchDaemons/com.apple.SystemUIServer.plist"];
        if ( [systemUIServerLaunchdURL checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsIncludeSystemUIServerKey] = @YES;
        } else {
            settingsDict[NBCSettingsIncludeSystemUIServerKey] = @NO;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsIncludeSystemUIServerKey, settingsDict[NBCSettingsIncludeSystemUIServerKey]);
        
        [_target setRcImagingContent:rcImaging];
        [_target setRcImagingURL:rcImagingURL];
        
        NSString *rcFiles = [NSString stringWithFormat:@"%@\n%@", rcInstall, rcImaging];
        
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
                settingsDict[NBCSettingsDisplaySleepKey] = @NO;
                settingsDict[NBCSettingsDisplaySleepMinutesKey] = @120;
            } else {
                settingsDict[NBCSettingsDisplaySleepKey] = @YES;
                settingsDict[NBCSettingsDisplaySleepMinutesKey] = @([displaySleepTime intValue]);
            }
        } else {
            settingsDict[NBCSettingsDisplaySleepKey] = @YES;
            settingsDict[NBCSettingsDisplaySleepMinutesKey] = @30;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDisplaySleepKey, settingsDict[NBCSettingsDisplaySleepKey]);
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDisplaySleepMinutesKey, settingsDict[NBCSettingsDisplaySleepMinutesKey]);
        
        NSURL *ioBluetoothFamilyURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IOBluetoothFamily.kext"];
        if ( [ioBluetoothFamilyURL checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsDisableBluetoothKey] = @NO;
        } else {
            settingsDict[NBCSettingsDisableBluetoothKey] = @YES;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDisableBluetoothKey, settingsDict[NBCSettingsDisableBluetoothKey]);
        
        NSURL *rcCdmCdromURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"private/etc/rc.cdm.cdrom"];
        if ( [rcCdmCdromURL checkResourceIsReachableAndReturnError:nil] ) {
            NSString *rcCdmCdromContent = [NSString stringWithContentsOfURL:rcCdmCdromURL encoding:NSUTF8StringEncoding error:&err];
            __block BOOL inspectNextLine = NO;
            __block NSMutableArray *customRamDisks = [[NSMutableArray alloc] init];
            [rcCdmCdromContent enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
#pragma unused(stop)
                if ( inspectNextLine ) {
                    if ( [line hasPrefix:@"RAMDisk"] ) {
                        NSMutableArray *lineArray = [NSMutableArray arrayWithArray:[line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                        NSString *path = lineArray[1];
                        NSString *size = lineArray[2];
                        NSString *ramDiskSize = [[NSNumber numberWithInt:( [size intValue] / 1024 )] stringValue];
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
                settingsDict[NBCSettingsRAMDisksKey] = customRamDisks;
            } else {
                settingsDict[NBCSettingsAddCustomRAMDisksKey] = @NO;
                settingsDict[NBCSettingsRAMDisksKey] = @[];
            }
        } else {
            settingsDict[NBCSettingsAddCustomRAMDisksKey] = @NO;
            settingsDict[NBCSettingsRAMDisksKey] = @[];
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsAddCustomRAMDisksKey, settingsDict[NBCSettingsAddCustomRAMDisksKey]);
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsRAMDisksKey, settingsDict[NBCSettingsRAMDisksKey]);
        
        NSURL *bsdpSourcesURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/bsdpSources.txt"];
        if ( [bsdpSourcesURL checkResourceIsReachableAndReturnError:nil] ) {
            NSString *bsdpSourcesContent = [[NSString alloc] initWithContentsOfURL:bsdpSourcesURL encoding:NSUTF8StringEncoding error:&err];
            if ( [bsdpSourcesContent length] != 0 ) {
                NSMutableArray *bsdpArray = [[bsdpSourcesContent componentsSeparatedByString:@"\n"] mutableCopy];
                [bsdpArray removeObject:@""];
                settingsDict[NBCSettingsTrustedNetBootServersKey] = bsdpArray ?: @[];
                settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @YES;
            } else {
                settingsDict[NBCSettingsTrustedNetBootServersKey] = @[];
                settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @NO;
            }
        } else {
            settingsDict[NBCSettingsTrustedNetBootServersKey] = @[];
            settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @NO;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsAddTrustedNetBootServersKey, settingsDict[NBCSettingsAddTrustedNetBootServersKey]);
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsTrustedNetBootServersKey, settingsDict[NBCSettingsTrustedNetBootServersKey]);
        
        NSURL *rubyURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/bin/ruby"];
        if ( [rubyURL checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsIncludeRubyKey] = @YES;
        } else {
            settingsDict[NBCSettingsIncludeRubyKey] = @NO;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsIncludeRubyKey, settingsDict[NBCSettingsIncludeRubyKey]);
        
        NSURL *certificatesFolderURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"usr/local/certificates"];
        if ( ! [certificatesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            certificatesFolderURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:@"Packages/certificates"];
        }
        
        if ( [certificatesFolderURL checkResourceIsReachableAndReturnError:nil] ) {
            NSMutableArray *certificatesArray = [[NSMutableArray alloc] init];
            NSArray *certificates = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:certificatesFolderURL includingPropertiesForKeys:@[] options:0 error:&err];
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
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsCertificatesKey, settingsDict[NBCSettingsCertificatesKey]);
        
        NSURL *wifiKext = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
        if ( [wifiKext checkResourceIsReachableAndReturnError:nil] ) {
            settingsDict[NBCSettingsDisableWiFiKey] = @NO;
        } else {
            settingsDict[NBCSettingsDisableWiFiKey] = @YES;
        }
        DDLogDebug(@"[DEBUG] %@ = %@", NBCSettingsDisableWiFiKey, settingsDict[NBCSettingsDisableWiFiKey]);
        
        NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
        [helperConnector connectToHelper];
        
        [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                
                // ------------------------------------------------------------------
                //  If task failed, post workflow failed notification
                // ------------------------------------------------------------------
                DDLogError(@"[ERROR] %@", proxyError);
                [NBCDiskImageController detachDiskImageAtPath:[[self->_target baseSystemVolumeURL] path]];
            }];
            
        }] readSettingsFromNBI:nbiBaseSystemVolumeURL settingsDict:[settingsDict copy] withReply:^(NSError *error, BOOL success, NSDictionary *newSettingsDict) {
#pragma unused(newSettingsDict)
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if ( success ) {
                    [self setNbiSourceSettings:newSettingsDict];
                    [self updateUISettingsFromDict:newSettingsDict];
                    [self saveUISettingsWithName:nbiName atUrl:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.nbictemplate", NSTemporaryDirectory(), [[NSUUID UUID] UUIDString]]]]; // Temporary, to test
                    [self verifyBuildButton];
                    [self->_templates updateTemplateListForPopUpButton:self->_popUpButtonTemplates title:nbiName];
                    [NBCDiskImageController detachDiskImageAtPath:[[self->_target baseSystemVolumeURL] path]];
                } else {
                    DDLogError(@"[ERROR] %@", error);
                    [NBCDiskImageController detachDiskImageAtPath:[[self->_target baseSystemVolumeURL] path]];
                }
            }];
        }];
    }
} // returnSettingsFromUI

- (NSDictionary *)returnSettingsFromURL:(NSURL *)url {
    
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    NSDictionary *settingsDict;
    if ( mainDict ) {
        settingsDict = mainDict[NBCSettingsSettingsKey];
    }
    
    return settingsDict;
} // returnSettingsFromURL

- (void)saveUISettingsWithName:(NSString *)name atUrl:(NSURL *)url {
    
    NSURL *settingsURL = url;
    // -------------------------------------------------------------
    //  Create an empty dict and add template type, name and version
    // -------------------------------------------------------------
    NSMutableDictionary *mainDict = [[NSMutableDictionary alloc] init];
    mainDict[NBCSettingsTitleKey] = name;
    mainDict[NBCSettingsTypeKey] = NBCSettingsTypeImagr;
    mainDict[NBCSettingsVersionKey] = NBCSettingsFileVersion;
    
    // ----------------------------------------------------------------
    //  Get current UI settings and add to settings sub-dict
    // ----------------------------------------------------------------
    NSDictionary *settingsDict = [self returnSettingsFromUI];
    mainDict[NBCSettingsSettingsKey] = settingsDict;
    
    // -------------------------------------------------------------
    //  If no url was passed it means it's never been saved before.
    //  Create a new UUID and set 'settingsURL' to the new settings file
    // -------------------------------------------------------------
    if ( settingsURL == nil ) {
        NSString *uuid = [[NSUUID UUID] UUIDString];
        settingsURL = [_templatesFolderURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.nbictemplate", uuid]];
    }
    
    // -------------------------------------------------------------
    //  Create the template folder if it doesn't exist.
    // -------------------------------------------------------------
    NSError *error;
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    if ( ! [_templatesFolderURL checkResourceIsReachableAndReturnError:&error] ) {
        if ( ! [fm createDirectoryAtURL:_templatesFolderURL withIntermediateDirectories:YES attributes:nil error:&error] ) {
            DDLogError(@"[ERROR]: %@", [error localizedDescription]);

            // Should display error
            return;
        }
    }
    
    // -------------------------------------------------------------
    //  Write settings to url and update _templatesDict
    // -------------------------------------------------------------
    if ( [mainDict writeToURL:settingsURL atomically:NO] ) {
        _templatesDict[name] = settingsURL;
    } else {
        DDLogError(@"[ERROR] Writing Imagr template to disk failed!");
    }
} // saveUISettingsWithName:atUrl

- (BOOL)haveSettingsChanged {
    NSError *error = nil;
    BOOL retval = YES;
    NSURL *defaultSettingsURL = [[NSBundle mainBundle] URLForResource:NBCFileNameImagrDefaults withExtension:@"plist"];
    if ( [defaultSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        if ( [defaultSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *defaultSettings = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsURL];
            if ( [currentSettings count] != 0 && [defaultSettings count] != 0 ) {
                if ( [currentSettings isEqualToDictionary:defaultSettings] ) {
                    return NO;
                } else {
                    /*
                     NSArray *keys = [currentSettings allKeys];
                     for (NSString *key in keys) {
                     if ( ! [currentSettings[key] isEqualTo:defaultSettings[key]]) {
                     DDLogDebug(@"[DEBUG] Key \"%@\" has changed", key);
                     DDLogDebug(@"[DEBUG] Value from current UI settings: %@", currentSettings[key]);
                     DDLogDebug(@"[DEBUG] Value from default settings: %@", defaultSettings[key]);
                     }
                     }
                     */
                }
            }
        }
    }
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        return retval;
    }
    
    NSURL *savedSettingsURL = _templatesDict[_selectedTemplate];
    if ( [savedSettingsURL checkResourceIsReachableAndReturnError:&error] ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        NSDictionary *savedSettings = [self returnSettingsFromURL:savedSettingsURL];
        if ( currentSettings && savedSettings ) {
            if ( [currentSettings isEqualToDictionary:savedSettings] ) {
                retval = NO;
            }
        } else {
            DDLogError(@"[ERROR] Could not compare UI settings to saved template settings, one of them was empty!");
        }
    } else {
        DDLogError(@"[ERROR] %@", [error localizedDescription]);
    }
    
    return retval;
} // haveSettingsChanged

- (void)expandVariablesForCurrentSettings {
    
    // -------------------------------------------------------------
    //  Expand tilde in destination folder path
    // -------------------------------------------------------------
    if ( [_destinationFolder hasPrefix:@"~"] ) {
        NSString *destinationFolderPath = [_destinationFolder stringByExpandingTildeInPath];
        [self setDestinationFolder:destinationFolderPath];
    }
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Index
    // -------------------------------------------------------------
    NSString *nbiIndex = [NBCVariables expandVariables:_nbiIndex source:_source applicationSource:_siuSource];
    [_textFieldIndexPreview setStringValue:[NSString stringWithFormat:@"Index: %@", nbiIndex]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Name
    // -------------------------------------------------------------
    NSString *nbiName = [NBCVariables expandVariables:_nbiName source:_source applicationSource:_siuSource];
    [_textFieldNBINamePreview setStringValue:[NSString stringWithFormat:@"%@.nbi", nbiName]];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Description
    // -------------------------------------------------------------
    NSString *nbiDescription = [NBCVariables expandVariables:_nbiDescription source:_source applicationSource:_siuSource];
    [_textFieldNBIDescriptionPreview setStringValue:nbiDescription];
    
    // -------------------------------------------------------------
    //  Expand variables in NBI Icon Path
    // -------------------------------------------------------------
    NSString *nbiIconPath = [NBCVariables expandVariables:_nbiIconPath source:_source applicationSource:_siuSource];
    [self setNbiIcon:nbiIconPath];
    
    // -------------------------------------------------------------
    //  Expand variables in Image Background Path
    // -------------------------------------------------------------
    NSString *customBackgroundPath = [NBCVariables expandVariables:_imageBackgroundURL source:_source applicationSource:_siuSource];
    [self setImageBackground:@""];
    [self setImageBackground:[customBackgroundPath stringByResolvingSymlink]];
    
} // expandVariablesForCurrentSettings

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction Buttons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonChooseDestinationFolder:(id)sender {
#pragma unused(sender)
    
    NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [chooseDestionation setTitle:@"Choose Destination Folder"];
    [chooseDestionation setPrompt:@"Choose"];
    [chooseDestionation setCanChooseFiles:NO];
    [chooseDestionation setCanChooseDirectories:YES];
    [chooseDestionation setCanCreateDirectories:YES];
    [chooseDestionation setAllowsMultipleSelection:NO];
    
    if ( [chooseDestionation runModal] == NSModalResponseOK ) {
        // -------------------------------------------------------------------------
        //  Get first item in URL array returned (should only be one) and update UI
        // -------------------------------------------------------------------------
        NSArray* selectedURLs = [chooseDestionation URLs];
        NSURL* selectedURL = [selectedURLs firstObject];
        [self setDestinationFolder:[selectedURL path]];
    }
} // buttonChooseDestinationFolder

- (IBAction)buttonPopOver:(id)sender {
    [self updatePopOver];
    [_popOverVariables showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
} // buttonPopOver

- (IBAction)buttonInstallXcode:(id)sender {
#pragma unused(sender)
    NSString *xcodeLink = @"macappstore://itunes.apple.com/app/id497799835";
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:xcodeLink]];
}

- (IBAction)buttonAddCertificate:(id)sender {
#pragma unused(sender)
    NSOpenPanel* addCertificates = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [addCertificates setTitle:@"Add Certificates"];
    [addCertificates setPrompt:@"Add"];
    [addCertificates setCanChooseFiles:YES];
    [addCertificates setAllowedFileTypes:@[ @"public.x509-certificate" ]];
    [addCertificates setCanChooseDirectories:NO];
    [addCertificates setCanCreateDirectories:YES];
    [addCertificates setAllowsMultipleSelection:YES];
    
    if ( [addCertificates runModal] == NSModalResponseOK ) {
        NSArray* selectedURLs = [addCertificates URLs];
        for ( NSURL *certificateURL in selectedURLs ) {
            NSData *certificateData = [[NSData alloc] initWithContentsOfURL:certificateURL];
            NSDictionary *certificateDict = [self examineCertificate:certificateData];
            if ( [certificateDict count] != 0 ) {
                [self insertCertificateInTableView:certificateDict];
            }
        }
    }
}

- (IBAction)buttonRemoveCertificate:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewCertificates selectedRowIndexes];
    [_certificateTableViewContents removeObjectsAtIndexes:indexes];
    [_tableViewCertificates removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    if ( [_certificateTableViewContents count] == 0 ) {
        [_viewOverlayCertificates setHidden:NO];
    }
    //[_tableViewCertificates reloadData];
}

- (IBAction)buttonAddPackage:(id)sender {
#pragma unused(sender)
    NSOpenPanel* addPackages = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [addPackages setTitle:@"Add Packages"];
    [addPackages setPrompt:@"Add"];
    [addPackages setCanChooseFiles:YES];
    [addPackages setAllowedFileTypes:@[ @"com.apple.installer-package-archive" ]];
    [addPackages setCanChooseDirectories:NO];
    [addPackages setCanCreateDirectories:YES];
    [addPackages setAllowsMultipleSelection:YES];
    
    if ( [addPackages runModal] == NSModalResponseOK ) {
        NSArray* selectedURLs = [addPackages URLs];
        for ( NSURL *packageURL in selectedURLs ) {
            NSDictionary *packageDict = [self examinePackageAtURL:packageURL];
            if ( [packageDict count] != 0 ) {
                [self insertPackageInTableView:packageDict];
            }
        }
    }
}

- (IBAction)buttonRemovePackage:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewPackages selectedRowIndexes];
    [_packagesTableViewContents removeObjectsAtIndexes:indexes];
    [_tableViewPackages removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    if ( [_packagesTableViewContents count] == 0 ) {
        [_viewOverlayPackages setHidden:NO];
    }
    //[_tableViewPackages reloadData];
}

- (IBAction)buttonChooseImagrLocalPath:(id)sender {
#pragma unused(sender)
    NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [chooseDestionation setTitle:@"Select Imagr Application"];
    [chooseDestionation setPrompt:@"Choose"];
    [chooseDestionation setCanChooseFiles:YES];
    [chooseDestionation setAllowedFileTypes:@[ @"com.apple.application-bundle" ]];
    [chooseDestionation setCanChooseDirectories:NO];
    [chooseDestionation setCanCreateDirectories:NO];
    [chooseDestionation setAllowsMultipleSelection:NO];
    
    if ( [chooseDestionation runModal] == NSModalResponseOK ) {
        // -------------------------------------------------------------------------
        //  Get first item in URL array returned (should only be one) and update UI
        // -------------------------------------------------------------------------
        NSArray* selectedURLs = [chooseDestionation URLs];
        NSURL* selectedURL = [selectedURLs firstObject];
        NSBundle *bundle = [NSBundle bundleWithURL:selectedURL];
        if ( bundle != nil ) {
            NSString *bundleIdentifier = [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
            if ( [bundleIdentifier isEqualToString:NBCImagrBundleIdentifier] ) {
                [self setImagrLocalVersionPath:[selectedURL path]];
                return;
            }
        }
        [NBCAlerts showAlertUnrecognizedImagrApplication];
    }
    
} // buttonChooseImagrLocalPath

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Other
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopOver {
    NSString *separator = @";";
    NSString *variableString = [NSString stringWithFormat:@"%%OSVERSION%%%@"
                                "%%OSMAJOR%%%@"
                                "%%OSMINOR%%%@"
                                "%%OSPATCH%%%@"
                                "%%OSBUILD%%%@"
                                "%%DATE%%%@"
                                "%%OSINDEX%%%@"
                                "%%NBCVERSION%%%@"
                                ,separator, separator, separator, separator, separator, separator, separator, separator
                                ];
    NSString *expandedVariables = [NBCVariables expandVariables:variableString source:_source applicationSource:_siuSource];
    NSArray *expandedVariablesArray = [expandedVariables componentsSeparatedByString:separator];
    
    // %OSVERSION%
    if ( 1 <= [expandedVariablesArray count] ) {
        NSString *osVersion = expandedVariablesArray[0];
        if ( [osVersion length] != 0 ) {
            [self setPopOverOSVersion:osVersion];
        }
    }
    // %OSMAJOR%
    if ( 2 <= [expandedVariablesArray count] ) {
        NSString *osMajor = expandedVariablesArray[1];
        if ( [osMajor length] != 0 ) {
            [self setPopOverOSMajor:osMajor];
        }
    }
    // %OSMINOR%
    if ( 3 <= [expandedVariablesArray count] ) {
        NSString *osMinor = expandedVariablesArray[2];
        if ( [osMinor length] != 0 ) {
            [self setPopOverOSMinor:osMinor];
        }
    }
    // %OSPATCH%
    if ( 4 <= [expandedVariablesArray count] ) {
        NSString *osPatch = expandedVariablesArray[3];
        if ( [osPatch length] != 0 ) {
            [self setPopOverOSPatch:osPatch];
        }
    }
    // %OSBUILD%
    if ( 5 <= [expandedVariablesArray count] ) {
        NSString *osBuild = expandedVariablesArray[4];
        if ( [osBuild length] != 0 ) {
            [self setPopOverOSBuild:osBuild];
        }
    }
    // %DATE%
    if ( 6 <= [expandedVariablesArray count] ) {
        NSString *date = expandedVariablesArray[5];
        if ( [date length] != 0 ) {
            [self setPopOverDate:date];
        }
    }
    // %OSINDEX%
    if ( 7 <= [expandedVariablesArray count] ) {
        NSString *osIndex = expandedVariablesArray[6];
        if ( [osIndex length] != 0 ) {
            [self setPopOverOSIndex:osIndex];
        }
    }
    // %NBCVERSION%
    if ( 8 <= [expandedVariablesArray count] ) {
        NSString *nbcVersion = expandedVariablesArray[7];
        if ( [nbcVersion length] != 0 ) {
            [self setNbcVersion:nbcVersion];
        }
    }
    // %COUNTER%
    [self setPopOverIndexCounter:[[[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsIndexCounter] stringValue]];
    // %SIUVERSION%
    [self setSiuVersion:[_siuSource systemImageUtilityVersion]];
} // updatePopOver

- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo {
    NSLog(@"Importing %@", url);
    NSLog(@"templateInfo=%@", templateInfo);
} // importTemplateAtURL

- (void)checkIfXcodeIsInstalled {
    _xcodeInstalled = [NBCXcodeSource isInstalled];
} // checkIfXcodeIsInstalled

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark UI Updates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)showSystemImageUtilityVersion {
    [self setUseSystemImageUtility:YES];
    [_constraintTemplatesBoxHeight setConstant:93];
    [_constraintSavedTemplatesToTool setConstant:32];
} // showImagrLocalVersionInput

- (void)hideSystemImageUtilityVersion {
    [self setUseSystemImageUtility:NO];
    [_constraintTemplatesBoxHeight setConstant:70];
    [_constraintSavedTemplatesToTool setConstant:8];
} // hideImagrLocalVersionInput

- (void)showImagrBranchSelection {
    [self setImagrUseLocalVersion:NO];
    [self setImagrUseGitBranch:YES];
    [_constraintConfigurationURLToImagrVersion setConstant:42];
    [_textFieldImagrLocalPathLabel setHidden:YES];
    [_textFieldImagrLocalPath setHidden:YES];
    [_buttonChooseImagrLocalPath setHidden:YES];
    [_textFieldImagrGitBranchLabel setHidden:NO];
    [_popUpButtonImagrGitBranch setHidden:NO];
    [_textFieldImagrGitBranchBuildTargetLabel setHidden:NO];
    [_popUpButtonImagrGitBranchBuildTarget setHidden:NO];
    if ( ! _xcodeInstalled ) {
        [_buttonInstallXcode setHidden:NO];
        [[_buttonInstallXcode window] makeFirstResponder:_buttonInstallXcode];
        [_textFieldImagrGitBranchLabel setEnabled:NO];
        [_popUpButtonImagrGitBranch setEnabled:NO];
        [_textFieldImagrGitBranchBuildTargetLabel setEnabled:NO];
        [_popUpButtonImagrGitBranchBuildTarget setEnabled:NO];
    } else {
        [_textFieldImagrGitBranchLabel setEnabled:YES];
        [_popUpButtonImagrGitBranch setEnabled:YES];
        [_textFieldImagrGitBranchBuildTargetLabel setEnabled:YES];
        [_popUpButtonImagrGitBranchBuildTarget setEnabled:YES];
    }
} // showImagrBranchSelection

- (void)hideImagrBranchSelection {
    [self setImagrUseLocalVersion:NO];
    [self setImagrUseGitBranch:NO];
    [_constraintConfigurationURLToImagrVersion setConstant:13];
    [_textFieldImagrLocalPathLabel setHidden:YES];
    [_textFieldImagrLocalPath setHidden:YES];
    [_buttonChooseImagrLocalPath setHidden:YES];
    [_textFieldImagrGitBranchLabel setHidden:YES];
    [_popUpButtonImagrGitBranch setHidden:YES];
    [_textFieldImagrGitBranchBuildTargetLabel setHidden:YES];
    [_popUpButtonImagrGitBranchBuildTarget setHidden:YES];
    [_buttonInstallXcode setHidden:YES];
} // hideImagrBranchSelection

- (void)showImagrLocalVersionInput {
    [self setImagrUseLocalVersion:YES];
    [self setImagrUseGitBranch:NO];
    [_constraintConfigurationURLToImagrVersion setConstant:42];
    [_textFieldImagrLocalPathLabel setHidden:NO];
    [_textFieldImagrLocalPath setHidden:NO];
    [_buttonChooseImagrLocalPath setHidden:NO];
    [_textFieldImagrGitBranchLabel setHidden:YES];
    [_popUpButtonImagrGitBranch setHidden:YES];
    [_textFieldImagrGitBranchBuildTargetLabel setHidden:YES];
    [_popUpButtonImagrGitBranchBuildTarget setHidden:YES];
    [_buttonInstallXcode setHidden:YES];
} // showImagrLocalVersionInput

- (void)hideImagrLocalVersionInput {
    [self setImagrUseLocalVersion:NO];
    [self setImagrUseGitBranch:NO];
    [_constraintConfigurationURLToImagrVersion setConstant:13];
    [_textFieldImagrLocalPathLabel setHidden:YES];
    [_textFieldImagrLocalPath setHidden:YES];
    [_buttonChooseImagrLocalPath setHidden:YES];
    [_textFieldImagrGitBranchLabel setHidden:YES];
    [_popUpButtonImagrGitBranch setHidden:YES];
    [_textFieldImagrGitBranchBuildTargetLabel setHidden:YES];
    [_popUpButtonImagrGitBranchBuildTarget setHidden:YES];
    [_buttonInstallXcode setHidden:YES];
} // hideImagrLocalVersionInput

- (void)addOverlayViewToView:(NSView *)view overlayView:(NSView *)overlayView {
    [view addSubview:overlayView positioned:NSWindowAbove relativeTo:nil];
    [overlayView setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSArray *constraintsArray;
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|-1-[overlayView]-1-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(overlayView)];
    [view addConstraints:constraintsArray];
    constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-1-[overlayView]-1-|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(overlayView)];
    [view addConstraints:constraintsArray];
    [view setHidden:NO];
} // addOverlayViewToView:overlayView

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Templates
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopUpButtonTemplates {
    [_templates updateTemplateListForPopUpButton:_popUpButtonTemplates title:nil];
} // updatePopUpButtonTemplates

- (IBAction)popUpButtonTemplates:(id)sender {
    NSString *selectedTemplate = [[sender selectedItem] title];
    BOOL settingsChanged = [self haveSettingsChanged];
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        [_templates showSheetSaveUntitled:selectedTemplate buildNBI:NO preWorkflowTasks:@{}];
        return;
    } else if ( settingsChanged ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsUnsaved,
                                     NBCAlertUserInfoSelectedTemplate : selectedTemplate };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsaved:@"You have unsaved settings, do you want to discard changes and continue?"
                              alertInfo:alertInfo];
    } else {
        [self setSelectedTemplate:[[sender selectedItem] title]];
        [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
    }
} // popUpButtonTemplates

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton NBI Creation Tool
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)uppdatePopUpButtonTool {
    NSString *systemUtilityVersion = [_siuSource systemImageUtilityVersion];
    if ( [systemUtilityVersion length] != 0 ) {
        [_textFieldSIUVersionString setStringValue:systemUtilityVersion];
    } else {
        [_textFieldSIUVersionString setStringValue:@"Not Installed"];
    }
    
    if ( _popUpButtonTool ) {
        [_popUpButtonTool removeAllItems];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemNBICreator];
        [_popUpButtonTool addItemWithTitle:NBCMenuItemSystemImageUtility];
        [_popUpButtonTool selectItemWithTitle:_nbiCreationTool];
        [self setNbiCreationTool:[_popUpButtonTool titleOfSelectedItem]];
    }
} // uppdatePopUpButtonTool

- (IBAction)popUpButtonTool:(id)sender {
    NSString *selectedVersion = [[sender selectedItem] title];
    if ( [selectedVersion isEqualToString:NBCMenuItemSystemImageUtility] ) {
        [self showSystemImageUtilityVersion];
        if ( [_nbiDescription isEqualToString:NBCNBIDescriptionNBC] ) {
            [self setNbiDescription:NBCNBIDescriptionSIU];
        }
        
        [self expandVariablesForCurrentSettings];
    } else {
        [self hideSystemImageUtilityVersion];
        if ( [_nbiDescription isEqualToString:NBCNBIDescriptionSIU] ) {
            [self setNbiDescription:NBCNBIDescriptionNBC];
        }
        
        [self expandVariablesForCurrentSettings];
    }
} // popUpButtonTool

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton TimeZone
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)populatePopUpButtonTimeZone {
    [self setTimeZoneArray:[NSTimeZone knownTimeZoneNames]];
    if ( [_timeZoneArray count] != 0 ) {
        NSMenu *menuAfrica = [[NSMenu alloc] initWithTitle:@"Africa"];
        [menuAfrica setAutoenablesItems:NO];
        NSMenu *menuAmerica = [[NSMenu alloc] initWithTitle:@"America"];
        [menuAmerica setAutoenablesItems:NO];
        NSMenu *menuAntarctica = [[NSMenu alloc] initWithTitle:@"Antarctica"];
        [menuAntarctica setAutoenablesItems:NO];
        NSMenu *menuArctic = [[NSMenu alloc] initWithTitle:@"Arctic"];
        [menuArctic setAutoenablesItems:NO];
        NSMenu *menuAsia = [[NSMenu alloc] initWithTitle:@"Asia"];
        [menuAsia setAutoenablesItems:NO];
        NSMenu *menuAtlantic = [[NSMenu alloc] initWithTitle:@"Atlantic"];
        [menuAtlantic setAutoenablesItems:NO];
        NSMenu *menuAustralia = [[NSMenu alloc] initWithTitle:@"Australia"];
        [menuAustralia setAutoenablesItems:NO];
        NSMenu *menuEurope = [[NSMenu alloc] initWithTitle:@"Europe"];
        [menuEurope setAutoenablesItems:NO];
        NSMenu *menuIndian = [[NSMenu alloc] initWithTitle:@"Indian"];
        [menuIndian setAutoenablesItems:NO];
        NSMenu *menuPacific = [[NSMenu alloc] initWithTitle:@"Pacific"];
        [menuPacific setAutoenablesItems:NO];
        for ( NSString *timeZoneName in _timeZoneArray ) {
            if ( [timeZoneName isEqualToString:@"GMT"] ) {
                continue;
            }
            
            NSArray *timeZone = [timeZoneName componentsSeparatedByString:@"/"];
            NSString *timeZoneRegion = timeZone[0];
            __block NSString *timeZoneCity = @"";
            if ( 2 < [timeZone count] ) {
                NSRange range;
                range.location = 1;
                range.length = ( [timeZone count] -1 );
                [timeZone enumerateObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] options:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(idx,stop)
                    if ( [timeZoneCity length] == 0 ) {
                        timeZoneCity = obj;
                    } else {
                        timeZoneCity = [NSString stringWithFormat:@"%@/%@", timeZoneCity, obj];
                    }
                }];
            } else {
                timeZoneCity = timeZone[1];
            }
            
            NSMenuItem *cityMenuItem = [[NSMenuItem alloc] initWithTitle:timeZoneCity action:@selector(selectTimeZone:) keyEquivalent:@""];
            [cityMenuItem setEnabled:YES];
            [cityMenuItem setTarget:self];
            
            if ( [timeZoneRegion isEqualToString:@"Africa"] ) {
                [menuAfrica addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"America"] ) {
                [menuAmerica addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Antarctica"] ) {
                [menuAntarctica addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Arctic"] ) {
                [menuArctic addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Asia"] ) {
                [menuAsia addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Atlantic"] ) {
                [menuAtlantic addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Australia"] ) {
                [menuAustralia addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Europe"] ) {
                [menuEurope addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Indian"] ) {
                [menuIndian addItem:cityMenuItem];
            } else if ( [timeZoneRegion isEqualToString:@"Pacific"] ) {
                [menuPacific addItem:cityMenuItem];
            }
        }
        
        [_popUpButtonTimeZone removeAllItems];
        [_popUpButtonTimeZone setAutoenablesItems:NO];
        [_popUpButtonTimeZone addItemWithTitle:NBCMenuItemCurrent];
        [[_popUpButtonTimeZone menu] addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *menuItemAfrica = [[NSMenuItem alloc] initWithTitle:@"Africa" action:nil keyEquivalent:@""];
        [menuItemAfrica setSubmenu:menuAfrica];
        [menuItemAfrica setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAfrica];
        
        NSMenuItem *menuItemAmerica = [[NSMenuItem alloc] initWithTitle:@"America" action:nil keyEquivalent:@""];
        [menuItemAmerica setSubmenu:menuAmerica];
        [menuItemAmerica setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAmerica];
        
        NSMenuItem *menuItemAntarctica = [[NSMenuItem alloc] initWithTitle:@"Antarctica" action:nil keyEquivalent:@""];
        [menuItemAntarctica setSubmenu:menuAntarctica];
        [menuItemAntarctica setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAntarctica];
        
        NSMenuItem *menuItemArctic = [[NSMenuItem alloc] initWithTitle:@"Arctic" action:nil keyEquivalent:@""];
        [menuItemArctic setSubmenu:menuArctic];
        [menuItemArctic setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemArctic];
        
        NSMenuItem *menuItemAsia = [[NSMenuItem alloc] initWithTitle:@"Asia" action:nil keyEquivalent:@""];
        [menuItemAsia setSubmenu:menuAsia];
        [menuItemAsia setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAsia];
        
        NSMenuItem *menuItemAtlantic = [[NSMenuItem alloc] initWithTitle:@"Atlantic" action:nil keyEquivalent:@""];
        [menuItemAtlantic setSubmenu:menuAtlantic];
        [menuItemAtlantic setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAtlantic];
        
        NSMenuItem *menuItemAustralia = [[NSMenuItem alloc] initWithTitle:@"Australia" action:nil keyEquivalent:@""];
        [menuItemAustralia setSubmenu:menuAustralia];
        [menuItemAustralia setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemAustralia];
        
        NSMenuItem *menuItemEurope = [[NSMenuItem alloc] initWithTitle:@"Europe" action:nil keyEquivalent:@""];
        [menuItemEurope setSubmenu:menuEurope];
        [menuItemEurope setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemEurope];
        
        NSMenuItem *menuItemIndian = [[NSMenuItem alloc] initWithTitle:@"Indian" action:nil keyEquivalent:@""];
        [menuItemIndian setSubmenu:menuIndian];
        [menuItemIndian setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemIndian];
        
        NSMenuItem *menuItemPacific = [[NSMenuItem alloc] initWithTitle:@"Pacific" action:nil keyEquivalent:@""];
        [menuItemPacific setSubmenu:menuPacific];
        [menuItemPacific setTarget:self];
        [[_popUpButtonTimeZone menu] addItem:menuItemPacific];
        
        [self setSelectedMenuItem:[_popUpButtonTimeZone selectedItem]];
    } else {
        DDLogError(@"[ERROR] Could not find language strings file!");
    }
}

- (void)selectTimeZone:(id)sender {
    if ( ! [sender isKindOfClass:[NSMenuItem class]] ) {
        return;
    }
    
    [_selectedMenuItem setState:NSOffState];
    
    _selectedMenuItem = (NSMenuItem *)sender;
    [_selectedMenuItem setState:NSOnState];
    
    NSMenuItem *newMenuItem = [_selectedMenuItem copy];
    
    NSInteger selectedMenuItemIndex = [_popUpButtonTimeZone indexOfSelectedItem];
    
    if ( selectedMenuItemIndex == 0 ) {
        if ( ! [[_popUpButtonTimeZone itemAtIndex:1] isSeparatorItem] ) {
            [_popUpButtonTimeZone removeItemAtIndex:1];
        }
    } else {
        [_popUpButtonTimeZone removeItemAtIndex:selectedMenuItemIndex];
    }
    
    for ( NSMenuItem *menuItem in [[_popUpButtonTimeZone menu] itemArray] ) {
        if ( [[menuItem title] isEqualToString:NBCMenuItemCurrent] ) {
            [_popUpButtonTimeZone removeItemWithTitle:NBCMenuItemCurrent];
            break;
        }
    }
    [[_popUpButtonTimeZone menu] insertItem:newMenuItem atIndex:0];
    
    if ( ! [[_selectedMenuItem title] isEqualToString:NBCMenuItemCurrent] ) {
        [[_popUpButtonTimeZone menu] insertItemWithTitle:NBCMenuItemCurrent action:@selector(selectTimeZone:) keyEquivalent:@"" atIndex:0];
    }
    [_popUpButtonTimeZone selectItem:newMenuItem];
}

- (NSString *)timeZoneFromMenuItem:(NSMenuItem *)menuItem {
    NSString *timeZone;
    
    NSString *selectedTimeZoneCity = [menuItem title];
    if ( [selectedTimeZoneCity isEqualToString:NBCMenuItemCurrent] ) {
        timeZone = selectedTimeZoneCity;
    } else {
        NSString *selectedTimeZoneRegion = [[menuItem menu] title];
        timeZone = [NSString stringWithFormat:@"%@/%@", selectedTimeZoneRegion, selectedTimeZoneCity];
    }
    
    return timeZone;
} // timeZoneFromMenuItem

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Language
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)populatePopUpButtonLanguage {
    NSError *error;
    NSURL *languageStringsFile = [NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/IntlPreferences.framework/Versions/A/Resources/Language.strings"];
    if ( [languageStringsFile checkResourceIsReachableAndReturnError:&error] ) {
        _languageDict = [[NSDictionary dictionaryWithContentsOfURL:languageStringsFile] mutableCopy];
        NSArray *languageArray = [[_languageDict allValues] sortedArrayUsingSelector:@selector(compare:)];
        [_popUpButtonLanguage removeAllItems];
        [_popUpButtonLanguage addItemWithTitle:NBCMenuItemCurrent];
        [[_popUpButtonLanguage menu] addItem:[NSMenuItem separatorItem]];
        [_popUpButtonLanguage addItemsWithTitles:languageArray];
    } else {
        DDLogError(@"[ERROR] Could not find language strings file!");
        DDLogError(@"%@", error);
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton KeyboardLayout
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)populatePopUpButtonKeyboardLayout {
    NSDictionary *ref = @{
                          (NSString *)kTISPropertyInputSourceType : (NSString *)kTISTypeKeyboardLayout
                          };
    
    CFArrayRef sourceList = TISCreateInputSourceList ((__bridge CFDictionaryRef)(ref),true);
    for (int i = 0; i < CFArrayGetCount(sourceList); ++i) {
        TISInputSourceRef source = (TISInputSourceRef)(CFArrayGetValueAtIndex(sourceList, i));
        if ( ! source) continue;
        
        NSString* sourceID = (__bridge NSString *)(TISGetInputSourceProperty(source, kTISPropertyInputSourceID));
        NSString* localizedName = (__bridge NSString *)(TISGetInputSourceProperty(source, kTISPropertyLocalizedName));
        
        _keyboardLayoutDict[localizedName] = sourceID;
    }
    
    NSArray *keyboardLayoutArray = [[_keyboardLayoutDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
    [_popUpButtonKeyboardLayout removeAllItems];
    [_popUpButtonKeyboardLayout addItemWithTitle:NBCMenuItemCurrent];
    [[_popUpButtonKeyboardLayout menu] addItem:[NSMenuItem separatorItem]];
    [_popUpButtonKeyboardLayout addItemsWithTitles:keyboardLayoutArray];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Imagr Versions
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopUpButtonImagrVersions {
    if ( _popUpButtonImagrVersion ) {
        [_popUpButtonImagrVersion removeAllItems];
        [_popUpButtonImagrVersion addItemWithTitle:NBCMenuItemImagrVersionLatest];
        NSMenuItem *menuItemVersionLocal = [[NSMenuItem alloc] init];
        [menuItemVersionLocal setTitle:NBCMenuItemImagrVersionLocal];
        [menuItemVersionLocal setTarget:self];
        [[_popUpButtonImagrVersion menu] addItem:menuItemVersionLocal];
        NSMenuItem *menuItemBranches = [[NSMenuItem alloc] init];
        [menuItemBranches setTitle:NBCMenuItemGitBranch];
        [menuItemBranches setTarget:self];
        [[_popUpButtonImagrVersion menu] addItem:menuItemBranches];
        [[_popUpButtonImagrVersion menu] addItem:[NSMenuItem separatorItem]];
        [_popUpButtonImagrVersion addItemsWithTitles:_imagrVersions];
        [_popUpButtonImagrVersion selectItemWithTitle:_imagrVersion];
        [self setImagrVersion:[_popUpButtonImagrVersion titleOfSelectedItem]];
    }
    
    [_imageViewNetworkWarning setHidden:YES];
    [_textFieldNetworkWarning setHidden:YES];
} // updatePopUpButtonImagrVersions

- (void)updatePopUpButtonImagrVersionsLocal {
    if ( ! _resourcesController ) {
        [self setResourcesController:[[NBCWorkflowResourcesController alloc] init]];
    }
    
    [_popUpButtonImagrVersion removeAllItems];
    [_popUpButtonImagrVersion addItemWithTitle:NBCMenuItemImagrVersionLatest];
    NSMenuItem *menuItemVersionLocal = [[NSMenuItem alloc] init];
    [menuItemVersionLocal setTitle:NBCMenuItemImagrVersionLocal];
    [menuItemVersionLocal setTarget:self];
    [[_popUpButtonImagrVersion menu] addItem:menuItemVersionLocal];
    [[_popUpButtonImagrVersion menu] addItem:[NSMenuItem separatorItem]];
    [[_popUpButtonImagrVersion menu] setAutoenablesItems:NO];
    
    NSArray *localImagrVersions = [_resourcesController cachedVersionsFromResourceFolder:NBCFolderResourcesCacheImagr];
    NSDictionary *cachedDownloadsDict = [_resourcesController cachedDownloadsDictFromResourceFolder:NBCFolderResourcesCacheImagr];
    if ( cachedDownloadsDict != nil ) {
        [self setImagrVersionsDownloadLinks:cachedDownloadsDict];
        NSArray *cachedDownloadVersions = [cachedDownloadsDict allKeys];
        BOOL cachedVersionAvailable = NO;
        for ( NSString *version in cachedDownloadVersions ) {
            NSMenuItem *versionItem = [[NSMenuItem alloc] init];
            [versionItem setTitle:version];
            if ( [localImagrVersions containsObject:version] ) {
                cachedVersionAvailable = YES;
                [versionItem setEnabled:YES];
            } else {
                [versionItem setEnabled:NO];
            }
            [[_popUpButtonImagrVersion menu] addItem:versionItem];
        }
        if ( ! cachedVersionAvailable ) {
            NSMenuItem *latestVersionMenuItem = [[_popUpButtonImagrVersion menu] itemWithTitle:NBCMenuItemImagrVersionLatest];
            [latestVersionMenuItem setEnabled:NO];
            // Add check what segmented control is selected, only show when Imagr is selected. Queue notifications, how?
            [NBCAlerts showAlertOKWithTitle:@"No Cached Versions Available" informativeText:@"Until you connect to the internet, only local version of Imagr.app can be used to create an Imagr NBI."];
        }
    }
    
    [_imageViewNetworkWarning setHidden:NO];
    [_textFieldNetworkWarning setHidden:NO];
}

- (void)updateCachedImagrVersions:(NSDictionary *)imagrVersionsDict {
    if ( ! _resourcesController ) {
        [self setResourcesController:[[NBCWorkflowResourcesController alloc] init]];
    }
    
    NSURL *imagrDownloadsDictURL = [_resourcesController cachedDownloadsDictURLFromResourceFolder:NBCFolderResourcesCacheImagr];
    if ( imagrDownloadsDictURL != nil ) {
        NSURL *imagrResourceFolder = [_resourcesController urlForResourceFolder:NBCFolderResourcesCacheImagr];
        if ( ! [imagrResourceFolder checkResourceIsReachableAndReturnError:nil] ) {
            NSError *error;
            NSFileManager *fm = [NSFileManager defaultManager];
            if ( ! [fm createDirectoryAtURL:imagrResourceFolder withIntermediateDirectories:YES attributes:nil error:&error] ) {
                DDLogError(@"[ERROR] Could not create Imagr resource folder!");
                DDLogError(@"[ERROR] %@", [error localizedDescription]);
                return;
            }
        }
        
        if ( ! [imagrVersionsDict writeToURL:imagrDownloadsDictURL atomically:YES] ) {
            DDLogError(@"[ERROR] Could not write to Imagr downloads cache dict");
        }
    }
} // updateCachedImagrVersions

- (void)getImagrVersions {
    NBCDownloaderGitHub *downloader =  [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagImagr };
    [downloader getReleaseVersionsAndURLsFromGithubRepository:NBCImagrGitHubRepository downloadInfo:downloadInfo];
} // getImagrVersions

- (IBAction)popUpButtonImagrVersion:(id)sender {
    NSString *selectedVersion = [[sender selectedItem] title];
    if ( [selectedVersion isEqualToString:NBCMenuItemImagrVersionLocal] ) {
        [self showImagrLocalVersionInput];
    } else if ( [selectedVersion isEqualToString:NBCMenuItemGitBranch] ) {
        [self showImagrBranchSelection];
    } else {
        [self hideImagrLocalVersionInput];
        [self hideImagrBranchSelection];
    }
} // popUpButtonImagrVersion

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Imagr Branches
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopUpButtonImagrBranches {
    if ( _popUpButtonImagrGitBranch ) {
        [_popUpButtonImagrGitBranch removeAllItems];
        [_popUpButtonImagrGitBranch addItemsWithTitles:_imagrBranches];
    }
    
    if ( [_imagrBranches containsObject:_imagrGitBranch] ) {
        [_popUpButtonImagrGitBranch selectItemWithTitle:_imagrGitBranch];
    } else {
        DDLogError(@"[ERROR] Git branch %@ is not available!", _imagrGitBranch);
    }
}

- (void)getImagrBranches {
    NBCDownloaderGitHub *downloader =  [[NBCDownloaderGitHub alloc] initWithDelegate:self];
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagImagr };
    [downloader getBranchesAndURLsFromGithubRepository:NBCImagrGitHubRepository downloadInfo:downloadInfo];
} // getImagrBranches

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark PopUpButton Imagr Branch Build Target
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)updatePopUpButtonImagrBranchesBuildTarget {
    NSArray *buildTargets = @[ @"Release", @"Debug" ];
    if ( _popUpButtonImagrGitBranchBuildTarget ) {
        [_popUpButtonImagrGitBranchBuildTarget removeAllItems];
        [_popUpButtonImagrGitBranchBuildTarget addItemsWithTitles:buildTargets];
    }
    if ( [buildTargets containsObject:_imagrBuildTarget] ) {
        [_popUpButtonImagrGitBranchBuildTarget selectItemWithTitle:_imagrBuildTarget];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Verify Build Button
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)verifyBuildButton {
    
    BOOL buildEnabled = YES;
    
    // -------------------------------------------------------------
    //  Verify that the current source is not nil.
    // -------------------------------------------------------------
    if ( _source == nil ) {
        buildEnabled = NO;
    }
    
    // -------------------------------------------------------------
    //  Verify that the destination folder is not empty
    // -------------------------------------------------------------
    if ( [_destinationFolder length] == 0 ) {
        buildEnabled = NO;
    }
    
    // --------------------------------------------------------------------------------
    //  Post a notification that sets the button state to value of bool 'buildEnabled'
    // --------------------------------------------------------------------------------
    NSDictionary * userInfo = @{ NBCNotificationUpdateButtonBuildUserInfoButtonState : @(buildEnabled) };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationUpdateButtonBuild object:self userInfo:userInfo];
    
} // verifyBuildButton

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Build NBI
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)buildNBI:(NSDictionary *)preWorkflowTasks {
    
    if ( ! _isNBI && [self haveSettingsChanged] ) {
        NSDictionary *alertInfo = @{
                                    NBCAlertTagKey : NBCAlertTagSettingsUnsavedBuild,
                                    NBCAlertUserInfoSelectedTemplate : _selectedTemplate,
                                    NBCAlertUserInfoPreWorkflowTasks : preWorkflowTasks ?: @{}
                                    };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsavedBuild:@"You have unsaved settings, do you want to save current template and continue?"
                                   alertInfo:alertInfo];
    } else if ( _isNBI && ! [self haveSettingsChanged] ) {
        
        // --------------------------------------------------------------------------------
        //  If source is an NBI and no settings have changed, theres no reason to continue
        // --------------------------------------------------------------------------------
        [NBCAlerts showAlertSettingsUnchangedNBI];
        return;
    } else {
        [self verifySettings:preWorkflowTasks];
    }
} // buildNBI

- (void)verifySettings:(NSDictionary *)preWorkflowTasks {
    
    DDLogInfo(@"Verifying settings...");
    
    DDLogDebug(@"[DEBUG] Creating new workflow item");
    NBCWorkflowItem *workflowItem = [[NBCWorkflowItem alloc] initWithWorkflowType:kWorkflowTypeImagr
                                                              workflowSessionType:kWorkflowSessionTypeGUI];
    
    if ( _source ) {
        DDLogDebug(@"[DEBUG] Settings workflow item source...");
        [workflowItem setSource:_source];
    } else {
        DDLogError(@"[ERROR] Source was empty!");
        return;
    }
    
    if ( _target ) {
        DDLogDebug(@"[DEBUG] Settings workflow item target...");
        [workflowItem setTarget:_target];
    }
    
    [workflowItem setApplicationSource:_siuSource];
    [workflowItem setSettingsViewController:self];
    [workflowItem setPreWorkflowTasks:preWorkflowTasks];
    
    // ----------------------------------------------------------------
    //  Collect current UI settings and pass them through verification
    // ----------------------------------------------------------------
    NSDictionary *userSettings = [self returnSettingsFromUI];
    if ( [userSettings count] != 0 ) {
        [workflowItem setUserSettings:userSettings];
        NBCSettingsController *sc = [[NBCSettingsController alloc] init];
        
        // ----------------------------------------------------
        //  Check all settings for possible errors or warnings
        // ----------------------------------------------------
        NSDictionary *errorInfoDict = [sc verifySettings:workflowItem];
        
        if ( [errorInfoDict count] != 0 ) {
            BOOL configurationError = NO;
            BOOL configurationWarning = NO;
            NSMutableString *alertInformativeText = [[NSMutableString alloc] init];
            NSArray *error = errorInfoDict[NBCSettingsError];
            NSArray *warning = errorInfoDict[NBCSettingsWarning];
            
            if ( [error count] != 0 ) {
                configurationError = YES;
                for ( NSString *errorString in error ) {
                    DDLogError(@"[ERROR] %@", errorString);
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n\n• %@", errorString]];
                }
            }
            
            if ( [warning count] != 0 ) {
                configurationWarning = YES;
                for ( NSString *warningString in warning ) {
                    DDLogWarn(@"[WARN] %@", warningString);
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n\n• %@", warningString]];
                }
            }
            
            // ----------------------------------------------------------------
            //  If any errors are found, display alert and stop NBI creation
            // ----------------------------------------------------------------
            if ( configurationError ) {
                [NBCAlerts showAlertSettingsError:alertInformativeText];
            }
            
            // --------------------------------------------------------------------------------
            //  If only warnings are found, display alert and allow user to continue or cancel
            // --------------------------------------------------------------------------------
            if ( ! configurationError && configurationWarning ) {
                NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsWarning,
                                             NBCAlertWorkflowItemKey : workflowItem };
                
                NBCAlerts *alerts = [[NBCAlerts alloc] initWithDelegate:self];
                [alerts showAlertSettingsWarning:alertInformativeText alertInfo:alertInfo];
            }
        } else {
            DDLogDebug(@"[DEBUG] Verification complete!");
            [self prepareWorkflowItem:workflowItem];
        }
    } else {
        DDLogError(@"[ERROR] Settings dict returned empty");
    }
} // verifySettings

- (void)prepareWorkflowItem:(NBCWorkflowItem *)workflowItem {
    
    DDLogInfo(@"Preparing workflow item...");
    
    NSMutableDictionary *resourcesSettings = [[NSMutableDictionary alloc] init];
    NSDictionary *userSettings = [workflowItem userSettings];
    
    // --------------------------------
    //  Prepare where to get Imagr.app
    // --------------------------------
    if ( [userSettings[NBCSettingsImagrUseGitBranch] boolValue] ) {
        NSString *selectedGitBranch = _imagrGitBranch;
        if ( ! [selectedGitBranch isEqualToString:[_popUpButtonImagrGitBranch titleOfSelectedItem]] ) {
            selectedGitBranch = [_popUpButtonImagrGitBranch titleOfSelectedItem];
        }
        resourcesSettings[NBCSettingsImagrGitBranch] = selectedGitBranch;
        
        NSString *selectedBuildTarget = _imagrBuildTarget;
        if ( ! [selectedBuildTarget isEqualToString:[_popUpButtonImagrGitBranchBuildTarget titleOfSelectedItem]] ) {
            selectedBuildTarget = [_popUpButtonImagrGitBranchBuildTarget titleOfSelectedItem];
        }
        resourcesSettings[NBCSettingsImagrBuildTarget] = selectedBuildTarget;
        
        NSDictionary *imagrGitBranchesDownloadLinks = _imagrBranchesDownloadLinks[selectedGitBranch];
        NSString *imagrGitDownloadURL = imagrGitBranchesDownloadLinks[@"url"];
        if ( [imagrGitDownloadURL length] != 0 ) {
            resourcesSettings[NBCSettingsImagrDownloadURL] = imagrGitDownloadURL;
        } else {
            DDLogError(@"[ERROR] Could not get Imagr Git Branch download URL!");
            return;
        }
        
        NSString *imagrGitBranchSHA = imagrGitBranchesDownloadLinks[@"sha"];
        if ( [imagrGitBranchSHA length] != 0 ) {
            resourcesSettings[NBCSettingsImagrGitBranchSHA] = imagrGitBranchSHA;
        } else {
            DDLogError(@"[ERROR] Could not get Imagr Git Branch SHA");
            return;
        }
    } else if ( ! [userSettings[NBCSettingsImagrUseLocalVersion] boolValue] ) {
        NSString *selectedImagrVersion = userSettings[NBCSettingsImagrVersion];
        DDLogDebug(@"[DEBUG] Selected Imagr.app version: %@", selectedImagrVersion);
        if ( [selectedImagrVersion isEqualToString:NBCMenuItemImagrVersionLatest] ) {
            if ( [_imagrVersions count] == 0 ) {
                DDLogError(@"[ERROR] Imagr versions array is empty!");
                return;
            }
            selectedImagrVersion = [_imagrVersions firstObject];
        }
        
        NSString *imagrDownloadURL = _imagrVersionsDownloadLinks[selectedImagrVersion];
        DDLogDebug(@"[DEBUG] Selected Imagr.app download url: %@", imagrDownloadURL);
        if ( [imagrDownloadURL length] == 0 ) {
            DDLogError(@"[ERROR] Imagr download link is empty!");
            return;
        }
        resourcesSettings[NBCSettingsImagrVersion] = selectedImagrVersion;
        resourcesSettings[NBCSettingsImagrDownloadURL] = imagrDownloadURL;
    }
    
    NSString *selectedLanguage = userSettings[NBCSettingsLanguageKey];
    if ( [selectedLanguage isEqualToString:NBCMenuItemCurrent] ) {
        NSLocale *currentLocale = [NSLocale currentLocale];
        NSString *currentLanguageID = [NSLocale preferredLanguages][0];
        if ( [currentLanguageID length] != 0 ) {
            resourcesSettings[NBCSettingsLanguageKey] = currentLanguageID;
        } else {
            DDLogError(@"[ERROR] Could not get current language ID!");
            return;
        }
        
        NSString *currentLocaleIdentifier = [currentLocale localeIdentifier];
        if ( [currentLocaleIdentifier length] != 0 ) {
            resourcesSettings[NBCSettingsLocale] = currentLocaleIdentifier;
        }
        
        NSString *currentCountry = [currentLocale objectForKey:NSLocaleCountryCode];
        if ( [currentCountry length] != 0 ) {
            resourcesSettings[NBCSettingsCountry] = currentCountry;
        }
    } else {
        NSArray *allKeys = [_languageDict allKeysForObject:selectedLanguage];
        if ( [allKeys count] != 0 ) {
            NSString *languageID = [allKeys firstObject];
            if ( [languageID length] != 0 ) {
                resourcesSettings[NBCSettingsLanguageKey] = languageID;
            } else {
                DDLogError(@"[ERROR] Could not get language ID!");
                return;
            }
            
            if ( [languageID containsString:@"-"] ) {
                NSString *localeFromLanguage = [languageID stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
                if ( [localeFromLanguage length] != 0 ) {
                    resourcesSettings[NBCSettingsLocale] = localeFromLanguage;
                    
                    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:localeFromLanguage];
                    NSString *country = [locale objectForKey:NSLocaleCountryCode];
                    if ( [country length] != 0 ) {
                        resourcesSettings[NBCSettingsCountry] = country;
                    }
                }
            }
        } else {
            DDLogError(@"[ERROR] No objects in language dict for %@", selectedLanguage);
            return; // Show error
        }
    }
    
    NSDictionary *hiToolboxDict = [NSDictionary dictionaryWithContentsOfFile:NBCFilePathPreferencesHIToolbox];
    NSString *selectedKeyboardLayoutName = userSettings[NBCSettingsKeyboardLayoutKey];
    if ( [selectedKeyboardLayoutName isEqualToString:NBCMenuItemCurrent] ) {
        NSDictionary *appleDefaultAsciiInputSourceDict = hiToolboxDict[@"AppleDefaultAsciiInputSource"];
        selectedKeyboardLayoutName = appleDefaultAsciiInputSourceDict[@"KeyboardLayout Name"];
        if ( [selectedKeyboardLayoutName length] != 0 ) {
            resourcesSettings[NBCSettingsKeyboardLayoutKey] = selectedKeyboardLayoutName;
        } else {
            DDLogError(@"[ERROR] Could not get current keyboard layout name!");
            return;
        }
    } else {
        resourcesSettings[NBCSettingsKeyboardLayoutKey] = selectedKeyboardLayoutName;
    }
    
    NSString *selectedKeyboardLayout = _keyboardLayoutDict[selectedKeyboardLayoutName];
    if ( [selectedKeyboardLayout length] == 0 ) {
        NSString *currentKeyboardLayout = hiToolboxDict[@"AppleCurrentKeyboardLayoutInputSourceID"];
        if ( [currentKeyboardLayout length] != 0 ) {
            resourcesSettings[NBCSettingsKeyboardLayoutID] = currentKeyboardLayout;
        } else {
            DDLogError(@"[ERROR] Could not get current keyboard layout!");
            return;
        }
    } else {
        resourcesSettings[NBCSettingsKeyboardLayoutID] = selectedKeyboardLayout;
    }
    
    NSString *selectedTimeZone = [self timeZoneFromMenuItem:_selectedMenuItem];
    if ( [selectedTimeZone length] != 0 ) {
        if ( [selectedTimeZone isEqualToString:NBCMenuItemCurrent] ) {
            NSTimeZone *currentTimeZone = [NSTimeZone defaultTimeZone];
            NSString *currentTimeZoneName = [currentTimeZone name];
            resourcesSettings[NBCSettingsTimeZoneKey] = currentTimeZoneName;
        } else {
            resourcesSettings[NBCSettingsTimeZoneKey] = selectedTimeZone;
        }
    } else {
        DDLogError(@"[ERROR] selectedTimeZone is nil!");
        return;
    }
    
    // -------------------------------------------------------------
    //  Create list of items to extract from installer
    // -------------------------------------------------------------
    NBCWorkflowResources *resources = [[NBCWorkflowResources alloc] initWithWorkflowItem:workflowItem];
    resourcesSettings = [resources prepareResourcesToExtract:resourcesSettings];
    
     /*
    NSMutableDictionary *sourceItemsDict = [[NSMutableDictionary alloc] init];
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    if ( ! [[_source sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        
        // --------------------------------------------------------------------------------
        //  Python - Required for Imagr
        // --------------------------------------------------------------------------------
        [NBCSourceController addPython:sourceItemsDict source:_source];
        
        // --------------------------------------------------------------------------------
        //  spctl -
        // --------------------------------------------------------------------------------
        //[NBCSourceController addSpctl:sourceItemsDict source:_source];
        
        // --------------------------------------------------------------------------------
        // taskgated -
        // --------------------------------------------------------------------------------
        //[NBCSourceController addTaskgated:sourceItemsDict source:_source];
        
        // --------------------------------------------------------------------------------
        // NSURLStoraged, NSURLSessiond -
        // --------------------------------------------------------------------------------
        //[NBCSourceController addNSURLStoraged:sourceItemsDict source:_source];
        
        // -------------------------------------------
        //  Console.app - Selected in UI (Tab: Debug)
        // -------------------------------------------
        if ( [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
            [NBCSourceController addConsole:sourceItemsDict source:_source];
        }
        
        // ---------------------------------------------------------------------------
        //  Kernel - Included if selections in UI requires regenerating kernel caches
        // ---------------------------------------------------------------------------
        if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] || [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
            [NBCSourceController addKernel:sourceItemsDict source:_source];
        }
        
        // ----------------------------------------------------------------
        //  DesktopViewer, DesktopPicture - Selected in UI (Tab: Advanced)
        // ----------------------------------------------------------------
        if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
            [NBCSourceController addDesktopPicture:sourceItemsDict source:_source];
        }
        
        // -------------------------------------
        //  ntp - Selected in UI (Tab: Options)
        // -------------------------------------
        if ( [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
            [NBCSourceController addNTP:sourceItemsDict source:_source];
        }
        
        // ------------------------------------------------
        //  SystemUIServer - Selected in UI (Tab: Options)
        // ------------------------------------------------
        if ( [userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
            [NBCSourceController addSystemUIServer:sourceItemsDict source:_source];
        }
        
        // ------------------------------------------------------------------------
        //  systemkeychain - Included if selections in UI requires system keychain
        // ------------------------------------------------------------------------
        if ( [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
            [NBCSourceController addSystemkeychain:sourceItemsDict source:_source];
        }
        
        // ------------------------------------------------
        //  SystemUIServer - Selected in UI (Tab: Options)
        // ------------------------------------------------
        if ( [userSettings[NBCSettingsIncludeRubyKey] boolValue] ) {
            [NBCSourceController addRuby:sourceItemsDict source:_source];
        }
        
        // -------------------------------------
        //  VNC - Selected in UI (Tab: Options)
        // -------------------------------------
        if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
            [NBCSourceController addVNC:sourceItemsDict source:_source];
        }
        
        // -------------------------------------
        //  ARD - Selected in UI (Tab: Options)
        // -------------------------------------
        if ( [userSettings[NBCSettingsARDLoginKey] length] != 0 && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
            [NBCSourceController addARD:sourceItemsDict source:_source];
            //[sourceController addKerberos:sourceItemsDict source:_source];
        }
        
        // -------------------------------------------------------------
        //  In OS X 10.11 all sources moved to Essentials.pkg
        //  This moves all regexes to Essentials
        // -------------------------------------------------------------
        if ( 11 <= sourceVersionMinor ) {
            
            // -----------------------------------------------------------------
            //  libssl is not in 10.11 BaseSystem by default, required by Imagr
            // -----------------------------------------------------------------
            [NBCSourceController addLibSsl:sourceItemsDict source:_source];
            
            // -------------------------------------------------------------
            //  networkd
            // -------------------------------------------------------------
            [NBCSourceController addNetworkd:sourceItemsDict source:_source];
            
            // -------------------------------------------------------------
            //  Move all regexes from AdditionalEssentials to Essentials
            // -------------------------------------------------------------
            NSString *packageAdditionalEssentialsPath = [NSString stringWithFormat:@"%@/Packages/AdditionalEssentials.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageAdditionalEssentialsDict = sourceItemsDict[packageAdditionalEssentialsPath];
            NSMutableArray *packageAdditionalEssentialsRegexes;
            if ( [packageAdditionalEssentialsDict count] != 0 ) {
                packageAdditionalEssentialsRegexes = packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey];
                NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
                NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
                NSMutableArray *packageEssentialsRegexes = packageEssentialsDict[NBCSettingsSourceItemsRegexKey] ?: [[NSMutableArray alloc] init];
                [packageEssentialsRegexes addObjectsFromArray:packageAdditionalEssentialsRegexes];
                packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects];;
                sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
                [sourceItemsDict removeObjectForKey:packageAdditionalEssentialsPath];
            }
            
            // -----------------------------------------
            //  Move all regexes from BSD to Essentials
            // -----------------------------------------
            NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageBSDDict = sourceItemsDict[packageBSDPath];
            NSArray *packageBSDRegexes;
            if ( [packageBSDDict count] != 0 ) {
                packageBSDRegexes = packageBSDDict[NBCSettingsSourceItemsRegexKey];
                NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
                NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
                NSMutableArray *packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
                [packageEssentialsRegexes addObjectsFromArray:packageBSDRegexes];
                packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects];;
                sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
                [sourceItemsDict removeObjectForKey:packageBSDPath];
            }
            
            // --------------------------------------------------------
            //  Move all regexes from BaseSystemBinaries to Essentials
            // --------------------------------------------------------
            NSString *packageBaseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageBaseSystemBinariesDict = sourceItemsDict[packageBaseSystemBinariesPath];
            NSArray *packageBaseSystemBinariesRegexes;
            if ( [packageBaseSystemBinariesDict count] != 0 ) {
                packageBaseSystemBinariesRegexes = packageBaseSystemBinariesDict[NBCSettingsSourceItemsRegexKey];
                NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
                NSMutableDictionary *packageEssentialsDict = [sourceItemsDict[packageEssentialsPath] mutableCopy] ?: [[NSMutableDictionary alloc] init];
                NSMutableArray *packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy] ?: [[NSMutableArray alloc] init];
                [packageEssentialsRegexes addObjectsFromArray:packageBaseSystemBinariesRegexes];
                packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects];
                sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
                [sourceItemsDict removeObjectForKey:packageBaseSystemBinariesPath];
            }
        }
        
        // ------------------------------------------------------------------
        //  Replace source items dict with the new merged Essentials version
        // ------------------------------------------------------------------
        resourcesSettings[NBCSettingsSourceItemsKey] = [sourceItemsDict copy];
    }
    */
      
    NSMutableArray *certificates = [[NSMutableArray alloc] init];
    for ( NSDictionary *certificateDict in _certificateTableViewContents ) {
        NSData *certificate = certificateDict[NBCDictionaryKeyCertificate];
        [certificates addObject:certificate];
    }
    resourcesSettings[NBCSettingsCertificatesKey] = [certificates copy] ?: @[];
    
    NSMutableArray *packages = [[NSMutableArray alloc] init];
    for ( NSDictionary *packageDict in _packagesTableViewContents ) {
        NSString *packagePath = packageDict[NBCDictionaryKeyPackagePath];
        [packages addObject:packagePath];
    }
    resourcesSettings[NBCSettingsPackagesKey] = [packages copy] ?: @[];
    
    NSMutableArray *ramDisks = [[NSMutableArray alloc] init];
    for ( NSDictionary *ramDiskDict in _ramDisks ) {
        if ( [self validateRAMDisk:ramDiskDict] ) {
            [ramDisks addObject:ramDiskDict];
        }
    }
    resourcesSettings[NBCSettingsRAMDisksKey] = [ramDisks copy] ?: @[];
    
    NSMutableArray *validatedTrustedNetBootServers = [[NSMutableArray alloc] init];
    for ( NSString *netBootServerIP in _trustedServers ) {
        if ( [netBootServerIP isValidIPAddress] ) {
            [validatedTrustedNetBootServers addObject:netBootServerIP];
        }
    }
    resourcesSettings[NBCSettingsTrustedNetBootServersKey] = [validatedTrustedNetBootServers copy] ?: @[];
    
    // ---------------------------------------------------------------------
    //  If source is NBI, create array of which settings have been modified
    // ---------------------------------------------------------------------
    if ( [[_source sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        DDLogDebug(@"[DEBUG] Checking what settings has been changed..");
        NSMutableDictionary *settingsChanged = [[NSMutableDictionary alloc] init];
        NSArray *userSettingsArray = [userSettings allKeys];
        for ( NSString *key in userSettingsArray ) {
            if ( [userSettings[key] isEqualTo:_nbiSourceSettings[key]]) {
                settingsChanged[key] = @NO;
            } else {
                DDLogDebug(@"[DEBUG] Setting Changed: %@", key);
                DDLogDebug(@"[DEBUG] Setting value UI: %@", userSettings[key]);
                DDLogDebug(@"[DEBUG] Setting value original: %@", _nbiSourceSettings[key]);
                settingsChanged[key] = @YES;
            }
        }
        [workflowItem setUserSettingsChanged:settingsChanged];
    }
    
    // --------------------------------------------------------------
    //  Set dict of resources to be included in NBI to workflow item
    // --------------------------------------------------------------
    [workflowItem setResourcesSettings:[resourcesSettings copy]];
    
    // -------------------------------------------------------------
    //  Instantiate all workflows to be used to create a Imagr NBI
    // -------------------------------------------------------------
    NBCImagrWorkflowResources *workflowResources = [[NBCImagrWorkflowResources alloc] init];
    [workflowItem setWorkflowResources:workflowResources];
    
    NBCImagrWorkflowNBI *workflowNBI = [[NBCImagrWorkflowNBI alloc] init];
    [workflowItem setWorkflowNBI:workflowNBI];
    
    //NBCWorkflowModifyNBI *workflowModifyNBI = [[NBCWorkflowModifyNBI alloc] init];
    //[workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    NBCImagrWorkflowModifyNBI *workflowModifyNBI = [[NBCImagrWorkflowModifyNBI alloc] init];
    [workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    // -------------------------------------------------------------
    //  Post notification to add workflow item to queue
    // -------------------------------------------------------------
    NSDictionary *userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : workflowItem };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationAddWorkflowItemToQueue object:self userInfo:userInfo];
    
} // prepareWorkflowItem

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Trusted NetBoot Servers
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonManageTrustedServers:(id)sender {
    [_popOverManageTrustedServers showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)buttonAddTrustedServer:(id)sender {
#pragma unused(sender)
    
    // Check if empty view already exist
    __block NSNumber *index;
    [_trustedServers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( [obj length] == 0 ) {
            index = [NSNumber numberWithInteger:(NSInteger)idx];
            *stop = YES;
        }
    }];
    
    if ( index == nil ) {
        // Insert new view
        index = [NSNumber numberWithInteger:[self insertNetBootServerIPInTableView:@""]];
    }
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:(NSUInteger)index];
    // Select the newly created text field in the new view
    [_tableViewTrustedServers selectRowIndexes:indexSet byExtendingSelection:NO];
    [[[_tableViewTrustedServers viewAtColumn:[_tableViewTrustedServers selectedColumn]
                                         row:[index integerValue]
                             makeIfNecessary:NO] textFieldTrustedNetBootServer] selectText:self];
    [self updateTrustedNetBootServersCount];
}

- (IBAction)buttonRemoveTrustedServer:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewTrustedServers selectedRowIndexes];
    [_trustedServers removeObjectsAtIndexes:indexes];
    [_tableViewTrustedServers removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    [self updateTrustedNetBootServersCount];
}

- (void)updateTrustedNetBootServersCount {
    __block int validNetBootServersCounter = 0;
    __block BOOL containsInvalidNetBootServer = NO;
    
    [_trustedServers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(stop)
        // Skip empty lines
        if ( [obj length] == 0 ) {
            return;
        }
        
        NBCImagrTrustedNetBootServerCellView *cellView = [self->_tableViewTrustedServers viewAtColumn:0 row:(NSInteger)idx makeIfNecessary:NO];
        
        if ( [obj isValidIPAddress] ) {
            validNetBootServersCounter++;
            [[cellView textFieldTrustedNetBootServer] setStringValue:obj];
        } else {
            NSMutableAttributedString *trustedNetBootServerAttributed = [[NSMutableAttributedString alloc] initWithString:obj];
            [trustedNetBootServerAttributed addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[trustedNetBootServerAttributed length])];
            [[cellView textFieldTrustedNetBootServer] setAttributedStringValue:trustedNetBootServerAttributed];
            containsInvalidNetBootServer = YES;
        }
    }];
    
    NSString *trustedNetBootServerCount = [[NSNumber numberWithInt:validNetBootServersCounter] stringValue];
    if ( containsInvalidNetBootServer ) {
        NSMutableAttributedString *trustedNetBootServerCountMutable = [[NSMutableAttributedString alloc] initWithString:trustedNetBootServerCount];
        [trustedNetBootServerCountMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[trustedNetBootServerCountMutable length])];
        [_textFieldTrustedServersCount setAttributedStringValue:trustedNetBootServerCountMutable];
    } else {
        [_textFieldTrustedServersCount setStringValue:trustedNetBootServerCount];
    }
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Slider
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)sliderDisplaySleep:(id)sender {
#pragma unused(sender)
    [self setDisplaySleepMinutes:(int)[_sliderDisplaySleep integerValue]];
    [self updateSliderPreview:(int)[_sliderDisplaySleep integerValue]];
}

- (void)updateSliderPreview:(int)sliderValue {
    NSString *sliderPreviewString;
    if ( 120 <= sliderValue ) {
        sliderPreviewString = @"Never";
    } else {
        NSCalendar *calendarUS = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian];
        calendarUS.locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
        NSDateComponentsFormatter *dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
        dateComponentsFormatter.maximumUnitCount = 2;
        dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        dateComponentsFormatter.calendar = calendarUS;
        
        sliderPreviewString = [dateComponentsFormatter stringFromTimeInterval:(sliderValue * 60)];
    }
    
    [_textFieldDisplaySleepPreview setStringValue:sliderPreviewString];
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark RAM Disks
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (IBAction)buttonRamDisks:(id)sender {
    [_popOverRAMDisks showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMaxXEdge];
}

- (IBAction)buttonAddRAMDisk:(id)sender {
#pragma unused(sender)
    
    // Check if empty view already exist
    __block NSNumber *index;
    [_ramDisks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ( [obj[@"path"] length] == 0 && [obj[@"size"] isEqualToString:@"1"] ) {
            index = [NSNumber numberWithInteger:(NSInteger)idx];
            *stop = YES;
        }
    }];
    
    if ( index == nil ) {
        // Insert new view
        NSDictionary *newRamDiskDict = @{
                                         @"path" : @"",
                                         @"size" : @"1",
                                         };
        index = [NSNumber numberWithInteger:[self insertRAMDiskInTableView:newRamDiskDict]];
    }
    
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:(NSUInteger)index];
    
    // Select the newly created text field in the new view
    [_tableViewRAMDisks selectRowIndexes:indexSet byExtendingSelection:NO];
    [[[_tableViewRAMDisks viewAtColumn:[_tableViewRAMDisks selectedColumn]
                                   row:[index integerValue]
                       makeIfNecessary:NO] textFieldRAMDiskPath] selectText:self];
    [self updateRAMDisksCount];
}

- (IBAction)buttonRemoveRAMDisk:(id)sender {
#pragma unused(sender)
    NSIndexSet *indexes = [_tableViewRAMDisks selectedRowIndexes];
    [_ramDisks removeObjectsAtIndexes:indexes];
    [_tableViewRAMDisks removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
    [self updateRAMDisksCount];
}

- (void)updateRAMDisksCount {
    __block BOOL containsInvalidRAMDisk = NO;
    __block int validRAMDisksCounter = 0;
    __block int sumRAMDiskSize = 0;
    [_ramDisks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
#pragma unused(stop, idx, obj)
        BOOL validPath = NO;
        BOOL validSize = NO;
        NSString *path = obj[@"path"];
        NSString *size = obj[@"size"];
        if ( [path length] == 0 && [size isEqualToString:@"1"] ) {
            return;
        }
        
        NBCImagrRAMDiskPathCellView *cellView = [self->_tableViewRAMDisks viewAtColumn:0
                                                                                   row:(NSInteger)idx
                                                                       makeIfNecessary:NO];
        if ( [path length] != 0 ) {
            [[cellView textFieldRAMDiskPath] setStringValue:path];
            validPath = YES;
        } else {
            /*
             NSMutableAttributedString *pathathAttributed = [[NSMutableAttributedString alloc] initWithString:path];
             [pathathAttributed addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[pathathAttributed length])];
             [[cellView textFieldRAMDiskPath] setAttributedStringValue:pathathAttributed];
             */
        }
        
        if ( [size length] != 0 ) {
            sumRAMDiskSize = ( sumRAMDiskSize  + [size intValue] );
            validSize = YES;
        }
        
        if ( validPath && validSize ) {
            validRAMDisksCounter++;
        } else {
            containsInvalidRAMDisk = YES;
        }
    }];
    
    NSString *ramDisksCount = [[NSNumber numberWithInt:validRAMDisksCounter] stringValue];
    NSString *ramDiskSize = [NSByteCountFormatter stringFromByteCount:(long long)(sumRAMDiskSize * 1000000) countStyle:NSByteCountFormatterCountStyleDecimal];
    [_textFieldRAMDiskSize setStringValue:ramDiskSize];
    
    if ( containsInvalidRAMDisk ) {
        NSMutableAttributedString *ramDisksCountMutable = [[NSMutableAttributedString alloc] initWithString:ramDisksCount];
        [ramDisksCountMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[ramDisksCountMutable length])];
        [_textFieldRAMDiskCount setAttributedStringValue:ramDisksCountMutable];
    } else {
        [_textFieldRAMDiskCount setStringValue:ramDisksCount];
    }
}

- (BOOL)validateRAMDisk:(NSDictionary *)ramDiskDict {
    BOOL retval = YES;
    NSString *path = ramDiskDict[@"path"];
    NSString *size = ramDiskDict[@"size"];
    if ( [path length] == 0 || [size length] == 0 ) {
        return NO;
    }
    
    return retval;
}

@end
