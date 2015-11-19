//
//  NBCError.m
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
    }
    return @{ NSLocalizedDescriptionKey : errorMessage };
};

@implementation NBCError

+ (NSError *)errorWithCode:(int)errorCode {
    NSDictionary *userInfo = userInfoFromCode(errorCode) ?: @{};
    return [NSError errorWithDomain:NBCErrorDomain code:errorCode userInfo:userInfo];
} // errorWithCode

+ (NSError *)errorWithDescription:(NSString *)errorDescription {
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorDescription ?: @"" };
    return [NSError errorWithDomain:NBCErrorDomain code:255 userInfo:userInfo];
} // errorWithCode

@end
