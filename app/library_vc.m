#import "library_vc.h"

#import <QuartzCore/QuartzCore.h>

#import "tuntube_config.h"
#import "ytm_api.h"
#import "ytm_player.h"

static UIColor *LibraryColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static NSDictionary *TuneTubeDictionaryForTrack(YTMTrack *track) {
    if (!track.videoID.length) return nil;
    return [NSDictionary dictionaryWithObjectsAndKeys:
            track.videoID, @"id",
            track.title ?: @"", @"title",
            track.artist ?: @"", @"artist",
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
                            artist:[entry objectForKey:@"artist"] ?: @""
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
                                      objectForKey:TUNTUBE_LIBRARY_DEFAULTS_KEY]);
}

NSArray *TuneTubeRecentTracks(void) {
    return TuneTubeTracksFromEntries([[NSUserDefaults standardUserDefaults]
                                      objectForKey:TUNTUBE_HISTORY_DEFAULTS_KEY]);
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
    TuneTubeInsertTrack(track, TUNTUBE_LIBRARY_DEFAULTS_KEY, 200);
}

void TuneTubeRecordTrack(YTMTrack *track) {
    TuneTubeInsertTrack(track, TUNTUBE_HISTORY_DEFAULTS_KEY, 12);
}

BOOL TuneTubeTrackIsSaved(YTMTrack *track) {
    if (!track.videoID.length) return NO;
    for (NSDictionary *entry in TuneTubeEntriesForKey(TUNTUBE_LIBRARY_DEFAULTS_KEY)) {
        if ([[entry objectForKey:@"id"] isEqualToString:track.videoID]) return YES;
    }
    return NO;
}

void TuneTubeRemoveTrack(YTMTrack *track) {
    if (!track.videoID.length) return;
    NSMutableArray *saved = TuneTubeEntriesForKey(TUNTUBE_LIBRARY_DEFAULTS_KEY);
    for (NSInteger index = (NSInteger)saved.count - 1; index >= 0; --index) {
        NSDictionary *entry = [saved objectAtIndex:(NSUInteger)index];
        if ([[entry objectForKey:@"id"] isEqualToString:track.videoID])
            [saved removeObjectAtIndex:(NSUInteger)index];
    }
    TuneTubeWriteEntries(saved, TUNTUBE_LIBRARY_DEFAULTS_KEY);
}

@interface TuneLibraryVC ()
- (void)donePressed;
- (void)reloadLibrary;
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
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = LibraryColor(0.02f, 0.05f, 0.06f, 1.0f);
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Library";
    self.navigationController.navigationBar.tintColor = LibraryColor(0.84f, 0.08f, 0.06f, 1.0f);
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
                                               initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                               target:self action:@selector(donePressed)] autorelease];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = [NSArray arrayWithObjects:
                       (id)LibraryColor(0.04f, 0.18f, 0.19f, 1.0f).CGColor,
                       (id)LibraryColor(0.01f, 0.03f, 0.04f, 1.0f).CGColor, nil];
    gradient.frame = self.view.bounds;
    [self.view.layer insertSublayer:gradient atIndex:0];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.backgroundView = nil;
    _table.separatorColor = LibraryColor(0.35f, 0.52f, 0.52f, 0.35f);
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 66.0f;
    _table.contentInset = UIEdgeInsetsMake(10.0f, 0.0f, 10.0f, 0.0f);
    [self.view addSubview:_table];

    _emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _emptyLabel.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = LibraryColor(0.72f, 0.80f, 0.80f, 0.86f);
    _emptyLabel.font = [UIFont systemFontOfSize:16.0f];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.text = @"Your saved tracks will appear here";
    [self.view addSubview:_emptyLabel];
    [self reloadLibrary];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    for (CALayer *layer in self.view.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) layer.frame = bounds;
    }
    _table.frame = bounds;
    _emptyLabel.frame = CGRectMake(20.0f, floorf(bounds.size.height * 0.43f),
                                   bounds.size.width - 40.0f, 30.0f);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadLibrary];
}

- (void)reloadLibrary {
    [_tracks removeAllObjects];
    [_tracks addObjectsFromArray:TuneTubeLibraryTracks()];
    _emptyLabel.hidden = _tracks.count != 0;
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
    cell.backgroundColor = LibraryColor(0.04f, 0.10f, 0.11f, 0.82f);
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0f];
    cell.detailTextLabel.textColor = LibraryColor(0.67f, 0.76f, 0.76f, 1.0f);
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.textLabel.text = track.title;
    cell.detailTextLabel.text = track.artist.length ? track.artist : @"Unknown artist";
    cell.imageView.image = [UIImage imageNamed:@"Icon.png"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (!_tracks.count) return;
    TuneTubeRecordTrack([_tracks objectAtIndex:(NSUInteger)indexPath.row]);
    [_player setQueue:_tracks selectedIndex:(NSInteger)indexPath.row usingAPI:_api];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
 commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
 forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *saved = [NSMutableArray arrayWithArray:
                             [[NSUserDefaults standardUserDefaults]
                              objectForKey:TUNTUBE_LIBRARY_DEFAULTS_KEY] ?: [NSArray array]];
    if ((NSUInteger)indexPath.row < saved.count) {
        [saved removeObjectAtIndex:(NSUInteger)indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:saved
                                                   forKey:TUNTUBE_LIBRARY_DEFAULTS_KEY];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    [_tracks removeObjectAtIndex:(NSUInteger)indexPath.row];
    [_table deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                  withRowAnimation:UITableViewRowAnimationAutomatic];
    _emptyLabel.hidden = _tracks.count != 0;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView; (void)indexPath;
    return YES;
}

@end
