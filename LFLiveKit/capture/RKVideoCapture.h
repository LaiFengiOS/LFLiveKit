//
//  RKVideoCapture.h
//  LFLiveKit
//
//  Created by Ken Sun on 2018/1/11.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "LFVideoCaptureInterface.h"
#import <OpenGLES/EAGL.h>

@interface RKVideoCapture : NSObject <LFVideoCaptureInterface>

@property (strong, nonatomic, readonly) EAGLContext *eaglContext;
@property (strong, nonatomic) LFLiveVideoConfiguration *nextVideoConfiguration;

- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

- (nullable instancetype)initWithVideoConfiguration:(nullable LFLiveVideoConfiguration *)configuration
                                        eaglContext:(nullable EAGLContext *)glContext;

@end
