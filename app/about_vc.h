#ifndef TUNTUBE_ABOUT_VC_H
#define TUNTUBE_ABOUT_VC_H

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface TuneAboutVC : UIViewController {
    UIScrollView *_scroll;
    UIView *_card;
    UIView *_info;
    UILabel *_bodyLabel;
    UIButton *_githubButton;
    CAGradientLayer *_cardGradient;
    CAGradientLayer *_infoGradient;
}
@end

#endif /* TUNTUBE_ABOUT_VC_H */
