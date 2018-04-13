//
//  QBGLProgram.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLProgram.h"

#define QBGL_DEBUG  1

@interface QBGLProgram ()

@property (nonatomic) GLuint programId;
@property (nonatomic) GLuint vertexId;
@property (nonatomic) GLuint fragmentId;

@end

@implementation QBGLProgram

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader {
    if (self = [super init]) {
        _programId = glCreateProgram();
        _vertexId = [self loadShader:GL_VERTEX_SHADER withString:vertexShader];
        _fragmentId = [self loadShader:GL_FRAGMENT_SHADER withString:fragmentShader];
        [self link];
        [self use];
    }
    return self;
}

- (void)deallocx {
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
    
#if QBGL_DEBUG
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
    
#if QBGL_DEBUG
    NSLog(@"Link program status = %@", status == 1 ? @"success" : @"failed");
#endif
    
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

- (void)setParameter:(const char *)param intValue:(int)value {
    glUniform1i([self uniformWithName:param], value);
}
- (void)setParameter:(const char *)param floatValue:(float)value {
    glUniform1f([self uniformWithName:param], value);
}

@end
