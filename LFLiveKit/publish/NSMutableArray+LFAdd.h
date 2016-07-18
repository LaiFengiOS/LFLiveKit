//
//  NSMutableArray+LFAdd.h
//  YYKit
//
//  Created by admin on 16/5/20.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (YYAdd)

/**
 Removes and returns the object with the lowest-valued index in the array.
 If the array is empty, it just returns nil.
 
 @return The first object, or nil.
 */
- (nullable id)lfPopFirstObject;

@end
