#ifndef TUNETUBE_LIBRARY_VC_H
#define TUNETUBE_LIBRARY_VC_H

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class YTMAPI;
@class YTMPlayer;
@class YTMTrack;

NSArray *TuneTubeLibraryTracks(void);
NSArray *TuneTubeRecentTracks(void);
void TuneTubeRecordTrack(YTMTrack *track);
BOOL TuneTubeTrackIsSaved(YTMTrack *track);
void TuneTubeSaveTrack(YTMTrack *track);
void TuneTubeRemoveTrack(YTMTrack *track);

@interface TuneLibraryVC : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    YTMPlayer *_player;
    YTMAPI *_api;
    NSMutableArray *_tracks;
    UITableView *_table;
    UILabel *_emptyLabel;
    UILabel *_emptyDescription;
    UIImageView *_emptyIcon;
    UIButton *_findButton;
    CAGradientLayer *_backgroundGradient;
}

- (id)initWithPlayer:(YTMPlayer *)player api:(YTMAPI *)api;

@end

#endif
