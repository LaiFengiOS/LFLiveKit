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
- (void)captureOutput:(nullable LFAudioCapture *)capture didFinishAudioProcessing:(nullable NSData *)data;
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

//@property (nonatomic, assign) BOOL isMixer;
//
//@property (nonatomic, assign) BOOL isLoadingAudioFile;

//@property (nonatomic, strong, nullable) NSURL *audioPath;

//@property (nonatomic, assign) int dataSizeTotal;
//
//@property (nonatomic, assign) long dataSizeCount;
//
//@property char* _Nullable mp3Data;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

//@property (nonatomic, strong, nullable) NSMutableArray *inputAudioDataArray;
//
//@property (nonatomic, assign) int inputAudioDataCurrentIndex;

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

- (void)mixSound:(nonnull NSURL *)url;

- (void)mixSideData:(nonnull NSData *)data;

@end
