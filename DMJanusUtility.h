//
//  DMJanusUtility.h
//  JFDream
//
//  Created by 杨雨东 on 2018/9/4.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMJanusUtility : NSObject
+(BOOL)isAudioSendEnabled:(NSDictionary *)media;
+(BOOL)isAudioSendRequired:(NSDictionary *)media;
+(BOOL)isAudioRecvEnabled:(NSDictionary *)media;
+(BOOL)isVideoSendEnabled:(NSDictionary *)media;
+(BOOL)isVideoSendRequired:(NSDictionary *)media;
+(BOOL)isVideoRecvEnabled:(NSDictionary *)media;
+(BOOL)isDataEnabled:(NSDictionary *)media;
+(BOOL)isTrickleEnabled:(NSNumber *)trickle;
@end
