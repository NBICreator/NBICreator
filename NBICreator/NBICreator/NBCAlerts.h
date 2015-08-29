//
//  NBCAlerts.h
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

#import <Foundation/Foundation.h>

@protocol NBCAlertDelegate
- (void)alertReturnCode:(NSInteger)returnCode alertInfo:(NSDictionary *)alertInfo;
@end

@interface NBCAlerts : NSObject {
    id _delegate;
}

- (id)initWithDelegate:(id<NBCAlertDelegate>)delegate;
- (void)showAlertError:(NSError *)error;
+ (void)showAlertOKWithTitle:(NSString *)title informativeText:(NSString *)informativeText;
+ (void)showAlertUnrecognizedImagrApplication;
+ (void)showAlertRecoveryVersionMismatch;
+ (void)showAlertUnrecognizedSourceForWorkflow:(int)workflowType errorMessage:(NSString *)errorMessage;
+ (void)showAlertSettingsUnchangedNBI;
+ (void)showAlertImportTemplateDuplicate:(NSString *)informativeText;
+ (void)showAlertSettingsError:(NSString *)informativeText;
- (void)showAlertSettingsWarning:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsaved:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsavedBuild:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsavedQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertWorkflowRunningQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertDeleteTemplate:(NSString *)informativeText templateName:(NSString *)templateName  alertInfo:(NSDictionary *)alertInfo;

@end
