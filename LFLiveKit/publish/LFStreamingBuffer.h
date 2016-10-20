//
//  LFStreamingBuffer.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFAudioFrame.h"
#import "LFVideoFrame.h"


/** current buffer status */
typedef NS_ENUM (NSUInteger, LFLiveBuffferState) {
    LFLiveBuffferUnknown = 0,      //< 未知
    LFLiveBuffferIncrease = 1,    //< 缓冲区状态差应该降低码率
    LFLiveBuffferDecline = 2      //< 缓冲区状态好应该提升码率
};

@class LFStreamingBuffer;
/** this two method will control videoBitRate */
@protocol LFStreamingBufferDelegate <NSObject>
@optional
/** 当前buffer变动（增加or减少） 根据buffer中的updateInterval时间回调*/
- (void)streamingBuffer:(nullable LFStreamingBuffer *)buffer bufferState:(LFLiveBuffferState)state;
@end

@interface LFStreamingBuffer : NSObject


/** The delegate of the buffer. buffer callback */
@property (nullable, nonatomic, weak) id <LFStreamingBufferDelegate> delegate;

/** current frame buffer */
@property (nonatomic, strong, readonly) NSMutableArray <LFFrame *> *_Nonnull list;

/** buffer count max size default 1000 */
@property (nonatomic, assign) NSUInteger maxCount;

/** count of drop frames in last time */
@property (nonatomic, assign) NSInteger lastDropFrames;

/** add frame to buffer */
- (void)appendObject:(nullable LFFrame *)frame;

/** pop the first frome buffer */
- (nullable LFFrame *)popFirstObject;

/** remove all objects from Buffer */
- (void)removeAllObject;

@end
