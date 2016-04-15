//
//  NBCDDReader.h
//  NBICreator
//
//  Taken from here: http://stackoverflow.com/a/3711079
//

#import <Foundation/Foundation.h>

@interface NBCDDReader : NSObject {
    NSString *filePath;

    NSFileHandle *fileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;

    NSString *lineDelimiter;
    NSUInteger chunkSize;
}

@property (nonatomic, copy) NSString *lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id)initWithFilePath:(NSString *)aPath;

- (NSString *)readLine;
- (NSString *)readTrimmedLine;

#if NS_BLOCKS_AVAILABLE
- (void)enumerateLinesUsingBlock:(void (^)(NSString *, BOOL *))block;
#endif

@end
