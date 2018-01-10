//
//  QBGLBrannanFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLBrannanFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBBrannanFilterVertex;
char * const kQBBrannanFilterFragment;

@interface QBGLBrannanFilter ()

@property (strong, nonatomic) QBGLDrawable *processDrawable;
@property (strong, nonatomic) QBGLDrawable *blowoutDrawable;
@property (strong, nonatomic) QBGLDrawable *contrastDrawable;
@property (strong, nonatomic) QBGLDrawable *lumaDrawable;
@property (strong, nonatomic) QBGLDrawable *screenDrawable;

@end

@implementation QBGLBrannanFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBBrannanFilterVertex fragmentShader:kQBBrannanFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _processDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_process"] identifier:@"processTexture"];
    _blowoutDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_blowout"] identifier:@"blowoutTexture"];
    _contrastDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_contrast"] identifier:@"contrastTexture"];
    _lumaDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_luma"] identifier:@"lumaTexture"];
    _screenDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_screen"] identifier:@"screenTexture"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_processDrawable, _blowoutDrawable, _contrastDrawable, _lumaDrawable, _screenDrawable];
}

@end


#define STRING(x) #x

char * const kQBBrannanFilterVertex = STRING
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

char * const kQBBrannanFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D processTexture;  //process
 uniform sampler2D blowoutTexture;  //blowout
 uniform sampler2D contrastTexture;  //contrast
 uniform sampler2D lumaTexture;  //luma
 uniform sampler2D screenTexture;  //screen
 
 mat3 saturateMatrix = mat3(
                            1.105150, -0.044850,-0.046000,
                            -0.088050,1.061950,-0.089200,
                            -0.017100,-0.017100,1.132900);
 
 vec3 luma = vec3(.3, .59, .11);
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     vec2 lookup;
     lookup.y = 0.5;
     lookup.x = texel.r;
     texel.r = texture2D(processTexture, lookup).r;
     lookup.x = texel.g;
     texel.g = texture2D(processTexture, lookup).g;
     lookup.x = texel.b;
     texel.b = texture2D(processTexture, lookup).b;
     
     texel = saturateMatrix * texel;
     
     
     vec2 tc = (2.0 * textureCoordinate) - 1.0;
     float d = dot(tc, tc);
     vec3 sampled;
     lookup.y = 0.5;
     lookup.x = texel.r;
     sampled.r = texture2D(blowoutTexture, lookup).r;
     lookup.x = texel.g;
     sampled.g = texture2D(blowoutTexture, lookup).g;
     lookup.x = texel.b;
     sampled.b = texture2D(blowoutTexture, lookup).b;
     float value = smoothstep(0.0, 1.0, d);
     texel = mix(sampled, texel, value);
     
     lookup.x = texel.r;
     texel.r = texture2D(contrastTexture, lookup).r;
     lookup.x = texel.g;
     texel.g = texture2D(contrastTexture, lookup).g;
     lookup.x = texel.b;
     texel.b = texture2D(contrastTexture, lookup).b;
     
     
     lookup.x = dot(texel, luma);
     texel = mix(texture2D(lumaTexture, lookup).rgb, texel, .5);
     
     lookup.x = texel.r;
     texel.r = texture2D(screenTexture, lookup).r;
     lookup.x = texel.g;
     texel.g = texture2D(screenTexture, lookup).g;
     lookup.x = texel.b;
     texel.b = texture2D(screenTexture, lookup).b;
     
     texel = mix(originColor.rgb, texel.rgb, strength);
     
     gl_FragColor = vec4(texel, 1.0);
 }
);
