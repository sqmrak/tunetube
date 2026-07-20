#ifndef TUNTUBE_SETTINGS_VC_H
#define TUNTUBE_SETTINGS_VC_H

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface TuneSettingsVC : UIViewController <UITableViewDataSource, UITableViewDelegate,
                                              UIAlertViewDelegate> {
    UITableView *_table;
    CAGradientLayer *_backgroundGradient;
}
@end

#endif /* TUNTUBE_SETTINGS_VC_H */
