//
//  QBGLSakuraFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLSakuraFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBSakuraFilterVertex;
char * const kQBSakuraFilterFragment;

@interface QBGLSakuraFilter ()

@property (strong, nonatomic) QBGLDrawable *curveDrawable;

@end

@implementation QBGLSakuraFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBSakuraFilterVertex fragmentShader:kQBSakuraFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    GLuint textureId = [QBGLUtils generateTexture];
    Byte arrayOfByte[1024];
    int arrayOfInt[] = { 95, 95, 96, 97, 97, 98, 99, 99, 100, 101, 101, 102, 103, 104, 104, 105, 106, 106, 107, 108, 108, 109, 110, 111, 111, 112, 113, 113, 114, 115, 115, 116, 117, 117, 118, 119, 120, 120, 121, 122, 122, 123, 124, 124, 125, 126, 127, 127, 128, 129, 129, 130, 131, 131, 132, 133, 133, 134, 135, 136, 136, 137, 138, 138, 139, 140, 140, 141, 142, 143, 143, 144, 145, 145, 146, 147, 147, 148, 149, 149, 150, 151, 152, 152, 153, 154, 154, 155, 156, 156, 157, 158, 159, 159, 160, 161, 161, 162, 163, 163, 164, 165, 165, 166, 167, 168, 168, 169, 170, 170, 171, 172, 172, 173, 174, 175, 175, 176, 177, 177, 178, 179, 179, 180, 181, 181, 182, 183, 184, 184, 185, 186, 186, 187, 188, 188, 189, 190, 191, 191, 192, 193, 193, 194, 195, 195, 196, 197, 197, 198, 199, 200, 200, 201, 202, 202, 203, 204, 204, 205, 206, 207, 207, 208, 209, 209, 210, 211, 211, 212, 213, 213, 214, 215, 216, 216, 217, 218, 218, 219, 220, 220, 221, 222, 223, 223, 224, 225, 225, 226, 227, 227, 228, 229, 229, 230, 231, 232, 232, 233, 234, 234, 235, 236, 236, 237, 238, 239, 239, 240, 241, 241, 242, 243, 243, 244, 245, 245, 246, 247, 248, 248, 249, 250, 250, 251, 252, 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    for (int i = 0; i < 256; i++)
    {
        arrayOfByte[(i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(1 + i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(2 + i * 4)] = ((Byte)arrayOfInt[i]);
        arrayOfByte[(3 + i * 4)] = ((Byte)arrayOfInt[i]);
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, &arrayOfByte);
    _curveDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"curve"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_curveDrawable];
}

- (GLuint)render {
    [self.program setParameter:"texelWidthOffset" floatValue:1 / self.inputSize.width];
    [self.program setParameter:"texelHeightOffset" floatValue:1 / self.inputSize.height];
    return [super render];
}

@end


#define STRING(x) #x

char * const kQBSakuraFilterVertex = STRING
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

char * const kQBSakuraFilterFragment = STRING
(
 varying highp vec2 textureCoordinate;
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D curve;
 
 void main()
{
    lowp vec4 textureColor;
    lowp vec4 textureColorRes;
    lowp vec4 textureColorOri;
    vec4 grey1Color;
    vec4 layerColor;
    mediump float satVal = 115.0 / 100.0;
    
    float xCoordinate = textureCoordinate.x;
    float yCoordinate = textureCoordinate.y;
    
    highp float redCurveValue;
    highp float greenCurveValue;
    highp float blueCurveValue;
    
    textureColor = texture2D( inputImageTexture, vec2(xCoordinate, yCoordinate));
    textureColorRes = textureColor;
    textureColorOri = textureColor;
    
    // step1. screen blending
    textureColor = 1.0 - ((1.0 - textureColorOri) * (1.0 - textureColorOri));
    textureColor = (textureColor - textureColorOri) + textureColorOri;
    
    // step2. curve
    redCurveValue = texture2D(curve, vec2(textureColor.r, 0.0)).r;
    greenCurveValue = texture2D(curve, vec2(textureColor.g, 0.0)).g;
    blueCurveValue = texture2D(curve, vec2(textureColor.b, 0.0)).b;
    
    // step3. saturation
    highp float G = (redCurveValue + greenCurveValue + blueCurveValue);
    G = G / 3.0;
    
    redCurveValue = ((1.0 - satVal) * G + satVal * redCurveValue);
    greenCurveValue = ((1.0 - satVal) * G + satVal * greenCurveValue);
    blueCurveValue = ((1.0 - satVal) * G + satVal * blueCurveValue);
    
    textureColor = vec4(redCurveValue, greenCurveValue, blueCurveValue, 1.0);
    
    gl_FragColor = vec4(textureColor.r, textureColor.g, textureColor.b, 1.0); 
}

);

