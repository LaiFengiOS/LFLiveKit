//
//  QBGLHealthyFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLHealthyFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBHealthyFilterVertex;
char * const kQBHealthyFilterFragment;

@interface QBGLHealthyFilter ()

@property (strong, nonatomic) QBGLDrawable *curveDrawable;
@property (strong, nonatomic) QBGLDrawable *maskDrawable;

@end

@implementation QBGLHealthyFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBHealthyFilterVertex fragmentShader:kQBHealthyFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    GLuint textureId = [QBGLUtils generateTexture];
    Byte arrayOfByte[1024];
    int arrayOfInt1[] = { 95, 95, 96, 97, 97, 98, 99, 99, 100, 101, 101, 102, 103, 104, 104, 105, 106, 106, 107, 108, 108, 109, 110, 111, 111, 112, 113, 113, 114, 115, 115, 116, 117, 117, 118, 119, 120, 120, 121, 122, 122, 123, 124, 124, 125, 126, 127, 127, 128, 129, 129, 130, 131, 131, 132, 133, 133, 134, 135, 136, 136, 137, 138, 138, 139, 140, 140, 141, 142, 143, 143, 144, 145, 145, 146, 147, 147, 148, 149, 149, 150, 151, 152, 152, 153, 154, 154, 155, 156, 156, 157, 158, 159, 159, 160, 161, 161, 162, 163, 163, 164, 165, 165, 166, 167, 168, 168, 169, 170, 170, 171, 172, 172, 173, 174, 175, 175, 176, 177, 177, 178, 179, 179, 180, 181, 181, 182, 183, 184, 184, 185, 186, 186, 187, 188, 188, 189, 190, 191, 191, 192, 193, 193, 194, 195, 195, 196, 197, 197, 198, 199, 200, 200, 201, 202, 202, 203, 204, 204, 205, 206, 207, 207, 208, 209, 209, 210, 211, 211, 212, 213, 213, 214, 215, 216, 216, 217, 218, 218, 219, 220, 220, 221, 222, 223, 223, 224, 225, 225, 226, 227, 227, 228, 229, 229, 230, 231, 232, 232, 233, 234, 234, 235, 236, 236, 237, 238, 239, 239, 240, 241, 241, 242, 243, 243, 244, 245, 245, 246, 247, 248, 248, 249, 250, 250, 251, 252, 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    int arrayOfInt2[] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 4, 5, 7, 8, 9, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 60, 61, 62, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 168, 169, 170, 171, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 189, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 204, 205, 206, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 219, 220, 221, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 234, 235, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 249, 249, 250, 251, 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    int arrayOfInt3[] = { 0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11, 12, 13, 14, 15, 16, 17, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 95, 96, 97, 98, 99, 100, 101, 102, 103, 105, 106, 107, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 120, 121, 122, 124, 125, 126, 127, 128, 129, 130, 131, 132, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 249, 250, 251, 252, 253, 254, 255 };
    for (int i = 0; i < 256; i++)
    {
        arrayOfByte[(i * 4)] = ((Byte)arrayOfInt3[i]);
        arrayOfByte[(1 + i * 4)] = ((Byte)arrayOfInt2[i]);
        arrayOfByte[(2 + i * 4)] = ((Byte)arrayOfInt1[i]);
        arrayOfByte[(3 + i * 4)] = -1;
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, &arrayOfByte);
    _curveDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"curve"];
    _maskDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"healthy_mask_1"] identifier:@"mask"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_curveDrawable, _maskDrawable];
}

- (GLuint)render {
    [self.program setParameter:"texelWidthOffset" floatValue:1 / self.inputSize.width];
    [self.program setParameter:"texelHeightOffset" floatValue:1 / self.inputSize.height];
    return [super render];
}

@end


#define STRING(x) #x

char * const kQBHealthyFilterVertex = STRING
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

char * const kQBHealthyFilterFragment = STRING
(
 precision mediump float;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D curve;
 uniform sampler2D mask;
 
 uniform float texelWidthOffset ;
 
 uniform float texelHeightOffset;
 
 varying mediump vec2 textureCoordinate;
 
 
 vec4 level0c(vec4 color, sampler2D sampler)
{
    color.r = texture2D(sampler, vec2(color.r, 0.)).r;
    color.g = texture2D(sampler, vec2(color.g, 0.)).r;
    color.b = texture2D(sampler, vec2(color.b, 0.)).r;
    return color;
}
 
 vec4 level1c(vec4 color, sampler2D sampler)
{
    color.r = texture2D(sampler, vec2(color.r, 0.)).g;
    color.g = texture2D(sampler, vec2(color.g, 0.)).g;
    color.b = texture2D(sampler, vec2(color.b, 0.)).g;
    return color;
}
 
 vec4 level2c(vec4 color, sampler2D sampler)
{
    color.r = texture2D(sampler, vec2(color.r,0.)).b;
    color.g = texture2D(sampler, vec2(color.g,0.)).b;
    color.b = texture2D(sampler, vec2(color.b,0.)).b;
    return color;
}
 
 vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
 
 vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
 
 vec4 normal(vec4 c1, vec4 c2, float alpha)
{
    return (c2-c1) * alpha + c1;
}
 
 vec4 multiply(vec4 c1, vec4 c2)
{
    return c1 * c2 * 1.01;
}
 
 vec4 overlay(vec4 c1, vec4 c2)
{
    vec4 color = vec4(0.,0.,0.,1.);
    
    color.r = c1.r < 0.5 ? 2.0*c1.r*c2.r : 1.0 - 2.0*(1.0-c1.r)*(1.0-c2.r);
    color.g = c1.g < 0.5 ? 2.0*c1.g*c2.g : 1.0 - 2.0*(1.0-c1.g)*(1.0-c2.g);
    color.b = c1.b < 0.5 ? 2.0*c1.b*c2.b : 1.0 - 2.0*(1.0-c1.b)*(1.0-c2.b);
    
    return color;
}
 
 vec4 screen(vec4 c1, vec4 c2)
{
    return vec4(1.) - ((vec4(1.) - c1) * (vec4(1.) - c2));
}
 
 void main()
{
    // iOS ImageLiveFilter adjustment
    // begin
    
    vec4 textureColor;
    
    vec4 t0 = texture2D(mask, vec2(textureCoordinate.x, textureCoordinate.y));
    
    // naver skin
    vec4 c2 = texture2D(inputImageTexture, textureCoordinate);
    vec4 c5 = c2;
    
    // healthy
    vec3 hsv = rgb2hsv(c5.rgb);
    lowp float h = hsv.x;
    lowp float s = hsv.y;
    lowp float v = hsv.z;
    
    lowp float cF = 0.;
    // color strength
    lowp float cG = 0.;
    // color gap;
    lowp float sF = 0.06;
    // saturation strength;
    
    if(h >= 0.125 && h <= 0.208)
    {
        // 45 to 75
        s = s - (s * sF);
    }
    else if (h >= 0.208 && h < 0.292)
    {
        // 75 to 105
        cG = abs(h - 0.208);
        cF = (cG / 0.0833);
        s = s - (s * sF * cF);
    }
    else if (h > 0.042 && h <=  0.125)
    {
        // 15 to 45
        cG = abs(h - 0.125);
        cF = (cG / 0.0833);
        s = s - (s * sF * cF);
    }
    hsv.y = s;
    
    vec4 c6 = vec4(hsv2rgb(hsv),1.);
    
    c6 = normal(c6, screen  (c6, c6), 0.275); // screen 70./255. 
    c6 = normal(c6, overlay (c6, vec4(1., 0.61176, 0.25098, 1.)), 0.04); // overlay 10./255. 
    
    c6 = normal(c6, multiply(c6, t0), 0.262); // multiply 67./255. 
    
    c6 = level1c(level0c(c6,curve),curve); 
    
    gl_FragColor = c6; 
    // end
}
);
