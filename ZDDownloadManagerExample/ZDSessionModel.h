//
//  ZDSessionModel.h
//  ZDDownloadManagerExample
//
//  Created by mac on 2017/6/21.
//  Copyright © 2017年 com.zhouzhaodong. All rights reserved.
//
typedef enum {
    DownloadStateStart = 0,     /** 下载中 */
    DownloadStateSuspended,     /** 下载暂停 */
    DownloadStateCompleted,     /** 下载完成 */
    DownloadStateFailed         /** 下载失败 */
}DownloadState;

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface ZDSessionModel : NSObject
/** 流 */
@property (nonatomic, strong) NSOutputStream *stream;

/** 下载地址 */
@property (nonatomic, copy) NSString *url;

/** 获得服务器这次请求 返回数据的总长度 */
@property (nonatomic, assign) NSInteger totalLength;

/** 下载进度 */
@property (nonatomic, copy) void(^progressBlock)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress);

/** 下载状态 */
@property (nonatomic, copy) void(^stateBlock)(DownloadState state);
@end
