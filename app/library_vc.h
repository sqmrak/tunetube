#ifndef TUNTUBE_LIBRARY_VC_H
#define TUNTUBE_LIBRARY_VC_H

#import <UIKit/UIKit.h>

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
}

- (id)initWithPlayer:(YTMPlayer *)player api:(YTMAPI *)api;

@end

#endif
