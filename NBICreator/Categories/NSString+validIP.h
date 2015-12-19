//
//  NSString+validIP.h
//  NBICreator
//
//  Taken from http://stackoverflow.com/a/10971521/4596429.
//

#import <Foundation/Foundation.h>

@interface NSString (NBCvalidIP)

- (BOOL)isValidIPAddress;
- (BOOL)isValidHostname;

@end
