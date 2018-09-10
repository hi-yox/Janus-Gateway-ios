//
//  DMJanusBaseTest.m
//  JFDream
//
//  Created by 杨雨东 on 2018/9/5.
//  Copyright © 2018 jfdreamyang. All rights reserved.
//

#import "DMJanusBaseTest.h"

@implementation DMJanusBaseTest
-(DMVideoCallView *)videoCallView{
    if (!_videoCallView) {
        _videoCallView = [[DMVideoCallView alloc]initWithFrame:[UIScreen mainScreen].bounds];
        [[UIApplication sharedApplication].delegate.window addSubview:_videoCallView];
    }
    return _videoCallView;
}
@end
