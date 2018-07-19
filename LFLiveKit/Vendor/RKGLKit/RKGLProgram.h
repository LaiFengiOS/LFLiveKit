//
//  RKGLProgram.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface RKGLProgram : NSObject

@property (readonly) GLuint programId;

@property (readonly) GLuint vertexId;

@property (readonly) GLuint fragmentId;

- (int)attributeWithName:(const char *)name;

- (int)uniformWithName:(const char *)name;

- (BOOL)link;

- (void)use;

/**
 * Attribute id is returned. You can cache this id and call `enableAttributeWithId:` in following usages.
 */
- (int)enableAttributeWithName:(const char *)name;

- (void)enableAttributeWithId:(GLuint)attributeId;

@end
