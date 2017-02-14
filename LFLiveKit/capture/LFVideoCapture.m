//
//  LFVideoCapture.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFVideoCapture.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFGPUImageEmptyFilter.h"
#import "RKGPUImageColorFilter.h"

#if __has_include(<GPUImage/GPUImage.h>)
#import <GPUImage/GPUImage.h>
#elif __has_include("GPUImage/GPUImage.h")
#import "GPUImage/GPUImage.h"
#else
#import "GPUImage.h"
#endif

static NSString * const kColorFilterTypeKey = @"type";
static NSString * const kColorFilterNameKey = @"name";
static NSString * const kColorFilterColorMapKey = @"colorMap";
static NSString * const kColorFilterSoftLightKey = @"softLight";
static NSString * const kColorFilterOverlayKey = @"overlay";

@interface LFVideoCapture ()

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property (nonatomic, strong) LFGPUImageBeautyFilter *beautyFilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property (nonatomic, strong) GPUImageCropFilter *cropfilter;
@property (nonatomic, strong) GPUImageOutput<GPUImageInput> *output;
@property (nonatomic, strong) GPUImageView *gpuImageView;
@property (nonatomic, strong) LFLiveVideoConfiguration *configuration;

@property (nonatomic, strong) GPUImageAlphaBlendFilter *blendFilter;
@property (nonatomic, strong) GPUImageUIElement *uiElementInput;
@property (nonatomic, strong) UIView *waterMarkContentView;

@property (nonatomic, strong) GPUImageMovieWriter *movieWriter;

@property (nonatomic, assign) NSInteger currentFilterIndex;

@property (nonatomic, copy, readonly) NSArray *filterInfos;

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

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarChanged:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        
        self.beautyFace = YES;
        self.beautyLevel = 0.5;
        self.brightLevel = 0.5;
        self.zoomScale = 1.0;
        self.mirror = YES;
        _currentFilterIndex = 0;
        _filterInfos = @[@{kColorFilterTypeKey: @(RKColorFilterNone),
                           kColorFilterNameKey: NSLocalizedString(@"NORMAL_FILTER", nil)},
                         
//                         @{kColorFilterTypeKey: @(RKColorFilterRich),
//                           kColorFilterNameKey: NSLocalizedString(@"RICH_FILTER", nil),
//                           kColorFilterColorMapKey: @"rich_map",
//                           kColorFilterSoftLightKey: @"overlay_softlight6"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterWarm),
                           kColorFilterNameKey: NSLocalizedString(@"WARM_FILTER", nil),
                           kColorFilterColorMapKey: @"warm_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterSoft),
                           kColorFilterNameKey: NSLocalizedString(@"SOFT_FILTER", nil),
                           kColorFilterColorMapKey: @"soft_map"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterRose),
                           kColorFilterNameKey: NSLocalizedString(@"ROSE_FILTER", nil),
                           kColorFilterColorMapKey: @"rose_map"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterMorning),
                           kColorFilterNameKey: NSLocalizedString(@"MORNING_FILTER", nil),
                           kColorFilterColorMapKey: @"morning_map"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterSunshine),
                           kColorFilterNameKey: NSLocalizedString(@"SUNSHINE_FILTER", nil),
                           kColorFilterColorMapKey: @"sunshine_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterSunset),
                           kColorFilterNameKey: NSLocalizedString(@"SUNSET_FILTER", nil),
                           kColorFilterColorMapKey: @"sunset_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterCool),
                           kColorFilterNameKey: NSLocalizedString(@"COOL_FILTER", nil),
                           kColorFilterColorMapKey: @"cool_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterFreeze),
                           kColorFilterNameKey: NSLocalizedString(@"FREEZE_FILTER", nil),
                           kColorFilterColorMapKey: @"freeze_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterOcean),
                           kColorFilterNameKey: NSLocalizedString(@"OCEAN_FILTER", nil),
                           kColorFilterColorMapKey: @"ocean_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterDream),
                           kColorFilterNameKey: NSLocalizedString(@"DREAM_FILTER", nil),
                           kColorFilterColorMapKey: @"dream_map",
                           kColorFilterSoftLightKey: @"overlay_softlight3"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterViolet),
                           kColorFilterNameKey: NSLocalizedString(@"VIOLET_FILTER", nil),
                           kColorFilterColorMapKey: @"violet_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterMellow),
                           kColorFilterNameKey: NSLocalizedString(@"MELLOW_FILTER", nil),
                           kColorFilterColorMapKey: @"mellow_map",
                           kColorFilterSoftLightKey: @"overlay_softlight6"},
                         
//                         @{kColorFilterTypeKey: @(RKColorFilterBleak),
//                           kColorFilterNameKey: NSLocalizedString(@"BLEAK_FILTER", nil),
//                           kColorFilterColorMapKey: @"bleak_map",
//                           kColorFilterSoftLightKey: @"overlay_softlight1",
//                           kColorFilterOverlayKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterMemory),
                           kColorFilterNameKey: NSLocalizedString(@"MEMORY_FILTER", nil),
                           kColorFilterColorMapKey: @"memory_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1",
                           kColorFilterOverlayKey: @"overlay_softlight3"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterPure),
                           kColorFilterNameKey: NSLocalizedString(@"PURE_FILTER", nil),
                           kColorFilterColorMapKey: @"pure_map"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterCalm),
                           kColorFilterNameKey: NSLocalizedString(@"CALM_FILTER", nil),
                           kColorFilterColorMapKey: @"calm_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterAutumn),
                           kColorFilterNameKey: NSLocalizedString(@"AUTUMN_FILTER", nil),
                           kColorFilterColorMapKey: @"autumn_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1",
                           kColorFilterOverlayKey: @"overlay_softlight3"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterFantasy),
                           kColorFilterNameKey: NSLocalizedString(@"FANTASY_FILTER", nil),
                           kColorFilterColorMapKey: @"fantasy_map",
                           kColorFilterSoftLightKey: @"overlay_softlight4"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterFreedom),
                           kColorFilterNameKey: NSLocalizedString(@"FREEDOM_FILTER", nil),
                           kColorFilterColorMapKey: @"freedom_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterMild),
                           kColorFilterNameKey: NSLocalizedString(@"MILD_FILTER", nil),
                           kColorFilterColorMapKey: @"mild_map",
                           kColorFilterSoftLightKey: @"overlay_softlight5"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterPrairie),
                           kColorFilterNameKey: NSLocalizedString(@"PRAIRIE_FILTER", nil),
                           kColorFilterColorMapKey: @"prairie_map",
                           kColorFilterSoftLightKey: @"overlay_softlight5"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterDeep),
                           kColorFilterNameKey: NSLocalizedString(@"DEEP_FILTER", nil),
                           kColorFilterColorMapKey: @"deep_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterGlow),
                           kColorFilterNameKey: NSLocalizedString(@"GLOW_FILTER", nil),
                           kColorFilterColorMapKey: @"glow_map",
                           kColorFilterSoftLightKey: @"overlay_softlight5"},
                         
//                         @{kColorFilterTypeKey: @(RKColorFilterMemoir),
//                           kColorFilterNameKey: NSLocalizedString(@"MEMOIR_FILTER", nil),
//                           kColorFilterColorMapKey: @"memoir_map",
//                           kColorFilterSoftLightKey: @"overlay_softlight6"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterMist),
                           kColorFilterNameKey: NSLocalizedString(@"MIST_FILTER", nil),
                           kColorFilterColorMapKey: @"mist_map",
                           kColorFilterSoftLightKey: @"overlay_softlight5"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterVivid),
                           kColorFilterNameKey: NSLocalizedString(@"VIVID_FILTER", nil),
                           kColorFilterColorMapKey: @"vivid_map",
                           kColorFilterSoftLightKey: @"overlay_softlight1"},
                         
//                         @{kColorFilterTypeKey: @(RKColorFilterChill),
//                           kColorFilterNameKey: NSLocalizedString(@"CHILL_FILTER", nil),
//                           kColorFilterColorMapKey: @"chill_map",
//                           kColorFilterSoftLightKey: @"overlay_softlight1",
//                           kColorFilterOverlayKey: @"overlay_softlight5"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterPinky),
                           kColorFilterNameKey: NSLocalizedString(@"PINKY_FILTER", nil),
                           kColorFilterColorMapKey: @"pinky_map",
                           kColorFilterSoftLightKey: @"overlay_softlight5"},
                         
                         @{kColorFilterTypeKey: @(RKColorFilterAdventure),
                           kColorFilterNameKey: NSLocalizedString(@"ADVENTURE_FILTER", nil),
                           kColorFilterColorMapKey: @"adventure_map",
                           kColorFilterSoftLightKey: @"overlay_softlight2",
                           kColorFilterOverlayKey: @"overlay_softlight3"}
                         ];
    }
    return self;
}

- (void)dealloc {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_videoCamera stopCameraCapture];
    if(_gpuImageView){
        [_gpuImageView removeFromSuperview];
        _gpuImageView = nil;
    }
}

#pragma mark -- Public

- (void)previousFilter {
    self.currentFilterIndex--;
    [self reloadFilter];
}

- (void)nextFilter {
    self.currentFilterIndex++;
    [self reloadFilter];
}

#pragma mark -- Setter Getter

- (NSString *)currentFilterName {
    NSDictionary *filterInfo = self.filterInfos[self.currentFilterIndex];
    return filterInfo[kColorFilterNameKey];
}

- (void)setCurrentFilterIndex:(NSInteger)currentFilterIndex {
    if (currentFilterIndex < 0) {
        currentFilterIndex = self.filterInfos.count - 1;
        
    } else if (currentFilterIndex >= self.filterInfos.count) {
        currentFilterIndex = 0;
    }
    
    _currentFilterIndex = currentFilterIndex;
}

- (GPUImageVideoCamera *)videoCamera{
    if(!_videoCamera){
        _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:_configuration.avSessionPreset cameraPosition:AVCaptureDevicePositionFront];
        _videoCamera.outputImageOrientation = _configuration.outputImageOrientation;
        _videoCamera.horizontallyMirrorFrontFacingCamera = NO;
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
        if(self.saveLocalVideo) [self.movieWriter finishRecording];
    } else {
        [UIApplication sharedApplication].idleTimerDisabled = YES;
        [self reloadFilter];
        [self.videoCamera startCameraCapture];
        if(self.saveLocalVideo) [self.movieWriter startRecording];
    }
}

- (void)setPreView:(UIView *)preView {
    if (self.gpuImageView.superview) [self.gpuImageView removeFromSuperview];
    [preView insertSubview:self.gpuImageView atIndex:0];
    self.gpuImageView.frame = CGRectMake(0, 0, preView.frame.size.width, preView.frame.size.height);
}

- (UIView *)preView {
    return self.gpuImageView.superview;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    if(captureDevicePosition == self.videoCamera.cameraPosition) return;
    [self.videoCamera rotateCamera];
    self.videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
    [self reloadMirror];
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
        _waterMarkContentView.frame = CGRectMake(0, 0, self.configuration.videoSize.width, self.configuration.videoSize.height);
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
    if(_filter){
        [_filter useNextFrameForImageCapture];
        return _filter.imageFromCurrentFramebuffer;
    }
    return nil;
}

- (GPUImageMovieWriter*)movieWriter{
    if(!_movieWriter){
        _movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:self.saveLocalVideoPath size:self.configuration.videoSize];
        _movieWriter.encodingLiveVideo = YES;
        _movieWriter.shouldPassthroughAudio = YES;
        self.videoCamera.audioEncodingTarget = self.movieWriter;
    }
    return _movieWriter;
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
    [self.blendFilter removeAllTargets];
    [self.uiElementInput removeAllTargets];
    [self.videoCamera removeAllTargets];
    [self.output removeAllTargets];
    [self.cropfilter removeAllTargets];
    
    self.output = [[LFGPUImageEmptyFilter alloc] init];
    self.filter = [[GPUImageFilterGroup alloc] init];
    
    NSDictionary *filterInfo = self.filterInfos[self.currentFilterIndex];
    NSString *colorMap = filterInfo[kColorFilterColorMapKey];
    NSString *softLight = filterInfo[kColorFilterSoftLightKey];
    NSString *overlay = filterInfo[kColorFilterOverlayKey];
    RKGPUImageColorFilter *colorFilter = [[RKGPUImageColorFilter alloc] initWithColorMap:colorMap softLight:softLight overlay:overlay];

    if (self.beautyFace) {
        self.beautyFilter = [[LFGPUImageBeautyFilter alloc] init];
        [(GPUImageFilterGroup *)self.filter addFilter:self.beautyFilter];
        
        if (colorFilter) {
            [self.beautyFilter addTarget:colorFilter];
            [(GPUImageFilterGroup *)self.filter addFilter:colorFilter];
            [(GPUImageFilterGroup *)self.filter setTerminalFilter:colorFilter];
        }
        
        [(GPUImageFilterGroup *)self.filter setInitialFilters:@[self.beautyFilter]];
        [(GPUImageFilterGroup *)self.filter setTerminalFilter:colorFilter ? colorFilter : self.beautyFilter];
        
    } else {
        self.beautyFilter = nil;
        
        LFGPUImageEmptyFilter *emptyFilter = [[LFGPUImageEmptyFilter alloc] init];
        [(GPUImageFilterGroup *)self.filter addFilter:emptyFilter];
        
        if (colorFilter) {
            [emptyFilter addTarget:colorFilter];
            [(GPUImageFilterGroup *)self.filter addFilter:colorFilter];
            [(GPUImageFilterGroup *)self.filter setTerminalFilter:colorFilter];
        }
        
        [(GPUImageFilterGroup *)self.filter setInitialFilters:@[emptyFilter]];
        [(GPUImageFilterGroup *)self.filter setTerminalFilter:colorFilter ? colorFilter : emptyFilter];
    }
    
    ///< 调节镜像
    [self reloadMirror];
    
    //< 480*640 比例为4:3  强制转换为16:9
    if([self.configuration.avSessionPreset isEqualToString:AVCaptureSessionPreset640x480]){
        CGRect cropRect = self.configuration.landscape ? CGRectMake(0, 0.125, 1, 0.75) : CGRectMake(0.125, 0, 0.75, 1);
        self.cropfilter = [[GPUImageCropFilter alloc] initWithCropRegion:cropRect];
        [self.videoCamera addTarget:self.cropfilter];
        [self.cropfilter addTarget:self.filter];
    }else{
        [self.videoCamera addTarget:self.filter];
    }
    
    //< 添加水印
    if(self.warterMarkView){
        [self.filter addTarget:self.blendFilter];
        [self.uiElementInput addTarget:self.blendFilter];
        [self.blendFilter addTarget:self.gpuImageView];
        if(self.saveLocalVideo) [self.blendFilter addTarget:self.movieWriter];
        [self.filter addTarget:self.output];
        [self.uiElementInput update];
    }else{
        [self.filter addTarget:self.output];
        [self.output addTarget:self.gpuImageView];
        if(self.saveLocalVideo) [self.output addTarget:self.movieWriter];
    }
    
    [self.filter forceProcessingAtSize:self.configuration.videoSize];
    [self.output forceProcessingAtSize:self.configuration.videoSize];
    [self.blendFilter forceProcessingAtSize:self.configuration.videoSize];
    [self.uiElementInput forceProcessingAtSize:self.configuration.videoSize];
    
    
    //< 输出数据
    __weak typeof(self) _self = self;
    [self.output setFrameProcessingCompletionBlock:^(GPUImageOutput *output, CMTime time) {
        [_self processVideo:output];
    }];
    
}

- (void)reloadMirror{
//    if(self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront){
//        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
//    }else{
//        self.videoCamera.horizontallyMirrorFrontFacingCamera = NO;
//    }
    
    [self.gpuImageView setInputRotation:(self.mirror && self.captureDevicePosition == AVCaptureDevicePositionFront) ? kGPUImageFlipHorizonal : kGPUImageNoRotation atIndex:0];
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

    if(self.configuration.autorotate){
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
}

@end
