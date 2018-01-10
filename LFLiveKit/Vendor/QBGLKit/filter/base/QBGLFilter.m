//
//  QBGLFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"

char * const kQBNoFilterVertex;
char * const kQBNoFilterFragment;

@interface QBGLFilter ()

@property (nonatomic) int attrPosition;
@property (nonatomic) int attrInputTextureCoordinate;

@property (strong, nonatomic) QBGLDrawable *inputImageDrawable;
@property (strong, nonatomic) QBGLDrawable *yDrawable;
@property (strong, nonatomic) QBGLDrawable *uvDrawable;

@end

@implementation QBGLFilter

- (instancetype)init {
    return [self initWithVertexShader:kQBNoFilterVertex fragmentShader:kQBNoFilterFragment];
}

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader {
    if (self = [super init]) {
        _program = [[QBGLProgram alloc] initWithVertexShader:vertexShader fragmentShader:fragmentShader];
        _attrPosition = [_program attributeWithName:"position"];
        _attrInputTextureCoordinate = [_program attributeWithName:"inputTextureCoordinate"];
    }
    return self;
}

- (void)dealloc {
    [self deleteTextures];
}

- (void)loadTextures {
    
}

- (void)deleteTextures {
    for (QBGLDrawable *drawable in [self renderTextures]) {
        [drawable deleteTexture];
    }
}

- (void)loadBGRA:(CVPixelBufferRef)pixelBuffer textureCache:(CVOpenGLESTextureCacheRef)textureCacheRef {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CVOpenGLESTextureRef imageTextureRef;
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                 textureCacheRef,
                                                 pixelBuffer,
                                                 NULL,
                                                 GL_TEXTURE_2D,
                                                 GL_RGBA,
                                                 width,
                                                 height,
                                                 GL_BGRA,
                                                 GL_UNSIGNED_BYTE,
                                                 0,
                                                 &imageTextureRef);
    _inputImageDrawable = [[QBGLDrawable alloc] initWithTextureRef:imageTextureRef identifier:@"inputImageTexture"];
    CFRelease(imageTextureRef);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer textureCache:(CVOpenGLESTextureCacheRef)textureCacheRef {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CVOpenGLESTextureRef luminanceTextureRef, chrominanceTextureRef;
    
    // y texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, width, height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    
    _yDrawable = [[QBGLDrawable alloc] initWithTextureRef:luminanceTextureRef identifier:@"yTexture"];
    
    // uv texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, width/2, height/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    
    _uvDrawable = [[QBGLDrawable alloc] initWithTextureRef:chrominanceTextureRef identifier:@"uvTexture"];
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (GLuint)render {
    [_program use];
    [_program enableAttributeWithId:_attrPosition];
    [_program enableAttributeWithId:_attrInputTextureCoordinate];
    
    glVertexAttribPointer(_attrPosition, 2, GL_FLOAT, 0, 0, squareVertices);
    glVertexAttribPointer(_attrInputTextureCoordinate, 2, GL_FLOAT, 0, 0, squareTextureCoordinates);
    
    GLuint index = 0;
    if (_inputImageDrawable) {
        index = [_inputImageDrawable prepareToDrawAtTextureIndex:index program:_program];
    }
    if (_yDrawable) {
        index = [_yDrawable prepareToDrawAtTextureIndex:index program:_program];
    }
    if (_uvDrawable) {
        index = [_uvDrawable prepareToDrawAtTextureIndex:index program:_program];
    }
    for (QBGLDrawable *drawable in [self renderTextures]) {
        index = [drawable prepareToDrawAtTextureIndex:index program:_program];
    }
    return index;
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return nil;
}

@end

char * const kQBNoFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform mat4 transformMatrix;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position * transformMatrix;
     textureCoordinate = inputTextureCoordinate.xy;
 }
);

char * const kQBNoFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 vec3 rgbFromYuv(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 void main()
 {
     vec3 centralColor = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     gl_FragColor = vec4(centralColor, 1.0);
 }
);


