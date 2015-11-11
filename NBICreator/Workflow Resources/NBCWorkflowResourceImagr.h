//
//  NBCWorkflowResourceImagr.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-11-04.
//  Copyright © 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NBCWorkflowProgressDelegate.h"
#import "NBCWorkflowResourcesController.h"
#import "NBCDownloader.h"
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
