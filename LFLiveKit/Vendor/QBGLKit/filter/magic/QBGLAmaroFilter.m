//
//  QBGLAmaroFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLAmaroFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBAmaroFilterVertex;
char * const kQBAmaroFilterFragment;

@interface QBGLAmaroFilter ()

@property (strong, nonatomic) QBGLDrawable *blowoutDrawable;
@property (strong, nonatomic) QBGLDrawable *overlayDrawable;
@property (strong, nonatomic) QBGLDrawable *colorMapDrawable;

@end

@implementation QBGLAmaroFilter

- (instancetype)init {
    self = [self initWithVertexShader:kQBAmaroFilterVertex fragmentShader:kQBAmaroFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _blowoutDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"brannan_blowout"] identifier:@"blowoutTexture"];
    _overlayDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"overlaymap"] identifier:@"overlayTexture"];
    _colorMapDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"amaromap"] identifier:@"colormapTexture"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_blowoutDrawable, _overlayDrawable, _colorMapDrawable];
}

@end


#define STRING(x) #x

char * const kQBAmaroFilterVertex = STRING
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

char * const kQBAmaroFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D blowoutTexture;  // blowout
 uniform sampler2D overlayTexture;  // overlay
 uniform sampler2D colormapTexture; // color map
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
     vec4 texel = texture2D(inputImageTexture, textureCoordinate);
     vec3 bbTexel = texture2D(blowoutTexture, textureCoordinate).rgb;
     
     texel.r = texture2D(overlayTexture, vec2(bbTexel.r, texel.r)).r;
     texel.g = texture2D(overlayTexture, vec2(bbTexel.g, texel.g)).g;
     texel.b = texture2D(overlayTexture, vec2(bbTexel.b, texel.b)).b;
     
     vec4 mapped;
     mapped.r = texture2D(colormapTexture, vec2(texel.r, .16666)).r;
     mapped.g = texture2D(colormapTexture, vec2(texel.g, .5)).g;
     mapped.b = texture2D(colormapTexture, vec2(texel.b, .83333)).b;
     mapped.a = 1.0;
     
     mapped.rgb = mix(originColor.rgb, mapped.rgb, strength);
     
     gl_FragColor = mapped;
 }
);
