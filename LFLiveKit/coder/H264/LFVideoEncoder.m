//
//  LFVideoEncoder.m
//  Encoder Demo
//
//  Created by Geraint Davies on 14/01/2013.
//  Copyright (c) 2013 GDCL http://www.gdcl.co.uk/license.htm
//

#import "LFVideoEncoder.h"

@implementation LFVideoEncoder
{
    AVAssetWriter *_writer;
    AVAssetWriterInput *_writerInput;
    NSString *_path;
}

@synthesize path = _path;

+ (LFVideoEncoder *)encoderForPath:(NSString *)path Height:(int)height andWidth:(int)width bitrate:(int)bitrate {
    LFVideoEncoder *enc = [LFVideoEncoder alloc];
    [enc initPath:path Height:height andWidth:width bitrate:bitrate];
    return enc;
}

- (void)initPath:(NSString *)path Height:(int)height andWidth:(int)width bitrate:(int)bitrate {
    self.path = path;
    _bitrate = bitrate;

    [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
    NSURL *url = [NSURL fileURLWithPath:self.path];

    NSDictionary *settings = @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @(width),
        AVVideoHeightKey: @(height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(self.bitrate),
            AVVideoMaxKeyFrameIntervalKey: @(30 * 2),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline41,
            AVVideoAllowFrameReorderingKey: @NO,
        }
    };
    _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    _writerInput.expectsMediaDataInRealTime = YES;

    _writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:nil];
    [_writer addInput:_writerInput];
}

- (void)finishWithCompletionHandler:(void (^)(void))handler {
    if (_writer.status == AVAssetWriterStatusWriting) {
        [_writer finishWritingWithCompletionHandler:handler];
    }
}

- (BOOL)encodeFrame:(CMSampleBufferRef)sampleBuffer {
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        if (_writer.status == AVAssetWriterStatusUnknown) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [_writer startWriting];
            [_writer startSessionAtSourceTime:startTime];
        }
        if (_writer.status == AVAssetWriterStatusFailed) {
            //NSLog(@"AVAssetWriterStatusFailed");
            return NO;
        }
        if (_writerInput.readyForMoreMediaData == YES) {
            [_writerInput appendSampleBuffer:sampleBuffer];
            return YES;
        }
    }
    return NO;
}

@end
