//
//  RKGPUImageMemoryFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/12.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageColorFilter.h"
#import "GPUImagePicture.h"
#import "RKGPUImageColorMapFilter.h"
#import "RKGUPImageSoftLightFilter.h"
#import "RKGPUImageOverlayFilter.h"

@implementation RKGPUImageColorFilter

- (instancetype)initWithColorMap:(NSString *)colorMap softLight:(NSString *)softLight overlay:(NSString *)overlay {
    if (!(self = [super init])) {
        return nil;
    }
    if (colorMap.length > 0) {
        UIImage *colorMapImage = [UIImage imageNamed:colorMap];
        NSAssert(colorMapImage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        colorMapImageSource = [[GPUImagePicture alloc] initWithImage:colorMapImage];
        RKGPUImageColorMapFilter *colorMapFilter = [[RKGPUImageColorMapFilter alloc] init];
        [self addFilter:colorMapFilter];
        
        [colorMapImageSource addTarget:colorMapFilter atTextureLocation:1];
        [colorMapImageSource processImage];
    }
    
    if (softLight.length > 0) {
        UIImage *softLightimage = [UIImage imageNamed:softLight];
        NSAssert(softLightimage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        softLightImageSource = [[GPUImagePicture alloc] initWithImage:softLightimage];
        
        RKGUPImageSoftLightFilter *softLightFilter = [[RKGUPImageSoftLightFilter alloc] init];
        if (filters.lastObject) {
            [filters.lastObject addTarget:softLightFilter];
        }
        [softLightImageSource addTarget:softLightFilter];
        [softLightImageSource processImage];
        [self addFilter:softLightFilter];
        
    }
    
    if (overlay.length > 0) {
        UIImage *overlayImage = [UIImage imageNamed:overlay];
        NSAssert(overlayImage, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
        
        overlayImageSource = [[GPUImagePicture alloc] initWithImage:overlayImage];
        
        RKGPUImageOverlayFilter *overlayFilter = [[RKGPUImageOverlayFilter alloc] init];
        if (filters.lastObject) {
            [filters.lastObject addTarget:overlayFilter];
        }
        [overlayImageSource addTarget:overlayFilter];
        [overlayImageSource processImage];
        [self addFilter:overlayFilter];
    }
    
    if (filters.count > 0) {
        self.initialFilters = [NSArray arrayWithObjects:filters.firstObject, nil];
        self.terminalFilter = filters.lastObject;
        return self;
        
    }
    
    return nil;
}

- (instancetype)init {
    if (!(self = [self initWithColorMap:nil softLight:nil overlay:nil])) {
        return nil;
    }
    
    return self;
}

@end
