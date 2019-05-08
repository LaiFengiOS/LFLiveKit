//
//  QBGLN1977Filter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLN1977Filter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBN1977FilterVertex;
char * const kQBN1977FilterFragment;

@interface QBGLN1977Filter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;

@end

@implementation QBGLN1977Filter

- (instancetype)init {
    self = [self initWithVertexShader:kQBN1977FilterVertex fragmentShader:kQBN1977FilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"n1977map"] identifier:@"inputImageTexture2"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (self.image1Drawable) {
        [array addObject:self.image1Drawable];
    }
    return [array copy];
}

@end


#define STRING(x) #x

char * const kQBN1977FilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 varying vec2 textureCoordinate;
 
 attribute vec4 inputAnimationCoordinate;
 varying vec2 animationCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
     animationCoordinate = inputAnimationCoordinate.xy;
 }
 );

char * const kQBN1977FilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 varying highp vec2 animationCoordinate;
 uniform sampler2D animationTexture;
 uniform int enableAnimationView;
 
 void main()
 {
     
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     texel = vec3(
                  texture2D(inputImageTexture2, vec2(texel.r, .16666)).r,
                  texture2D(inputImageTexture2, vec2(texel.g, .5)).g,
                  texture2D(inputImageTexture2, vec2(texel.b, .83333)).b);
     
     vec4 animationColor = texture2D(animationTexture, animationCoordinate);
     if (enableAnimationView == 1) {
         texel.r = animationColor.r + texel.r * (1.0 - animationColor.a);
         texel.g = animationColor.g + texel.g * (1.0 - animationColor.a);
         texel.b = animationColor.b + texel.b * (1.0 - animationColor.a);
         gl_FragColor = vec4(texel, 1.0);
     } else {
         gl_FragColor = vec4(texel, 1.0);
     }
 }

);
