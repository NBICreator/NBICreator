//
//  NBCResolver.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-12-18.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCResolver : NSObject

@property NSString *hostname;
@property NSArray *addresses;
@property NSError *error;
@property BOOL shouldCancel, done;

- (id)initWithHostname:(NSString *)hostname;
- (BOOL)lookup;
@end
