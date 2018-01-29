//
//  QBGLContext.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/21.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import "QBGLFilterTypes.h"

@interface QBGLContext : NSObject

@property (strong, nonatomic, readonly) EAGLContext *glContext;
@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (nonatomic) CGSize viewPortSize;
@property (nonatomic) CGSize outputSize;

@property (nonatomic) QBGLFilterType colorFilterType;
@property (nonatomic) BOOL beautyEnabled;

- (instancetype)initWithContext:(EAGLContext *)context;

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)render;

- (void)renderToOutput;

- (void)setRotation:(float)degrees flipHorizontal:(BOOL)flip;

@end
