//
//  RKGPUImageOverlayFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/13.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageOverlayFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kRKGPUImageOverlayFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 void main(){
     lowp vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     lowp vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     lowp float rColor;
     lowp float gColor;
     lowp float bColor;
     if (imageColor.r < 0.5) {
         rColor = 2.0 * textureColor.r * imageColor.r;
     } else {
         rColor = 1.0 - 2.0 * (1.0 - textureColor.r) * (1.0 - imageColor.r);
     }
     
     if (imageColor.g < 0.5) {
         gColor = 2.0 * textureColor.g * imageColor.g;
     } else {
         gColor = 1.0 - 2.0 * (1.0 - textureColor.g) * (1.0 - imageColor.g);
     }
     
     if (imageColor.b < 0.5) {
         bColor = 2.0 * textureColor.b * imageColor.b;
     } else {
         bColor = 1.0 - 2.0 * (1.0 - textureColor.b) * (1.0 - imageColor.b);
     }
     
     lowp vec3 result = vec3(rColor, gColor, bColor);
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
);
#else
NSString *const kGPUImageInvertFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 void main(){
     vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     float rColor;
     float gColor;
     float bColor;
     if (imageColor.r < 0.5) {
         rColor = 2.0 * textureColor.r * imageColor.r;
     } else {
         rColor = 1.0 - 2.0 * (1.0 - textureColor.r) * (1.0 - imageColor.r);
     }
     
     if (imageColor.g < 0.5) {
         gColor = 2.0 * textureColor.g * imageColor.g;
     } else {
         gColor = 1.0 - 2.0 * (1.0 - textureColor.g) * (1.0 - imageColor.g);
     }
     
     if (imageColor.b < 0.5) {
         bColor = 2.0 * textureColor.b * imageColor.b;
     } else {
         bColor = 1.0 - 2.0 * (1.0 - textureColor.b) * (1.0 - imageColor.b);
     }
     
     vec3 result = vec3(rColor, gColor, bColor);
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
);
#endif

@implementation RKGPUImageOverlayFilter

- (instancetype)init {
    if (!(self = [super initWithFragmentShaderFromString:kRKGPUImageOverlayFragmentShaderString])) {
        return nil;
    }
    
    return self;
}

@end
