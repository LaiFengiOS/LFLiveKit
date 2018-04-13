//
//  QBGLHudsonFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLHudsonFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBHudsonFilterVertex;
char * const kQBHudsonFilterFragment;

@interface QBGLHudsonFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;
@property (strong, nonatomic) QBGLDrawable *image3Drawable;

@end

@implementation QBGLHudsonFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBHudsonFilterVertex fragmentShader:kQBHudsonFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"hudsonbackground"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"overlaymap"] identifier:@"inputImageTexture3"];
    _image3Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"hudsonmap"] identifier:@"inputImageTexture4"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable, _image3Drawable];
}

@end


#define STRING(x) #x

char * const kQBHudsonFilterVertex = STRING
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

char * const kQBHudsonFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //blowout;
 uniform sampler2D inputImageTexture3; //overlay;
 uniform sampler2D inputImageTexture4; //map
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
     
     vec4 texel = texture2D(inputImageTexture, textureCoordinate);
     
     vec3 bbTexel = texture2D(inputImageTexture2, textureCoordinate).rgb;
     
     texel.r = texture2D(inputImageTexture3, vec2(bbTexel.r, texel.r)).r;
     texel.g = texture2D(inputImageTexture3, vec2(bbTexel.g, texel.g)).g;
     texel.b = texture2D(inputImageTexture3, vec2(bbTexel.b, texel.b)).b;
     
     vec4 mapped;
     mapped.r = texture2D(inputImageTexture4, vec2(texel.r, .16666)).r;
     mapped.g = texture2D(inputImageTexture4, vec2(texel.g, .5)).g;
     mapped.b = texture2D(inputImageTexture4, vec2(texel.b, .83333)).b;
     mapped.a = 1.0;
     
     mapped.rgb = mix(originColor.rgb, mapped.rgb, strength);
     
     gl_FragColor = mapped;
 }
);
