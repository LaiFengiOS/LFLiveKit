//
//  LFHardwareVideoEncoder.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//
#import "LFHardwareVideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface LFHardwareVideoEncoder (){
    VTCompressionSessionRef compressionSession;
    NSInteger frameCount;
    NSData *sps;
    NSData *pps;
    FILE *fp;
    BOOL enabledWriteVideoFile;
}

@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;
@property (nonatomic, weak) id<LFVideoEncodingDelegate> h264Delegate;
@property (nonatomic) NSInteger currentVideoBitRate;
@property (nonatomic) BOOL isBackGround;

@end

@implementation LFHardwareVideoEncoder

#pragma mark -- LifeCycle
- (instancetype)initWithVideoStreamConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        NSLog(@"USE LFHardwareVideoEncoder");
        _configuration = configuration;
        [self resetCompressionSession];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
#ifdef DEBUG
        enabledWriteVideoFile = NO;
        [self initForFilePath];
#endif
        
    }
    return self;
}

- (void)resetCompressionSession {//重置VTCompressionSessionRef
    if (compressionSession) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);

        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }

    //创建VTCompressionSessionRef用于编码h.264  VideoCompressonOutputCallback为编码完成后回掉
    OSStatus status = VTCompressionSessionCreate(NULL, _configuration.videoSize.width, _configuration.videoSize.height, kCMVideoCodecType_H264, NULL, NULL, NULL, VideoCompressonOutputCallback, (__bridge void *)self, &compressionSession);
    if (status != noErr) {
        return;
    }

    //设置VTCompressionSessionRef参数
    _currentVideoBitRate = _configuration.videoBitRate;
    // 设置最大关键帧间隔，即gop size
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(_configuration.videoMaxKeyframeInterval));
    // 
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(_configuration.videoMaxKeyframeInterval/_configuration.videoFrameRate));
    // 设置帧率，只用于初始化session，不是实际FPS
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(_configuration.videoFrameRate));
    // 设置编码码率(比特率)，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(_configuration.videoBitRate));
    // 设置数据速率限制
    NSArray *limit = @[@(_configuration.videoBitRate * 1.5/8), @(1)];// CFArray[CFNumber], [bytes, seconds, bytes, seconds...]
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    // 设置实时编码输出，降低编码延迟
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    // 设置允许帧重新排序
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
    // 设置编码类型h.264
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    // 准备编码
    VTCompressionSessionPrepareToEncodeFrames(compressionSession);

}

- (void)setVideoBitRate:(NSInteger)videoBitRate {
    if(_isBackGround) return;
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(videoBitRate));
    NSArray *limit = @[@(videoBitRate * 1.5/8), @(1)];
    VTSessionSetProperty(compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    _currentVideoBitRate = videoBitRate;
}

- (NSInteger)videoBitRate {
    return _currentVideoBitRate;
}

- (void)dealloc {
    if (compressionSession != NULL) {
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid);

        VTCompressionSessionInvalidate(compressionSession);
        CFRelease(compressionSession);
        compressionSession = NULL;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -- LFVideoEncoder
- (void)encodeVideoData:(CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp {
    if(_isBackGround) return;
    frameCount++;
    // fps
    CMTime presentationTimeStamp = CMTimeMake(frameCount, (int32_t)_configuration.videoFrameRate);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)_configuration.videoFrameRate);

    NSDictionary *properties = nil;
    if (frameCount % (int32_t)_configuration.videoMaxKeyframeInterval == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);

    //开始编码
    OSStatus status = VTCompressionSessionEncodeFrame(compressionSession, pixelBuffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
    if(status != noErr){
        [self resetCompressionSession];
    }
}

- (void)stopEncoder {
    VTCompressionSessionCompleteFrames(compressionSession, kCMTimeIndefinite);
}

- (void)setDelegate:(id<LFVideoEncodingDelegate>)delegate {
    _h264Delegate = delegate;
}

#pragma mark -- Notification
- (void)willEnterBackground:(NSNotification*)notification{
    _isBackGround = YES;
}

- (void)willEnterForeground:(NSNotification*)notification{
    [self resetCompressionSession];
    _isBackGround = NO;
}

#pragma mark -- VideoCallBack
static void VideoCompressonOutputCallback(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    if (!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;

    // 判断当前帧是否为关键帧
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];

    LFHardwareVideoEncoder *videoEncoder = (__bridge LFHardwareVideoEncoder *)VTref;
    if (status != noErr) {
        return;
    }

    if (keyframe && !videoEncoder->sps) {//是关键帧，并且尚未设置sps（序列参数集）
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);

        size_t sparameterSetSize, sparameterSetCount;
        //获取sps
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            //获取pps
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                videoEncoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];//设置sps
                videoEncoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];//这只pps
                //数据处理时，sps pps 数据可以作为一个普通h264帧，放在h264视频流的最前面。
                //如果保存到文件中，需要将此数据前加上 [0 0 0 1] 4个字节，写入到h264文件的最前面。
                //如果推流，将此数据放入flv数据区即可。

                if (videoEncoder->enabledWriteVideoFile) {//debug
                    NSMutableData *data = [[NSMutableData alloc] init];
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder->sps];
                    [data appendBytes:header length:4];
                    [data appendData:videoEncoder->pps];
                    fwrite(data.bytes, 1, data.length, videoEncoder->fp);
                }

            }
        }
    }


    //获取视频数据
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    //获取视频数据指针  数据大小 总数据大小
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            

            //大小端转化，关于大端和小端模式，请参考此网址：http://blog.csdn.net/sunjie886/article/details/54944810
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);

            //封装视频数据LFVideoFrame,方便以后推流
            LFVideoFrame *videoFrame = [LFVideoFrame new];
            videoFrame.timestamp = timeStamp;
            videoFrame.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            videoFrame.isKeyFrame = keyframe;
            videoFrame.sps = videoEncoder->sps;
            videoFrame.pps = videoEncoder->pps;

            //调用视频编码完成后的代理
            if (videoEncoder.h264Delegate && [videoEncoder.h264Delegate respondsToSelector:@selector(videoEncoder:videoFrame:)]) {
                [videoEncoder.h264Delegate videoEncoder:videoEncoder videoFrame:videoFrame];
            }

            if (videoEncoder->enabledWriteVideoFile) {//debug
                NSMutableData *data = [[NSMutableData alloc] init];
                if (keyframe) {
                    uint8_t header[] = {0x00, 0x00, 0x00, 0x01};
                    [data appendBytes:header length:4];
                } else {
                    uint8_t header[] = {0x00, 0x00, 0x01};
                    [data appendBytes:header length:3];
                }
                [data appendData:videoFrame.data];

                fwrite(data.bytes, 1, data.length, videoEncoder->fp);
            }


            bufferOffset += AVCCHeaderLength + NALUnitLength;

        }

    }
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
