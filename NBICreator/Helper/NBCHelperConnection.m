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
    if ( _connection == nil ) {
        _connection = [[NSXPCConnection alloc] initWithMachServiceName:NBCBundleIdentifierHelper
                                                               options:NSXPCConnectionPrivileged];
        
        [_connection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(NBCHelperProtocol)]];
        
        // If the connection gets invalidated set it to nil on the main thread.
        // This ensures that we attempt to rebuild it the next time around.
        
        [_connection setInvalidationHandler:^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            [self->_connection setInvalidationHandler:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_connection = nil;
            });
#pragma clang diagnostic pop
        }];
        
        [_connection setExportedObject:self];
        [_connection resume];
    }
}

@end
