//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/1.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFVideoCapture.h"
#import "GPUImage.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFGPUImageEmptyFilter.h"

@interface LFVideoCapture ()

@property(nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property(nonatomic, strong) GPUImageCropFilter *cropfilter;
@property(nonatomic, strong) GPUImageView *gpuImageView;
@property(nonatomic, strong) LFLiveVideoConfiguration *configuration;

@end

@implementation LFVideoCapture

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration{
    if(self = [super init]){
        _configuration = configuration;
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = _configuration.orientation;
        _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
        
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        self.beautyFace = YES;
    }
    return self;
}

- (void)dealloc{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
}

#pragma mark -- Setter Getter
- (void)setRunning:(BOOL)running{
    if(_running == running) return;
    _running = running;
    
    if(!_running){
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [_videoCamera stopCameraCapture];
    }else{
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [_videoCamera startCameraCapture];
    }
}

- (void)setPreView:(UIView *)preView{
    if(_gpuImageView.superview) [_gpuImageView removeFromSuperview];
    [preView insertSubview:_gpuImageView atIndex:0];
}

- (UIView*)preView{
    return _gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition{
    [_videoCamera rotateCamera];
    _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    if (captureDevicePosition == AVCaptureDevicePositionFront) {
        [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    } else {
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
}

- (AVCaptureDevicePosition)captureDevicePosition{
    return [_videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate{
    if(videoFrameRate <= 0) return;
    if(videoFrameRate == _videoCamera.frameRate) return;
    _videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate{
    return _videoCamera.frameRate;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    if(_beautyFace == beautyFace) return;
    
    _beautyFace = beautyFace;
    [_filter removeAllTargets];
    [_cropfilter removeAllTargets];
    [_videoCamera removeAllTargets];
    
    if (_beautyFace) {
        _output = [[LFGPUImageEmptyFilter alloc] init];
        _filter = [[LFGPUImageBeautyFilter alloc] init];
        
        __weak typeof(self) _self = self;
        [_output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
            [_self processVideo:output];
        }];
    } else {
        _filter = [[LFGPUImageEmptyFilter alloc] init];
        
        __weak typeof(self) _self = self;
        [_filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
            [_self processVideo:output];
        }];
    }
    
    if (_configuration.isClipVideo) {
        if (_configuration.orientation == UIInterfaceOrientationPortrait || _configuration.orientation == UIInterfaceOrientationPortraitUpsideDown){
            _cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0.125, 0, 0.75, 1)];
        } else {
            _cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(0, 0.125, 1, 0.75)];
        }
        [_videoCamera addTarget:_cropfilter];
        [_cropfilter addTarget:_filter];
    } else {
        [_videoCamera addTarget:_filter];
    }
    
    if (_beautyFace) {
        [_filter addTarget:_output];
        [_output addTarget:_gpuImageView];
    } else {
        [_filter addTarget:_gpuImageView];
    }
    
    if (_videoCamera.cameraPosition == AVCaptureDevicePositionFront) {
        [_gpuImageView setInputRotation:kGPUImageFlipHorizonal atIndex:0];
    } else {
        [_gpuImageView setInputRotation:kGPUImageNoRotation atIndex:0];
    }
}

#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output{
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];
        
        if(pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]){
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }

    }
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification*)notification{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification*)notification{
    [_videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

@end
