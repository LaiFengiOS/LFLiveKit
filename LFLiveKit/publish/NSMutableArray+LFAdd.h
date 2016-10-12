//
//  NSMutableArray+LFAdd.h
//  YYKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
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
