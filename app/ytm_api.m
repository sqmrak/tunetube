#import "ytm_api.h"

#import "../core/ytm_model.h"

static NSString * const YTMErrorDomain = @"com.sqmrak.tuntube.api";
static NSString * const YTMEndpoint = @"https://music.youtube.com/youtubei/v1";
static NSString * const YTMEndpointFallback = @"https://youtubei.googleapis.com/youtubei/v1";
static NSString * const YTMClientName = @"WEB_REMIX";
static NSString * const YTMClientVersion = @"1.20260707.12.00";
static NSString * const YTMPlayerEndpoint = @"https://www.youtube.com/youtubei/v1";
static NSString * const YTMPlayerEndpointFallback = @"https://youtubei.googleapis.com/youtubei/v1";
static NSString * const YTMIOSClientName = @"IOS";
static NSString * const YTMIOSClientVersion = @"21.26.4";
static NSString * const YTMAndroidClientName = @"ANDROID";
static NSString * const YTMAndroidClientVersion = @"21.26.364";
static NSString * const YTMAndroidVRClientName = @"ANDROID_VR";
static NSString * const YTMAndroidVRClientVersion = @"1.65.10";
/* keep a fallback so a fresh install can search before settings is opened */
NSString * const YTMDefaultAPIKey = @"AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8";

static NSError *YTMError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:YTMErrorDomain
                                code:code
                            userInfo:[NSDictionary dictionaryWithObject:message
                                                                 forKey:NSLocalizedDescriptionKey]];
}

static NSString *YTMString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSString *YTMText(id node) {
    if ([node isKindOfClass:[NSString class]]) return node;
    if (![node isKindOfClass:[NSDictionary class]]) return nil;

    NSString *simple = YTMString([(NSDictionary *)node objectForKey:@"simpleText"]);
    if (simple) return simple;

    NSArray *runs = [(NSDictionary *)node objectForKey:@"runs"];
    if ([runs isKindOfClass:[NSArray class]]) {
        NSMutableString *text = [NSMutableString string];
        for (id run in runs) {
            NSString *part = YTMString([run objectForKey:@"text"]);
            if (part) [text appendString:part];
        }
        if ([text length] > 0) return text;
    }

    NSString *value = YTMString([(NSDictionary *)node objectForKey:@"text"]);
    if (value) return value;
    return nil;
}

static NSString *YTMFindStringForKey(id node, NSString *key) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)node;
        NSString *direct = YTMString([dict objectForKey:key]);
        if (direct) return direct;
        for (id value in [dict allValues]) {
            NSString *found = YTMFindStringForKey(value, key);
            if (found) return found;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)node) {
            NSString *found = YTMFindStringForKey(value, key);
            if (found) return found;
        }
    }
    return nil;
}

static NSString *YTMThumbnail(id node) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)node;
        NSArray *thumbs = [dict objectForKey:@"thumbnails"];
        if ([thumbs isKindOfClass:[NSArray class]]) {
            NSString *url = nil;
            for (id thumb in thumbs) {
                NSString *candidate = YTMString([thumb objectForKey:@"url"]);
                if (candidate) url = candidate;
            }
            if (url) return url;
        }
        for (id value in [dict allValues]) {
            NSString *found = YTMThumbnail(value);
            if (found) return found;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)node) {
            NSString *found = YTMThumbnail(value);
            if (found) return found;
        }
    }
    return nil;
}

static NSUInteger YTMClockSeconds(NSString *value) {
    NSArray *parts = [value componentsSeparatedByString:@":"];
    NSUInteger result = 0;
    for (NSString *part in parts) {
        NSInteger n = [part integerValue];
        if (n < 0 || n > 3600) return 0;
        result = result * 60u + (NSUInteger)n;
    }
    return result;
}

static BOOL YTMLooksLikeClock(NSString *value) {
    NSArray *parts = [value componentsSeparatedByString:@":"];
    if ([parts count] < 2 || [parts count] > 3) return NO;
    NSCharacterSet *notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    for (NSString *part in parts) {
        if (![part length] || [part rangeOfCharacterFromSet:notDigits].location != NSNotFound)
            return NO;
    }
    NSUInteger seconds = [[parts lastObject] integerValue];
    return seconds < 60;
}

static NSString *YTMFindClockText(id node) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)node;
        for (NSString *key in [NSArray arrayWithObjects:@"text", @"simpleText", nil]) {
            NSString *text = YTMText([dict objectForKey:key]);
            if (text && YTMLooksLikeClock(text)) return text;
        }
        for (id value in [dict allValues]) {
            NSString *found = YTMFindClockText(value);
            if (found) return found;
        }
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)node) {
            NSString *found = YTMFindClockText(value);
            if (found) return found;
        }
    }
    return nil;
}

static YTMTrack *YTMTrackFromRenderer(NSDictionary *renderer) {
    NSDictionary *columns = [renderer objectForKey:@"flexColumns"];
    if (![columns isKindOfClass:[NSArray class]] || [columns count] == 0) return nil;

    NSMutableArray *texts = [NSMutableArray array];
    for (NSDictionary *column in columns) {
        NSDictionary *columnRenderer = [column objectForKey:@"musicResponsiveListItemFlexColumnRenderer"];
        NSString *text = YTMText([columnRenderer objectForKey:@"text"]);
        if (text) [texts addObject:text];
    }

    NSString *videoID = YTMFindStringForKey(renderer, @"videoId");
    if (!videoID || [texts count] == 0) return nil;

    NSString *title = [texts objectAtIndex:0];
    NSString *artist = [texts count] > 1 ? [texts objectAtIndex:1] : @"Unknown artist";
    NSString *album = [texts count] > 2 ? [texts objectAtIndex:2] : @"";
    NSArray *meta = [artist componentsSeparatedByString:@" • "];
    BOOL typeLabel = [artist caseInsensitiveCompare:@"Song"] == NSOrderedSame ||
                     [artist caseInsensitiveCompare:@"Video"] == NSOrderedSame ||
                     [artist caseInsensitiveCompare:@"Album"] == NSOrderedSame;
    if (typeLabel && [album length]) {
        artist = album;
        album = @"";
    } else if ([meta count] > 1) {
        if ([[meta objectAtIndex:0] caseInsensitiveCompare:@"Song"] == NSOrderedSame ||
            [[meta objectAtIndex:0] caseInsensitiveCompare:@"Video"] == NSOrderedSame) {
            artist = [meta objectAtIndex:1];
            if ([album length] == 0 && [meta count] > 2)
                album = [meta objectAtIndex:2];
        } else {
            artist = [meta objectAtIndex:0];
            if ([album length] == 0)
                album = [meta objectAtIndex:1];
        }
    }

    NSUInteger duration = 0;
    NSString *clock = YTMFindClockText(renderer);
    if (clock)
        duration = YTMClockSeconds(clock);

    return [[[YTMTrack alloc] initWithVideoID:videoID
                                        title:title
                                       artist:artist
                                        album:album
                                thumbnailURL:YTMThumbnail(renderer)
                                     duration:duration] autorelease];
}

static void YTMCollectTracks(id node, NSMutableArray *tracks) {
    if ([node isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)node;
        NSDictionary *renderer = [dict objectForKey:@"musicResponsiveListItemRenderer"];
        if ([renderer isKindOfClass:[NSDictionary class]]) {
            YTMTrack *track = YTMTrackFromRenderer(renderer);
            if (track) {
                [tracks addObject:track];
                return;
            }
        }
        for (id value in [dict allValues]) YTMCollectTracks(value, tracks);
    } else if ([node isKindOfClass:[NSArray class]]) {
        for (id value in (NSArray *)node) YTMCollectTracks(value, tracks);
    }
}

static NSDictionary *YTMClientContext(void) {
    NSDictionary *client = [NSDictionary dictionaryWithObjectsAndKeys:
                            YTMClientName, @"clientName",
                            YTMClientVersion, @"clientVersion",
                            @"en", @"hl",
                            @"US", @"gl",
                            nil];
    return [NSDictionary dictionaryWithObject:client forKey:@"client"];
}

static NSDictionary *YTMPlayerContext(NSString *clientName, NSString *clientVersion) {
    NSMutableDictionary *client = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   clientName, @"clientName",
                                   clientVersion, @"clientVersion",
                                   @"en", @"hl",
                                   @"US", @"gl",
                                   nil];

    if ([clientName isEqualToString:YTMIOSClientName]) {
        [client setObject:@"Apple" forKey:@"deviceMake"];
        [client setObject:@"iPhone16,2" forKey:@"deviceModel"];
        [client setObject:@"iPhone" forKey:@"osName"];
        [client setObject:@"18.3.2.22D82" forKey:@"osVersion"];
        [client setObject:@"com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)" forKey:@"userAgent"];
    } else if ([clientName isEqualToString:YTMAndroidClientName]) {
        [client setObject:@30 forKey:@"androidSdkVersion"];
        [client setObject:@"Android" forKey:@"osName"];
        [client setObject:@"11" forKey:@"osVersion"];
        [client setObject:@"com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip" forKey:@"userAgent"];
    } else {
        [client setObject:@"Oculus" forKey:@"deviceMake"];
        [client setObject:@"Quest 3" forKey:@"deviceModel"];
        [client setObject:@32 forKey:@"androidSdkVersion"];
        [client setObject:@"Android" forKey:@"osName"];
        [client setObject:@"12L" forKey:@"osVersion"];
        [client setObject:@"com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip" forKey:@"userAgent"];
    }
    return [NSDictionary dictionaryWithObject:client forKey:@"client"];
}

static NSURLRequest *YTMRequestForEndpoint(NSString *endpoint,
                                           NSString *origin,
                                           NSString *clientHeaderName,
                                           NSString *clientVersion,
                                           NSString *userAgent,
                                           NSString *path,
                                           NSString *apiKey,
                                           NSDictionary *body,
                                           NSError **error) {
    if (![apiKey length]) {
        if (error) *error = YTMError(1, @"YouTube Music API key is empty");
        return nil;
    }

    NSString *escapedKey = [apiKey stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@?key=%@",
                                       endpoint, path, escapedKey]];
    if (!url) {
        if (error) *error = YTMError(2, @"invalid YouTube Music endpoint");
        return nil;
    }

    NSError *jsonError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (!data) {
        if (error) *error = jsonError;
        return nil;
    }

    NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:url] autorelease];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:origin forHTTPHeaderField:@"Origin"];
    [request setValue:clientHeaderName forHTTPHeaderField:@"X-YouTube-Client-Name"];
    [request setValue:clientVersion forHTTPHeaderField:@"X-YouTube-Client-Version"];
    [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [request setHTTPBody:data];
    return request;
}

static NSURLRequest *YTMRequest(NSString *path, NSString *apiKey, NSDictionary *body,
                                NSError **error) {
    return YTMRequestForEndpoint(YTMEndpoint,
                                 @"https://music.youtube.com",
                                 @"67",
                                 YTMClientVersion,
                                 @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/534.46 Mobile/9A334 Safari/7534.48.3",
                                 path, apiKey, body, error);
}

typedef void (^YTMNetworkCompletion)(NSData *data, NSError *error);

static BOOL YTMShouldTryFallback(NSError *error) {
    if (![error.domain isEqualToString:NSURLErrorDomain]) return NO;
    return error.code == NSURLErrorCannotFindHost || error.code == NSURLErrorDNSLookupFailed;
}

/* try the google endpoint when an older dns setup cannot resolve youtube */
static void YTMSendRequest(NSURLRequest *request, NSURLRequest *fallback,
                           YTMNetworkCompletion completion) {
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        (void)response;
        if (error && fallback && YTMShouldTryFallback(error)) {
            YTMSendRequest(fallback, nil, completion);
            return;
        }
        completion(data, error);
    }];
}

static void YTMDecodeResponse(NSData *data, void (^completion)(id root, NSError *error)) {
    NSError *error = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!root) {
        completion(nil, error ? error : YTMError(3, @"invalid JSON response"));
        return;
    }
    completion(root, nil);
}

@implementation YTMTrack

@synthesize videoID = _videoID;
@synthesize title = _title;
@synthesize artist = _artist;
@synthesize album = _album;
@synthesize thumbnailURL = _thumbnailURL;
@synthesize duration = _duration;

- (id)initWithVideoID:(NSString *)videoID
                title:(NSString *)title
               artist:(NSString *)artist
                album:(NSString *)album
        thumbnailURL:(NSString *)thumbnailURL
             duration:(NSUInteger)duration {
    self = [super init];
    if (!self) return nil;
    _videoID = [videoID copy];
    _title = [title copy];
    _artist = [artist copy];
    _album = [album copy];
    _thumbnailURL = [thumbnailURL copy];
    _duration = duration;
    return self;
}

- (void)dealloc {
    [_videoID release];
    [_title release];
    [_artist release];
    [_album release];
    [_thumbnailURL release];
    [super dealloc];
}

@end

@implementation YTMAPI

- (id)initWithAPIKey:(NSString *)apiKey {
    self = [super init];
    if (!self) return nil;
    _apiKey = [apiKey copy];
    return self;
}

- (void)dealloc {
    [_apiKey release];
    [super dealloc];
}

- (void)search:(NSString *)query completion:(YTMSearchCompletion)completion {
    if (!completion) return;
    if (![query length]) {
        completion(nil, YTMError(4, @"search query is empty"));
        return;
    }

    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
                          YTMClientContext(), @"context",
                          query, @"query",
                          nil];
    NSError *error = nil;
    NSURLRequest *request = YTMRequest(@"search", _apiKey, body, &error);
    NSError *fallbackError = nil;
    NSURLRequest *fallbackRequest = YTMRequestForEndpoint(
        YTMEndpointFallback, @"https://youtubei.googleapis.com", @"67",
        YTMClientVersion,
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/534.46 Mobile/9A334 Safari/7534.48.3",
        @"search", _apiKey, body, &fallbackError);
    if (!request) {
        completion(nil, error);
        return;
    }

    YTMSendRequest(request, fallbackRequest, ^(NSData *data, NSError *networkError) {
        if (networkError) {
            completion(nil, networkError);
            return;
        }
        YTMDecodeResponse(data, ^(id root, NSError *jsonError) {
            if (jsonError) {
                completion(nil, jsonError);
                return;
            }
            NSMutableArray *tracks = [NSMutableArray array];
            YTMCollectTracks(root, tracks);
            if ([tracks count] == 0) {
                completion(nil, YTMError(5, @"no playable music results in response"));
                return;
            }
            completion(tracks, nil);
        });
    });
}

static NSURL *YTMDirectAudioURL(id root, BOOL *ciphered) {
    NSDictionary *streaming = [root isKindOfClass:[NSDictionary class]]
        ? [(NSDictionary *)root objectForKey:@"streamingData"] : nil;
    if (![streaming isKindOfClass:[NSDictionary class]]) return nil;

    NSArray *lists = [NSArray arrayWithObjects:
                      [streaming objectForKey:@"adaptiveFormats"],
                      [streaming objectForKey:@"formats"], nil];
    NSDictionary *best = nil;
    NSDictionary *combined = nil;
    NSUInteger listIndex = 0;
    for (NSArray *formats in lists) {
        if (![formats isKindOfClass:[NSArray class]]) continue;
        for (NSDictionary *format in formats) {
            NSString *mime = YTMString([format objectForKey:@"mimeType"]);
            BOOL audioOnly = [mime hasPrefix:@"audio/"];
            BOOL combinedMP4 = listIndex == 1 &&
                [mime hasPrefix:@"video/"] &&
                [mime rangeOfString:@"mp4a."].location != NSNotFound;
            if (!audioOnly && !combinedMP4) continue;
            NSString *url = YTMString([format objectForKey:@"url"]);
            if (!url) {
                if ([format objectForKey:@"signatureCipher"] || [format objectForKey:@"cipher"])
                    *ciphered = YES;
                continue;
            }
            if (audioOnly) {
                if (!best || [[format objectForKey:@"bitrate"] integerValue] > [[best objectForKey:@"bitrate"] integerValue])
                    best = format;
            } else if (!combined ||
                       [[format objectForKey:@"bitrate"] integerValue] > [[combined objectForKey:@"bitrate"] integerValue]) {
                combined = format;
            }
        }
        ++listIndex;
    }
    if (!best) best = combined;
    if (best) return [NSURL URLWithString:YTMString([best objectForKey:@"url"])];

    /* ios may return an hls manifest instead of adaptive formats */
    return [NSURL URLWithString:YTMString([streaming objectForKey:@"hlsManifestUrl"])];
}

static void YTMAudioURLWithPlayerClient(NSString *videoID,
                                        NSString *apiKey,
                                        NSString *clientName,
                                        NSString *clientVersion,
                                        NSString *clientHeaderName,
                                        NSString *userAgent,
                                        YTMAudioCompletion completion) {
    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
                          YTMPlayerContext(clientName, clientVersion), @"context",
                          videoID, @"videoId",
                          @YES, @"contentCheckOk",
                          @YES, @"racyCheckOk",
                          nil];
    NSError *error = nil;
    NSURLRequest *request = YTMRequestForEndpoint(YTMPlayerEndpoint,
                                                   @"https://www.youtube.com",
                                                   clientHeaderName,
                                                   clientVersion,
                                                   userAgent,
                                                   @"player",
                                                   apiKey,
                                                   body,
                                                   &error);
    NSError *fallbackError = nil;
    NSURLRequest *fallbackRequest = YTMRequestForEndpoint(
        YTMPlayerEndpointFallback, @"https://youtubei.googleapis.com",
        clientHeaderName, clientVersion, userAgent, @"player", apiKey, body,
        &fallbackError);
    if (!request) {
        completion(nil, error);
        return;
    }

    YTMSendRequest(request, fallbackRequest, ^(NSData *data, NSError *networkError) {
        if (networkError) {
            completion(nil, networkError);
            return;
        }
        YTMDecodeResponse(data, ^(id root, NSError *jsonError) {
            BOOL ciphered = NO;
            NSURL *url;
            if (jsonError) {
                completion(nil, jsonError);
                return;
            }
            url = YTMDirectAudioURL(root, &ciphered);
            if (url) {
                completion(url, nil);
                return;
            }

            NSDictionary *playability = [root isKindOfClass:[NSDictionary class]]
                ? [(NSDictionary *)root objectForKey:@"playabilityStatus"] : nil;
            NSString *reason = YTMString([playability objectForKey:@"reason"]);
            if ([reason length]) {
                completion(nil, YTMError(8, [NSString stringWithFormat:@"%@ player: %@", clientName, reason]));
            } else if (ciphered) {
                completion(nil, YTMError(7, @"audio format is ciphered; decipher support is not enabled yet"));
            } else {
                completion(nil, YTMError(8, [NSString stringWithFormat:@"%@ player response has no audio format", clientName]));
            }
        });
    });
}

- (void)audioURLForTrack:(YTMTrack *)track completion:(YTMAudioCompletion)completion {
    if (!completion) return;
    if (![track.videoID length]) {
        completion(nil, YTMError(6, @"track has no video id"));
        return;
    }

    NSString *iosUA = @"com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)";
    NSString *androidUA = @"com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip";
    NSString *vrUA = @"com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip";
    YTMAudioURLWithPlayerClient(track.videoID, _apiKey,
                                YTMIOSClientName, YTMIOSClientVersion, @"5", iosUA,
                                ^(NSURL *url, NSError *iosError) {
        if (url) {
            completion(url, nil);
            return;
        }
        YTMAudioURLWithPlayerClient(track.videoID, _apiKey,
                                    YTMAndroidClientName, YTMAndroidClientVersion, @"3", androidUA,
                                    ^(NSURL *androidURL, NSError *androidError) {
            if (androidURL) {
                completion(androidURL, nil);
                return;
            }
            YTMAudioURLWithPlayerClient(track.videoID, _apiKey,
                                        YTMAndroidVRClientName, YTMAndroidVRClientVersion, @"28", vrUA,
                                        ^(NSURL *fallbackURL, NSError *fallbackError) {
                completion(fallbackURL, fallbackURL ? nil :
                           (fallbackError ? fallbackError :
                            (androidError ? androidError : iosError)));
            });
        });
    });
}

@end
