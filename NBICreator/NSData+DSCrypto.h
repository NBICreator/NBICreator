//
//  NSData+DSCrypto.h
//  DSEnc
//
//  Created by Erik Berglund on 2016-05-18.
//  Copyright © 2016 Erik Berglund. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (NBCDSCrypto)

- (NSData *)nbc_encryptDSPassword;
- (NSData *)nbc_encryptLegacyDSPassword;

@end
