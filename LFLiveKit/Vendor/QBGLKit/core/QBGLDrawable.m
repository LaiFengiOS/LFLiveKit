//
//  QBGLDrawable.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLDrawable.h"
#import "QBGLProgram.h"
#import "QBGLUtils.h"

@implementation QBGLDrawable

- (instancetype)initWithImage:(UIImage *)image identifier:(NSString *)identifier {
    if (self = [super init]) {
        NSAssert(image, @"image can not be nil");
        _identifier = identifier;
        _textureId = [QBGLUtils createTextureWithImage:image];
    }
    return self;
}

- (instancetype)initWithTextureRef:(CVOpenGLESTextureRef)textureRef identifier:(NSString *)identifier{
    if (self = [super init]) {
        _identifier = identifier;
        _textureId = CVOpenGLESTextureGetName(textureRef);
        [QBGLUtils bindTexture:_textureId];
    }
    return self;
}

- (instancetype)initWithTextureId:(GLuint)textureId identifier:(NSString *)identifier {
    if (self = [super init]) {
        _identifier = identifier;
        _textureId = textureId;
        [QBGLUtils bindTexture:textureId];
    }
    return self;
}

- (void)deleteTexture {
    glDeleteTextures(1, &_textureId);
}

- (void)reloadImage:(UIImage *)image {
    _textureId = [QBGLUtils bindTexture:_textureId withImage:image];
}

- (GLuint)prepareToDrawAtTextureIndex:(GLuint)index program:(QBGLProgram *)program {
    glActiveTexture([QBGLUtils activeTextureFromIndex:index]);
    glBindTexture(GL_TEXTURE_2D, _textureId);
    glUniform1i([program uniformWithName:_identifier.UTF8String], index);
    
    return index + 1;
}

@end
