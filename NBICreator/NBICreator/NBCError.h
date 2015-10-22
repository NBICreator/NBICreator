//
//  NBCError.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-22.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, NBCErrorCodes) {
    /** Success **/
    kNBCErrorSuccess,
    /** Unknown Error **/
    kNBCErrorUnknown
};

@interface NBCError : NSObject

+ (NSError *)errorWithCode:(int)errorCode;
+ (NSError *)errorWithDescription:(NSString *)errorDescription;

@end
