//
//  DMJanusVideoCallTest.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/4.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusVideoCallTest.h"
#import "DMJanusManager.h"
#import "DMJanusManager.h"
#import "ARDFileCaptureController.h"
#import "DMVideoCallView.h"
#import "DMCallEngine.h"

@interface DMJanusVideoCallTest()<DMJanusManagerDelegate>
{
    ARDFileCaptureController * _fileCaptureController;
    RTCVideoTrack * _remoteVideoTrack;
}
@end


@implementation DMJanusVideoCallTest
- (instancetype)init
{
    self = [super init];
    if (self) {
        [DMJanusManager sharedManager].delegate = self;
        [[DMJanusManager sharedManager] createSession];
        [[DMCallEngine shareEngine] launch];
    }
    return self;
}
-(NSString *)janusManagerOpaqueId{
    return [@"videocalltest-" stringByAppendingString:[[DMJanusManager sharedManager] randomString:12]];
}
-(NSString *)janusManagerpluginName{
    return @"janus.plugin.videocall";
}
-(void)janusManager:(DMJanusManager *)manager didCreateSession:(NSString *)session{
    DMJanusPluginHandle * handle = [[DMJanusPluginHandle alloc]init];
    [[DMJanusManager sharedManager] attach:handle];
}
-(void)janusManager:(DMJanusManager *)manager didCreateHandle:(DMJanusPluginHandle *)handle{
    
    __weak typeof(handle) weakHandle = handle;
    __weak typeof(self) weakSelf = self;
    handle.onmessage = ^(NSDictionary * inmessage,NSDictionary * jsep){
        NSString * event = inmessage[@"result"][@"event"];
        if ([event isEqualToString:@"accepted"]) {
            if (jsep) {
                [weakHandle handleRemoteJsep:jsep];
            }
        } else if ([event isEqualToString:@"registered"]) {
            [weakSelf registerSuccess:weakHandle];
        } else if([event isEqualToString:@"incomingcall"]) {
            [weakHandle createAnswer:@{@"media":@{@"data":[NSNumber numberWithInt:true]},@"jsep":jsep} simulcast:NO success:^(NSDictionary *jsep) {
                NSDictionary * body = @{@"request": @"accept"};
                [weakHandle sendMessage:@{@"message":body, @"jsep":jsep}];
            } error:^(NSString *error) {
                
            }];
        } else if ([event isEqualToString:@"calling"]){
            NSLog(@"正在呼叫 ... ");
        }
    };
    NSDictionary * message = @{@"message":@{@"request": @"register", @"username": @"yangyudong"}};
    [handle sendMessage:message];
}
-(void)registerSuccess:(DMJanusPluginHandle *)handle{
    __weak typeof(handle) weakHandle = handle;
    [handle createOffer:@{@"media":@{@"data":[NSNumber numberWithInt:true]}} simulcast:NO success:^(NSDictionary *jsep) {
        NSDictionary * body = @{@"request":@"call", @"username": @"18900125162" };
        [weakHandle sendMessage:@{@"message":body,@"jsep":jsep}];
    } error:^(NSString *error) {
        
    }];
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
