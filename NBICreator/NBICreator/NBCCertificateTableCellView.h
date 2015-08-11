//
//  NBCCertificateTableCellView.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-08-05.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NBCCertificateTableCellView : NSTableCellView

@property (weak) IBOutlet NSImageView *imageViewCertificateIcon;
@property (weak) IBOutlet NSTextField *textFieldCertificateName;
@property (weak) IBOutlet NSTextField *textFieldCertificateExpiration;

@end
