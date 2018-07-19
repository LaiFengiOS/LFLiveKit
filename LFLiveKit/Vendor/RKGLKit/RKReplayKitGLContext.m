//
//  RKReplayKitGLContext.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKReplayKitGLContext.h"
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/glext.h>
#import "RKGLProgram.h"

static GLfloat const squareVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

static GLfloat const squareTextureCoordinates[] = {
    0.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
};

static char * const kAttrPosition       = "position";
static char * const kAttrInputTexCoord  = "inputTextureCoordinate";
static char * const kUniTransformMat    = "transformMatrix";

@interface RKReplayKitGLContext ()

@property (strong, nonatomic) EAGLContext *glContext;

@property (strong, nonatomic) RKGLProgram *program;

@property (assign, nonatomic) GLuint outputTexture;
@property (assign, nonatomic) GLuint outputFrameBuffer;
@property (assign, nonatomic) GLuint yTextureId;
@property (assign, nonatomic) GLuint uvTextureId;
@property (assign, nonatomic) CVOpenGLESTextureCacheRef glTextureCacheRef;
@property (assign, nonatomic) CVPixelBufferRef outputPixelBufferRef;
@property (assign, nonatomic) CVOpenGLESTextureRef glOutputTextureRef;

@property (assign, nonatomic) int positionAttribute;
@property (assign, nonatomic) int inputTextureCoordinateAttribute;

@end

@implementation RKReplayKitGLContext

- (instancetype)initWithCanvasSize:(CGSize)canvasSize {
    if (self = [super init]) {
        _canvasSize = canvasSize;
        
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        [EAGLContext setCurrentContext:_glContext];
        
        [self prepareOutputBuffer];
        [self loadProgram];
        [self setRotation:0.0];
    }
    return self;
}

- (void)prepareOutputBuffer {
    NSDictionary* attrs = @{(__bridge NSString*) kCVPixelBufferIOSurfacePropertiesKey: @{}};
    
    CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_glTextureCacheRef);
    CVPixelBufferCreate(kCFAllocatorDefault, _canvasSize.width, _canvasSize.height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef) attrs, &_outputPixelBufferRef);
    
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _glTextureCacheRef, _outputPixelBufferRef, NULL, GL_TEXTURE_2D, GL_RGBA, _canvasSize.width, _canvasSize.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &_glOutputTextureRef);
    _outputTexture = CVOpenGLESTextureGetName(_glOutputTextureRef);
    
    [self bindTexture:_outputTexture];
    
    // create output frame buffer
    glGenFramebuffers(1, &_outputFrameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outputTexture, 0);
}

- (void)loadProgram {
    _program = [[RKGLProgram alloc] init];
    [_program link];
    [_program use];
    
    // enable vertex attribute array
    _positionAttribute = [_program enableAttributeWithName:kAttrPosition];
    _inputTextureCoordinateAttribute = [_program enableAttributeWithName:kAttrInputTexCoord];
}

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    [self becomeCurrentContext];
    
    int pixelBufferWidth = (int) CVPixelBufferGetWidth(pixelBuffer);
    int pixelBufferHeight = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CVOpenGLESTextureRef luminanceTextureRef, chrominanceTextureRef;
    
    // y texture
    //
    glActiveTexture(GL_TEXTURE2);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _glTextureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, pixelBufferWidth, pixelBufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    
    _yTextureId = CVOpenGLESTextureGetName(luminanceTextureRef);
    [self bindTexture:_yTextureId];
    
    // uv texture
    //
    glActiveTexture(GL_TEXTURE3);
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _glTextureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, pixelBufferWidth/2, pixelBufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    
    _uvTextureId = CVOpenGLESTextureGetName(chrominanceTextureRef);
    [self bindTexture:_uvTextureId];
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)render {
    [self becomeCurrentProgram];
    
    [_program enableAttributeWithId:_positionAttribute];
    [_program enableAttributeWithId:_inputTextureCoordinateAttribute];
    
    glVertexAttribPointer(_positionAttribute, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_inputTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, squareTextureCoordinates);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _outputFrameBuffer);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, _yTextureId);
    glUniform1i([_program uniformWithName:"yTexture"], 2);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, _uvTextureId);
    glUniform1i([_program uniformWithName:"uvTexture"], 3);
    
    glViewport(0, 0, _canvasSize.width, _canvasSize.height);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    glFinish();
}

- (void)setRotation:(float)degrees {
    [self becomeCurrentProgram];
    
    GLKMatrix4 matrix = GLKMatrix4MakeZRotation(GLKMathDegreesToRadians(degrees));
    glUniformMatrix4fv([_program uniformWithName:kUniTransformMat], 1, false, matrix.m);
}

- (CVPixelBufferRef)outputPixelBuffer {
    return _outputPixelBufferRef;
}


#pragma mark - Utils

- (GLuint)generateTexture {
    GLuint texture = 0;
    
    glGenTextures(1, &texture);
    [self bindTexture:texture];
    
    return texture;
}

- (void)bindTexture:(GLuint)textureId {
    glBindTexture(GL_TEXTURE_2D, textureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)becomeCurrentContext {
    if ([EAGLContext currentContext] != _glContext) {
        [EAGLContext setCurrentContext:_glContext];
    }
}

- (void)becomeCurrentProgram {
    [self becomeCurrentContext];
    [_program use];
}

@end
