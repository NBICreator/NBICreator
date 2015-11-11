//
//  NBCHelperAuthorization.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-17.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCHelperAuthorization : NSObject

+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command;
+ (NSData *)authorizeHelper;

@end
