//
//  NBCDesktopEntity.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-08-10.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface NBCDesktopEntity : NSObject <NSPasteboardReading>

@property (strong, nonatomic) NSURL *fileURL;
@property (strong, readonly) NSString *name;

- (id)initWithFileURL:(NSURL *)fileURL;
+ (NBCDesktopEntity *)entityForURL:(NSURL *)url;

@end

@interface NBCDesktopFolderEntity : NBCDesktopEntity

@end

@interface NBCDesktopCertificateEntity : NBCDesktopEntity

@property (strong, nonatomic) NSData *certificate;

@end

@interface NBCDesktopPackageEntity : NBCDesktopEntity

@end
