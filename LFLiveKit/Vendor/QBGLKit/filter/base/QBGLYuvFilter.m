//
//  QBGLYuvFilter.m
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLYuvFilter.h"
#import "QBGLProgram.h"
#import "QBGLDrawable.h"

char * const kQBGLYuvFilterVertex;
char * const kQBGLYuvFilterFragment;

@interface QBGLYuvFilter ()

@property (strong, nonatomic) QBGLDrawable *yDrawable;
@property (strong, nonatomic) QBGLDrawable *uvDrawable;

// watermark
@property (strong, nonatomic) QBGLDrawable *watermarkDrawable;
@property (strong, nonatomic) QBGLDrawable *mirrorWatermarkDrawable;
@property (assign, nonatomic) CGRect watermarkRect;
@property (assign, nonatomic) CGRect mirrorWatermarkRect;
@property (assign, nonatomic) CGFloat watermarkAlpha;

@end

@implementation QBGLYuvFilter

- (instancetype)init {
    return [self initWithVertexShader:kQBGLYuvFilterVertex fragmentShader:kQBGLYuvFilterFragment];
}

- (instancetype)initWithWatermarkView:(UIView *)watermarkView {
    if (self = [self init]) {
        if (watermarkView) {
            _watermarkDrawable = [[QBGLDrawable alloc] initWithView:watermarkView identifier:@"watermarkTexture" horizontalFlip:NO verticalFlip:NO];
            _mirrorWatermarkDrawable = [[QBGLDrawable alloc] initWithView:watermarkView identifier:@"mirrorWatermarkTexture" horizontalFlip:YES verticalFlip:NO];
            _watermarkRect = CGRectMake(self.outputSize.width - CGRectGetMaxX(watermarkView.frame), CGRectGetMinY(watermarkView.frame), CGRectGetWidth(watermarkView.frame), CGRectGetHeight(watermarkView.frame));
            _mirrorWatermarkRect = watermarkView.frame;
            _watermarkAlpha = watermarkView.alpha;
        }
    }
    return self;
}

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer {
    int width = (int) CVPixelBufferGetWidth(pixelBuffer);
    int height = (int) CVPixelBufferGetHeight(pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    CVOpenGLESTextureRef luminanceTextureRef, chrominanceTextureRef;
    
    // y texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE, width, height, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &luminanceTextureRef);
    
    _yDrawable = [[QBGLDrawable alloc] initWithTextureRef:luminanceTextureRef identifier:@"yTexture"];
    
    // uv texture
    CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCacheRef, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, width/2, height/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &chrominanceTextureRef);
    
    _uvDrawable = [[QBGLDrawable alloc] initWithTextureRef:chrominanceTextureRef identifier:@"uvTexture"];
    
    CFRelease(luminanceTextureRef);
    CFRelease(chrominanceTextureRef);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    NSMutableArray *array = [NSMutableArray arrayWithArray:[super renderTextures]];
    if (_yDrawable && _uvDrawable ) {
        [array addObject:_yDrawable];
        [array addObject:_uvDrawable];
    }
    if (_watermarkDrawable) {
        [array addObject:_watermarkDrawable];
    }
    if (_mirrorWatermarkDrawable) {
        [array addObject:_mirrorWatermarkDrawable];
    }
    return array;
}

- (void)setAdditionalUniformVarsForRender {
    CGRect targetRect = (self.mirrorWatermark ? self.mirrorWatermarkRect : self.watermarkRect);
    if (CGRectEqualToRect(targetRect, CGRectZero)) {
        const GLfloat rect[] = {0.f, 0.f, 0.f, 0.f};
        glUniform4fv([self.program uniformWithName:"watermarkRect"], 1, rect);
    } else {
        CGFloat xStart = CGRectGetMinX(targetRect) / self.outputSize.width;
        CGFloat yStart = CGRectGetMinY(targetRect) / self.outputSize.height;
        CGFloat xEnd = xStart + CGRectGetWidth(targetRect) / self.outputSize.width;
        CGFloat yEnd = yStart + CGRectGetHeight(targetRect) / self.outputSize.height;
        const GLfloat rect[] = {yStart, xStart, yEnd, xEnd};
        glUniform4fv([self.program uniformWithName:"watermarkRect"], 1, rect);
    }
    
    [self.program setParameter:"watermarkAlpha" floatValue:self.watermarkAlpha];
    [self.program setParameter:"mirrorWatermark" intValue:(self.mirrorWatermark ? 1 : 0)];
}

- (void)setOutputSize:(CGSize)outputSize {
    if (CGSizeEqualToSize(outputSize, self.outputSize))
        return;
    
    [super setOutputSize:outputSize];
    
    [self updateWatermarkRect];
}

- (void)updateWatermarkRect {
    self.watermarkRect = CGRectMake(self.outputSize.width - CGRectGetMaxX(self.mirrorWatermarkRect), CGRectGetMinY(self.mirrorWatermarkRect), CGRectGetWidth(self.mirrorWatermarkRect), CGRectGetHeight(self.mirrorWatermarkRect));
}

@end

char * const kQBGLYuvFilterVertex = STRING
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

char * const kQBGLYuvFilterFragment = STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D yTexture;
 uniform sampler2D uvTexture;
 
 uniform sampler2D watermarkTexture;
 uniform sampler2D mirrorWatermarkTexture;
 uniform vec4 watermarkRect;
 uniform float watermarkAlpha;
 uniform int mirrorWatermark;
 
 const mat3 yuv2rgbMatrix = mat3(1.0, 1.0, 1.0,
                                 0.0, -0.343, 1.765,
                                 1.4, -0.711, 0.0);
 
 vec3 rgbFromYuv(sampler2D yTexture, sampler2D uvTexture, vec2 textureCoordinate) {
     float y = texture2D(yTexture, textureCoordinate).r;
     float u = texture2D(uvTexture, textureCoordinate).r - 0.5;
     float v = texture2D(uvTexture, textureCoordinate).a - 0.5;
     return yuv2rgbMatrix * vec3(y, u, v);
 }
 
 bool validWatermarkRect() {
     return (watermarkRect.b - watermarkRect.r) > 0.0 && (watermarkRect.a - watermarkRect.g) > 0.0;
 }
 
 void main()
 {
     vec3 centralColor = rgbFromYuv(yTexture, uvTexture, textureCoordinate).rgb;
     if (validWatermarkRect() && textureCoordinate.x >= watermarkRect.r && textureCoordinate.x <= watermarkRect.b && textureCoordinate.y >= watermarkRect.g && textureCoordinate.y <= watermarkRect.a) {
         vec2 watermarkTextureCoordinate = vec2((textureCoordinate.y - watermarkRect.g) / (watermarkRect.a - watermarkRect.g), (textureCoordinate.x - watermarkRect.r) / (watermarkRect.b - watermarkRect.r));
         if (mirrorWatermark == 1) {
             vec4 watermarkTextureColor = texture2D(mirrorWatermarkTexture, watermarkTextureCoordinate);
             gl_FragColor = vec4(mix(centralColor, watermarkTextureColor.rgb, watermarkTextureColor.a * watermarkAlpha), 1.0);
         } else {
             vec4 watermarkTextureColor = texture2D(watermarkTexture, watermarkTextureCoordinate);
             gl_FragColor = vec4(mix(centralColor, watermarkTextureColor.rgb, watermarkTextureColor.a * watermarkAlpha), 1.0);
         }

     } else {
         gl_FragColor = vec4(centralColor, 1.0);
     }
 }
 );
