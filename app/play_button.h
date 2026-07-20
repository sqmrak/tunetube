#ifndef TUNTUBE_PLAY_BUTTON_H
#define TUNTUBE_PLAY_BUTTON_H

#import <UIKit/UIKit.h>

@interface TunePlaybackButton : UIButton {
    BOOL _playing;
    BOOL _lightStyle;
}

@property(nonatomic, readonly, getter=isPlaying) BOOL playing;
- (void)setPlaying:(BOOL)playing;
- (void)setLightStyle:(BOOL)lightStyle;

@end

typedef enum {
    TuneRoundButtonKindPrevious = 0,
    TuneRoundButtonKindNext,
    TuneRoundButtonKindStar,
    TuneRoundButtonKindRepeat,
    TuneRoundButtonKindClose
} TuneRoundButtonKind;

@interface TuneRoundButton : UIButton {
    TuneRoundButtonKind _kind;
    BOOL _active;
}

- (id)initWithKind:(TuneRoundButtonKind)kind;
- (void)setActive:(BOOL)active;

@end

#endif
