#import "library_vc.h"

#import <QuartzCore/QuartzCore.h>

#import "tunetube_config.h"
#import "tunetube_theme.h"
#import "ytm_api.h"
#import "ytm_player.h"

static NSDictionary *TuneTubeDictionaryForTrack(YTMTrack *track) {
    if (!track.videoID.length) return nil;
    return [NSDictionary dictionaryWithObjectsAndKeys:
            track.videoID, @"id",
            track.title ?: @"", @"title",
            YTMDisplayArtist(track.artist), @"artist",
            track.album ?: @"", @"album",
            track.thumbnailURL ?: @"", @"thumbnail",
            [NSNumber numberWithUnsignedInteger:track.duration], @"duration", nil];
}

static NSArray *TuneTubeTracksFromEntries(NSArray *saved) {
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSDictionary *entry in saved) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSString *videoID = [entry objectForKey:@"id"];
        if (!videoID.length) continue;
        YTMTrack *track = [[[YTMTrack alloc]
                            initWithVideoID:videoID
                            title:[entry objectForKey:@"title"] ?: @"Untitled"
                            artist:YTMDisplayArtist([entry objectForKey:@"artist"])
                            album:[entry objectForKey:@"album"] ?: @""
                            thumbnailURL:[entry objectForKey:@"thumbnail"] ?: @""
                            duration:[[entry objectForKey:@"duration"] unsignedIntegerValue]] autorelease];
        [tracks addObject:track];
    }
    return tracks;
}

static NSMutableArray *TuneTubeEntriesForKey(NSString *key) {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (![saved isKindOfClass:[NSArray class]]) saved = [NSArray array];
    return [NSMutableArray arrayWithArray:saved];
}

static void TuneTubeWriteEntries(NSMutableArray *entries, NSString *key) {
    [[NSUserDefaults standardUserDefaults] setObject:entries forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

NSArray *TuneTubeLibraryTracks(void) {
    return TuneTubeTracksFromEntries([[NSUserDefaults standardUserDefaults]
                                      objectForKey:TUNETUBE_LIBRARY_DEFAULTS_KEY]);
}

NSArray *TuneTubeRecentTracks(void) {
    return TuneTubeTracksFromEntries([[NSUserDefaults standardUserDefaults]
                                      objectForKey:TUNETUBE_HISTORY_DEFAULTS_KEY]);
}

static void TuneTubeInsertTrack(YTMTrack *track, NSString *key, NSUInteger limit) {
    NSDictionary *entry = TuneTubeDictionaryForTrack(track);
    if (!entry) return;

    NSMutableArray *saved = TuneTubeEntriesForKey(key);
    NSString *videoID = track.videoID;
    NSUInteger existing = NSNotFound;
    for (NSUInteger index = 0; index < saved.count; ++index) {
        NSDictionary *item = [saved objectAtIndex:index];
        if ([[item objectForKey:@"id"] isEqualToString:videoID]) {
            existing = index;
            break;
        }
    }
    if (existing != NSNotFound) [saved removeObjectAtIndex:existing];
    [saved insertObject:entry atIndex:0];
    while (saved.count > limit) [saved removeLastObject];
    TuneTubeWriteEntries(saved, key);
}

void TuneTubeSaveTrack(YTMTrack *track) {
    TuneTubeInsertTrack(track, TUNETUBE_LIBRARY_DEFAULTS_KEY, 200);
}

void TuneTubeRecordTrack(YTMTrack *track) {
    TuneTubeInsertTrack(track, TUNETUBE_HISTORY_DEFAULTS_KEY, 12);
}

BOOL TuneTubeTrackIsSaved(YTMTrack *track) {
    if (!track.videoID.length) return NO;
    for (NSDictionary *entry in TuneTubeEntriesForKey(TUNETUBE_LIBRARY_DEFAULTS_KEY)) {
        if ([[entry objectForKey:@"id"] isEqualToString:track.videoID]) return YES;
    }
    return NO;
}

void TuneTubeRemoveTrack(YTMTrack *track) {
    if (!track.videoID.length) return;
    NSMutableArray *saved = TuneTubeEntriesForKey(TUNETUBE_LIBRARY_DEFAULTS_KEY);
    for (NSInteger index = (NSInteger)saved.count - 1; index >= 0; --index) {
        NSDictionary *entry = [saved objectAtIndex:(NSUInteger)index];
        if ([[entry objectForKey:@"id"] isEqualToString:track.videoID])
            [saved removeObjectAtIndex:(NSUInteger)index];
    }
    TuneTubeWriteEntries(saved, TUNETUBE_LIBRARY_DEFAULTS_KEY);
}

@interface TuneLibraryVC ()
- (void)donePressed;
- (void)reloadLibrary;
- (void)applyTheme:(NSNotification *)note;
- (void)findMusicPressed;
@end

@implementation TuneLibraryVC

- (id)initWithPlayer:(YTMPlayer *)player api:(YTMAPI *)api {
    self = [super init];
    if (self) {
        _player = [player retain];
        _api = [api retain];
        _tracks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_player release];
    [_api release];
    [_tracks release];
    [_table release];
    [_emptyLabel release];
    [_emptyDescription release];
    [_emptyIcon release];
    [_findButton release];
    [_backgroundGradient release];
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = TuneThemeBackgroundBottom();
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Library";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme:)
                                                 name:TuneTubeThemeDidChangeNotification
                                               object:nil];
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
                                               initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                               target:self action:@selector(donePressed)] autorelease];

    _backgroundGradient = [[CAGradientLayer layer] retain];
    [self.view.layer insertSublayer:_backgroundGradient atIndex:0];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.backgroundView = nil;
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 66.0f;
    _table.contentInset = UIEdgeInsetsMake(10.0f, 0.0f, 10.0f, 0.0f);
    [self.view addSubview:_table];

    _emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _emptyLabel.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = TuneThemePrimaryText();
    _emptyLabel.font = [UIFont boldSystemFontOfSize:18.0f];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.text = @"Nothing here";
    [self.view addSubview:_emptyLabel];

    _emptyIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"player-star-off.png"]];
    _emptyIcon.backgroundColor = [UIColor clearColor];
    _emptyIcon.contentMode = UIViewContentModeCenter;
    [self.view addSubview:_emptyIcon];

    _emptyDescription = [[UILabel alloc] initWithFrame:CGRectZero];
    _emptyDescription.backgroundColor = [UIColor clearColor];
    _emptyDescription.textColor = TuneThemeSecondaryText();
    _emptyDescription.font = [UIFont systemFontOfSize:13.0f];
    _emptyDescription.numberOfLines = 0;
    _emptyDescription.textAlignment = NSTextAlignmentCenter;
    _emptyDescription.text = @"Saved tracks will appear here.\nFind music and tap ♥ to add it.";
    [self.view addSubview:_emptyDescription];

    _findButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [_findButton setTitle:@"Find music" forState:UIControlStateNormal];
    _findButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
    _findButton.layer.cornerRadius = 10.0f;
    _findButton.layer.borderWidth = 1.0f;
    [_findButton addTarget:self action:@selector(findMusicPressed)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_findButton];
    [self applyTheme:nil];
    [self reloadLibrary];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    _backgroundGradient.frame = bounds;
    _table.frame = bounds;
    CGFloat center = floorf(bounds.size.height * 0.45f);
    _emptyIcon.frame = CGRectMake(floorf((bounds.size.width - 72.0f) * 0.5f),
                                  center - 112.0f, 72.0f, 72.0f);
    _emptyLabel.frame = CGRectMake(20.0f, center - 28.0f,
                                   bounds.size.width - 40.0f, 28.0f);
    _emptyDescription.frame = CGRectMake(28.0f, center + 8.0f,
                                         bounds.size.width - 56.0f, 46.0f);
    _findButton.frame = CGRectMake(floorf((bounds.size.width - 164.0f) * 0.5f),
                                   center + 68.0f, 164.0f, 40.0f);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadLibrary];
}

- (void)reloadLibrary {
    [_tracks removeAllObjects];
    [_tracks addObjectsFromArray:TuneTubeLibraryTracks()];
    BOOL empty = _tracks.count == 0;
    _emptyLabel.hidden = !empty;
    _emptyIcon.hidden = !empty;
    _emptyDescription.hidden = !empty;
    _findButton.hidden = !empty;
    [_table reloadData];
}

- (void)applyTheme:(NSNotification *)note {
    (void)note;
    self.view.backgroundColor = TuneThemeBackgroundBottom();
    self.navigationController.navigationBar.barStyle = TuneTubeThemeIsLight()
        ? UIBarStyleDefault : UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = TuneThemeAccent();
    self.navigationController.navigationBar.titleTextAttributes =
        [NSDictionary dictionaryWithObject:TuneThemePrimaryText()
                                     forKey:UITextAttributeTextColor];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)TuneThemeBackgroundTop().CGColor,
                                  (id)TuneThemeBackgroundBottom().CGColor, nil];
    _emptyLabel.textColor = TuneThemePrimaryText();
    _emptyDescription.textColor = TuneThemeSecondaryText();
    _findButton.backgroundColor = TuneThemeAccent();
    [_findButton setTitleColor:TuneTubeThemeIsLight() ? [UIColor whiteColor] : [UIColor whiteColor]
                      forState:UIControlStateNormal];
    _findButton.layer.borderColor = TuneThemeBorder().CGColor;
    [_table reloadData];
}

- (void)donePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; (void)section;
    return (NSInteger)_tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"TuneLibraryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                               reuseIdentifier:cellID] autorelease];
    YTMTrack *track = [_tracks objectAtIndex:(NSUInteger)indexPath.row];
    cell.backgroundColor = TuneThemeSurface();
    cell.textLabel.textColor = TuneThemePrimaryText();
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    cell.detailTextLabel.textColor = TuneThemeSecondaryText();
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.textLabel.text = track.title;
    cell.detailTextLabel.text = YTMDisplayArtist(track.artist);
    cell.imageView.image = [UIImage imageNamed:@"Icon.png"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger row;
    YTMTrack *track;
    YTMAPI *api;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    row = (NSUInteger)indexPath.row;
    if (row >= _tracks.count || !_player || !_api) return;
    track = [[_tracks objectAtIndex:row] retain];
    api = [_api retain];
    TuneTubeRecordTrack(track);
    [_player setQueue:_tracks selectedIndex:(NSInteger)row usingAPI:api];
    [api release];
    [track release];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
 commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *saved = [NSMutableArray arrayWithArray:
                             [[NSUserDefaults standardUserDefaults]
                              objectForKey:TUNETUBE_LIBRARY_DEFAULTS_KEY] ?: [NSArray array]];
    if ((NSUInteger)indexPath.row < saved.count) {
        [saved removeObjectAtIndex:(NSUInteger)indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:saved
                                                   forKey:TUNETUBE_LIBRARY_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [_tracks removeObjectAtIndex:(NSUInteger)indexPath.row];
    [_table deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
    _emptyLabel.hidden = _tracks.count != 0;
    _emptyIcon.hidden = _tracks.count != 0;
    _emptyDescription.hidden = _tracks.count != 0;
    _findButton.hidden = _tracks.count != 0;
}

- (void)findMusicPressed {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:TuneTubeFocusSearchNotification object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; (void)indexPath;
    return YES;
}

@end
