//
//  LFPingServices.m
//  STKitDemo
//
//  Created by SunJiangting on 15-3-9.
//  Copyright (c) 2015年 SunJiangting. All rights reserved.
//

#import "LFPingServices.h"

@implementation LFPingItem

- (NSString *)description {
    switch (self.status) {
        case STDPingStatusDidStart:
            return [NSString stringWithFormat:@"PING %@ (%@): %ld data bytes",self.originalAddress, self.IPAddress, (long)self.dateBytesLength];
        case STDPingStatusDidReceivePacket:
            return [NSString stringWithFormat:@"%ld bytes from %@: icmp_seq=%ld ttl=%ld time=%.3f ms", (long)self.dateBytesLength, self.IPAddress, (long)self.ICMPSequence, (long)self.timeToLive, self.timeMilliseconds];
        case STDPingStatusDidTimeout:
            return [NSString stringWithFormat:@"Request timeout for icmp_seq %ld", (long)self.ICMPSequence];
        case STDPingStatusDidFailToSendPacket:
            return [NSString stringWithFormat:@"Fail to send packet to %@: icmp_seq=%ld", self.IPAddress, (long)self.ICMPSequence];
        case STDPingStatusDidReceiveUnexpectedPacket:
            return [NSString stringWithFormat:@"Receive unexpected packet from %@: icmp_seq=%ld", self.IPAddress, (long)self.ICMPSequence];
        case STDPingStatusError:
            return [NSString stringWithFormat:@"Can not ping to %@", self.originalAddress];
        default:
            break;
    }
    return super.description;
}

@end


#pragma mark - LFPingServices Class

@interface LFPingServices () <LFSimplePingDelegate> {
    BOOL _hasStarted;
    BOOL _isTimeout;
    NSInteger   _repingTimes;
    NSInteger   _sequenceNumber;
    NSMutableArray<LFPingItem *> *_pingItems;
}

@property(nonatomic, copy)   NSString   *address;
@property(nonatomic, strong) LFSimplePing *simplePing;

@property (copy, nonatomic) void(^callbackHandler)(LFPingItem *item, NSArray<LFPingItem *> *pingItems);

@end

@implementation LFPingServices

+ (instancetype)startPingAddress:(NSString *)address
                           times:(NSInteger)times
                         handler:(void(^)(LFPingItem *pingItem, NSArray<LFPingItem *> *history))handler {
    LFPingServices *services = [[LFPingServices alloc] initWithAddress:address sendnum:times];
    services.callbackHandler = handler;
    [services startPing];
    return services;
}

- (instancetype)initWithAddress:(NSString *)address sendnum:(NSInteger)snum {
    if (self = [super init]) {
        _timeoutMilliseconds = 500;
        _maximumPingTimes = snum;
        _address = address;
        _pingItems = [NSMutableArray arrayWithCapacity:10];
    
        _simplePing = [[LFSimplePing alloc] initWithHostName:address];
        _simplePing.addressStyle = LFSimplePingAddressStyleAny;
        _simplePing.delegate = self;
    }
    return self;
}

- (void)startPing {
    _repingTimes = 0;
    _hasStarted = NO;
    [_pingItems removeAllObjects];
    [self.simplePing start];
}

- (void)reping {
    [self.simplePing stop];
    [self.simplePing start];
}

- (void)timeoutActionFired {
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.ICMPSequence = _sequenceNumber;
    pingItem.originalAddress = self.address;
    pingItem.status = STDPingStatusDidTimeout;
    [self.simplePing stop];
    [self handlePingItem:pingItem];
}

- (void)handlePingItem:(LFPingItem *)pingItem {
    if (pingItem.status == STDPingStatusDidReceivePacket || pingItem.status == STDPingStatusDidTimeout) {
        [_pingItems addObject:pingItem];
    }
    if (_repingTimes < self.maximumPingTimes - 1) {
        if (self.callbackHandler) {
            self.callbackHandler(pingItem, [_pingItems copy]);
        }
        _repingTimes++;
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(reping) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    } else {
        if (self.callbackHandler) {
            self.callbackHandler(pingItem, [_pingItems copy]);
        }
        [self cancel];
    }
}

- (void)cancel {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutActionFired) object:nil];
    [self.simplePing stop];
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.status = STDPingStatusFinished;
    [_pingItems addObject:pingItem];
    if (self.callbackHandler) {
        self.callbackHandler(pingItem, [_pingItems copy]);
    }
}

- (long)averageRetryTime {
    double total = 0;
    long count = 0;
    for (LFPingItem *item in _pingItems) {
        if (item.status == STDPingStatusDidReceivePacket) {
            total += item.timeMilliseconds;
            count++;
        }
    }
    return count > 0 ? total / count : 0;
}

- (float)lossPercentage {
    int receivedCount = 0;
    for (LFPingItem *item in _pingItems) {
        if (item.status == STDPingStatusDidReceivePacket) {
            receivedCount++;
        }
    }
    return receivedCount == _pingItems.count ? 100 : (float)(_pingItems.count - receivedCount) / _pingItems.count * 100;
}

- (NSString *)statistics {
    //    --- ping statistics ---
    //    5 packets transmitted, 5 packets received, 0.0% packet loss
    //    round-trip min/avg/max/stddev = 4.445/9.496/12.210/2.832 ms
    NSString *address = [_pingItems.firstObject originalAddress];
    __block NSInteger receivedCount = 0, allCount = 0;
    [_pingItems enumerateObjectsUsingBlock:^(LFPingItem *obj, NSUInteger idx, BOOL *stop) {
        if (obj.status != STDPingStatusFinished && obj.status != STDPingStatusError) {
            allCount ++;
            if (obj.status == STDPingStatusDidReceivePacket) {
                receivedCount ++;
            }
        }
    }];
    
    NSMutableString *description = [NSMutableString stringWithCapacity:50];
    [description appendFormat:@"--- %@ ping statistics ---\n", address];
    
    float lossPercent = (float)(allCount - receivedCount) / MAX(1.0, allCount) * 100;
    [description appendFormat:@"%ld packets transmitted, %ld packets received, %.1f%% packet loss\n", (long)allCount, (long)receivedCount, lossPercent];
    return [description stringByReplacingOccurrencesOfString:@".0%" withString:@"%"];
}

#pragma mark - LFSimplePing Delegate

- (void)st_simplePing:(LFSimplePing *)pinger didStartWithAddress:(NSData *)address {
    NSData *packet = [pinger packetWithPingData:nil];
    if (!_hasStarted) {
        LFPingItem *pingItem = [[LFPingItem alloc] init];
        pingItem.IPAddress = pinger.IPAddress;
        pingItem.originalAddress = self.address;
        pingItem.dateBytesLength = packet.length - sizeof(STICMPHeader);
        pingItem.status = STDPingStatusDidStart;
        if (self.callbackHandler) {
            self.callbackHandler(pingItem, nil);
        }
        _hasStarted = YES;
    }
    [pinger sendPacket:packet];
    [self performSelector:@selector(timeoutActionFired) withObject:nil afterDelay:self.timeoutMilliseconds / 1000.0];
}

// If this is called, the SimplePing object has failed.  By the time this callback is
// called, the object has stopped (that is, you don't need to call -stop yourself).

// IMPORTANT: On the send side the packet does not include an IP header.
// On the receive side, it does.  In that case, use +[SimplePing icmpInPacket:]
// to find the ICMP header within the packet.

- (void)st_simplePing:(LFSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    _sequenceNumber = sequenceNumber;
}

- (void)st_simplePing:(LFSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutActionFired) object:nil];
    _sequenceNumber = sequenceNumber;
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.ICMPSequence = _sequenceNumber;
    pingItem.originalAddress = self.address;
    pingItem.status = STDPingStatusDidFailToSendPacket;
    [self handlePingItem:pingItem];
}

- (void)st_simplePing:(LFSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutActionFired) object:nil];
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.ICMPSequence = _sequenceNumber;
    pingItem.originalAddress = self.address;
    pingItem.status = STDPingStatusDidReceiveUnexpectedPacket;
//    [self handlePingItem:pingItem];
}

- (void)st_simplePing:(LFSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet timeToLive:(NSInteger)timeToLive sequenceNumber:(uint16_t)sequenceNumber timeElapsed:(NSTimeInterval)timeElapsed {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutActionFired) object:nil];
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.IPAddress = pinger.IPAddress;
    pingItem.dateBytesLength = packet.length;
    pingItem.timeToLive = timeToLive;
    pingItem.timeMilliseconds = timeElapsed * 1000;
    pingItem.ICMPSequence = sequenceNumber;
    pingItem.originalAddress = self.address;
    pingItem.status = STDPingStatusDidReceivePacket;
    [self handlePingItem:pingItem];
}

- (void)st_simplePing:(LFSimplePing *)pinger didFailWithError:(NSError *)error {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(timeoutActionFired) object:nil];
    [self.simplePing stop];
    
    LFPingItem *errorPingItem = [[LFPingItem alloc] init];
    errorPingItem.originalAddress = self.address;
    errorPingItem.status = STDPingStatusError;
    if (self.callbackHandler) {
        self.callbackHandler(errorPingItem, [_pingItems copy]);
    }
    
    LFPingItem *pingItem = [[LFPingItem alloc] init];
    pingItem.originalAddress = self.address;
    pingItem.IPAddress = pinger.IPAddress ?: pinger.hostName;
    [_pingItems addObject:pingItem];
    pingItem.status = STDPingStatusFinished;
    if (self.callbackHandler) {
        self.callbackHandler(pingItem, [_pingItems copy]);
    }
}
@end
