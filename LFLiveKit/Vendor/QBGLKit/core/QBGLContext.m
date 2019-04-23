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
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
        // workaround: prevent screen flash when switching to magic filters
        [self.magicFilterFactory preloadFiltersWithTextureCacheRef:_textureCacheRef animationView:animationView];
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
    if (_colorFilter.type != _colorFilterType) {
        [QBGLFilterFactory refactorColorFilter:_colorFilter withType:_colorFilterType];
        _colorFilter.type = _colorFilterType;
    }
    return _colorFilter;
}

- (QBGLBeautyColorMapFilter *)beautyColorFilter {
    if (!_beautyColorFilter) {
        _beautyColorFilter = [[QBGLBeautyColorMapFilter alloc] initWithAnimationView:self.animationView];
        _beautyColorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_beautyColorFilter.type != _colorFilterType) {
        [QBGLFilterFactory refactorColorFilter:_beautyColorFilter withType:_colorFilterType];
        _beautyColorFilter.type = _colorFilterType;
    }
    return _beautyColorFilter;
}

- (QBGLMagicFilterBase *)magicFilter {
    if (!_magicFilter || (_colorFilterType != QBGLFilterTypeNone && _magicFilter.type != _colorFilterType)) {
        _magicFilter = [self.magicFilterFactory filterWithType:_colorFilterType animationView:self.animationView];
    }
    return _magicFilter;
}

- (QBGLYuvFilter *)filter {
    BOOL colorFilterType17 = (_colorFilterType > QBGLFilterTypeNone && _colorFilterType < QBGLFilterTypeCrayon);
    if (_beautyEnabled && _colorFilterType != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.beautyColorFilter : self.beautyFilter);
    } else if (_beautyEnabled && _colorFilterType == QBGLFilterTypeNone) {
        return self.beautyFilter;
    } else if (!_beautyEnabled && _colorFilterType != QBGLFilterTypeNone) {
        return (colorFilterType17 ? self.colorFilter : self.normalFilter);
    } else {
        return self.normalFilter;
    }
}

- (QBGLYuvFilter *)inputFilter {
    return self.filter;
}

- (QBGLFilter *)outputFilter {
    BOOL colorFilterTypeMagic = (_colorFilterType >= QBGLFilterTypeCrayon && _colorFilterType <= QBGLFilterTypeWalden);
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

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    self.normalFilter.outputSize = outputSize;
    self.beautyFilter.inputSize = self.beautyFilter.outputSize = outputSize;
    self.colorFilter.inputSize = self.colorFilter.outputSize = outputSize;
    self.beautyColorFilter.inputSize = self.beautyColorFilter.outputSize = outputSize;
    
    [self.magicFilterFactory updateInputOutputSizeForFilters:outputSize];
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
    BOOL hasMagicFilter = (self.outputFilter == self.magicFilter);
    self.inputFilter.enableAnimationView = (self.animationView != nil && !hasMagicFilter);
    self.inputFilter.inputRotation = _inputRotation;
    [self.inputFilter render];
    
    if (self.outputFilter != self.inputFilter) {
        [self.inputFilter bindDrawable];
        [self.inputFilter draw];
        GLuint textureId = self.inputFilter.outputTextureId;
        self.outputFilter.enableAnimationView = (self.animationView != nil && hasMagicFilter);
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

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position {
    if (position == AVCaptureDevicePositionBack) {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotation180   : QBGLImageRotationNone;
    } else {
        _inputRotation =
        orientation == UIInterfaceOrientationPortrait           ? QBGLImageRotationRight :
        orientation == UIInterfaceOrientationPortraitUpsideDown ? QBGLImageRotationLeft  :
        orientation == UIInterfaceOrientationLandscapeLeft      ? QBGLImageRotationNone  :
        orientation == UIInterfaceOrientationLandscapeRight     ? QBGLImageRotation180   : QBGLImageRotationNone;
    }
}

@end
