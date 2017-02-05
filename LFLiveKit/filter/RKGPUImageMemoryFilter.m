//
//  RKGPUImageMemoryFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/5.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageMemoryFilter.h"
#import "GPUImagePicture.h"
#import "GPUImageLookupFilter.h"

@implementation RKGPUImageMemoryFilter

- (instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    
    UIImage *image1 = [UIImage imageNamed:@"memory_map"];
    UIImage *image2 = [UIImage imageNamed:@"overlay_softlight1"];
    UIImage *image3 = [UIImage imageNamed:@"overlay_softlight3"];
    
    NSAssert(image1 && image2 && image3,
             @"To use GPUImageSoftEleganceFilter you need to add lookup_soft_elegance_1.png and lookup_soft_elegance_2.png from GPUImage/framework/Resources to your application bundle.");
    
    GPUImageLookupFilter *lookupFilter1 = [[GPUImageLookupFilter alloc] init];
    [self addFilter:lookupFilter1];
    
    lookupImageSource1 = [[GPUImagePicture alloc] initWithImage:image1];
    [lookupImageSource1 addTarget:lookupFilter1 atTextureLocation:1];
    [lookupImageSource1 processImage];
    
    GPUImageLookupFilter *lookupFilter2 = [[GPUImageLookupFilter alloc] init];
    [lookupFilter1 addTarget:lookupFilter2];
    [self addFilter:lookupFilter2];
    
    lookupImageSource2 = [[GPUImagePicture alloc] initWithImage:image2];
    [lookupImageSource2 addTarget:lookupFilter2];
    [lookupImageSource2 processImage];
    
    GPUImageLookupFilter *lookupFilter3 = [[GPUImageLookupFilter alloc] init];
    [lookupFilter2 addTarget:lookupFilter3];
    [self addFilter:lookupFilter3];
    
    lookupImageSource3 = [[GPUImagePicture alloc] initWithImage:image3];
    [lookupImageSource3 addTarget:lookupFilter3];
    [lookupImageSource3 processImage];
    
    self.initialFilters = @[lookupFilter1];
    self.terminalFilter = lookupFilter3;
    
    return self;
}

@end
