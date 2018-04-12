//
//  RKVideoCamera.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol RKVideoCameraDelegate;

@interface RKVideoCamera : NSObject

@property (weak, nonatomic) id<RKVideoCameraDelegate> delegate;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoDataOutput;

/// This enables the capture session preset to be changed on the fly
@property (readwrite, nonatomic, copy) NSString *captureSessionPreset;

/// This sets the frame rate of the camera (iOS 5 and above only)
/**
 Setting this to 0 or below will set the frame rate back to the default setting for a particular preset.
 */
@property (readwrite) int32_t frameRate;

@property (readwrite) CGFloat zoomFactor;

- (instancetype)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;

- (void)startCapture;
- (void)stopCapture;
- (void)pauseCapture;
- (void)resumeCapture;

- (AVCaptureDevicePosition)cameraPosition;

- (void)rotateCamera;

@end

@protocol RKVideoCameraDelegate <NSObject>

- (void)videoCamera:(RKVideoCamera *)camera didCaptureVideoSample:(CMSampleBufferRef)sampleBuffer;

@end
