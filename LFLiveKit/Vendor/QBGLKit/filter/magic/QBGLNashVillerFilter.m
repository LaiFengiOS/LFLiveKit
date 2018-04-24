//
//  QBGLNashVillerFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLNashVillerFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBNashVillerFilterVertex;
char * const kQBNashVillerFilterFragment;

@interface QBGLNashVillerFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;

@end

@implementation QBGLNashVillerFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBNashVillerFilterVertex fragmentShader:kQBNashVillerFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"nashvillemap"] identifier:@"inputImageTexture2"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable];
}

@end


#define STRING(x) #x

char * const kQBNashVillerFilterVertex = STRING
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

char * const kQBNashVillerFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 void main()
 {
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     texel = vec3(
                  texture2D(inputImageTexture2, vec2(texel.r, .16666)).r,
                  texture2D(inputImageTexture2, vec2(texel.g, .5)).g,
                  texture2D(inputImageTexture2, vec2(texel.b, .83333)).b);
     gl_FragColor = vec4(texel, 1.0);
 }

);

