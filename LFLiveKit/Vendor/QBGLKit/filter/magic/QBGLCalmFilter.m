//
//  QBGLCalmFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLCalmFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBCalmFilterVertex;
char * const kQBCalmFilterFragment;

@interface QBGLCalmFilter ()

@property (strong, nonatomic) QBGLDrawable *curveDrawable;
@property (strong, nonatomic) QBGLDrawable *mask1Drawable;
@property (strong, nonatomic) QBGLDrawable *mask2Drawable;

@end

@implementation QBGLCalmFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBCalmFilterVertex fragmentShader:kQBCalmFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    GLuint textureId = [QBGLUtils generateTexture];
    Byte arrayOfByte[3072];
    int arrayOfInt1[] = { 38, 39, 40, 41, 41, 42, 43, 44, 45, 46, 47, 47, 48, 49, 50, 51, 52, 52, 53, 54, 55, 56, 57, 58, 58, 59, 60, 61, 62, 63, 64, 64, 65, 66, 67, 68, 69, 69, 70, 71, 72, 73, 74, 75, 75, 76, 77, 78, 79, 80, 81, 81, 82, 83, 84, 85, 86, 87, 87, 88, 89, 90, 91, 92, 92, 93, 94, 95, 96, 97, 98, 98, 99, 100, 101, 102, 103, 104, 104, 105, 106, 107, 108, 109, 109, 110, 111, 112, 113, 114, 115, 115, 116, 117, 118, 119, 120, 121, 121, 122, 123, 124, 125, 126, 127, 127, 128, 129, 130, 131, 132, 132, 133, 134, 135, 136, 137, 138, 138, 139, 140, 141, 142, 143, 144, 144, 145, 146, 147, 148, 149, 149, 150, 151, 152, 153, 154, 155, 155, 156, 157, 158, 159, 160, 161, 161, 162, 163, 164, 165, 166, 166, 167, 168, 169, 170, 171, 172, 172, 173, 174, 175, 176, 177, 178, 178, 179, 180, 181, 182, 183, 184, 184, 185, 186, 187, 188, 189, 189, 190, 191, 192, 193, 194, 195, 195, 196, 197, 198, 199, 200, 201, 201, 202, 203, 204, 205, 206, 206, 207, 208, 209, 210, 211, 212, 212, 213, 214, 215, 216, 217, 218, 218, 219, 220, 221, 222, 223, 224, 224, 225, 226, 227, 228, 229, 229, 230, 231, 232, 233, 234, 235, 235, 236, 237, 238, 239, 240, 241, 241, 242, 243, 244, 245, 246, 246, 247, 248, 249, 250, 251, 252, 252, 253, 254, 255 };
    for (int i = 0; i < 256; i++){
        arrayOfByte[(i * 4)] = ((Byte)arrayOfInt1[i]);
        arrayOfByte[(1 + i * 4)] = ((Byte)arrayOfInt1[i]);
        arrayOfByte[(2 + i * 4)] = ((Byte)arrayOfInt1[i]);
        arrayOfByte[(3 + i * 4)] = -1;
    }
    int arrayOfInt2[] = { 0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 29, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 93, 94, 95, 96, 97, 98, 99, 99, 100, 101, 102, 103, 104, 104, 105, 106, 107, 108, 109, 109, 110, 111, 112, 113, 114, 114, 115, 116, 117, 118, 118, 119, 120, 121, 122, 123, 123, 124, 125, 126, 127, 127, 128, 129, 130, 131, 131, 132, 133, 134, 135, 135, 136, 137, 138, 139, 140, 140, 141, 142, 143, 144, 145, 145, 146, 147, 148, 149, 150, 150, 151, 152, 153, 154, 155, 156, 157, 157, 158, 159, 160, 161, 162, 163, 164, 165, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 196, 197, 198, 199, 200, 201, 202, 203, 204, 206, 207, 208, 209, 210, 211, 213, 214, 215, 216, 217, 218, 220, 221, 222, 223, 224, 226, 227, 228, 229, 230, 232, 233, 234, 235, 237, 238, 239, 240, 241, 243, 244, 245, 246, 248, 249, 250, 251, 253, 254, 255 };
    int arrayOfInt3[] = { 0, 1, 1, 2, 3, 3, 4, 5, 6, 6, 7, 8, 8, 9, 10, 11, 11, 12, 13, 14, 15, 15, 16, 17, 18, 19, 20, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 36, 37, 38, 39, 40, 42, 43, 44, 46, 47, 48, 50, 51, 53, 54, 56, 57, 59, 60, 62, 64, 65, 67, 69, 70, 72, 74, 75, 77, 79, 80, 82, 84, 85, 87, 89, 91, 92, 94, 96, 97, 99, 101, 102, 104, 106, 107, 109, 111, 112, 114, 115, 117, 118, 120, 121, 123, 124, 126, 127, 129, 130, 132, 133, 134, 136, 137, 138, 140, 141, 142, 144, 145, 146, 147, 149, 150, 151, 152, 153, 155, 156, 157, 158, 159, 160, 161, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 184, 185, 186, 187, 188, 189, 190, 191, 191, 192, 193, 194, 195, 196, 196, 197, 198, 199, 200, 200, 201, 202, 203, 203, 204, 205, 206, 206, 207, 208, 209, 209, 210, 211, 211, 212, 213, 214, 214, 215, 216, 216, 217, 218, 218, 219, 220, 220, 221, 222, 222, 223, 224, 224, 225, 226, 226, 227, 227, 228, 229, 229, 230, 231, 231, 232, 233, 233, 234, 234, 235, 236, 236, 237, 237, 238, 239, 239, 240, 240, 241, 242, 242, 243, 243, 244, 245, 245, 246, 246, 247, 247, 248, 249, 249, 250, 250, 251, 252, 252, 253, 253, 254, 254, 255 };
    for (int j = 0; j < 256; j++){
        arrayOfByte[(1024 + j * 4)] = ((Byte)arrayOfInt3[j]);
        arrayOfByte[(1 + (1024 + j * 4))] = ((Byte)arrayOfInt3[j]);
        arrayOfByte[(2 + (1024 + j * 4))] = ((Byte)arrayOfInt2[j]);
        arrayOfByte[(3 + (1024 + j * 4))] = -1;
    }
    int arrayOfInt4[] = { 0, 1, 3, 4, 5, 7, 8, 10, 11, 12, 14, 15, 16, 18, 19, 20, 22, 23, 24, 26, 27, 28, 30, 31, 33, 34, 35, 37, 38, 39, 41, 42, 43, 45, 46, 47, 49, 50, 51, 53, 54, 55, 57, 58, 59, 61, 62, 63, 64, 66, 67, 68, 70, 71, 72, 74, 75, 76, 77, 79, 80, 81, 83, 84, 85, 86, 88, 89, 90, 91, 93, 94, 95, 96, 98, 99, 100, 101, 103, 104, 105, 106, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119, 121, 122, 123, 124, 125, 126, 128, 129, 130, 131, 132, 133, 134, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 175, 176, 177, 178, 179, 180, 181, 182, 183, 183, 184, 185, 186, 187, 188, 189, 189, 190, 191, 192, 193, 194, 194, 195, 196, 197, 198, 198, 199, 200, 201, 202, 202, 203, 204, 205, 205, 206, 207, 208, 208, 209, 210, 211, 211, 212, 213, 214, 214, 215, 216, 216, 217, 218, 218, 219, 220, 221, 221, 222, 223, 223, 224, 225, 225, 226, 227, 227, 228, 229, 229, 230, 231, 231, 232, 233, 233, 234, 235, 235, 236, 237, 237, 238, 239, 239, 240, 240, 241, 242, 242, 243, 244, 244, 245, 246, 246, 247, 247, 248, 249, 249, 250, 251, 251, 252, 252, 253, 254, 254, 255 };
    int arrayOfInt5[] = { 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11, 11, 11, 12, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15, 16, 16, 16, 17, 17, 17, 18, 18, 18, 19, 19, 20, 20, 21, 21, 21, 22, 22, 23, 23, 24, 24, 24, 25, 25, 26, 26, 27, 27, 28, 28, 29, 29, 30, 30, 31, 31, 32, 33, 33, 34, 34, 35, 35, 36, 37, 37, 38, 38, 39, 40, 40, 41, 42, 42, 43, 44, 44, 45, 46, 47, 47, 48, 49, 49, 50, 51, 52, 53, 53, 54, 55, 56, 57, 57, 58, 59, 60, 61, 62, 63, 64, 65, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 81, 82, 83, 84, 85, 86, 87, 88, 90, 91, 92, 93, 94, 96, 97, 98, 99, 101, 102, 103, 105, 106, 107, 109, 110, 111, 113, 114, 115, 117, 118, 120, 121, 123, 124, 126, 127, 129, 130, 132, 133, 135, 137, 138, 140, 142, 143, 145, 147, 148, 150, 152, 153, 155, 157, 159, 161, 162, 164, 166, 168, 170, 172, 174, 175, 177, 179, 181, 183, 185, 187, 189, 191, 193, 195, 197, 199, 201, 203, 205, 207, 209, 211, 213, 215, 217, 219, 221, 224, 226, 228, 230, 232, 234, 236, 238, 240, 242, 244, 247, 249, 251, 253, 255 };
    int arrayOfInt6[] = { 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 8, 8, 8, 9, 9, 10, 10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15, 16, 16, 16, 17, 17, 17, 18, 18, 18, 19, 19, 20, 20, 20, 21, 21, 21, 22, 22, 23, 23, 23, 24, 24, 24, 25, 25, 25, 25, 26, 26, 27, 27, 28, 28, 28, 28, 29, 29, 30, 29, 31, 31, 31, 31, 32, 32, 33, 33, 34, 34, 34, 34, 35, 35, 36, 36, 37, 37, 37, 38, 38, 39, 39, 39, 40, 40, 40, 41, 42, 42, 43, 43, 44, 44, 45, 45, 45, 46, 47, 47, 48, 48, 49, 50, 51, 51, 52, 52, 53, 53, 54, 55, 55, 56, 57, 57, 58, 59, 60, 60, 61, 62, 63, 63, 64, 65, 66, 67, 68, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 100, 101, 103, 104, 105, 107, 108, 110, 111, 113, 115, 116, 118, 119, 120, 122, 123, 125, 127, 128, 130, 132, 134, 135, 137, 139, 141, 143, 144, 146, 148, 150, 152, 154, 156, 158, 160, 163, 165, 167, 169, 171, 173, 175, 178, 180, 182, 185, 187, 189, 192, 194, 197, 199, 201, 204, 206, 209, 211, 214, 216, 219, 221, 224, 226, 229, 232, 234, 236, 239, 241, 245, 247, 250, 252, 255 };
    for (int k = 0; k < 256; k++){
        arrayOfByte[(2048 + k * 4)] = ((Byte)arrayOfInt4[k]);
        arrayOfByte[(1 + (2048 + k * 4))] = ((Byte)arrayOfInt5[k]);
        arrayOfByte[(2 + (2048 + k * 4))] = ((Byte)arrayOfInt6[k]);
        arrayOfByte[(3 + (2048 + k * 4))] = -1;
    }
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 3, 0, GL_RGBA, GL_UNSIGNED_BYTE, &arrayOfByte);
    _curveDrawable = [[QBGLDrawable alloc] initWithTextureId:textureId identifier:@"curve"];
    _mask1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"calm_mask1"] identifier:@"grey1Frame"];
    _mask2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"calm_mask2"] identifier:@"grey2Frame"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_curveDrawable, _mask1Drawable, _mask2Drawable];
}

@end


#define STRING(x) #x

char * const kQBCalmFilterVertex = STRING
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

char * const kQBCalmFilterFragment = STRING
(
 varying highp vec2 textureCoordinate;
 
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D grey1Frame;
 uniform sampler2D grey2Frame;
 uniform sampler2D curve;
 
 const mediump vec3 luminanceWeighting = vec3(0.2125, 0.7154, 0.0721);
 
 void main()
{
    lowp float satura = 0.5;
    float GreyVal;
    lowp vec4 textureColor;
    lowp vec4 textureColorRes;
    
    highp float redCurveValue;
    highp float greenCurveValue;
    highp float blueCurveValue;
    
    vec4 grey1Color;
    vec4 grey2Color;
    
    float xCoordinate = textureCoordinate.x;
    float yCoordinate = textureCoordinate.y;
    
    textureColor = texture2D( inputImageTexture, vec2(xCoordinate, yCoordinate));
    textureColorRes = textureColor;
    
    grey1Color = texture2D(grey1Frame, vec2(xCoordinate, yCoordinate));
    grey2Color = texture2D(grey2Frame, vec2(xCoordinate, yCoordinate));
    
    // step 1. saturation
    lowp float luminance = dot(textureColor.rgb, luminanceWeighting);
    lowp vec3 greyScaleColor = vec3(luminance);
    
    textureColor = vec4(mix(greyScaleColor, textureColor.rgb, satura), textureColor.w);
    
    // step 2. level, blur curve, rgb curve
    redCurveValue = texture2D(curve, vec2(textureColor.r, 0.0)).r;
    redCurveValue = texture2D(curve, vec2(redCurveValue, 1.0/2.0)).r;
    
    greenCurveValue = texture2D(curve, vec2(textureColor.g, 0.0)).g;
    greenCurveValue = texture2D(curve, vec2(greenCurveValue, 1.0/2.0)).g;
    
    blueCurveValue = texture2D(curve, vec2(textureColor.b, 0.0)).b;
    blueCurveValue = texture2D(curve, vec2(blueCurveValue, 1.0/2.0)).b;
    blueCurveValue = texture2D(curve, vec2(blueCurveValue, 1.0/2.0)).g;
    
    lowp vec4 base = vec4(redCurveValue, greenCurveValue, blueCurveValue, 1.0);
    
    redCurveValue = texture2D(curve, vec2(redCurveValue, 1.0)).r;
    greenCurveValue = texture2D(curve, vec2(greenCurveValue, 1.0)).r;
    blueCurveValue = texture2D(curve, vec2(blueCurveValue, 1.0)).r;
    lowp vec4 overlayer = vec4(redCurveValue, greenCurveValue, blueCurveValue, 1.0);
    //gl_FragColor = base * (1.0 - grey1Color.r) + overlayer * grey1Color.r;
    base = (base - overlayer) * (1.0 - grey1Color.r) + overlayer;
    
    redCurveValue = texture2D(curve, vec2(base.r, 1.0)).g;
    greenCurveValue = texture2D(curve, vec2(base.g, 1.0)).g;
    blueCurveValue = texture2D(curve, vec2(base.b, 1.0)).g;
    overlayer = vec4(redCurveValue, greenCurveValue, blueCurveValue, 1.0);
    
    textureColor = (base - overlayer) * (1.0 - grey2Color.r) + overlayer;
    //base * (grey2Color.r) + overlayer * (1.0 - grey2Color.r);
    
    gl_FragColor = vec4(textureColor.r, textureColor.g, textureColor.b, 1.0); 
}
);
