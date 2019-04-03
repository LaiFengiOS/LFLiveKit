//
//  LFVideoCaptureInterface.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFLiveVideoConfiguration.h"

typedef NS_ENUM(NSInteger, RKColorFilter) {
    RKColorFilterNone,
    RKColorFilterRich,
    RKColorFilterWarm,
    RKColorFilterSoft,
    RKColorFilterRose,
    RKColorFilterMorning,
    RKColorFilterSunshine,
    RKColorFilterSunset,
    RKColorFilterCool,
    RKColorFilterFreeze,
    RKColorFilterOcean,
    RKColorFilterDream,
    RKColorFilterViolet,
    RKColorFilterMellow,
    RKColorFilterBleak,
    RKColorFilterMemory,
    RKColorFilterPure,
    RKColorFilterCalm,
    RKColorFilterAutumn,
    RKColorFilterFantasy,
    RKColorFilterFreedom,
    RKColorFilterMild,
    RKColorFilterPrairie,
    RKColorFilterDeep,
    RKColorFilterGlow,
    RKColorFilterMemoir,
    RKColorFilterMist,
    RKColorFilterVivid,
    RKColorFilterChill,
    RKColorFilterPinky,
    RKColorFilterAdventure
};

@protocol LFVideoCaptureInterfaceDelegate;

@protocol LFVideoCaptureInterface <NSObject>

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================

/** The delegate of the capture. captureData callback */
@property (nullable, nonatomic, weak) id<LFVideoCaptureInterfaceDelegate> delegate;

/** The running control start capture or stop capture*/
@property (nonatomic, assign) BOOL running;

/** The preView will show OpenGL ES view*/
@property (null_resettable, nonatomic, strong) UIView *preView;

/** The captureDevicePosition control camraPosition ,default front*/
@property (nonatomic, assign) AVCaptureDevicePosition captureDevicePosition;

/** The beautyFace control capture shader filter empty or beautiy */
@property (nonatomic, assign) BOOL beautyFace;

/** The torch control capture flash is on or off */
@property (nonatomic, assign) BOOL torch;

/** The mirror control mirror of front camera is on or off */
@property (nonatomic, assign) BOOL mirror;

/** The torch control camera zoom scale default 1.0, between 1.0 ~ 3.0 */
@property (nonatomic, assign) CGFloat zoomScale;

/** The videoFrameRate control videoCapture output data count */
@property (nonatomic, assign) NSInteger videoFrameRate;

/*** The watermarkView control whether the watermark is displayed or not ,if set ni,will remove watermark,otherwise add *.*/
@property (nonatomic, strong, nullable) UIView *watermarkView;

/* The currentImage is videoCapture shot */
@property (nonatomic, readonly, nullable) UIImage *currentImage;

/* The saveLocalVideo is save the local video */
@property (nonatomic, assign) BOOL saveLocalVideo;

/* The saveLocalVideoPath is save the local video  path */
@property (nonatomic, strong, nullable) NSURL *saveLocalVideoPath;

/* The currentColorFilterName is localized name of current color filter */
@property (nonatomic, copy, readonly, nullable) NSString *currentColorFilterName;

/* The currentColorFilterIndex is index of current color filter */
@property (nonatomic, assign, readonly) NSInteger currentColorFilterIndex;

/* The colorFilterNames is name of all color filters */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *colorFilterNames;

/** The mirrorOuput control mirror of front camera output is on or off */
@property (nonatomic, assign) BOOL mirrorOutput;

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
/**
 The designated initializer. Multiple instances with the same configuration will make the
 capture unstable.
 */
- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration;

/** Switch to previous color filter. */
- (void)previousColorFilter;

/** Switch to next color filter. */
- (void)nextColorFilter;

/** Switch to target color filter. */
- (void)setTargetColorFilter:(NSInteger)targetIndex;

@end

@protocol LFVideoCaptureInterfaceDelegate <NSObject>
@optional
- (void)captureOutput:(nullable id<LFVideoCaptureInterface>)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer atTime:(CMTime)time;
- (void)captureRawCamera:(nullable id<LFVideoCaptureInterface>)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer atTime:(CMTime)time;

@end
