//
//  NSMutableString+hyperlinkFromString.m
//  NBICreator
//
//  Created by Erik Berglund on 2015-09-07.
//  Copyright (c) 2015 NBICreator. All rights reserved.
//

#import "NSMutableString+hyperlinkFromString.h"
#import <Cocoa/Cocoa.h>

@implementation NSAttributedString (NBCHyperlink)

+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSUnderlineStyleSingle] range:range];
    [attrString addAttribute:NSFontAttributeName value:[NSFont fontWithName:@"Lucida Grande" size:9] range:range];
    [attrString endEditing];
    
    return attrString;
}
@end
