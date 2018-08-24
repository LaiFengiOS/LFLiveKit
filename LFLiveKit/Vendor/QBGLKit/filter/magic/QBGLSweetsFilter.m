//
//  QBGLSweetsFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLSweetsFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBSweetsFilterVertex;
char * const kQBSweetsFilterFragment;

@interface QBGLSweetsFilter ()

@property (strong, nonatomic) QBGLDrawable *curveDrawable;
@property (strong, nonatomic) QBGLDrawable *image1Drawable;

@end

@implementation QBGLSweetsFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBSweetsFilterVertex fragmentShader:kQBSweetsFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    GLuint textureId = [QBGLUtils generateTexture];
    Byte arrayOfByte[1024];
    int arrayOfInt[] = { 0, 1, 2, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 23, 24, 24, 25, 26, 27, 28, 29, 30, 30, 31, 32, 33, 34, 35, 36, 37, 38, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 71, 72, 73, 74, 75, 76, 77, 79, 80, 81, 82, 83, 84, 86, 87, 88, 89, 90, 92, 93, 94, 95, 96, 98, 99, 100, 101, 103, 104, 105, 106, 108, 109, 110, 111, 113, 114, 115, 116, 118, 119, 120, 121, 123, 124, 125, 126, 128, 129, 130, 132, 133, 134, 135, 137, 138, 139, 140, 142, 143, 144, 145, 147, 148, 149, 150, 152, 153, 154, 155, 157, 158, 159, 160, 161, 163, 164, 165, 166, 167, 169, 170, 171, 172, 173, 174, 176, 177, 178, 179, 180, 181, 182, 183, 184, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 209, 210, 211, 212, 213, 214, 215, 216, 217, 217, 218, 219, 220, 221, 222, 222, 223, 224, 225, 226, 227, 227, 228, 229, 230, 230, 231, 232, 233, 234, 234, 235, 236, 237, 237, 238, 239, 240, 240, 241, 242, 243, 243, 244, 245, 246, 246, 247, 248, 248, 249, 250, 251, 251, 252, 253, 254, 254, 255 };
    for (int i = 0; i < 256; i++){
        arrayOfByte[(i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(1 + i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(2 + i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(3 + i * 4)] = ((Byte)i);
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, &arrayOfByte);
    _curveDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"curve"];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"rise_mask2"] identifier:@"samplerMask"];
    [self.program setParameter:"lowPerformance" intValue:1];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_curveDrawable, _image1Drawable];
}

- (void)setAdditionalUniformVarsForRender {
    [super setAdditionalUniformVarsForRender];
    
    [self.program setParameter:"texelWidthOffset" floatValue:1 / self.inputSize.width];
    [self.program setParameter:"texelHeightOffset" floatValue:1 / self.inputSize.height];
}

@end


#define STRING(x) #x

char * const kQBSweetsFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

char * const kQBSweetsFilterFragment = STRING
(
 precision mediump float;
 
 uniform lowp sampler2D inputImageTexture;
 uniform lowp sampler2D curve;
 uniform lowp sampler2D samplerMask;
 uniform lowp int lowPerformance;
 
 uniform float texelWidthOffset ;
 uniform float texelHeightOffset;
 
 varying mediump vec2 textureCoordinate;
 
 vec4 sharpen(sampler2D sampler)
{
    vec4 color = texture2D(sampler, textureCoordinate) * 2.;
    
    color -= texture2D(sampler, textureCoordinate-vec2(texelWidthOffset, 0. )) * 0.25;
    color -= texture2D(sampler, textureCoordinate+vec2(texelWidthOffset, 0. )) * 0.25;
    color -= texture2D(sampler, textureCoordinate-vec2(0., texelHeightOffset)) * 0.25;
    color -= texture2D(sampler, textureCoordinate+vec2(0., texelHeightOffset)) * 0.25;
    
    return color;
}
 
 vec4 gaussianBlur(sampler2D sampler)
{
    lowp float strength = 1.;
    
    vec4 color = vec4(0.);
    vec2 step  = vec2(0.);
    
    color += texture2D(sampler,textureCoordinate)* 0.0443 ;
    
    step.x = 1.49583 * texelWidthOffset  * strength;
    step.y = 1.49583 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+vec2(step.x, 0.)) * 0.04321;
    color += texture2D(sampler,textureCoordinate-vec2(step.x, 0.)) * 0.04321;
    color += texture2D(sampler,textureCoordinate+vec2(0., step.y)) * 0.04321;
    color += texture2D(sampler,textureCoordinate-vec2(0., step.y)) * 0.04321;
    
    step.x = 2.4719250988753685 * texelWidthOffset  * strength;
    step.y = 2.4719250988753685 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+step) * 0.041795;
    color += texture2D(sampler,textureCoordinate-step) * 0.041795;
    color += texture2D(sampler,textureCoordinate+vec2(-step.x, step.y)) * 0.041795;
    color += texture2D(sampler,textureCoordinate+vec2( step.x,-step.y)) * 0.041795;
    
    step.x = 5.49583 * texelWidthOffset  * strength;
    step.y = 5.49583 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+vec2(step.x, 0.)) * 0.040425;
    color += texture2D(sampler,textureCoordinate-vec2(step.x, 0.)) * 0.040425;
    color += texture2D(sampler,textureCoordinate+vec2(0., step.y)) * 0.040425;
    color += texture2D(sampler,textureCoordinate-vec2(0., step.y)) * 0.040425;
    
    step.x = 5.300352223621558 * texelWidthOffset  * strength;
    step.y = 5.300352223621558 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+step) * 0.0391;
    color += texture2D(sampler,textureCoordinate-step) * 0.0391;
    color += texture2D(sampler,textureCoordinate+vec2(-step.x, step.y)) * 0.0391;
    color += texture2D(sampler,textureCoordinate+vec2( step.x,-step.y)) * 0.0391;
    
    step.x = 9.49583 * texelWidthOffset  * strength;
    step.y = 9.49583 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+vec2(step.x, 0.)) * 0.037815;
    color += texture2D(sampler,textureCoordinate-vec2(step.x, 0.)) * 0.037815;
    color += texture2D(sampler,textureCoordinate+vec2(0., step.y)) * 0.037815;
    color += texture2D(sampler,textureCoordinate-vec2(0., step.y)) * 0.037815;
    
    step.x = 8.128779348367749 * texelWidthOffset  * strength;
    step.y = 8.128779348367749 * texelHeightOffset * strength;
    color += texture2D(sampler,textureCoordinate+step) * 0.03658;
    color += texture2D(sampler,textureCoordinate-step) * 0.03658;
    color += texture2D(sampler,textureCoordinate+vec2(-step.x, step.y)) * 0.03658;
    color += texture2D(sampler,textureCoordinate+vec2( step.x,-step.y)) * 0.03658;
    
    return color;
}
 
 vec4 level(vec4 color, sampler2D sampler)
{
    color.r = texture2D(sampler, vec2(color.r, 0.)).r;
    color.g = texture2D(sampler, vec2(color.g, 0.)).g;
    color.b = texture2D(sampler, vec2(color.b, 0.)).b;
    
    return color;
}
 
 vec4 normal(vec4 c1, vec4 c2, float alpha)
{
    return (c2-c1) * alpha + c1;
}
 
 vec4 lighten(vec4 c1, vec4 c2)
{
    return max(c1,c2);
}
 
 vec4 overlay(vec4 c1, vec4 c2)
{
    vec4 r1 = vec4(0.,0.,0.,1.);
    r1.r = c1.r < 0.5 ? 2.0*c1.r*c2.r : 1.0 - 2.0*(1.0-c1.r)*(1.0-c2.r);
    r1.g = c1.g < 0.5 ? 2.0*c1.g*c2.g : 1.0 - 2.0*(1.0-c1.g)*(1.0-c2.g);
    r1.b = c1.b < 0.5 ? 2.0*c1.b*c2.b : 1.0 - 2.0*(1.0-c1.b)*(1.0-c2.b);
    
    return r1;
}
 
 vec3 lerp (vec3 x, vec3 y, float s)
{
    return x+s*(y-x);
}
 
 vec4 adjust (vec4 color, float brightness, float contrast, float saturation)
{
    vec3 averageLuminance = vec3(0.5);
    vec3 brightedColor    = color.rgb * (brightness+1.);
    vec3 intensity        = vec3(dot(brightedColor, vec3(0.299, 0.587, 0.114)));
    vec3 saturatedColor   = lerp(intensity, brightedColor, saturation+1.);
    vec3 contrastedColor  = lerp(averageLuminance, saturatedColor, contrast+1.);
    
    return vec4(contrastedColor,1.);
}
 
 vec4 vibrance(vec4 color, float strength)
{
    float luminance = (color.r+color.g+color.b)/3.;
    //dot(color.rgb, vec3(0.299,0.587,0.114));
    float maximum   = max(color.r, max(color.g, color.b));
    float amount    = (maximum-luminance)*-strength;
    
    return vec4(color.rgb * (1.-amount) + maximum*amount, 1.);
}
 
 void main()
{
    vec4 c1;
    vec4 c2;
    if (lowPerformance == 1)
    {
        c1 = texture2D(inputImageTexture, textureCoordinate);
        c2 = texture2D(inputImageTexture, textureCoordinate);
    }
    else
    {
        c1 = sharpen(inputImageTexture);
        c2 = normal(c1, gaussianBlur(inputImageTexture), 0.8); // radius = 13. sharpen?? gaussian blur? ???? ??, ?? blending?? ??
    }
    vec4 c3 = normal(c1, lighten(c1,c2), 0.6); // lighten (0.6) 
    c3 = adjust(c3, 0.12, 0., 0.05); // brightness = 12, saturation = 0.5; 
    c3 = vibrance(level(c3, curve), 0.5); // vibrance = 0.5; 
    c3 = normal(c3, overlay(c3, vec4(0.)), 1.-texture2D(samplerMask, textureCoordinate).r); // vignetting 
    
    gl_FragColor = c3;
}
);
