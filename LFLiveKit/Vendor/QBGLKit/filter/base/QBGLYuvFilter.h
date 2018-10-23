//
//  QBGLYuvFilter.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLFilter.h"

@interface QBGLYuvFilter : QBGLFilter

@property (assign, nonatomic) BOOL mirrorWatermark;

- (instancetype)initWithWatermarkView:(UIView *)watermarkView;
- (void)loadYUV:(CVPixelBufferRef)pixelBuffer;

@end
