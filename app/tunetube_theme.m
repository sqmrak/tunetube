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
    UIColor *buttonColor = TuneThemeAccent();
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
        }
    }
}

UIColor *TuneThemeBackgroundTop(void) {
    return TuneThemeColor(0.15f, 0.06f, 0.07f, 0.97f, 0.94f, 0.90f);
}

UIColor *TuneThemeBackgroundBottom(void) {
    return TuneThemeColor(0.07f, 0.03f, 0.04f, 0.90f, 0.85f, 0.80f);
}

UIColor *TuneThemeSurface(void) {
    return TuneThemeColor(0.22f, 0.09f, 0.11f, 0.99f, 0.97f, 0.93f);
}

UIColor *TuneThemeSurfaceTop(void) {
    return TuneThemeColor(0.32f, 0.13f, 0.15f, 1.00f, 0.99f, 0.96f);
}

UIColor *TuneThemeSurfaceBottom(void) {
    return TuneThemeColor(0.18f, 0.07f, 0.09f, 0.94f, 0.89f, 0.85f);
}

UIColor *TuneThemeHeader(void) {
    return TuneThemeColor(0.35f, 0.10f, 0.12f, 0.70f, 0.28f, 0.30f);
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
    return TuneThemeColor(0.45f, 0.15f, 0.17f, 0.99f, 0.95f, 0.90f);
}

UIColor *TuneThemeRaisedBottom(void) {
    return TuneThemeColor(0.20f, 0.05f, 0.07f, 0.82f, 0.72f, 0.67f);
}

UIColor *TuneThemeRaisedBorder(void) {
    return TuneThemeColor(0.75f, 0.28f, 0.31f, 0.60f, 0.14f, 0.16f);
}

UIColor *TuneThemeRaisedText(void) {
    return TuneThemeColor(0.99f, 0.90f, 0.88f, 0.35f, 0.09f, 0.11f);
}

UIColor *TuneThemeAccent(void) {
    return TuneThemeColor(0.93f, 0.27f, 0.30f, 0.70f, 0.14f, 0.17f);
}

UIColor *TuneThemePrimaryText(void) {
    return TuneThemeColor(0.99f, 0.95f, 0.93f, 0.20f, 0.07f, 0.09f);
}

UIColor *TuneThemeSecondaryText(void) {
    return TuneThemeColor(0.84f, 0.65f, 0.64f, 0.42f, 0.23f, 0.25f);
}

UIColor *TuneThemeMutedText(void) {
    return TuneThemeColor(0.65f, 0.42f, 0.43f, 0.56f, 0.38f, 0.39f);
}

UIColor *TuneThemeBorder(void) {
    return TuneThemeColor(0.55f, 0.20f, 0.22f, 0.70f, 0.37f, 0.38f);
}

UIColor *TuneThemeSearchBackground(void) {
    return TuneThemeColor(0.18f, 0.08f, 0.09f, 1.00f, 0.98f, 0.95f);
}
