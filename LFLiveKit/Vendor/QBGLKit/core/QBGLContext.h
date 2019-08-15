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
#import <AVFoundation/AVFoundation.h>
#import "QBGLFilterTypes.h"

@interface QBGLContext : NSObject

@property (strong, nonatomic, readonly) EAGLContext *glContext;
@property (nonatomic, readonly) CVPixelBufferRef outputPixelBuffer;

@property (nonatomic) CGSize outputSize;
@property (nonatomic) CGSize viewPortSize;

@property (nonatomic) QBGLFilterType colorFilterType;
@property (nonatomic) QBGLFilterType colorFilterTypeForRender;

@property (nonatomic) BOOL beautyEnabled;

@property (strong, nonatomic) UIView *animationView;

@property (assign, nonatomic, readonly) BOOL hasMagicFilter;
@property (assign, nonatomic, readonly) BOOL hasMultiFilters;

- (instancetype)initWithContext:(EAGLContext *)context animationView:(UIView *)animationView;

- (void)loadYUVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)loadBGRAPixelBuffer:(CVPixelBufferRef)pixelBuffer;

- (void)render;

- (void)renderToOutput;

- (void)setDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror;

#pragma mark - Animation

- (void)setPreviewAnimationOrientationWithCameraPosition:(AVCaptureDevicePosition)position mirror:(BOOL)mirror;

#pragma mark - Preview

- (void)setPreviewDisplayOrientation:(UIInterfaceOrientation)orientation cameraPosition:(AVCaptureDevicePosition)position;
- (void)configInputFilterToPreview;
- (void)renderInputFilterToPreview;
- (void)renderInputFilterToOutputFilter;
- (void)renderOutputFilterToPreview;

@end
