//
//  QBGLXprollFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLXprollFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBXprollFilterVertex;
char * const kQBXprollFilterFragment;

@interface QBGLXprollFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;

@end

@implementation QBGLXprollFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBXprollFilterVertex fragmentShader:kQBXprollFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"xpromap"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"vignettemap_new"] identifier:@"inputImageTexture3"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable];
}

@end


#define STRING(x) #x

char * const kQBXprollFilterVertex = STRING
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

char * const kQBXprollFilterFragment = STRING
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
     
     vec2 tc = (2.0 * textureCoordinate) - 1.0;
     float d = dot(tc, tc);
     vec2 lookup = vec2(d, texel.r);
     texel.r = texture2D(inputImageTexture3, lookup).r;
     lookup.y = texel.g;
     texel.g = texture2D(inputImageTexture3, lookup).g;
     lookup.y = texel.b;
     texel.b	= texture2D(inputImageTexture3, lookup).b;
     
     vec2 red = vec2(texel.r, 0.16666);
     vec2 green = vec2(texel.g, 0.5);
     vec2 blue = vec2(texel.b, .83333);
     texel.r = texture2D(inputImageTexture2, red).r;
     texel.g = texture2D(inputImageTexture2, green).g;
     texel.b = texture2D(inputImageTexture2, blue).b;
     
     texel.rgb = mix(originColor.rgb, texel.rgb, strength);
     
     gl_FragColor = vec4(texel, 1.0);
     
 }
);
