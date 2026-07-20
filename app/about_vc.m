#import "about_vc.h"

#import <QuartzCore/QuartzCore.h>
#import "tuntube_config.h"

static UIColor *AboutColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@interface TuneAboutVC ()
- (void)githubPressed;
@end

@implementation TuneAboutVC

- (void)dealloc {
    [_scroll release];
    [_card release];
    [_info release];
    [_bodyLabel release];
    [_githubButton release];
    [_cardGradient release];
    [_infoGradient release];
    [super dealloc];
}

- (void)loadView {
    UIView *view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    view.backgroundColor = AboutColor(0.02f, 0.06f, 0.08f, 1.0f);
    CAGradientLayer *background = [CAGradientLayer layer];
    background.colors = [NSArray arrayWithObjects:
                         (id)AboutColor(0.03f, 0.20f, 0.22f, 1.0f).CGColor,
                         (id)AboutColor(0.02f, 0.06f, 0.08f, 1.0f).CGColor,
                         (id)AboutColor(0.01f, 0.02f, 0.03f, 1.0f).CGColor, nil];
    [view.layer insertSublayer:background atIndex:0];
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"About";
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.navigationController.navigationBar.tintColor = AboutColor(0.77f, 0.06f, 0.05f, 1.0f);
    self.navigationController.navigationBar.titleTextAttributes =
        [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                     forKey:UITextAttributeTextColor];

    _scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scroll.backgroundColor = [UIColor clearColor];
    _scroll.alwaysBounceVertical = YES;
    _scroll.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:_scroll];

    _card = [[UIView alloc] initWithFrame:CGRectZero];
    _card.layer.cornerRadius = 14.0f;
    _card.layer.masksToBounds = YES;
    _card.layer.borderWidth = 1.0f;
    _card.layer.borderColor = AboutColor(1.0f, 0.30f, 0.24f, 0.5f).CGColor;
    _cardGradient = [[CAGradientLayer layer] retain];
    _cardGradient.cornerRadius = 14.0f;
    [_card.layer insertSublayer:_cardGradient atIndex:0];
    [_scroll addSubview:_card];

    UIImageView *avatar = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sqmrak.jpg"]] autorelease];
    avatar.tag = 1;
    avatar.backgroundColor = AboutColor(0.12f, 0.15f, 0.16f, 1.0f);
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    avatar.layer.cornerRadius = 12.0f;
    avatar.layer.masksToBounds = YES;
    avatar.layer.borderWidth = 2.0f;
    avatar.layer.borderColor = AboutColor(1.0f, 1.0f, 1.0f, 0.42f).CGColor;
    [_card addSubview:avatar];

    UILabel *name = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    name.tag = 2;
    name.backgroundColor = [UIColor clearColor];
    name.textColor = [UIColor whiteColor];
    name.shadowColor = [UIColor colorWithWhite:0 alpha:0.62f];
    name.shadowOffset = CGSizeMake(0.0f, 1.0f);
    name.font = [UIFont boldSystemFontOfSize:18.0f];
    name.text = @"TuneTube";
    [_card addSubview:name];

    _githubButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [_githubButton setTitle:@"github.com/sqmrak" forState:UIControlStateNormal];
    [_githubButton setTitleColor:AboutColor(1.0f, 0.91f, 0.86f, 1.0f) forState:UIControlStateNormal];
    _githubButton.titleLabel.font = [UIFont systemFontOfSize:14.0f];
    _githubButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [_githubButton addTarget:self action:@selector(githubPressed)
            forControlEvents:UIControlEventTouchUpInside];
    [_card addSubview:_githubButton];

    _info = [[UIView alloc] initWithFrame:CGRectZero];
    _info.layer.cornerRadius = 14.0f;
    _info.layer.masksToBounds = YES;
    _info.layer.borderWidth = 1.0f;
    _info.layer.borderColor = AboutColor(0.28f, 0.48f, 0.49f, 0.44f).CGColor;
    _infoGradient = [[CAGradientLayer layer] retain];
    _infoGradient.cornerRadius = 14.0f;
    [_info.layer insertSublayer:_infoGradient atIndex:0];
    [_scroll addSubview:_info];

    _bodyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _bodyLabel.backgroundColor = [UIColor clearColor];
    _bodyLabel.textColor = AboutColor(0.86f, 0.91f, 0.90f, 1.0f);
    _bodyLabel.font = [UIFont systemFontOfSize:14.0f];
    _bodyLabel.numberOfLines = 0;
    _bodyLabel.lineBreakMode = UILineBreakModeWordWrap;
    _bodyLabel.text = [NSString stringWithFormat:
                       @"YouTube Music client for iOS 6-10\n\n"
                        "TuneTube searches YouTube Music and plays audio anonymously. "
                        "No Google password, cookies, or sign-in flow are required.\n\n"
                        "Built for armv7 and arm64.\n"
                        "Version: %@", TUNTUBE_VERSION];
    [_info addSubview:_bodyLabel];

    [self layoutAbout];
}

- (void)layoutAbout {
    CGRect bounds = self.view.bounds;
    _scroll.frame = bounds;

    CGFloat contentWidth = MIN(bounds.size.width, 700.0f);
    CGFloat contentX = floorf((bounds.size.width - contentWidth) * 0.5f);
    CGFloat side = bounds.size.width > 700.0f ? 22.0f : 12.0f;
    CGFloat cardWidth = MAX(160.0f, contentWidth - side * 2.0f);

    _card.frame = CGRectMake(contentX + side, 16.0f, cardWidth, 118.0f);
    _cardGradient.frame = _card.bounds;
    _cardGradient.colors = [NSArray arrayWithObjects:
                            (id)AboutColor(0.91f, 0.07f, 0.05f, 1.0f).CGColor,
                            (id)AboutColor(0.34f, 0.02f, 0.02f, 1.0f).CGColor, nil];
    UIImageView *avatar = (UIImageView *)[_card viewWithTag:1];
    UILabel *name = (UILabel *)[_card viewWithTag:2];
    avatar.frame = CGRectMake(14.0f, 14.0f, 90.0f, 90.0f);
    name.frame = CGRectMake(120.0f, 28.0f, MAX(40.0f, cardWidth - 132.0f), 28.0f);
    _githubButton.frame = CGRectMake(120.0f, 61.0f, MAX(40.0f, cardWidth - 132.0f), 28.0f);

    CGFloat textWidth = cardWidth - 32.0f;
    CGSize textSize = [_bodyLabel.text sizeWithFont:_bodyLabel.font
                                  constrainedToSize:CGSizeMake(textWidth, 5000.0f)
                                      lineBreakMode:UILineBreakModeWordWrap];
    if (textSize.height < 60.0f) textSize.height = 60.0f;
    CGFloat infoY = CGRectGetMaxY(_card.frame) + 12.0f;
    CGFloat infoHeight = textSize.height + 32.0f;
    _info.frame = CGRectMake(contentX + side, infoY, cardWidth, infoHeight);
    _infoGradient.frame = _info.bounds;
    _infoGradient.colors = [NSArray arrayWithObjects:
                            (id)AboutColor(0.12f, 0.20f, 0.21f, 1.0f).CGColor,
                            (id)AboutColor(0.04f, 0.08f, 0.09f, 1.0f).CGColor, nil];
    _bodyLabel.frame = CGRectMake(16.0f, 16.0f, textWidth, textSize.height + 2.0f);
    _scroll.contentSize = CGSizeMake(bounds.size.width, CGRectGetMaxY(_info.frame) + 24.0f);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutAbout];
}

- (void)githubPressed {
    NSURL *url = [NSURL URLWithString:@"https://github.com/sqmrak"];
    if ([[UIApplication sharedApplication] canOpenURL:url])
        [[UIApplication sharedApplication] openURL:url];
}

@end
