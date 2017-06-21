//
//  ZDDownloadManager.m
//  ZDDownloadManagerExample
//
//  Created by mac on 2017/6/21.
//  Copyright © 2017年 com.zhouzhaodong. All rights reserved.
//
// 缓存主目录
#define ZDCachesDirectory [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"ZDCache"]

// 保存文件名
//#define HSFileName(url) url.md5String
#define ZDFileName(url) [NSString stringWithFormat:@"%@.%@",url.md5String,[url lastPathComponent]]
// 文件的存放路径（caches）
#define ZDFileFullpath(url) [ZDCachesDirectory stringByAppendingPathComponent:ZDFileName(url)]

// 文件的已下载长度
#define ZDDownloadLength(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:ZDFileFullpath(url) error:nil][NSFileSize] integerValue]

// 存储文件总长度的文件路径（caches）
#define ZDTotalLengthFullpath [ZDCachesDirectory stringByAppendingPathComponent:@"totalLength.plist"]
//相册
#define ZDAlbum @"断点续传"


#import "NSString+Hash.h"
#import "ZDDownloadManager.h"
@interface ZDDownloadManager()<NSCopying, NSURLSessionDelegate>

/** 保存所有任务(注：用下载地址md5后作为key) */
@property (nonatomic, strong) NSMutableDictionary *tasks;
/** 保存所有下载相关信息 */
@property (nonatomic, strong) NSMutableDictionary *sessionModels;
@end

@implementation ZDDownloadManager
- (NSMutableDictionary *)tasks
{
    if (!_tasks) {
        _tasks = [NSMutableDictionary dictionary];
    }
    return _tasks;
}

- (NSMutableDictionary *)sessionModels
{
    if (!_sessionModels) {
        _sessionModels = [NSMutableDictionary dictionary];
    }
    return _sessionModels;
}


static ZDDownloadManager *_downloadManager;

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _downloadManager = [super allocWithZone:zone];
    });
    
    return _downloadManager;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    return _downloadManager;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _downloadManager = [[self alloc] init];
    });
    
    return _downloadManager;
}

/**
 *  创建缓存目录文件
 */
- (void)createCacheDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:ZDCachesDirectory]) {
        [fileManager createDirectoryAtPath:ZDCachesDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

/**
 *  开启任务下载资源
 */
- (void)download:(NSString *)url progress:(void (^)(NSInteger, NSInteger, CGFloat))progressBlock state:(void (^)(DownloadState))stateBlock
{
    if (!url) return;
    if ([self isCompletion:url]) {
        stateBlock(DownloadStateCompleted);
        NSLog(@"----该资源已下载完成");
        return;
    }
    
    // 暂停
    if ([self.tasks valueForKey:ZDFileName(url)]) {
        [self handle:url];
        
        return;
    }
    
    // 创建缓存目录文件
    [self createCacheDirectory];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc] init]];
    
    // 创建流
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:ZDFileFullpath(url) append:YES];
    
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    // 设置请求头
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-", ZDDownloadLength(url)];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    // 创建一个Data任务
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    NSUInteger taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
    [task setValue:@(taskIdentifier) forKeyPath:@"taskIdentifier"];
    
    // 保存任务
    [self.tasks setValue:task forKey:ZDFileName(url)];
    
    ZDSessionModel *sessionModel = [[ZDSessionModel alloc] init];
    sessionModel.url = url;
    sessionModel.progressBlock = progressBlock;
    sessionModel.stateBlock = stateBlock;
    sessionModel.stream = stream;
    [self.sessionModels setValue:sessionModel forKey:@(task.taskIdentifier).stringValue];
    
    [self start:url];
}


- (void)handle:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    if (task.state == NSURLSessionTaskStateRunning) {
        [self pause:url];
    } else {
        [self start:url];
    }
}

/**
 *  开始下载
 */
- (void)start:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    [task resume];
    
    [self getSessionModel:task.taskIdentifier].stateBlock(DownloadStateStart);
}

/**
 *  暂停下载
 */
- (void)pause:(NSString *)url
{
    NSURLSessionDataTask *task = [self getTask:url];
    [task suspend];
    
    [self getSessionModel:task.taskIdentifier].stateBlock(DownloadStateSuspended);
}

/**
 *  根据url获得对应的下载任务
 */
- (NSURLSessionDataTask *)getTask:(NSString *)url
{
    return (NSURLSessionDataTask *)[self.tasks valueForKey:ZDFileName(url)];
}

/**
 *  根据url获取对应的下载信息模型
 */
- (ZDSessionModel *)getSessionModel:(NSUInteger)taskIdentifier
{
    return (ZDSessionModel *)[self.sessionModels valueForKey:@(taskIdentifier).stringValue];
}

/**
 *  判断该文件是否下载完成
 */
- (BOOL)isCompletion:(NSString *)url
{
    if ([self fileTotalLength:url] && ZDDownloadLength(url) == [self fileTotalLength:url]) {
        return YES;
    }
    return NO;
}

/**
 *  查询该资源的下载进度值
 */
- (CGFloat)progress:(NSString *)url
{
    return [self fileTotalLength:url] == 0 ? 0.0 : 1.0 * ZDDownloadLength(url) /  [self fileTotalLength:url];
}

/**
 *  获取该资源总大小
 */
- (NSInteger)fileTotalLength:(NSString *)url
{
    return [[NSDictionary dictionaryWithContentsOfFile:ZDTotalLengthFullpath][ZDFileName(url)] integerValue];
}

#pragma mark - 删除
/**
 *  删除该资源
 */
- (void)deleteFile:(NSString *)url
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:ZDFileFullpath(url)]) {
        
        // 删除沙盒中的资源
        [fileManager removeItemAtPath:ZDFileFullpath(url) error:nil];
        // 删除任务
        [self.tasks removeObjectForKey:ZDFileName(url)];
        [self.sessionModels removeObjectForKey:@([self getTask:url].taskIdentifier).stringValue];
        // 删除资源总长度
        if ([fileManager fileExistsAtPath:ZDTotalLengthFullpath]) {
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:ZDTotalLengthFullpath];
            [dict removeObjectForKey:ZDFileName(url)];
            [dict writeToFile:ZDTotalLengthFullpath atomically:YES];
            
        }
    }
}

/**
 *  清空所有下载资源
 */
- (void)deleteAllFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:ZDCachesDirectory]) {
        // 删除沙盒中所有资源
        [fileManager removeItemAtPath:ZDCachesDirectory error:nil];
        // 删除任务
        [[self.tasks allValues] makeObjectsPerformSelector:@selector(cancel)];
        [self.tasks removeAllObjects];
        
        for (ZDSessionModel *sessionModel in [self.sessionModels allValues]) {
            [sessionModel.stream close];
        }
        [self.sessionModels removeAllObjects];
        
        // 删除资源总长度
        if ([fileManager fileExistsAtPath:ZDTotalLengthFullpath]) {
            [fileManager removeItemAtPath:ZDTotalLengthFullpath error:nil];
        }
    }
}

#pragma mark - 代理
#pragma mark NSURLSessionDataDelegate
/**
 * 接收到响应
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    
    ZDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    
    // 打开流
    [sessionModel.stream open];
    
    // 获得服务器这次请求 返回数据的总长度
    NSInteger totalLength = [response.allHeaderFields[@"Content-Length"] integerValue] + ZDDownloadLength(sessionModel.url);
    sessionModel.totalLength = totalLength;
    
    // 存储总长度
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:ZDTotalLengthFullpath];
    if (dict == nil) dict = [NSMutableDictionary dictionary];
    dict[ZDFileName(sessionModel.url)] = @(totalLength);
    [dict writeToFile:ZDTotalLengthFullpath atomically:YES];
    
    // 接收这个请求，允许接收服务器的数据
    completionHandler(NSURLSessionResponseAllow);
}

/**
 * 接收到服务器返回的数据
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    ZDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    
    // 写入数据
    [sessionModel.stream write:data.bytes maxLength:data.length];
    
    // 下载进度
    NSUInteger receivedSize = ZDDownloadLength(sessionModel.url);
    NSUInteger expectedSize = sessionModel.totalLength;
    CGFloat progress = 1.0 * receivedSize / expectedSize;
    
    sessionModel.progressBlock(receivedSize, expectedSize, progress);
}

/**
 * 请求完毕（成功|失败）
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    ZDSessionModel *sessionModel = [self getSessionModel:task.taskIdentifier];
    if (!sessionModel) return;
    
    if ([self isCompletion:sessionModel.url]) {
        // 下载完成
        sessionModel.stateBlock(DownloadStateCompleted);
    } else if (error){
        // 下载失败
        sessionModel.stateBlock(DownloadStateFailed);
    }
    
    // 关闭流
    [sessionModel.stream close];
    sessionModel.stream = nil;
    
    // 清除任务
    [self.tasks removeObjectForKey:ZDFileName(sessionModel.url)];
    [self.sessionModels removeObjectForKey:@(task.taskIdentifier).stringValue];
}


- (NSString*)filePath:(NSString *)url
{
    NSString *temp = ZDFileFullpath(url);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:temp]){
        return temp;
    }else{
        return nil;
    }
}

- (void)saveVideoWithPath:(NSString *)filePath{
    [self creatAlbum];
    [self saveVideo:filePath toAlbum:ZDAlbum withCompletionBlock:^{
        UIAlertView * aler=[[UIAlertView alloc]initWithTitle:@"提示" message:@"保存成功" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
        [aler show];
    }];
}
//创建相册
- (void)creatAlbum{
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        // 调用判断是否已有该名称相册
        
        PHAssetCollection *assetCollection = [self fetchAssetColletion:ZDAlbum];
        
        //创建一个操作图库的对象
        
        PHAssetCollectionChangeRequest *assetCollectionChangeRequest;
        
        if (assetCollection) {
            
            // 已有相册
            
            assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
            
        } else {
            
            // 1.创建自定义相册
            
            assetCollectionChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:ZDAlbum];
            
        }
        
        // 3.把创建好图片添加到自己相册
        
        　　 //这里使用了占位图片,为什么使用占位图片呢
        
        　　//这个block是异步执行的,使用占位图片先为图片分配一个内存,等到有图片的时候,再对内存进行赋值
        
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        
        //弹出一个界面提醒用户是否保存成功
        
        if (error) {
            
            //[SVProgressHUD showErrorWithStatus:@"保存失败"];
            
        } else {
            
            // [SVProgressHUD showSuccessWithStatus:@"保存成功"];
            
        }
        
    }];
    
}
- (PHAssetCollection *)fetchAssetColletion:(NSString *)albumTitle

{
    
    // 获取所有的相册
    
    PHFetchResult *result = [PHAssetCollection           fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    //遍历相册数组,是否已创建该相册
    
    for (PHAssetCollection *assetCollection in result) {
        
        if ([assetCollection.localizedTitle isEqualToString:albumTitle]) {
            
            return assetCollection;
            
        }
        
    }
    
    return nil;
    
}


-(void)saveVideo:(NSString *)filePath toAlbum:(NSString*)albumName withCompletionBlock:(void (^)(void))completionBlock
{
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    //write the image data to the assets library (camera roll)
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:filePath] completionBlock:^(NSURL* assetURL, NSError* error)
     {
         //error handling
         if (error!=nil) {
             //completionBlock(error);
             return;
         }
         //add the asset to the custom photo album
         [self addAssetURL: assetURL toAlbum:albumName withCompletionBlock:completionBlock];
     }];
}

-(void)addAssetURL:(NSURL*)assetURL toAlbum:(NSString*)albumName withCompletionBlock:(void (^)(void))completionBlock
{
    
    ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc] init];
    
    __block BOOL albumWasFound = NO;
    
    //search all photo albums in the library
    [assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop)
     {
         //compare the names of the albums
         if ([albumName compare: [group valueForProperty:ALAssetsGroupPropertyName]]==NSOrderedSame) {
             //target album is found
             albumWasFound = YES;
             
             //get a hold of the photo's asset instance
             [assetsLibrary assetForURL: assetURL resultBlock:^(ALAsset *asset)
              {
                  //add photo to the target album
                  [group addAsset: asset];
                  
                  //run the completion block
                  completionBlock();
              } failureBlock: nil];
             
             //album was found, bail out of the method
             return;
         }
         
         if (group==nil && albumWasFound==NO) {
             //photo albums are over, target album does not exist, thus create it
             ALAssetsLibrary* weakSelf = assetsLibrary;
             
             
             {
                 // iOS 7.x code
                 //create new assets album
                 [assetsLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group)
                  {
                      //get the photo's instance
                      [weakSelf assetForURL: assetURL resultBlock:^(ALAsset *asset)
                       {
                           //add photo to the newly created album
                           [group addAsset: asset];
                           
                           //call the completion block
                           completionBlock();
                       } failureBlock: nil];
                  } failureBlock: nil];
                 albumWasFound = YES;
             }
             
             //should be the last iteration anyway, but just in case
             return;
         }
     } failureBlock: nil];
}
@end
