//
//  RKVideoCapture.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "LFVideoCaptureInterface.h"

@interface RKVideoCapture : NSObject <LFVideoCaptureInterface>

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

@end
