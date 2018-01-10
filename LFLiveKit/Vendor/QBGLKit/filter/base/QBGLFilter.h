//
//  QBGLFilter.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <UIKit/UIKit.h>

@class QBGLProgram;
@class QBGLDrawable;

@interface QBGLFilter : NSObject

@property (strong, nonatomic, readonly) QBGLProgram *program;

@property (nonatomic) CGSize inputSize;

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader;

/**
 * Subclass should call this method when ready to load.
 */
- (void)loadTextures;

/**
 * Subclass should always call [super deleteTextures].
 */
- (void)deleteTextures;

- (void)loadBGRA:(CVPixelBufferRef)pixelBuffer textureCache:(CVOpenGLESTextureCacheRef)textureCacheRef;

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer textureCache:(CVOpenGLESTextureCacheRef)textureCacheRef;

/**
 * Prepare for drawing and return the next available active texture index.
 */
- (GLuint)render;

- (NSArray<QBGLDrawable*> *)renderTextures;

@end
