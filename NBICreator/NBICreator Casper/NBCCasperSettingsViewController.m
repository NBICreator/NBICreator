//
//  NBCCasperSettingsViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-02.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Carbon/Carbon.h>
#import "NBCCasperSettingsViewController.h"
#import "NBCConstants.h"
#import "NBCVariables.h"

#import "NBCWorkflowItem.h"
#import "NBCSettingsController.h"
#import "NBCController.h"

#import "NBCCasperWorkflowNBI.h"
#import "NBCCasperWorkflowResources.h"
#import "NBCCasperWorkflowModifyNBI.h"

#import "NBCHelperConnection.h"
#import "NBCHelperProtocol.h"

#import "Reachability.h"
#import "NBCLogging.h"
#import "NBCCertificateTableCellView.h"
#import "NBCPackageTableCellView.h"
#import "NBCDesktopEntity.h"
#import "TFHpple.h"
#import "NBCCasperTrustedNetBootServerCellView.h"
#import "NSString+validIP.h"
#import "NBCCasperRAMDiskPathCellView.h"
#import "NBCCasperRAMDiskSizeCellView.h"
#import "NBCOverlayViewController.h"

DDLogLevel ddLogLevel;

@interface NBCCasperSettingsViewController () {
    Reachability *_internetReachableFoo;
}

@end

@implementation NBCCasperSettingsViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCCasperSettingsViewController" bundle:nil];
    if (self != nil) {
        _templates = [[NBCTemplatesController alloc] initWithSettingsViewController:self templateType:NBCSettingsTypeCasper delegate:self];
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
    
    [self setConnectedToInternet:NO];
    _keyboardLayoutDict = [[NSMutableDictionary alloc] init];
    _certificateTableViewContents = [[NSMutableArray alloc] init];
    _packagesTableViewContents = [[NSMutableArray alloc] init];
    _trustedServers = [[NSMutableArray alloc] init];
    _ramDisks = [[NSMutableArray alloc] init];
    
    // --------------------------------------------------------------
    //  Add Notification Observers
    // --------------------------------------------------------------
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(updateSource:) name:NBCNotificationCasperUpdateSource object:nil];
    [nc addObserver:self selector:@selector(removedSource:) name:NBCNotificationCasperRemovedSource object:nil];
    [nc addObserver:self selector:@selector(updateNBIIcon:) name:NBCNotificationCasperUpdateNBIIcon object:nil];
    [nc addObserver:self selector:@selector(updateNBIBackground:) name:NBCNotificationCasperUpdateNBIBackground object:nil];
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
        _templatesFolderURL = [userApplicationSupport URLByAppendingPathComponent:NBCFolderTemplatesCasper isDirectory:YES];
    } else {
        DDLogError(@"[ERROR] Could not get user Application Support Folder");
        DDLogError(@"[ERROR] %@", error);
    }
    _siuSource = [[NBCSystemImageUtilitySource alloc] init];
    _templatesDict = [[NSMutableDictionary alloc] init];
    [self setShowARDPassword:NO];
    
    // --------------------------------------------------------------
    //  Test Internet Connectivity
    // --------------------------------------------------------------
    [self testInternetConnection];
    
    [self populatePopUpButtonTimeZone];
    [self populatePopUpButtonLanguage];
    [self populatePopUpButtonKeyboardLayout];
    
    // ------------------------------------------------------------------------------
    //  Add contextual menu to NBI Icon image view to allow to restore original icon.
    // -------------------------------------------------------------------------------
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *restoreView = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalIcon action:@selector(restoreNBIIcon:) keyEquivalent:@""];
    [restoreView setTarget:self];
    [menu addItem:restoreView];
    [_imageViewIcon setMenu:menu];
    
    // --------------------------------------------------------------
    //  Load saved templates and create the template menu
    // --------------------------------------------------------------
    [self updatePopUpButtonTemplates];
    
    
    // --------------------------------------------------------------
    //  Set Hyperlink to "More Info" text after Allow Invalid Certificate
    // --------------------------------------------------------------
    /*
     [_textFieldMoreInfo setAllowsEditingTextAttributes: YES];
     [_textFieldMoreInfo setSelectable: YES];
     NSURL* url = [NSURL URLWithString:@"https://macmule.com/projects/autocaspernbi/#Enable_Invalid_JSS_Cert_if_a_JSS_URL_is_given"];
     NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
     [string appendAttributedString:[NSAttributedString hyperlinkFromString:@"More Info" withURL:url]];
     [_textFieldMoreInfo setAttributedStringValue:string];
     */
    
    // ------------------------------------------------------------------------------------------
    //  Add contextual menu to NBI background image view to allow to restore original background.
    // ------------------------------------------------------------------------------------------
    NSMenu *backgroundImageMenu = [[NSMenu alloc] init];
    NSMenuItem *restoreViewBackground = [[NSMenuItem alloc] initWithTitle:NBCMenuItemRestoreOriginalBackground action:@selector(restoreNBIBackground:) keyEquivalent:@""];
    [backgroundImageMenu addItem:restoreViewBackground];
    [_imageViewBackgroundImage setMenu:backgroundImageMenu];
    
    // ------------------------------------------------------------------------------
    //
    // -------------------------------------------------------------------------------
    [self updateSettingVisibility];
    
    // ------------------------------------------------------------------------------
    //  Verify build button so It's not enabled by mistake
    // -------------------------------------------------------------------------------
    [self verifyBuildButton];
    
} // viewDidLoad

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSTableView DataSource Methods
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCertificates] ) {
        if ( ! _viewOverlayPackages ) {
            NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypeCertificates];
            _viewOverlayCertificates = [vc view];
        }
        NSInteger count = (NSInteger)[_certificateTableViewContents count];
        if ( count == 0 && [[[_superViewCertificates subviews] firstObject] isNotEqualTo:_viewOverlayCertificates] ) {
            [_superViewCertificates addSubview:_viewOverlayCertificates positioned:NSWindowAbove relativeTo:_scrollViewCertificates];
            [_viewOverlayCertificates setTranslatesAutoresizingMaskIntoConstraints:NO];
            NSArray *constraintsArray;
            constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|-1-[_viewOverlayCertificates]-1-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_viewOverlayCertificates)];
            [_superViewCertificates addConstraints:constraintsArray];
            constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-1-[_viewOverlayCertificates]-1-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_viewOverlayCertificates)];
            [_superViewCertificates addConstraints:constraintsArray];
        } else if ( count > 0 && [[_superViewCertificates subviews] containsObject:_viewOverlayCertificates] ) {
            [_viewOverlayCertificates removeFromSuperview];
        }
        return count;
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierPackages] ) {
        if ( ! _viewOverlayPackages ) {
            NBCOverlayViewController *vc = [[NBCOverlayViewController alloc] initWithContentType:kContentTypePackages];
            _viewOverlayPackages = [vc view];
        }
        NSInteger count = (NSInteger)[_packagesTableViewContents count];
        if ( count == 0 && [[[_superViewPackages subviews] firstObject] isNotEqualTo:_viewOverlayPackages] ) {
            [_superViewPackages addSubview:_viewOverlayPackages positioned:NSWindowAbove relativeTo:_scrollViewPackages];
            [_viewOverlayPackages setTranslatesAutoresizingMaskIntoConstraints:NO];
            NSArray *constraintsArray;
            constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"|-1-[_viewOverlayPackages]-1-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_viewOverlayPackages)];
            [_superViewPackages addConstraints:constraintsArray];
            constraintsArray = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-1-[_viewOverlayPackages]-1-|"
                                                                       options:0
                                                                       metrics:nil
                                                                         views:NSDictionaryOfVariableBindings(_viewOverlayPackages)];
            [_superViewPackages addConstraints:constraintsArray];
        } else if ( count > 0 && [[_superViewPackages subviews] containsObject:_viewOverlayPackages] ) {
            [_viewOverlayPackages removeFromSuperview];
        }
        return count;
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCasperTrustedServers] ) {
        return (NSInteger)[_trustedServers count];
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCasperRAMDisks] ) {
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
                                             [tableView reloadData];
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
                                             [tableView reloadData];
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

- (NBCCasperTrustedNetBootServerCellView *)populateTrustedNetBootServerCellView:(NBCCasperTrustedNetBootServerCellView *)cellView netBootServerIP:(NSString *)netBootServerIP {
    NSMutableAttributedString *netBootServerIPMutable;
    if ( [netBootServerIP isValidIPAddress] ) {
        [[cellView textFieldTrustedNetBootServer] setStringValue:netBootServerIP];
    } else {
        netBootServerIPMutable = [[NSMutableAttributedString alloc] initWithString:netBootServerIP];
        [netBootServerIPMutable addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[netBootServerIPMutable length])];
        [[cellView textFieldTrustedNetBootServer] setAttributedStringValue:netBootServerIPMutable];
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

- (NBCCasperRAMDiskPathCellView *)populateRAMDiskPathCellView:(NBCCasperRAMDiskPathCellView *)cellView ramDiskDict:(NSDictionary *)ramDiskDict row:(NSInteger)row {
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

- (NBCCasperRAMDiskSizeCellView *)populateRAMDiskSizeCellView:(NBCCasperRAMDiskSizeCellView *)cellView ramDiskDict:(NSDictionary *)ramDiskDict row:(NSInteger)row {
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
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCasperTrustedServers] ) {
        [self updateTrustedNetBootServersCount];
        NSString *trustedServer = _trustedServers[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"CasperTrustedNetBootTableColumn"] ) {
            NBCCasperTrustedNetBootServerCellView *cellView = [tableView makeViewWithIdentifier:@"CasperNetBootServerCellView" owner:self];
            return [self populateTrustedNetBootServerCellView:cellView netBootServerIP:trustedServer];
        }
    } else if ( [[tableView identifier] isEqualToString:NBCTableViewIdentifierCasperRAMDisks] ) {
        [self updateRAMDisksCount];
        NSDictionary *ramDiskDict = _ramDisks[(NSUInteger)row];
        if ( [[tableColumn identifier] isEqualToString:@"CasperRAMDiskPathTableColumn"] ) {
            NBCCasperRAMDiskPathCellView *cellView = [tableView makeViewWithIdentifier:@"CasperRAMDiskPathCellView" owner:self];
            return [self populateRAMDiskPathCellView:cellView ramDiskDict:ramDiskDict row:row];
        } else if ( [[tableColumn identifier] isEqualToString:@"CasperRAMDiskSizeTableColumn"] ) {
            NBCCasperRAMDiskSizeCellView *cellView = [tableView makeViewWithIdentifier:@"CasperRAMDiskSizeCellView" owner:self];
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
        DDLogDebug(@"certificateName=%@", certificateName);
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

- (BOOL)insertCertificateInTableView:(NSDictionary *)certificateDict {
    for ( NSDictionary *certDict in _certificateTableViewContents ) {
        if ( [certificateDict[NBCDictionaryKeyCertificateSignature] isEqualToData:certDict[NBCDictionaryKeyCertificateSignature]] ) {
            if ( [certificateDict[NBCDictionaryKeyCertificateSerialNumber] isEqualToString:certDict[NBCDictionaryKeyCertificateSerialNumber]] ) {
                DDLogWarn(@"Certificate %@ is already added!", certificateDict[NBCDictionaryKeyCertificateName]);
                return NO;
            }
        }
    }
    
    NSInteger index = [_tableViewCertificates selectedRow];
    index++;
    [_tableViewCertificates beginUpdates];
    [_tableViewCertificates insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] withAnimation:NSTableViewAnimationSlideDown];
    [_tableViewCertificates scrollRowToVisible:index];
    [_certificateTableViewContents insertObject:certificateDict atIndex:(NSUInteger)index];
    [_tableViewCertificates reloadData];
    [_tableViewCertificates endUpdates];
    return YES;
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
    [_tableViewPackages reloadData];
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
            [weakSelf setConnectedToInternet:YES];
            if ( weakSelf->_verifyJSSWhenConnected ) {
                [weakSelf setVerifyJSSWhenConnected:NO];
                [weakSelf buttonVerifyJSS:nil];
            }
        });
    };
    
    // Internet is not reachable
    _internetReachableFoo.unreachableBlock = ^(Reachability*reach) {
#pragma unused(reach)
        // Update the UI on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf setConnectedToInternet:NO];
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
        if ( [_nbiIconPath isEqualToString:NBCFilePathNBIIconCasper] ) {
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
        if ( [[[textField superview] class] isSubclassOfClass:[NBCCasperTrustedNetBootServerCellView class]] ) {
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
        } else if ( textField == _textFieldJSSURL ) {
            NSURL *stringAsURL = [NSURL URLWithString:[_textFieldJSSURL stringValue]];
            if ( stringAsURL && [stringAsURL scheme] && [stringAsURL host] ) {
                [self jssURLIsValid];
            } else {
                [self jssURLIsInvalid];
            }
            
            [_imageViewVerifyJSSStatus setHidden:YES];
            [_textFieldVerifyJSSStatus setHidden:YES];
            [_imageViewDownloadJSSCertificateStatus setHidden:YES];
            [_textFieldDownloadJSSCertificateStatus setHidden:YES];
            [_buttonShowJSSCertificate setHidden:YES];
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

- (void)downloadCanceled:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagJSSCertificate] ) {
        DDLogError(@"Download with tag %@ canceled!", downloadTag);
    }
}

- (void)jssURLIsValid {
    [self setJssURLValid:YES];
    if ( ! _verifyingJSS ) {
        [_buttonVerifyJSS setEnabled:YES];
    }
    [_buttonDownloadJSSCertificate setEnabled:YES];
    [_buttonShowJSSCertificate setEnabled:YES];
}

- (void)jssURLIsInvalid {
    [self setJssURLValid:NO];
    [_buttonVerifyJSS setEnabled:NO];
    [_buttonDownloadJSSCertificate setEnabled:NO];
    [_buttonShowJSSCertificate setEnabled:NO];
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
        if ( returnCode == NSAlertFirstButtonReturn ) {         // Save and Continue
            if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
                [_templates showSheetSaveUntitled:selectedTemplate buildNBI:YES];
                return;
            } else {
                [self saveUISettingsWithName:_selectedTemplate atUrl:_templatesDict[_selectedTemplate]];
                [self setSelectedTemplate:selectedTemplate];
                [self updateUISettingsFromURL:_templatesDict[_selectedTemplate]];
                [self expandVariablesForCurrentSettings];
                [self verifySettings];
                return;
            }
        } else if ( returnCode == NSAlertSecondButtonReturn ) { // Continue
            [self verifySettings];
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
            [self setSettingTrustedNetBootServersVisible:YES];
        } else {
            [self setSettingTrustedNetBootServersVisible:NO];
        }
    } else {
        [self setSettingTrustedNetBootServersVisible:NO];
    }
}

- (void)updateSource:(NSNotification *)notification {
    
    NBCSource *source = [notification userInfo][NBCNotificationUpdateSourceUserInfoSource];
    if ( source != nil ) {
        [self setSource:source];
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
        [self setTarget:target];
    }
    
    if ( [[source sourceType] isEqualToString:NBCSourceTypeNBI] ) {
        [self setIsNBI:YES];
        NSURL *nbiURL = [source sourceURL];
        [self createSettingsFromNBI:nbiURL];
    } else {
        [self setIsNBI:NO];
        [_textFieldDestinationFolder setEnabled:YES];
        [_buttonChooseDestinationFolder setEnabled:YES];
        [_popUpButtonTool setEnabled:YES];
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
    
    [self setIsNBI:NO];
    [_textFieldDestinationFolder setEnabled:YES];
    [_buttonChooseDestinationFolder setEnabled:YES];
    [_popUpButtonTool setEnabled:YES];
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
    
    [self setNbiIconPath:NBCFilePathNBIIconCasper];
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
        if ( [[[textField superview] class] isSubclassOfClass:[NBCCasperTrustedNetBootServerCellView class]] ) {
            [self updateTrustedNetBootServersCount];
        } else if ( [[[textField superview] class] isSubclassOfClass:[NBCCasperRAMDiskPathCellView class]] ) {
            NSString *newPath = [textField stringValue];
            NSNumber *textFieldTag = [NSNumber numberWithInteger:[textField tag]];
            if ( textFieldTag != nil ) {
                NSMutableDictionary *ramDiskDict = [NSMutableDictionary dictionaryWithDictionary:[_ramDisks objectAtIndex:(NSUInteger)[textFieldTag integerValue]]];
                ramDiskDict[@"path"] = newPath ?: @"";
                [_ramDisks replaceObjectAtIndex:(NSUInteger)[textFieldTag integerValue] withObject:[ramDiskDict copy]];
                [self updateRAMDisksCount];
            }
        } else if ( [[[textField superview] class] isSubclassOfClass:[NBCCasperRAMDiskSizeCellView class]] ) {
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
    
    [self setCasperImagingVersion:@""];
    [self setJssCACertificateExpirationString:@""];
    [self setJssVersion:@""];
    
    
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
    [self setCasperImagingPath:settingsDict[NBCSettingsCasperImagingPathKey]];
    [self setCasperJSSURL:settingsDict[NBCSettingsCasperJSSURLKey]];
    //[self setIsNBI:[settingsDict[NBCSettingsCasperSourceIsNBI] boolValue]];
    [self setUseBackgroundImage:[settingsDict[NBCSettingsUseBackgroundImageKey] boolValue]];
    [self setImageBackgroundURL:settingsDict[NBCSettingsBackgroundImageKey]];
    [self setUseVerboseBoot:[settingsDict[NBCSettingsUseVerboseBootKey] boolValue]];
    [self setDiskImageReadWrite:[settingsDict[NBCSettingsDiskImageReadWriteKey] boolValue]];
    [self setIncludeConsoleApp:[settingsDict[NBCSettingsIncludeConsoleAppKey] boolValue]];
    [self setAllowInvalidCertificate:[settingsDict[NBCSettingsCasperAllowInvalidCertificateKey] boolValue]];
    [self setJssCACertificate:settingsDict[NBCSettingsCasperJSSCACertificateKey]];
    [self setEnableCasperImagingDebugMode:[settingsDict[NBCSettingsCasperImagingDebugModeKey] boolValue]];
    [self setEnableLaunchdLogging:[settingsDict[NBCSettingsEnableLaunchdLoggingKey] boolValue]];
    [self setLaunchConsoleApp:[settingsDict[NBCSettingsLaunchConsoleAppKey] boolValue]];
    [self setIncludeRuby:[settingsDict[NBCSettingsIncludeRubyKey] boolValue]];
    [self setAddTrustedNetBootServers:[settingsDict[NBCSettingsAddTrustedNetBootServersKey] boolValue]];
    [self setAddCustomRAMDisks:[settingsDict[NBCSettingsAddCustomRAMDisksKey] boolValue]];
    [self setIncludePython:[settingsDict[NBCSettingsIncludePythonKey] boolValue]];
    
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
    
    if ( _isNBI ) {
        [_popUpButtonTool setEnabled:NO];
        [_textFieldDestinationFolder setEnabled:NO];
        [_buttonChooseDestinationFolder setEnabled:NO];
        if ([settingsDict[NBCSettingsDisableWiFiKey] boolValue] ) {
            [_checkboxDisableWiFi setEnabled:NO];
        } else {
            [_checkboxDisableWiFi setEnabled:YES];
        }
    } else {
        [_popUpButtonTool setEnabled:YES];
        [_textFieldDestinationFolder setEnabled:YES];
        [_buttonChooseDestinationFolder setEnabled:YES];
    }
    
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
    
    if ( [_jssCACertificate count] != 0 ) {
        if ( _jssCACertificate[_casperJSSURL] ) {
            NSImage *imageSuccess = [[NSImage alloc] initWithContentsOfFile:IconSuccessPath];
            [_imageViewDownloadJSSCertificateStatus setImage:imageSuccess];
            [_buttonShowJSSCertificate setHidden:NO];
            [_textFieldDownloadJSSCertificateStatus setStringValue:@"Downloaded"];
            [_imageViewDownloadJSSCertificateStatus setHidden:NO];
            [_textFieldDownloadJSSCertificateStatus setHidden:NO];
            for ( NSDictionary *certDict in _certificateTableViewContents ) {
                if ( [certDict[@"CertificateSignature"] isEqualToData:_jssCACertificate[_casperJSSURL]] ) {
                    [self updateJSSCACertificateExpirationFromDateNotValidAfter:certDict[@"CertificateNotValidAfterDate"]
                                                             dateNotValidBefore:certDict[@"CertificateNotValidBeforeDate"]];
                }
            }
        } else {
            [_buttonShowJSSCertificate setHidden:YES];
            [_textFieldDownloadJSSCertificateStatus setStringValue:@""];
            [_imageViewDownloadJSSCertificateStatus setHidden:YES];
            [_textFieldDownloadJSSCertificateStatus setHidden:YES];
        }
    } else {
        [_buttonShowJSSCertificate setHidden:YES];
        [_textFieldDownloadJSSCertificateStatus setStringValue:@""];
        [_imageViewDownloadJSSCertificateStatus setHidden:YES];
        [_textFieldDownloadJSSCertificateStatus setHidden:YES];
    }
    
    [_imageViewVerifyJSSStatus setHidden:YES];
    [_textFieldVerifyJSSStatus setHidden:YES];
    [_textFieldVerifyJSSStatus setStringValue:@""];
    NSURL *stringAsURL = [NSURL URLWithString:_casperJSSURL];
    if ( stringAsURL && [stringAsURL scheme] && [stringAsURL host] ) {
        [self jssURLIsValid];
        if ( _connectedToInternet ) {
            [self buttonVerifyJSS:nil];
        } else {
            [self setVerifyJSSWhenConnected:YES];
        }
    } else {
        [self jssURLIsInvalid];
    }
    
    if ( [_casperImagingPath length] != 0 ) {
        NSBundle *bundle = [NSBundle bundleWithPath:_casperImagingPath];
        if ( bundle != nil ) {
            NSString *bundleIdentifier = [bundle objectForInfoDictionaryKey:@"CFBundleIdentifier"];
            if ( [bundleIdentifier isEqualToString:NBCCasperImagingBundleIdentifier] ) {
                NSString *bundleVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                if ( [bundleVersion length] != 0 ) {
                    [self setCasperImagingVersion:bundleVersion];
                }
            }
        }
    }
    
    NSString *selectedTimeZone = settingsDict[NBCSettingsTimeZoneKey];
    if ( [selectedTimeZone length] == 0 || [selectedTimeZone isEqualToString:NBCMenuItemCurrent] ) {
        [self selectTimeZone:[_popUpButtonTimeZone itemWithTitle:NBCMenuItemCurrent]];
    } else {
        NSString *selectedTimeZoneRegion = [selectedTimeZone componentsSeparatedByString:@"/"][0];
        NSString *selectedTimeZoneCity = [selectedTimeZone componentsSeparatedByString:@"/"][1];
        NSArray *regionArray = [[[_popUpButtonTimeZone itemWithTitle:selectedTimeZoneRegion] submenu] itemArray];
        for ( NSMenuItem *menuItem in regionArray ) {
            if ( [[menuItem title] isEqualToString:selectedTimeZoneCity] ) {
                [self selectTimeZone:menuItem];
                break;
            }
        }
    }
    
    [self expandVariablesForCurrentSettings];
    
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

- (void)updateJSSCACertificateExpirationFromDateNotValidAfter:(NSDate *)dateAfter dateNotValidBefore:(NSDate *)dateBefore {
#pragma unused(dateBefore)
    NSDate *dateNow = [NSDate date];
    
    BOOL certificateExpired = NO;
    if ( [dateBefore compare:dateNow] == NSOrderedDescending ) {
        // Not valid before...
        
    }
    
    if ( [dateAfter compare:dateNow] == NSOrderedAscending && ! certificateExpired ) {
        // Expired...
    } else {
        // Expires...
    }
    
    NSTimeInterval secondsBetween = [dateAfter timeIntervalSinceDate:dateNow];
    NSDateComponentsFormatter *dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
    NSCalendar *calendarUS = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    [calendarUS setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];
    [dateComponentsFormatter setCalendar:calendarUS];
    [dateComponentsFormatter setUnitsStyle:NSDateComponentsFormatterUnitsStyleFull];
    [dateComponentsFormatter setMaximumUnitCount:3];
    NSString *expirationString = [dateComponentsFormatter stringFromTimeInterval:secondsBetween];
    if ( [expirationString length] != 0 ) {
        [self setJssCACertificateExpirationString:expirationString];
    }
}

- (void)updateUISettingsFromURL:(NSURL *)url {
    
    NSDictionary *mainDict = [[NSDictionary alloc] initWithContentsOfURL:url];
    if ( mainDict ) {
        NSDictionary *settingsDict = mainDict[NBCSettingsSettingsKey];
        if ( settingsDict ) {
            [self updateUISettingsFromDict:settingsDict];
        } else {
            DDLogError(@"[ERROR] No key named 'Settings' i plist at URL: %@", url);
        }
    } else {
        DDLogError(@"[ERROR] Could not read plist at URL: %@", url);
    }
} // updateUISettingsFromURL

- (NSDictionary *)returnSettingsFromUI {
    
    NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
    
    settingsDict[NBCSettingsNBICreationToolKey] = _nbiCreationTool ?: @"NBICreator";
    settingsDict[NBCSettingsNameKey] = _nbiName ?: @"";
    settingsDict[NBCSettingsIndexKey] = _nbiIndex ?: @"1";
    settingsDict[NBCSettingsProtocolKey] = _nbiProtocol ?: @"NFS";
    settingsDict[NBCSettingsLanguageKey] = _nbiLanguage ?: @"Current";
    settingsDict[NBCSettingsKeyboardLayoutKey] = _nbiKeyboardLayout ?: @"Current";
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
    settingsDict[NBCSettingsIconKey] = _nbiIconPath ?: @"%APPLICATIONRESOURCESURL%/IconCasperImaging.icns";
    settingsDict[NBCSettingsDisableWiFiKey] = @(_disableWiFi) ?: @NO;
    settingsDict[NBCSettingsDisableBluetoothKey] = @(_disableBluetooth) ?: @NO;
    settingsDict[NBCSettingsDisplaySleepMinutesKey] = @(_displaySleepMinutes) ?: @30;
    settingsDict[NBCSettingsDisplaySleepKey] = ( _displaySleepMinutes == 120 ) ? @NO : @YES;
    settingsDict[NBCSettingsIncludeSystemUIServerKey] = @(_includeSystemUIServer) ?: @NO;
    settingsDict[NBCSettingsCasperImagingPathKey] = _casperImagingPath ?: @"";
    settingsDict[NBCSettingsCasperJSSURLKey] = _casperJSSURL ?: @"";
    settingsDict[NBCSettingsARDLoginKey] = _ardLogin ?: @"";
    settingsDict[NBCSettingsARDPasswordKey] = _ardPassword ?: @"";
    settingsDict[NBCSettingsUseNetworkTimeServerKey] = @(_useNetworkTimeServer) ?: @NO;
    settingsDict[NBCSettingsNetworkTimeServerKey] = _networkTimeServer ?: @"time.apple.com";
    //settingsDict[NBCSettingsCasperSourceIsNBI] = @(_isNBI) ?: @NO;
    settingsDict[NBCSettingsUseBackgroundImageKey] = @(_useBackgroundImage) ?: @NO;
    settingsDict[NBCSettingsBackgroundImageKey] = _imageBackgroundURL ?: @"%SOURCEURL%/System/Library/CoreServices/DefaultDesktop.jpg";
    settingsDict[NBCSettingsUseVerboseBootKey] = @(_useVerboseBoot) ?: @NO;
    settingsDict[NBCSettingsDiskImageReadWriteKey] = @(_diskImageReadWrite) ?: @NO;
    settingsDict[NBCSettingsIncludeConsoleAppKey] = @(_includeConsoleApp) ?: @NO;
    settingsDict[NBCSettingsCasperAllowInvalidCertificateKey] = @(_allowInvalidCertificate) ?: @NO;
    settingsDict[NBCSettingsCasperJSSCACertificateKey] = _jssCACertificate ?: @{};
    settingsDict[NBCSettingsCasperImagingDebugModeKey] = @(_enableCasperImagingDebugMode) ?: @NO;
    settingsDict[NBCSettingsEnableLaunchdLoggingKey] = @(_enableLaunchdLogging) ?: @NO;
    settingsDict[NBCSettingsLaunchConsoleAppKey] = @(_launchConsoleApp) ?: @NO;
    settingsDict[NBCSettingsIncludeRubyKey] = @(_includeRuby) ?: @NO;
    settingsDict[NBCSettingsAddTrustedNetBootServersKey] = @(_addTrustedNetBootServers) ?: @NO;
    settingsDict[NBCSettingsAddCustomRAMDisksKey] = @(_addCustomRAMDisks) ?: @NO;
    settingsDict[NBCSettingsIncludePythonKey] = @(_includePython) ?: @NO;
    
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
#pragma unused(nbiURL)
    /*
     
     NSError *err;
     if ( ! [nbiURL checkResourceIsReachableAndReturnError:&err] ) {
     NSLog(@"Could not find NBI!");
     NSLog(@"Error: %@", err);
     return;
     }
     
     NSURL *nbImageInfoURL = [nbiURL URLByAppendingPathComponent:@"NBImageInfo.plist"];
     if ( ! [nbImageInfoURL checkResourceIsReachableAndReturnError:&err] ) {
     NSLog(@"Could not find nbImageInfoURL");
     NSLog(@"Error: %@", err);
     return;
     }
     
     NSDictionary *nbImageInfoDict = [[NSDictionary alloc] initWithContentsOfURL:nbImageInfoURL];
     NSMutableDictionary *settingsDict = [[NSMutableDictionary alloc] init];
     
     //settingsDict[NBCSettingsCasperSourceIsNBI] = @YES;
     
     NSString *nbiName = nbImageInfoDict[NBCNBImageInfoDictNameKey];
     if ( nbiName != nil ) {
     settingsDict[NBCSettingsNameKey] = nbiName;
     } else {
     settingsDict[NBCSettingsNameKey] = _nbiName ?: @"";
     }
     
     NSNumber *nbiIndex = nbImageInfoDict[NBCNBImageInfoDictIndexKey];
     if ( nbiIndex != nil ) {
     settingsDict[NBCSettingsIndexKey] = [nbiIndex stringValue];
     } else if ( _nbiIndex != nil ) {
     settingsDict[NBCSettingsIndexKey] = _nbiIndex;
     }
     
     NSString *nbiProtocol = nbImageInfoDict[NBCNBImageInfoDictProtocolKey];
     if ( nbiProtocol != nil ) {
     settingsDict[NBCSettingsProtocolKey] = nbiProtocol;
     } else {
     settingsDict[NBCSettingsProtocolKey] = _nbiProtocol ?: @"NFS";
     }
     
     NSString *nbiLanguage = nbImageInfoDict[NBCNBImageInfoDictLanguageKey];
     if ( nbiLanguage != nil ) {
     settingsDict[NBCSettingsLanguageKey] = nbiLanguage;
     } else {
     settingsDict[NBCSettingsLanguageKey] = _nbiLanguage ?: @"Current";
     }
     
     BOOL nbiEnabled = [nbImageInfoDict[NBCNBImageInfoDictIsEnabledKey] boolValue];
     if ( @(nbiEnabled) != nil ) {
     settingsDict[NBCSettingsEnabledKey] = @(nbiEnabled);
     } else {
     settingsDict[NBCSettingsEnabledKey] = @(_nbiEnabled) ?: @NO;
     }
     
     BOOL nbiDefault = [nbImageInfoDict[NBCNBImageInfoDictIsDefaultKey] boolValue];
     if ( @(nbiDefault) != nil ) {
     settingsDict[NBCSettingsDefaultKey] = @(nbiDefault);
     } else {
     settingsDict[NBCSettingsDefaultKey] = @(_nbiDefault) ?: @NO;
     }
     
     NSString *nbiDescription = nbImageInfoDict[NBCNBImageInfoDictDescriptionKey];
     if ( [nbiDescription length] != 0 ) {
     settingsDict[NBCSettingsDescriptionKey] = nbiDescription;
     } else {
     settingsDict[NBCSettingsDescriptionKey] = _nbiDescription ?: @"";
     }
     
     NSURL *destinationFolderURL = [_source sourceURL];
     if ( destinationFolderURL != nil ) {
     settingsDict[NBCSettingsDestinationFolderKey] = [destinationFolderURL path];
     } else if ( _destinationFolder != nil ) {
     NSString *currentUserHome = NSHomeDirectory();
     if ( [_destinationFolder hasPrefix:currentUserHome] ) {
     NSString *destinationFolderPath = [_destinationFolder stringByReplacingOccurrencesOfString:currentUserHome withString:@"~"];
     settingsDict[NBCSettingsDestinationFolderKey] = destinationFolderPath;
     } else {
     settingsDict[NBCSettingsDestinationFolderKey] = _destinationFolder; }
     }
     
     //NSImage *nbiIcon = [[NSWorkspace sharedWorkspace] iconForFile:[nbiURL path]]; // To be fixed later
     
     settingsDict[NBCSettingsIconKey] = _nbiIconPath ?: @"";
     
     BOOL nbiCasperConfigurationDictFound = NO;
     BOOL nbiCasperVersionFound = NO;
     if ( _target != nil ) {
     NSURL *nbiNetInstallVolumeURL = [_target nbiNetInstallVolumeURL];
     NSURL *nbiBaseSystemVolumeURL = [_target baseSystemVolumeURL];
     if ( [nbiNetInstallVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
     NSURL *nbiCasperConfigurationDictURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCCasperConfigurationPlistTargetURL];
     if ( [nbiCasperConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
     NSDictionary *nbiCasperConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiCasperConfigurationDictURL];
     if ( [nbiCasperConfigurationDict count] != 0 ) {
     NSString *CasperConfigurationURL = nbiCasperConfigurationDict[NBCSettingsCasperServerURLKey];
     if ( CasperConfigurationURL != nil ) {
     settingsDict[NBCSettingsCasperConfigurationURL] = CasperConfigurationURL;
     [_target setCasperConfigurationPlistURL:nbiCasperConfigurationDictURL];
     nbiCasperConfigurationDictFound = YES;
     }
     }
     }
     
     NSURL *nbiApplicationURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCCasperApplicationTargetURL];
     if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
     NSString *nbiCasperVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
     if ( [nbiCasperVersion length] != 0 ) {
     settingsDict[NBCSettingsCasperVersion] = nbiCasperVersion;
     [_target setCasperApplicationExistOnTarget:YES];
     [_target setCasperApplicationURL:nbiApplicationURL];
     nbiCasperVersionFound = YES;
     }
     }
     } else if ( [nbiBaseSystemVolumeURL checkResourceIsReachableAndReturnError:nil] ) {
     NSURL *nbiCasperConfigurationDictURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCCasperConfigurationPlistNBICreatorTargetURL];
     if ( [nbiCasperConfigurationDictURL checkResourceIsReachableAndReturnError:nil] ) {
     NSDictionary *nbiCasperConfigurationDict = [[NSDictionary alloc] initWithContentsOfURL:nbiCasperConfigurationDictURL];
     if ( [nbiCasperConfigurationDict count] != 0 ) {
     NSString *CasperConfigurationURL = nbiCasperConfigurationDict[NBCSettingsCasperServerURLKey];
     if ( CasperConfigurationURL != nil ) {
     settingsDict[NBCSettingsCasperConfigurationURL] = CasperConfigurationURL;
     [_target setCasperConfigurationPlistURL:nbiCasperConfigurationDictURL];
     nbiCasperConfigurationDictFound = YES;
     }
     }
     }
     
     NSURL *nbiApplicationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCCasperApplicationNBICreatorTargetURL];
     if ( [nbiApplicationURL checkResourceIsReachableAndReturnError:nil] ) {
     NSString *nbiCasperVersion = [[NSBundle bundleWithURL:nbiApplicationURL] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
     if ( [nbiCasperVersion length] != 0 ) {
     settingsDict[NBCSettingsCasperVersion] = nbiCasperVersion;
     [_target setCasperApplicationExistOnTarget:YES];
     [_target setCasperApplicationURL:nbiApplicationURL];
     nbiCasperVersionFound = YES;
     }
     }
     }
     
     if ( ! nbiCasperConfigurationDictFound ) {
     settingsDict[NBCSettingsCasperConfigurationURL] = @"";
     }
     
     if ( ! nbiCasperVersionFound ) {
     settingsDict[NBCSettingsCasperVersion] = NBCMenuItemCasperVersionLatest;
     }
     
     if ( @(_includeCasperPreReleaseVersions) != nil ) {
     settingsDict[NBCSettingsCasperIncludePreReleaseVersions] = @(_includeCasperPreReleaseVersions);
     }
     
     NSString *rcInstall;
     NSURL *rcInstallURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCCasperRCInstallTargetURL];
     if ( [rcInstallURL checkResourceIsReachableAndReturnError:nil] ) {
     rcInstall = [NSString stringWithContentsOfURL:rcInstallURL encoding:NSUTF8StringEncoding error:&err];
     
     }
     
     NSString *rcImaging;
     NSURL *rcImagingURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:NBCCasperRCImagingNBICreatorTargetURL];
     if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
     rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
     
     } else {
     rcImagingURL = [nbiNetInstallVolumeURL URLByAppendingPathComponent:NBCCasperRCImagingTargetURL];
     if ( [rcImagingURL checkResourceIsReachableAndReturnError:nil] ) {
     rcImaging = [NSString stringWithContentsOfURL:rcImagingURL encoding:NSUTF8StringEncoding error:&err];
     }
     }
     
     [_target setRcImagingContent:rcImaging];
     [_target setRcImagingURL:rcImagingURL];
     
     NSString *rcFiles = [NSString stringWithFormat:@"%@\n%@", rcInstall, rcImaging];
     
     if ( [rcFiles length] != 0 ) {
     NSArray *rcFilesArray = [rcFiles componentsSeparatedByString:@"\n"];
     for ( NSString *line in rcFilesArray ) {
     if ( [line containsString:@"pmset"] && [line containsString:@"displaysleep"] ) {
     NSError* regexError = nil;
     NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"displaysleep [0-9]+"
     options:0
     error:&regexError];
     
     if ( regex == nil ) {
     NSLog(@"Regex creation failed with error: %@", [regexError description]);
     }
     
     NSArray *matches = [regex matchesInString:line
     options:NSMatchingWithoutAnchoringBounds
     range:NSMakeRange(0, line.length)];
     
     for (NSTextCheckingResult *entry in matches) {
     NSString *text = [line substringWithRange:entry.range];
     if ( [text length] != 0 ) {
     NSString *displaySleepTime = [text componentsSeparatedByString:@" "][1];
     if ( [displaySleepTime length] != 0 ) {
     if ( [displaySleepTime integerValue] == 0 ) {
     settingsDict[NBCSettingsDisplaySleepKey] = @NO;
     settingsDict[NBCSettingsDisplaySleepMinutesKey] = @120;
     } else {
     settingsDict[NBCSettingsDisplaySleepKey] = @YES;
     settingsDict[NBCSettingsDisplaySleepMinutesKey] = @([displaySleepTime intValue]);
     }
     }
     }
     }
     }
     }
     }
     
     NSURL *wifiKext = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"System/Library/Extensions/IO80211Family.kext"];
     if ( [wifiKext checkResourceIsReachableAndReturnError:nil] ) {
     settingsDict[NBCSettingsDisableWiFiKey] = @NO;
     } else {
     settingsDict[NBCSettingsDisableWiFiKey] = @YES;
     }
     
     // Get network Time Server
     NSURL *ntpConfigurationURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"etc/ntp.conf"];
     if ( [ntpConfigurationURL checkResourceIsReachableAndReturnError:nil] ) {
     NSString *ntpConfiguration = [NSString stringWithContentsOfURL:ntpConfigurationURL encoding:NSUTF8StringEncoding error:nil];
     NSArray *ntpConfigurationArray = [ntpConfiguration componentsSeparatedByString:@"\n"];
     NSString *ntpConfigurationFirstLine = ntpConfigurationArray[0];
     if ( [ntpConfigurationFirstLine containsString:@"server"] ) {
     NSString *ntpServer = [ntpConfigurationFirstLine componentsSeparatedByString:@" "][1];
     if ( [ntpServer length] != 0 ) {
     settingsDict[NBCSettingsNetworkTimeServerKey] = ntpServer;
     }
     }
     }
     
     
     NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
     [helperConnector connectToHelper];
     
     [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
     [[NSOperationQueue mainQueue]addOperationWithBlock:^{
     
     // ------------------------------------------------------------------
     //  If task failed, post workflow failed notification
     // ------------------------------------------------------------------
     DDLogError(@"[ERROR] %@", proxyError);
     }];
     
     }] readSettingsFromNBI:nbiBaseSystemVolumeURL settingsDict:[settingsDict copy] withReply:^(NSError *error, BOOL success, NSDictionary *newSettingsDict) {
     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
     
     if ( success )
     {
     NSLog(@"Success");
     NSLog(@"newSettingsDict=%@", newSettingsDict);
     [self updateUISettingsFromDict:newSettingsDict];
     [self saveUISettingsWithName:nbiName atUrl:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@.nbictemplate", NSTemporaryDirectory(), [[NSUUID UUID] UUIDString]]]]; // Temporary, to test
     [self->_templates updateTemplateListForPopUpButton:self->_popUpButtonTemplates title:nbiName];
     [self verifyBuildButton];
     } else {
     NSLog(@"CopyFailed!");
     NSLog(@"Error: %@", error);
     }
     }];
     }];
     
     
     // Get any configured user name
     NSURL *dsLocalUsersURL = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"var/db/dslocal/nodes/Default/users"];
     if ( [dsLocalUsersURL checkResourceIsReachableAndReturnError:&err] ) {
     NSArray *userFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[dsLocalUsersURL path] error:nil];
     NSMutableArray *userFilesFiltered = [[userFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (self BEGINSWITH '_')"]] mutableCopy];
     [userFilesFiltered removeObjectsInArray:@[ @"daemon.plist", @"nobody.plist", @"root.plist" ]];
     if ( [userFilesFiltered count] != 0 ) {
     NSString *firstUser = userFilesFiltered[0];
     NSURL *firstUserPlistURL = [dsLocalUsersURL URLByAppendingPathComponent:firstUser];
     NSDictionary *firstUserDict = [NSDictionary dictionaryWithContentsOfURL:firstUserPlistURL];
     if ( firstUserDict ) {
     NSArray *userNameArray = firstUserDict[@"name"];
     NSString *userName = userNameArray[0];
     if ( [userName length] != 0 ) {
     settingsDict[NBCSettingsARDLoginKey] = userName;
     }
     }
     }
     } else {
     NSLog(@"Could not get path to local user database");
     NSLog(@"Error: %@", err);
     }
     
     // Get any configured user password
     NSURL *vncPasswordFile = [nbiBaseSystemVolumeURL URLByAppendingPathComponent:@"Library/Preferences/com.apple.VNCSettings.txt"];
     if ( [vncPasswordFile checkResourceIsReachableAndReturnError:nil] ) {
     NSURL *commandURL = [NSURL fileURLWithPath:@"/bin/bash"];
     NSMutableArray *args = [NSMutableArray arrayWithObjects:@"-c",
     [NSString stringWithFormat:@"/bin/cat %@ | perl -wne 'BEGIN { @k = unpack \"C*\", pack \"H*\", \"1734516E8BA8C5E2FF1C39567390ADCA\"}; chomp; @p = unpack \"C*\", pack \"H*\", $_; foreach (@k) { printf \"%%c\", $_ ^ (shift @p || 0) }; print \"\n\"'", [vncPasswordFile path]],
     nil];
     NSPipe *stdOut = [[NSPipe alloc] init];
     NSFileHandle *stdOutFileHandle = [stdOut fileHandleForWriting];
     [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
     __block NSString *outStr;
     NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
     id stdOutObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
     object:[stdOut fileHandleForReading]
     queue:nil
     usingBlock:^(NSNotification *notification){
     #pragma unused(notification)
     
     // ------------------------
     //  Convert data to string
     // ------------------------
     NSData *stdOutdata = [[stdOut fileHandleForReading] availableData];
     outStr = [[[NSString alloc] initWithData:stdOutdata encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
     
     // -----------------------------------------------------------------------
     //  When output data becomes available, pass it to workflow status parser
     // -----------------------------------------------------------------------
     NSLog(@"outStr=%@", outStr);
     
     [[stdOut fileHandleForReading] waitForDataInBackgroundAndNotify];
     }];
     
     // -----------------------------------------------------------------------------------
     //  Create standard error file handle and register for data available notifications.
     // -----------------------------------------------------------------------------------
     NSPipe *stdErr = [[NSPipe alloc] init];
     NSFileHandle *stdErrFileHandle = [stdErr fileHandleForWriting];
     [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
     __block NSString *errStr;
     id stdErrObserver = [nc addObserverForName:NSFileHandleDataAvailableNotification
     object:[stdErr fileHandleForReading]
     queue:nil
     usingBlock:^(NSNotification *notification){
     #pragma unused(notification)
     
     // ------------------------
     //  Convert data to string
     // ------------------------
     NSData *stdErrdata = [[stdErr fileHandleForReading] availableData];
     errStr = [[NSString alloc] initWithData:stdErrdata encoding:NSUTF8StringEncoding];
     
     // -----------------------------------------------------------------------
     //  When error data becomes available, pass it to workflow status parser
     // -----------------------------------------------------------------------
     NSLog(@"errStr=%@", errStr);
     
     [[stdErr fileHandleForReading] waitForDataInBackgroundAndNotify];
     }];
     
     NBCHelperConnection *helperConnector = [[NBCHelperConnection alloc] init];
     [helperConnector connectToHelper];
     
     [[[helperConnector connection] remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
     [[NSOperationQueue mainQueue]addOperationWithBlock:^{
     
     // ------------------------------------------------------------------
     //  If task failed, post workflow failed notification
     // ------------------------------------------------------------------
     NSLog(@"ProxyError? %@", proxyError);
     [nc removeObserver:stdOutObserver];
     [nc removeObserver:stdErrObserver];
     }];
     
     }] runTaskWithCommandAtPath:commandURL arguments:args environmentVariables:nil stdOutFileHandleForWriting:stdOutFileHandle stdErrFileHandleForWriting:stdErrFileHandle withReply:^(NSError *error, int terminationStatus) {
     #pragma unused(error)
     [[NSOperationQueue mainQueue]addOperationWithBlock:^{
     [nc removeObserver:stdOutObserver];
     [nc removeObserver:stdErrObserver];
     
     if ( terminationStatus == 0 )
     {
     if ( [outStr length] != 0 ) {
     settingsDict[NBCSettingsARDPasswordKey] = outStr;
     }
     [self updateUISettingsFromDict:settingsDict];
     [self->_templates updateTemplateListForPopUpButton:self->_popUpButtonTemplates title:nbiName];
     [self verifyBuildButton];
     [self->_textFieldDestinationFolder setEnabled:NO];
     [self->_buttonChooseDestinationFolder setEnabled:NO];
     [self->_popUpButtonTool setEnabled:NO];
     } else {
     
     }
     }];
     }];
     
     }
     
     }
     */
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
    mainDict[NBCSettingsTypeKey] = NBCSettingsTypeCasper;
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
            DDLogError(@"[ERROR] Casper template folder create failed!");
            DDLogError(@"[ERROR] %@", error);
        }
    }
    
    // -------------------------------------------------------------
    //  Write settings to url and update _templatesDict
    // -------------------------------------------------------------
    if ( [mainDict writeToURL:settingsURL atomically:NO] ) {
        _templatesDict[name] = settingsURL;
    } else {
        NSLog(@"Writing Casper template to disk failed!");
    }
} // saveUISettingsWithName:atUrl

- (BOOL)haveSettingsChanged {
    
    BOOL retval = YES;
    
    NSURL *defaultSettingsURL = [[NSBundle mainBundle] URLForResource:NBCFileNameCasperDefaults withExtension:@"plist"];
    if ( defaultSettingsURL ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        if ( [defaultSettingsURL checkResourceIsReachableAndReturnError:nil] ) {
            NSDictionary *defaultSettings = [NSDictionary dictionaryWithContentsOfURL:defaultSettingsURL];
            if ( currentSettings && defaultSettings ) {
                if ( [currentSettings isEqualToDictionary:defaultSettings] ) {
                    return NO;
                }
            }
        }
    }
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        return retval;
    }
    
    NSURL *savedSettingsURL = _templatesDict[_selectedTemplate];
    if ( savedSettingsURL ) {
        NSDictionary *currentSettings = [self returnSettingsFromUI];
        NSDictionary *savedSettings = [self returnSettingsFromURL:savedSettingsURL];
        if ( currentSettings && savedSettings ) {
            if ( [currentSettings isEqualToDictionary:savedSettings] ) {
                retval = NO;
            }
        } else {
            NSLog(@"Could not compare UI settings to saved template settings, one of them is nil!");
        }
    } else {
        NSLog(@"Could not get URL to current template file!");
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
    [self setImageBackground:customBackgroundPath];
    
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

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark IBAction PopUpButtons
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (void)importTemplateAtURL:(NSURL *)url templateInfo:(NSDictionary *)templateInfo {
    
    NSLog(@"Importing %@", url);
    NSLog(@"templateInfo=%@", templateInfo);
} // importTemplateAtURL

- (void)updatePopUpButtonTemplates {
    
    [_templates updateTemplateListForPopUpButton:_popUpButtonTemplates title:nil];
} // updatePopUpButtonTemplates

- (IBAction)popUpButtonTemplates:(id)sender {
    
    NSString *selectedTemplate = [[sender selectedItem] title];
    BOOL settingsChanged = [self haveSettingsChanged];
    
    if ( [_selectedTemplate isEqualToString:NBCMenuItemUntitled] ) {
        [_templates showSheetSaveUntitled:selectedTemplate buildNBI:NO];
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

- (void)showSystemImageUtilityVersion {
    
    [self setUseSystemImageUtility:YES];
    [_constraintTemplatesBoxHeight setConstant:93];
    [_constraintSavedTemplatesToTool setConstant:32];
} // showCasperLocalVersionInput

- (void)hideSystemImageUtilityVersion {
    
    [self setUseSystemImageUtility:NO];
    [_constraintTemplatesBoxHeight setConstant:70];
    [_constraintSavedTemplatesToTool setConstant:8];
} // hideCasperLocalVersionInput

- (IBAction)buttonChooseCasperImagingPath:(id)sender {
#pragma unused(sender)
    
    NSOpenPanel* chooseDestionation = [NSOpenPanel openPanel];
    
    // --------------------------------------------------------------
    //  Setup open dialog to only allow one folder to be chosen.
    // --------------------------------------------------------------
    [chooseDestionation setTitle:@"Select Casper Imaging Application"];
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
            if ( [bundleIdentifier isEqualToString:NBCCasperImagingBundleIdentifier] ) {
                [self setCasperImagingPath:[selectedURL path]];
                NSString *bundleVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
                if ( [bundleVersion length] != 0 ) {
                    [self setCasperImagingVersion:bundleVersion];
                }
                return;
            }
        }
        [NBCAlerts showAlertUnrecognizedCasperImagingApplication];
    }
} // buttonChooseCasperLocalPath

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

- (void)buildNBI {
    
    if ( [self haveSettingsChanged] ) {
        NSDictionary *alertInfo = @{ NBCAlertTagKey : NBCAlertTagSettingsUnsavedBuild,
                                     NBCAlertUserInfoSelectedTemplate : _selectedTemplate };
        
        NBCAlerts *alert = [[NBCAlerts alloc] initWithDelegate:self];
        [alert showAlertSettingsUnsavedBuild:@"You have unsaved settings, do you want to save current template and continue?"
                                   alertInfo:alertInfo];
    } else if ( _isNBI && ! [self haveSettingsChanged] ) {
        [NBCAlerts showAlertSettingsUnchangedNBI];
        return;
    } else {
        [self verifySettings];
    }
} // buildNBI

- (void)verifySettings {
    
    DDLogInfo(@"Verifying settings...");
    NBCWorkflowItem *workflowItem = [[NBCWorkflowItem alloc] initWithWorkflowType:kWorkflowTypeCasper
                                                              workflowSessionType:kWorkflowSessionTypeGUI];
    [workflowItem setSource:_source];
    [workflowItem setApplicationSource:_siuSource];
    [workflowItem setSettingsViewController:self];
    
    // ----------------------------------------------------------------
    //  Collect current UI settings and pass them through verification
    // ----------------------------------------------------------------
    NSDictionary *userSettings = [self returnSettingsFromUI];
    if ( userSettings ) {
        
        // Add userSettings dict to workflowItem
        [workflowItem setUserSettings:userSettings];
        
        // Instantiate settingsController and run verification
        NBCSettingsController *sc = [[NBCSettingsController alloc] init];
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
                    [alertInformativeText appendString:[NSString stringWithFormat:@"\n\n• %@", errorString]];
                }
            }
            
            if ( [warning count] != 0 ) {
                configurationWarning = YES;
                for ( NSString *warningString in warning ) {
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
            [self prepareWorkflowItem:workflowItem];
        }
    } else {
        DDLogError(@"Could not get settings from UI");
    }
} // verifySettings

- (void)prepareWorkflowItem:(NBCWorkflowItem *)workflowItem {
    NSDictionary *userSettings = [workflowItem userSettings];
    NSMutableDictionary *resourcesSettings = [[NSMutableDictionary alloc] init];
    
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
        
        /* Should not access property lists directly, keeping it around for now
         NSDictionary *globalPreferencesDict = [NSDictionary dictionaryWithContentsOfFile:NBCFilePathPreferencesGlobal];
         NSString *currentLanguageID = globalPreferencesDict[@"AppleLanguages"][0];
         DDLogInfo(@"Current Language ID: %@", currentLanguageID);
         if ( [currentLanguageID length] != 0 ) {
         resourcesSettings[NBCSettingsLanguageKey] = currentLanguageID;
         } else {
         DDLogError(@"[ERROR] Could not get current language ID!");
         return;
         }
         
         NSString *currentLocaleIdentifier = globalPreferencesDict[@"AppleLocale"];
         DDLogInfo(@"currentLocaleIdentifier=%@", currentLocaleIdentifier);
         if ( [currentLocaleIdentifier length] != 0 ) {
         resourcesSettings[NBCSettingsLocale] = currentLocaleIdentifier;
         }
         
         NSString *currentCountry = globalPreferencesDict[@"Country"];
         DDLogInfo(@"currentCountry=%@", currentCountry);
         if ( [currentCountry length] != 0 ) {
         resourcesSettings[NBCSettingsCountry] = currentCountry;
         }
         */
    } else {
        NSString *languageID = [_languageDict allKeysForObject:selectedLanguage][0];
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
    
    NSMutableArray *certificates = [[NSMutableArray alloc] init];
    for ( NSDictionary *certificateDict in _certificateTableViewContents ) {
        NSData *certificate = certificateDict[NBCDictionaryKeyCertificate];
        [certificates addObject:certificate];
    }
    resourcesSettings[NBCSettingsCertificatesKey] = certificates;
    
    NSMutableArray *packages = [[NSMutableArray alloc] init];
    for ( NSDictionary *packageDict in _packagesTableViewContents ) {
        NSString *packagePath = packageDict[NBCDictionaryKeyPackagePath];
        [packages addObject:packagePath];
    }
    resourcesSettings[NBCSettingsPackagesKey] = packages;
    
    // -------------------------------------------------------------
    //  Create list of items to extract from installer
    // -------------------------------------------------------------
    NSMutableDictionary *sourceItemsDict = [[NSMutableDictionary alloc] init];
    int sourceVersionMinor = (int)[[[workflowItem source] expandVariables:@"%OSMINOR%"] integerValue];
    
    if ( [userSettings[NBCSettingsIncludePythonKey] boolValue] ) {
        [NBCSourceController addPython:sourceItemsDict source:_source];
    }
    
    [NBCSourceController addCasperImaging:sourceItemsDict source:_source];
    
    // - AppleScript is required for Casper
    [NBCSourceController addAppleScript:sourceItemsDict source:_source];
    
    // - Dtrace for now
    //[NBCSourceController addDtrace:sourceItemsDict source:_source];
    
    // - spctl
    [NBCSourceController addSpctl:sourceItemsDict source:_source];
    
    // - taskgated
    //[NBCSourceController addTaskgated:sourceItemsDict source:_source];
    
    // - NSURLStoraged + NSURLSessiond
    [NBCSourceController addNSURLStoraged:sourceItemsDict source:_source];
    
    if ( 11 <= sourceVersionMinor ) {
        [NBCSourceController addLibSsl:sourceItemsDict source:_source];
    }
    
    // - Console.app
    if ( [userSettings[NBCSettingsIncludeConsoleAppKey] boolValue] ) {
        [NBCSourceController addConsole:sourceItemsDict source:_source];
    }
    
    // - Kernel
    if ( [userSettings[NBCSettingsDisableWiFiKey] boolValue] || [userSettings[NBCSettingsDisableBluetoothKey] boolValue] ) {
        [NBCSourceController addKernel:sourceItemsDict source:_source];
    }
    
    // - Desktop Picture
    if ( [userSettings[NBCSettingsUseBackgroundImageKey] boolValue] && [userSettings[NBCSettingsBackgroundImageKey] isEqualToString:NBCBackgroundImageDefaultPath] ) {
        [NBCSourceController addDesktopPicture:sourceItemsDict source:_source];
    }
    
    // - NTP
    if ( [userSettings[NBCSettingsUseNetworkTimeServerKey] boolValue] ) {
        [NBCSourceController addNTP:sourceItemsDict source:_source];
    }
    
    // - SystemUIServer
    if ( [userSettings[NBCSettingsIncludeSystemUIServerKey] boolValue] ) {
        [NBCSourceController addSystemUIServer:sourceItemsDict source:_source];
    }
    
    // - systemkeychain
    if ( [userSettings[NBCSettingsCertificatesKey] count] != 0 ) {
        [NBCSourceController addSystemkeychain:sourceItemsDict source:_source];
    }
    
    // - Ruby
    if ( [userSettings[NBCSettingsIncludeRubyKey] boolValue] ) {
        [NBCSourceController addRuby:sourceItemsDict source:_source];
    }
    
    // - VNC if an ARD/VNC password has been set
    if ( [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [NBCSourceController addVNC:sourceItemsDict source:_source];
    }
    
    // - ARD if both ARD login name and ARD/VNC password has been set
    if ( [userSettings[NBCSettingsARDLoginKey] length] != 0 && [userSettings[NBCSettingsARDPasswordKey] length] != 0 ) {
        [NBCSourceController addARD:sourceItemsDict source:_source];
        //[NBCSourceController addKerberos:sourceItemsDict source:_source];
    }
    
    // -------------------------------------------------------------
    //  In OS X 10.11 all sources moved to Essentials.pkg
    //  This moves all BSD and AdditionalEssentials-regexes to Essentials
    // -------------------------------------------------------------
    if ( 11 <= sourceVersionMinor ) {
        [NBCSourceController addNetworkd:sourceItemsDict source:_source];
        
        NSString *packageAdditionalEssentialsPath = [NSString stringWithFormat:@"%@/Packages/AdditionalEssentials.pkg", [[_source installESDVolumeURL] path]];
        NSMutableDictionary *packageAdditionalEssentialsDict = sourceItemsDict[packageAdditionalEssentialsPath];
        NSMutableArray *packageAdditionalEssentialsRegexes;
        if ( [packageAdditionalEssentialsDict count] != 0 ) {
            packageAdditionalEssentialsRegexes = packageAdditionalEssentialsDict[NBCSettingsSourceItemsRegexKey];
            NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
            NSMutableArray *packageEssentialsRegexes;
            if ( [packageEssentialsDict count] == 0 ) {
                packageEssentialsDict = [[NSMutableDictionary alloc] init];
            }
            packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
            if ( packageEssentialsRegexes == nil ) {
                packageEssentialsRegexes = [[NSMutableArray alloc] init];
            }
            [packageEssentialsRegexes addObjectsFromArray:packageAdditionalEssentialsRegexes];
            packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects] ;
            sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
            [sourceItemsDict removeObjectForKey:packageAdditionalEssentialsPath];
        }
        
        NSString *packageBSDPath = [NSString stringWithFormat:@"%@/Packages/BSD.pkg", [[_source installESDVolumeURL] path]];
        NSMutableDictionary *packageBSDDict = sourceItemsDict[packageBSDPath];
        NSArray *packageBSDRegexes;
        if ( [packageBSDDict count] != 0 ) {
            packageBSDRegexes = packageBSDDict[NBCSettingsSourceItemsRegexKey];
            NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
            NSMutableArray *packageEssentialsRegexes;
            if ( [packageEssentialsDict count] == 0 ) {
                packageEssentialsDict = [[NSMutableDictionary alloc] init];
            }
            packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
            if ( packageEssentialsRegexes == nil ) {
                packageEssentialsRegexes = [[NSMutableArray alloc] init];
            }
            [packageEssentialsRegexes addObjectsFromArray:packageBSDRegexes];
            packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects];;
            sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
            [sourceItemsDict removeObjectForKey:packageBSDPath];
        }
        
        NSString *packageBaseSystemBinariesPath = [NSString stringWithFormat:@"%@/Packages/BaseSystemBinaries.pkg", [[_source installESDVolumeURL] path]];
        NSMutableDictionary *packageBaseSystemBinariesDict = sourceItemsDict[packageBaseSystemBinariesPath];
        NSArray *packageBaseSystemBinariesRegexes;
        if ( [packageBaseSystemBinariesDict count] != 0 ) {
            packageBaseSystemBinariesRegexes = packageBaseSystemBinariesDict[NBCSettingsSourceItemsRegexKey];
            NSString *packageEssentialsPath = [NSString stringWithFormat:@"%@/Packages/Essentials.pkg", [[_source installESDVolumeURL] path]];
            NSMutableDictionary *packageEssentialsDict = sourceItemsDict[packageEssentialsPath];
            NSMutableArray *packageEssentialsRegexes;
            if ( [packageEssentialsDict count] == 0 ) {
                packageEssentialsDict = [[NSMutableDictionary alloc] init];
            }
            packageEssentialsRegexes = [packageEssentialsDict[NBCSettingsSourceItemsRegexKey] mutableCopy];
            if ( packageEssentialsRegexes == nil ) {
                packageEssentialsRegexes = [[NSMutableArray alloc] init];
            }
            [packageEssentialsRegexes addObjectsFromArray:packageBaseSystemBinariesRegexes];
            packageEssentialsDict[NBCSettingsSourceItemsRegexKey] = [[NSSet setWithArray:[packageEssentialsRegexes copy]] allObjects];;
            sourceItemsDict[packageEssentialsPath] = packageEssentialsDict;
            [sourceItemsDict removeObjectForKey:packageBaseSystemBinariesPath];
        }
    }
    
    resourcesSettings[NBCSettingsSourceItemsKey] = sourceItemsDict;
    [workflowItem setResourcesSettings:[resourcesSettings copy]];
    
    // -------------------------------------------------------------
    //  Instantiate all workflows to be used to create a Casper NBI
    // -------------------------------------------------------------
    NBCCasperWorkflowResources *workflowResources = [[NBCCasperWorkflowResources alloc] init];
    [workflowItem setWorkflowResources:workflowResources];
    
    NBCCasperWorkflowNBI *workflowNBI = [[NBCCasperWorkflowNBI alloc] init];
    [workflowItem setWorkflowNBI:workflowNBI];
    
    NBCCasperWorkflowModifyNBI *workflowModifyNBI = [[NBCCasperWorkflowModifyNBI alloc] init];
    [workflowItem setWorkflowModifyNBI:workflowModifyNBI];
    
    // -------------------------------------------------------------
    //  Post notification to add workflow item to queue
    // -------------------------------------------------------------
    NSDictionary *userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : workflowItem };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationAddWorkflowItemToQueue object:self userInfo:userInfo];
    
} // prepareWorkflowItem

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
}

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
        [menuItemAfrica setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAfrica];
        
        NSMenuItem *menuItemAmerica = [[NSMenuItem alloc] initWithTitle:@"America" action:nil keyEquivalent:@""];
        [menuItemAmerica setSubmenu:menuAmerica];
        [menuItemAmerica setTarget:self];
        [menuItemAmerica setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAmerica];
        
        NSMenuItem *menuItemAntarctica = [[NSMenuItem alloc] initWithTitle:@"Antarctica" action:nil keyEquivalent:@""];
        [menuItemAntarctica setSubmenu:menuAntarctica];
        [menuItemAntarctica setTarget:self];
        [menuItemAntarctica setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAntarctica];
        
        NSMenuItem *menuItemArctic = [[NSMenuItem alloc] initWithTitle:@"Arctic" action:nil keyEquivalent:@""];
        [menuItemArctic setSubmenu:menuArctic];
        [menuItemArctic setTarget:self];
        [menuItemArctic setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemArctic];
        
        NSMenuItem *menuItemAsia = [[NSMenuItem alloc] initWithTitle:@"Asia" action:nil keyEquivalent:@""];
        [menuItemAsia setSubmenu:menuAsia];
        [menuItemAsia setTarget:self];
        [menuItemAsia setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAsia];
        
        NSMenuItem *menuItemAtlantic = [[NSMenuItem alloc] initWithTitle:@"Atlantic" action:nil keyEquivalent:@""];
        [menuItemAtlantic setSubmenu:menuAtlantic];
        [menuItemAtlantic setTarget:self];
        [menuItemAtlantic setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAtlantic];
        
        NSMenuItem *menuItemAustralia = [[NSMenuItem alloc] initWithTitle:@"Australia" action:nil keyEquivalent:@""];
        [menuItemAustralia setSubmenu:menuAustralia];
        [menuItemAustralia setTarget:self];
        [menuItemAustralia setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemAustralia];
        
        NSMenuItem *menuItemEurope = [[NSMenuItem alloc] initWithTitle:@"Europe" action:nil keyEquivalent:@""];
        [menuItemEurope setSubmenu:menuEurope];
        [menuItemEurope setTarget:self];
        [menuItemEurope setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemEurope];
        
        NSMenuItem *menuItemIndian = [[NSMenuItem alloc] initWithTitle:@"Indian" action:nil keyEquivalent:@""];
        [menuItemIndian setSubmenu:menuIndian];
        [menuItemIndian setTarget:self];
        [menuItemIndian setEnabled:YES];
        [[_popUpButtonTimeZone menu] addItem:menuItemIndian];
        
        NSMenuItem *menuItemPacific = [[NSMenuItem alloc] initWithTitle:@"Pacific" action:nil keyEquivalent:@""];
        [menuItemPacific setSubmenu:menuPacific];
        [menuItemPacific setTarget:self];
        [menuItemPacific setEnabled:YES];
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

- (void)populatePopUpButtonLanguage {
    
    /* Localized Names
     NSArray *localeIdentifiers = [NSLocale availableLocaleIdentifiers];
     for ( NSString *identifier in localeIdentifiers ) {
     
     NSLocale *tmpLocale = [[NSLocale alloc] initWithLocaleIdentifier:identifier];
     NSString *localeIdentifier = [tmpLocale objectForKey: NSLocaleIdentifier];
     NSString *localeIdentifierDisplayName = [tmpLocale displayNameForKey:NSLocaleIdentifier value:localeIdentifier];
     
     NSLog(@"localeIdentifierDisplayName = %@", localeIdentifierDisplayName);
     NSLog(@"localeIdentifier = %@", localeIdentifier);
     }
     */
    
    /* English Names
     NSMutableDictionary *mutableLanguageDict = [[NSMutableDictionary alloc] init];
     NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
     NSArray *localeIdentifiers = [NSLocale availableLocaleIdentifiers];
     for ( NSString *identifier in localeIdentifiers ) {
     mutableLanguageDict[identifier] = [locale displayNameForKey:NSLocaleIdentifier value:identifier];
     }
     _languageDict = [mutableLanguageDict mutableCopy];
     */
    
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
    [_tableViewCertificates reloadData];
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
    [_tableViewPackages reloadData];
}

- (NSString *)jssVersionFromDownloadData:(NSData *)data {
    NSString *jssVersion;
    
    TFHpple *parser = [TFHpple hppleWithHTMLData:data];
    
    NSString *xpathQueryString = @"/html/head/meta[@name='version']/@content";
    NSArray *nodes = [parser searchWithXPathQuery:xpathQueryString];
    
    if ( ! nodes ) {
        NSString *downloadString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"downloadString=%@", downloadString);
    }
    
    for ( TFHppleElement *element in nodes ) {
        NSArray *children = [element children];
        for (TFHppleElement *childElement in children) {
            jssVersion = [childElement content];
        }
    }
    
    return [jssVersion copy];
}

- (IBAction)buttonVerifyJSS:(id)sender {
#pragma unused(sender)
    [self setVerifyingJSS:YES];
    [_imageViewVerifyJSSStatus setHidden:YES];
    [_textFieldVerifyJSSStatus setStringValue:@"Contacting JSS..."];
    [_textFieldVerifyJSSStatus setHidden:NO];
    
    NSString *jssURLString = _casperJSSURL;
    NSURL *jssURL;
    if ( [jssURLString length] == 0 ) {
        [_imageViewVerifyJSSStatus setHidden:NO];
        [_textFieldVerifyJSSStatus setHidden:NO];
        [_textFieldVerifyJSSStatus setStringValue:@"No URL was passed!"];
        // Show Alert
        return;
    } else {
        jssURL = [NSURL URLWithString:jssURLString];
    }
    
    if ( ! _jssVersionDownloader ) {
        _jssVersionDownloader = [[NBCDownloader alloc] initWithDelegate:self];
    }
    
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagJSSVerify };
    [_jssVersionDownloader downloadPageAsData:jssURL downloadInfo:downloadInfo];
}

- (void)downloadFailed:(NSDictionary *)downloadInfo withError:(NSError *)error {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagJSSCertificate] ) {
        NSString *errorMessage = @"";
        if ( error ) {
            errorMessage = [error localizedDescription];
        }
        
        [self setDownloadingJSSCertificate:NO];
        NSImage *imageWarning = [NSImage imageNamed:@"NSCaution"];
        [_imageViewDownloadJSSCertificateStatus setImage:imageWarning];
        [_imageViewDownloadJSSCertificateStatus setHidden:NO];
        [_textFieldDownloadJSSCertificateStatus setStringValue:errorMessage];
        [_textFieldDownloadJSSCertificateStatus setHidden:NO];
    } else if ( [downloadTag isEqualToString:NBCDownloaderTagJSSVerify] ) {
        NSString *errorMessage = @"";
        if ( error ) {
            errorMessage = [error localizedDescription];
        }
        
        [self setVerifyingJSS:NO];
        NSImage *imageWarning = [NSImage imageNamed:@"NSCaution"];
        [_imageViewVerifyJSSStatus setImage:imageWarning];
        [_imageViewVerifyJSSStatus setHidden:NO];
        [_textFieldVerifyJSSStatus setStringValue:errorMessage];
        [_textFieldVerifyJSSStatus setHidden:NO];
    }
}

- (void)dataDownloadCompleted:(NSData *)data downloadInfo:(NSDictionary *)downloadInfo {
    NSString *downloadTag = downloadInfo[NBCDownloaderTag];
    if ( [downloadTag isEqualToString:NBCDownloaderTagJSSCertificate] ) {
        [self setDownloadingJSSCertificate:NO];
        NSDictionary *certificateDict = [self examineCertificate:data];
        if ( [certificateDict count] != 0 ) {
            if ( [_casperJSSURL length] != 0 ) {
                _jssCACertificate = @{ _casperJSSURL : certificateDict[@"CertificateSignature"] };
            }
            
            NSString *status;
            NSImage *image;
            
            if ( [self insertCertificateInTableView:certificateDict] ) {
                status = @"Downloaded";
            } else {
                status = @"Already Exist";
            }
            
            if ( [certificateDict[@"CertificateExpired"] boolValue] ) {
                image = [NSImage imageNamed:@"NSCaution"];
                NSMutableAttributedString *certificateExpired = [[NSMutableAttributedString alloc] initWithString:@"Certificate Expired"];
                [certificateExpired addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:NSMakeRange(0,(NSUInteger)[certificateExpired length])];
                [_textFieldDownloadJSSCertificateStatus setAttributedStringValue:certificateExpired];
            } else {
                image = [[NSImage alloc] initWithContentsOfFile:IconSuccessPath];
                [_textFieldDownloadJSSCertificateStatus setStringValue:status];
            }
            
            [self updateJSSCACertificateExpirationFromDateNotValidAfter:certificateDict[@"CertificateNotValidAfterDate"]
                                                     dateNotValidBefore:certificateDict[@"CertificateNotValidBeforeDate"]];
            
            [_imageViewDownloadJSSCertificateStatus setImage:image];
            [_textFieldDownloadJSSCertificateStatus setHidden:NO];
            [_imageViewDownloadJSSCertificateStatus setHidden:NO];
            [_buttonShowJSSCertificate setHidden:NO];
        } else {
            
        }
    } else if ( [downloadTag isEqualToString:NBCDownloaderTagJSSVerify] ) {
        NSString *jssVersion = [self jssVersionFromDownloadData:data];
        if ( [jssVersion length] != 0 ) {
            [self setJssVersion:jssVersion];
            [self setVerifyingJSS:NO];
            NSImage *imageSuccess = [[NSImage alloc] initWithContentsOfFile:IconSuccessPath];
            [_imageViewVerifyJSSStatus setImage:imageSuccess];
            [_imageViewVerifyJSSStatus setHidden:NO];
            [_textFieldVerifyJSSStatus setHidden:NO];
            [_textFieldVerifyJSSStatus setStringValue:[NSString stringWithFormat:@"Verified JSS Version: %@", jssVersion]];
        } else {
            [self setVerifyingJSS:NO];
            NSImage *imageCaution = [NSImage imageNamed:@"NSCaution"];
            [_imageViewVerifyJSSStatus setImage:imageCaution];
            [_imageViewVerifyJSSStatus setHidden:NO];
            [_textFieldVerifyJSSStatus setHidden:NO];
            [_textFieldVerifyJSSStatus setStringValue:@"Unable to determine JSS version"];
        }
    }
}

- (IBAction)buttonDownloadJSSCertificate:(id)sender {
#pragma unused(sender)
    [_buttonShowJSSCertificate setHidden:YES];
    [self setDownloadingJSSCertificate:YES];
    [_imageViewDownloadJSSCertificateStatus setHidden:YES];
    [_textFieldDownloadJSSCertificateStatus setHidden:NO];
    [_textFieldDownloadJSSCertificateStatus setStringValue:@"Contacting JSS..."];
    
    NSString *jssURLString = _casperJSSURL;
    NSURL *jssCertificateURL;
    if ( [jssURLString length] != 0 ) {
        jssCertificateURL = [[NSURL URLWithString:jssURLString] URLByAppendingPathComponent:NBCCasperJSSCertificateURLPath];
        NSURLComponents *components = [[NSURLComponents alloc] initWithURL:jssCertificateURL resolvingAgainstBaseURL:NO];
        NSURLQueryItem *queryItems = [NSURLQueryItem queryItemWithName:@"operation" value:@"getcacert"];
        [components setQueryItems:@[ queryItems ]];
        jssCertificateURL = [components URL];
    } else {
        [_imageViewDownloadJSSCertificateStatus setHidden:NO];
        [_textFieldDownloadJSSCertificateStatus setHidden:NO];
        [_textFieldDownloadJSSCertificateStatus setStringValue:@"No URL was passed!"];
        // Show Alert
        return;
    }
    
    if ( ! _jssCertificateDownloader ) {
        _jssCertificateDownloader = [[NBCDownloader alloc] initWithDelegate:self];
    }
    NSDictionary *downloadInfo = @{ NBCDownloaderTag : NBCDownloaderTagJSSCertificate };
    [_jssCertificateDownloader downloadPageAsData:jssCertificateURL downloadInfo:downloadInfo];
}

- (IBAction)buttonShowJSSCertificate:(id)sender {
#pragma unused(sender)
    [_tabViewCasperSettings selectTabViewItemWithIdentifier:NBCTabViewItemExtra];
    if ( [_casperJSSURL length] != 0 ) {
        __block NSData *jssCACertificateSignature = _jssCACertificate[_casperJSSURL];
        if ( jssCACertificateSignature ) {
            [_certificateTableViewContents enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                if ( [jssCACertificateSignature isEqualToData:obj[@"CertificateSignature"]] ) {
                    [self->_tableViewCertificates selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
                    *stop = YES;
                }
            }];
        }
    }
}

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
    // Insert new view
    NSInteger index = [self insertNetBootServerIPInTableView:@""];
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:(NSUInteger)index];
    
    // Select the newly created text field in the new view
    [_tableViewTrustedServers selectRowIndexes:indexSet byExtendingSelection:NO];
    [[[_tableViewTrustedServers viewAtColumn:[_tableViewTrustedServers selectedColumn]
                                         row:index
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
        NBCCasperTrustedNetBootServerCellView *cellView = [self->_tableViewTrustedServers viewAtColumn:0 row:(NSInteger)idx makeIfNecessary:NO];
        
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
        
        NBCCasperRAMDiskPathCellView *cellView = [self->_tableViewRAMDisks viewAtColumn:0
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
