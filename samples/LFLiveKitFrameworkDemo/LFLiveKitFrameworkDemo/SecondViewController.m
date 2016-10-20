//
//  SecondViewController.m
//  LFLiveKitFrameworkDemo
//
//  Created by admin on 2016/10/20.
//  Copyright © 2016年 admin. All rights reserved.
//

#import "SecondViewController.h"
#import "LFLivePreview.h"

@interface SecondViewController ()

@end

@implementation SecondViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self.view addSubview:[[LFLivePreview alloc] initWithFrame:self.view.bounds]];
}


- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}


@end
