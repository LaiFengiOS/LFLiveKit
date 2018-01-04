//
//  RKGPULogWhiteFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/4.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKGPULogWhiteFilter.h"

NSString *const kRKGPUImageLogWhiteFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 varying highp vec2 textureCoordinate;
 
 uniform highp float beta;
 
 void main() {
     vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     vec3 result = log(textureColor * (beta - 1.0) + 1.0) / log(beta);
     
     gl_FragColor = vec4(result, 1.0);
 }
);

@implementation RKGPULogWhiteFilter

- (instancetype)init {
    if (self = [super initWithFragmentShaderFromString:kRKGPUImageLogWhiteFragmentShaderString]) {
        [self setBeta:5.0];
    }
    return self;
}

- (void)setBeta:(float)beta {
    [self setFloat:beta forUniformName:@"beta"];
}

@end
