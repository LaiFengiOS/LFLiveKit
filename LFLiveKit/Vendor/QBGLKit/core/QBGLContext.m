//
//  QBGLContext.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLContext.h"
#import "QBGLFilter.h"
#import "QBGLFilterFactory.h"
#import "QBGLProgram.h"
#import "QBGLUtils.h"
#import "QBGLBeautyFilter.h"
#import "QBGLBeautyColorMapFilter.h"

@interface QBGLContext ()

@property (nonatomic, readonly) QBGLFilter *filter;

@property (strong, nonatomic) QBGLFilter *normalFilter;
@property (strong, nonatomic) QBGLBeautyFilter *beautyFilter;
@property (strong, nonatomic) QBGLColorMapFilter *colorFilter;
@property (strong, nonatomic) QBGLBeautyColorMapFilter *beautyColorFilter;

@property (nonatomic) GLuint outputFrameBuffer;
@property (nonatomic) GLuint outputTextureId;

@property (nonatomic) CVOpenGLESTextureCacheRef textureCacheRef;

@end

@implementation QBGLContext

- (instancetype)init {
    if (self = [super init]) {
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [self becomeCurrentContext];
        CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    }
    return self;
}

- (void)dealloc {
    [self becomeCurrentContext];
    [self unloadOutputBuffer];
    CFRelease(_textureCacheRef);
    
    [EAGLContext setCurrentContext:nil];
}

- (QBGLFilter *)normalFilter {
    if (!_normalFilter) {
        _normalFilter = [[QBGLFilter alloc] init];
    }
    return _normalFilter;
}

- (QBGLBeautyFilter *)beautyFilter {
    if (!_beautyFilter) {
        _beautyFilter = [[QBGLBeautyFilter alloc] init];
    }
    return _beautyFilter;
}

- (QBGLColorMapFilter *)colorFilter {
    if (!_colorFilter) {
        _colorFilter = [[QBGLColorMapFilter alloc] init];
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
    }
    if (_beautyColorFilter.type != _colorFilterType) {
        [QBGLFilterFactory refactorColorFilter:_beautyColorFilter withType:_colorFilterType];
        _beautyColorFilter.type = _colorFilterType;
    }
    return _beautyColorFilter;
}

- (QBGLFilter *)filter {
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

- (void)setBeautyEnabled:(BOOL)beautyEnabled {
    _beautyEnabled = beautyEnabled;
}

- (void)becomeCurrentContext {
    [EAGLContext setCurrentContext:_glContext];
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, _outputSize))
        return;
    _outputSize = outputSize;
    
    [self unloadOutputBuffer];
    [self loadOutputBuffer];
}

- (void)loadOutputBuffer {
    NSDictionary* attrs = @{(__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    CVPixelBufferCreate(kCFAllocatorDefault, _outputSize.width, _outputSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attrs, &_outputPixelBuffer);
    
    CVOpenGLESTextureRef outputTextureRef;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 _textureCacheRef,
                                                 _outputPixelBuffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA,
                                                 _outputSize.width,
                                                 _outputSize.height,
                                                 GL_BGRA,
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &outputTextureRef);
    _outputTextureId = CVOpenGLESTextureGetName(outputTextureRef);
    [QBGLUtils bindTexture:_outputTextureId];
    CFRelease(outputTextureRef);
    
    // create output frame buffer
    glGenFramebuffers(1, &_outputFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outputTextureId, 0);
}

- (void)unloadOutputBuffer {
    if (_outputTextureId) {
        glDeleteTextures(1, &_outputTextureId);
    }
    if (_outputPixelBuffer) {
        CFRelease(_outputPixelBuffer);
    }
    if (_outputFrameBuffer) {
        glDeleteFramebuffers(1, &_outputFrameBuffer);
    }
}

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.filter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.filter loadYUV:pixelBuffer textureCache:_textureCacheRef];
}

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    self.filter.inputSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    [self.filter loadBGRA:pixelBuffer textureCache:_textureCacheRef];
}

- (void)render {
    [self becomeCurrentContext];
    [self.filter render];
    [self draw];
}

- (void)renderToOutput {
    [self becomeCurrentContext];
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    [self.filter render];
    [self draw];
}

- (void)draw {
    glActiveTexture(GL_TEXTURE0);
    glViewport(0, 0, _viewPortSize.width, _viewPortSize.height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)setRotation:(float)degrees flipHorizontal:(BOOL)flip {
    [self becomeCurrentContext];
    
    GLKMatrix4 matrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(degrees));
    if (flip) {
        matrix = GLKMatrix4Multiply(matrix, GLKMatrix4MakeScale(-1.0, 1.0, 1.0));
    }
    glUniformMatrix4fv([self.normalFilter.program uniformWithName:"transformMatrix"], 1, false, matrix.m);
    glUniformMatrix4fv([self.beautyFilter.program uniformWithName:"transformMatrix"], 1, false, matrix.m);
    glUniformMatrix4fv([self.colorFilter.program uniformWithName:"transformMatrix"], 1, false, matrix.m);
    glUniformMatrix4fv([self.beautyColorFilter.program uniformWithName:"transformMatrix"], 1, false, matrix.m);
}

@end
