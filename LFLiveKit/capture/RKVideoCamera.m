//
//  RKVideoCamera.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKVideoCamera.h"

@interface RKVideoCamera () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation RKVideoCamera {
    dispatch_queue_t _cameraProcessingQueue;
    BOOL _capturePaused;
}
@synthesize frameRate = _frameRate;
@synthesize zoomFactor = _zoomFactor;

- (instancetype)initWithSessionPreset:(NSString *)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition {
    if (self = [super init]) {
        _cameraProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (device.position == cameraPosition) {
                _captureDevice = device;
                break;
            }
        }
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = sessionPreset;
        [_captureSession beginConfiguration];
        
        _videoDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:_captureDevice error:nil];
        if ([_captureSession canAddInput:_videoDeviceInput]) {
            [_captureSession addInput:_videoDeviceInput];
        }
        
        _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        _videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        _videoDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        [_videoDataOutput setSampleBufferDelegate:self queue:_cameraProcessingQueue];
        if ([_captureSession canAddOutput:_videoDataOutput]) {
            [_captureSession addOutput:_videoDataOutput];
        }
        [_captureSession commitConfiguration];
        
        _frameRate = 1 / CMTimeGetSeconds(_captureDevice.activeVideoMaxFrameDuration);
        _zoomFactor = _captureDevice.videoZoomFactor;
        NSLog(@"RKVideoCamera init - frame rate = %d, zoom scale = %f", _frameRate, _zoomFactor);
    }
    return self;
}

- (void)startCapture {
    if (!_captureSession.isRunning) {
        [_captureSession startRunning];
    }
}

- (void)stopCapture {
    if (_captureSession.isRunning) {
        [_captureSession stopRunning];
    }
}

- (void)pauseCapture {
    _capturePaused = YES;
}

- (void)resumeCapture {
    _capturePaused = NO;
}

- (void)rotateCamera {
    AVCaptureDevicePosition position = _captureDevice.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    
    AVCaptureDevice *newCaptureDevice = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            newCaptureDevice = device;
            break;
        }
    }
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCaptureDevice error:nil];
    
    if (newVideoInput) {
        [_captureSession beginConfiguration];
        
        [_captureSession removeInput:_videoDeviceInput];
        if ([_captureSession canAddInput:newVideoInput]) {
            [_captureSession addInput:newVideoInput];
            _videoDeviceInput = newVideoInput;
        } else  {
            [_captureSession addInput:_videoDeviceInput];
        }
        [_captureSession commitConfiguration];
    }
    _captureDevice = newCaptureDevice;
}

- (AVCaptureDevicePosition)cameraPosition {
    return _captureDevice.position;
}

- (void)setFrameRate:(int32_t)frameRate {
    _frameRate = frameRate;

    if ([_captureDevice lockForConfiguration:nil]) {
        [_captureDevice setActiveVideoMinFrameDuration:frameRate > 0 ? CMTimeMake(1, frameRate) : kCMTimeInvalid];
        [_captureDevice setActiveVideoMaxFrameDuration:frameRate > 0 ? CMTimeMake(1, frameRate) : kCMTimeInvalid];
        [_captureDevice unlockForConfiguration];
    }
}

- (int32_t)frameRate {
    return _frameRate;
}

- (void)setZoomFactor:(CGFloat)zoomFactor {
    CGFloat maxZoom = MIN(_captureDevice.activeFormat.videoMaxZoomFactor, 3.0);
    if (zoomFactor > maxZoom) {
        zoomFactor = maxZoom;
    } else if (zoomFactor < 1) {
        zoomFactor = 1;
    }
    if (_zoomFactor == zoomFactor) {
        return;
    }
    if ([_captureDevice lockForConfiguration:nil]) {
        _captureDevice.videoZoomFactor = zoomFactor;
        [_captureDevice unlockForConfiguration];
        _zoomFactor = zoomFactor;
    }
}

- (CGFloat)zoomFactor {
    return _zoomFactor;
}

#pragma mark - AVCaptureVideoDataOutputSampleBuffer Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_capturePaused || !_captureSession.isRunning) {
        return;
    }
    [_delegate videoCamera:self didCaptureVideoSample:sampleBuffer];
}

@end
