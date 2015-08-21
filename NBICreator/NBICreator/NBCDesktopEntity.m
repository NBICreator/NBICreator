//
//  NBCDesktopEntity.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-08-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCDesktopEntity.h"

@implementation NBCDesktopEntity

- (id)initWithFileURL:(NSURL *)fileURL {
    self = [super init];
    if ( self ) {
        _fileURL = fileURL;
    }
    return self;
}

+ (NBCDesktopEntity *)entityForURL:(NSURL *)url {
    NSString *typeIdentifier;
    if ( [url getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:nil] ) {
        NSArray *certificateUTIs = @[ @"public.x509-certificate" ];
        NSArray *packageUTIs = @[ @"com.apple.installer-package-archive" ];
        if ( [certificateUTIs containsObject:typeIdentifier] ) {
            return [[NBCDesktopCertificateEntity alloc] initWithFileURL:url];
        } else if ( [packageUTIs containsObject:typeIdentifier] ) {
            return [[NBCDesktopPackageEntity alloc] initWithFileURL:url];
        } else if ( [typeIdentifier isEqualToString:(NSString *)kUTTypeFolder] ) {
            return [[NBCDesktopFolderEntity alloc] initWithFileURL:url];
        }
    }
    return nil;
}

- (NSString *)name {
    NSString *name;
    if ( [_fileURL getResourceValue:&name forKey:NSURLLocalizedNameKey error:nil] ) {
        return name;
    }
    return nil;
}

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NSPasteboardReading
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
#pragma unused(pasteboard)
    return @[ (id)kUTTypeFolder, (id)kUTTypeFileURL ];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
#pragma unused(type, pasteboard)
    return NSPasteboardReadingAsString;
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    NSURL *url = [[NSURL alloc] initWithPasteboardPropertyList:propertyList ofType:type];
    self = [NBCDesktopEntity entityForURL:url];
    return self;
}

@end

#pragma mark -
@implementation NBCDesktopCertificateEntity

- (NSData *)certificate {
    if ( !_certificate ) {
        NSError *error;
        NSMutableString *certificateString = [NSMutableString stringWithContentsOfURL:self.fileURL encoding:NSUTF8StringEncoding error:&error];
        if ( [certificateString length] != 0 ) {
            [certificateString setString:[certificateString stringByReplacingOccurrencesOfString:@"-----BEGIN CERTIFICATE-----" withString:@""]];
            [certificateString setString:[certificateString stringByReplacingOccurrencesOfString:@"-----END CERTIFICATE-----" withString:@""]];
            _certificate = [[NSData alloc] initWithBase64EncodedString:certificateString options:NSDataBase64DecodingIgnoreUnknownCharacters];
        } else {
            _certificate = [[NSData alloc] initWithContentsOfURL:self.fileURL];
        }
    }
    return _certificate;
}

@end

#pragma mark -
@implementation NBCDesktopPackageEntity

@end

#pragma mark -
@implementation NBCDesktopFolderEntity

@end
