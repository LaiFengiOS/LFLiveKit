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
         rColor = 2.*textureColor.r*imageColor.r;
     } else {
         rColor = 1.-2.*(1.-textureColor.r)*(1.-imageColor.r);
     }
     
     if (imageColor.g < 0.5) {
         gColor = 2.*textureColor.g*imageColor.g;
     } else {
         gColor = 1.-2.*(1.-textureColor.g)*(1.-imageColor.g);
     }
     
     if (imageColor.b < 0.5) {
         bColor = 2.*textureColor.b*imageColor.b;
     } else {
         bColor = 1.-2.*(1.-textureColor.b)*(1.-imageColor.b);
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
 
 vec3 applyColorMap(vec3 inputTexture, sampler2D colorMap) {
     float size = 33.0;
     
     float sliceSize = 1.0 / size;
     float slicePixelSize = sliceSize / size;
     float sliceInnerSize = slicePixelSize * (size - 1.0);
     float xOffset = 0.5 * sliceSize + inputTexture.x * (1.0 - sliceSize);
     float yOffset = 0.5 * slicePixelSize + inputTexture.y * sliceInnerSize;
     float zOffset = inputTexture.z * (size - 1.0);
     float zSlice0 = floor(zOffset);
     float zSlice1 = zSlice0 + 1.0;
     float s0 = yOffset + (zSlice0 * sliceSize);
     float s1 = yOffset + (zSlice1 * sliceSize);
     vec4 sliceColor0 = texture2D(colorMap, vec2(xOffset, s0));
     vec4 sliceColor1 = texture2D(colorMap, vec2(xOffset, s1));
     
     return mix(sliceColor0, sliceColor1, zOffset - zSlice0).rgb;
 }
 
 void main(){
     vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec3 result = applyColorMap(textureColor, inputImageTexture2);
     result = clamp(result, 0.0, 1.0);
     gl_FragColor = vec4(result, 1.0);
 }
 );
#endif

@implementation RKGPUImageOverlayFilter

- (instancetype)init; {
    if (!(self = [super initWithFragmentShaderFromString:kRKGPUImageOverlayFragmentShaderString])) {
        return nil;
    }
    
    return self;
}

@end
