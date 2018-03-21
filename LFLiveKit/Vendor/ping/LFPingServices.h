//
//  LFPingServices.h
//  STKitDemo
//
//  Created by SunJiangting on 15-3-9.
//  Copyright (c) 2015年 SunJiangting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFSimplePing.h"

typedef NS_ENUM(NSInteger, STDPingStatus) {
    STDPingStatusDidStart,
    STDPingStatusDidFailToSendPacket,
    STDPingStatusDidReceivePacket,
    STDPingStatusDidReceiveUnexpectedPacket,
    STDPingStatusDidTimeout,
    STDPingStatusError,
    STDPingStatusFinished,
};


@interface LFPingItem : NSObject

@property (copy, nonatomic) NSString *originalAddress;
@property (copy, nonatomic) NSString *IPAddress;
@property (nonatomic) NSUInteger dateBytesLength;
@property (nonatomic) NSInteger  timeToLive;
@property (nonatomic) NSInteger  ICMPSequence;
@property (nonatomic) double     timeMilliseconds;
@property (nonatomic) STDPingStatus status;

@end


@interface LFPingServices : NSObject

// default 500ms
@property (nonatomic) double timeoutMilliseconds;

@property (nonatomic, readonly) NSInteger maximumPingTimes;

+ (instancetype)startPingAddress:(NSString *)address
                           times:(NSInteger)times
                         handler:(void(^)(LFPingItem *pingItem, NSArray<LFPingItem *> *history))handler;

- (void)cancel;

- (long)averageRetryTime;

- (float)lossPercentage;

- (NSString *)statistics;

@end
