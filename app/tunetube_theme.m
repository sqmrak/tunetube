#import "tunetube_theme.h"

#import "tunetube_config.h"

NSString * const TuneTubeThemeDidChangeNotification = @"TuneTubeThemeDidChangeNotification";
NSString * const TuneTubeFocusSearchNotification = @"TuneTubeFocusSearchNotification";

static UIColor *TuneThemeColor(CGFloat darkRed, CGFloat darkGreen, CGFloat darkBlue,
                               CGFloat lightRed, CGFloat lightGreen, CGFloat lightBlue) {
    if (TuneTubeThemeIsLight())
        return [UIColor colorWithRed:lightRed green:lightGreen blue:lightBlue alpha:1.0f];
    return [UIColor colorWithRed:darkRed green:darkGreen blue:darkBlue alpha:1.0f];
}

static UIImage *TuneTubeNavigationBackgroundImage(void) {
    CGSize size = CGSizeMake(1.0f, 44.0f);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    NSArray *colors = [NSArray arrayWithObjects:
                       (id)TuneThemeNavigationTop().CGColor,
                       (id)TuneThemeNavigationBottom().CGColor, nil];
    CGFloat locations[] = {0.0f, 1.0f};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace,
                                                        (CFArrayRef)colors,
                                                        locations);
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(0.0f, 0.0f),
                                CGPointMake(0.0f, size.height),
                                0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIColor *TuneThemeNavigationButtonColor(void) {
    return TuneTubeThemeIsLight()
        ? TuneThemeAccent()
        : [UIColor colorWithRed:0.82f green:0.20f blue:0.23f alpha:1.0f];
}

static UIImage *TuneTubeNavigationButtonImage(BOOL highlighted) {
    CGSize size = CGSizeMake(76.0f, 32.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectInset(CGRectMake(0.5f, 0.5f, size.width - 1.0f,
                                         size.height - 1.0f), 0.0f, 0.0f);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:7.0f];
    CGContextSaveGState(context);
    [path addClip];

    UIColor *top;
    UIColor *bottom;
    if (TuneTubeThemeIsLight()) {
        top = highlighted ? [UIColor colorWithRed:1.00f green:0.58f blue:0.58f alpha:1.0f]
                          : [UIColor colorWithRed:0.99f green:0.53f blue:0.54f alpha:1.0f];
        bottom = highlighted ? [UIColor colorWithRed:0.90f green:0.36f blue:0.39f alpha:1.0f]
                             : [UIColor colorWithRed:0.84f green:0.31f blue:0.34f alpha:1.0f];
    } else {
        top = highlighted ? [UIColor colorWithRed:0.56f green:0.18f blue:0.20f alpha:1.0f]
                          : [UIColor colorWithRed:0.50f green:0.15f blue:0.17f alpha:1.0f];
        bottom = highlighted ? [UIColor colorWithRed:0.36f green:0.10f blue:0.12f alpha:1.0f]
                             : [UIColor colorWithRed:0.30f green:0.08f blue:0.10f alpha:1.0f];
    }
    NSArray *colors = [NSArray arrayWithObjects:(id)top.CGColor, (id)bottom.CGColor, nil];
    CGFloat locations[] = {0.0f, 1.0f};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace,
                                                        (CFArrayRef)colors,
                                                        locations);
    CGContextDrawLinearGradient(context, gradient,
                                CGPointMake(0.0f, 0.0f),
                                CGPointMake(0.0f, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);

    [[TuneThemeNavigationBorder() colorWithAlphaComponent:0.95f] setStroke];
    path.lineWidth = 1.0f;
    [path stroke];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(8.0f, 12.0f, 8.0f, 12.0f)];
}

BOOL TuneTubeThemeIsLight(void) {
    id value = [[NSUserDefaults standardUserDefaults]
                objectForKey:TUNETUBE_LIGHT_THEME_DEFAULTS_KEY];
    return value ? [value boolValue] : NO;
}

void TuneTubeThemeSetLight(BOOL light) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL oldValue = TuneTubeThemeIsLight();
    [defaults setBool:light forKey:TUNETUBE_LIGHT_THEME_DEFAULTS_KEY];
    [defaults synchronize];
    if (oldValue != light) {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:TuneTubeThemeDidChangeNotification object:nil];
    }
}

void TuneTubeStyleNavigationBar(UINavigationBar *bar) {
    if (!bar) return;
    bar.barStyle = UIBarStyleBlack;
    bar.translucent = NO;
    UIColor *buttonColor = TuneThemeNavigationButtonColor();
    bar.tintColor = buttonColor;
    SEL barTintSelector = NSSelectorFromString(@"setBarTintColor:");
    if ([bar respondsToSelector:barTintSelector])
        [bar performSelector:barTintSelector withObject:TuneThemeNavigationBottom()];
    UIImage *background = TuneTubeNavigationBackgroundImage();
    [bar setBackgroundImage:background forBarMetrics:UIBarMetricsDefault];
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
        [bar setBackgroundImage:background forBarMetrics:UIBarMetricsLandscapePhone];
    bar.titleTextAttributes = [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                                              forKey:UITextAttributeTextColor];
    NSDictionary *buttonTitleAttributes =
        [NSDictionary dictionaryWithObject:[UIColor whiteColor]
                                    forKey:UITextAttributeTextColor];
    for (UINavigationItem *item in bar.items) {
        NSArray *buttons = [NSArray arrayWithObjects:
                            item.leftBarButtonItem ?: [NSNull null],
                            item.rightBarButtonItem ?: [NSNull null], nil];
        for (id object in buttons) {
            if (![object isKindOfClass:[UIBarButtonItem class]]) continue;
            UIBarButtonItem *button = (UIBarButtonItem *)object;
            button.tintColor = buttonColor;
            [button setTitleTextAttributes:buttonTitleAttributes
                                  forState:UIControlStateNormal];
            [button setTitleTextAttributes:buttonTitleAttributes
                                  forState:UIControlStateHighlighted];
            if ([button respondsToSelector:@selector(setBackgroundImage:forState:barMetrics:)]) {
                UIImage *normal = TuneTubeNavigationButtonImage(NO);
                UIImage *highlighted = TuneTubeNavigationButtonImage(YES);
                [button setBackgroundImage:normal
                                   forState:UIControlStateNormal
                                 barMetrics:UIBarMetricsDefault];
                [button setBackgroundImage:highlighted
                                   forState:UIControlStateHighlighted
                                 barMetrics:UIBarMetricsDefault];
                [button setBackgroundImage:normal
                                   forState:UIControlStateNormal
                                 barMetrics:UIBarMetricsLandscapePhone];
                [button setBackgroundImage:highlighted
                                   forState:UIControlStateHighlighted
                                 barMetrics:UIBarMetricsLandscapePhone];
            }
        }
    }
}

UIColor *TuneThemeBackgroundTop(void) {
    return TuneThemeColor(0.24f, 0.075f, 0.09f, 0.97f, 0.94f, 0.90f);
}

UIColor *TuneThemeBackgroundBottom(void) {
    return TuneThemeColor(0.11f, 0.025f, 0.035f, 0.90f, 0.85f, 0.80f);
}

UIColor *TuneThemeSurface(void) {
    return TuneThemeColor(0.30f, 0.09f, 0.12f, 0.99f, 0.97f, 0.93f);
}

UIColor *TuneThemeSurfaceTop(void) {
    return TuneThemeColor(0.39f, 0.13f, 0.16f, 1.00f, 0.99f, 0.96f);
}

UIColor *TuneThemeSurfaceBottom(void) {
    return TuneThemeColor(0.26f, 0.065f, 0.095f, 0.94f, 0.89f, 0.85f);
}

UIColor *TuneThemeHeader(void) {
    return TuneThemeColor(0.40f, 0.11f, 0.14f, 0.70f, 0.28f, 0.30f);
}

UIColor *TuneThemeHeaderText(void) {
    return TuneThemeColor(1.00f, 0.95f, 0.93f, 1.00f, 0.98f, 0.96f);
}

UIColor *TuneThemeNavigationTop(void) {
    return TuneThemeColor(0.45f, 0.13f, 0.15f, 0.97f, 0.46f, 0.47f);
}

UIColor *TuneThemeNavigationBottom(void) {
    return TuneThemeColor(0.25f, 0.06f, 0.08f, 0.76f, 0.26f, 0.29f);
}

UIColor *TuneThemeNavigationBorder(void) {
    return TuneThemeColor(0.68f, 0.22f, 0.25f, 0.56f, 0.15f, 0.17f);
}

UIColor *TuneThemeRaisedTop(void) {
    return TuneThemeColor(0.48f, 0.15f, 0.18f, 0.99f, 0.95f, 0.90f);
}

UIColor *TuneThemeRaisedBottom(void) {
    return TuneThemeColor(0.25f, 0.06f, 0.09f, 0.82f, 0.72f, 0.67f);
}

UIColor *TuneThemeRaisedBorder(void) {
    return TuneThemeColor(0.75f, 0.28f, 0.31f, 0.60f, 0.14f, 0.16f);
}

UIColor *TuneThemeRaisedText(void) {
    return TuneThemeColor(0.99f, 0.90f, 0.88f, 0.35f, 0.09f, 0.11f);
}

UIColor *TuneThemeAccent(void) {
    return TuneThemeColor(0.84f, 0.20f, 0.24f, 0.70f, 0.14f, 0.17f);
}

UIColor *TuneThemePrimaryText(void) {
    return TuneThemeColor(0.99f, 0.95f, 0.93f, 0.20f, 0.07f, 0.09f);
}

UIColor *TuneThemeSecondaryText(void) {
    return TuneThemeColor(0.88f, 0.67f, 0.66f, 0.42f, 0.23f, 0.25f);
}

UIColor *TuneThemeMutedText(void) {
    return TuneThemeColor(0.70f, 0.47f, 0.48f, 0.56f, 0.38f, 0.39f);
}

UIColor *TuneThemeBorder(void) {
    return TuneThemeColor(0.64f, 0.22f, 0.25f, 0.70f, 0.37f, 0.38f);
}

UIColor *TuneThemeSearchBackground(void) {
    return TuneThemeColor(0.28f, 0.08f, 0.10f, 1.00f, 0.98f, 0.95f);
}

UIColor *TuneThemeSliderMinimum(void) {
    return TuneThemeColor(0.72f, 0.18f, 0.21f, 0.66f, 0.12f, 0.15f);
}

UIColor *TuneThemeSliderMaximum(void) {
    return TuneThemeColor(0.34f, 0.10f, 0.13f, 0.72f, 0.62f, 0.62f);
}

UIColor *TuneThemeSliderThumb(void) {
    return TuneThemeColor(0.64f, 0.46f, 0.47f, 0.86f, 0.82f, 0.78f);
}
