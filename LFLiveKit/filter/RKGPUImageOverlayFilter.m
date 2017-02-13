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
 
 lowp float overlayCal(lowp float a, lowp float b) {
     if (b < 0.5) {
         return 2.0 * a * b;
     } else {
         return 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
     }
 }
 
 void main() {
     lowp vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     lowp vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     lowp vec3 result = vec3(overlayCal(textureColor.r, imageColor.r),
                             overlayCal(textureColor.g, imageColor.g),
                             overlayCal(textureColor.b, imageColor.b));
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
);
#else
NSString *const kRKGPUImageOverlayFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2; // TODO: This is not used
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; // lookup texture
 
 float overlayCal(float a, float b) {
     if (b < 0.5) {
         return 2.0 * a * b;
     } else {
         return 1.0 - 2.0 * (1.0 - a) * (1.0 - b);
     }
 }
 
 void main() {
     vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec3 imageColor = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     vec3 result = vec3(overlayCal(textureColor.r, imageColor.r),
                        overlayCal(textureColor.g, imageColor.g),
                        overlayCal(textureColor.b, imageColor.b));
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
