//
//  NBCError.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-22.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCError.h"
#import "NBCConstants.h"

static NSDictionary *userInfoFromCode(NBCErrorCodes errorCode) {
    NSString *errorMessage;
    switch ( errorCode ) {
        case kNBCErrorSuccess:
            errorMessage = @"Success";
            break;
        case kNBCErrorUnknown:
            errorMessage = @"Unknown Error";
            break;
        default:
            errorMessage = @"Unknown Error";
            break;
    }
    return @{ NSLocalizedDescriptionKey : errorMessage };
};

@implementation NBCError

+ (NSError *)errorWithCode:(int)errorCode {
    NSDictionary *userInfo = userInfoFromCode(errorCode) ?: @{};
    return [NSError errorWithDomain:NBCErrorDomain code:errorCode userInfo:userInfo];
}

+ (NSError *)errorWithDescription:(NSString *)errorDescription {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorDescription ?: @"" };
    return [NSError errorWithDomain:NBCErrorDomain code:255 userInfo:userInfo];
}

@end
