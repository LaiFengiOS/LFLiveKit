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
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (self.yDrawable && self.uvDrawable ) {
        [array addObject:self.yDrawable];
        [array addObject:self.uvDrawable];
    }
    return [array copy];
}

@end


char * const kQBGLYuvFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 attribute vec4 inputAnimationCoordinate;
 varying vec2 animationCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     animationCoordinate = inputAnimationCoordinate.xy;
 }
 );

char * const kQBGLYuvFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 varying highp vec2 animationCoordinate;
 uniform sampler2D animationTexture;
 uniform int enableAnimationView;
 
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
     vec4 animationColor = texture2D(animationTexture, animationCoordinate);
     if (enableAnimationView == 1) {
         gl_FragColor = vec4(mix(centralColor, animationColor.rgb, animationColor.a), 1.0);
     } else {
         gl_FragColor = vec4(centralColor, 1.0);
     }
 }
 );
