//
//  RKGUPImageSoftLightFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/13.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGUPImageSoftLightFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kRKGPUImageSoftLightFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 lowp float softLightCal(lowp float a, lowp float b) {
     if (b < 0.5) {
         return 2.0 * a * b + a * a * (1.0 - 2.0 * b);
     } else {
         return 2.0 * a * (1.0 - b) + sqrt(a) * (2.0 * b - 1.0);
     }
 }
 
 void main() {
     lowp vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     lowp vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;

     lowp vec3 result = vec3(softLightCal(textureColor.r, imageColor.r),
                             softLightCal(textureColor.g, imageColor.g),
                             softLightCal(textureColor.b, imageColor.b));
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
);
#else
NSString *const kRKGPUImageSoftLightFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 float softLightCal(float a, float b) {
     if (b < 0.5) {
         return 2.0 * a * b + a * a * (1.0 - 2.0 * b);
     } else {
         return 2.0 * a * (1.0 - b) + sqrt(a) * (2.0 * b - 1.0);
     }
 }
 
 void main() {
     vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     vec3 result = vec3(softLightCal(textureColor.r, imageColor.r),
                        softLightCal(textureColor.g, imageColor.g),
                        softLightCal(textureColor.b, imageColor.b));
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
);
#endif

@implementation RKGUPImageSoftLightFilter

- (instancetype)init {
    if (!(self = [super initWithFragmentShaderFromString:kRKGPUImageSoftLightFragmentShaderString])) {
        return nil;
    }
    
    return self;
}

@end
