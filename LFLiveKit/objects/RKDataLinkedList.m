//
//  RKDataLinkedList.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKDataLinkedList.h"

@interface RKDataNode : NSObject

@property (strong, nonatomic) RKDataNode *next;
@property (strong, nonatomic) RKDataNode *prev;
@property (strong, nonatomic) NSData *data;

@end

@implementation RKDataNode

@end

@implementation RKDataLinkedList {
    RKDataNode *_head, *_tail;
}

- (NSData *)head {
    return _head.data;
}

- (NSData *)tail {
    return _tail.data;
}

- (void)pushHead:(nonnull NSData *)data {
    RKDataNode *node = [[RKDataNode alloc] init];
    node.data = data;
    node.next = _head;
    _head.prev = node;
    _head = node;
    if (!_tail) {
        _tail = node;
    }
}

- (nullable NSData *)popHead {
    if (!_head) {
        return nil;
    }
    RKDataNode *node = _head;
    _head = node.next;
    _head.prev = nil;
    return node.data;
}

- (void)pushTail:(nonnull NSData *)data {
    RKDataNode *node = [[RKDataNode alloc] init];
    node.data = data;
    node.prev = _tail;
    _tail.next = node;
    _tail = node;
    if (!_head) {
        _head = node;
    }
}

- (nullable NSData *)popTail {
    if (!_tail) {
        return nil;
    }
    RKDataNode *node = _tail;
    _tail = node.prev;
    _tail.next = nil;
    return node.data;
}

@end
