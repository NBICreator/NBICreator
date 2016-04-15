//
//  NBCDesktopEntity.h
//  NBICreator
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Imports
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopEntity : NSObject <NSPasteboardReading>

@property (strong, nonatomic) NSURL *fileURL;
@property (strong, readonly) NSString *name;

- (id)initWithFileURL:(NSURL *)fileURL;
+ (NBCDesktopEntity *)entityForURL:(NSURL *)url;

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopCertificateEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopCertificateEntity : NBCDesktopEntity

@property (strong, nonatomic) NSData *certificate;

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopPackageEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopPackageEntity : NBCDesktopEntity

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopScriptEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopScriptEntity : NBCDesktopEntity

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopConfigurationProfileEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopConfigurationProfileEntity : NBCDesktopEntity

@end

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark NBCDesktopFolderEntity
#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@interface NBCDesktopFolderEntity : NBCDesktopEntity

@end
