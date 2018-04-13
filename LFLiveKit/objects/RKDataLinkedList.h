//
//  RKDataLinkedList.h
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RKDataLinkedList : NSObject

@property (nonatomic, readonly) NSData * _Nullable head;
@property (nonatomic, readonly) NSData * _Nullable tail;
@property (nonatomic, readonly) NSUInteger length;

- (void)pushHead:(nonnull NSData *)data;

- (nullable NSData *)popHead;

- (void)pushTail:(nonnull NSData *)data;

- (nullable NSData *)popTail;

@end
