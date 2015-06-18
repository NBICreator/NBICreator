//
//  NBCWorkflowProgressViewController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowProgressViewController.h"
#import "NBCConstants.h"
#import "NBCWorkflowItem.h"

@interface NBCWorkflowProgressViewController ()

@end

@implementation NBCWorkflowProgressViewController

- (id)init {
    self = [super initWithNibName:@"NBCWorkflowProgressViewController" bundle:nil];
    if (self != nil) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)buttonStatusInfo:(id)sender {
#pragma unused(sender)
    if (_nbiURL) {
        NSArray *fileURLs = @[ _nbiURL ];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    }
}

- (IBAction)buttonCancel:(id)sender {
    #pragma unused(sender)
    NSDictionary * userInfo = @{ NBCNotificationAddWorkflowItemToQueueUserInfoWorkflowItem : _workflowItem };
    [[NSNotificationCenter defaultCenter] postNotificationName:@"removeWorkflowItem"
                                                        object:self
                                                      userInfo:userInfo];
}

@end
