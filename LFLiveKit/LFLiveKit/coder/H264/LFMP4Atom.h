//
//  LFMP4Atom.h
//  Encoder Demo
//
//  Created by Geraint Davies on 15/01/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import <Foundation/Foundation.h>

@interface LFMP4Atom : NSObject

{
    NSFileHandle *_file;
    int64_t _offset;
    int64_t _length;
    OSType _type;
    int64_t _nextChild;
}
@property OSType type;
@property int64_t length;

+ (LFMP4Atom *)atomAt:(int64_t)offset size:(int)length type:(OSType)fourcc inFile:(NSFileHandle *)handle;
- (BOOL)init:(int64_t)offset size:(int)length type:(OSType)fourcc inFile:(NSFileHandle *)handle;
- (NSData *)readAt:(int64_t)offset size:(int)length;
- (BOOL)setChildOffset:(int64_t)offset;
- (LFMP4Atom *)nextChild;
- (LFMP4Atom *)childOfType:(OSType)fourcc startAt:(int64_t)offset;

@end
