//
//  RKGPUImageMemoryFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/12.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageMemoryFilter.h"
#import "GPUImagePicture.h"
#import "RKGPUImageColorMapFilter.h"
#import "RKGUPImageSoftLightFilter.h"
#import "RKGPUImageOverlayFilter.h"

@implementation RKGPUImageMemoryFilter

- (id)init;
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    UIImage *image1 = [UIImage imageNamed:@"memory_map"];
    UIImage *image2 = [UIImage imageNamed:@"overlay_softlight1"];
    UIImage *image3 = [UIImage imageNamed:@"overlay_softlight3"];

    NSAssert(image1 && image2 && image3, @"To use GPUImageAmatorkaFilter you need to add lookup_amatorka.png from GPUImage/framework/Resources to your application bundle.");
    
    lookupImageSource = [[GPUImagePicture alloc] initWithImage:image1];
    RKGPUImageColorMapFilter *colorMapFilter = [[RKGPUImageColorMapFilter alloc] init];
    [self addFilter:colorMapFilter];
    
    [lookupImageSource addTarget:colorMapFilter atTextureLocation:1];
    [lookupImageSource processImage];
    
    lookupImageSource2 = [[GPUImagePicture alloc] initWithImage:image2];
    
    RKGUPImageSoftLightFilter *softLightFilter = [[RKGUPImageSoftLightFilter alloc] init];
    [colorMapFilter addTarget:softLightFilter];
    [lookupImageSource2 addTarget:softLightFilter];
    [lookupImageSource2 processImage];
    [self addFilter:softLightFilter];
    
    lookupImageSource3 = [[GPUImagePicture alloc] initWithImage:image3];
    
    RKGPUImageOverlayFilter *overlayFilter = [[RKGPUImageOverlayFilter alloc] init];
    [softLightFilter addTarget:overlayFilter];
    [lookupImageSource3 addTarget:overlayFilter];
    [lookupImageSource3 processImage];
    [self addFilter:overlayFilter];
    
    self.initialFilters = [NSArray arrayWithObjects:colorMapFilter, nil];
    self.terminalFilter = overlayFilter;
    
    return self;
}


@end
