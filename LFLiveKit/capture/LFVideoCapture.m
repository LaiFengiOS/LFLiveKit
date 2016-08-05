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

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, weak) LFGPUImageBeautyFilter *beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageUIElement *uiElementInput;
@property (nonatomic, strong) UIView *waterMarkContentView;

@end

@implementation LFVideoCapture
@synthesize torch = _torch;
@synthesize beautyLevel = _beautyLevel;
@synthesize brightLevel = _brightLevel;
@synthesize zoomScale = _zoomScale;

#pragma mark -- LifeCycle
- (instancetype)initWithVideoConfiguration:(LFLiveVideoConfiguration *)configuration {
    if (self = [super init]) {
        _configuration = configuration;
        if([self pixelBufferImageSize].width < configuration.videoSize.width || [self pixelBufferImageSize].height < configuration.videoSize.height){
            @throw [NSException exceptionWithName:@"当前videoSize大小出错" reason:@"LFLiveVideoConfiguration videoSize error" userInfo:nil];
            return nil;
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        self.beautyFace = YES;
        self.beautyLevel = 0.5;
        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
        self.mirror = YES;
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.videoCamera stopCameraCapture];
}

#pragma mark -- Setter Getter

- (GPUImageVideoCamera *)videoCamera{
    if(!_videoCamera){
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];
        if (self.configuration.landscape) {
            if (statusBar != UIInterfaceOrientationLandscapeLeft && statusBar != UIInterfaceOrientationLandscapeRight) {
                @throw [NSException exceptionWithName:@"当前设置方向出错" reason:@"LFLiveVideoConfiguration landscape error" userInfo:nil];
                _videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
            } else {
                _videoCamera.outputImageOrientation = statusBar;
            }
        } else {
            if (statusBar != UIInterfaceOrientationPortrait && statusBar != UIInterfaceOrientationPortraitUpsideDown) {
                @throw [NSException exceptionWithName:@"当前设置方向出错" reason:@"LFLiveVideoConfiguration landscape error" userInfo:nil];
                _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
            } else {
                _videoCamera.outputImageOrientation = statusBar;
            }
        }
        
        _videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        _videoCamera.horizontallyMirrorRearFacingCamera = NO;
        _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    }
    return _videoCamera;
}

- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    _running = running;
    
    if (!_running) {
        [UIApplication sharedApplication].idleTimerDisabled = NO;
        [self.videoCamera stopCameraCapture];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
    }
}

- (void)setPreView:(UIView *)preView {
    if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
    [preView insertSubview:self.gpuImageView atIndex:0];
    self.gpuImageView.bounds = preView.bounds;
    self.waterMarkContentView.bounds = preView.bounds;
}

- (UIView *)preView {
    return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return [self.videoCamera cameraPosition];
}

- (void)setVideoFrameRate:(NSInteger)videoFrameRate {
    if (videoFrameRate <= 0) return;
    if (videoFrameRate == self.videoCamera.frameRate) return;
    self.videoCamera.frameRate = (uint32_t)videoFrameRate;
}

- (NSInteger)videoFrameRate {
    return self.videoCamera.frameRate;
}

- (void)setTorch:(BOOL)torch {
    BOOL ret;
    if (!self.videoCamera.captureSession) return;
    AVCaptureSession *session = (AVCaptureSession *)self.videoCamera.captureSession;
    [session beginConfiguration];
    if (self.videoCamera.inputCamera) {
        if (self.videoCamera.inputCamera.torchAvailable) {
            NSError *err = nil;
            if ([self.videoCamera.inputCamera lockForConfiguration:&err]) {
                [self.videoCamera.inputCamera setTorchMode:(torch ? AVCaptureTorchModeOn : AVCaptureTorchModeOff) ];
                [self.videoCamera.inputCamera unlockForConfiguration];
                ret = (self.videoCamera.inputCamera.torchMode == AVCaptureTorchModeOn);
            } else {
                NSLog(@"Error while locking device for torch: %@", err);
                ret = false;
            }
        } else {
            NSLog(@"Torch not available in current camera input");
        }
    }
    [session commitConfiguration];
    _torch = ret;
}

- (BOOL)torch {
    return self.videoCamera.inputCamera.torchMode;
}

- (void)setMirror:(BOOL)mirror {
    _mirror = mirror;
    self.videoCamera.horizontallyMirrorRearFacingCamera = mirror;
    self.videoCamera.horizontallyMirrorFrontFacingCamera = mirror;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    _beautyFace = beautyFace;
    [self reloadFilter];
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    _beautyLevel = beautyLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBeautyLevel:_beautyLevel];
    }
}

- (CGFloat)beautyLevel {
    return _beautyLevel;
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    _brightLevel = brightLevel;
    if (self.beautyFilter) {
        [self.beautyFilter setBrightLevel:brightLevel];
    }
}

- (CGFloat)brightLevel {
    return _brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    if (self.videoCamera && self.videoCamera.inputCamera) {
        AVCaptureDevice *device = (AVCaptureDevice *)self.videoCamera.inputCamera;
        if ([device lockForConfiguration:nil]) {
            device.videoZoomFactor = zoomScale;
            [device unlockForConfiguration];
            _zoomScale = zoomScale;
        }
    }
}

- (CGFloat)zoomScale {
    return _zoomScale;
}

- (void)setWarterMarkView:(UIView *)warterMarkView{
    if(_warterMarkView && _warterMarkView.superview){
        [_warterMarkView removeFromSuperview];
        _warterMarkView = nil;
    }
    _warterMarkView = warterMarkView;
    self.blendFilter.mix = warterMarkView.alpha;
    [self.waterMarkContentView addSubview:_warterMarkView];
    [self reloadFilter];
}

- (GPUImageUIElement *)uiElementInput{
    if(!_uiElementInput){
        _uiElementInput = [[GPUImageUIElement alloc] initWithView:self.waterMarkContentView];
    }
    return _uiElementInput;
}

- (GPUImageAlphaBlendFilter *)blendFilter{
    if(!_blendFilter){
        _blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
        _blendFilter.mix = 1.0;
        [_blendFilter disableSecondFrameCheck];
    }
    return _blendFilter;
}

- (UIView *)waterMarkContentView{
    if(!_waterMarkContentView){
        _waterMarkContentView = [UIView new];
        _waterMarkContentView.frame = CGRectMake(0, 0, self.gpuImageView.frame.size.width, self.gpuImageView.frame.size.height);
        _waterMarkContentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _waterMarkContentView;
}

- (GPUImageView *)gpuImageView{
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    }
    return _gpuImageView;
}
-(UIImage *)currentImage{
    [_filter useNextFrameForImageCapture];
    return _filter.imageFromCurrentFramebuffer;
}
#pragma mark -- Custom Method
- (void)processVideo:(GPUImageOutput *)output {
    __weak typeof(self) _self = self;
    @autoreleasepool {
        GPUImageFramebuffer *imageFramebuffer = output.framebufferForOutput;
        CVPixelBufferRef pixelBuffer = [imageFramebuffer pixelBuffer];

        if (pixelBuffer && _self.delegate && [_self.delegate respondsToSelector:@selector(captureOutput:pixelBuffer:)]) {
            [_self.delegate captureOutput:_self pixelBuffer:pixelBuffer];
        }
    }
}

- (void)reloadFilter{
    [self.filter removeAllTargets];
    [self.cropfilter removeAllTargets];
    [self.blendFilter removeAllTargets];
    [self.uiElementInput removeAllTargets];
    [self.videoCamera removeAllTargets];
   
    
    if (self.beautyFace) {
        self.output = [[LFGPUImageEmptyFilter alloc] init];
        self.filter = [[LFGPUImageBeautyFilter alloc] init];
        self.beautyFilter = self.filter;
        __weak typeof(self) _self = self;
        [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
            [_self processVideo:output];
        }];
    } else {
        self.filter = [[LFGPUImageEmptyFilter alloc] init];
        self.beautyFilter = nil;
        __weak typeof(self) _self = self;
        [self.filter setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
            [_self processVideo:output];
        }];
    }
    
    CGSize imageSize = [self pixelBufferImageSize];
    CGFloat cropLeft = (imageSize.width - self.configuration.videoSize.width)/2.0/imageSize.width;
    CGFloat cropTop = (imageSize.height - self.configuration.videoSize.height)/2.0/imageSize.height;
    
    if(cropLeft == 0 && cropTop == 0){
        [self.videoCamera addTarget:_filter];
    }else{
        self.cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(cropLeft, cropTop, 1 - cropLeft*2, 1 - cropTop*2)];
        [self.videoCamera addTarget:self.cropfilter];
        [self.cropfilter addTarget:self.filter];
    }
    
    if(self.warterMarkView){
        [self.filter addTarget:self.blendFilter];
        [self.uiElementInput addTarget:self.blendFilter];
        [self.blendFilter addTarget:self.gpuImageView];
        if(self.beautyFace){
            [self.filter addTarget:self.output];
        }
        [self.uiElementInput update];
    }else{
        if (self.beautyFace) {
            [self.filter addTarget:self.output];
            [self.output addTarget:self.gpuImageView];
        } else {
            [self.filter addTarget:self.gpuImageView];
        }
    }
    
}

#pragma mark Notification

- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.videoCamera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self.videoCamera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)statusBarChanged:(NSNotification *)notification {
    NSLog(@"UIApplicationWillChangeStatusBarOrientationNotification. UserInfo: %@", notification.userInfo);
    UIInterfaceOrientation statusBar = [[UIApplication sharedApplication] statusBarOrientation];
    if (self.configuration.landscape) {
        if (statusBar == UIInterfaceOrientationLandscapeLeft) {
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeRight;
        } else if (statusBar == UIInterfaceOrientationLandscapeRight) {
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationLandscapeLeft;
        }
    } else {
        if (statusBar == UIInterfaceOrientationPortrait) {
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortraitUpsideDown;
        } else if (statusBar == UIInterfaceOrientationPortraitUpsideDown) {
            self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        }
    }
}

#pragma mark -- 
- (CGSize)pixelBufferImageSize{
    CGSize videoSize = CGSizeZero;
    switch (self.configuration.sessionPreset) {
        case LFCaptureSessionPreset360x640:
        {
            videoSize = CGSizeMake(480, 640);
        }
            break;
        case LFCaptureSessionPreset540x960:
        {
            videoSize = CGSizeMake(540, 960);
        }
            break;
        case LFCaptureSessionPreset720x1280:
        {
            videoSize = CGSizeMake(720, 1280);
        }
            break;
            
        default:
            break;
    }
    
    if(self.configuration.landscape){
        return CGSizeMake(videoSize.height, videoSize.width);
    }
    return videoSize;
}

@end
