//
//  NBCWorkflowProgressDelegate.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-10-29.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#ifndef NBCWorkflowProgressDelegate_h
#define NBCWorkflowProgressDelegate_h

@protocol NBCWorkflowProgressDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressBar:(double)value;
- (void)updateProgressStatus:(NSString *)statusMessage;
- (void)logDebug:(NSString *)logMessage;
- (void)logInfo:(NSString *)logMessage;
- (void)logWarn:(NSString *)logMessage;
- (void)logError:(NSString *)logMessage;
- (void)logStdOut:(NSString *)stdOutString;
- (void)logStdErr:(NSString *)stdErrString;
@end

#endif /* NBCWorkflowProgressDelegate_h */
