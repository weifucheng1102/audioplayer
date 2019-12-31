#import "AudioplayerPlugin.h"
#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
static NSString *const CHANNEL_NAME = @"bz.rxla.flutter/audio";
static FlutterMethodChannel *channel;
static AVPlayer *player;
static AVPlayerItem *playerItem;
static NSMutableArray * arr;

@interface AudioplayerPlugin()
-(void)pause;
-(void)stop;
-(void)mute:(BOOL)muted;
-(void)seek:(CMTime)time;
-(void)onStart;
-(void)onTimeInterval:(CMTime)time;
@end

@implementation AudioplayerPlugin

CMTime position;
NSString *lastUrl;
int islocal;
BOOL isPlaying = false;
NSMutableSet *observers;
NSMutableSet *timeobservers;
FlutterMethodChannel *_channel;
BOOL isback = false;
int playIndex;
int  playedTime = 0;
int playState = 0;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:CHANNEL_NAME
                                     binaryMessenger:[registrar messenger]];
    AudioplayerPlugin* instance = [[AudioplayerPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
    _channel = channel;
    [registrar addApplicationDelegate:instance];
}
-(void)applicationWillResignActive:(UIApplication *)application
{
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    // *后台播放代码
    AVAudioSession*session=[AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}
//设置锁屏信息
- (void)setLockingInfo
{
    if (player) {
        if (!isback || arr.count==0) {
            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
            return;

        }
         //数据信息
           NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
           
           //图片

           NSData *imgData = [NSData dataWithContentsOfURL:[NSURL URLWithString:arr[playIndex][@"musicimg"]]];
           UIImage *image = [UIImage imageWithData:imgData];
           if (image) {
               MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:image];
               [songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
           }

           
           
           // 4、设置歌曲的时长和已经消耗的时间
              NSNumber *playbackDuration = @(CMTimeGetSeconds(player.currentItem.duration));
              NSNumber *elapsedPlaybackTime = @(CMTimeGetSeconds(player.currentItem.currentTime));

              if (!playbackDuration || !elapsedPlaybackTime) {
                  return;
              }
           //当前播放时间
           [songInfo setObject:elapsedPlaybackTime forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
           //速率
           [songInfo setObject:[NSNumber numberWithFloat:1.0f] forKey:MPNowPlayingInfoPropertyPlaybackRate];
           //剩余时长
           [songInfo setObject:playbackDuration forKey:MPMediaItemPropertyPlaybackDuration];
           
           //设置标题
           [songInfo setObject:@"亲道" forKey:MPMediaItemPropertyTitle];
           
           //设置副标题
           [songInfo setObject:arr[playIndex][@"title"] forKey:MPMediaItemPropertyArtist];
           
           //设置音频数据信息
           [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
        
    }else{
         [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
    }
   
}
-(void)applicationDidEnterBackground:(UIApplication *)application
{
    isback  =true;
    [self setupLockScreenControlInfo];
}
-(void)applicationDidBecomeActive:(UIApplication *)application{
    isback = false;
}

- (void)setupLockScreenControlInfo {
    [self setLockingInfo];
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    
    // 锁屏播放
    MPRemoteCommand *playCommand = commandCenter.playCommand;
    playCommand.enabled = YES;
    [playCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        NSLog(@"锁屏暂停后点击播放");
        if (!isPlaying) {
            [self play:lastUrl isLocal:islocal];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    // 锁屏暂停
    MPRemoteCommand *pauseCommand = commandCenter.pauseCommand;
    pauseCommand.enabled = YES;
    [pauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        NSLog(@"锁屏正在播放点击后暂停");
        
        if (isPlaying) {
            [self pause];
        }
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    
    MPRemoteCommand *stopCommand = commandCenter.stopCommand;
    stopCommand.enabled = YES;
    [stopCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        [self stop];
        
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    // 播放和暂停按钮（耳机控制）
    MPRemoteCommand *playPauseCommand = commandCenter.togglePlayPauseCommand;
    playPauseCommand.enabled = YES;
    
    [playPauseCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
        
        if (isPlaying) {
             [self pause];
        }else {
             [self play:lastUrl isLocal:islocal];
        }
        
        return MPRemoteCommandHandlerStatusSuccess;
    }];
    
    
//        //这部分功能没有用到，就暂时先放在这里
//     // 上一曲
//     MPRemoteCommand *previousCommand = commandCenter.previousTrackCommand;
//    if (playIndex == 0) {
//        previousCommand.enabled = NO;
//    }else{
//        previousCommand.enabled = YES;
//    }
//     [previousCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//         if (isPlaying) {
//            [self stop];
//         }
//         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//         [self playBack];
//         });
//     return MPRemoteCommandHandlerStatusSuccess;
//     }];
//
//     // 下一曲
//     MPRemoteCommand *nextCommand = commandCenter.nextTrackCommand;
//    if (playIndex==arr.count-1) {
//        nextCommand.enabled = NO;
//    }else{
//        nextCommand.enabled = YES;
//
//    }
//     [nextCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//     if (isPlaying) {
//        [self stop];
//     }
//
//     dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//
//
//     [self playNext];
//     });
//
//     return MPRemoteCommandHandlerStatusSuccess;
//     }];
//
//     // 快进
//     MPRemoteCommand *forwardCommand = commandCenter.seekForwardCommand;
//     forwardCommand.enabled = YES;
//     [forwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//
//     MPSeekCommandEvent *seekEvent = (MPSeekCommandEvent *)event;
//     if (seekEvent.type == MPSeekCommandEventTypeBeginSeeking) {
//     [self seekingForwardStart];
//     }else {
//     [self seekingForwardStop];
//     }
//
//     return MPRemoteCommandHandlerStatusSuccess;
//     }];
     
//     // 快退
//     MPRemoteCommand *backwardCommand = commandCenter.seekBackwardCommand;
//     backwardCommand.enabled = YES;
//     [backwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//
//     MPSeekCommandEvent *seekEvent = (MPSeekCommandEvent *)event;
//     if (seekEvent.type == MPSeekCommandEventTypeBeginSeeking) {
//     [self seekingBackwardStart];
//     }else {
//     [self seekingBackwardStop];
//     }
//
//     return MPRemoteCommandHandlerStatusSuccess;
//     }];
//
    
     //拖动进度条
//    if (@available(iOS 9.1, *)) {
//
//
//        MPRemoteCommand *changePlaybackPositionCommand = commandCenter.changePlaybackPositionCommand;
//        changePlaybackPositionCommand.enabled = YES;
//        [changePlaybackPositionCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent * _Nonnull event) {
//            MPChangePlaybackPositionCommandEvent *positionEvent = (MPChangePlaybackPositionCommandEvent *)event;
//
//            self.positionTime = positionEvent.positionTime;
//            NSLog(@"positionTime = %f",self.positionTime);
//            //业务逻辑如下：
//            self.currentTime = (float)self.positionTime * 1000 >= self.courseItem.duration.integerValue * 1000 ? self.courseItem.duration.integerValue * 1000 : (float)self.positionTime * 1000;
//
//            CGFloat value = self.currentTime / self.duration;
//            if (isPlaying) {
//                [kAudioPlayer setPlayerProgress:value];
//            }else {
//                if (value == 0) {
//                    value = 0.001;
//                }
//                self.seekProgress = value;
//            }
//            self.updataMediaCount = 0;
//            NSLog(@"self.isDraging = %d",self.isDraging);
//            return MPRemoteCommandHandlerStatusSuccess;
//        }];
//    } else {
//        // Fallback on earlier versions
//    }
}
- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    typedef void (^CaseBlock)(void);
    // Squint and this looks like a proper switch!
    NSDictionary *methods = @{
                              @"play":
                                  ^{
                                      
                                      NSString *url = call.arguments[@"url"];
                                      int isLocal = [call.arguments[@"isLocal"] intValue];
                                      NSString *name = call.arguments[@"name"];
                                      arr = [NSMutableArray arrayWithCapacity:0];
                                      NSString * jsonStr = call.arguments[@"json"];
                                      //string转data
                                    NSData * jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                                          //json解析
                                    id obj = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
                                    arr = obj;
                                      playIndex = 0;
                                      for (int i = 0; i<arr.count; i++) {
                                          if([name isEqualToString:arr[i][@"title"]]){
                                              playIndex = i;
                                          }
                                      }
                                      [self play:url isLocal:isLocal];

                                      result(nil);
                                  },
                              @"pause":
                                  ^{
                                      [self pause];
                                      result(nil);
                                  },
                              @"stop":
                                  ^{
                                      [self stop];
                                      result(nil);
                                  },
                              @"mute":
                                  ^{
                                      [self mute:[call.arguments boolValue]];
                                      result(nil);
                                  },
                              @"seek":
                                  ^{
                                      [self seek:CMTimeMakeWithSeconds([call.arguments doubleValue], 1)];
                                      result(nil);
                                  },
                              @"changeState":
                                  ^{
                                      [self changeState:[call.arguments intValue]];
                                      result(nil);
                                  }
                              };
    
    CaseBlock c = methods[call.method];
    if (c) {
        c();
    } else {
        result(FlutterMethodNotImplemented);
    }
}

//修改播放状态 -1不循环   0单曲循环   1列表循环
-(void)changeState:(int)state{
    playState = state;
}
- (void)play:(NSString*)url isLocal:(int)isLocal {
    playedTime = 0;
    if (![url isEqualToString:lastUrl]) {
        [playerItem removeObserver:self
                        forKeyPath:@"player.currentItem.status"];
        
        for (id ob in observers) {
            [[NSNotificationCenter defaultCenter] removeObserver:ob];
        }
        observers = nil;
        
        if (isLocal) {
            playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:url]];
        } else {
            playerItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:url]];
        }
        lastUrl = url;
        islocal = isLocal;
        id anobserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                                          object:playerItem
                                                                           queue:nil
                                                                      usingBlock:^(NSNotification* note){
                                                                          [self stop];
                                                                          [_channel invokeMethod:@"audio.onComplete" arguments:nil];
                                                                      }];
        [observers addObject:anobserver];
        
        if (player) {
            [player replaceCurrentItemWithPlayerItem:playerItem];
        } else {
            player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
            // Stream player position.
            // This call is only active when the player is active so there's no need to
            // remove it when player is paused or stopped.
            CMTime interval = CMTimeMakeWithSeconds(0.2, NSEC_PER_SEC);
            id timeObserver = [player addPeriodicTimeObserverForInterval:interval queue:nil usingBlock:^(CMTime time){
                [self onTimeInterval:time];
            }];
            [timeobservers addObject:timeObserver];
        }
        
        // is sound ready
        [[player currentItem] addObserver:self
                               forKeyPath:@"player.currentItem.status"
                                  options:0
                                  context:nil];
    }
    [self onStart];
    [player play];
    isPlaying = true;

}

- (void)onStart {
    CMTime duration = [[player currentItem] duration];
    if (CMTimeGetSeconds(duration) > 0) {
        int mseconds= CMTimeGetSeconds(duration)*1000;
        [_channel invokeMethod:@"audio.onStart" arguments:@(mseconds)];
    }
}

- (void)onTimeInterval:(CMTime)time {
    int mseconds =  CMTimeGetSeconds(time)*1000;
    [_channel invokeMethod:@"audio.onCurrentPosition" arguments:@(mseconds)];
//    if (playedTime<10) {
    if (isPlaying) {
        [self setLockingInfo];
    }
//        playedTime = playedTime+1;
//    }
}

- (void)pause {
    [player pause];
    isPlaying = false;
    [_channel invokeMethod:@"audio.onPause" arguments:nil];
}

- (void)stop {
    if (isPlaying) {
        [player pause];
        isPlaying = false;
    }
    [playerItem seekToTime:CMTimeMake(0, 1)];
    [_channel invokeMethod:@"audio.onStop" arguments:nil];
}

- (void)mute:(BOOL)muted {
    player.muted = muted;
}

- (void)seek:(CMTime)time {
    [playerItem seekToTime:time];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"player.currentItem.status"]) {
        if ([[player currentItem] status] == AVPlayerItemStatusReadyToPlay) {
            [self onStart];
        } else if ([[player currentItem] status] == AVPlayerItemStatusFailed) {
            [_channel invokeMethod:@"audio.onError" arguments:@[(player.currentItem.error.localizedDescription)]];
        }
    } else {
        // Any unrecognized context must belong to super
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}


-(void)playNext{
    playIndex = playIndex+1;
    playedTime = 0;
    [self play:arr[playIndex][@"vipmusic"] isLocal:NO];
}
-(void)playBack{
    playIndex = playIndex-1;
    playedTime = 0;
    [self play:arr[playIndex][@"vipmusic"] isLocal:NO];
}


- (void)dealloc {
    for (id ob in timeobservers) {
        [player removeTimeObserver:ob];
    }
    timeobservers = nil;
    
    for (id ob in observers) {
        [[NSNotificationCenter defaultCenter] removeObserver:ob];
    }
    observers = nil;
}

@end
