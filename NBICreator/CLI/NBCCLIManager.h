//
//  NBCCLIManager.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-04.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCCLIManager : NSObject

// -------------------------------------------------------------
//  Class Methods
// -------------------------------------------------------------
+ (id)sharedManager;

- (void)verifyCLIArguments;

@end
