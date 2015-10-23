//
//  NBCWorkflowPanelController.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-04-03.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NBCWorkflowPanelController.h"

@interface NBCWorkflowPanelController ()

@end

@implementation NBCWorkflowPanelController

- (void)awakeFromNib {
    [_stackView setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_stackView setAlignment:NSLayoutAttributeCenterX];
    [_stackView setSpacing:0];
    [_stackView setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];
    [_stackView setHuggingPriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationVertical];
} // awakeFromNib

- (void)windowDidLoad {
    [super windowDidLoad];
} // windowDidLoad

@end
