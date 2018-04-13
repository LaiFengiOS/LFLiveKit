//
//  QBGLPixarFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLPixarFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBPixarFilterVertex;
char * const kQBPixarFilterFragment;

@interface QBGLPixarFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;

@end

@implementation QBGLPixarFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBPixarFilterVertex fragmentShader:kQBPixarFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"pixar_curves"] identifier:@"inputImageTexture2"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable];
}

@end


#define STRING(x) #x

char * const kQBPixarFilterVertex = STRING
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

char * const kQBPixarFilterFragment = STRING
(
 precision mediump float;
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
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
    mapped.r = texture2D(inputImageTexture2, vec2(color.r, 0.0)).r;
    mapped.g = texture2D(inputImageTexture2, vec2(color.g, 0.0)).g;
    mapped.b = texture2D(inputImageTexture2, vec2(color.b, 0.0)).b;
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
    color.r = texture2D(inputImageTexture2, vec2(color.r, 0.0)).r;
    color.g = texture2D(inputImageTexture2, vec2(color.g, 0.0)).g;
    color.b = texture2D(inputImageTexture2, vec2(color.b, 0.0)).b;
    
    // color control
    color = NCColorControl(color, 1.0, 0.08, 1.0);
    
    // hue adjust
    color = NCHueAdjust(color, 0.0556);
    
    // color matrix
    color = NCColorMatrix(color, 1.0, 1.0, 1.0, 1.0, vec4(0.02, 0.02, 0.06, 0));
    
    color.rgb = mix(originColor.rgb, color.rgb, strength);
    
    gl_FragColor = color;
}
);

