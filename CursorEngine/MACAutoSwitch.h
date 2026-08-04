#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MACPreferencesAutoSwitchRulesKey;
extern NSString * const MACAutoSwitchDidChangeNotification;
extern NSString * const MACAutoSwitchAppliedThemeDidChangeNotification;

extern NSString * MACAutoSwitchThemePathForIdentifier(NSString *identifier);

extern NSString * _Nullable MACAutoSwitchResolveScheduleTheme(NSArray * _Nullable rules, NSInteger nowMinutes);
extern NSInteger MACAutoSwitchMinutesUntilNextBoundary(NSArray * _Nullable rules, NSInteger nowMinutes);
extern NSInteger MACAutoSwitchCurrentMinuteOfDay(void);
extern NSDictionary * _Nullable MACAutoSwitchReadConfig(void);
extern NSString * _Nullable MACAutoSwitchResolveThemeIdentifier(NSDictionary * _Nullable config, NSInteger nowMinutes);

extern NSString * _Nullable MACAutoSwitchPendingIdentifier(NSString * _Nullable desired, NSString * _Nullable current);
extern BOOL MACAutoSwitchApplyIfNeeded(void);

NS_ASSUME_NONNULL_END
