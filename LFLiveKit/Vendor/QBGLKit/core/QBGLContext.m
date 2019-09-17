//
//  QBGLContext.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLContext.h"
#import "QBGLFilterFactory.h"
#import "QBGLProgram.h"
#import "QBGLUtils.h"
#import "QBGLBeautyFilter.h"
#import "QBGLBeautyColorMapFilter.h"
#import "QBGLMagicFilterBase.h"
#import "QBGLMagicFilterFactory.h"

@interface QBGLContext ()

@property (nonatomic, readonly) QBGLYuvFilter *filter;

@property (nonatomic, readonly) QBGLYuvFilter *inputFilter;
@property (nonatomic, readonly) QBGLFilter *outputFilter;

@property (strong, nonatomic) QBGLYuvFilter *normalFilter;
@property (strong, nonatomic) QBGLBeautyFilter *beautyFilter;
@property (strong, nonatomic) QBGLColorMapFilter *colorFilter;
@property (strong, nonatomic) QBGLBeautyColorMapFilter *beautyColorFilter;

@property (strong, nonatomic) QBGLMagicFilterFactory *magicFilterFactory;
@property (strong, nonatomic) QBGLMagicFilterBase *magicFilter;

@property (nonatomic) QBGLImageRotation inputRotation;
@property (nonatomic) QBGLImageRotation previewInputRotation;
@property (nonatomic) QBGLImageRotation previewAnimationRotation;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;

@end

@implementation QBGLContext

- (instancetype)init {
    return [self initWithContext:nil animationView:nil];
}

- (instancetype)initWithContext:(EAGLContext *)context animationView:(UIView *)animationView {
    if (context.API == kEAGLRenderingAPIOpenGLES1)
        @throw [NSException exceptionWithName:@"QBGLContext init error" reason:@"GL context  can't be kEAGLRenderingAPIOpenGLES1" userInfo:nil];
    if (self = [super init]) {
        _glContext = context ?: [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];;
        _animationView = animationView;
        [self becomeCurrentContext];
    }
    return self;
}

- (void)dealloc {
    [self becomeCurrentContext];
    CFRelease(_textureCacheRef);
    
    [EAGLContext setCurrentContext:nil];
    
    [self.magicFilterFactory clearCache];
}

- (CVPixelBufferRef)outputPixelBuffer {
    return self.outputFilter.outputPixelBuffer;
}

- (QBGLMagicFilterFactory *)magicFilterFactory {
    if (!_magicFilterFactory) {
        _magicFilterFactory = [[QBGLMagicFilterFactory alloc] init];
    }
    return _magicFilterFactory;
}

- (QBGLYuvFilter *)normalFilter {
    if (!_normalFilter) {
        _normalFilter = [[QBGLYuvFilter alloc] initWithAnimationView:self.animationView];
        _normalFilter.textureCacheRef = _textureCacheRef;
    }
    return _normalFilter;
}

- (QBGLBeautyFilter *)beautyFilter {
    if (!_beautyFilter) {
        _beautyFilter = [[QBGLBeautyFilter alloc] initWithAnimationView:self.animationView];
        _beautyFilter.textureCacheRef = _textureCacheRef;
    }
    return _beautyFilter;
}

- (QBGLColorMapFilter *)colorFilter {
    if (!_colorFilter) {
        _colorFilter = [[QBGLColorMapFilter alloc] initWithAnimationView:self.animationView];
        _colorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_colorFilter.type != _colorFilterTypeForRender) {
        [QBGLFilterFactory refactorColorFilter:_colorFilter withType:_colorFilterTypeForRender];
        _colorFilter.type = _colorFilterTypeForRender;
    }
    return _colorFilter;
}

- (QBGLBeautyColorMapFilter *)beautyColorFilter {
    if (!_beautyColorFilter) {
        _beautyColorFilter = [[QBGLBeautyColorMapFilter alloc] initWithAnimationView:self.animationView];
        _beautyColorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_beautyColorFilter.type != _colorFilterTypeForRender) {
        [QBGLFilterFactory refactorColorFilter:_beautyColorFilter withType:_colorFilterTypeForRender];
        _beautyColorFilter.type = _colorFilterTypeForRender;
    }
    return _beautyColorFilter;
}

- (QBGLMagicFilterBase *)magicFilter {
    if (!_magicFilter || (_colorFilterTypeForRender != QBGLFilterTypeNone && _magicFilter.type != _colorFilterTypeForRender)) {
        _magicFilter = [self.magicFilterFactory filterWithType:_colorFilterTypeForRender animationView:self.animationView];
    }
    return _magicFilter;
}

- (QBGLYuvFilter *)filter {
    BOOL colorFilterType17 = (_colorFilterTypeForRender > QBGLFilterTypeNone && _colorFilterTypeForRender < QBGLFilterTypeFairytale);
    if (_beautyEnabled && _colorFilterTypeForRender != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.beautyColorFilter : self.beautyFilter);
    } else if (_beautyEnabled && _colorFilterTypeForRender == QBGLFilterTypeNone) {
        return self.beautyFilter;
    } else if (!_beautyEnabled && _colorFilterTypeForRender != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.colorFilter : self.normalFilter);
    } else {
        return self.normalFilter;
    }
}

- (QBGLYuvFilter *)inputFilter {
    return self.filter;
}

- (QBGLFilter *)outputFilter {
    BOOL colorFilterTypeMagic = (_colorFilterTypeForRender >= QBGLFilterTypeFairytale && _colorFilterTypeForRender <= QBGLFilterTypeWalden);
    return (colorFilterTypeMagic ? self.magicFilter : self.filter);
}

- (void)setBeautyEnabled:(BOOL)beautyEnabled {
    _beautyEnabled = beautyEnabled;
}

- (void)becomeCurrentContext {
    if ([EAGLContext currentContext] != _glContext) {
        [EAGLContext setCurrentContext:_glContext];
    }
}

- (void)reloadTextureCache {
    [self becomeCurrentContext];
    
    if (_textureCacheRef) {
        CFRelease(_textureCacheRef);
    }
    
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    
    self.normalFilter.textureCacheRef = _textureCacheRef;
    self.beautyFilter.textureCacheRef = _textureCacheRef;
    self.colorFilter.textureCacheRef = _textureCacheRef;
    self.beautyColorFilter.textureCacheRef = _textureCacheRef;
    [self.magicFilterFactory preloadFiltersWithTextureCacheRef:_textureCacheRef animationView:_animationView];
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    [self reloadTextureCache];
    
    self.normalFilter.outputSize = outputSize;
    self.beautyFilter.inputSize = self.beautyFilter.outputSize = outputSize;
    self.colorFilter.inputSize = self.colorFilter.outputSize = outputSize;
    self.beautyColorFilter.inputSize = self.beautyColorFilter.outputSize = outputSize;
    
    [self.magicFilterFactory updateInputOutputSizeForFilters:outputSize];
}

- (void)setViewPortSize:(CGSize)viewPortSize {
    if (CGSizeEqualToSize(viewPortSize, _viewPortSize))
        return;
    _viewPortSize = viewPortSize;
    
    self.normalFilter.viewPortSize = viewPortSize;
    self.beautyFilter.viewPortSize = viewPortSize;
    self.colorFilter.viewPortSize = viewPortSize;
    self.beautyColorFilter.viewPortSize = viewPortSize;
    
    [self.magicFilterFactory updateViewPortSizeForFilters:viewPortSize];
}

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.inputFilter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.inputFilter loadYUV:pixelBuffer];
}

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.inputFilter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.inputFilter loadBGRA:pixelBuffer];
}

- (void)render {
    [self becomeCurrentContext];
    
    // Prefer magic filter to draw animation view texture than other filters because magic filter's z-order is upper than other filters
    BOOL hasMagicFilter = self.hasMagicFilter;
    BOOL hasMultiFilters = self.hasMultiFilters;
    self.inputFilter.enableAnimationView = (self.animationView != nil && !hasMagicFilter);
    self.inputFilter.inputRotation = self.inputRotation;
    self.inputFilter.animationRotation = QBGLImageRotationNone;
    [self.inputFilter bindDrawable];
    [self.inputFilter render];
    
    if (hasMultiFilters) {
        [self.inputFilter draw];
        GLuint textureId = self.inputFilter.outputTextureId;
        self.outputFilter.enableAnimationView = (self.animationView != nil && hasMagicFilter);
        self.outputFilter.animationRotation = QBGLImageRotationNone;
        [self.outputFilter loadTexture:textureId];
        [self.outputFilter render];
    }
}

- (void)renderToOutput {
    [self render];
    [self.outputFilter bindDrawable];
    [self.outputFilter draw];
    glFlush();
}

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror {
    if (position == AVCaptureDevicePositionBack) {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? (mirror ? QBGLImageRotationRightFlipHorizontal : QBGLImageRotationRight) :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? (mirror ? QBGLImageRotationLeftFlipHorizontal  : QBGLImageRotationLeft)  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? (mirror ? QBGLImageRotation180FlipHorizontal   : QBGLImageRotation180)   :
        orientation == UIInterfaceOrientationLandscapeRight     ? (mirror ? QBGLImageRotationFlipHorizonal       : QBGLImageRotationNone)  :
        QBGLImageRotationNone;
    } else {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? (mirror ? QBGLImageRotationRightFlipHorizontal : QBGLImageRotationRight) :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? (mirror ? QBGLImageRotationLeftFlipHorizontal  : QBGLImageRotationLeft)  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? (mirror ? QBGLImageRotationFlipHorizonal       : QBGLImageRotationNone)  :
        orientation == UIInterfaceOrientationLandscapeRight     ? (mirror ? QBGLImageRotation180FlipHorizontal   : QBGLImageRotation180)   :
        QBGLImageRotationNone;
    }
}

- (BOOL)hasMagicFilter {
    return (self.outputFilter == self.magicFilter);
}

- (BOOL)hasMultiFilters {
    return (self.outputFilter != self.inputFilter);
}

#pragma mark - Preview

- (void)setPreviewAnimationOrientationWithCameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror {
    if (position == AVCaptureDevicePositionBack) {
        _previewAnimationRotation = (mirror ? QBGLImageRotationNone : QBGLImageRotationFlipHorizonal);
    } else {
        _previewAnimationRotation = (mirror ? QBGLImageRotationFlipHorizonal : QBGLImageRotationNone);
    }
}

- (void)setPreviewDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position {
    if (position == AVCaptureDevicePositionBack) {
        _previewInputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRightFlipHorizontal :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeftFlipHorizontal  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotation180FlipHorizontal   :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotationFlipHorizonal       :
        QBGLImageRotationNone;
    } else {
        _previewInputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotationNone  :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotation180   :
        QBGLImageRotationNone;
    }
}

- (void)configInputFilterToPreview {
    [self becomeCurrentContext];
    
    // Prefer magic filter to draw animation view texture than other filters because magic filter's z-order is upper than other filters
    BOOL hasMagicFilter = self.hasMagicFilter;
    self.inputFilter.enableAnimationView = (self.animationView != nil && !hasMagicFilter);
    self.inputFilter.inputRotation = self.previewInputRotation;
    self.inputFilter.animationRotation = (hasMagicFilter ? QBGLImageRotationNone : self.previewAnimationRotation);
}

- (void)renderInputFilterToPreview {
    [self.inputFilter render];
    [self.inputFilter draw];
}

- (void)renderInputFilterToOutputFilter {
    [self.inputFilter bindDrawable];
    [self.inputFilter render];
    [self.inputFilter draw];
    
    BOOL hasMagicFilter = self.hasMagicFilter;
    self.outputFilter.enableAnimationView = (self.animationView != nil && hasMagicFilter);
    self.outputFilter.animationRotation = (hasMagicFilter ? self.previewAnimationRotation : QBGLImageRotationNone);
}

- (void)renderOutputFilterToPreview {
    GLuint textureId = self.inputFilter.outputTextureId;
    [self.outputFilter loadTexture:textureId];
    [self.outputFilter render];
    [self.outputFilter draw];
}

@end
