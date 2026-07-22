#import "player_vc.h"

#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

#import "ytm_api.h"
#import "ytm_player.h"
#import "library_vc.h"
#import "play_button.h"
#import "tunetube_image_cache.h"
#import "tunetube_theme.h"

static NSString *PlayerTime(NSUInteger seconds) {
    return [NSString stringWithFormat:@"%lu:%02lu",
            (unsigned long)(seconds / 60), (unsigned long)(seconds % 60)];
}

static UIImage *TunePlayerMaskImage(UIImage *mask, UIColor *color) {
    if (!mask) return nil;
    UIGraphicsBeginImageContextWithOptions(mask.size, NO, mask.scale);
    CGRect rect = CGRectMake(0.0f, 0.0f, mask.size.width, mask.size.height);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    [mask drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TunePlayerLibraryImage(CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, MAX(1.3f, size * 0.075f));
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetLineCap(context, kCGLineCapRound);

    CGRect rear = CGRectMake(size * 0.18f, size * 0.14f, size * 0.58f, size * 0.66f);
    CGRect front = CGRectMake(size * 0.31f, size * 0.25f, size * 0.56f, size * 0.62f);
    CGContextStrokeRect(context, rear);
    CGContextStrokeRect(context, front);
    CGContextMoveToPoint(context, size * 0.43f, size * 0.45f);
    CGContextAddLineToPoint(context, size * 0.76f, size * 0.45f);
    CGContextMoveToPoint(context, size * 0.43f, size * 0.58f);
    CGContextAddLineToPoint(context, size * 0.76f, size * 0.58f);
    CGContextStrokePath(context);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *TunePlayerSearchImage(CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, MAX(1.3f, size * 0.075f));
    CGContextSetLineCap(context, kCGLineCapRound);

    CGContextStrokeEllipseInRect(context,
                                 CGRectMake(size * 0.16f, size * 0.14f,
                                            size * 0.48f, size * 0.48f));
    CGContextMoveToPoint(context, size * 0.56f, size * 0.56f);
    CGContextAddLineToPoint(context, size * 0.84f, size * 0.84f);
    CGContextStrokePath(context);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TunePlayerHeaderButton : UIButton {
    CAGradientLayer *_gradient;
}
- (void)applyTheme;
@end

@implementation TunePlayerHeaderButton

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _gradient = [[CAGradientLayer layer] retain];
    _gradient.cornerRadius = 8.0f;
    [self.layer insertSublayer:_gradient atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.layer.cornerRadius = 8.0f;
    self.layer.borderWidth = 1.0f;
    self.layer.borderColor = TuneThemeNavigationBorder().CGColor;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.24f;
    self.layer.shadowOffset = CGSizeMake(0.0f, 2.0f);
    self.layer.shadowRadius = 1.5f;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.adjustsImageWhenHighlighted = NO;
    return self;
}

- (void)dealloc {
    [_gradient release];
    [super dealloc];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
}

- (void)applyTheme {
    _gradient.colors = [NSArray arrayWithObjects:
                        (id)TuneThemeNavigationTop().CGColor,
                        (id)TuneThemeNavigationBottom().CGColor, nil];
    self.backgroundColor = [UIColor clearColor];
    self.layer.borderColor = TuneThemeNavigationBorder().CGColor;
    self.layer.shadowOpacity = 0.24f;
    [self setTitleColor:TuneThemeHeaderText() forState:UIControlStateNormal];
}

@end

static void PlayerStyleVolumeView(MPVolumeView *volumeView) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(28.0f, 28.0f), NO, 0.0f);
    CGContextRef thumbContext = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(thumbContext,
                                   [UIColor colorWithWhite:0.58f alpha:1.0f].CGColor);
    CGContextFillEllipseInRect(thumbContext, CGRectMake(2.0f, 2.0f, 24.0f, 24.0f));
    CGContextSetStrokeColorWithColor(thumbContext, TuneThemeBorder().CGColor);
    CGContextSetLineWidth(thumbContext, 1.0f);
    CGContextStrokeEllipseInRect(thumbContext, CGRectMake(2.0f, 2.0f, 24.0f, 24.0f));
    UIImage *volumeThumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    for (UIView *subview in volumeView.subviews) {
        if (![subview isKindOfClass:[UISlider class]]) continue;
        UISlider *slider = (UISlider *)subview;
        if ([slider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
            slider.minimumTrackTintColor = TuneThemeAccent();
            slider.maximumTrackTintColor = TuneThemeMutedText();
        }
        [slider setThumbImage:volumeThumb forState:UIControlStateNormal];
        [slider setThumbImage:volumeThumb forState:UIControlStateHighlighted];
        if ([slider respondsToSelector:@selector(setThumbTintColor:)])
            slider.thumbTintColor = TuneThemePrimaryText();
        if (volumeView.bounds.size.height > 0.0f && slider.frame.size.height > 0.0f) {
            CGRect frame = slider.frame;
            frame.origin.y = floorf((volumeView.bounds.size.height - frame.size.height) * 0.5f);
            slider.frame = frame;
        }
        break;
    }
}

@interface TunePlayerVolumeView : MPVolumeView
@end

@implementation TunePlayerVolumeView

- (void)layoutSubviews {
    [super layoutSubviews];
    PlayerStyleVolumeView(self);
}

@end

static void PlayerStyleSlider(UISlider *slider) {
    if ([slider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
        slider.minimumTrackTintColor = TuneThemeAccent();
        slider.maximumTrackTintColor = TuneThemeMutedText();
    }
    if ([slider respondsToSelector:@selector(setThumbTintColor:)])
        slider.thumbTintColor = TuneThemePrimaryText();
}

static BOOL PlayerIsPad(void) {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
}

static BOOL PlayerIsCompactPhone(CGFloat height) {
    return !PlayerIsPad() && height <= 568.0f;
}

@interface TunePlayerVC ()
- (void)refresh:(NSNotification *)note;
- (void)updateProgress:(NSTimer *)timer;
- (void)progressChanged:(UISlider *)slider;
- (void)searchPressed;
- (void)libraryPressed;
- (void)backPressed;
- (void)togglePressed;
- (void)favoritePressed;
- (void)nextTrackPressed;
- (void)previousTrackPressed;
- (void)repeatPressed;
- (void)applyTheme:(NSNotification *)note;
@end

@implementation TunePlayerVC

- (id)initWithPlayer:(YTMPlayer *)player {
    return [self initWithPlayer:player api:nil];
}

- (id)initWithPlayer:(YTMPlayer *)player api:(YTMAPI *)api {
    self = [super init];
    if (self) {
        _player = [player retain];
        _api = [api retain];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_player release];
    [_api release];
    [_backgroundGradient release];
    [_headerGradient release];
    [_headerBar release];
    [_headerSearch release];
    [_headerLibrary release];
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
    view.backgroundColor = TuneThemeBackgroundBottom();
    self.view = view;
}

- (UIButton *)textButton:(NSString *)title size:(CGFloat)size {
    UIButton *button = [[[TunePlayerHeaderButton alloc] initWithFrame:CGRectZero] autorelease];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:TuneThemeHeaderText() forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:size];
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = NO;
    self.title = @"TuneTube";
    self.navigationItem.leftBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:@"Back"
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(backPressed)] autorelease];
    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:@"Library"
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(libraryPressed)] autorelease];
    _backgroundGradient = [[CAGradientLayer layer] retain];
    _backgroundGradient.colors = [NSArray arrayWithObjects:
                                  (id)TuneThemeBackgroundTop().CGColor,
                                  (id)TuneThemeBackgroundBottom().CGColor, nil];
    _backgroundGradient.locations = [NSArray arrayWithObjects:@0.0f, @1.0f, nil];
    [self.view.layer insertSublayer:(CAGradientLayer *)_backgroundGradient atIndex:0];

    _headerBar = [[UIView alloc] initWithFrame:CGRectZero];
    _headerBar.backgroundColor = [UIColor clearColor];
    _headerBar.hidden = YES;
    _headerBar.layer.borderWidth = 1.0f;
    _headerBar.layer.borderColor = TuneThemeNavigationBorder().CGColor;
    _headerGradient = [[CAGradientLayer layer] retain];
    [_headerBar.layer insertSublayer:_headerGradient atIndex:0];
    [self.view addSubview:_headerBar];

    _headerSearch = [[self textButton:@"Search" size:12.0f] retain];
    [_headerSearch setTitle:nil forState:UIControlStateNormal];
    [_headerSearch setImage:TunePlayerMaskImage(TunePlayerSearchImage(24.0f),
                                                TuneThemeHeaderText())
                    forState:UIControlStateNormal];
    _headerSearch.imageEdgeInsets = UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f);
    _headerSearch.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _headerSearch.accessibilityLabel = @"Search";
    [_headerSearch addTarget:self action:@selector(searchPressed)
            forControlEvents:UIControlEventTouchUpInside];
    [_headerBar addSubview:_headerSearch];

    _headerLibrary = [[self textButton:@"Library" size:12.0f] retain];
    [_headerLibrary setTitle:nil forState:UIControlStateNormal];
    [_headerLibrary setImage:TunePlayerMaskImage(TunePlayerLibraryImage(24.0f),
                                                 TuneThemeHeaderText())
                     forState:UIControlStateNormal];
    _headerLibrary.imageEdgeInsets = UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f);
    _headerLibrary.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    _headerLibrary.accessibilityLabel = @"Library";
    [_headerLibrary addTarget:self action:@selector(libraryPressed)
              forControlEvents:UIControlEventTouchUpInside];
    [_headerBar addSubview:_headerLibrary];

    _headerTitle = [[UILabel alloc] initWithFrame:CGRectZero];
    _headerTitle.backgroundColor = [UIColor clearColor];
    _headerTitle.textColor = TuneThemePrimaryText();
    _headerTitle.font = [UIFont boldSystemFontOfSize:17.0f];
    _headerTitle.textAlignment = NSTextAlignmentCenter;
    _headerTitle.text = @"TuneTube";
    _headerTitle.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.65f];
    _headerTitle.shadowOffset = CGSizeMake(0.0f, 2.0f);
    [_headerBar addSubview:_headerTitle];

    _artwork = [[UIImageView alloc] initWithFrame:CGRectZero];
    _artwork.image = [UIImage imageNamed:@"Icon.png"];
    _artwork.contentMode = UIViewContentModeScaleAspectFill;
    _artwork.layer.cornerRadius = 12.0f;
    _artwork.layer.masksToBounds = YES;
    _artwork.layer.borderWidth = 1.0f;
    _artwork.layer.borderColor = TuneThemeBorder().CGColor;
    _artwork.layer.shadowColor = [UIColor blackColor].CGColor;
    _artwork.layer.shadowOpacity = 0.7f;
    _artwork.layer.shadowOffset = CGSizeMake(0.0f, 6.0f);
    _artwork.layer.shadowRadius = 8.0f;
    [self.view addSubview:_artwork];

    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textColor = TuneThemePrimaryText();
    _titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    [self.view addSubview:_titleLabel];

    _artistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _artistLabel.backgroundColor = [UIColor clearColor];
    _artistLabel.textColor = TuneThemeSecondaryText();
    _artistLabel.font = [UIFont systemFontOfSize:12.0f];
    _artistLabel.textAlignment = NSTextAlignmentCenter;
    _artistLabel.lineBreakMode = UILineBreakModeTailTruncation;
    [self.view addSubview:_artistLabel];

    _progress = [[UISlider alloc] initWithFrame:CGRectZero];
    _progress.minimumValue = 0.0f;
    _progress.maximumValue = 1.0f;
    _progress.value = 0.0f;
    PlayerStyleSlider(_progress);
    _progress.userInteractionEnabled = YES;
    [_progress addTarget:self action:@selector(progressChanged:)
        forControlEvents:UIControlEventValueChanged | UIControlEventTouchUpInside |
                         UIControlEventTouchUpOutside];
    [self.view addSubview:_progress];

    _elapsedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _elapsedLabel.backgroundColor = [UIColor clearColor];
    _elapsedLabel.textColor = TuneThemeMutedText();
    _elapsedLabel.font = [UIFont systemFontOfSize:11.0f];
    [self.view addSubview:_elapsedLabel];

    _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _durationLabel.backgroundColor = [UIColor clearColor];
    _durationLabel.textColor = TuneThemeMutedText();
    _durationLabel.font = [UIFont systemFontOfSize:11.0f];
    _durationLabel.textAlignment = NSTextAlignmentRight;
    [self.view addSubview:_durationLabel];

    _volumeView = [[TunePlayerVolumeView alloc] initWithFrame:CGRectZero];
    _volumeView.showsRouteButton = NO;
    _volumeView.showsVolumeSlider = YES;
    _volumeView.backgroundColor = [UIColor clearColor];
    _volumeView.clipsToBounds = NO;
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
                                             selector:@selector(refresh:)
                                                 name:YTMPlayerDidChangeNotification
                                               object:_player];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyTheme:)
                                                 name:TuneTubeThemeDidChangeNotification
                                               object:nil];
    [self applyTheme:nil];
    [self refresh:nil];
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
    _backgroundGradient.locations = [NSArray arrayWithObjects:@0.0f, @1.0f, nil];
    _headerGradient.frame = _headerBar.bounds;
    _headerGradient.colors = [NSArray arrayWithObjects:
                              (id)TuneThemeNavigationTop().CGColor,
                              (id)TuneThemeNavigationBottom().CGColor, nil];
    _headerBar.backgroundColor = [UIColor clearColor];
    _headerBar.layer.borderColor = TuneThemeNavigationBorder().CGColor;
    [_headerSearch setImage:TunePlayerMaskImage(TunePlayerSearchImage(24.0f),
                                                TuneThemeHeaderText())
                    forState:UIControlStateNormal];
    [_headerLibrary setImage:TunePlayerMaskImage(TunePlayerLibraryImage(24.0f),
                                                 TuneThemeHeaderText())
                     forState:UIControlStateNormal];
    [(TunePlayerHeaderButton *)_headerSearch applyTheme];
    [(TunePlayerHeaderButton *)_headerLibrary applyTheme];
    _headerTitle.textColor = TuneThemePrimaryText();
    _artwork.layer.borderColor = TuneThemeBorder().CGColor;
    _titleLabel.textColor = TuneThemePrimaryText();
    _artistLabel.textColor = TuneThemeSecondaryText();
    _elapsedLabel.textColor = TuneThemeMutedText();
    _durationLabel.textColor = TuneThemeMutedText();
    PlayerStyleSlider(_progress);
    PlayerStyleVolumeView(_volumeView);
    [self.view setNeedsLayout];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!_progressTimer) {
        _progressTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5f
                                                            target:self
                                                          selector:@selector(updateProgress:)
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

    CGFloat headerHeight = 0.0f;
    CGFloat headerButtonSize = landscape ? 30.0f : 34.0f;
    CGFloat headerButtonInset = b.size.width > 700.0f ? 28.0f : 14.0f;
    CGFloat headerButtonY = landscape ? 7.0f : 12.0f;
    _headerBar.frame = CGRectMake(0.0f, 0.0f, b.size.width, headerHeight);
    _headerGradient.frame = _headerBar.bounds;
    _headerSearch.frame = CGRectMake(headerButtonInset, headerButtonY,
                                     headerButtonSize, headerButtonSize);
    _headerLibrary.frame = CGRectMake(b.size.width - headerButtonInset - headerButtonSize,
                                      headerButtonY, headerButtonSize, headerButtonSize);
    _headerTitle.frame = CGRectMake(headerButtonInset + headerButtonSize + 8.0f, 0.0f,
                                    b.size.width - (headerButtonInset + headerButtonSize + 8.0f) * 2.0f,
                                    headerHeight);
    _headerTitle.font = [UIFont boldSystemFontOfSize:
                         landscape ? (PlayerIsPad() ? 23.0f : 20.0f) : 25.0f];

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
        CGFloat playSize = compact ? 58.0f : (PlayerIsPad() ? 76.0f : 68.0f);
        CGFloat small = compact ? 34.0f : (PlayerIsPad() ? 48.0f : 42.0f);
        CGFloat gap = compact ? 4.0f : 8.0f;
        CGFloat artworkCenterY = CGRectGetMidY(_artwork.frame);
        CGFloat controlY = artworkCenterY - floorf(playSize * 0.5f);
        CGFloat sliderY = MAX(headerHeight + 34.0f, controlY - 42.0f);
        _progress.frame = CGRectMake(rightX, sliderY, rightWidth, 24.0f);
        _elapsedLabel.frame = CGRectMake(rightX + 2.0f, sliderY + 18.0f, 70.0f, 18.0f);
        _durationLabel.frame = CGRectMake(rightX + rightWidth - 72.0f, sliderY + 18.0f,
                                          70.0f, 18.0f);

        _playButton.frame = CGRectMake(rightX + floorf((rightWidth - playSize) * 0.5f),
                                       controlY, playSize, playSize);
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
        _volumeView.frame = CGRectMake(rightX, MIN(b.size.height - 32.0f, controlY + playSize + 8.0f) - 4.0f,
                                       rightWidth, 24.0f);
        PlayerStyleVolumeView(_volumeView);
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
        _volumeView.frame = CGRectMake(38.0f, volumeY - 4.0f, b.size.width - 76.0f, 24.0f);
        PlayerStyleVolumeView(_volumeView);
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                          duration:(NSTimeInterval)duration {
    (void)orientation;
    (void)duration;
    [self.view setNeedsLayout];
}

- (void)refresh:(NSNotification *)note {
    NSError *error = [[note userInfo] objectForKey:@"error"];
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
    if (error) {
        _artistLabel.text = YTMDisplayArtist(track.artist);
        _elapsedLabel.text = @"0:00";
        _durationLabel.text = PlayerTime(track.duration);
        _progress.value = 0.0f;
        [_playButton setPlaying:NO];
        return;
    }
    _artistLabel.text = YTMDisplayArtist(track.artist);
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

- (void)updateProgress:(NSTimer *)timer {
    (void)timer;
    if (!_player.track) return;
    _progress.value = [_player progress];
    _elapsedLabel.text = PlayerTime((NSUInteger)[_player currentTime]);
    _durationLabel.text = PlayerTime((NSUInteger)[_player duration]);
}

- (void)progressChanged:(UISlider *)slider {
    [_player seekToProgress:slider.value];
    [self updateProgress:nil];
}

- (void)searchPressed {
    [[NSNotificationCenter defaultCenter]
     postNotificationName:TuneTubeFocusSearchNotification object:nil];
}

- (void)libraryPressed {
    if (!_player || !_api) return;
    TuneLibraryVC *library = [[[TuneLibraryVC alloc] initWithPlayer:_player api:_api] autorelease];
    UINavigationController *navigation =
        [[[UINavigationController alloc] initWithRootViewController:library] autorelease];
    navigation.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)backPressed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)togglePressed {
    if (!_player.track) return;
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
