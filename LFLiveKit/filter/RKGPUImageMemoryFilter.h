//
//  RKGPUImageMemoryFilter.h
//  LFLiveKit
//
//  Created by Racing on 2017/2/5.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "GPUImageFilterGroup.h"

@class GPUImagePicture;

@interface RKGPUImageMemoryFilter : GPUImageFilterGroup {
    GPUImagePicture *lookupImageSource1;
    GPUImagePicture *lookupImageSource2;
    GPUImagePicture *lookupImageSource3;
}

@end
