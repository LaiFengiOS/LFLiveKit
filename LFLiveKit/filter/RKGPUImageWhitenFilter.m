//
//  RKGPUImageWhitenFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/12/28.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageWhitenFilter.h"

NSString *const kRKGPUImageWhitenFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D whitenTexture;
 
 varying highp vec2 textureCoordinate;
 
 vec3 whiten(vec3 textureColor) {
     float strength = -1.0 / 512.0;
     float redCurveValue = texture2D(whitenTexture, vec2(textureColor.r, 0.0)).r;
     float greenCurveValue = texture2D(whitenTexture, vec2(textureColor.g, 0.0)).r;
     float blueCurveValue = texture2D(whitenTexture, vec2(textureColor.b, 0.0)).r;
     redCurveValue = min(1.0, redCurveValue + strength);
     greenCurveValue = min(1.0, greenCurveValue + strength);
     blueCurveValue = min(1.0, blueCurveValue + strength);
     
     return vec3(redCurveValue, greenCurveValue, blueCurveValue);
 }
 
 vec3 overlay(vec3 base, vec3 overlay) {
     float ra;
     if (base.r < 0.5) {
         ra = overlay.r * base.r * 2.0;
     } else {
         ra = 1.0 - ((1.0 - base.r) * (1.0 - overlay.r) * 2.0);
     }
     
     float ga;
     if (base.g < 0.5) {
         ga = overlay.g * base.g * 2.0;
     } else {
         ga = 1.0 - ((1.0 - base.g) * (1.0 - overlay.g) * 2.0);
     }
     
     float ba;
     if (base.b < 0.5) {
         ba = overlay.b * base.b * 2.0;
     } else {
         ba = 1.0 - ((1.0 - base.b) * (1.0 - overlay.b) * 2.0);
     }
     
     return vec3(ra, ga, ba);
 }
 
 void main(){
     vec3 centralColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     vec3 white = whiten(centralColor);
     vec3 result = overlay(centralColor, white);
     
     gl_FragColor = vec4(result, 1.0);
 }
 );

@implementation RKGPUImageWhitenFilter {
    GLuint _whitenTextureId;
    GLint _whitenTextureUniform;
}

- (instancetype)init {
    if (self = [super initWithFragmentShaderFromString:kRKGPUImageWhitenFragmentShaderString]) {
        [self setupWhiten];
    }
    return self;
}

- (void)dealloc {
    glDeleteTextures(1, &_whitenTextureId);
}

- (void)setupWhiten {
    char *arrayOfByte = (char *)malloc(1024);
    int arrayOfInt1[] = { 95, 95, 96, 97, 97, 98, 99, 99, 100, 101, 101, 102, 103, 104, 104, 105, 106, 106, 107, 108, 108, 109, 110, 111, 111, 112, 113, 113, 114, 115, 115, 116, 117, 117, 118, 119, 120, 120, 121, 122, 122, 123, 124, 124, 125, 126, 127, 127, 128, 129, 129, 130, 131, 131, 132, 133, 133, 134, 135, 136, 136, 137, 138, 138, 139, 140, 140, 141, 142, 143, 143, 144, 145, 145, 146, 147, 147, 148, 149, 149, 150, 151, 152, 152, 153, 154, 154, 155, 156, 156, 157, 158, 159, 159, 160, 161, 161, 162, 163, 163, 164, 165, 165, 166, 167, 168, 168, 169, 170, 170, 171, 172, 172, 173, 174, 175, 175, 176, 177, 177, 178, 179, 179, 180, 181, 181, 182, 183, 184, 184, 185, 186, 186, 187, 188, 188, 189, 190, 191, 191, 192, 193, 193, 194, 195, 195, 196, 197, 197, 198, 199, 200, 200, 201, 202, 202, 203, 204, 204, 205, 206, 207, 207, 208, 209, 209, 210, 211, 211, 212, 213, 213, 214, 215, 216, 216, 217, 218, 218, 219, 220, 220, 221, 222, 223, 223, 224, 225, 225, 226, 227, 227, 228, 229, 229, 230, 231, 232, 232, 233, 234, 234, 235, 236, 236, 237, 238, 239, 239, 240, 241, 241, 242, 243, 243, 244, 245, 245, 246, 247, 248, 248, 249, 250, 250, 251, 252, 252, 253, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255 };
    int arrayOfInt2[] = { 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 8, 8, 8, 9, 9, 10, 10, 10, 11, 11, 11, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15, 16, 16, 16, 17, 17, 17, 18, 18, 18, 19, 19, 20, 20, 20, 21, 21, 21, 22, 22, 23, 23, 23, 24, 24, 24, 25, 25, 25, 25, 26, 26, 27, 27, 28, 28, 28, 28, 29, 29, 30, 29, 31, 31, 31, 31, 32, 32, 33, 33, 34, 34, 34, 34, 35, 35, 36, 36, 37, 37, 37, 38, 38, 39, 39, 39, 40, 40, 40, 41, 42, 42, 43, 43, 44, 44, 45, 45, 45, 46, 47, 47, 48, 48, 49, 50, 51, 51, 52, 52, 53, 53, 54, 55, 55, 56, 57, 57, 58, 59, 60, 60, 61, 62, 63, 63, 64, 65, 66, 67, 68, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 100, 101, 103, 104, 105, 107, 108, 110, 111, 113, 115, 116, 118, 119, 120, 122, 123, 125, 127, 128, 130, 132, 134, 135, 137, 139, 141, 143, 144, 146, 148, 150, 152, 154, 156, 158, 160, 163, 165, 167, 169, 171, 173, 175, 178, 180, 182, 185, 187, 189, 192, 194, 197, 199, 201, 204, 206, 209, 211, 214, 216, 219, 221, 224, 226, 229, 232, 234, 236, 239, 241, 245, 247, 250, 252, 255 };
    for (int i = 0; i < 256; i++){
        arrayOfByte[(i * 4)] = ((char)arrayOfInt1[i]);
        arrayOfByte[(1 + i * 4)] = ((char)arrayOfInt1[i]);
        arrayOfByte[(2 + i * 4)] = ((char)arrayOfInt2[i]);
        arrayOfByte[(3 + i * 4)] = -1;
    }
    
    glActiveTexture(GL_TEXTURE3);
    glGenTextures(1, &_whitenTextureId);
    glBindTexture(GL_TEXTURE_2D, _whitenTextureId);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, arrayOfByte);
    
    _whitenTextureUniform = [filterProgram uniformIndex:@"whitenTexture"];
}

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates {
    if (self.preventRendering)
    {
        [firstInputFramebuffer unlock];
        return;
    }
    
    [GPUImageContext setActiveShaderProgram:filterProgram];
    
    outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:[self sizeOfFBO] textureOptions:self.outputTextureOptions onlyTexture:NO];
    [outputFramebuffer activateFramebuffer];
    if (usingNextFrameForImageCapture)
    {
        [outputFramebuffer lock];
    }
    
    [self setUniformsForProgramAtIndex:0];
    
    glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [firstInputFramebuffer texture]);
    glUniform1i(filterInputTextureUniform, 2);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, _whitenTextureId);
    glUniform1i(_whitenTextureUniform, 3);
    
    glVertexAttribPointer(filterPositionAttribute, 2, GL_FLOAT, 0, 0, vertices);
    glVertexAttribPointer(filterTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, textureCoordinates);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [firstInputFramebuffer unlock];
    
    if (usingNextFrameForImageCapture)
    {
        dispatch_semaphore_signal(imageCaptureSemaphore);
    }
}

@end
