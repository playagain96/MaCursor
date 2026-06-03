#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * _Nullable appliedThemePathForUser(NSString *user);
extern void listener(void);

extern void registerHotKeysFromPreferences(void);
extern void unregisterAllHotKeys(void);

NS_ASSUME_NONNULL_END
