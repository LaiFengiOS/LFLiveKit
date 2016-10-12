//
//  LFH264VideoEncoder
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <mach/mach_time.h>
#import "LFNALUnit.h"
#import "LFAVEncoder.h"
#import "LFH264VideoEncoder.h"
#import "LFVideoFrame.h"

@interface LFH264VideoEncoder() {
    FILE *fp;
    NSInteger frameCount;
    BOOL enabledWriteVideoFile;
}
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;
@property (nonatomic, weak) id<LFVideoEncodingDelegate> h264Delegate;
@property (nonatomic) BOOL isBackGround;
@property (nonatomic) NSInteger currentVideoBitRate;
@property (nonatomic, strong) dispatch_queue_t sendQueue;

@property (nonatomic, strong) LFAVEncoder *encoder;

@property (nonatomic, strong) NSData *naluStartCode;
@property (nonatomic, strong) NSMutableData *videoSPSandPPS;
@property (nonatomic, strong) NSMutableData *spsData;
@property (nonatomic, strong) NSMutableData *ppsData;
@property (nonatomic, strong) NSMutableData *sei;
@property (nonatomic) CMTimeScale timescale;
@property (nonatomic, strong) NSMutableArray *orphanedFrames;
@property (nonatomic, strong) NSMutableArray *orphanedSEIFrames;
@property (nonatomic) CMTime lastPTS;
@end

@implementation LFH264VideoEncoder

#pragma mark -- LifeCycle
- (instancetype)initWithVideoStreamConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        NSLog(@"USE LF264VideoEncoder");
        _configuration = configuration;
        [self initCompressionSession];
    }
    return self;
}

- (void)initCompressionSession{
    _sendQueue = dispatch_queue_create("com.youku.laifeng.h264.sendframe", DISPATCH_QUEUE_SERIAL);
    [self initializeNALUnitStartCode];
    _lastPTS = kCMTimeInvalid;
    _timescale = 1000;
    frameCount = 0;
#ifdef DEBUG
    enabledWriteVideoFile = NO;
    [self initForFilePath];
#endif
    
    _encoder = [LFAVEncoder encoderForHeight:(int)_configuration.videoSize.height andWidth:(int)_configuration.videoSize.width bitrate:(int)_configuration.videoBitRate];
    [_encoder encodeWithBlock:^int(NSArray* dataArray, CMTimeValue ptsValue) {
        [self incomingVideoFrames:dataArray ptsValue:ptsValue];
        return 0;
    } onParams:^int(NSData *data) {
        [self generateSPSandPPS];
        return 0;
    }];
}

- (void) initializeNALUnitStartCode {
    NSUInteger naluLength = 4;
    uint8_t *nalu = (uint8_t*)malloc(naluLength * sizeof(uint8_t));
    nalu[0] = 0x00;
    nalu[1] = 0x00;
    nalu[2] = 0x00;
    nalu[3] = 0x01;
    _naluStartCode = [NSData dataWithBytesNoCopy:nalu length:naluLength freeWhenDone:YES];
}

- (void) generateSPSandPPS {
    NSData* config = _encoder.getConfigData;
    if (!config) {
        return;
    }
    LFavcCHeader avcC((const BYTE*)[config bytes], (int)[config length]);
    LFSeqParamSet seqParams;
    seqParams.Parse(avcC.sps());
    
    NSData* spsData = [NSData dataWithBytes:avcC.sps()->Start() length:avcC.sps()->Length()];
    NSData *ppsData = [NSData dataWithBytes:avcC.pps()->Start() length:avcC.pps()->Length()];
    
    _spsData = [NSMutableData dataWithCapacity:avcC.sps()->Length()+_naluStartCode.length];
    _ppsData = [NSMutableData dataWithCapacity:avcC.pps()->Length()+_naluStartCode.length];
    
    [_spsData appendData:_naluStartCode];
    [_spsData appendData:spsData];
    [_ppsData appendData:_naluStartCode];
    [_ppsData appendData:ppsData];
    
    _videoSPSandPPS = [NSMutableData dataWithCapacity:avcC.sps()->Length() + avcC.pps()->Length() + _naluStartCode.length * 2];
    [_videoSPSandPPS appendData:_naluStartCode];
    [_videoSPSandPPS appendData:spsData];
    [_videoSPSandPPS appendData:_naluStartCode];
    [_videoSPSandPPS appendData:ppsData];
}



- (void)setVideoBitRate:(NSInteger)videoBitRate{
    _currentVideoBitRate = videoBitRate;
    _encoder.bitrate = _currentVideoBitRate;
}

- (NSInteger)videoBitRate{
    return _currentVideoBitRate;
}

- (void)setDelegate:(id<LFVideoEncodingDelegate>)delegate{
    _h264Delegate = delegate;
}

- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
  
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    
    CMTime frameTime = CMTimeMake(timeStamp, 1000);
    CMTime duration = CMTimeMake(1, (int32_t)_configuration.videoFrameRate);
    CMSampleTimingInfo timing = {duration, frameTime, kCMTimeInvalid};
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, YES, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    [_encoder encodeFrame:sampleBuffer];
    CFRelease(videoInfo);
    CFRelease(sampleBuffer);

    frameCount++;
}

- (void)addOrphanedFramesFromArray:(NSArray*)frames {
    for (NSData *data in frames) {
        unsigned char* pNal = (unsigned char*)[data bytes];
        int idc = pNal[0] & 0x60;
        int naltype = pNal[0] & 0x1f;
        if (idc == 0 && naltype == 6) { // SEI
            [self.orphanedSEIFrames addObject:data];
        } else {
            [self.orphanedFrames addObject:data];
        }
    }
}

- (void)writeVideoFrames:(NSArray*)frames pts:(CMTime)pts {
    NSMutableArray *totalFrames = [NSMutableArray array];
    if (self.orphanedSEIFrames.count > 0) {
        [totalFrames addObjectsFromArray:self.orphanedSEIFrames];
        [self.orphanedSEIFrames removeAllObjects];
    }
    [totalFrames addObjectsFromArray:frames];
    
    NSMutableData *aggregateFrameData = [NSMutableData data];
    //BOOL hasKeyframe = NO;
    
    for (NSData *data in totalFrames) {
        unsigned char* pNal = (unsigned char*)[data bytes];
        int idc = pNal[0] & 0x60;
        int naltype = pNal[0] & 0x1f;
        NSData *videoData = nil;
    
        if (idc == 0 && naltype == 6) { // SEI
            _sei = [NSMutableData dataWithData:data];
            continue;
        } else if (naltype == 5) { // IDR
            //hasKeyframe = YES;
            NSMutableData *IDRData = [NSMutableData dataWithData:_videoSPSandPPS];
            if (_sei) {
                [IDRData appendData:_naluStartCode];
                [IDRData appendData:_sei];
                _sei = nil;
            }
            [IDRData appendData:_naluStartCode];
            [IDRData appendData:data];
            videoData = IDRData;
        } else {
            NSMutableData *regularData = [NSMutableData dataWithData:_naluStartCode];
            [regularData appendData:data];
            videoData = regularData;
        }
        [aggregateFrameData appendData:videoData];
        
        LFVideoFrame *videoFrame = [LFVideoFrame new];
        const char *dataBuffer = (const char *)aggregateFrameData.bytes;
        videoFrame.data = [NSMutableData dataWithBytes:dataBuffer + _naluStartCode.length length:aggregateFrameData.length - _naluStartCode.length];
        videoFrame.timestamp = pts.value;
        videoFrame.isKeyFrame = (naltype == 5);
        videoFrame.sps = _spsData;
        videoFrame.pps = _ppsData;

        if(self.h264Delegate && [self.h264Delegate respondsToSelector:@selector(videoEncoder:videoFrame:)]){
            [self.h264Delegate videoEncoder:self videoFrame:videoFrame];
        }
    }
    
    if (self->enabledWriteVideoFile) {
        fwrite(aggregateFrameData.bytes, 1, aggregateFrameData.length, self->fp);
    }
}

- (void) incomingVideoFrames:(NSArray*)frames ptsValue:(CMTimeValue)ptsValue {
    if (ptsValue == 0) {
        [self addOrphanedFramesFromArray:frames];
        return;
    }
    if (!_videoSPSandPPS) {
        [self generateSPSandPPS];
    }
    CMTime pts = CMTimeMake(ptsValue, _timescale);
    if (self.orphanedFrames.count > 0) {
        CMTime ptsDiff = CMTimeSubtract(pts, _lastPTS);
        NSUInteger orphanedFramesCount = self.orphanedFrames.count;
//        NSLog(@"lastPTS before first orphaned frame: %lld", _lastPTS.value);
        for (NSData *frame in self.orphanedFrames) {
            CMTime fakePTSDiff = CMTimeMultiplyByFloat64(ptsDiff, 1.0/(orphanedFramesCount + 1));
            CMTime fakePTS = CMTimeAdd(_lastPTS, fakePTSDiff);
//            NSLog(@"orphan frame fakePTS: %lld", fakePTS.value);
            [self writeVideoFrames:@[frame] pts:fakePTS];
        }
//        NSLog(@"pts after orphaned frame: %lld", pts.value);
        [self.orphanedFrames removeAllObjects];
    }
    
    [self writeVideoFrames:frames pts:pts];
    _lastPTS = pts;
}


- (void) dealloc {
    [_encoder shutdown];
}

- (void)shutdown {
    [_encoder encodeWithBlock:nil onParams:nil];
}

- (void)initForFilePath {
    NSString *path = [self GetFilePathByfileName:@"IOSCamDemo.h264"];
    NSLog(@"%@", path);
    self->fp = fopen([path cStringUsingEncoding:NSUTF8StringEncoding], "wb");
}

- (NSString *)GetFilePathByfileName:(NSString*)filename {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writablePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return writablePath;
}

@end
