//
//  RKAudioMixSource.h
//  LFLiveKit
//
//  Created by Ken Sun on 2017/10/2.
//  Copyright © 2017年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RKAudioMixSource <NSObject>

- (BOOL)hasNext;

// If has no next, 0 is returned.
- (short)next;

@end


@interface RKAudioURLMixSrc : NSObject <RKAudioMixSource>

@property (strong, nonatomic, readonly, nonnull) NSURL *soundURL;
@property (nonatomic) NSUInteger mixingChannels;
@property (nonatomic) BOOL repeated;
@property (nonatomic, readonly) BOOL isFinished;

- (nonnull instancetype)initWithURL:(nonnull NSURL *)url;

- (void)reset;

@end


@interface RKAudioDataMixSrc : NSObject <RKAudioMixSource>

@property (nonatomic, readonly) BOOL isEmpty;

- (void)pushData:(nonnull NSData *)data;

- (nullable NSData *)popData;

- (SInt16)nextFrame;

- (void)readBytes:(void *)dst length:(NSUInteger)length;

@end


