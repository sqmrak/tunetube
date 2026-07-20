#import "player_vc.h"

#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

#import "ytm_api.h"
#import "ytm_player.h"
#import "library_vc.h"
#import "play_button.h"
#import "tuntube_image_cache.h"

static UIColor *PlayerColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

static NSString *PlayerTime(NSUInteger seconds) {
    return [NSString stringWithFormat:@"%lu:%02lu",
            (unsigned long)(seconds / 60), (unsigned long)(seconds % 60)];
}

static void PlayerStyleVolumeView(MPVolumeView *volumeView) {
    for (UIView *subview in volumeView.subviews) {
        if (![subview isKindOfClass:[UISlider class]]) continue;
        UISlider *slider = (UISlider *)subview;
        slider.minimumTrackTintColor = PlayerColor(0.96f, 0.10f, 0.08f, 1.0f);
        slider.maximumTrackTintColor = PlayerColor(0.55f, 0.58f, 0.58f, 0.65f);
        slider.thumbTintColor = PlayerColor(0.93f, 0.95f, 0.95f, 1.0f);
        break;
    }
}

static BOOL PlayerIsPad(void) {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
}

static BOOL PlayerIsCompactPhone(CGFloat height) {
    return !PlayerIsPad() && height <= 568.0f;
}

@interface TunePlayerVC ()
- (void)refresh;
- (void)updateProgress;
- (void)progressChanged:(UISlider *)slider;
- (void)closePressed;
- (void)togglePressed;
- (void)favoritePressed;
- (void)nextTrackPressed;
- (void)previousTrackPressed;
- (void)repeatPressed;
@end

@implementation TunePlayerVC

- (id)initWithPlayer:(YTMPlayer *)player {
    self = [super init];
    if (self) _player = [player retain];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player release];
    [_backgroundGradient release];
    [_headerBar release];
    [_headerSearch release];
    [_headerTitle release];
    [_artwork release];
    [_titleLabel release];
    [_artistLabel release];
    [_progress release];
    [_elapsedLabel release];
    [_durationLabel release];
    [_previousButton release];
    [_nextButton release];
    [_repeatButton release];
    [_favoriteButton release];
    [_playButton release];
    [_volumeView release];
    [_progressTimer invalidate];
    [_progressTimer release];
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = PlayerColor(0.01f, 0.03f, 0.04f, 1.0f);
    self.view = view;
}

- (UIButton *)textButton:(NSString *)title size:(CGFloat)size {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:size];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = YES;
    _backgroundGradient = [[CAGradientLayer layer] retain];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)PlayerColor(0.30f, 0.03f, 0.03f, 1.0f).CGColor,
                                  (id)PlayerColor(0.12f, 0.01f, 0.02f, 1.0f).CGColor,
                                  (id)PlayerColor(0.015f, 0.01f, 0.015f, 1.0f).CGColor, nil];
    _backgroundGradient.locations = [NSArray arrayWithObjects:@0.0f, @0.38f, @1.0f, nil];
    [self.view.layer insertSublayer:(CAGradientLayer *)_backgroundGradient atIndex:0];

    _headerBar = [[UIView alloc] initWithFrame:CGRectZero];
    _headerBar.backgroundColor = PlayerColor(0.42f, 0.04f, 0.04f, 0.96f);
    _headerBar.layer.borderWidth = 1.0f;
    _headerBar.layer.borderColor = PlayerColor(0.75f, 0.17f, 0.14f, 0.38f).CGColor;
    [self.view addSubview:_headerBar];

    _headerSearch = [[self textButton:@"Search" size:12.0f] retain];
    _headerSearch.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    _headerSearch.accessibilityLabel = @"Search";
    [_headerSearch addTarget:self action:@selector(closePressed)
            forControlEvents:UIControlEventTouchUpInside];
    [_headerBar addSubview:_headerSearch];

    _headerTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    _headerTitle.backgroundColor = [UIColor clearColor];
    _headerTitle.textColor = [UIColor whiteColor];
    _headerTitle.font = [UIFont boldSystemFontOfSize:17.0f];
    _headerTitle.textAlignment = NSTextAlignmentCenter;
    _headerTitle.text = @"TuneTube";
    [_headerBar addSubview:_headerTitle];

    _artwork = [[UIImageView alloc] initWithFrame:CGRectZero];
    _artwork.image = [UIImage imageNamed:@"Icon.png"];
    _artwork.contentMode = UIViewContentModeScaleAspectFill;
    _artwork.layer.cornerRadius = 12.0f;
    _artwork.layer.masksToBounds = YES;
    _artwork.layer.borderWidth = 1.0f;
    _artwork.layer.borderColor = PlayerColor(1.0f, 0.25f, 0.20f, 0.55f).CGColor;
    _artwork.layer.shadowColor = [UIColor blackColor].CGColor;
    _artwork.layer.shadowOpacity = 0.7f;
    _artwork.layer.shadowOffset = CGSizeMake(0.0f, 6.0f);
    _artwork.layer.shadowRadius = 8.0f;
    [self.view addSubview:_artwork];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    [self.view addSubview:_titleLabel];

    _artistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _artistLabel.backgroundColor = [UIColor clearColor];
    _artistLabel.textColor = PlayerColor(0.82f, 0.86f, 0.86f, 0.62f);
    _artistLabel.font = [UIFont systemFontOfSize:12.0f];
    _artistLabel.textAlignment = NSTextAlignmentCenter;
    _artistLabel.lineBreakMode = UILineBreakModeTailTruncation;
    [self.view addSubview:_artistLabel];

    _progress = [[UISlider alloc] initWithFrame:CGRectZero];
    _progress.minimumValue = 0.0f;
    _progress.maximumValue = 1.0f;
    _progress.value = 0.0f;
    _progress.minimumTrackTintColor = PlayerColor(0.96f, 0.10f, 0.08f, 1.0f);
    _progress.maximumTrackTintColor = PlayerColor(0.55f, 0.58f, 0.58f, 0.65f);
    _progress.userInteractionEnabled = YES;
    [_progress addTarget:self action:@selector(progressChanged:)
        forControlEvents:UIControlEventValueChanged | UIControlEventTouchUpInside |
                         UIControlEventTouchUpOutside];
    [self.view addSubview:_progress];

    _elapsedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _elapsedLabel.backgroundColor = [UIColor clearColor];
    _elapsedLabel.textColor = PlayerColor(0.70f, 0.74f, 0.74f, 1.0f);
    _elapsedLabel.font = [UIFont systemFontOfSize:11.0f];
    [self.view addSubview:_elapsedLabel];

    _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _durationLabel.backgroundColor = [UIColor clearColor];
    _durationLabel.textColor = PlayerColor(0.70f, 0.74f, 0.74f, 1.0f);
    _durationLabel.font = [UIFont systemFontOfSize:11.0f];
    _durationLabel.textAlignment = NSTextAlignmentRight;
    [self.view addSubview:_durationLabel];

    _volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    _volumeView.showsRouteButton = NO;
    _volumeView.showsVolumeSlider = YES;
    _volumeView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_volumeView];
    PlayerStyleVolumeView(_volumeView);

    _playButton = [[TunePlaybackButton alloc] initWithFrame:CGRectZero];
    [_playButton setLightStyle:NO];
    [_playButton addTarget:self action:@selector(togglePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playButton];

    _previousButton = [[TuneRoundButton alloc] initWithKind:TuneRoundButtonKindPrevious];
    [_previousButton addTarget:self action:@selector(previousTrackPressed)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_previousButton];

    _nextButton = [[TuneRoundButton alloc] initWithKind:TuneRoundButtonKindNext];
    [_nextButton addTarget:self action:@selector(nextTrackPressed)
          forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_nextButton];

    _repeatButton = [[TuneRoundButton alloc] initWithKind:TuneRoundButtonKindRepeat];
    [_repeatButton addTarget:self action:@selector(repeatPressed)
            forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_repeatButton];

    _favoriteButton = [[TuneRoundButton alloc] initWithKind:TuneRoundButtonKindStar];
    [_favoriteButton addTarget:self action:@selector(favoritePressed)
              forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_favoriteButton];

    _artwork.userInteractionEnabled = YES;
    UISwipeGestureRecognizer *nextSwipe = [[[UISwipeGestureRecognizer alloc]
                                             initWithTarget:self action:@selector(nextTrackPressed)] autorelease];
    nextSwipe.direction = UISwipeGestureRecognizerDirectionLeft;
    [_artwork addGestureRecognizer:nextSwipe];
    UISwipeGestureRecognizer *previousSwipe = [[[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self action:@selector(previousTrackPressed)] autorelease];
    previousSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [_artwork addGestureRecognizer:previousSwipe];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:YTMPlayerDidChangeNotification
                                               object:_player];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!_progressTimer) {
        _progressTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5f
                                                            target:self
                                                          selector:@selector(updateProgress)
                                                          userInfo:nil
                                                            repeats:YES] retain];
    }
    [self becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [_progressTimer invalidate];
    [_progressTimer release];
    _progressTimer = nil;
    [self resignFirstResponder];
    [super viewWillDisappear:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    _backgroundGradient.frame = b;
    BOOL landscape = b.size.width > b.size.height;
    BOOL compact = PlayerIsCompactPhone(b.size.height);

    CGFloat headerHeight = PlayerIsPad() ? 52.0f : 44.0f;
    _headerBar.frame = CGRectMake(0.0f, 0.0f, b.size.width, headerHeight);
    _headerSearch.frame = CGRectMake(12.0f, 0.0f, 68.0f, headerHeight);
    _headerTitle.frame = CGRectMake(0.0f, 0.0f, b.size.width, headerHeight);

    if (landscape) {
        CGFloat side = PlayerIsPad() ? 28.0f : 14.0f;
        /* leave a little more air below the header on the wide ipad layout */
        CGFloat top = headerHeight + (PlayerIsPad() ? 28.0f : 8.0f);
        CGFloat leftWidth = MIN(b.size.height - 56.0f, b.size.width * 0.42f);
        if (leftWidth < 172.0f) leftWidth = 172.0f;
        CGFloat artSize = MIN(leftWidth - 18.0f, b.size.height - 116.0f);
        if (artSize < 132.0f) artSize = 132.0f;
        if (artSize > 520.0f) artSize = 520.0f;
        CGFloat artX = side + floorf((leftWidth - artSize) * 0.5f);
        CGFloat artY = top;
        _artwork.frame = CGRectMake(artX, artY, artSize, artSize);

        CGFloat titleY = CGRectGetMaxY(_artwork.frame) + 7.0f;
        CGFloat leftTextWidth = leftWidth - 16.0f;
        _titleLabel.font = [UIFont boldSystemFontOfSize:compact ? 16.0f : 20.0f];
        _titleLabel.frame = CGRectMake(side + 8.0f, titleY, leftTextWidth, 25.0f);
        _artistLabel.frame = CGRectMake(side + 8.0f, titleY + 25.0f, leftTextWidth, 18.0f);

        CGFloat rightX = side + leftWidth + (PlayerIsPad() ? 32.0f : 20.0f);
        CGFloat rightWidth = MAX(120.0f, b.size.width - rightX - side);
        /* keep the transport block in the lower half instead of crowding the artwork */
        CGFloat sliderAnchor = PlayerIsPad() ? b.size.height * 0.54f : b.size.height * 0.50f;
        CGFloat sliderY = MIN(b.size.height - 126.0f, MAX(headerHeight + 38.0f,
                                                         sliderAnchor));
        _progress.frame = CGRectMake(rightX, sliderY, rightWidth, 24.0f);
        _elapsedLabel.frame = CGRectMake(rightX + 2.0f, sliderY + 18.0f, 70.0f, 18.0f);
        _durationLabel.frame = CGRectMake(rightX + rightWidth - 72.0f, sliderY + 18.0f,
                                          70.0f, 18.0f);

        CGFloat playSize = compact ? 64.0f : 76.0f;
        CGFloat controlY = MIN(b.size.height - playSize - 18.0f, sliderY + 56.0f);
        _playButton.frame = CGRectMake(rightX + floorf((rightWidth - playSize) * 0.5f),
                                       controlY, playSize, playSize);
        CGFloat small = compact ? 42.0f : 48.0f;
        CGFloat gap = 8.0f;
        CGFloat centerX = CGRectGetMidX(_playButton.frame);
        CGFloat smallY = controlY + floorf((playSize - small) * 0.5f);
        _previousButton.frame = CGRectMake(centerX - playSize * 0.5f - gap - small,
                                           smallY, small, small);
        _nextButton.frame = CGRectMake(centerX + playSize * 0.5f + gap,
                                       smallY, small, small);
        _repeatButton.frame = CGRectMake(CGRectGetMaxX(_nextButton.frame) + gap,
                                         smallY, small, small);
        _favoriteButton.frame = CGRectMake(CGRectGetMinX(_previousButton.frame) - gap - small,
                                           smallY, small, small);
        _volumeView.frame = CGRectMake(rightX, MIN(b.size.height - 30.0f, controlY + playSize + 8.0f),
                                       rightWidth, 24.0f);
    } else {
        CGFloat artTop = PlayerIsPad() ? headerHeight + 12.0f : headerHeight + 8.0f;
        CGFloat artSize;
        if (PlayerIsPad())
            artSize = MIN(b.size.width - 96.0f, b.size.height * 0.50f);
        else
            artSize = MIN(b.size.width - 44.0f, b.size.height - artTop - 190.0f);
        artSize = MIN(PlayerIsPad() ? 520.0f : 220.0f, MAX(150.0f, artSize));
        CGFloat artX = floorf((b.size.width - artSize) * 0.5f);
        _artwork.frame = CGRectMake(artX, artTop, artSize, artSize);

        CGFloat titleY = CGRectGetMaxY(_artwork.frame) + 7.0f;
        _titleLabel.font = [UIFont boldSystemFontOfSize:PlayerIsPad() ? 24.0f : 20.0f];
        _titleLabel.frame = CGRectMake(24.0f, titleY, b.size.width - 48.0f, 30.0f);
        _artistLabel.frame = CGRectMake(24.0f, titleY + 27.0f, b.size.width - 48.0f, 20.0f);

        CGFloat sliderY = CGRectGetMaxY(_artistLabel.frame) + 8.0f;
        _progress.frame = CGRectMake(24.0f, sliderY, b.size.width - 48.0f, 24.0f);
        _elapsedLabel.frame = CGRectMake(26.0f, sliderY + 18.0f, 70.0f, 18.0f);
        _durationLabel.frame = CGRectMake(b.size.width - 96.0f, sliderY + 18.0f,
                                          70.0f, 18.0f);

        CGFloat controlY = MIN(b.size.height - 92.0f, sliderY + 46.0f);
        CGFloat playSize = PlayerIsPad() ? 86.0f : 62.0f;
        _playButton.frame = CGRectMake(floorf((b.size.width - playSize) * 0.5f), controlY,
                                       playSize, playSize);
        CGFloat small = PlayerIsPad() ? 52.0f : 42.0f;
        CGFloat gap = PlayerIsPad() ? 9.0f : 7.0f;
        CGFloat centerX = CGRectGetMidX(_playButton.frame);
        CGFloat smallY = controlY + floorf((playSize - small) * 0.5f);
        _previousButton.frame = CGRectMake(centerX - playSize * 0.5f - gap - small,
                                           smallY, small, small);
        _nextButton.frame = CGRectMake(centerX + playSize * 0.5f + gap,
                                       smallY, small, small);
        _repeatButton.frame = CGRectMake(CGRectGetMaxX(_nextButton.frame) + gap,
                                         smallY, small, small);
        _favoriteButton.frame = CGRectMake(CGRectGetMinX(_previousButton.frame) - gap - small,
                                           smallY, small, small);
        CGFloat volumeY = MIN(b.size.height - 28.0f, controlY + playSize + 8.0f);
        _volumeView.frame = CGRectMake(38.0f, volumeY, b.size.width - 76.0f, 24.0f);
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                          duration:(NSTimeInterval)duration {
    (void)orientation;
    (void)duration;
    [self.view setNeedsLayout];
}

- (void)refresh {
    YTMTrack *track = _player.track;
    if (!track) {
        _titleLabel.text = @"Nothing playing";
        _artistLabel.text = @"Choose a track from search";
        _elapsedLabel.text = @"0:00";
        _durationLabel.text = @"0:00";
        _progress.value = 0.0f;
        [_playButton setPlaying:NO];
        [_favoriteButton setActive:NO];
        [_repeatButton setActive:_player.isRepeating];
        _artwork.image = [UIImage imageNamed:@"Icon.png"];
        return;
    }

    _titleLabel.text = track.title;
    _artistLabel.text = track.artist.length ? track.artist : @"Unknown artist";
    _progress.value = [_player progress];
    _elapsedLabel.text = PlayerTime((NSUInteger)[_player currentTime]);
    _durationLabel.text = PlayerTime((NSUInteger)[_player duration]);
    [_playButton setPlaying:_player.isPlaying];
    [_favoriteButton setActive:TuneTubeTrackIsSaved(track)];
    [_repeatButton setActive:_player.isRepeating];

    NSString *requestedURL = [track.thumbnailURL copy];
    TuneLoadImage(requestedURL, ^(UIImage *image) {
        if (image && _player.track == track &&
            [requestedURL isEqualToString:track.thumbnailURL]) {
            _artwork.image = image;
        }
    });
    [requestedURL release];
}

- (void)updateProgress {
    if (!_player.track) return;
    _progress.value = [_player progress];
    _elapsedLabel.text = PlayerTime((NSUInteger)[_player currentTime]);
    _durationLabel.text = PlayerTime((NSUInteger)[_player duration]);
}

- (void)progressChanged:(UISlider *)slider {
    [_player seekToProgress:slider.value];
    [self updateProgress];
}

- (void)closePressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)togglePressed {
    [_player toggle];
}

- (void)favoritePressed {
    YTMTrack *track = _player.track;
    if (!track) return;
    if (TuneTubeTrackIsSaved(track)) TuneTubeRemoveTrack(track);
    else TuneTubeSaveTrack(track);
    [_favoriteButton setActive:TuneTubeTrackIsSaved(track)];
}

- (void)nextTrackPressed {
    [_player nextTrack];
    if (_player.track) TuneTubeRecordTrack(_player.track);
}

- (void)previousTrackPressed {
    [_player previousTrack];
    if (_player.track) TuneTubeRecordTrack(_player.track);
}

- (void)repeatPressed {
    [_player setRepeating:!_player.isRepeating];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) return;
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay:
        case UIEventSubtypeRemoteControlPause:
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [_player toggle];
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [_player nextTrack];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [_player previousTrack];
            break;
        default:
            break;
    }
}

@end
