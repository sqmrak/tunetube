#ifndef TUNETUBE_THEME_H
#define TUNETUBE_THEME_H

#import <UIKit/UIKit.h>

extern NSString * const TuneTubeThemeDidChangeNotification;
extern NSString * const TuneTubeFocusSearchNotification;

BOOL TuneTubeThemeIsLight(void);
void TuneTubeThemeSetLight(BOOL light);
void TuneTubeStyleNavigationBar(UINavigationBar *bar);

UIColor *TuneThemeBackgroundTop(void);
UIColor *TuneThemeBackgroundBottom(void);
UIColor *TuneThemeSurface(void);
UIColor *TuneThemeSurfaceTop(void);
UIColor *TuneThemeSurfaceBottom(void);
UIColor *TuneThemeHeader(void);
UIColor *TuneThemeHeaderText(void);
UIColor *TuneThemeNavigationTop(void);
UIColor *TuneThemeNavigationBottom(void);
UIColor *TuneThemeNavigationBorder(void);
UIColor *TuneThemeRaisedTop(void);
UIColor *TuneThemeRaisedBottom(void);
UIColor *TuneThemeRaisedBorder(void);
UIColor *TuneThemeRaisedText(void);
UIColor *TuneThemeAccent(void);
UIColor *TuneThemePrimaryText(void);
UIColor *TuneThemeSecondaryText(void);
UIColor *TuneThemeMutedText(void);
UIColor *TuneThemeBorder(void);
UIColor *TuneThemeSearchBackground(void);

#endif /* TUNETUBE_THEME_H */
