//
//  DMJanusManager.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/1.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusManager.h"
#import "SRWebSocket.h"
#import "DMCallParameters.h"
#import "RTCSessionDescription+JSON.h"
#import "RTCIceCandidate+JSON.h"
#import "DMJanusUtility.h"

static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";
static NSString * const kARDVideoTrackKind = @"video";
static NSString * const kDMSignalingMessageType = @"signal";
static NSInteger  const kKeepAliveTime = 25;
static NSString * const kStreamOfMine = @"kStreamOfMine";
static NSString * kJanusServerURL = @"ws://voip.jfdream.com:8188";

@interface DMJanusManager()<SRWebSocketDelegate,RTCPeerConnectionDelegate>
{
    BOOL _initDone;
    SRWebSocket * _webSocket;
    dispatch_queue_t _webSocketQueue;
    NSMutableDictionary * _pluginHandles;// 通过 sender 获取 handle
    NSMutableDictionary * _pluginHash;  // 通过 transation 获取 handle（只在创建时有效）
    BOOL _isConnected;
    RTCPeerConnectionFactory * _factory;
    DMVideoAdapter * _videoAdapter;
}
@property (nonatomic,strong)NSNumber * sessionId;
@property (nonatomic,strong)NSString * apisecret;
@property (nonatomic,strong)NSString * token;
@end

@implementation DMJanusManager

+(DMJanusManager *)sharedManager{
    static DMJanusManager * _manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[self alloc]init];
    });
    return _manager;
}

-(BOOL)createSession{
    RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];// 视频解码工厂
    NSArray * supportedCodecs = [RTCDefaultVideoEncoderFactory supportedCodecs];
    RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];// 视频编码工厂
    encoderFactory.preferredCodec = supportedCodecs.firstObject;
    _factory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory decoderFactory:decoderFactory];
    
    self.apisecret = @"";
    self.token = @"";
    _pluginHash = [NSMutableDictionary new];
    _pluginHandles = [NSMutableDictionary new];
    _webSocketQueue = dispatch_queue_create("com.jfdream.com.videoconference.queue", DISPATCH_QUEUE_SERIAL);
    _webSocket = [[SRWebSocket alloc]initWithURL:[NSURL URLWithString:kJanusServerURL] protocols:@[@"janus-protocol"]];
    _webSocket.delegate = self;
    [_webSocket setDelegateDispatchQueue:_webSocketQueue];
    [_webSocket open];
    
    return YES;
}

#pragma mark WebSocket

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)data{
    
    NSData * sourceData = [data isKindOfClass:[NSData class]]? data : [data dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary * event = [NSJSONSerialization JSONObjectWithData:sourceData options:NSJSONReadingMutableContainers error:nil];
    if (event) {
        [self handleEvent:event];
    }
    else{
        NSLog(@"Unknown message %@",data);
    }
}
- (void)webSocketDidOpen:(SRWebSocket *)webSocket{
    
    NSString * transaction = [self randomString:12];
    NSMutableDictionary * request = [@{@"janus":@"create",@"transaction":transaction} mutableCopy];
    request[@"token"]=self.token;
    request[@"apisecret"]=self.apisecret;
    
    [_webSocket send:request];
    _isConnected = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKeepAliveTime * NSEC_PER_SEC)), _webSocketQueue, ^{
        [self keepAlive];
    });
}
-(void)sendMessage:(NSDictionary *)message{
    [_webSocket send:message];
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error{
    
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean{
    _isConnected = NO;
}
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    
}
-(void)keepAlive{
    if (_isConnected && self.sessionId) {
        NSString * transaction = [self randomString:12];
        NSDictionary * request = @{ @"janus": @"keepalive", @"session_id": self.sessionId, @"transaction": transaction,@"token":self.token,@"apisecret":self.apisecret};
        [_webSocket send:request];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKeepAliveTime * NSEC_PER_SEC)), _webSocketQueue, ^{
            [self keepAlive];
        });
    }
}
-(void)handleEvent:(NSDictionary *)message{
    NSString * janus = message[@"janus"];
    if ([janus isEqualToString:@"keepalive"]) {
        
    }
    else if ([janus isEqualToString:@"ack"]){
        
    }
    else if ([janus isEqualToString:@"success"]) {
        // 连接成功，获取到一条 sessionId
        if (!_sessionId) {
            NSNumber * sessionId = message[@"session_id"];
            _sessionId = sessionId ? sessionId : message[@"data"][@"id"];
            NSDictionary * session = @{@"id":_sessionId};
            if ([self.delegate respondsToSelector:@selector(janusManager:didCreateSession:)]) {
                [self.delegate janusManager:self didCreateSession:message[@"data"][@"id"]];
            }
            return;
        }
        
        NSNumber * _handleId = message[@"data"][@"id"];
        
        NSString * transaction = message[@"transaction"];
        if (transaction) {
            DMJanusPluginHandle * pluginHandle = _pluginHash[transaction];
            if (pluginHandle) {
                pluginHandle.webrtcStuff = [NSMutableDictionary new];
                pluginHandle.handleId = _handleId;
                _pluginHandles[_handleId] = pluginHandle;
                if (!self.currentHandleId) {
                    self.currentHandleId = _handleId;
                }
                if ([self.delegate respondsToSelector:@selector(janusManager:didCreateHandle:)]) {
                    [self.delegate janusManager:self didCreateHandle:pluginHandle];
                }
            }
        }
    }
    else if ([janus isEqualToString:@"trickle"]){
        // We got a trickle candidate from Janus
        NSNumber * sender = message[@"sender"];
        DMJanusPluginHandle * pluginHandle = _pluginHandles[sender];
        
        
        NSLog(@"trickle===================>%@",message);
        
    }
    else if ([janus isEqualToString:@"webrtcup"]){
        NSNumber * sender = message[@"sender"];
        if (_pluginHandles[@"sender"]) {
            NSLog(@"Got a webrtcup event on session %@",self.sessionId);
        }
        else{
            NSLog(@"webrtcup %@",sender);
        }
    }
    else if ([janus isEqualToString:@"hangup"]){
        
    }
    else if ([janus isEqualToString:@"detached"]){
        
    }
    else if ([janus isEqualToString:@"media"]){
        NSNumber * sender = message[@"sender"];
        DMJanusPluginHandle * handle = _pluginHandles[sender];
        if (handle && handle.mediaState) {
            handle.mediaState(message);
        }
    }
    else if ([janus isEqualToString:@"slowlink"]){
        
    }
    else if ([janus isEqualToString:@"error"]){
        
    }
    else if ([janus isEqualToString:@"event"]){
        NSNumber * sender = message[@"sender"];
        NSDictionary * plugindata = message[@"plugindata"][@"data"];
        NSDictionary * jsep = message[@"jsep"];
        DMJanusPluginHandle * handle = _pluginHandles[sender];
        handle.onmessage(plugindata, jsep);
    }
    else{
        NSLog(@"Unknown message/event %@",message);
    }
}

-(void)prepareWebRTC:(NSNumber *)handleId mediaFrom:(NSDictionary *)mediaFrom{
    NSMutableDictionary * media = [mediaFrom mutableCopy];
    DMJanusPluginHandle * handle = _pluginHandles[handleId];
    NSMutableDictionary * config = handle.webrtcStuff;
    RTCPeerConnection * pc = config[@"pc"];
    config[@"trickle"] = [NSNumber numberWithBool:[DMJanusUtility isTrickleEnabled:config[@"trickle"]]];
    if (!pc) {
        media[@"update"] = [NSNumber numberWithBool:NO];
    }
    RTCMediaConstraints *constraints = [[DMCallParameters shareParameters] defaultPeerConnectionConstraints];
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    configuration.iceServers = [DMCallEngine shareEngine].iceServers;
    RTCIceServer * server = [[RTCIceServer alloc]initWithURLStrings:@[@"turn:47.94.129.124:3478?transport=udp",@"turn:47.94.129.124:3478?transport=tcp",@"stun:47.94.129.124:3478"] username:@"1536163274:jfdream_voip" credential:@"WM2M/dA+vtaMhW1RuElqauXSDk4="];
    configuration.iceServers = @[server];
    RTCPeerConnection * _peerConnection = [_factory peerConnectionWithConfiguration:configuration constraints:constraints delegate:self];
    config[@"pc"] = _peerConnection;
    
    if (mediaFrom[@"media"][@"audioSend"] && ![mediaFrom[@"media"][@"audioSend"] boolValue]) {
        return;
    }
    RTCMediaConstraints *defaultMediaAudioConstraints = [[DMCallParameters shareParameters] defaultMediaAudioConstraints];
    RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [_factory audioTrackWithSource:source trackId:kARDAudioTrackId];
    RTCMediaStream *stream = [_factory mediaStreamWithStreamId:kARDMediaStreamId];
    [stream addAudioTrack:track];
    [_peerConnection addStream:stream];
    RTCVideoSource * videoSource = [_factory videoSource];
    
    
#if !TARGET_IPHONE_SIMULATOR
    RTCCameraVideoCapturer *capturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:videoSource];
    [_delegate remoteCallLocalCaptureDidOpen:capturer];
#else
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
    if (@available(iOS 10, *)) {
        _videoAdapter = [[DMVideoAdapter alloc]init];
        _videoAdapter.videoSourceDelegate = videoSource;
        RTCFileVideoCapturer *fileCapturer = [[RTCFileVideoCapturer alloc] initWithDelegate:_videoAdapter];
        [_delegate remoteCallLocalFileCaptureDidOpen:fileCapturer videoAdapter:_videoAdapter];
    }
#endif
#endif
    RTCVideoTrack * _localVideoTrack = [_factory videoTrackWithSource:videoSource trackId:kARDVideoTrackId];
    if (_localVideoTrack) {
        [stream addVideoTrack:_localVideoTrack];
    }
    [_peerConnection addStream:stream];
    config[kStreamOfMine] = stream;
}

-(void)createOffer:(NSDictionary *)mediaFrom handleId:(NSNumber *)handleId simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error{
    [self prepareWebRTC:handleId mediaFrom:mediaFrom];
    DMJanusPluginHandle * handle = _pluginHandles[handleId];
    NSMutableDictionary * config = handle.webrtcStuff;
    RTCPeerConnection * _peerConnection = config[@"pc"];
    __weak typeof(_peerConnection) weakPc = _peerConnection;
    RTCMediaConstraints * constrains = [[DMCallParameters shareParameters] defaultOfferConstraints];
    if (mediaFrom[@"media"][@"audioRecv"] && [mediaFrom[@"media"][@"audioRecv"] boolValue] == NO) {
        constrains = [[DMCallParameters shareParameters] constraintsWithDict:@{
                                                                               @"OfferToReceiveAudio" : @"false",
                                                                               @"OfferToReceiveVideo" : @"false"
                                                                  }];
    }
    [_peerConnection offerForConstraints:constrains completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [weakPc setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
            
        }];
        success([sdp JSONDictionary]);
    }];
}

-(void)createAnwser:(NSDictionary *)mediaFrom handleId:(NSNumber *)handleId simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error{
    [self prepareWebRTC:handleId mediaFrom:mediaFrom];
    DMJanusPluginHandle * handle = _pluginHandles[handleId];
    NSMutableDictionary * config = handle.webrtcStuff;

    RTCPeerConnection * _peerConnection = config[@"pc"];
    __weak typeof(_peerConnection) weakPc = _peerConnection;
    
    RTCSessionDescription * remoteSdp = [RTCSessionDescription descriptionFromJSONDictionary:mediaFrom[@"jsep"]];
    config[@"remoteSdp"] = remoteSdp;
    RTCMediaConstraints * constraints = [[DMCallParameters shareParameters] defaultAnswerConstraints];
    [_peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError * _Nullable error) {
        [weakPc answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
            [weakPc setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                
            }];
            success([sdp JSONDictionary]);
        }];
        
    }];
}

-(void)prepareWebrtcPeer:(NSNumber *)handleId jsep:(NSDictionary *)jsep{
    DMJanusPluginHandle * pluginHandle = _pluginHandles[handleId];
    NSMutableDictionary * config = pluginHandle.webrtcStuff;
    RTCPeerConnection * _peerConnection = config[@"pc"];
    config[@"remoteSdp"] = jsep;
    [_peerConnection setRemoteDescription:[RTCSessionDescription descriptionFromJSONDictionary:jsep] completionHandler:^(NSError * _Nullable error) {
        
        
    }];
}
#pragma mark RTCPeerConnectionDelegate

/** Called when the SignalingState changed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged{
    
}
/** Called when media is received on a new stream from remote peer. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [self.delegate remoteCallDidReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

/** Called when a remote peer closes a stream. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream{
    
}

/** Called when negotiation is needed, for example ICE has restarted. */
- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection{
    
}

/** Called any time the IceConnectionState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState{
    
}

/** Called any time the IceGatheringState changes. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState{

    
}

/** New ice candidate has been found. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate{
    __block NSNumber * handleId = self.currentHandleId;
    [_pluginHandles enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        DMJanusPluginHandle * handle = obj;
        if (handle.webrtcStuff[@"pc"] == peerConnection) {
            handleId = handle.handleId;
        }
    }];
    NSDictionary * info = @{@"candidate":candidate.sdp,@"sdpMid":candidate.sdpMid,@"sdpMLineIndex":@(candidate.sdpMLineIndex)};
    [self sendCandidate:info handleId:handleId];
}

-(void)sendCandidate:(NSDictionary *)info handleId:(NSNumber *)handleId{
    
    NSString * transaction = [self randomString:12];
    NSMutableDictionary * request = [@{@"janus":@"trickle",@"candidate":info,@"transaction":transaction} mutableCopy];
    request[@"token"]=self.token;
    request[@"apisecret"]= self.apisecret;
    request[@"session_id"] = self.sessionId;
    request[@"handle_id"] = handleId;
    [self sendMessage:request];
}

/** Called when a group of local Ice candidates have been removed. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates{
    
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel{
    
}

-(NSString *)randomString:(NSUInteger)len{
    NSString * charSet = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    NSString * stringResult = @"";
    for (NSInteger i=0; i<len; i++) {
        uint32_t index = arc4random()%charSet.length;
        stringResult = [stringResult stringByAppendingString:[charSet substringWithRange:NSMakeRange(index, 1)]];
    }
    return stringResult;
}
-(void)attach:(DMJanusPluginHandle *)pluginHandle{
    NSString * plugin = [self.delegate janusManagerpluginName];
    NSString * opaqueId = [self.delegate janusManagerOpaqueId];
    NSString * transaction = [self randomString:12];
    NSMutableDictionary * request = [@{@"janus": @"attach", @"plugin": plugin, @"opaque_id": opaqueId, @"transaction": transaction} mutableCopy];
    request[@"token"] = self.token;
    request[@"apisecret"] = self.apisecret;
    request[@"session_id"] = _sessionId;
    _pluginHash[transaction] = pluginHandle;
    [_webSocket send:request];
}
-(void)detach{
    
}
-(BOOL)initDone{
    return _initDone;
}

@end

@implementation DMJanusPluginHandle
-(NSNumber *)sessionId{
    return [DMJanusManager sharedManager].sessionId;
}
-(void)sendMessage:(NSDictionary *)message{
    NSMutableDictionary * request = [message mutableCopy];
    request[@"token"]= [DMJanusManager sharedManager].token;
    request[@"apisecret"]= [DMJanusManager sharedManager].apisecret;
    if (message[@"jsep"]) {
        request[@"jsep"]=message[@"jsep"];
    }
    request[@"janus"]= @"message";
    request[@"body"]=message[@"message"];
    NSString * transaction = [[DMJanusManager sharedManager] randomString:12];
    request[@"transaction"]=transaction;
    request[@"session_id"]=self.sessionId;
    request[@"handle_id"]=self.handleId;
    [[DMJanusManager sharedManager] sendMessage:request];
}
-(void)createOffer:(NSDictionary *)media simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error{
    [[DMJanusManager sharedManager] createOffer:media handleId:self.handleId simulcast:doSimulcast success:success error:error];
}
-(void)createAnswer:(NSDictionary *)media simulcast:(BOOL)doSimulcast success:(CreateOfferBlock)success error:(CreateOfferError)error{
    [[DMJanusManager sharedManager] createAnwser:media handleId:self.handleId simulcast:doSimulcast success:success error:error];
}
-(NSString *)description{
    return [NSString stringWithFormat:@"%@\n webrtcStuff:%@",[super description],self.webrtcStuff];
}
-(void)handleRemoteJsep:(NSDictionary *)jsep{
    [[DMJanusManager sharedManager] prepareWebrtcPeer:self.handleId jsep:jsep];
}
@end










