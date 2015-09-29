//
//  NBCLog.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef NBICreator_NBCLogging_h
#define NBICreator_NBCLogging_h

#import <CocoaLumberjack/CocoaLumberjack.h>
extern DDLogLevel ddLogLevel;
#endif

@interface NBCLog : NSObject

+ (void)configureLoggingFor:(int)sessionType;

@end
