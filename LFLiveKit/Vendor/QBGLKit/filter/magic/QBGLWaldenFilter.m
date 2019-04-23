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

- (instancetype)init {
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
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (self.image1Drawable && self.image2Drawable) {
        [array addObject:self.image1Drawable];
        [array addObject:self.image2Drawable];
    }
    return [array copy];
}

@end


#define STRING(x) #x

char * const kQBWaldenFilterVertex = STRING
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

char * const kQBWaldenFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //map
 uniform sampler2D inputImageTexture3; //vigMap
 uniform float strength;
 
 varying highp vec2 animationCoordinate;
 uniform sampler2D animationTexture;
 uniform int enableAnimationView;
 
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
    
    vec4 animationColor = texture2D(animationTexture, animationCoordinate);
    if (enableAnimationView == 1) {
        gl_FragColor = vec4(mix(texel, animationColor.rgb, animationColor.a), 1.0);
    } else {
        gl_FragColor = vec4(texel, 1.0);
    }
}
);

