//
//  QBGLValenciaFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLValenciaFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBValenciaFilterVertex;
char * const kQBValenciaFilterFragment;

@interface QBGLValenciaFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;

@end

@implementation QBGLValenciaFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBValenciaFilterVertex fragmentShader:kQBValenciaFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"valenciamap"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"valenciagradientmap"] identifier:@"inputImageTexture3"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable];
}

@end


#define STRING(x) #x

char * const kQBValenciaFilterVertex = STRING
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

char * const kQBValenciaFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //map
 uniform sampler2D inputImageTexture3; //gradMap
 
 mat3 saturateMatrix = mat3(
                            1.1402,
                            -0.0598,
                            -0.061,
                            -0.1174,
                            1.0826,
                            -0.1186,
                            -0.0228,
                            -0.0228,
                            1.1772);
 
 vec3 lumaCoeffs = vec3(.3, .59, .11);
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     texel = vec3(
                  texture2D(inputImageTexture2, vec2(texel.r, .1666666)).r,
                  texture2D(inputImageTexture2, vec2(texel.g, .5)).g,
                  texture2D(inputImageTexture2, vec2(texel.b, .8333333)).b
                  );
     
     texel = saturateMatrix * texel;
     float luma = dot(lumaCoeffs, texel);
     texel = vec3(
                  texture2D(inputImageTexture3, vec2(luma, texel.r)).r,
                  texture2D(inputImageTexture3, vec2(luma, texel.g)).g,
                  texture2D(inputImageTexture3, vec2(luma, texel.b)).b);
     
     texel.rgb = mix(originColor.rgb, texel.rgb, strength);
     gl_FragColor = vec4(texel, 1.0);
 }
);

