//
//  NBCPackageTableCellView.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-08-05.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NBCPackageTableCellView : NSTableCellView

@property (weak) IBOutlet NSImageView *imageViewPackageIcon;
@property (weak) IBOutlet NSTextField *textFieldPackageName;

@end
