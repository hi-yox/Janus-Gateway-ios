//
//  DMJanusUtility.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/4.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusUtility.h"

@implementation DMJanusUtility
+(BOOL)isAudioSendEnabled:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return true;
    }
    if ([media[@"audio"] boolValue] == NO) {
        return NO;
    }
    if (!media[@"audioSend"] || [media[@"audioSend"] isKindOfClass:[NSNull class]]) {
        return YES;
    }
    return [media[@"audioSend"] boolValue] == YES;
}
+(BOOL)isAudioSendRequired:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return NO;
    }
    if ([media[@"audio"] boolValue] == NO || [media[@"audioSend"] boolValue] == NO) {
        return NO;
    }
    if (!media[@"failIfNoAudio"] || [media[@"failIfNoAudio"] isKindOfClass:[NSNull class]]) {
        return NO;
    }
    return [media[@"failIfNoAudio"] boolValue] == YES;
}

+(BOOL)isAudioRecvEnabled:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return true;
    }
    if (![media[@"audio"] boolValue]) {
        return NO;
    }
    if (!media[@"audioRecv"] || [media[@"audioRecv"] isKindOfClass:[NSNull class]]) {
        return YES;
    }
    
    return [media[@"audioRecv"] boolValue] == YES;
}

+(BOOL)isVideoSendEnabled:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return true;
    }
    if (![media[@"video"] boolValue]) {
        return NO;
    }
    if (!media[@"videoSend"] || [media[@"videoSend"] isKindOfClass:[NSNull class]]) {
        return YES;
    }
    return [media[@"videoSend"] boolValue] == YES;
}

+(BOOL)isVideoSendRequired:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return NO;
    }
    if ([media[@"video"] boolValue] == NO || [media[@"videoSend"] boolValue] == NO) {
        return NO;
    }
    if (!media[@"failIfNoVideo"] || [media[@"failIfNoVideo"] isKindOfClass:[NSNull class]]) {
        return NO;
    }
    return [media[@"failIfNoVideo"] boolValue] == YES;
}

+(BOOL)isVideoRecvEnabled:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return true;
    }
    if([media[@"video"] boolValue] == NO) return false;    // Generic video has precedence
    if (!media[@"videoRecv"] || [media[@"videoRecv"] isKindOfClass:[NSNull class]]) {
        return true;
    }
    return ([media[@"videoRecv"] boolValue] == true);
}

+(BOOL)isDataEnabled:(NSDictionary *)media{
    if (!media || [media isKindOfClass:[NSNull class]]) {
        return NO;
    }
    return [media[@"data"] boolValue] == YES;
}
+(BOOL)isTrickleEnabled:(NSNumber *)trickle{
    if (!trickle || [trickle isKindOfClass:[NSNull class]]) {
        return YES;
    }
    return trickle.boolValue == YES;
}
@end
