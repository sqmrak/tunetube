#import "ytm_player.h"

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "ytm_api.h"
#import "tuntube_image_cache.h"

#include <math.h>

NSString * const YTMPlayerDidChangeNotification = @"YTMPlayerDidChangeNotification";

static void YTMUpdateNowPlaying(YTMPlayer *player) {
    Class centerClass = NSClassFromString(@"MPNowPlayingInfoCenter");
    if (!centerClass) return;
    id center = [centerClass performSelector:@selector(defaultCenter)];
    if (!center) return;

    YTMTrack *track = player.track;
    if (!track) {
        [center setValue:nil forKey:@"nowPlayingInfo"];
        return;
    }

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (track.title.length) [info setObject:track.title forKey:@"title"];
    if (track.artist.length) [info setObject:track.artist forKey:@"artist"];
    if (track.album.length) [info setObject:track.album forKey:@"albumTitle"];
    NSTimeInterval duration = [player duration];
    if (duration > 0.0) {
        [info setObject:[NSNumber numberWithDouble:duration] forKey:@"playbackDuration"];
        [info setObject:[NSNumber numberWithDouble:[player currentTime]]
                 forKey:@"elapsedPlaybackTime"];
    }
    [info setObject:[NSNumber numberWithFloat:player.isPlaying ? 1.0f : 0.0f]
             forKey:@"playbackRate"];
    if (player.queue.count) {
        [info setObject:[NSNumber numberWithUnsignedInteger:player.queue.count]
                 forKey:@"playbackQueueCount"];
    }
    [center setValue:info forKey:@"nowPlayingInfo"];
}

static void YTMUpdateNowPlayingArtwork(YTMPlayer *player, YTMTrack *track,
                                        NSUInteger generation) {
    if (!track.thumbnailURL.length) return;
    NSString *requestedURL = [track.thumbnailURL copy];
    TuneLoadImage(requestedURL, ^(UIImage *image) {
        if (!image || player.track != track || generation == 0) return;
        Class artworkClass = NSClassFromString(@"MPMediaItemArtwork");
        Class centerClass = NSClassFromString(@"MPNowPlayingInfoCenter");
        if (!artworkClass || !centerClass) return;
        id artwork = [[artworkClass alloc] performSelector:@selector(initWithImage:)
                                                 withObject:image];
        id center = [centerClass performSelector:@selector(defaultCenter)];
        if (!artwork || !center || player.track != track) {
            [artwork release];
            return;
        }
        NSMutableDictionary *info = [[[center valueForKey:@"nowPlayingInfo"] mutableCopy]
                                     autorelease];
        if (!info) info = [NSMutableDictionary dictionary];
        [info setObject:artwork forKey:@"artwork"];
        [center setValue:info forKey:@"nowPlayingInfo"];
        [artwork release];
    });
    [requestedURL release];
}

static void YTMPlayerNotify(YTMPlayer *player, NSError *error) {
    YTMUpdateNowPlaying(player);
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:player
                                                                        forKey:@"player"];
    if (error) [info setObject:error forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotificationName:YTMPlayerDidChangeNotification
                                                        object:player
                                                      userInfo:info];
}

@implementation YTMPlayer

- (YTMTrack *)track { return _track; }
- (NSArray *)queue { return _queue; }
- (BOOL)isRepeating { return _repeating; }

- (BOOL)isPlaying {
    return [_player isKindOfClass:[AVPlayer class]] && [(AVPlayer *)_player rate] > 0.0f;
}

- (NSTimeInterval)currentTime {
    if (![_player isKindOfClass:[AVPlayer class]]) return 0.0;
    Float64 seconds = CMTimeGetSeconds([(AVPlayer *)_player currentTime]);
    return isfinite(seconds) && seconds > 0.0 ? seconds : 0.0;
}

- (NSTimeInterval)duration {
    if (_track.duration) return (NSTimeInterval)_track.duration;
    if (![_player isKindOfClass:[AVPlayer class]]) return 0.0;
    AVPlayerItem *item = [(AVPlayer *)_player currentItem];
    Float64 seconds = CMTimeGetSeconds(item.duration);
    return isfinite(seconds) && seconds > 0.0 ? seconds : 0.0;
}

- (float)progress {
    NSTimeInterval duration = [self duration];
    if (duration <= 0.0) return 0.0f;
    float value = (float)([self currentTime] / duration);
    if (value < 0.0f) return 0.0f;
    if (value > 1.0f) return 1.0f;
    return value;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player pause];
    [_player release];
    [_track release];
    [_api release];
    [_queue release];
    [super dealloc];
}

- (void)playTrack:(YTMTrack *)track usingAPI:(YTMAPI *)api {
    NSUInteger generation;
    YTMTrack *selectedTrack;
    YTMAPI *selectedAPI;
    if (!track || !api) return;
    selectedTrack = [track retain];
    selectedAPI = [api retain];
    ++_generation;
    generation = _generation;
    [_api release];
    _api = selectedAPI;
    [_track release];
    _track = selectedTrack;
    for (NSUInteger index = 0; index < _queue.count; ++index) {
        YTMTrack *queued = [_queue objectAtIndex:index];
        if ([queued.videoID isEqualToString:selectedTrack.videoID]) {
            _queueIndex = (NSInteger)index;
            break;
        }
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [_player pause];
    [_player release];
    _player = nil;
    YTMPlayerNotify(self, nil);

    NSError *sessionError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:&sessionError];
    [session setActive:YES error:&sessionError];

    [selectedAPI audioURLForTrack:selectedTrack completion:^(NSURL *url, NSError *error) {
        if (generation != _generation) return;
        if (error || !url) {
            YTMPlayerNotify(self, error);
            return;
        }
        AVPlayer *av = [[AVPlayer alloc] initWithURL:url];
        [_player release];
        _player = av;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(itemDidFinish:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:[(AVPlayer *)_player currentItem]];
        [(AVPlayer *)_player play];
        YTMUpdateNowPlayingArtwork(self, selectedTrack, generation);
        YTMPlayerNotify(self, nil);
    }];
}

- (void)setQueue:(NSArray *)tracks selectedIndex:(NSInteger)index usingAPI:(YTMAPI *)api {
    NSMutableArray *newQueue;
    YTMTrack *selectedTrack;
    YTMAPI *selectedAPI;
    if (![tracks isKindOfClass:[NSArray class]] || !tracks.count || !api) return;

    newQueue = [tracks mutableCopy];
    if (!newQueue.count) {
        [newQueue release];
        return;
    }
    if (index < 0) index = 0;
    if ((NSUInteger)index >= newQueue.count) index = (NSInteger)newQueue.count - 1;
    selectedTrack = [[newQueue objectAtIndex:(NSUInteger)index] retain];
    selectedAPI = [api retain];

    [_queue release];
    _queue = newQueue;
    _queueIndex = index;
    [self playTrack:selectedTrack usingAPI:selectedAPI];
    [selectedTrack release];
    [selectedAPI release];
}

- (void)nextTrack {
    if (!_queue.count || _queueIndex + 1 >= (NSInteger)_queue.count) return;
    ++_queueIndex;
    [self playTrack:[_queue objectAtIndex:(NSUInteger)_queueIndex] usingAPI:_api];
}

- (void)previousTrack {
    if (!_queue.count || !_api) return;
    if (_queueIndex > 0) --_queueIndex;
    [self playTrack:[_queue objectAtIndex:(NSUInteger)_queueIndex] usingAPI:_api];
}

- (void)itemDidFinish:(NSNotification *)note {
    (void)note;
    if (_repeating && _track && _api) {
        [self playTrack:_track usingAPI:_api];
    } else if (_queue.count && _queueIndex + 1 < (NSInteger)_queue.count) {
        [self nextTrack];
    } else {
        [_player pause];
        YTMPlayerNotify(self, nil);
    }
}

- (void)setRepeating:(BOOL)repeating {
    if (_repeating == repeating) return;
    _repeating = repeating;
    YTMPlayerNotify(self, nil);
}

- (void)toggle {
    if (![_player isKindOfClass:[AVPlayer class]]) return;
    AVPlayer *player = (AVPlayer *)_player;
    if ([player rate] > 0.0f) [player pause];
    else [player play];
    YTMPlayerNotify(self, nil);
}

- (void)seekToProgress:(float)progress {
    if (![_player isKindOfClass:[AVPlayer class]]) return;
    NSTimeInterval duration = [self duration];
    if (duration <= 0.0) return;
    if (progress < 0.0f) progress = 0.0f;
    if (progress > 1.0f) progress = 1.0f;
    CMTime time = CMTimeMakeWithSeconds((Float64)duration * progress, 600);
    [(AVPlayer *)_player seekToTime:time
                    toleranceBefore:kCMTimeZero
                     toleranceAfter:kCMTimeZero];
    YTMPlayerNotify(self, nil);
}

- (void)stop {
    ++_generation;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:nil];
    [_player pause];
    [_player release];
    _player = nil;
    [_track release];
    _track = nil;
    [_queue release];
    _queue = nil;
    _queueIndex = 0;
    YTMPlayerNotify(self, nil);
}

@end
