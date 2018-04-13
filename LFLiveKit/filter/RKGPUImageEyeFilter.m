//
//  RKGPUImageEyeFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/2.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKGPUImageEyeFilter.h"

NSString *const kRKGPUImageEyeFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 uniform highp float scaleRatio;// 缩放系数，0无缩放，大于0则放大
 uniform highp float radius;// 缩放算法的作用域半径
 uniform highp vec2 leftEyeCenterPosition; // 左眼控制点，越远变形越小
 uniform highp vec2 rightEyeCenterPosition; // 右眼控制点
 uniform float aspectRatio; // 所处理图像的宽高比
 
 highp vec2 warpPositionToUse(vec2 centerPostion, vec2 currentPosition, float radius, float scaleRatio, float aspectRatio)
{
    vec2 positionToUse = currentPosition;
    
    vec2 currentPositionToUse = vec2(currentPosition.x, currentPosition.y * aspectRatio + 0.5 - 0.5 * aspectRatio);
    vec2 centerPostionToUse = vec2(centerPostion.x, centerPostion.y * aspectRatio + 0.5 - 0.5 * aspectRatio);
    
    float r = distance(currentPositionToUse, centerPostionToUse);
    
    if(r < radius)
    {
        float alpha = 1.0 - scaleRatio * pow(r / radius - 1.0, 2.0);
        positionToUse = centerPostion + alpha * (currentPosition - centerPostion);
    }
    
    return positionToUse;
}
 
 void main()
{
    vec2 positionToUse = warpPositionToUse(leftEyeCenterPosition, textureCoordinate, radius, scaleRatio, aspectRatio);
    
    positionToUse = warpPositionToUse(rightEyeCenterPosition, positionToUse, radius, scaleRatio, aspectRatio);
    
    gl_FragColor = texture2D(inputImageTexture, positionToUse);
} 
);

@implementation RKGPUImageEyeFilter

- (instancetype)init {
    if (self = [super initWithFragmentShaderFromString:kRKGPUImageEyeFragmentShaderString]) {
        [self setFloat:0.5 forUniformName:@"scaleRatio"];
        [self setFloat:20.0 forUniformName:@"radius"];
        [self setFloat:9.0 / 16.0 forUniformName:@"aspectRatio"];
    }
    return self;
}

- (void)setLeftEyePosition:(CGPoint)position {
    GLfloat array[2] = {position.x, position.y};
    [self setFloatArray:array length:2 forUniform:@"leftEyeCenterPosition"];
}

- (void)setRightEyePosition:(CGPoint)position {
    GLfloat array[2] = {position.x, position.y};
    [self setFloatArray:array length:2 forUniform:@"rightEyeCenterPosition"];
}

@end
