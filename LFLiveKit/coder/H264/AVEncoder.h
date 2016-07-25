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
#import "sys/stat.h"
#import "VideoEncoder.h"
#import "MP4Atom.h"

typedef int (^encoder_handler_t)(NSArray *data, CMTimeValue ptsValue);
typedef int (^param_handler_t)(NSData *params);

@interface AVEncoder : NSObject

@property (atomic) NSUInteger bitrate;

+ (AVEncoder *)encoderForHeight:(int)height andWidth:(int)width bitrate:(int)bitrate;

- (void)encodeWithBlock:(encoder_handler_t)block onParams:(param_handler_t)paramsHandler;
- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer;
- (void)encodePixelBuffer:(CVPixelBufferRef)pixelBuffer pts:(CMTime)pts;
- (NSData *)getConfigData;
- (void)shutdown;


@property (readonly, atomic) int bitspersecond;

@end
