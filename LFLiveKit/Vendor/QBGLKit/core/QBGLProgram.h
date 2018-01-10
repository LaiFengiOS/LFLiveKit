//
//  QBGLProgram.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface QBGLProgram : NSObject

- (instancetype)initWithVertexShader:(const char *)vertexShader
                      fragmentShader:(const char *)fragmentShader;

- (int)attributeWithName:(const char *)name;

- (int)uniformWithName:(const char *)name;

- (void)use;

/**
 * Attribute id is returned. You can cache this id and call `enableAttributeWithId:` in following usages.
 */
- (int)enableAttributeWithName:(const char *)name;

- (void)enableAttributeWithId:(GLuint)attributeId;

- (void)setParameter:(const char *)param intValue:(int)value;
- (void)setParameter:(const char *)param floatValue:(float)value;

@end
