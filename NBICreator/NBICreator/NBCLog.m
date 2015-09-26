//
//  NBCLog.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-26.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import "NBCLog.h"
#import "NBCConstants.h"

DDLogLevel ddLogLevel;

@implementation NBCLog

+ (void)configureLogging {
    // --------------------------------------------------------------
    //  Log to Console (Xcode/Commandline)
    // --------------------------------------------------------------
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    // --------------------------------------------------------------
    //  Log to File
    // --------------------------------------------------------------
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    [fileLogger setMaximumFileSize:10000000]; // 10000000 = 10 MB
    [fileLogger setRollingFrequency:0];
    [[fileLogger logFileManager] setMaximumNumberOfLogFiles:7];
    [DDLog addLogger:fileLogger];
    
    // --------------------------------------------------------------
    //  Set log level from setting in application preferences
    // --------------------------------------------------------------
    NSNumber *logLevel = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsLogLevel];
    if ( logLevel ) {
        
        // --------------------------------------------------------------
        //  If log level was set to Debug, lower to Info
        // --------------------------------------------------------------
        if ( [logLevel intValue] == (int)DDLogLevelDebug ) {
            ddLogLevel = DDLogLevelInfo;
            [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:(int)ddLogLevel] forKey:NBCUserDefaultsLogLevel];
        } else {
            ddLogLevel = (DDLogLevel)[logLevel intValue];
        }
    } else {
        ddLogLevel = DDLogLevelWarning;
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:(int)ddLogLevel] forKey:NBCUserDefaultsLogLevel];
    }
    
    DDLogError(@"");
    DDLogError(@"Starting NBICreator version %@ (build %@)...", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
    NSString *logLevelName;
    switch (ddLogLevel) {
        case 1:
            logLevelName = @"Error";
            break;
        case 3:
            logLevelName = @"Warn";
            break;
        case 7:
            logLevelName = @"Info";
            break;
        case 15:
            logLevelName = @"Debug";
            break;
        default:
            logLevelName = [[NSNumber numberWithInt:(int)ddLogLevel] stringValue];
            break;
    }
    DDLogInfo(@"Log level: %@", logLevelName);
}

@end
