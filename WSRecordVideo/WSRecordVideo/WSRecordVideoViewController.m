//
//  WSRecordVideoViewController.m
//  WSRecordVideo
//
//  Created by WangS on 16/12/23.
//  Copyright © 2016年 WangS. All rights reserved.
//

#import "WSRecordVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIView+Tools.h"
#import "NSString+Utils.h"
#import "WSPlayVideoViewController.h"

#define ScreenW [UIScreen mainScreen].bounds.size.width
#define ScreenH [UIScreen mainScreen].bounds.size.height
#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define TIMER_INTERVAL 1
#define VIDEO_FOLDER @"videoFolder"
#define MINTIME 30.0f
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface WSRecordVideoViewController ()<AVCaptureFileOutputRecordingDelegate,UIAlertViewDelegate>

@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (strong,nonatomic) UIView *viewContainer;//视频容器
@property (strong,nonatomic) UIImageView *focusCursor; //聚焦光标
@property (strong,nonatomic) NSURL *outputFileURL;
@property (strong,nonatomic) UIImageView *videoRemindImg;//提示框
@property (strong,nonatomic) UILabel *videoRemindLab;//提示语
@property (strong,nonatomic) NSMutableArray *urlArray;//保存视频片段的数组
@property (strong,nonatomic) UIImage *coverImg;//视频第一帧
@property (assign,nonatomic) BOOL firstPic;//第一帧
@property (weak,nonatomic) UILabel *timeLab;
@property (weak,nonatomic) UIButton *completeRecordBtn;//完成录制
@property (weak,nonatomic) UIButton *resetRecordBtn;//重新录制
@property (copy,nonatomic) NSString *fileNameStr;//文件地址
@property (strong,nonatomic) UIImageView *tipRecordImg;//录制提示
@property (strong,nonatomic) UIView *bottomView;
 
@end

@implementation WSRecordVideoViewController

{
    NSInteger currentTime; //当前视频长度
    NSTimer *countTimer; //计时器
    UIView* progressPreView; //进度条
    float progressStep; //进度条每次变长的最小单位
    float preLayerWidth;//镜头宽
    float preLayerHeight;//镜头高
    float preLayerHWRate; //高，宽比
    UIButton *shootBt;//录制按钮
    UIButton *flashBt;//闪光灯
    UIButton *cameraBt;//切换摄像头
    float totalTime; //视频总长度 默认180秒
}

- (NSMutableArray *)urlArray{
    if (!_urlArray) {
        _urlArray = [NSMutableArray new];
    }
    return _urlArray;
}
- (UIImageView *) videoRemindImg{
    if (!_videoRemindImg) {
        _videoRemindImg = [[UIImageView alloc] initWithFrame:CGRectMake(ScreenW/(totalTime/MINTIME)-40, 64+62+preLayerHeight+23-35, 80, 25)];
        _videoRemindImg.image = [UIImage imageNamed:@"videoRemindImg"];
        [self.view addSubview:self.videoRemindImg];
    }
    return _videoRemindImg;
}
- (UILabel *) videoRemindLab{
    if (!_videoRemindLab) {
        _videoRemindLab = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 20)];
        _videoRemindLab.text = @"至少录到这里";
        _videoRemindLab.textColor = [UIColor whiteColor];
        _videoRemindLab.font = [UIFont systemFontOfSize:12];
        _videoRemindLab.textAlignment = NSTextAlignmentCenter;
        [self.videoRemindImg addSubview:self.videoRemindLab];
    }
    return _videoRemindLab;
}
- (UIImageView *)tipRecordImg{
    if (!_tipRecordImg) {
        _tipRecordImg = [[UIImageView alloc] initWithFrame:CGRectMake((ScreenW-200)/2, CGRectGetMaxY(shootBt.frame)-10, 200, 115)];
        [self.bottomView addSubview:_tipRecordImg];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tipRecordImgTapClick)];
        _tipRecordImg.userInteractionEnabled = YES;
        [_tipRecordImg addGestureRecognizer:tap];
    }
    return _tipRecordImg;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _firstPic = YES;
    //视频最大时长 默认180秒
    if (totalTime==0) {
        totalTime = 180.0;
    }
    currentTime = -1;
    preLayerWidth = ScreenW;
    preLayerHeight = ceilf(9.0f/16.0f * ScreenW);
    preLayerHWRate = preLayerHeight/preLayerWidth;
    progressStep = ScreenW*TIMER_INTERVAL/totalTime;
    
    [self createVideoFolderIfNotExist];
    [self initCapture];
    [self setUpNav];
    [self addUI];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"tipRecordImg"]) {
        self.tipRecordImg.image = [UIImage imageNamed:@"recordVideoRecordBtn"];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)tipRecordImgTapClick{
    [self.tipRecordImg removeFromSuperview];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"tipRecordImg"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (void)appDidEnterBackground{//进入后台
    [self stopTimer];
    [self.captureMovieFileOutput stopRecording];//停止录制
    cameraBt.hidden = NO;
    shootBt.selected = NO;
    [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xff5a5f) forState:UIControlStateNormal];
    self.resetRecordBtn.enabled = YES;
}
//-(BOOL)prefersStatusBarHidden{
//    return true;
//}
- (void)setUpNav{
    UIView *navView=[[UIView alloc] initWithFrame:CGRectMake(0, 0, ScreenW, 64)];
    navView.backgroundColor=[UIColor whiteColor];
    [self.view addSubview:navView];
    
    UIButton *backBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame=CGRectMake(0, 20, 60, 44);
    backBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 20);
    [backBtn setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:backBtn];
    
    UILabel *titleLab = [[UILabel alloc] initWithFrame:CGRectMake(90, 27, ScreenW-180, 30)];
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.text = @"录制视频";
    titleLab.textColor = [UIColor blackColor];
    titleLab.font = [UIFont systemFontOfSize:18];
    [navView addSubview:titleLab];
    
    UIButton *resetRecordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    resetRecordBtn.frame = CGRectMake(ScreenW-90, 27, 90, 30);
    resetRecordBtn.enabled = NO;
    resetRecordBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [resetRecordBtn setTitle:@"重新录制" forState:UIControlStateNormal];
    [resetRecordBtn setTitleColor:UIColorFromRGB(0xb8b8b8) forState:UIControlStateNormal];
    [resetRecordBtn addTarget:self action:@selector(resetRecordBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [navView addSubview:resetRecordBtn];
    self.resetRecordBtn = resetRecordBtn;
    
    UIImageView *lineImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 63.5, ScreenW, 0.5)];
    lineImgView.backgroundColor = UIColorFromRGB(0xebddd5);
    [navView addSubview:lineImgView];
}
- (void)addUI{
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, ScreenW, 62)];
    topView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:topView];
    
    UILabel *timeLab=[[UILabel alloc] initWithFrame:CGRectMake(100, 16, ScreenW-200, 30)];
    timeLab.textAlignment=NSTextAlignmentCenter;
    timeLab.text=@"00:00";
    timeLab.font=[UIFont systemFontOfSize:16];
    timeLab.textColor=UIColorFromRGB(0xff5a5f);
    [topView addSubview:timeLab];
    self.timeLab = timeLab;
    
    flashBt = [[UIButton alloc]initWithFrame:CGRectMake(ScreenW-100, 6, 50, 50)];
    flashBt.hidden = YES;
    [flashBt addTarget:self action:@selector(flashBtTap:) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:flashBt];
    
    cameraBt = [[UIButton alloc]initWithFrame:CGRectMake(ScreenW-50, 6, 50, 50)];
    [cameraBt setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [cameraBt addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:cameraBt];
    
    
    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0,64+62+preLayerHeight+27, ScreenW,  ScreenH-(64+62+preLayerHeight+27))];
    bottomView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:bottomView];
    self.bottomView = bottomView;
    
    shootBt = [UIButton buttonWithType:UIButtonTypeCustom];
    shootBt.frame = CGRectMake((ScreenW-80)/2, 50, 80, 80);
    [shootBt setImage:[UIImage imageNamed:@"recordNor"] forState:UIControlStateNormal];
    [shootBt setImage:[UIImage imageNamed:@"recordSelect"] forState:UIControlStateSelected];
    [shootBt addTarget:self action:@selector(shootButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:shootBt];
    
    
    UIButton *completeRecordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    completeRecordBtn.frame = CGRectMake((ScreenW-180)/2, 64+80+52, 180, 30);
    completeRecordBtn.hidden = YES;
    completeRecordBtn.titleLabel.font = [UIFont systemFontOfSize:17];
    completeRecordBtn.layer.cornerRadius = 15;
    completeRecordBtn.clipsToBounds = YES;
    [completeRecordBtn setTitle:@"录制完成，下一步" forState:UIControlStateNormal];
    [completeRecordBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    completeRecordBtn.backgroundColor = UIColorFromRGB(0xff5a5f);
    [completeRecordBtn addTarget:self action:@selector(completeRecordBtnClick) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:completeRecordBtn];
    self.completeRecordBtn = completeRecordBtn;
}
#pragma mark - UIButton点击事件
- (void)resetRecordBtnClick{
    _firstPic = YES;
    //还原数据-----------
    [self deleteAllVideos];
    currentTime = -1;
    self.timeLab.text = @"00:00";
    shootBt.selected = NO;
    shootBt.hidden = NO;
    self.completeRecordBtn.hidden = YES;
    [progressPreView setFrame:CGRectMake(0, 64+62+preLayerHeight+23, 0, 4)];
    self.videoRemindImg.hidden = YES;
}
- (void)completeRecordBtnClick{
    self.completeRecordBtn.enabled = NO;
    [self save:self.urlArray];
}
-(void)backBtnClick{
    if (currentTime > 0) {
        [self stopTimer];
        [self.captureMovieFileOutput stopRecording];//停止录制
        cameraBt.hidden = NO;
        shootBt.selected = NO;
        [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xff5a5f) forState:UIControlStateNormal];
        self.resetRecordBtn.enabled = YES;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"退出后您录制的内容将不会保存，确认退出" message:@"" delegate:self cancelButtonTitle:@"退出" otherButtonTitles:@"继续录制", nil];
        [alert show];
    }else{
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}
-(void)initCapture{
    
    //视频高度加进度条（10）高度
    self.viewContainer = [[UIView alloc]initWithFrame:CGRectMake(0, 64+62, preLayerWidth, preLayerHeight)];
    [self.view addSubview:self.viewContainer];
    
    self.focusCursor = [[UIImageView alloc]initWithFrame:CGRectMake(100, 100, 50, 50)];
    [self.focusCursor setImage:[UIImage imageNamed:@"focusImg"]];
    self.focusCursor.alpha = 0;
    [self.viewContainer addSubview:self.focusCursor];
    
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset640x480;
    }
    
    //获得输入设备
    AVCaptureDevice *captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];//取得前置摄像头
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureMovieFileOutput alloc]init];
    
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoStabilizationSupported ]) {
            captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
        }
    }
    
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer= self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=  CGRectMake(0, 0, preLayerWidth, preLayerHeight);
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
    [self addGenstureRecognizer];
    
    UIView * progressBackView = [[UIView alloc] initWithFrame:CGRectMake(0, 64+62+preLayerHeight,ScreenW, 27)];
    progressBackView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:progressBackView];
    UIView * progressBottomView = [[UIView alloc] initWithFrame:CGRectMake(0, 64+62+preLayerHeight+23,ScreenW, 4)];
    progressBottomView.backgroundColor = UIColorFromRGB(0xd6d6d6);
    [self.view addSubview:progressBottomView];
    progressPreView = [[UIView alloc]initWithFrame:CGRectMake(0, 64+62+preLayerHeight+23, 0, 4)];
    progressPreView.backgroundColor = UIColorFromRGB(0xff5a5f);
    [progressPreView makeCornerRadius:2 borderColor:nil borderWidth:0];
    [self.view addSubview:progressPreView];
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(ScreenW/(totalTime/MINTIME), 0, 1, 4)];
    imgView.backgroundColor = UIColorFromRGB(0xff5a5f);
    [progressBottomView addSubview:imgView];
}

-(void)flashBtTap:(UIButton*)bt{
    if (bt.selected == YES) {
        bt.selected = NO;
        [flashBt setImage:[UIImage imageNamed:@"flashOpen"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOff];
    }else{
        bt.selected = YES;
        [flashBt setImage:[UIImage imageNamed:@"flashClose"] forState:UIControlStateNormal];
        [self setTorchMode:AVCaptureTorchModeOn];
    }
}

-(void)startTimer{
    countTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
    // [[NSRunLoop currentRunLoop] addTimer:countTimer forMode:NSRunLoopCommonModes];
    [countTimer fire];
}

-(void)stopTimer{
    [countTimer invalidate];
    countTimer = nil;
}
- (void)onTimer:(NSTimer *)timer{
    currentTime += TIMER_INTERVAL;
    float progressWidth = progressPreView.frame.size.width+progressStep;
    [progressPreView setFrame:CGRectMake(0, 64+62+preLayerHeight+23, progressWidth, 4)];
    
    //时间到了停止录制视频
    if (currentTime>=totalTime) {
        [countTimer invalidate];
        countTimer = nil;
        [_captureMovieFileOutput stopRecording];
        shootBt.hidden = YES;
        cameraBt.hidden = NO;
        self.completeRecordBtn.hidden = NO;
        self.completeRecordBtn.frame = CGRectMake((ScreenW-180)/2, 64+52, 180, 30);
        [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xff5a5f) forState:UIControlStateNormal];
        self.resetRecordBtn.enabled = YES;
    }
    
    NSString *minuteStr = [NSString stringWithFormat:@"%ld",currentTime/60];
    NSString *secountStr = [NSString stringWithFormat:@"%ld",currentTime%60];
    self.timeLab.text = [NSString stringWithFormat:@"%02.f:%02.f",[minuteStr floatValue],[secountStr floatValue]];
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
    [self stopTimer];
    //还原数据-----------
    [self deleteAllVideos];
    currentTime = -1;
    self.timeLab.text = @"00:00";
    [progressPreView setFrame:CGRectMake(0, 64+62+preLayerHeight+23, 0, 4)];
    self.completeRecordBtn.hidden = YES;
    self.completeRecordBtn.frame = CGRectMake((ScreenW-180)/2, 64+80+52, 180, 30);
    self.completeRecordBtn.enabled = YES;
    shootBt.hidden = NO;
    [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xb8b8b8) forState:UIControlStateNormal];
    self.resetRecordBtn.enabled = NO;
}

#pragma mark 视频录制
- (void)shootButtonClick{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"tipRecordImg"]) {
        [self.tipRecordImg removeFromSuperview];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"tipRecordImg"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSString *mp4Path = [[NSUserDefaults standardUserDefaults] valueForKey:@"mp4Path"];
    NSLog(@"--mp4Path--- %@",mp4Path);
    if (![NSString isEmptyStrings:mp4Path]) {
        [self deleteMp4Video:[[NSUserDefaults standardUserDefaults] valueForKey:@"mp4Path"]];
        [[NSUserDefaults standardUserDefaults] setValue:@"" forKey:@"mp4Path"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    shootBt.selected = !shootBt.selected;
    self.videoRemindImg.hidden = YES;
    self.videoRemindLab.hidden = YES;
    cameraBt.hidden = YES;
    //根据设备输出获得连接
    AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    //根据连接取得设备输出的数据
    if (![self.captureMovieFileOutput isRecording]) {
        //预览图层和视频方向保持一致
        captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
        [self.captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoSaveFilePathString]] recordingDelegate:self];
        self.completeRecordBtn.hidden = YES;
        self.resetRecordBtn.enabled = NO;
        [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xb8b8b8) forState:UIControlStateNormal];
    }else{
        [self stopTimer];
        [self.captureMovieFileOutput stopRecording];//停止录制
        cameraBt.hidden = NO;
        [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xff5a5f) forState:UIControlStateNormal];
        self.resetRecordBtn.enabled = YES;
    }
}

#pragma mark 切换前后摄像头
- (void)changeCamera:(UIButton*)bt {
    
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
        flashBt.hidden = NO;
    }else{
        flashBt.hidden = YES;
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    //关闭闪光灯
    flashBt.selected = NO;
    [flashBt setImage:[UIImage imageNamed:@"flashOpen"] forState:UIControlStateNormal];
    [self setTorchMode:AVCaptureTorchModeOff];
    
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    [self startTimer];
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"---outputFileURL---   %@",outputFileURL);
    [self.urlArray addObject:outputFileURL];
    
    //时间到了
    if (error) {
        if (error.code == -11807) {
            [[[UIAlertView alloc] initWithTitle:@"磁盘空间不足，无法完成录制" message:@"" delegate:self cancelButtonTitle:@"好" otherButtonTitles:nil, nil] show];
            
            [self stopTimer];
            [self.captureMovieFileOutput stopRecording];//停止录制
            cameraBt.hidden = NO;
            [self.resetRecordBtn setTitleColor:UIColorFromRGB(0xff5a5f) forState:UIControlStateNormal];
            self.resetRecordBtn.enabled = YES;
        }
        NSLog(@"1111");
    }else{
        if (currentTime<MINTIME) {
            self.videoRemindImg.hidden = NO;
            self.videoRemindLab.hidden = NO;
            [self animationRemind];
            NSLog(@"2222");
        }else{
            self.completeRecordBtn.hidden = NO;
            cameraBt.hidden = NO;
        }
    }
}
- (void)animationRemind{
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.8]; //动画时长
    [UIView setAnimationDelegate:self]; //设置代理
    [UIView setAnimationDidStopSelector:@selector(animationDidStop)]; //动画已经结束
    [UIView setAnimationRepeatCount:3]; //重复次数
    //动画执行代码
    self.videoRemindImg.frame = CGRectMake(ScreenW/(totalTime/MINTIME)-40, 64+62+preLayerHeight+23-30, 80, 25);
    [UIView commitAnimations];
}
//动画已经结束
-(void)animationDidStop{
    self.videoRemindImg.frame = CGRectMake(ScreenW/(totalTime/MINTIME)-40, 64+62+preLayerHeight+23-35, 80, 25);
}
//转换输出
- (void)save:(NSMutableArray *)fileURLArray{
    NSError *error = nil;
    CGSize renderSize = CGSizeMake(0, 0);
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    CMTime totalDuration = kCMTimeZero;
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray) {
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        [assetArray addObject:asset];
        NSArray* tmpAry =[asset tracksWithMediaType:AVMediaTypeVideo];
        if (tmpAry.count>0) {
            AVAssetTrack *assetTrack = [tmpAry objectAtIndex:0];
            [assetTrackArray addObject:assetTrack];
            renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
            renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
        }
    }
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        NSArray*dataSourceArray= [asset tracksWithMediaType:AVMediaTypeAudio];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:([dataSourceArray count]>0)?[dataSourceArray objectAtIndex:0]:nil
                             atTime:totalDuration
                              error:nil];
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0+preLayerHWRate*(preLayerHeight-preLayerWidth)/2));
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        [layerInstructionArray addObject:layerInstruciton];
    }
    NSString *path = [self getVideoMergeFilePathString];
    [[NSUserDefaults standardUserDefaults] setValue:path forKey:@"mp4Path"];
    [[NSUserDefaults standardUserDefaults] synchronize];//保存路径，下次录制时删除
    NSURL *mergeFileURL = [NSURL fileURLWithPath:path];
    
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 100);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW*preLayerHWRate);
    
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            self.coverImg = [self getVideoFirstPic:mergeFileURL];//获取视频第一帧图片
            WSPlayVideoViewController *vc = [[WSPlayVideoViewController alloc] init];
            vc.videoURL = mergeFileURL;
            vc.coverImage = self.coverImg;
            vc.type = @"video";
            vc.resetVideoBlock = ^(){
                [self resetRecordBtnClick];
            };
            [self.navigationController pushViewController:vc animated:YES];
        });
    }];
}
//最后合成为 mp4
- (NSString *)getVideoMergeFilePathString{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    self.fileNameStr = path;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];
    return fileName;
}
//录制保存的时候要保存为 mov
- (NSString *)getVideoSaveFilePathString{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mov"];
    
    return fileName;
}
- (void)createVideoFolderIfNotExist{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    NSString *folderPath = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];
    
    if(!(isDirExist && isDir)){
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"创建保存视频文件夹失败");
        }
    }
}
- (void)deleteAllVideos{
    for (NSURL *videoFileURL in self.urlArray) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *filePath = [[videoFileURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if ([fileManager fileExistsAtPath:filePath]) {
                NSError *error = nil;
                [fileManager removeItemAtPath:filePath error:&error];
                
                if (error) {
                    NSLog(@"delete All Video 删除视频文件出错:%@", error);
                }
            }
        });
    }
    [self.urlArray removeAllObjects];
}
- (void)deleteMp4Video:(NSString *)filePath{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:filePath]) {
            NSError *error = nil;
            [fileManager removeItemAtPath:filePath error:&error];
            if (error) {
                NSLog(@"delete All Video 删除视频文件出错:%@", error);
            }
        }
    });
    
}
#pragma mark - 私有方法
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

-(void)setTorchMode:(AVCaptureTorchMode )torchMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isTorchModeSupported:torchMode]) {
            [captureDevice setTorchMode:torchMode];
        }
    }];
}

-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}
// 获取视频的第一帧
- (UIImage *)getVideoFirstPic:(NSURL *)url{
    // 获取资源类
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    // 视频中截图类
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    //设置时间为0秒
    CMTime time = CMTimeMakeWithSeconds(0, 10);
    // 取出视频在0秒时候的图片
    CGImageRef image = [generator copyCGImageAtTime:time actualTime:nil error:nil];
    UIImage *thumb = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return thumb;
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }else{
        [self shootButtonClick];
    }
}



- (void)dealloc{
    NSLog(@"recordDealloc-----");
}
 
@end
