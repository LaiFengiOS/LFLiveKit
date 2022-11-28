//
//  BitrateHandler.m
//  LFLiveKit
//
//  Created by Kory on 2020/6/29.
//  Copyright © 2020 admin. All rights reserved.
//

#import "BitrateHandler.h"


static NSInteger kb = 1024;

@interface BitrateHandler()

@property (nonatomic, assign) NSUInteger avgBitrate;
@property (nonatomic, assign) NSUInteger maxBitrate;
@property (nonatomic, assign) NSUInteger minBitrate;
@property (nonatomic, assign) NSUInteger currentBitrate;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, assign) NSUInteger cursor;
@property (nonatomic, retain) NSMutableArray *samples;

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
        _count = MAX(1, count);
        _cursor = 0;
        _samples = [NSMutableArray arrayWithCapacity:count];
    }
    return self;
}

#pragma mark - Public Methods

- (void)sendBufferSize:(NSUInteger)size {
    self.samples[self.cursor] = @(size);
    self.cursor = (self.cursor + 1) % self.count;
    if (self.samples.count < self.count) {
        return;
    }
    if (self.bitrateShouldChangeBlock == nil) {
        return;
    }
    NSInteger suggestedBitrate = [self calculateAdaptBitrateInput:self.movingAverage];
    if (suggestedBitrate == self.currentBitrate) {
        return;
    }
    NSLog(@"StreamStats: Reset to %@", @(suggestedBitrate));
    self.currentBitrate = suggestedBitrate;
    [self reset];
    self.bitrateShouldChangeBlock(suggestedBitrate);
}

#pragma mark - Private Methods

- (NSUInteger)movingAverage {
    if (self.samples.count == 0) {
        return 0;
    }
    NSUInteger sum = 0;
    NSArray *list = [self.samples copy];
    for (NSNumber *size in list) {
        sum += [size integerValue];
    }
    return sum / self.samples.count;
}

- (NSUInteger)calculateAdaptBitrateInput:(NSUInteger)input {
    NSUInteger suggestion = input;
    if (input <= (self.currentBitrate - 200 * kb)) {
        suggestion = input;
    } else if (input < (self.currentBitrate - 100 * kb)) {
        suggestion = self.currentBitrate;
    } else if (input < self.currentBitrate) {
        suggestion = self.currentBitrate + 50 * kb;
    } else {
        suggestion = self.currentBitrate + 100 * kb;
    }
    suggestion = [self quantize:suggestion];
    if (suggestion > self.maxBitrate) {
        return self.maxBitrate;
    }
    return suggestion;
}

- (NSUInteger)quantize:(NSUInteger)input {
    return ((NSUInteger)round((
                  (double)input / (50 * kb)
               ))) * 50 * kb;
}

- (void)reset {
    self.cursor = 0;
    self.samples = [NSMutableArray arrayWithCapacity:self.count];
}

@end
