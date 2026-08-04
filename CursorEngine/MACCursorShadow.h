#pragma once

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    CGFloat offsetX;
    CGFloat offsetY;
    CGFloat blur;
    CGFloat alpha;
    CGFloat supportRadius;
} MACShadowParams;

typedef struct {
    CGFloat left;
    CGFloat top;
    CGFloat right;
    CGFloat bottom;
} MACShadowMargins;

extern const MACShadowParams MACShadowParamsDefault;

extern MACShadowMargins MACShadowMarginsForParams(MACShadowParams params);

extern void MACShadowAdjustRegistration(CGSize *size,
                                        CGPoint *hotSpot,
                                        MACShadowMargins margins,
                                        CGFloat scale);

extern NSArray * _Nullable MACShadowedCursorImages(NSArray * _Nullable images,
                                                   NSUInteger frameCount,
                                                   CGSize pointSize,
                                                   MACShadowParams params,
                                                   MACShadowMargins * _Nullable outMargins);

NS_ASSUME_NONNULL_END
