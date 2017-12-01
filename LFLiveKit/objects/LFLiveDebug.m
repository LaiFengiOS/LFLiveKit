//
//  LFLiveDebug.m
//  LaiFeng
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFLiveDebug.h"

@implementation LFLiveDebug

- (id)copyWithZone:(NSZone *)zone {
    LFLiveDebug *debug = [[LFLiveDebug alloc] init];
    debug.streamId = self.streamId;
    debug.uploadUrl = self.uploadUrl;
    debug.videoSize = self.videoSize;
    debug.isRtmp = self.isRtmp;
    debug.elapsedMilli = self.elapsedMilli;
    debug.timeStamp = self.timeStamp;
    debug.elapsedMilliForSpeed = self.elapsedMilliForSpeed;
    debug.timeStampForSpeed = self.timeStampForSpeed;
    debug.bandwidthForSpeed = self.bandwidthForSpeed;
    debug.lastSpeed = self.lastSpeed;
    debug.dataFlow = self.dataFlow;
    debug.bandwidth = self.bandwidth;
    debug.currentBandwidth = self.currentBandwidth;
    debug.dropFrame = self.dropFrame;
    debug.totalFrame = self.totalFrame;
    debug.capturedAudioCount = self.capturedAudioCount;
    debug.capturedVideoCount = self.capturedVideoCount;
    debug.currentCapturedAudioCount = self.currentCapturedAudioCount;
    debug.currentCapturedVideoCount = self.currentCapturedVideoCount;
    debug.unSendCount = self.unSendCount;
    return debug;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DropFrame:%ld TotalFrame:%ld CurrentCaptureAuidoCount:%zd CurrentCaptureVideoCount:%zd unSendCount:%ld TotalTraffic:%0.f",
            _dropFrame,
            _totalFrame,
            (long)_currentCapturedAudioCount,
            _currentCapturedVideoCount,
            _unSendCount,
            _dataFlow];
}

@end
