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

@interface QBGLContext ()

@property (nonatomic, readonly) QBGLYuvFilter *filter;

@property (nonatomic, readonly) QBGLYuvFilter *inputFilter;
@property (nonatomic, readonly) QBGLFilter *outputFilter;

@property (strong, nonatomic) QBGLYuvFilter *normalFilter;
@property (strong, nonatomic) QBGLBeautyFilter *beautyFilter;
@property (strong, nonatomic) QBGLColorMapFilter *colorFilter;
@property (strong, nonatomic) QBGLBeautyColorMapFilter *beautyColorFilter;

@property (strong, nonatomic) QBGLFilter *magicFilter;

@property (nonatomic) QBGLImageRotation inputRotation;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;

@end

@implementation QBGLContext

- (instancetype)init {
    return [self initWithContext:nil];
}

- (instancetype)initWithContext:(EAGLContext *)context {
    if (context.API == kEAGLRenderingAPIOpenGLES1)
        @throw [NSException exceptionWithName:@"QBGLContext init error" reason:@"GL context  can't be kEAGLRenderingAPIOpenGLES1" userInfo:nil];
    if (self = [super init]) {
        _glContext = context ?: [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];;
        [self becomeCurrentContext];
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    }
    return self;
}

- (void)dealloc {
    [self becomeCurrentContext];
    CFRelease(_textureCacheRef);
    
    [EAGLContext setCurrentContext:nil];
}

- (CVPixelBufferRef)outputPixelBuffer {
    return self.outputFilter.outputPixelBuffer;
}

- (QBGLYuvFilter *)normalFilter {
    if (!_normalFilter) {
        _normalFilter = [[QBGLYuvFilter alloc] init];
        _normalFilter.textureCacheRef = _textureCacheRef;
    }
    return _normalFilter;
}

- (QBGLBeautyFilter *)beautyFilter {
    if (!_beautyFilter) {
        _beautyFilter = [[QBGLBeautyFilter alloc] init];
        _beautyFilter.textureCacheRef = _textureCacheRef;
    }
    return _beautyFilter;
}

- (QBGLColorMapFilter *)colorFilter {
    if (!_colorFilter) {
        _colorFilter = [[QBGLColorMapFilter alloc] init];
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
        _beautyColorFilter = [[QBGLBeautyColorMapFilter alloc] init];
        _beautyColorFilter.textureCacheRef = _textureCacheRef;
    }
    if (_beautyColorFilter.type != _colorFilterType) {
        [QBGLFilterFactory refactorColorFilter:_beautyColorFilter withType:_colorFilterType];
        _beautyColorFilter.type = _colorFilterType;
    }
    return _beautyColorFilter;
}

- (QBGLYuvFilter *)filter {
    if (_beautyEnabled && _colorFilterType != QBGLFilterTypeNone) {
        return self.beautyColorFilter;
    } else if (_beautyEnabled && _colorFilterType == QBGLFilterTypeNone) {
        return self.beautyFilter;
    } else if (!_beautyEnabled && _colorFilterType != QBGLFilterTypeNone) {
        return self.colorFilter;
    } else {
        return self.normalFilter;
    }
}

- (QBGLYuvFilter *)inputFilter {
    return self.filter;
}

- (QBGLFilter *)outputFilter {
    //return self.magicFilter;
    return self.filter;
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
    
    self.inputFilter.inputRotation = _inputRotation;
    [self.inputFilter render];
    
    if (self.outputFilter != self.inputFilter) {
        [self.inputFilter bindDrawable];
        [self.inputFilter draw];
        GLuint textureId = self.inputFilter.outputTextureId;
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
