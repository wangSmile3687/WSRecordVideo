//
//  WSPlayVideoViewController.m
//  WSRecordVideo
//
//  Created by WangS on 16/12/23.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import "WSPlayVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ZFPlayer.h"
#define ScreenW [UIScreen mainScreen].bounds.size.width
#define ScreenH [UIScreen mainScreen].bounds.size.height
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
@interface WSPlayVideoViewController ()<ZFPlayerDelegate,UIAlertViewDelegate>
@property(nonatomic, strong)ZFPlayerView                *playerView;
@property(nonatomic, assign)BOOL                        isPlaying;/** 离开页面时候是否在播放 */
@property(nonatomic, strong)ZFPlayerModel               *playerModel;
@property(nonatomic, strong)UIView                      *playVideoView;
@property(nonatomic, strong)UILabel                     *previewVideoLab;
@end

@implementation WSPlayVideoViewController

- (UIView *)playVideoView{
    
    if (!_playVideoView) {
        _playVideoView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, ScreenW, ScreenW * (9.0f/16.0f) + 31)];
        _playVideoView.backgroundColor = [UIColor whiteColor];
        [self.view addSubview:_playVideoView];
    }
    return _playVideoView;
}
- (UILabel *)previewVideoLab{
    if (!_previewVideoLab) {
        _previewVideoLab = [[UILabel alloc] init];
        _previewVideoLab.font = [UIFont boldSystemFontOfSize:16];
        _previewVideoLab.textColor = [UIColor blackColor];
        [self.view addSubview:_previewVideoLab];
    }
    return _previewVideoLab;
}
- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    if (self.navigationController.viewControllers.count == 2 && self.playerView && self.isPlaying) {
        self.isPlaying = NO;
        [self.playerView play];
    }
    
}
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    // push出下一级页面时候暂停
    if (self.navigationController.viewControllers.count == 3 && self.playerView && !self.playerView.isPauseByUser){
        self.isPlaying = YES;
        [self.playerView pause];
    }
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setUpNav];
//    self.previewVideoLab.text = @"预览视频";
    [self.view addSubview:self.playVideoView];
   [self palyVideo];
}
- (void)setUpNav{
    UIView *navView=[[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenW, 64)];
    navView.backgroundColor=[UIColor whiteColor];
    [self.view addSubview:navView];
    
    UIButton *backBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame=CGRectMake(0, 20, 60, 44);
    backBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 20);
    [backBtn setImage:[UIImage imageNamed:@"arrowBack"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:backBtn];
    
    UILabel *titleLab = [[UILabel alloc] initWithFrame:CGRectMake(90, 27, ScreenW-180, 30)];
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.text = @"预览视频";
    titleLab.textColor = [UIColor blackColor];
    titleLab.font = [UIFont systemFontOfSize:18];
    [navView addSubview:titleLab];
    
    
    UIImageView *lineImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 63.5, ScreenW, 0.5)];
    lineImgView.backgroundColor = UIColorFromRGB(0xebddd5);
    [navView addSubview:lineImgView];
}
- (void)backBtnClick{
    [self.navigationController popViewControllerAnimated:YES];
}
#pragma mark - 视频播放
- (void)palyVideo{
    self.playerView = [[ZFPlayerView alloc] init];
    // 指定控制层(可自定义)
    ZFPlayerControlView *controlView = [[ZFPlayerControlView alloc] init];
    // 设置控制层和播放模型
    [self.playerView playerControlView:controlView playerModel:self.playerModel];
    // 设置代理
    self.playerView.delegate = self;
    // 打开预览图
    self.playerView.hasPreviewView = YES;
    
}

#pragma mark - ZFPlayerDelegate
- (void)zf_playerBackAction{
    [self.navigationController popViewControllerAnimated:YES];
}
#pragma mark - Getter
- (ZFPlayerModel *)playerModel{
    if (!_playerModel) {
        _playerModel                  = [[ZFPlayerModel alloc] init];
        _playerModel.videoURL         = self.videoURL;
        _playerModel.placeholderImage = self.coverImage;
        _playerModel.fatherView       = self.playVideoView;
        
    }
    return _playerModel;
}



@end
