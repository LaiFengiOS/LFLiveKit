//
//  LFLiveDebug.h
//  LaiFeng
//
//  Created by admin on 16/5/19.
//  Copyright © 2016年 live Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface LFLiveDebug : NSObject

@property (nonatomic, copy) NSString *streamId;                         ///< 流id
@property (nonatomic, copy) NSString *uploadUrl;                        ///< 流地址
@property (nonatomic, assign) CGSize videoSize;                         ///< 上传的分辨率
@property (nonatomic, assign) BOOL isRtmp;                              ///< 上传方式（TCP or RTMP）

@property (nonatomic, assign) CGFloat elapsedMilli;                     ///< 距离上次统计的时间 单位ms
@property (nonatomic, assign) CGFloat timeStamp;                        ///< 当前的时间戳，从而计算1s内数据
@property (nonatomic, assign) CGFloat dataFlow;                         ///< 总流量
@property (nonatomic, assign) CGFloat bandwidth;                        ///< 1s内总带宽
@property (nonatomic, assign) CGFloat currentBandwidth;                 ///< 上次的带宽

@property (nonatomic, assign) NSInteger dropFrame;                      ///< 丢掉的帧数
@property (nonatomic, assign) NSInteger totalFrame;                     ///< 总帧数

@property (nonatomic, assign) NSInteger capturedAudioCount;             ///< 1s内音频捕获个数
@property (nonatomic, assign) NSInteger capturedVideoCount;             ///< 1s内视频捕获个数
@property (nonatomic, assign) NSInteger currentCapturedAudioCount;      ///< 上次的音频捕获个数
@property (nonatomic, assign) NSInteger currentCapturedVideoCount;      ///< 上次的视频捕获个数

@property (nonatomic, assign) NSInteger unSendCount;                    ///< 未发送个数（代表当前缓冲区等待发送的）

@end
