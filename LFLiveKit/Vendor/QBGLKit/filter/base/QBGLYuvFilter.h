//
//  QBGLYuvFilter.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/2/1.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLFilter.h"

@interface QBGLYuvFilter : QBGLFilter

- (void)loadYUV:(CVPixelBufferRef)pixelBuffer;

@end
