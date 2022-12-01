//
//  BitrateHandler.h
//  LFLiveKit
//
//  Created by Kory on 2020/6/29.
//  Copyright © 2020 admin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BitrateHandler : NSObject

@property (nonatomic, copy, nullable) void (^bitrateShouldChangeBlock)(NSUInteger);
@property (nonatomic, assign, readonly) NSUInteger currentBitrate;

- (instancetype)initWithAvg:(NSUInteger)avgBitrate
                        max:(NSUInteger)maxBitrate
                        min:(NSUInteger)minBitrate
                      count:(NSUInteger)count;
- (instancetype)init NS_UNAVAILABLE;

- (void)sendBufferSize:(NSUInteger)size;

@end

NS_ASSUME_NONNULL_END
