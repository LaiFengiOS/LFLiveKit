//
//  RKGPUImageColorFilter.h
//  LFLiveKit
//
//  Created by Racing on 2017/2/12.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "GPUImageFilterGroup.h"

@class GPUImagePicture;

@interface RKGPUImageColorFilter : GPUImageFilterGroup {
    GPUImagePicture *colorMapImageSource;
    GPUImagePicture *softLightImageSource;
    GPUImagePicture *overlayImageSource;
}
@property (copy, nonatomic, readonly) NSString *localizedName;

- (instancetype)initWithColorMap:(NSString *)colorMap softLight:(NSString *)softLight overlay:(NSString *)overlay;

@end
