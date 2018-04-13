//
//  QBGLToasterFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/27.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLToasterFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBToasterFilterVertex;
char * const kQBToasterFilterFragment;

@interface QBGLToasterFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;
@property (strong, nonatomic) QBGLDrawable *image3Drawable;
@property (strong, nonatomic) QBGLDrawable *image4Drawable;
@property (strong, nonatomic) QBGLDrawable *image5Drawable;

@end

@implementation QBGLToasterFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBToasterFilterVertex fragmentShader:kQBToasterFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"toastermetal"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"toastersoftlight"] identifier:@"inputImageTexture3"];
    _image3Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"toastercurves"] identifier:@"inputImageTexture4"];
    _image4Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"toasteroverlaymapwarm"] identifier:@"inputImageTexture5"];
    _image5Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"toastercolorshift"] identifier:@"inputImageTexture6"];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable, _image3Drawable, _image4Drawable, _image5Drawable];
}

@end


#define STRING(x) #x

char * const kQBToasterFilterVertex = STRING
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

char * const kQBToasterFilterFragment = STRING
(
 precision mediump float;
 
 varying mediump vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2; //toaster_metal
 uniform sampler2D inputImageTexture3; //toaster_soft_light
 uniform sampler2D inputImageTexture4; //toaster_curves
 uniform sampler2D inputImageTexture5; //toaster_overlay_map_warm
 uniform sampler2D inputImageTexture6; //toaster_color_shift
 
 void main()
{
    mediump vec3 texel;
    mediump vec2 lookup;
    vec2 blue;
    vec2 green;
    vec2 red;
    mediump vec4 tmpvar_1;
    tmpvar_1 = texture2D (inputImageTexture, textureCoordinate);
    texel = tmpvar_1.xyz;
    mediump vec4 tmpvar_2;
    tmpvar_2 = texture2D (inputImageTexture2, textureCoordinate);
    mediump vec2 tmpvar_3;
    tmpvar_3.x = tmpvar_2.x;
    tmpvar_3.y = tmpvar_1.x;
    texel.x = texture2D (inputImageTexture3, tmpvar_3).x;
    mediump vec2 tmpvar_4;
    tmpvar_4.x = tmpvar_2.y;
    tmpvar_4.y = tmpvar_1.y;
    texel.y = texture2D (inputImageTexture3, tmpvar_4).y;
    mediump vec2 tmpvar_5;
    tmpvar_5.x = tmpvar_2.z;
    tmpvar_5.y = tmpvar_1.z;
    texel.z = texture2D (inputImageTexture3, tmpvar_5).z;
    red.x = texel.x;
    red.y = 0.16666;
    green.x = texel.y;
    green.y = 0.5;
    blue.x = texel.z;
    blue.y = 0.833333;
    texel.x = texture2D (inputImageTexture4, red).x;
    texel.y = texture2D (inputImageTexture4, green).y;
    texel.z = texture2D (inputImageTexture4, blue).z;
    mediump vec2 tmpvar_6;
    tmpvar_6 = ((2.0 * textureCoordinate) - 1.0);
    mediump vec2 tmpvar_7;
    tmpvar_7.x = dot (tmpvar_6, tmpvar_6);
    tmpvar_7.y = texel.x;
    lookup = tmpvar_7;
    texel.x = texture2D (inputImageTexture5, tmpvar_7).x;
    lookup.y = texel.y;
    texel.y = texture2D (inputImageTexture5, lookup).y;
    lookup.y = texel.z;
    texel.z = texture2D (inputImageTexture5, lookup).z;
    red.x = texel.x;
    green.x = texel.y;
    blue.x = texel.z;
    texel.x = texture2D (inputImageTexture6, red).x;
    texel.y = texture2D (inputImageTexture6, green).y;
    texel.z = texture2D (inputImageTexture6, blue).z;
    mediump vec4 tmpvar_8;
    tmpvar_8.w = 1.0;
    tmpvar_8.xyz = texel;
    gl_FragColor = tmpvar_8;
}
);
