//
//  ViewController.m
//  ZDDownloadManagerExample
//
//  Created by mac on 2017/6/21.
//  Copyright © 2017年 com.zhouzhaodong. All rights reserved.
//

#import "ViewController.h"
#import "ZDDownloadManager.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
//相册
#define ZDAlbum @"断点续传"

@interface ViewController ()
/** 进度UILabel */
@property (weak, nonatomic) IBOutlet UILabel *progressLabel1;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel2;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel3;

/** 进度UIProgressView */
@property (weak, nonatomic) IBOutlet UIProgressView *progressView1;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView2;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView3;

/** 下载按钮 */
@property (weak, nonatomic) IBOutlet UIButton *downloadButton1;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton2;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton3;

/**  播放器 */
@property(nonatomic,strong)MPMoviePlayerController *moviePlayer;
/** 进度 */
@property(nonatomic,assign)float progress;
@end

@implementation ViewController

NSString * const downloadUrl1 = @"http://120.25.226.186:32812/resources/videos/minion_01.mp4";
NSString * const downloadUrl2 = @"http://box.9ku.com/download.aspx?from=9ku";
NSString * const downloadUrl3 = @"http://pic6.nipic.com/20100330/4592428_113348097000_2.jpg";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"%@", NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES));
    
    [self refreshDataWithState:DownloadStateSuspended];
}

#pragma mark 刷新数据
- (void)refreshDataWithState:(DownloadState)state
{
    
    self.progressLabel1.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl1] * 100];
    self.progressView1.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl1];
    NSString*title=@"播放";
    
    [self.downloadButton1 setTitle: self.progressView1.progress==1?title:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
    
    self.progressLabel2.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl2] * 100];
    self.progressView2.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl2];
    [self.downloadButton2 setTitle:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
    
    self.progressLabel3.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl3] * 100];
    self.progressView3.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl3];
    [self.downloadButton3 setTitle:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
    NSLog(@"-----%f", [[ZDDownloadManager sharedInstance] progress:downloadUrl1]);
    NSLog(@"-----%f", [[ZDDownloadManager sharedInstance] progress:downloadUrl2]);
}

#pragma mark 下载按钮事件
- (IBAction)download1:(UIButton *)sender {
    
    
    float progress=[[ZDDownloadManager sharedInstance] progress:downloadUrl1];
    
    progress==1?[self playVideo]:[self download:downloadUrl1 progressLabel:self.progressLabel1 progressView:self.progressView1 button:sender];
}

- (IBAction)download2:(UIButton *)sender {
    
    [self download:downloadUrl2 progressLabel:self.progressLabel2 progressView:self.progressView2 button:sender];
}

- (IBAction)download3:(UIButton *)sender {
    
    [self download:downloadUrl3 progressLabel:self.progressLabel3 progressView:self.progressView3 button:sender];
}

//视频保存到指定相册
- (IBAction)saveVideo:(UIButton *)sender {
    ZDDownloadManager * manager=[ZDDownloadManager sharedInstance];
    NSString *path=[manager filePath:downloadUrl1];
    if(path) [manager saveVideoWithPath:path];
    
}


#pragma mark 删除
- (IBAction)deleteFile1:(UIButton *)sender {
    [[ZDDownloadManager sharedInstance] deleteFile:downloadUrl1];
    self.progressLabel1.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl1] * 100];
    self.progressView1.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl1];
    [self.downloadButton1 setTitle:[self getTitleWithDownloadState:DownloadStateSuspended] forState:UIControlStateNormal];
}



- (IBAction)deleteFile2:(UIButton *)sender {
    [[ZDDownloadManager sharedInstance] deleteFile:downloadUrl2];
    self.progressLabel2.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl2] * 100];
    self.progressView2.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl2];
    [self.downloadButton2 setTitle:[self getTitleWithDownloadState:DownloadStateSuspended] forState:UIControlStateNormal];
}

- (IBAction)deleteFile3:(UIButton *)sender {
    [[ZDDownloadManager sharedInstance] deleteFile:downloadUrl3];
    self.progressLabel3.text = [NSString stringWithFormat:@"%.f%%", [[ZDDownloadManager sharedInstance] progress:downloadUrl3] * 100];
    self.progressView3.progress = [[ZDDownloadManager sharedInstance] progress:downloadUrl3];
    [self.downloadButton3 setTitle:[self getTitleWithDownloadState:DownloadStateSuspended] forState:UIControlStateNormal];
}

- (IBAction)deleteAllFile:(UIButton *)sender {
    [[ZDDownloadManager sharedInstance] deleteAllFile];
    [self refreshDataWithState:DownloadStateSuspended];
}


#pragma mark 开启任务下载资源
- (void)download:(NSString *)url progressLabel:(UILabel *)progressLabel progressView:(UIProgressView *)progressView button:(UIButton *)button
{
    [[ZDDownloadManager sharedInstance] download:url progress:^(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressLabel.text = [NSString stringWithFormat:@"%.f%%", progress * 100];
            progressView.progress = progress;
        });
    } state:^(DownloadState state) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [button setTitle:[self getTitleWithDownloadState:state] forState:UIControlStateNormal];
        });
    }];
}

#pragma mark 按钮状态
- (NSString *)getTitleWithDownloadState:(DownloadState)state
{
    switch (state) {
        case DownloadStateStart:
            return @"暂停";
        case DownloadStateSuspended:
        case DownloadStateFailed:
            return @"开始";
        case DownloadStateCompleted:
            return @"播放";
        default:
            break;
    }
}

- (void)playVideo{
    //设置播放的url
    NSString *path=[[ZDDownloadManager sharedInstance] filePath:downloadUrl1];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSLog(@"url==%@",url);
    self.moviePlayer=[[MPMoviePlayerController alloc] initWithContentURL:url];
    [self.moviePlayer.view setFrame:CGRectMake(40, 320, 300, 160)];
    [self.moviePlayer prepareToPlay];
    [self.moviePlayer setShouldAutoplay:YES]; // And other options you can look through the documentation.
    [self.view addSubview:self.moviePlayer.view];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
