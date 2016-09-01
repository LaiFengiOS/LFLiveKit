//
//  LFStreamSocket.h
//  LFLiveKit
//
//  Created by admin on 16/5/3.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFLiveStreamInfo.h>
#import <LFLiveKit/LFStreamingBuffer.h>
#import <LFLiveKit/LFLiveDebug.h>
#else
#import "LFLiveStreamInfo.h"
#import "LFStreamingBuffer.h"
#import "LFLiveDebug.h"
#endif



@protocol LFStreamSocket;
@protocol LFStreamSocketDelegate <NSObject>

/** callback buffer current status (回调当前缓冲区情况，可实现相关切换帧率 码率等策略)*/
- (void)socketBufferStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveBuffferState)status;
/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable id <LFStreamSocket>)socket status:(LFLiveState)status;
/** callback socket errorcode */
- (void)socketDidError:(nullable id <LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode;
@optional
/** callback debugInfo */
- (void)socketDebug:(nullable id <LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo;
@end

@protocol LFStreamSocket <NSObject>
- (void)start;
- (void)stop;
- (void)sendFrame:(nullable LFFrame *)frame;
- (void)setDelegate:(nullable id <LFStreamSocketDelegate>)delegate;
@optional
- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream;
- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount;
@end
