//
//  QBGLSutroFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLSutroFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBSutroFilterVertex;
char * const kQBSutroFilterFragment;

@interface QBGLSutroFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;
@property (strong, nonatomic) QBGLDrawable *image3Drawable;
@property (strong, nonatomic) QBGLDrawable *image4Drawable;
@property (strong, nonatomic) QBGLDrawable *image5Drawable;

@end

@implementation QBGLSutroFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBSutroFilterVertex fragmentShader:kQBSutroFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"vignette_map"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"sutrometal"] identifier:@"inputImageTexture3"];
    _image3Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"softlight"] identifier:@"inputImageTexture4"];
    _image4Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"sutroedgeburn"] identifier:@"inputImageTexture5"];
    _image5Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"sutrocurves"] identifier:@"inputImageTexture6"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable, _image3Drawable, _image4Drawable, _image5Drawable];
}

@end


#define STRING(x) #x

char * const kQBSutroFilterVertex = STRING
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

char * const kQBSutroFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //sutroMap;
 uniform sampler2D inputImageTexture3; //sutroMetal;
 uniform sampler2D inputImageTexture4; //softLight
 uniform sampler2D inputImageTexture5; //sutroEdgeburn
 uniform sampler2D inputImageTexture6; //sutroCurves
 
 uniform float strength;
 
 void main()
 {
     vec4 originColor = texture2D(inputImageTexture, textureCoordinate);
     vec3 texel = texture2D(inputImageTexture, textureCoordinate).rgb;
     
     vec2 tc = (2.0 * textureCoordinate) - 1.0;
     float d = dot(tc, tc);
     vec2 lookup = vec2(d, texel.r);
     texel.r = texture2D(inputImageTexture2, lookup).r;
     lookup.y = texel.g;
     texel.g = texture2D(inputImageTexture2, lookup).g;
     lookup.y = texel.b;
     texel.b	= texture2D(inputImageTexture2, lookup).b;
     
     vec3 rgbPrime = vec3(0.1019, 0.0, 0.0);
     float m = dot(vec3(.3, .59, .11), texel.rgb) - 0.03058;
     texel = mix(texel, rgbPrime + m, 0.32);
     
     vec3 metal = texture2D(inputImageTexture3, textureCoordinate).rgb;
     texel.r = texture2D(inputImageTexture4, vec2(metal.r, texel.r)).r;
     texel.g = texture2D(inputImageTexture4, vec2(metal.g, texel.g)).g;
     texel.b = texture2D(inputImageTexture4, vec2(metal.b, texel.b)).b;
     
     texel = texel * texture2D(inputImageTexture5, textureCoordinate).rgb;
     
     texel.r = texture2D(inputImageTexture6, vec2(texel.r, .16666)).r;
     texel.g = texture2D(inputImageTexture6, vec2(texel.g, .5)).g;
     texel.b = texture2D(inputImageTexture6, vec2(texel.b, .83333)).b;
     
     texel.rgb = mix(originColor.rgb, texel.rgb, strength);
     
     gl_FragColor = vec4(texel, 1.0);
 }
);

