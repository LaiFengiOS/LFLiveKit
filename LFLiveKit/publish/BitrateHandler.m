//
//  BitrateHandler.m
//  LFLiveKit
//
//  Created by Kory on 2020/6/29.
//  Copyright © 2020 admin. All rights reserved.
//

#import "BitrateHandler.h"

@interface BitrateHandler()

@property (nonatomic, assign) NSUInteger avgBitrate;
@property (nonatomic, assign) NSUInteger maxBitrate;
@property (nonatomic, assign) NSUInteger minBitrate;
@property (nonatomic, assign) NSUInteger currentBitrate;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) NSUInteger totalSize;

@end

@implementation BitrateHandler

- (instancetype)initWithAvg:(NSUInteger)avgBitrate
                        max:(NSUInteger)maxBitrate
                        min:(NSUInteger)minBitrate
                      count:(NSUInteger)count {
    if (self) {
        _avgBitrate = avgBitrate;
        _maxBitrate = maxBitrate;
        _minBitrate = minBitrate;
        _currentBitrate = avgBitrate;
        _count = count;
        _totalSize = 0;
    }
    return self;
}

#pragma mark - Public Methods

- (void)sendBufferSize:(NSUInteger)size {
    self.totalSize += size;
    self.count ++;
    if (self.count < 5) {
        return;
    }
    
    if (self.bitrateShouldChangeBlock) {
        self.bitrateShouldChangeBlock([self calculateAdaptBitrateInput:self.totalSize/self.count]);
    }
    [self reset];
}

#pragma mark - Private Methods

- (NSUInteger)calculateAdaptBitrateInput:(NSUInteger)input {
    if (input >= self.maxBitrate) {
        self.currentBitrate = self.maxBitrate;
    } else if (input <= self.currentBitrate * 0.8) {
        self.currentBitrate = (NSUInteger)(input * 0.8);
    } else {
        NSUInteger expected = (NSUInteger)(input * 1.1);
        self.currentBitrate = expected > self.maxBitrate ? self.maxBitrate : expected;
    }
    return self.currentBitrate;
}

- (void)reset {
    self.count = 0;
    self.totalSize = 0;
}

@end
