//
//  RKLinkedList.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RKLinkedList : NSObject

@property (nonatomic, readonly) id _Nullable head;
@property (nonatomic, readonly) id _Nullable tail;
@property (nonatomic, readonly) NSUInteger length;

- (void)pushHead:(nonnull id)obj;

- (nullable id)popHead;

- (void)pushTail:(nonnull id)obj;

- (nullable id)popTail;

@end
