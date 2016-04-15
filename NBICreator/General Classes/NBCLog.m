//
//  NBCLog.m
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

#import "NBCConstants.h"
#import "NBCLog.h"
#import "NBCWorkflowItem.h"

DDLogLevel ddLogLevel;

@implementation NBCLog

+ (void)configureLoggingFor:(int)sessionType {

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
    if (logLevel) {

        // --------------------------------------------------------------
        //  If log level was set to Debug, lower to Info
        // --------------------------------------------------------------
        if ([logLevel intValue] == (int)DDLogLevelDebug) {
            ddLogLevel = DDLogLevelInfo;
            [[NSUserDefaults standardUserDefaults] setObject:@((int)ddLogLevel) forKey:NBCUserDefaultsLogLevel];
        } else {
            ddLogLevel = (DDLogLevel)[logLevel intValue];
        }
    } else {
        ddLogLevel = DDLogLevelWarning;
        [[NSUserDefaults standardUserDefaults] setObject:@((int)ddLogLevel) forKey:NBCUserDefaultsLogLevel];
    }

    NSString *logLevelName;

    switch (sessionType) {
    case kWorkflowSessionTypeCLI:

        break;
    case kWorkflowSessionTypeGUI:
        DDLogError(@"");
        DDLogError(@"Starting NBICreator version %@ (build %@)...", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
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
            logLevelName = [@((int)ddLogLevel) stringValue];
            break;
        }
        DDLogInfo(@"Log level: %@", logLevelName);
        break;
    default:
        break;
    }
}

+ (DDFileLogger *)fileLogger {
    NSArray *allLoggers = [DDLog allLoggers];
    NSUInteger indexOfFileLogger = [allLoggers indexOfObjectPassingTest:^(id logger, NSUInteger idx, BOOL *stop) {
#pragma unused(idx, stop)
      return [logger isKindOfClass:[DDFileLogger class]];
    }];

    return indexOfFileLogger == NSNotFound ? nil : [allLoggers objectAtIndex:indexOfFileLogger];
}

@end
