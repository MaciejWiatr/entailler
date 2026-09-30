// The now-playing helper. Since macOS 15.4 only Apple-entitled processes may read MediaRemote,
// so Entailler runs /usr/bin/perl, which still is, and has it load this library and call
// `entailler_media_remote_main`. It then:
//
// - writes one JSON line to stdout whenever what's playing changes: an object with app (the
//   now-playing app's bundle identifier), title, artist, album, artwork (base64), duration,
//   elapsed, timestamp (seconds since 1970) and playing, or `null` when nothing is playing;
// - reads one command per line from stdin: `toggle`, `next`, `previous`, or `seek <seconds>`;
// - exits when stdin closes, so it never outlives Entailler.

#import <Foundation/Foundation.h>
#include <dlfcn.h>

typedef void (*MRGetNowPlayingInfo)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetIsPlaying)(dispatch_queue_t, void (^)(BOOL));
typedef void (*MRGetApplication)(dispatch_queue_t, void (^)(NSString *));
typedef void (*MRRegisterForNotifications)(dispatch_queue_t);
typedef BOOL (*MRSendCommand)(int, NSDictionary *);
typedef void (*MRSetElapsedTime)(double);

enum { MRTogglePlayPause = 2, MRNextTrack = 4, MRPreviousTrack = 5 };

/// How long to let MediaRemote's notifications for one change settle before reporting.
static const NSUInteger settleMilliseconds = 50;
/// How long to wait before looking again for artwork that was missing, and how many times.
static const NSUInteger artworkRecheckMilliseconds = 1000;
static const NSUInteger maxArtworkRechecks = 3;

static MRGetNowPlayingInfo getNowPlayingInfo;
static MRGetIsPlaying getIsPlaying;
static MRGetApplication getApplication;
static MRSendCommand sendCommand;
static MRSetElapsedTime setElapsedTime;
static NSString *lastLine;
static NSUInteger pendingReport;
static NSUInteger artworkRechecks;

static void writeLine(NSString *line) {
    if ([line isEqualToString:lastLine]) return;
    lastLine = line;
    printf("%s\n", line.UTF8String);
    fflush(stdout);
}

static id jsonValue(id value) {
    return value ?: [NSNull null];
}

static void scheduleReport(NSUInteger delayMilliseconds);

static void writeNowPlaying(NSDictionary *info, BOOL playing, NSString *app) {
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"] ?: [NSDate date];
    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    NSDictionary *nowPlaying = @{
        @"app": app ?: @"",
        @"title": info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"",
        @"artist": info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"",
        @"album": info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"",
        @"artwork": jsonValue([artwork base64EncodedStringWithOptions:0]),
        @"duration": jsonValue(info[@"kMRMediaRemoteNowPlayingInfoDuration"]),
        @"elapsed": info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] ?: @0,
        @"timestamp": @(timestamp.timeIntervalSince1970),
        @"playing": @(playing),
    };
    NSData *json = [NSJSONSerialization dataWithJSONObject:nowPlaying options:0 error:nil];
    if (json) writeLine([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]);
    // Some apps, like Spotify, briefly publish a sparser version of the track without
    // artwork around a change, so look again once they have settled.
    if (!artwork && artworkRechecks < maxArtworkRechecks) {
        artworkRechecks++;
        scheduleReport(artworkRecheckMilliseconds);
    }
}

static void report(void) {
    getNowPlayingInfo(dispatch_get_main_queue(), ^(NSDictionary *info) {
        if (info.count == 0) {
            writeLine(@"null");
            return;
        }
        getIsPlaying(dispatch_get_main_queue(), ^(BOOL playing) {
            getApplication(dispatch_get_main_queue(), ^(NSString *app) {
                writeNowPlaying(info, playing, app);
            });
        });
    });
}

/// MediaRemote posts several notifications for one change, so report once they settle.
static void scheduleReport(NSUInteger delayMilliseconds) {
    NSUInteger generation = ++pendingReport;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayMilliseconds * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (generation == pendingReport) report();
    });
}

static void runCommand(NSString *line) {
    NSArray<NSString *> *words = [line componentsSeparatedByString:@" "];
    NSString *command = words.firstObject;
    if ([command isEqualToString:@"toggle"]) {
        sendCommand(MRTogglePlayPause, nil);
    } else if ([command isEqualToString:@"next"]) {
        sendCommand(MRNextTrack, nil);
    } else if ([command isEqualToString:@"previous"]) {
        sendCommand(MRPreviousTrack, nil);
    } else if ([command isEqualToString:@"seek"] && words.count == 2) {
        setElapsedTime(words[1].doubleValue);
    }
}

static void readCommands(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char *buffer = NULL;
        size_t capacity = 0;
        ssize_t length;
        while ((length = getline(&buffer, &capacity, stdin)) > 0) {
            NSString *line = [[[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding]
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            dispatch_async(dispatch_get_main_queue(), ^{ runCommand(line); });
        }
        exit(0);
    });
}

__attribute__((visibility("default")))
void entailler_media_remote_main(void) {
    void *mediaRemote = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    getNowPlayingInfo = (MRGetNowPlayingInfo)dlsym(mediaRemote, "MRMediaRemoteGetNowPlayingInfo");
    getIsPlaying = (MRGetIsPlaying)dlsym(mediaRemote, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    getApplication = (MRGetApplication)dlsym(mediaRemote, "MRMediaRemoteGetNowPlayingApplicationDisplayID");
    sendCommand = (MRSendCommand)dlsym(mediaRemote, "MRMediaRemoteSendCommand");
    setElapsedTime = (MRSetElapsedTime)dlsym(mediaRemote, "MRMediaRemoteSetElapsedTime");
    MRRegisterForNotifications registerForNotifications =
        (MRRegisterForNotifications)dlsym(mediaRemote, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (!getNowPlayingInfo || !getIsPlaying || !getApplication || !sendCommand || !setElapsedTime || !registerForNotifications) {
        fprintf(stderr, "MediaRemote is unavailable\n");
        exit(1);
    }

    registerForNotifications(dispatch_get_main_queue());
    for (NSString *name in @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    ]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            artworkRechecks = 0;
            scheduleReport(settleMilliseconds);
        }];
    }

    readCommands();
    report();
    CFRunLoopRun();
}
