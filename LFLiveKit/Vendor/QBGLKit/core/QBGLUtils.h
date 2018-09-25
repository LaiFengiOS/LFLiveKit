//
//  QBGLUtils.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/glext.h>

#define STRING(x) #x

@interface QBGLUtils : NSObject

+ (GLuint)createTextureWithView:(UIView *)sourceView;
+ (GLuint)createTextureWithView:(UIView *)sourceView horizontalFlip:(BOOL)horizontalFlip verticalFlip:(BOOL)verticalFlip;

+ (GLuint)createTextureWithImage:(UIImage *)image;

+ (GLuint)bindTexture:(GLuint)textureId withView:(UIView *)sourceView;
+ (GLuint)bindTexture:(GLuint)textureId withView:(UIView *)sourceView horizontalFlip:(BOOL)horizontalFlip verticalFlip:(BOOL)verticalFlip;

+ (GLuint)bindTexture:(GLuint)textureId withImage:(UIImage *)image;

+ (GLuint)generateTexture;

+ (void)bindTexture:(GLuint)textureId;

+ (GLenum)activeTextureFromIndex:(GLuint)index;

@end


static GLfloat const squareVertices[] = {
    -1.0f, -1.0f,
    1.0f, -1.0f,
    -1.0f,  1.0f,
    1.0f,  1.0f,
};

static GLfloat const squareTextureCoordinates[] = {
    0.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
};
