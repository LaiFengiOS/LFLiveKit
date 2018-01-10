//
//  QBGLBeautyFilter.m
//  Qubi
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 Qubi. All rights reserved.
//

#import "QBGLBeautyFilter.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char *const kQBBeautyFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform mat4 transformMatrix;
 uniform float sharpness;
 
 uniform vec2 singleStepOffset;
 //varying vec2 blurCoordinates[24];
 varying vec2 sharpCoordinates[4];
 
 varying vec2 textureCoordinate;
 
 varying float sharpCenterMultiplier;
 varying float sharpEdgeMultiplier;
 
 void main() {
     gl_Position = position * transformMatrix;
     
     textureCoordinate = inputTextureCoordinate.xy;
     
//     blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
//     blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
//     blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
//     blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
//     blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
//     blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
//     blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
//     blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
//     blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
//     blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
//     blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
//     blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
//     blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
//     blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
//     blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
//     blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
//     blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
//     blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
//     blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
//     blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
//     blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
//     blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
//     blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
//     blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);
     
     sharpCoordinates[0] = inputTextureCoordinate.xy - vec2(singleStepOffset.x, 0.0);
     sharpCoordinates[1] = inputTextureCoordinate.xy + vec2(singleStepOffset.x, 0.0);
     sharpCoordinates[2] = inputTextureCoordinate.xy + vec2(0.0, singleStepOffset.y);
     sharpCoordinates[3] = inputTextureCoordinate.xy - vec2(0.0, singleStepOffset.y);
     
     sharpCenterMultiplier = 1.0 + 4.0 * sharpness;
     sharpEdgeMultiplier = sharpness;
 }
);


char * const kQBBeautyFilterFragment = STRING
(
 precision highp float;
 
 varying vec2 textureCoordinate;
 vec2 blurCoordinates[24];
 varying vec2 sharpCoordinates[4];
 
 uniform vec2 singleStepOffset;
 uniform vec4 params;
 
 uniform lowp float temperature;
 uniform lowp float tint;
 uniform highp float beta;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 varying highp float sharpCenterMultiplier;
 varying highp float sharpEdgeMultiplier;
 
 const vec3 W = vec3(0.299, 0.587, 0.114);
 const mat3 saturateMatrix = mat3(1.1102, -0.0598, -0.061,
                                  -0.0774, 1.0826, -0.1186,
                                  -0.0228, -0.0228, 1.1772);
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 const lowp vec3 warmFilter = vec3(0.93, 0.54, 0.0);
 const mediump mat3 RGBtoYIQ = mat3(0.299, 0.587, 0.114, 0.596, -0.274, -0.322, 0.212, -0.523, 0.311);
 const mediump mat3 YIQtoRGB = mat3(1.0, 0.956, 0.621, 1.0, -0.272, -0.647, 1.0, -1.105, 1.702);
 
 vec3 rgbFromYuv(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 float hardLight(float color) {
     if (color <= 0.5)
         color = color * color * 2.0;
     else
         color = 1.0 - ((1.0 - color)*(1.0 - color) * 2.0);
     return color;
 }
 
 void main(){
     vec3 centralColor = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     blurCoordinates[0] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -10.0);
     blurCoordinates[1] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 10.0);
     blurCoordinates[2] = textureCoordinate.xy + singleStepOffset * vec2(-10.0, 0.0);
     blurCoordinates[3] = textureCoordinate.xy + singleStepOffset * vec2(10.0, 0.0);
     blurCoordinates[4] = textureCoordinate.xy + singleStepOffset * vec2(5.0, -8.0);
     blurCoordinates[5] = textureCoordinate.xy + singleStepOffset * vec2(5.0, 8.0);
     blurCoordinates[6] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, 8.0);
     blurCoordinates[7] = textureCoordinate.xy + singleStepOffset * vec2(-5.0, -8.0);
     blurCoordinates[8] = textureCoordinate.xy + singleStepOffset * vec2(8.0, -5.0);
     blurCoordinates[9] = textureCoordinate.xy + singleStepOffset * vec2(8.0, 5.0);
     blurCoordinates[10] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, 5.0);
     blurCoordinates[11] = textureCoordinate.xy + singleStepOffset * vec2(-8.0, -5.0);
     blurCoordinates[12] = textureCoordinate.xy + singleStepOffset * vec2(0.0, -6.0);
     blurCoordinates[13] = textureCoordinate.xy + singleStepOffset * vec2(0.0, 6.0);
     blurCoordinates[14] = textureCoordinate.xy + singleStepOffset * vec2(6.0, 0.0);
     blurCoordinates[15] = textureCoordinate.xy + singleStepOffset * vec2(-6.0, 0.0);
     blurCoordinates[16] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, -4.0);
     blurCoordinates[17] = textureCoordinate.xy + singleStepOffset * vec2(-4.0, 4.0);
     blurCoordinates[18] = textureCoordinate.xy + singleStepOffset * vec2(4.0, -4.0);
     blurCoordinates[19] = textureCoordinate.xy + singleStepOffset * vec2(4.0, 4.0);
     blurCoordinates[20] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, -2.0);
     blurCoordinates[21] = textureCoordinate.xy + singleStepOffset * vec2(-2.0, 2.0);
     blurCoordinates[22] = textureCoordinate.xy + singleStepOffset * vec2(2.0, -2.0);
     blurCoordinates[23] = textureCoordinate.xy + singleStepOffset * vec2(2.0, 2.0);
     
     float sampleColor = centralColor.g * 22.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[0]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[1]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[2]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[3]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[4]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[5]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[6]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[7]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[8]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[9]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[10]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[11]).g;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[12]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[13]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[14]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[15]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[16]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[17]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[18]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[19]).g * 2.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[20]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[21]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[22]).g * 3.0;
     sampleColor += rgbFromYuv(yTexture, uvTexture, blurCoordinates[23]).g * 3.0;
     
     sampleColor = sampleColor / 62.0;
     
     float highPass = centralColor.g - sampleColor + 0.5;
     
     for (int i = 0; i < 5; i++) {
         highPass = hardLight(highPass);
     }
     float lumance = dot(centralColor, W);
     
     float alpha = pow(lumance, params.r);
     
     vec3 smoothColor = centralColor + (centralColor-vec3(highPass))*alpha*0.1;
     
     smoothColor.r = clamp(pow(smoothColor.r, params.g), 0.0, 1.0);
     smoothColor.g = clamp(pow(smoothColor.g, params.g), 0.0, 1.0);
     smoothColor.b = clamp(pow(smoothColor.b, params.g), 0.0, 1.0);
     
     // 濾色 Screen
     vec3 lvse = vec3(1.0)-(vec3(1.0)-smoothColor)*(vec3(1.0)-centralColor);
     // 變亮 Lighten
     vec3 bianliang = max(smoothColor, centralColor);
     // 柔光 SoftLight
     vec3 rouguang = 2.0*centralColor*smoothColor + centralColor*centralColor - 2.0*centralColor*centralColor*smoothColor;
     
     vec3 beautyColor = mix(centralColor, lvse, alpha);
     beautyColor = mix(beautyColor, bianliang, alpha);
     beautyColor = mix(beautyColor, rouguang, params.b);
     
     // 調節飽和度
     vec3 satcolor = beautyColor * saturateMatrix;
     beautyColor = mix(beautyColor, satcolor, params.a);
     
     // 銳化
     vec3 sharpenColor = beautyColor * sharpCenterMultiplier;
     sharpenColor -= rgbFromYuv(yTexture, uvTexture, sharpCoordinates[0]) * sharpEdgeMultiplier;
     sharpenColor -= rgbFromYuv(yTexture, uvTexture, sharpCoordinates[1]) * sharpEdgeMultiplier;
     sharpenColor -= rgbFromYuv(yTexture, uvTexture, sharpCoordinates[2]) * sharpEdgeMultiplier;
     sharpenColor -= rgbFromYuv(yTexture, uvTexture, sharpCoordinates[3]) * sharpEdgeMultiplier;
     
     // 白平衡
//     mediump vec3 yiq = RGBtoYIQ * sharpenColor; //adjusting tint
//     yiq.b = clamp(yiq.b + tint*0.5226*0.1, -0.5226, 0.5226);
//     lowp vec3 rgb = YIQtoRGB * yiq;
//
//     lowp vec3 processed = vec3(
//                                (rgb.r < 0.5 ? (2.0 * rgb.r * warmFilter.r) : (1.0 - 2.0 * (1.0 - rgb.r) * (1.0 - warmFilter.r))), //adjusting temperature
//                                (rgb.g < 0.5 ? (2.0 * rgb.g * warmFilter.g) : (1.0 - 2.0 * (1.0 - rgb.g) * (1.0 - warmFilter.g))),
//                                (rgb.b < 0.5 ? (2.0 * rgb.b * warmFilter.b) : (1.0 - 2.0 * (1.0 - rgb.b) * (1.0 - warmFilter.b))));
//
//     vec3 wBalanceColor = mix(rgb, processed, temperature);
     
     // 美白
     //vec3 whitenColor = log(wBalanceColor * (beta - 1.0) + 1.0) / log(beta);
     
     gl_FragColor = vec4(beautyColor, 1.0);
 }
 
);

@interface QBGLBeautyFilter ()

@end

@implementation QBGLBeautyFilter

- (instancetype)init {
    if (self = [super initWithVertexShader:kQBBeautyFilterVertex fragmentShader:kQBBeautyFilterFragment]) {
        [self setBeautyParams];
        [self setSharpness:0.5];
        [self setTemperature:4700];
        [self setTint:0.0];
        [self setBeta:4.0];
    }
    return self;
}

- (void)setInputSize:(CGSize)inputSize {
    [super setInputSize:inputSize];
    const GLfloat offset[] = {1 / self.inputSize.width, 1 / self.inputSize.height};
    glUniform2fv([self.program uniformWithName:"singleStepOffset"], 1, offset);
}

- (void)setBeautyParams {
    const GLfloat params[] = {0.33f, 0.63f, 0.4f, 0.35f};
    glUniform4fv([self.program uniformWithName:"params"], 1, params);
}

- (void)setSharpness:(float)value {
    glUniform1f([self.program uniformWithName:"sharpness"], value);
}

- (void)setTemperature:(float)value {
    value = value < 5000 ? 0.0004 * (value-5000.0) : 0.00006 * (value-5000.0);
    glUniform1f([self.program uniformWithName:"temperature"], value);
}

- (void)setTint:(float)value {
    value /= 100.0;
    glUniform1f([self.program uniformWithName:"tint"], value);
}

- (void)setBeta:(float)value {
    glUniform1f([self.program uniformWithName:"beta"], value);
}

@end
