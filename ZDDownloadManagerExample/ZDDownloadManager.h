//
//  ZDDownloadManager.h
//  ZDDownloadManagerExample
//
//  Created by mac on 2017/6/21.
//  Copyright © 2017年 com.zhouzhaodong. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "ZDSessionModel.h"
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Foundation/Foundation.h>

@interface ZDDownloadManager : NSObject

/**
 *  单例
 *
 *  @return 返回单例对象
 */
+ (instancetype)sharedInstance;

/**
 *  开启任务下载资源
 *
 *  @param url           下载地址
 *  @param progressBlock 回调下载进度
 *  @param stateBlock    下载状态
 */
- (void)download:(NSString *)url progress:(void(^)(NSInteger receivedSize, NSInteger expectedSize, CGFloat progress))progressBlock state:(void(^)(DownloadState state))stateBlock;

/**
 *  查询该资源的下载进度值
 *
 *  @param url 下载地址
 *
 *  @return 返回下载进度值
 */
- (CGFloat)progress:(NSString *)url;

/**
 *  获取该资源总大小
 *
 *  @param url 下载地址
 *
 *  @return 资源总大小
 */
- (NSInteger)fileTotalLength:(NSString *)url;

/**
 *  判断该资源是否下载完成
 *
 *  @param url 下载地址
 *
 *  @return YES: 完成
 */
- (BOOL)isCompletion:(NSString *)url;

/**
 *  删除该资源
 *
 *  @param url 下载地址
 */
- (void)deleteFile:(NSString *)url;

/**
 *  清空所有下载资源
 */
- (void)deleteAllFile;


-(NSString*)filePath:(NSString *)url;
-(void)saveVideoWithPath:(NSString *)filePath;
@end
