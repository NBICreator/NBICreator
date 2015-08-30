//
//  NBCWorkflowProgressViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowProgressViewController.h"

#import "NBCConstants.h"
#import "NBCLogging.h"

DDLogLevel ddLogLevel;

@interface NBCWorkflowProgressViewController ()

@end

@implementation NBCWorkflowProgressViewController

////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initialization
#pragma mark -
////////////////////////////////////////////////////////////////////////////////

- (id)init {
    self = [super initWithNibName:@"NBCWorkflowProgressViewController" bundle:nil];
    if (self != nil) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(workflowCompleteNBI:) name:NBCNotificationWorkflowCompleteNBI object:nil];
        [center addObserver:self selector:@selector(workflowCompleteResources:) name:NBCNotificationWorkflowCompleteResources object:nil];
        _messageDelegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setWorkflowComplete:NO];
    [_textFieldStatusInfo setStringValue:@"Waiting..."];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)workflowCompleteNBI:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    if ( [[_workflowItem workflowNBI] isEqualTo:[notification object]] ) {
        [self setWorkflowNBIComplete:YES];
        if ( ! _workflowNBIResourcesComplete ) {
            if ( [_workflowNBIResourcesLastStatus length] == 0 ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldStatusInfo setStringValue:@"Preparing Resources to be added to NBI..."];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self->_textFieldStatusInfo setStringValue:self->_workflowNBIResourcesLastStatus];
                });
            }
        }
    }
}

- (void)workflowCompleteResources:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setWorkflowNBIResourcesComplete:YES];
}

- (IBAction)buttonCancel:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem
                                                        object:self
                                                      userInfo:@{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : _workflowItem }];
    
    NSDictionary *errorUserInfo = @{
                                    NSLocalizedDescriptionKey: NSLocalizedString(@"Workflow Canceled.", nil),
                                    NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"User canceled workflow.", nil),
                                    };
    NSError *error = [NSError errorWithDomain:NBCErrorDomain code:-1 userInfo:errorUserInfo];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationWorkflowFailed
                                                        object:self
                                                      userInfo:@{ NBCUserInfoNSErrorKey : error }];
}

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    
    if ( [workflow isEqualTo:[_workflowItem workflowNBI]] && ! _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && ! _workflowNBIComplete ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setWorkflowNBIResourcesLastStatus:statusMessage];
        });
    } else if ( [workflow isEqualTo:[_workflowItem workflowModifyNBI]] ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_textFieldStatusInfo setStringValue:statusMessage];
        });
    }
}


- (void)updateProgressBar:(double)value {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_progressIndicator setDoubleValue:value];
    [_progressIndicator setNeedsDisplay:YES];
}

- (IBAction)buttonShowInFinder:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _nbiURL ) {
        NSString *destinationFileName = [_nbiURL lastPathComponent];
        if ( [destinationFileName containsString:@" "] ) {
            destinationFileName = [destinationFileName stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            _nbiURL = [[_nbiURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:destinationFileName];
            if ( ! _nbiURL ) {
                DDLogError(@"[ERROR] NBI URL is nil, cannot open in Finder!");
                return;
            }
        }
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _nbiURL ]];
    }
}
- (IBAction)buttonOpenLog:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _nbiLogURL ) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[ _nbiLogURL ]];
    }
}

- (void)workflowStartedForItem:(NBCWorkflowItem *)workflowItem {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [self setWorkflowItem:workflowItem];
    [self setNbiURL:[_workflowItem nbiURL]];
    [self setIsRunning:YES];
    [_layoutContraintStatusInfoLeading setConstant:24.0];
}

- (void)workflowFailedWithError:(NSString *)errorMessage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_layoutContraintStatusInfoLeading setConstant:1.0];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [self setIsRunning:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_textFieldStatusInfo setStringValue:[NSString stringWithFormat:@"ERROR: %@", errorMessage]];
    });
}

- (void)updateProgress:(NSString *)message {
    NSLog(@"updateProgress!!!!");
    NSLog(@"message=%@", message);
}

- (void)workflowCompleted {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_layoutContraintStatusInfoLeading setConstant:1.0];
    
    NSCalendar *calendarUS = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian];
    calendarUS.locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
    
    NSDate *startTime = [_workflowItem startTime];
    NSDate *endTime = [NSDate date];
    NSTimeInterval secondsBetween = [endTime timeIntervalSinceDate:startTime];
    NSDateComponentsFormatter *dateComponentsFormatter = [[NSDateComponentsFormatter alloc] init];
    dateComponentsFormatter.maximumUnitCount = 3;
    dateComponentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    dateComponentsFormatter.calendar = calendarUS;
    
    NSString *workflowTime = [dateComponentsFormatter stringFromTimeInterval:secondsBetween];
    if ( [workflowTime length] != 0 ) {
        [_workflowItem setWorkflowTime:workflowTime];
    }
    
    [self setWorkflowComplete:YES];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [self setIsRunning:NO];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_textFieldStatusInfo setStringValue:[NSString stringWithFormat:@"NBI created successfully in %@!", workflowTime]];
    });
}

@end
