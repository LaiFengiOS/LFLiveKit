//
//  LFAudioCapture.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFLiveAudioConfiguration.h"

#pragma mark -- AudioCaptureNotification
/** compoentFialed will post the notification */
extern NSString *_Nullable const LFAudioComponentFailedToCreateNotification;

@class LFAudioCapture;
/** LFAudioCapture callback audioData */
@protocol LFAudioCaptureDelegate <NSObject>
- (void)captureOutput:(nullable LFAudioCapture *)capture audioBeforeSideMixing:(nullable NSData *)data;
- (void)captureOutput:(nullable LFAudioCapture *)capture didFinishAudioProcessing:(AudioBufferList)buffers samples:(NSUInteger)samples;
@end


@interface LFAudioCapture : NSObject

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<LFAudioCaptureDelegate> delegate;

/** The muted control callbackAudioData,muted will memset 0.*/
@property (nonatomic, assign) BOOL muted;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;


#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

/**
   The designated initializer. Multiple instances with the same configuration will make the
   capture unstable.
 */
- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)configuration NS_DESIGNATED_INITIALIZER;

- (void)mixSound:(nonnull NSURL *)url weight:(float)weight;

- (void)mixSound:(nonnull NSURL *)url weight:(float)weight repeated:(BOOL)repeated;

- (void)mixSounds:(nonnull NSArray<NSURL *> *)urls weights:(nonnull NSArray<NSNumber *> *)weights;

- (void)mixSoundSequences:(nonnull NSArray<NSURL *> *)urls weight:(float)weight;

- (void)mixSideData:(nonnull NSData *)data weight:(float)weight;

- (void)stopMixSound:(nonnull NSURL *)url;

- (void)stopMixAllSounds;

@end
