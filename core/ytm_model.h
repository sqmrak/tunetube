#ifndef YTM_MODEL_H
#define YTM_MODEL_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define YTM_VIDEO_ID_MAX 32
#define YTM_TITLE_MAX    256
#define YTM_ARTIST_MAX   256
#define YTM_ALBUM_MAX    256

typedef struct {
    char video_id[YTM_VIDEO_ID_MAX];
    char title[YTM_TITLE_MAX];
    char artist[YTM_ARTIST_MAX];
    char album[YTM_ALBUM_MAX];
    unsigned duration_sec;
} ytm_track_t;

/* clear the fixed record so old callers can reuse one stack object */
void ytm_track_init(ytm_track_t *track);

/* avoid hidden allocations so callers can use fixed buffers */
int ytm_track_set_text(char *dst, size_t cap, const char *src);

/* keep duration parsing here because api responses use ISO-8601 strings */
int ytm_duration_parse(const char *text, unsigned *out_seconds);

#ifdef __cplusplus
}
#endif

#endif /* ytm_model_h */
