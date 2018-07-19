//
//  RKLinkedList.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKLinkedList.h"

@interface RKLinkedNode : NSObject

@property (strong, nonatomic) RKLinkedNode *next;
@property (strong, nonatomic) RKLinkedNode *prev;
@property (strong, nonatomic) id object;

@end

@implementation RKLinkedNode

@end

@implementation RKLinkedList {
    RKLinkedNode *_head, *_tail;
}

- (id)head {
    return _head.object;
}

- (id)tail {
    return _tail.object;
}

- (void)pushHead:(nonnull id)obj {
    RKLinkedNode *node = [[RKLinkedNode alloc] init];
    node.object = obj;
    node.next = _head;
    _head.prev = node;
    _head = node;
    if (!_tail) {
        _tail = node;
    }
    _length++;
}

- (nullable id)popHead {
    if (!_head) {
        return nil;
    }
    _length--;
    RKLinkedNode *node = _head;
    _head = node.next;
    _head.prev = nil;
    return node.object;
}

- (void)pushTail:(nonnull id)obj {
    RKLinkedNode *node = [[RKLinkedNode alloc] init];
    node.object = obj;
    node.prev = _tail;
    _tail.next = node;
    _tail = node;
    if (!_head) {
        _head = node;
    }
    _length++;
}

- (nullable id)popTail {
    if (!_tail) {
        return nil;
    }
    _length--;
    RKLinkedNode *node = _tail;
    _tail = node.prev;
    _tail.next = nil;
    return node.object;
}

@end
