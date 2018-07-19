//
//  RKGLProgram.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

//
//  RKGLProgram.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/12/12.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGLProgram.h"

#define STRING(x) #x

char *const RKVertexShader = STRING
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

char *const RKFragmentShader = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 vec3 rgbFrom_Y_UV(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 void main()
 {
     vec3 output_result = rgbFrom_Y_UV(yTexture, uvTexture, textureCoordinate);
     output_result = clamp(output_result, 0.0, 1.0);
     
     gl_FragColor = vec4(output_result, 1.);
 }
 );

@implementation RKGLProgram

- (instancetype)init {
    if (self = [super init]) {
        _programId = glCreateProgram();
        _vertexId = [self loadShader:GL_VERTEX_SHADER withString:RKVertexShader];
        _fragmentId = [self loadShader:GL_FRAGMENT_SHADER withString:RKFragmentShader];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __FUNCTION__);
    
    glDeleteProgram(_programId);
    glDeleteShader(_vertexId);
    glDeleteShader(_fragmentId);
}

- (GLuint)loadShader:(GLenum)type withString:(const char *)string {
    GLuint shader = glCreateShader(type);
    int length = (int)strlen(string);
    glShaderSource(shader, 1, (const char **)&string, &length);
    glCompileShader(shader);
    
    glAttachShader(_programId, shader);
    
    return shader;
}

- (int)attributeWithName:(const char *)name {
    return glGetAttribLocation(_programId, name);
}

- (int)uniformWithName:(const char *)name {
    return glGetUniformLocation(_programId, name);
}

- (BOOL)link {
    glLinkProgram(_programId);
    
#if DEBUG
    GLint logLength;
    glGetProgramiv(_programId, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(_programId, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    GLint status;
    glGetProgramiv(_programId, GL_LINK_STATUS, &status);
    
#if DEBUG
    NSLog(@"Link program status = %@", status == 1 ? @"success" : @"failed");
#endif
    
    NSAssert(status == GL_TRUE, @"aaa");
    
    return status == GL_TRUE;
}

- (void)use {
    glUseProgram(_programId);
}

- (int)enableAttributeWithName:(const char *)name {
    int attrId = [self attributeWithName:name];
    glEnableVertexAttribArray(attrId);
    return attrId;
}

- (void)enableAttributeWithId:(GLuint)attributeId {
    glEnableVertexAttribArray(attributeId);
}

@end
