//
//  NBCMessageDelegate.h
//  NBICreator
//
//  Created by Erik Berglund on 2015-05-25.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol NBCMessageDelegate <NSObject>
@optional
- (void)updateProgress:(NSString *)message;
@end



