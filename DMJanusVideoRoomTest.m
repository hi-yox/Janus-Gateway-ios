//
//  DMJanusVideoRoomTest.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/5.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusVideoRoomTest.h"
#import "DMJanusManager.h"
#import "ARDFileCaptureController.h"
#import "DMVideoCallView.h"
#import "DMCallEngine.h"
#import "DMCaptureController.h"

@interface DMJanusVideoRoomTest()<DMJanusManagerDelegate>
{
    ARDFileCaptureController * _fileCaptureController;
    RTCVideoTrack * _remoteVideoTrack;
    DMCaptureController * _captureController;
}
@property (nonatomic,strong)NSNumber * mypvtid;// private_id
@property (nonatomic,strong)NSMutableArray * feeds;
@end

@implementation DMJanusVideoRoomTest
- (instancetype)init
{
    self = [super init];
    if (self) {
        [DMJanusManager sharedManager].delegate = self;
        [[DMJanusManager sharedManager] createSession];
        [[DMCallEngine shareEngine] launch];
        _feeds = [NSMutableArray new];
    }
    return self;
}
-(NSString *)janusManagerOpaqueId{
    return [@"videoroomtest-" stringByAppendingString:[[DMJanusManager sharedManager] randomString:12]];
}
-(NSString *)janusManagerpluginName{
    return @"janus.plugin.videoroom";
}
-(void)janusManager:(DMJanusManager *)manager didCreateSession:(NSString *)session{
    DMJanusPluginHandle * handle = [[DMJanusPluginHandle alloc]init];
    [[DMJanusManager sharedManager] attach:handle];
    
}
-(void)processFeedHandle:(DMJanusManager *)manager handle:(DMJanusPluginHandle *)handle{
    __weak typeof(self) weakSelf = self;
    __weak typeof(handle) weakHandle = handle;
    DMJanusPluginHandle * remoteFeedHandle = handle;
    remoteFeedHandle.onmessage = ^(NSDictionary * inmessage, NSDictionary * jsep){
        if (inmessage[@"error"]) {
            return;
        }
        NSString * event = inmessage[@"videoroom"];
        if ([event isEqualToString:@"attached"]) {
            [weakSelf.feeds addObject:weakHandle];
        }
        else if([event isEqualToString:@"event"]){
            
        }
        else {
            NSLog(@"位置错误");
        }
        
        if (jsep) {
            [weakHandle createAnswer:@{@"media":@{@"data":[NSNumber numberWithInt:true],@"audioSend":@(false),@"videoSend":@(false)},@"jsep":jsep} simulcast:NO success:^(NSDictionary * myJsep) {
                NSDictionary * body = @{@"request": @"start", @"room": @(1234)};
                [weakHandle sendMessage:@{@"message":body,@"jsep":myJsep}];
            } error:^(NSString *error) {
                
            }];
        }
    };
    NSDictionary * processInfo = remoteFeedHandle.processInfo;
    NSNumber * otherId = processInfo[@"id"];
    NSString * display = processInfo[@"display"];
    NSString * audio = processInfo[@"audio_codec"];
    NSString * video = processInfo[@"video_codec"];
    NSDictionary * listen = @{@"request": @"join", @"room": @(1234), @"ptype": @"subscriber", @"feed": otherId, @"private_id": self.mypvtid };
    [remoteFeedHandle sendMessage:@{@"message":listen}];
    
}
-(void)janusManager:(DMJanusManager *)manager didCreateHandle:(DMJanusPluginHandle *)handle{
    
    if (![handle.handleId isEqual:manager.currentHandleId]) {
        // subscribe handle 订阅流句柄
        [self processFeedHandle:manager handle:handle];
        return;
    }
    __weak typeof(self) weakSelf = self;
    __weak typeof(handle) weakHandle = handle;
    // publish handle, 发布流句柄
    handle.onmessage = ^(NSDictionary * inmessage,NSDictionary * jsep){
        NSString * event = inmessage[@"videoroom"];
        if ([event isEqualToString:@"joined"]) {
            weakSelf.mypvtid = inmessage[@"private_id"];
            NSArray * publishers = inmessage[@"publishers"];
            
            [weakHandle createOffer:@{@"media":@{@"data":[NSNumber numberWithInt:true],@"audioRecv":@(NO),@"videoRecv":@(NO),@"audioSend":@(YES),@"videoSend":@(YES)}} simulcast:NO success:^(NSDictionary *myJsep) {
                
                NSDictionary * publish = @{@"request": @"configure", @"audio":[NSNumber numberWithBool:YES], @"video": [NSNumber numberWithBool:YES],@"audiocodec":@"opus",@"videocodec":@"h264"};
                [weakHandle sendMessage:@{@"message": publish, @"jsep": myJsep}];
                
                
            } error:^(NSString *error) {
                
            }];
            for (NSDictionary * publisher in publishers) {
                [weakSelf newRemoteFeed:publisher currentHandle:weakHandle];
            }
        }
        else if ([event isEqualToString:@"event"]){
            // 收到一个事件
            if (inmessage[@"publishers"]) {
                NSArray * publishers = inmessage[@"publishers"];
                for (NSDictionary * publisher in publishers) {
                    [weakSelf newRemoteFeed:publisher currentHandle:weakHandle];
                }
            }
            else if (inmessage[@"leaving"]){
                
            }
            else if (inmessage[@"unpublished"]){
                
            }
            else if (inmessage[@"error"]){
                if ([inmessage[@"error_code"] isEqual:@(426)]) {
                    
                }
            }
        }
        else if ([event isEqualToString:@"destroyed"]){
            
        }
        if (jsep) {
            [weakHandle handleRemoteJsep:jsep];
        }
    };
    handle.mediaState = ^(NSDictionary * info){
        NSLog(@"媒体状态==================>%@",info);
    };
    NSDictionary * message = @{@"message":@{@"request": @"join",@"room":@(1234), @"display": @"yangyudong",@"ptype":@"publisher"}};
    [handle sendMessage:message];
}
-(void)newRemoteFeed:(NSDictionary *)remoteFeed currentHandle:(DMJanusPluginHandle *)currentHandle{
    DMJanusPluginHandle * pluginHandle = [[DMJanusPluginHandle alloc]init];
    pluginHandle.processInfo = remoteFeed;
    [[DMJanusManager sharedManager] attach:pluginHandle];
}
-(void)remoteCallLocalCaptureDidOpen:(RTCCameraVideoCapturer *)localCapturer{
    dispatch_async(dispatch_get_main_queue(), ^{
        _captureController = [[DMCaptureController alloc] initWithCapturer:localCapturer];
        [_captureController startCapture];
        self.videoCallView.localVideoView.captureSession = localCapturer.captureSession;
        
        CGFloat width = 130;
        CGFloat height = 130 * _captureController.videoSize.width/_captureController.videoSize.height;
        CGRect frame = CGRectMake(self.videoCallView.frame.size.width - 10 - 130, self.videoCallView.frame.size.height - height, width, height);
        self.videoCallView.localVideoView.frame = frame;
    });
}
-(void)remoteCallDidReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack{
    self.videoCallView.remoteVideoView.hidden = NO;
    if (_remoteVideoTrack == remoteVideoTrack) {
        return;
    }
    if (_remoteVideoTrack) {
        [_remoteVideoTrack removeRenderer:self.videoCallView.remoteVideoView];// 设置远程视频轨，在此处即可进行正常的视频回调处理
    }
    _remoteVideoTrack = nil;
    [self.videoCallView.remoteVideoView renderFrame:nil];
    _remoteVideoTrack = remoteVideoTrack;
    [_remoteVideoTrack addRenderer:self.videoCallView.remoteVideoView];
}
-(void)remoteCallLocalFileCaptureDidOpen:(RTCFileVideoCapturer *)fileCapturer videoAdapter:(DMVideoAdapter *)videoAdapter{
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 10, *)) {
            _fileCaptureController = [[ARDFileCaptureController alloc] initWithCapturer:fileCapturer];
            [_fileCaptureController startCapture];
        }
        self.videoCallView.isCamera = NO;
        videoAdapter.previewDelegate = self.videoCallView;
    });
    
#endif
}

@end
