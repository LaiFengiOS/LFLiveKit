//
//  RKReplayKitGLContext.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface RKReplayKitGLContext : NSObject

@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (nonatomic) CGSize canvasSize;

- (instancetype)initWithCanvasSize:(CGSize)canvasSize;

- (void)setRotation:(float)degrees;

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)render;

@end
