//
//  AVEncoder.h
//  Encoder Demo
//
//  Created by Geraint Davies on 14/01/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAssetWriter.h>
#import <AVFoundation/AVAssetWriterInput.h>
#import <AVFoundation/AVMediaFormat.h>
#import <AVFoundation/AVVideoSettings.h>
#import <sys/stat.h>

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFVideoEncoder.h>
#import <LFLiveKit/LFMP4Atom.h>
#else
#import "LFVideoEncoder.h"
#import "LFMP4Atom.h"
#endif



typedef int (^encoder_handler_t)(NSArray *data, CMTimeValue ptsValue);
typedef int (^param_handler_t)(NSData *params);

@interface LFAVEncoder : NSObject

@property (atomic) NSUInteger bitrate;

+ (LFAVEncoder *)encoderForHeight:(int)height andWidth:(int)width bitrate:(int)bitrate;

- (void)encodeWithBlock:(encoder_handler_t)block onParams:(param_handler_t)paramsHandler;
- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;
- (NSData *)getConfigData;
- (void)shutdown;


@property (readonly, atomic) int bitspersecond;

@end
