//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFLiveStreamInfo.h"
#import "LFStreamingBuffer.h"
#import "LFLiveDebug.h"



@protocol LFStreamSocket;
@protocol LFStreamSocketDelegate <NSObject>

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveBuffferState)status;
/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveState)status;
/** callback socket errorcode */
- (void)socketDidError:(nullable id <LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode;
- (void)socketDidPublishSucceed:(nullable id <LFStreamSocket>)socket;
@optional
/** callback debugInfo */
- (void)socketDebug:(nullable id <LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo;
- (void)socketRTMPError:(nullable id <LFStreamSocket>)socket errorCode:(NSInteger)errorCode message:(nullable NSString *)message;
- (void)socket:(nullable id <LFStreamSocket>)socket rtmpCommandLog:(nonnull NSString *)log;
- (void)socketCallbackIsSuccess:(BOOL)isSuccess videoSize:(NSInteger)videoSize;

@end

@protocol LFStreamSocket <NSObject>
- (void)start;
- (void)stop;
- (void)switched;
- (void)sendFrame:(nullable LFFrame *)frame;
- (void)sendSeiWithJson:(nullable NSData *)data;
- (void)setDelegate:(nullable id <LFStreamSocketDelegate>)delegate;
@optional
- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream;
- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount;
- (void)streamURLChanged:(nonnull NSString *)url tcurl:(nonnull NSString *)tcurl;
@end
