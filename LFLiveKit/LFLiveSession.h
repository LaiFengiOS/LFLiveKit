//
//  LFLiveSession.h
//  LFLiveKit
//
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenGLES/EAGL.h>
#import "LFLiveStreamInfo.h"
#import "LFAudioFrame.h"
#import "LFVideoFrame.h"
#import "LFLiveAudioConfiguration.h"
#import "LFLiveVideoConfiguration.h"
#import "LFLiveDebug.h"



typedef NS_ENUM(NSInteger,LFLiveCaptureType) {
    LFLiveCaptureAudio,         //< capture only audio
    LFLiveCaptureVideo,         //< capture onlt video
    LFLiveInputAudio,           //< only audio (External input audio)
    LFLiveInputVideo,           //< only video (External input video)
    LFLiveMixAudio,             //< mix input audio
};


///< 用来控制采集类型（可以内部采集也可以外部传入等各种组合，支持单音频与单视频,外部输入适用于录屏，无人机等外设介入）
typedef NS_ENUM(NSInteger,LFLiveCaptureTypeMask) {
    LFLiveCaptureMaskAudio = (1 << LFLiveCaptureAudio),                                 ///< only inner capture audio (no video)
    LFLiveCaptureMaskVideo = (1 << LFLiveCaptureVideo),                                 ///< only inner capture video (no audio)
    LFLiveInputMaskAudio = (1 << LFLiveInputAudio),                                     ///< only outer input audio (no video)
    LFLiveInputMaskVideo = (1 << LFLiveInputVideo),                                     ///< only outer input video (no audio)
    LFLiveMixMaskAudio = (1 << LFLiveMixAudio | LFLiveCaptureMaskAudio),                ///< mix inner capture audio
    LFLiveCaptureMaskAll = (LFLiveCaptureMaskAudio | LFLiveCaptureMaskVideo),           ///< inner capture audio and video
    LFLiveInputMaskAll = (LFLiveInputMaskAudio | LFLiveInputMaskVideo),                 ///< outer input audio and video(method see pushVideo and pushAudio)
    LFLiveCaptureMaskAudioInputVideo = (LFLiveCaptureMaskAudio | LFLiveInputMaskVideo), ///< inner capture audio and outer input video(method pushVideo and setRunning)
    LFLiveCaptureMaskVideoInputAudio = (LFLiveCaptureMaskVideo | LFLiveInputMaskAudio), ///< inner capture video and outer input audio(method pushAudio and setRunning)
    LFLiveMixMaskAudioInputVideo = (LFLiveMixMaskAudio | LFLiveInputMaskVideo),         ///< mix inner capture audio and outer input video(method pushVideo and setRunning)
    LFLiveCaptureDefaultMask = LFLiveCaptureMaskAll                                     ///< default is inner capture audio and video
};

typedef NS_ENUM(NSUInteger, LFAudioMixVolume) {
    LFAudioMixVolumeVeryLow = 1,
    LFAudioMixVolumeLow = 3,
    LFAudioMixVolumeNormal = 5,
    LFAudioMixVolumeHigh = 7,
    LFAudioMixVolumeVeryHigh = 10
};

@class LFLiveSession;
@protocol LFLiveSessionDelegate <NSObject>

@optional
/** live status changed will callback */
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state;
/** live debug info callback */
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug *)debugInfo;
/** live stream log callback */
- (void)liveSession:(nullable LFLiveSession *)session log:(nullable NSDictionary *)dict;
/** callback socket errorcode */
- (void)liveSession:(nullable LFLiveSession *)session errorCode:(LFLiveSocketErrorCode)errorCode;
/** callback inner audio data */
- (void)liveSession:(nullable LFLiveSession *)session audioDataBeforeMixing:(nullable NSData *)audioData;

- (nullable CVPixelBufferRef)liveSession:(nullable LFLiveSession *)session willOutputVideoFrame:(nonnull CVPixelBufferRef)pixelBuffer atTime:(CMTime)time;

@end

@class LFLiveStreamInfo;

@interface LFLiveSession : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<LFLiveSessionDelegate> delegate;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The preView will show OpenGL ES view*/
@property (nonatomic, strong, null_resettable) UIView *preView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/** The beautyFace control capture shader filter empty or beautiy */
@property (nonatomic, assign) BOOL beautyFace;

/** The zoomScale control camera zoom scale, default 1.0 */
@property (nonatomic, assign) CGFloat zoomScale;

/** The torch control capture flash is on or off */
@property (nonatomic, assign) BOOL torch;

/** The mirror control mirror of front camera is on or off */
@property (nonatomic, assign) BOOL mirror;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic, assign) BOOL muted;

/*  The adaptiveBitrate control auto adjust bitrate. Default is NO */
@property (nonatomic, assign) BOOL adaptiveBitrate;

/** The stream control upload and package*/
@property (nullable, nonatomic, strong, readonly) LFLiveStreamInfo *streamInfo;

/** The status of the stream .*/
@property (nonatomic, assign, readonly) LFLiveState state;

/** The captureType control inner or outer audio and video .*/
@property (nonatomic, assign, readonly) LFLiveCaptureTypeMask captureType;

/** The showDebugInfo control streamInfo and uploadInfo(1s) *.*/
@property (nonatomic, assign) BOOL showDebugInfo;

/** The reconnectInterval control reconnect timeInterval(重连间隔) *.*/
@property (nonatomic, assign) NSUInteger reconnectInterval;

/** The reconnectCount control reconnect count (重连次数) *.*/
@property (nonatomic, assign) NSUInteger reconnectCount;

/*** The warterMarkView control whether the watermark is displayed or not ,if set ni,will remove watermark,otherwise add. 
 set alpha represent mix.Position relative to outVideoSize.
 *.*/
@property (nonatomic, strong, nullable) UIView *warterMarkView;

/* The currentImage is videoCapture shot */
@property (nonatomic, strong, readonly, nullable) UIImage *currentImage;

/* The saveLocalVideo is save the local video */
@property (nonatomic, assign) BOOL saveLocalVideo;

/* The saveLocalVideoPath is save the local video  path */
@property (nonatomic, strong, nullable) NSURL *saveLocalVideoPath;

/* The currentColorFilterName is localized name of current color filter */
@property (nonatomic, copy, readonly, nullable) NSString *currentColorFilterName;

/** The mirrorOuput control mirror of output is on or off */
@property (nonatomic, assign) BOOL mirrorOutput;

@property (nonatomic, assign) BOOL gpuimageOn;

@property (nonatomic, assign) BOOL gpuimageAdvanceBeautyEnabled;

// 17 log
@property (nonatomic, nullable) NSString *liveId;
@property (nonatomic, nullable) NSString *provider;
@property (nonatomic, nullable) NSString *userId;
@property (nonatomic, nullable) NSString *region;
@property (nonatomic, nullable) NSString *appVersion;
@property (nonatomic) double longitude;
@property (nonatomic) double latitude;
@property (nonatomic, readonly, nonnull) NSDictionary *logInfo;

@property (strong, nonatomic, readonly) EAGLContext *glContext;

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                                 videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration;

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                                 videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration
                                        captureType:(LFLiveCaptureTypeMask)captureType;
/**
 The designated initializer. Multiple instances with the same configuration will make the
 capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                                 videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration
                                        captureType:(LFLiveCaptureTypeMask)captureType
                                        eaglContext:(EAGLContext *)glContext NS_DESIGNATED_INITIALIZER;

/** The start stream .*/
- (void)startLive:(nonnull LFLiveStreamInfo *)streamInfo;

/** The stop stream .*/
- (void)stopLive;

/** support outer input yuv or rgb video(set LFLiveCaptureTypeMask) .*/
- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer;

/** support outer input pcm audio(set LFLiveCaptureTypeMask) .*/
- (void)pushAudio:(nullable NSData*)audioData;

- (BOOL)sendSeiJson:(nonnull id)jsonObj;

/** Switch to previous color filter. */
- (void)previousColorFilter;

/** Switch to next color filter. */
- (void)nextColorFilter;

// volume is LFAudioMixVolumeNormal
- (void)playSound:(nonnull NSURL *)soundUrl;

- (void)playSound:(nonnull NSURL *)soundUrl volume:(LFAudioMixVolume)volume;

- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls;

- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls volume:(LFAudioMixVolume)volume;

/** Not supported yet. Behavior will be the same as [playSoundSequences:] for now. */
- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls interval:(NSTimeInterval)interval;

- (void)playParallelSounds:(nonnull NSSet<NSURL *> *)urls;

- (void)playParallelSounds:(nonnull NSArray<NSURL *> *)urls volumes:(NSArray<NSNumber *> *)volumes;

- (void)startBackgroundSound:(nonnull NSURL *)soundUrl;

- (void)startBackgroundSound:(nonnull NSURL *)soundUrl volume:(LFAudioMixVolume)volume;

- (void)stopBackgroundSound;

- (void)restartBackgroundSound;

- (void)stopAllSounds;

@end

