//
//  QBGLBrooklynFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLBrooklynFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBBrooklynFilterVertex;
char * const kQBBrooklynFilterFragment;

@interface QBGLBrooklynFilter ()

@property (strong, nonatomic) QBGLDrawable *curve1Drawable;
@property (strong, nonatomic) QBGLDrawable *mapFirstDrawable;
@property (strong, nonatomic) QBGLDrawable *curve2Drawable;

@end

@implementation QBGLBrooklynFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBBrooklynFilterVertex fragmentShader:kQBBrooklynFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _curve1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brooklynCurves1"] identifier:@"curve1Texture"];
    _mapFirstDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"filter_map_first"] identifier:@"mapFirstTexture"];
    _curve2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brooklynCurves2"] identifier:@"curve2Texture"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_curve1Drawable, _mapFirstDrawable, _curve2Drawable];
}

@end


#define STRING(x) #x

char * const kQBBrooklynFilterVertex = STRING
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

char * const kQBBrooklynFilterFragment = STRING
(
 precision mediump float;
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D curve1Texture;
 uniform sampler2D mapFirstTexture;
 uniform sampler2D curve2Texture;
 
 uniform float strength;
 
 // gray
 float NCGray(vec4 color)
{
    float gray = 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
    
    return gray;
}
 
 // tone mapping
 vec4 NCTonemapping(vec4 color)
{
    
    vec4 mapped;
    mapped.r = texture2D(curve1Texture, vec2(color.r, 0.0)).r;
    mapped.g = texture2D(curve1Texture, vec2(color.g, 0.0)).g;
    mapped.b = texture2D(curve1Texture, vec2(color.b, 0.0)).b;
    mapped.a = color.a;
    
    return mapped;
}
 
 // color control
 vec4 NCColorControl(vec4 color, float saturation, float brightness, float contrast)
{
    float gray = NCGray(color);
    
    color.rgb = vec3(saturation) * color.rgb + vec3(1.0-saturation) * vec3(gray);
    color.r = clamp(color.r, 0.0, 1.0);
    color.g = clamp(color.g, 0.0, 1.0);
    color.b = clamp(color.b, 0.0, 1.0);
    
    color.rgb = vec3(contrast) * (color.rgb - vec3(0.5)) + vec3(0.5);
    color.r = clamp(color.r, 0.0, 1.0);
    color.g = clamp(color.g, 0.0, 1.0);
    color.b = clamp(color.b, 0.0, 1.0);
    
    color.rgb = color.rgb + vec3(brightness);
    color.r = clamp(color.r, 0.0, 1.0);
    color.g = clamp(color.g, 0.0, 1.0);
    color.b = clamp(color.b, 0.0, 1.0);
    
    return color;
}
 
 // hue adjust
 vec4 NCHueAdjust(vec4 color, float hueAdjust)
{
    vec3 kRGBToYPrime = vec3(0.299, 0.587, 0.114);
    vec3 kRGBToI = vec3(0.595716, -0.274453, -0.321263);
    vec3 kRGBToQ = vec3(0.211456, -0.522591, 0.31135);
    
    vec3 kYIQToR   = vec3(1.0, 0.9563, 0.6210);
    vec3 kYIQToG   = vec3(1.0, -0.2721, -0.6474);
    vec3 kYIQToB   = vec3(1.0, -1.1070, 1.7046);
    
    float yPrime = dot(color.rgb, kRGBToYPrime);
    float I = dot(color.rgb, kRGBToI);
    float Q = dot(color.rgb, kRGBToQ);
    
    float hue = atan(Q, I);
    float chroma  = sqrt (I * I + Q * Q);
    
    hue -= hueAdjust;
    
    Q = chroma * sin (hue);
    I = chroma * cos (hue);
    
    color.r = dot(vec3(yPrime, I, Q), kYIQToR);
    color.g = dot(vec3(yPrime, I, Q), kYIQToG);
    color.b = dot(vec3(yPrime, I, Q), kYIQToB);
    
    return color;
}
 
 // colorMatrix
 vec4 NCColorMatrix(vec4 color, float red, float green, float blue, float alpha, vec4 bias)
{
    color = color * vec4(red, green, blue, alpha) + bias;
    
    return color;
}
 
 // multiply blend
 vec4 NCMultiplyBlend(vec4 overlay, vec4 base)
{
    vec4 outputColor;
    
    float a = overlay.a + base.a * (1.0 - overlay.a);
    
    //    // normal blend
    //    outputColor.r = (base.r * base.a + overlay.r * overlay.a * (1.0 - base.a))/a;
    //    outputColor.g = (base.g * base.a + overlay.g * overlay.a * (1.0 - base.a))/a;
    //    outputColor.b = (base.b * base.a + overlay.b * overlay.a * (1.0 - base.a))/a;
    
    
    // multiply blend
    outputColor.rgb = ((1.0-base.a) * overlay.rgb * overlay.a + (1.0-overlay.a) * base.rgb * base.a + overlay.a * base.a * overlay.rgb * base.rgb) / a;
    
    
    outputColor.a = a;
    
    return outputColor;
}
 
 void main()
{
    vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
    vec4 color = texture2D(inputImageTexture, textureCoordinate);
    
    color.a = 1.0;
    
    // tone mapping
    color.r = texture2D(curve1Texture, vec2(color.r, 0.0)).r;
    color.g = texture2D(curve1Texture, vec2(color.g, 0.0)).g;
    color.b = texture2D(curve1Texture, vec2(color.b, 0.0)).b;
    
    // color control
    color = NCColorControl(color, 0.88, 0.03, 0.85);
    
    // hue adjust
    color = NCHueAdjust(color, -0.0444);
    
    // normal blend
    vec4 bg = vec4(0.5647, 0.1961, 0.0157, 0.14);
    color = NCMultiplyBlend(bg, color);
    
    // normal blend
    vec4 bg2 = texture2D(mapFirstTexture, textureCoordinate);
    bg2.a *= 0.9;
    color = NCMultiplyBlend(bg2, color);
    
    // tone mapping
    color.r = texture2D(curve2Texture, vec2(color.r, 0.0)).r;
    color.g = texture2D(curve2Texture, vec2(color.g, 0.0)).g;
    color.b = texture2D(curve2Texture, vec2(color.b, 0.0)).b;
    
    color.rgb = mix(originColor.rgb, color.rgb, strength);
    gl_FragColor = color;
}
);
