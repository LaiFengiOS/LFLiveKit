//
//  QBGLColorMapFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/23.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLColorMapFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBColorMapFilterVertex;
char * const kQBColorMapFilterFragment;

@interface QBGLColorMapFilter ()

@property (strong, nonatomic) QBGLDrawable *colorMapDrawable;
@property (strong, nonatomic) QBGLDrawable *overlay1Drawable;
@property (strong, nonatomic) QBGLDrawable *overlay2Drawable;

@end

@implementation QBGLColorMapFilter

- (instancetype)init {
    if (self = [super initWithVertexShader:kQBColorMapFilterVertex fragmentShader:kQBColorMapFilterFragment]) {
        [self loadTextures];
    }
    return self;
}

- (instancetype)initWithColorMap:(NSString *)colorMapName
                        overlay1:(NSString *)overlayName1
                        overlay2:(NSString *)overlayName2
                   localizedName:(nullable NSString *)localizedName{
    self = [self initWithVertexShader:kQBColorMapFilterVertex fragmentShader:kQBColorMapFilterFragment];
    if (self) {
        _colorMapName = colorMapName;
        _overlayName1 = overlayName1;
        _overlayName2 = overlayName2;
        _localizedName = localizedName;
        [self loadTextures];
    }
    return self;
}

- (void)setColorMapName:(NSString *)colorMapName {
    _colorMapName = colorMapName;
    _colorMapDrawable = colorMapName.length > 0 ? [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_colorMapName] identifier:@"colorMapTexture"] : nil;
}

- (void)setOverlayName1:(NSString *)overlayName1 {
    _overlayName1 = overlayName1;
    _overlay1Drawable = overlayName1.length > 0 ? [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_overlayName1] identifier:@"overlayTexture1"] : nil;
    [self.program setParameter:"overlay1Enabled" intValue:_overlay1Drawable ? 1 : 0];
}

- (void)setOverlayName2:(NSString *)overlayName2 {
    _overlayName2 = overlayName2;
    _overlay2Drawable = overlayName2.length > 0 ? [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_overlayName2] identifier:@"overlayTexture2"] : nil;
    [self.program setParameter:"overlay2Enabled" intValue:_overlay2Drawable ? 1 : 0];
}

- (void)loadTextures {
    [super loadTextures];
    
    if (_colorMapName.length > 0) {
        _colorMapDrawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_colorMapName] identifier:@"colorMapTexture"];
    }
    if (_overlayName1.length > 0) {
        _overlay1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_overlayName1] identifier:@"overlayTexture1"];
    }
    if (_overlayName2.length > 0) {
        _overlay2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:_overlayName2] identifier:@"overlayTexture2"];
    }
    [self.program setParameter:"filterMixPercentage" floatValue:1.0];
    [self.program setParameter:"overlay1Enabled" intValue:_overlay1Drawable ? 1 : 0];
    [self.program setParameter:"overlay2Enabled" intValue:_overlay2Drawable ? 1 : 0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (_colorMapDrawable) {
        [array addObject:_colorMapDrawable];
    }
    if (_overlay1Drawable) {
        [array addObject:_overlay1Drawable];
    }
    if (_overlay2Drawable) {
        [array addObject:_overlay2Drawable];
    }
    return array;
}

@end


#define STRING(x) #x

char * const kQBColorMapFilterVertex = STRING
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

char * const kQBColorMapFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 uniform sampler2D colorMapTexture; // mandatory
 uniform sampler2D overlayTexture1; // optional
 uniform sampler2D overlayTexture2; // optional
 
 uniform float filterMixPercentage;
 uniform int overlay1Enabled;
 uniform int overlay2Enabled;
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 vec3 rgbFromYuv(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 vec3 applyColorMap(vec3 inputTexture, sampler2D colorMap) {
     float size = 33.0;
     
     float sliceSize = 1.0 / size;
     float slicePixelSize = sliceSize / size;
     float sliceInnerSize = slicePixelSize * (size - 1.0);
     float xOffset = 0.5 * sliceSize + inputTexture.x * (1.0 - sliceSize);
     float yOffset = 0.5 * slicePixelSize + inputTexture.y * sliceInnerSize;
     float zOffset = inputTexture.z * (size - 1.0);
     float zSlice0 = floor(zOffset);
     float zSlice1 = zSlice0 + 1.0;
     float s0 = yOffset + (zSlice0 * sliceSize);
     float s1 = yOffset + (zSlice1 * sliceSize);
     vec4 sliceColor0 = texture2D(colorMap, vec2(xOffset, s0));
     vec4 sliceColor1 = texture2D(colorMap, vec2(xOffset, s1));
     
     return mix(sliceColor0, sliceColor1, zOffset - zSlice0).rgb;
 }
 
 float softLightCal(float a, float b){
     if(b<.5)
         return 2.*a*b+a*a*(1.-2.*b);
     else
         return 2.*a*(1.-b)+sqrt(a)*(2.*b-1.);
     
     return 0.;
 }

 float overlayCal(float a, float b){
     if(a<.5)
         return 2.*a*b;
     else
         return 1.-2.*(1.-a)*(1.-b);
     
     return 0.;
 }
 
 void main()
 {
     vec3 output_result = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     
     vec3 filter_result = applyColorMap(output_result, colorMapTexture);
     
     if (overlay1Enabled == 1) {
         vec3 overlay_image1 = texture2D(overlayTexture1, textureCoordinate).rgb;
         
         filter_result = vec3(softLightCal(filter_result.r, overlay_image1.r),
                              softLightCal(filter_result.g, overlay_image1.g),
                              softLightCal(filter_result.b, overlay_image1.b));
         
         filter_result = clamp(filter_result, 0.0, 1.0);
     }
     if (overlay2Enabled == 1) {
         vec3 overlay_image2 = texture2D(overlayTexture2, textureCoordinate).rgb;
         
         filter_result = vec3(overlayCal(filter_result.r, overlay_image2.r),
                              overlayCal(filter_result.g, overlay_image2.g),
                              overlayCal(filter_result.b, overlay_image2.b));
         
         filter_result = clamp(filter_result, 0.0, 1.0);
     }
     
     filter_result = mix(output_result, filter_result, filterMixPercentage);
     
     gl_FragColor = vec4(filter_result, 1.);
 }
);

