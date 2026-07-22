#ifndef YTM_API_H
#define YTM_API_H

#import <Foundation/Foundation.h>

/* keep a fallback for fresh installs; settings can replace it */
FOUNDATION_EXPORT NSString * const YTMDefaultAPIKey;
FOUNDATION_EXPORT NSString *YTMDisplayArtist(NSString *artist);

@interface YTMTrack : NSObject {
    NSString *_videoID;
    NSString *_title;
    NSString *_artist;
    NSString *_album;
    NSString *_thumbnailURL;
    NSUInteger _duration;
}

@property(nonatomic, readonly) NSString *videoID;
@property(nonatomic, readonly) NSString *title;
@property(nonatomic, readonly) NSString *artist;
@property(nonatomic, readonly) NSString *album;
@property(nonatomic, readonly) NSString *thumbnailURL;
@property(nonatomic, readonly) NSUInteger duration;

- (id)initWithVideoID:(NSString *)videoID
                title:(NSString *)title
               artist:(NSString *)artist
                album:(NSString *)album
        thumbnailURL:(NSString *)thumbnailURL
             duration:(NSUInteger)duration;

@end

typedef void (^YTMSearchCompletion)(NSArray *tracks, NSError *error);
typedef void (^YTMAudioCompletion)(NSURL *url, NSError *error);

@interface YTMAPI : NSObject {
    NSString *_apiKey;
}

- (id)initWithAPIKey:(NSString *)apiKey;
- (void)search:(NSString *)query completion:(YTMSearchCompletion)completion;
- (void)audioURLForTrack:(YTMTrack *)track completion:(YTMAudioCompletion)completion;

@end

#endif /* ytm_api_h */
