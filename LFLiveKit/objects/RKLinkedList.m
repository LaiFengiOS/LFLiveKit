//
//  RKLinkedList.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKLinkedList.h"

@interface RKLinkedListNode : NSObject

@property (strong, nonatomic) RKLinkedListNode *next;
@property (strong, nonatomic) RKLinkedListNode *prev;
@property (strong, nonatomic) id object;

@end


@implementation RKLinkedListNode
@end


@implementation RKLinkedList {
    RKLinkedListNode *_head, *_tail;
}

- (nullable id)head {
    return _head.object;
}

- (nullable id)tail {
    return _tail.object;
}

- (void)pushHead:(nonnull id)object {
    RKLinkedListNode *node = [[RKLinkedListNode alloc] init];
    node.object = object;
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
    RKLinkedListNode *node = _head;
    id obj = node.object;
    _head = node.next;
    _head.prev = nil;
    if (!_head) {
        _tail = nil;
    }
    _length--;
    return obj;
}

- (void)pushTail:(nonnull id)object {
    RKLinkedListNode *node = [[RKLinkedListNode alloc] init];
    node.object = object;
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
    RKLinkedListNode *node = _tail;
    id obj = node.object;
    _tail = node.prev;
    _tail.next = nil;
    if (!_tail) {
        _head = nil;
    }
    _length--;
    return obj;
}

@end
