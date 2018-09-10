//
//  DMJanusManager.h
//  JFDream
//
//  Created by 杨雨东 on 2018/9/1.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebRTC/WebRTC.h>

typedef void(^CreateOfferBlock)(NSDictionary * jsep);
typedef void(^CreateOfferError)(NSString * error);
typedef void(^CreateOnMessage)(NSDictionary * message,NSDictionary * jsep);

@interface DMJanusPluginHandle : NSObject
@property (nonatomic,strong,readonly)NSNumber * sessionId;
@property (nonatomic,strong)NSNumber * handleId;
@property (nonatomic,strong)NSString * uniqueId;
@property (nonatomic,copy)CreateOnMessage onmessage;
@property (nonatomic,strong)NSMutableDictionary * webrtcStuff;
@property (nonatomic,strong)NSDictionary * processInfo;
@property (nonatomic,copy)void (^mediaState)(NSDictionary *);


-(void)sendMessage:(NSDictionary *)message;
-(void)createOffer:(NSDictionary *)media simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error;
-(void)createAnswer:(NSDictionary *)media simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error;

-(void)handleRemoteJsep:(NSDictionary *)jsep;
@end

@class DMJanusManager;

@protocol DMJanusManagerDelegate <NSObject>
-(void)janusManager:(DMJanusManager *)manager didCreateSession:(NSString *)session;
-(void)janusManager:(DMJanusManager *)manager didCreateHandle:(DMJanusPluginHandle *)handle;
-(void)janusManager:(DMJanusManager *)manager onmessage:(NSDictionary *)message jsep:(NSString *)jsep;
-(NSString *)janusManagerpluginName;
-(NSString *)janusManagerOpaqueId;
-(void)remoteCallLocalFileCaptureDidOpen:(RTCFileVideoCapturer *)capturer videoAdapter:(DMVideoAdapter *)videoAdapter;
-(void)remoteCallLocalCaptureDidOpen:(RTCCameraVideoCapturer *)capturer;
-(void)remoteCallDidReceiveRemoteVideoTrack:(RTCVideoTrack *)track;
@end

@interface DMJanusManager : UIView
+(DMJanusManager *)sharedManager;
@property (nonatomic,readonly,assign)BOOL initDone;
@property (nonatomic,weak)id <DMJanusManagerDelegate> delegate;
-(BOOL)createSession;
@property (nonatomic,strong)NSNumber * currentHandleId;
-(void)attach:(DMJanusPluginHandle *)pluginHandle;
-(void)detach;

-(NSString *)randomString:(NSUInteger)len;

@end
