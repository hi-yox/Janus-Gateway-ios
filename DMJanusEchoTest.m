//
//  DMJanusEchoTest.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/3.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusEchoTest.h"
#import "DMJanusManager.h"
#import "ARDFileCaptureController.h"
#import "DMVideoCallView.h"
#import "DMCallEngine.h"

@interface DMJanusEchoTest()<DMJanusManagerDelegate>
{
    ARDFileCaptureController * _fileCaptureController;
    RTCVideoTrack * _remoteVideoTrack;
}
@property (nonatomic,strong)DMVideoCallView * videoCallView;
@end

@implementation DMJanusEchoTest
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
    return [@"echotest-" stringByAppendingString:[[DMJanusManager sharedManager] randomString:12]];
}
-(NSString *)janusManagerpluginName{
    return @"janus.plugin.echotest";
}
-(void)janusManager:(DMJanusManager *)manager didCreateSession:(NSString *)session{
    DMJanusPluginHandle * handle = [[DMJanusPluginHandle alloc]init];
    [[DMJanusManager sharedManager] attach:handle];
    
}
-(void)janusManager:(DMJanusManager *)manager didCreateHandle:(DMJanusPluginHandle *)handle{
    __weak typeof(handle) weakHandle = handle;
    handle.onmessage = ^(NSDictionary *message,NSDictionary * jsep){
        if (jsep) {
            [weakHandle handleRemoteJsep:jsep];
        }
    };
    NSDictionary * body = @{@"audio": [NSNumber numberWithBool:YES], @"video": [NSNumber numberWithBool:YES]};
    [handle sendMessage:@{@"message":body}];
    [handle createOffer:@{@"media":@{@"data":[NSNumber numberWithInt:true]}} simulcast:NO success:^(NSDictionary *jsep) {
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
