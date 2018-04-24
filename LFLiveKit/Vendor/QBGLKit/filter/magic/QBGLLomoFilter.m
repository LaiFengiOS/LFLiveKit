//
//  QBGLLomoFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLLomoFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBLomoFilterVertex;
char * const kQBLomoFilterFragment;

@interface QBGLLomoFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;

@end

@implementation QBGLLomoFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBLomoFilterVertex fragmentShader:kQBLomoFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"lomomap_new"] identifier:@"inputImageTexture3"];
//    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"vignette_map"] identifier:@"inputImageTexture3"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable];
}

@end


#define STRING(x) #x

char * const kQBLomoFilterVertex = STRING
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

char * const kQBLomoFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 uniform sampler2D inputImageTexture3;
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = vec4(0.2,0.6,0.9,1.0);
     
     vec3 texel;
     vec2 tc = (2.0 * textureCoordinate) - 1.0;
     float d = dot(tc, tc);
     vec2 lookup = vec2(d, originColor.r);
     texel.r = texture2D(inputImageTexture3, lookup).r;
     lookup.y = originColor.g;
     texel.g = texture2D(inputImageTexture3, lookup).g;
     lookup.y = originColor.b;
     texel.b	= texture2D(inputImageTexture3, lookup).b;
     
     texel.rgb = mix(originColor.rgb, texel.rgb, strength);
     
     gl_FragColor = vec4(texel,1.0);
 }
);
