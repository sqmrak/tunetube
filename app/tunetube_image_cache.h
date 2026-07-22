#ifndef TUNETUBE_IMAGE_CACHE_H
#define TUNETUBE_IMAGE_CACHE_H

#import <UIKit/UIKit.h>

typedef void (^TuneImageCompletion)(UIImage *image);

UIImage *TuneCachedImage(NSString *urlString);
void TuneLoadImage(NSString *urlString, TuneImageCompletion completion);

#endif
