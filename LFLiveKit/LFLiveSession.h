//
//  LFLiveSession.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFLiveStreamInfo.h"
#import "LFAudioFrame.h"
#import "LFVideoFrame.h"
#import "LFLiveAudioConfiguration.h"
#import "LFLiveVideoConfiguration.h"
#import "LFLiveDebug.h"

typedef void (^ LFRequestComplete)(_Nullable id info,NSError *_Nullable errorMsg);

/// 流类型
typedef NS_ENUM(NSUInteger, LFLiveType){
    /// rtmp格式
    LFLiveRTMP = 0,
    /// tcp 传输flv格式
    LFLiveFLV = 1,
};

@class LFLiveSession;
@protocol LFLiveSessionDelegate <NSObject>

@optional
/** live status changed will callback */
- (void)liveSession:(nullable LFLiveSession *)session liveStateDidChange:(LFLiveState)state;
/** live debug info callback */
- (void)liveSession:(nullable LFLiveSession *)session debugInfo:(nullable LFLiveDebug*)debugInfo;
/** callback socket errorcode */
- (void)liveSession:(nullable LFLiveSession*)session errorCode:(LFLiveSocketErrorCode)errorCode;
@end

@class LFLiveStreamInfo;

@interface LFLiveSession : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/** The delegate of the capture. captureData callback */
@property (nullable,nonatomic, weak) id<LFLiveSessionDelegate> delegate;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The preView will show OpenGL ES view*/
@property (nonatomic, strong,null_resettable) UIView *preView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/** The beautyFace control capture shader filter empty or beautiy */
@property (nonatomic, assign) BOOL beautyFace;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic,assign) BOOL muted;

/** The stream control upload and package*/
@property (nullable,nonatomic, strong,readonly) LFLiveStreamInfo * streamInfo;

/** The status of the stream .*/
@property (nonatomic,assign,readonly) LFLiveState state;

/** The showDebugInfo control streamInfo and uploadInfo(1s) *.*/
@property (nonatomic,assign) BOOL showDebugInfo;

/** The reconnectInterval control reconnect timeInterval(重连间隔) *.*/
@property (nonatomic,assign) NSUInteger reconnectInterval;

/** The reconnectCount control reconnect count (重连次数) *.*/
@property (nonatomic,assign) NSUInteger reconnectCount;

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
- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration*)audioConfiguration videoConfiguration:(nullable LFLiveVideoConfiguration*)videoConfiguration liveType:(LFLiveType)liveType NS_DESIGNATED_INITIALIZER;

/** The start stream .*/
- (void)startLive:(nonnull LFLiveStreamInfo*)streamInfo;

/** The stop stream .*/
- (void)stopLive;


@end

