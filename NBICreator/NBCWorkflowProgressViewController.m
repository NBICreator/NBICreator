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

- (id)init {
    self = [super initWithNibName:@"NBCWorkflowProgressViewController" bundle:nil];
    if (self != nil) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(workflowCompleteNBI:) name:NBCNotificationWorkflowCompleteNBI object:nil];
        [center addObserver:self selector:@selector(workflowCompleteResources:) name:NBCNotificationWorkflowCompleteResources object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setWorkflowComplete:NO];
    [_textFieldStatusInfo setStringValue:@"Waiting..."];
}

- (void)workflowCompleteNBI:(NSNotification *)notification {
#pragma unused(notification)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    
    if ( [[_workflowItem workflowNBI] isEqualTo:[notification object]] ) {
        [self setWorkflowNBIComplete:YES];
        if ( ! _workflowNBIResourcesComplete ) {
            if ( [_workflowNBIResourcesLastStatus length] == 0 ) {
                [_textFieldStatusInfo setStringValue:@"Preparing Resources to be added to NBI..."];
            } else {
                [_textFieldStatusInfo setStringValue:_workflowNBIResourcesLastStatus];
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
    NSDictionary * userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : _workflowItem };
    [[NSNotificationCenter defaultCenter] postNotificationName:NBCNotificationRemoveWorkflowItemUserInfoWorkflowItem
                                                        object:self
                                                      userInfo:userInfo];
}

- (void)updateProgressStatus:(NSString *)statusMessage workflow:(id)workflow {
    
    if ( [workflow isEqualTo:[_workflowItem workflowNBI]] && ! _workflowNBIComplete ) {
        [_textFieldStatusInfo setStringValue:statusMessage];
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && _workflowNBIComplete ) {
        [_textFieldStatusInfo setStringValue:statusMessage];
    } else if ( [workflow isEqualTo:[_workflowItem workflowResources]] && ! _workflowNBIComplete ) {
        [self setWorkflowNBIResourcesLastStatus:statusMessage];
    } else if ( [workflow isEqualTo:[_workflowItem workflowModifyNBI]] ) {
        [_textFieldStatusInfo setStringValue:statusMessage];
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
        NSArray *fileURLs = @[ _nbiURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    }
}
- (IBAction)buttonOpenLog:(id)sender {
#pragma unused(sender)
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    if ( _nbiLogURL ) {
        NSArray *fileURLs = @[ _nbiLogURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    }
}

- (void)workflowStartedForItem:(NBCWorkflowItem *)workflowItem {
    
    [self setWorkflowItem:workflowItem];
    [self setNbiURL:[_workflowItem nbiURL]];
    [self setIsRunning:YES];
    [_layoutContraintStatusInfoLeading setConstant:24.0];
}

- (void)workflowFailedWithError:(NSString *)errorMessage {
    DDLogDebug(@"%@", NSStringFromSelector(_cmd));
    [_layoutContraintStatusInfoLeading setConstant:1.0];
    [_textFieldStatusInfo setStringValue:[NSString stringWithFormat:@"ERROR: %@", errorMessage]];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [self setIsRunning:NO];
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
    
    [_textFieldStatusInfo setStringValue:[NSString stringWithFormat:@"NBI created successfully in %@!", [dateComponentsFormatter stringFromTimeInterval:secondsBetween]]];
    [self setWorkflowComplete:YES];
    [_progressIndicator setHidden:YES];
    [_progressIndicator stopAnimation:self];
    [self setIsRunning:NO];
}

@end
