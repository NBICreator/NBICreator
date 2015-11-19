//
//  NBCHelperConnection.m
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
