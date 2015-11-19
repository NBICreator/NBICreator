//
//  NBCWorkflowProgressDelegate.h
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

#ifndef NBCWorkflowProgressDelegate_h
#define NBCWorkflowProgressDelegate_h

@protocol NBCWorkflowProgressDelegate
- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow;
- (void)updateProgressStatus:(NSString *)statusMessage;
- (void)updateProgressBar:(double)value;
- (void)incrementProgressBar:(double)value;
- (void)logDebug:(NSString *)logMessage;
- (void)logInfo:(NSString *)logMessage;
- (void)logWarn:(NSString *)logMessage;
- (void)logError:(NSString *)logMessage;
- (void)logStdOut:(NSString *)stdOutString;
- (void)logStdErr:(NSString *)stdErrString;
@end

#endif /* NBCWorkflowProgressDelegate_h */
