//
//  NBCAlerts.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-17.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

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
+ (void)showAlertSettingsError:(NSString *)informativeText;
- (void)showAlertSettingsWarning:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsaved:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsavedBuild:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertSettingsUnsavedQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertWorkflowRunningQuit:(NSString *)informativeText alertInfo:(NSDictionary *)alertInfo;
- (void)showAlertDeleteTemplate:(NSString *)informativeText templateName:(NSString *)templateName  alertInfo:(NSDictionary *)alertInfo;

@end
