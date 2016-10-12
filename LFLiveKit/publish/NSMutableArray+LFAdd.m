//
//  NSMutableArray+LFAdd.m
//  YYKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "NSMutableArray+LFAdd.h"

@implementation NSMutableArray (YYAdd)

- (void)lfRemoveFirstObject {
    if (self.count) {
        [self removeObjectAtIndex:0];
    }
}

- (id)lfPopFirstObject {
    id obj = nil;
    if (self.count) {
        obj = self.firstObject;
        [self lfRemoveFirstObject];
    }
    return obj;
}

@end
