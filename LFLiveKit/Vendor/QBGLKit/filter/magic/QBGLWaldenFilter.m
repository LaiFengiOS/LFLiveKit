//
//  QBGLWaldenFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLWaldenFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBWaldenFilterVertex;
char * const kQBWaldenFilterFragment;

@interface QBGLWaldenFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;

@end

@implementation QBGLWaldenFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBWaldenFilterVertex fragmentShader:kQBWaldenFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"walden_map"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"vignette_map"] identifier:@"inputImageTexture3"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable];
}

@end


#define STRING(x) #x

char * const kQBWaldenFilterVertex = STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform mat4 transformMatrix;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position * transformMatrix;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

char * const kQBWaldenFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //map
 uniform sampler2D inputImageTexture3; //vigMap
 
 uniform float strength;
 
 void main()
{
    vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
    vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
    
    texel = vec3(
                 texture2D(inputImageTexture2, vec2(texel.r, .16666)).r,
                 texture2D(inputImageTexture2, vec2(texel.g, .5)).g,
                 texture2D(inputImageTexture2, vec2(texel.b, .83333)).b);
    
    vec2 tc = (2.0 * textureCoordinate) - 1.0;
    float d = dot(tc, tc);
    vec2 lookup = vec2(d, texel.r);
    texel.r = texture2D(inputImageTexture3, lookup).r;
    lookup.y = texel.g;
    texel.g = texture2D(inputImageTexture3, lookup).g;
    lookup.y = texel.b;
    texel.b	= texture2D(inputImageTexture3, lookup).b;
    
    texel.rgb = mix(originColor.rgb, texel.rgb, strength);
    
    gl_FragColor = vec4(texel, 1.0);
}
);

