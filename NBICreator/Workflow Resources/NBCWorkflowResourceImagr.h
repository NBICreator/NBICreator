//
//  NBCWorkflowResourceImagr.h
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

#import "NBCDownloader.h"
#import "NBCWorkflowProgressDelegate.h"
#import "NBCWorkflowResourcesController.h"
#import <Foundation/Foundation.h>
@class NBCWorkflowItem;

@protocol NBCWorkflowResourceImagrDelegate
- (void)imagrCopyDict:(NSDictionary *)copyDict;
- (void)imagrCopyError:(NSError *)error;
@end

@interface NBCWorkflowResourceImagr : NSObject <NBCDownloaderDelegate, NBCResourcesControllerDelegate>

@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) id progressDelegate;
@property NSString *creationTool;
@property NSString *imagrTargetPathComponent;

- (id)initWithDelegate:(id<NBCWorkflowResourceImagrDelegate>)delegate;
- (void)addCopyImagr:(NBCWorkflowItem *)workflowItem;

@end
