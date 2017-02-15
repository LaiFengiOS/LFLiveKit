//
//  RKGPUImageMemoryFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/12.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageColorFilter.h"
#import "GPUImageFilter.h"
#import "GPUImagePicture.h"
#import "RKGPUImageColorMapFilter.h"
#import "RKGUPImageSoftLightFilter.h"
#import "RKGPUImageOverlayFilter.h"

@implementation RKGPUImageColorFilter

#pragma mark - LifeCycle

- (instancetype)initWithColorMap:(NSString *)colorMap softLight:(NSString *)softLight overlay:(NSString *)overlay {
    if (!(self = [super init])) {
        return nil;
    }
    
    [self addFilter:[[GPUImageFilter alloc] init]];
    
    if (colorMap.length > 0) {
        UIImage *colorMapImage = [UIImage imageNamed:colorMap];
        NSAssert(colorMapImage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        colorMapImageSource = [[GPUImagePicture alloc] initWithImage:colorMapImage];
        RKGPUImageColorMapFilter *colorMapFilter = [[RKGPUImageColorMapFilter alloc] init];
        [filters.lastObject addTarget:colorMapFilter];

        [self addFilter:colorMapFilter];
        
        [colorMapImageSource addTarget:colorMapFilter atTextureLocation:1];
        [colorMapImageSource processImage];
    }
    
    if (softLight.length > 0) {
        UIImage *softLightimage = [UIImage imageNamed:softLight];
        NSAssert(softLightimage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        softLightImageSource = [[GPUImagePicture alloc] initWithImage:softLightimage];
        
        RKGUPImageSoftLightFilter *softLightFilter = [[RKGUPImageSoftLightFilter alloc] init];
        [filters.lastObject addTarget:softLightFilter];

        [self addFilter:softLightFilter];
        
        [softLightImageSource addTarget:softLightFilter];
        [softLightImageSource processImage];
        
    }
    
    if (overlay.length > 0) {
        UIImage *overlayImage = [UIImage imageNamed:overlay];
        NSAssert(overlayImage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        overlayImageSource = [[GPUImagePicture alloc] initWithImage:overlayImage];
        
        RKGPUImageOverlayFilter *overlayFilter = [[RKGPUImageOverlayFilter alloc] init];
        [filters.lastObject addTarget:overlayFilter];
        
        [self addFilter:overlayFilter];

        [overlayImageSource addTarget:overlayFilter];
        [overlayImageSource processImage];
    }
    
    self.initialFilters = @[filters.firstObject];
    self.terminalFilter = filters.lastObject;
    return self;
}

- (instancetype)init {
    if (!(self = [self initWithColorMap:nil softLight:nil overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"NORMAL_FILTER", nil);
}

@end
