/*
Copyright (c) 2008-2010
	Lars-Dominik Braun <PromyLOPh@lavabit.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#ifndef _PIANO_H
#define _PIANO_H

/* this is our public API; don't expect this api to be stable as long as
 * pandora does not provide a stable api
 * all strings _must_ be utf-8 encoded. i won't care, but pandora does. so
 * be nice and check the encoding of your strings. thanks :) */

#define PIANO_RPC_HOST "www.pandora.com"
#define PIANO_RPC_PORT "80"

typedef struct PianoUserInfo {
	char *webAuthToken;
	char *listenerId;
	char *authToken;
} PianoUserInfo_t;

typedef struct PianoStation {
	char isCreator;
	char isQuickMix;
	char useQuickMix; /* station will be included in quickmix */
	char *name;
	char *id;
	struct PianoStation *next;
} PianoStation_t;

typedef enum {
	PIANO_RATE_NONE = 0,
	PIANO_RATE_LOVE = 1,
	PIANO_RATE_BAN = 2
} PianoSongRating_t;

/* UNKNOWN should be 0, because memset sets audio format to 0 */
typedef enum {
	PIANO_AF_UNKNOWN = 0,
	PIANO_AF_AACPLUS = 1,
	PIANO_AF_MP3 = 2,
	PIANO_AF_MP3_HI = 3
} PianoAudioFormat_t;

typedef struct PianoSong {
	char *artist;
	char *artistMusicId;
	char *matchingSeed;
	float fileGain;
	PianoSongRating_t rating;
	char *stationId;
	char *album;
	char *userSeed;
	char *audioUrl;
	char *musicId;
	char *title;
	char *focusTraitId;
	char *identity;
	PianoAudioFormat_t audioFormat;
	struct PianoSong *next;
} PianoSong_t;

/* currently only used for search results */
typedef struct PianoArtist {
	char *name;
	char *musicId;
	int score;
	struct PianoArtist *next;
} PianoArtist_t;

typedef struct PianoGenreCategory {
	char *name;
	PianoStation_t *stations;
	struct PianoGenreCategory *next;
} PianoGenreCategory_t;

typedef struct PianoHandle {
	char routeId[9];
	PianoUserInfo_t user;
	/* linked lists */
	PianoStation_t *stations;
	PianoGenreCategory_t *genreStations;
} PianoHandle_t;

typedef struct PianoSearchResult {
	PianoSong_t *songs;
	PianoArtist_t *artists;
} PianoSearchResult_t;

typedef enum {
	PIANO_RET_ERR = 0,
	PIANO_RET_OK = 1,
	PIANO_RET_XML_INVALID = 2,
	PIANO_RET_AUTH_TOKEN_INVALID = 3,
	PIANO_RET_AUTH_USER_PASSWORD_INVALID = 4,
	PIANO_RET_NET_ERROR = 5,
	PIANO_RET_NOT_AUTHORIZED = 6,
	PIANO_RET_PROTOCOL_INCOMPATIBLE = 7,
	PIANO_RET_READONLY_MODE = 8,
	PIANO_RET_STATION_CODE_INVALID = 9,
	PIANO_RET_IP_REJECTED = 10,
	PIANO_RET_STATION_NONEXISTENT = 11,
	PIANO_RET_OUT_OF_MEMORY = 12,
	PIANO_RET_OUT_OF_SYNC = 13,
	PIANO_RET_PLAYLIST_END = 14
} PianoReturn_t;

void PianoInit (PianoHandle_t *);
void PianoDestroy (PianoHandle_t *);
void PianoDestroyPlaylist (PianoSong_t *);
void PianoDestroySearchResult (PianoSearchResult_t *);

PianoReturn_t PianoRequest (PianoHandle_t *, PianoRequest_t *,
		PianoRequestType_t);
PianoReturn_t PianoResponse (PianoHandle_t *, PianoRequest_t *);
void PianoDestroyRequest (PianoRequest_t *);

PianoStation_t *PianoFindStationById (PianoStation_t *, const char *);
const char *PianoErrorToStr (PianoReturn_t);
PianoReturn_t PianoSeedSuggestions (PianoHandle_t *, const char *,
		unsigned int, PianoSearchResult_t *);
PianoReturn_t PianoBookmarkSong (PianoHandle_t *, PianoSong_t *);
PianoReturn_t PianoBookmarkArtist (PianoHandle_t *, PianoSong_t *);

#endif /* _PIANO_H */
