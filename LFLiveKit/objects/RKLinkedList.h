//
//  RKLinkedList.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RKLinkedList<__covariant T> : NSObject

@property (nonatomic, readonly) T _Nullable head;
@property (nonatomic, readonly) T _Nullable tail;
@property (nonatomic, readonly) NSUInteger length;

- (void)pushHead:(nonnull T)object;
- (nullable T)popHead;
- (void)pushTail:(nonnull T)object;
- (nullable T)popTail;

@end
