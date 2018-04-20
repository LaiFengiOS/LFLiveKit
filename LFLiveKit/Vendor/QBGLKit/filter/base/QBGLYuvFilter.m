//
//  QBGLYuvFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLYuvFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char * const kQBGLYuvFilterVertex;
char * const kQBGLYuvFilterFragment;

@interface QBGLYuvFilter ()

@property (strong, nonatomic) QBGLDrawable *yDrawable;
@property (strong, nonatomic) QBGLDrawable *uvDrawable;

@end

@implementation QBGLYuvFilter

- (instancetype)init {
    return [self initWithVertexShader:kQBGLYuvFilterVertex fragmentShader:kQBGLYuvFilterFragment];
}

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CVOpenGLESTextureRef luminanceTextureRef, chrominanceTextureRef;
    
    // y texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, width, height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    
    _yDrawable = [[QBGLDrawable alloc] initWithTextureRef:luminanceTextureRef identifier:@"yTexture"];
    
    // uv texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, width/2, height/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    
    _uvDrawable = [[QBGLDrawable alloc] initWithTextureRef:chrominanceTextureRef identifier:@"uvTexture"];
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return _yDrawable && _uvDrawable ? @[_yDrawable, _uvDrawable] : nil;
}

@end

char * const kQBGLYuvFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

char * const kQBGLYuvFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
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
