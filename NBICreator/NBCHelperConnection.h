//
//  NBCHelperConnection.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBCHelperConnection : NSObject

@property (atomic, strong, readonly) NSXPCConnection *connection;

- (void)connectToHelper;

@end
