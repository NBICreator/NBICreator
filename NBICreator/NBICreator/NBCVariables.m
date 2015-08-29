//
//  NBCVariables.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-26.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCVariables.h"
#import "NBCConstants.h"

#import "NBCSource.h"
#import "NBCDeployStudioSource.h"
#import "NBCSystemImageUtilitySource.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@implementation NBCVariables

+ (NSString *)expandVariables:(NSString *)string source:(NBCSource *)source applicationSource:(id)applicationSource {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    NSString *newString = string;
    
    // -------------------------------------------------------------
    //  Expand variables for current application version
    // -------------------------------------------------------------
    NSDictionary *nbiCreatorInfoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *nbiCreatorVersion = nbiCreatorInfoDict[@"CFBundleShortVersionString"];
    NSString *nbiCreatorBuild = nbiCreatorInfoDict[@"CFBundleVersion"];
    NSString *nbiCreatorVersionString = [NSString stringWithFormat:@"%@-%@", nbiCreatorVersion, nbiCreatorBuild];
    newString = [newString stringByReplacingOccurrencesOfString:NBCVariableNBICreatorVersion
                                                     withString:nbiCreatorVersionString];
    
    // -------------------------------------------------------------
    //  Expand variables for current Source
    // -------------------------------------------------------------
    if ( source != nil ) {
        newString = [source expandVariables:newString];
    } else {
        NBCSource *tmpSource = [[NBCSource alloc] init];
        newString = [tmpSource expandVariables:newString];
    }
    
    // -------------------------------------------------------------
    //  Expand variables for current external application
    // -------------------------------------------------------------
    newString = [applicationSource expandVariables:newString];
    
    // --------------------------------------------------------------
    //  Expand %COUNTER%
    // --------------------------------------------------------------
    NSString *indexCounter;
    NSNumber *defaultsCounter = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsIndexCounter];
    if ( defaultsCounter ) {
        indexCounter = [NSString stringWithFormat:@"%@", defaultsCounter];
    } else {
        indexCounter = @"1024";
    }
    
    newString = [newString stringByReplacingOccurrencesOfString:NBCVariableIndexCounter
                                                     withString:indexCounter];
    
    // --------------------------------------------------------------
    //  Expand %APPLICATIONRESOURCESURL%
    // --------------------------------------------------------------
    NSString *applicationResourcesURL;
    applicationResourcesURL = [[NSBundle mainBundle] resourcePath];
    
    newString = [newString stringByReplacingOccurrencesOfString:NBCVariableApplicationResourcesURL
                                                     withString:applicationResourcesURL];
    
    // --------------------------------------------------------------
    //  Expand %DATE%
    // --------------------------------------------------------------
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSString *dateFormatString = [[NSUserDefaults standardUserDefaults] objectForKey:NBCUserDefaultsDateFormatString];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:dateFormatString];
    NSString *formattedDate = [dateFormatter stringFromDate:date];
    
    newString = [newString stringByReplacingOccurrencesOfString:NBCVariableDate
                                                     withString:formattedDate];
    return newString;
} // expandVariables

@end
