//
//  NBCHelperConnection.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-02-18.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCHelperConnection.h"

#import "NBCHelperProtocol.h"
#import "NBCConstants.h"

@interface NBCHelperConnection ()

@property (atomic, strong, readwrite) NSXPCConnection *connection;

@end

@implementation NBCHelperConnection

- (void)connectToHelper {
    
    // Ensure the connection to the helper tool.
    
    if (_connection == nil) {
        _connection = [[NSXPCConnection alloc] initWithMachServiceName:NBCBundleIdentifierHelper
                                                               options:NSXPCConnectionPrivileged];
        
        [_connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCHelperProtocol)]];
        
        // Ignore retain cycle warnings.
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        
        // If the connection gets invalidated set it to nil on the main thread.
        // This ensures that we attempt to rebuild it the next time around.
        
        [_connection setInvalidationHandler:^{
            
            [self->_connection setInvalidationHandler:nil];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self->_connection = nil;
                
                NSLog(@"connection invalidated");
            }];
            
        }];
        
        // Restore retain cycle warnings.
        
#pragma clang diagnostic pop
        
        // Start connection
        
        [_connection resume];
    }
}

@end
