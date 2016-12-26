//
//  WSPlayVideoViewController.h
//  WSRecordVideo
//
//  Created by WangS on 16/12/23.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WSPlayVideoViewController : UIViewController
@property (nonatomic,  copy) NSString                   *type;
@property (nonatomic,strong) NSURL                      *videoURL;
@property (nonatomic,strong) UIImage                    *coverImage;//视频第一帧图
@property (nonatomic,  copy) NSString                   *audioName;
@property(nonatomic, assign) NSInteger                  audioTime;
@property (nonatomic,copy) void(^resetVideoBlock)(void);
@end
