//
//  QBGLHefeFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLHefeFilter.h"
#import "QBGLDrawable.h"
#import "QBGLUtils.h"
#import "QBGLProgram.h"

char * const kQBHefeFilterVertex;
char * const kQBHefeFilterFragment;

@interface QBGLHefeFilter ()

@property (strong, nonatomic) QBGLDrawable *image1Drawable;
@property (strong, nonatomic) QBGLDrawable *image2Drawable;
@property (strong, nonatomic) QBGLDrawable *image3Drawable;
@property (strong, nonatomic) QBGLDrawable *image4Drawable;

@end

@implementation QBGLHefeFilter

- (instancetype) init {
    self = [self initWithVertexShader:kQBHefeFilterVertex fragmentShader:kQBHefeFilterFragment];
    if (self) {
        [self loadTextures];
    }
    return self;
}

- (void)loadTextures {
    [super loadTextures];
    _image1Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"edgeburn"] identifier:@"inputImageTexture2"];
    _image2Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"hefemap"] identifier:@"inputImageTexture3"];
    _image3Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"hefemetal"] identifier:@"inputImageTexture4"];
    _image4Drawable = [[QBGLDrawable alloc] initWithImage:[UIImage imageNamed:@"hefesoftlight"] identifier:@"inputImageTexture5"];
    [self.program setParameter:"strength" floatValue:1.0];
}

- (NSArray<QBGLDrawable*> *)renderTextures {
    return @[_image1Drawable, _image2Drawable, _image3Drawable, _image4Drawable];
}

@end


#define STRING(x) #x

char * const kQBHefeFilterVertex = STRING
(

);

char * const kQBHefeFilterFragment = STRING
(

);
