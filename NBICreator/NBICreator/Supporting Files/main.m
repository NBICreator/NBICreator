//
//  main.m
//  NBC
//
//  Created by Erik Berglund.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    if ( argc == 3 && [[NSString stringWithUTF8String:argv[1]] isEqualToString:@"-NSDocumentRevisionsDebugMode"] ) {
        return NSApplicationMain(argc, argv);
    } else if ( 1 < argc ) {
        NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
        NSLog(@"%@", [args dictionaryRepresentation]);
        NSLog(@"%@", [args objectForKey:@"-source"]);
    } else {
        return NSApplicationMain(argc, argv);
    }
    
}
