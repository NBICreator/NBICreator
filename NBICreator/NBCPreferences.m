//
//  NBCPreferences.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-08.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCPreferences.h"

@interface NBCPreferences ()

@end

@implementation NBCPreferences

- (id)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)awakeFromNib {
    [self createPopUpButtonDateFormats];
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)controlTextDidChange:(NSNotification *)sender {
    if ( [sender object] == _comboBoxDateFormat ) {
        [self updateDatePreview];
    }
}

- (void)createPopUpButtonDateFormats {
    NSMutableArray *dateFormats = [[NSMutableArray alloc] init];
    [dateFormats addObject:@"yyyy-MM-dd"];
    [_comboBoxDateFormat addItemsWithObjectValues:dateFormats];
    [self updateDatePreview];
}

- (void)updateDatePreview {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSString *dateFormat = [_comboBoxDateFormat stringValue];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:dateFormat];
    NSDate *date = [NSDate date];
    NSString *formattedDate = [dateFormatter stringFromDate:date];
    [_textFieldDatePreview setStringValue:formattedDate];
}

- (IBAction)comboBoxDateFormat:(id)sender {
    #pragma unused(sender)
    [self updateDatePreview];
}
@end
