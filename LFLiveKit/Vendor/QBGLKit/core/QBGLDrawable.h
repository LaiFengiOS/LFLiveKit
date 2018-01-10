//
//  QBGLDrawable.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>

@class QBGLProgram;

@interface QBGLDrawable : NSObject

/**
 * Identifier mapping to GLSL variables.
 */
@property (strong, nonatomic) NSString *identifier;

/**
 * Texture id registered to GL space. Automatically generated when texture loaded.
 */
@property (readonly) GLuint textureId;


- (instancetype)initWithImage:(UIImage *)image identifier:(NSString *)identifier;

- (instancetype)initWithTextureRef:(CVOpenGLESTextureRef)textureRef identifier:(NSString *)identifier;

- (instancetype)initWithTextureId:(GLuint)textureId identifier:(NSString *)identifier;

- (void)deleteTexture;

- (void)reloadImage:(UIImage *)image;

/**
 * Prepare drawing with active texture index. 
 * Call `glActiveTexture()` and return the next available active texture index.
 */
- (GLuint)prepareToDrawAtTextureIndex:(GLuint)index program:(QBGLProgram *)program;

@end
