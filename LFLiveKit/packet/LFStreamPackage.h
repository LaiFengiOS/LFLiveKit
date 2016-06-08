//
//  LFStreamPackage.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LFAudioFrame.h"
#import "LFVideoFrame.h"

/// 编码器抽象的接口
@protocol LFStreamPackage <NSObject>
@required
- (nullable instancetype)initWithVideoSize:(CGSize)videoSize;
- (nullable NSData*)aaCPacket:(nullable LFAudioFrame*)audioFrame;
- (nullable NSData*)h264Packet:(nullable LFVideoFrame*)videoFrame;
@end

