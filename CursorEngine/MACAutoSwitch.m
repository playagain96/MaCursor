#import "MACAutoSwitch.h"
#import "MACCursorDefs.h"
#import "MACCursorActions.h"

NSString * const MACPreferencesAutoSwitchRulesKey = @"MACAutoSwitchRules";
NSString * const MACAutoSwitchDidChangeNotification = @"MACAutoSwitchDidChange";
NSString * const MACAutoSwitchAppliedThemeDidChangeNotification = @"MACAutoSwitchAppliedThemeDidChange";

NSString * MACAutoSwitchThemePathForIdentifier(NSString *identifier) {
    NSURL *appSupportURL = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask].firstObject;
    return [[[appSupportURL.path stringByAppendingPathComponent:@"MaCursor/cursors"]
        stringByAppendingPathComponent:identifier]
        stringByAppendingPathExtension:@"cursor"];
}

static BOOL usableRule(id candidate, NSString **outTheme, NSInteger *outMinutes) {
    if (![candidate isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *dict = (NSDictionary *)candidate;

    id theme = dict[@"themeIdentifier"];
    if (![theme isKindOfClass:[NSString class]]) return NO;
    if ([(NSString *)theme length] == 0) return NO;

    id minutes = dict[@"startMinutes"];
    if (![minutes isKindOfClass:[NSNumber class]]) return NO;
    if (strcmp([(NSNumber *)minutes objCType], @encode(BOOL)) == 0) return NO;
    NSInteger value = [(NSNumber *)minutes integerValue];
    if (value < 0 || value > 1439) return NO;

    if (outTheme) *outTheme = (NSString *)theme;
    if (outMinutes) *outMinutes = value;
    return YES;
}

NSString * _Nullable MACAutoSwitchResolveScheduleTheme(NSArray * _Nullable rules, NSInteger nowMinutes) {
    if (![rules isKindOfClass:[NSArray class]] || rules.count == 0) return nil;

    NSString *passedTheme = nil;
    NSInteger passedMinutes = -1;
    NSString *latestTheme = nil;
    NSInteger latestMinutes = -1;

    for (id candidate in rules) {
        NSString *theme = nil;
        NSInteger minutes = 0;
        if (!usableRule(candidate, &theme, &minutes)) continue;

        if (minutes >= latestMinutes) {
            latestMinutes = minutes;
            latestTheme = theme;
        }
        if (minutes <= nowMinutes && minutes >= passedMinutes) {
            passedMinutes = minutes;
            passedTheme = theme;
        }
    }

    return passedTheme ?: latestTheme;
}

NSInteger MACAutoSwitchMinutesUntilNextBoundary(NSArray * _Nullable rules, NSInteger nowMinutes) {
    if (![rules isKindOfClass:[NSArray class]] || rules.count == 0) return -1;

    NSInteger best = -1;
    for (id candidate in rules) {
        NSInteger minutes = 0;
        if (!usableRule(candidate, NULL, &minutes)) continue;

        NSInteger delta = minutes - nowMinutes;
        if (delta <= 0) delta += 1440;
        if (best < 0 || delta < best) best = delta;
    }
    return best;
}

NSInteger MACAutoSwitchCurrentMinuteOfDay(void) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *parts = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                          fromDate:[NSDate date]];
    return parts.hour * 60 + parts.minute;
}

NSDictionary * _Nullable MACAutoSwitchReadConfig(void) {
    CFPreferencesSynchronize((__bridge CFStringRef)kMACDomain,
                             kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
    id raw = (__bridge_transfer id)CFPreferencesCopyAppValue(
        (__bridge CFStringRef)MACPreferencesAutoSwitchRulesKey,
        (__bridge CFStringRef)kMACDomain);
    if (![raw isKindOfClass:[NSData class]]) return nil;

    NSError *error = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:(NSData *)raw options:0 error:&error];
    if (error || ![parsed isKindOfClass:[NSDictionary class]]) return nil;
    return (NSDictionary *)parsed;
}

NSString * _Nullable MACAutoSwitchResolveThemeIdentifier(NSDictionary * _Nullable config, NSInteger nowMinutes) {
    if (![config isKindOfClass:[NSDictionary class]]) return nil;
    if (![config[@"enabled"] boolValue]) return nil;
    return MACAutoSwitchResolveScheduleTheme(config[@"scheduleRules"], nowMinutes);
}

NSString * _Nullable MACAutoSwitchPendingIdentifier(NSString * _Nullable desired, NSString * _Nullable current) {
    if (desired.length == 0) return nil;
    if (current.length > 0 && [desired isEqualToString:current]) return nil;
    return desired;
}

BOOL MACAutoSwitchApplyIfNeeded(void) {
    NSDictionary *config = MACAutoSwitchReadConfig();
    NSString *desired = MACAutoSwitchResolveThemeIdentifier(config, MACAutoSwitchCurrentMinuteOfDay());

    id stored = MACDefault(MACPreferencesAppliedCursorKey);
    NSString *current = [stored isKindOfClass:[NSString class]] ? (NSString *)stored : nil;

    NSString *pending = MACAutoSwitchPendingIdentifier(desired, current);
    if (!pending) return NO;

    NSString *path = MACAutoSwitchThemePathForIdentifier(pending);
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        MMLog(BOLD YELLOW "Auto-switch target %s is missing on disk, keeping current cursor" RESET,
              [pending UTF8String]);
        return NO;
    }

    if (!applyThemeAtPath(path)) {
        MMLog(BOLD RED "Auto-switch failed to apply %s" RESET, [pending UTF8String]);
        return NO;
    }

    MACSetDefault(pending, MACPreferencesAppliedCursorKey);
    MMLog(BOLD GREEN "Auto-switch applied %s" RESET, [pending UTF8String]);

    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:MACAutoSwitchAppliedThemeDidChangeNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
    return YES;
}
