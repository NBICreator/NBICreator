//
//  NBCVariables.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-26.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
@class NBCSource;

@interface NBCVariables : NSObject

+ (NSString *)expandVariables:(NSString *)string source:(NBCSource *)source applicationSource:(id)applicationSource;

@end
