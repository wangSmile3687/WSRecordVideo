//
//  ViewController.m
//  WSRecordVideo
//
//  Created by WangS on 16/12/23.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import "ViewController.h"
#import "WSRecordVideoViewController.h"

@interface ViewController ()
@property (nonatomic,strong) UIButton *recordVideoBtn;
@end

@implementation ViewController

- (UIButton *)recordVideoBtn{
    if (!_recordVideoBtn) {
        _recordVideoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _recordVideoBtn.frame = CGRectMake(40, 200, [UIScreen mainScreen].bounds.size.width-80, 30);
        _recordVideoBtn.backgroundColor = [UIColor cyanColor];
        [_recordVideoBtn addTarget:self action:@selector(recordVideoBtnClick) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_recordVideoBtn];
    }
    return _recordVideoBtn;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self addRecordVideoBtn];
}
- (void)addRecordVideoBtn{
    [self.recordVideoBtn setTitle:@"点击录制视频" forState:UIControlStateNormal];
}
- (void)recordVideoBtnClick{
    WSRecordVideoViewController *vc = [[WSRecordVideoViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [self presentViewController:nav animated:YES completion:nil];
}



@end
