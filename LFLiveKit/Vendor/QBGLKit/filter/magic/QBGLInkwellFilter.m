//
//  QBGLInkwellFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLInkwellFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBInkwellFilterVertex;
char * const kQBInkwellFilterFragment;

@interface QBGLInkwellFilter ()

@property (strong, nonatomic) QBGLDrawable *mapDrawable;

@end

@implementation QBGLInkwellFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBInkwellFilterVertex fragmentShader:kQBInkwellFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _mapDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"inkwellmap"] identifier:@"inputImageTexture2"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_mapDrawable];
}

@end


#define STRING(x) #x

char * const kQBInkwellFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
);

char * const kQBInkwellFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 void main()
 {
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     texel = vec3(dot(vec3(0.3, 0.6, 0.1), texel));
     texel = vec3(texture2D(inputImageTexture2, vec2(texel.r, .16666)).r);
     gl_FragColor = vec4(texel, 1.0);
 }
);
