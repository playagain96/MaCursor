#import "MACCursorShadow.h"
#import "MACCursorDefs.h"

const MACShadowParams MACShadowParamsDefault = { 2.0, 2.0, 3.0, 0.30, 8.0 };

static const NSUInteger MACShadowMaxRepScale = 16;

typedef struct {
    NSUInteger repScale;
    NSUInteger sourceWidth;
    NSUInteger sourceFrameHeight;
    BOOL isSheet;
} MACShadowLayout;

MACShadowMargins MACShadowMarginsForParams(MACShadowParams params) {
    MACShadowMargins margins;
    margins.left   = MAX(0.0, params.supportRadius - params.offsetX);
    margins.right  = MAX(0.0, params.supportRadius + params.offsetX);
    margins.top    = MAX(0.0, params.supportRadius - params.offsetY);
    margins.bottom = MAX(0.0, params.supportRadius + params.offsetY);
    return margins;
}

void MACShadowAdjustRegistration(CGSize *size,
                                 CGPoint *hotSpot,
                                 MACShadowMargins margins,
                                 CGFloat scale) {
    if (!size || !hotSpot) {
        return;
    }
    size->width  += (margins.left + margins.right) * scale;
    size->height += (margins.top + margins.bottom) * scale;
    hotSpot->x   += margins.left * scale;
    hotSpot->y   += margins.top * scale;
}

static BOOL MACShadowWithinNominalTolerance(CGFloat actual, CGFloat nominal, NSUInteger repScale) {
    return fabs(actual - nominal * (CGFloat)repScale) <= 0.5 * (CGFloat)repScale;
}

static NSUInteger MACShadowRepScaleForWidth(NSUInteger pixelsWide, CGFloat pointsWide) {
    if (pointsWide <= 0.0) {
        return 0;
    }
    long rounded = lround((CGFloat)pixelsWide / pointsWide);
    if (rounded < 1 || (NSUInteger)rounded > MACShadowMaxRepScale) {
        return 0;
    }
    NSUInteger repScale = (NSUInteger)rounded;
    if (!MACShadowWithinNominalTolerance((CGFloat)pixelsWide, pointsWide, repScale)) {
        return 0;
    }
    return repScale;
}

static BOOL MACShadowClassifyImage(CGImageRef image,
                                   NSUInteger frameCount,
                                   CGSize pointSize,
                                   MACShadowLayout *outLayout) {
    if (!image) {
        return NO;
    }

    NSUInteger pixelsWide = CGImageGetWidth(image);
    NSUInteger pixelsHigh = CGImageGetHeight(image);
    if (pixelsWide == 0 || pixelsHigh == 0) {
        return NO;
    }

    NSUInteger repScale = MACShadowRepScaleForWidth(pixelsWide, pointSize.width);
    if (repScale == 0) {
        return NO;
    }

    if (frameCount > 1 && pixelsHigh % frameCount == 0) {
        NSUInteger candidateFrameHeight = pixelsHigh / frameCount;
        if (candidateFrameHeight > 0 &&
            MACShadowWithinNominalTolerance((CGFloat)candidateFrameHeight, pointSize.height, repScale)) {
            outLayout->repScale = repScale;
            outLayout->sourceWidth = pixelsWide;
            outLayout->sourceFrameHeight = candidateFrameHeight;
            outLayout->isSheet = YES;
            return YES;
        }
    }

    if (MACShadowWithinNominalTolerance((CGFloat)pixelsHigh, pointSize.height, repScale)) {
        outLayout->repScale = repScale;
        outLayout->sourceWidth = pixelsWide;
        outLayout->sourceFrameHeight = pixelsHigh;
        outLayout->isSheet = NO;
        return YES;
    }

    return NO;
}

static CGImageRef MACShadowCreateFrame(CGImageRef sourceFrame,
                                       NSUInteger sourceWidth,
                                       NSUInteger sourceFrameHeight,
                                       NSUInteger padLeft,
                                       NSUInteger padTop,
                                       NSUInteger padRight,
                                       NSUInteger padBottom,
                                       NSUInteger repScale,
                                       MACShadowParams params) CF_RETURNS_RETAINED {
    NSUInteger outWidth = sourceWidth + padLeft + padRight;
    NSUInteger outHeight = sourceFrameHeight + padTop + padBottom;

    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             outWidth,
                                             outHeight,
                                             8,
                                             0,
                                             colorSpace,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    if (!ctx) {
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }

    CGContextClearRect(ctx, CGRectMake(0, 0, outWidth, outHeight));

    CGFloat components[4] = { 0.0, 0.0, 0.0, params.alpha };
    CGColorRef shadowColor = CGColorCreate(colorSpace, components);
    CGContextSetShadowWithColor(ctx,
                                CGSizeMake(params.offsetX * (CGFloat)repScale,
                                           -params.offsetY * (CGFloat)repScale),
                                params.blur * (CGFloat)repScale,
                                shadowColor);
    CGColorRelease(shadowColor);
    CGColorSpaceRelease(colorSpace);

    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextDrawImage(ctx,
                       CGRectMake(padLeft, padBottom, sourceWidth, sourceFrameHeight),
                       sourceFrame);

    CGImageRef result = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return result;
}

static CGImageRef MACShadowCreateSheet(NSArray *shadowedFrames,
                                       NSUInteger outWidth,
                                       NSUInteger outFrameHeight) CF_RETURNS_RETAINED {
    NSUInteger frameCount = shadowedFrames.count;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL,
                                             outWidth,
                                             outFrameHeight * frameCount,
                                             8,
                                             0,
                                             colorSpace,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(colorSpace);
    if (!ctx) {
        return NULL;
    }

    CGContextClearRect(ctx, CGRectMake(0, 0, outWidth, outFrameHeight * frameCount));

    for (NSUInteger i = 0; i < frameCount; i++) {
        CGImageRef frame = (__bridge CGImageRef)shadowedFrames[i];
        CGContextDrawImage(ctx,
                           CGRectMake(0,
                                      (frameCount - 1 - i) * outFrameHeight,
                                      outWidth,
                                      outFrameHeight),
                           frame);
    }

    CGImageRef result = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return result;
}

NSArray *MACShadowedCursorImages(NSArray *images,
                                 NSUInteger frameCount,
                                 CGSize pointSize,
                                 MACShadowParams params,
                                 MACShadowMargins *outMargins) {
    if (images.count == 0 || frameCount < 1 || frameCount > MACMaxFrameCount) {
        return nil;
    }
    if (!isfinite(pointSize.width) || !isfinite(pointSize.height) ||
        pointSize.width <= 0.0 || pointSize.height <= 0.0) {
        return nil;
    }
    if (!isfinite(params.supportRadius) || params.supportRadius < 0.0 ||
        !isfinite(params.blur) || params.blur < 0.0 ||
        !isfinite(params.offsetX) || !isfinite(params.offsetY) ||
        !isfinite(params.alpha)) {
        return nil;
    }

    MACShadowMargins margins = MACShadowMarginsForParams(params);

    NSMutableArray *layouts = [NSMutableArray arrayWithCapacity:images.count];
    BOOL uniformIsSheet = NO;

    for (NSUInteger index = 0; index < images.count; index++) {
        id object = images[index];
        if (CFGetTypeID((__bridge CFTypeRef)object) != CGImageGetTypeID()) {
            return nil;
        }

        MACShadowLayout layout = {0};
        if (!MACShadowClassifyImage((__bridge CGImageRef)object, frameCount, pointSize, &layout)) {
            return nil;
        }

        if (index == 0) {
            uniformIsSheet = layout.isSheet;
        } else if (layout.isSheet != uniformIsSheet) {
            return nil;
        }

        [layouts addObject:[NSValue valueWithBytes:&layout objCType:@encode(MACShadowLayout)]];
    }

    if (!uniformIsSheet && frameCount > 1 && images.count != frameCount) {
        return nil;
    }

    NSMutableArray *output = [NSMutableArray arrayWithCapacity:images.count];

    for (NSUInteger index = 0; index < images.count; index++) {
        MACShadowLayout layout = {0};
        [layouts[index] getValue:&layout];

        NSUInteger repScale = layout.repScale;
        NSUInteger padLeft   = (NSUInteger)lround(margins.left * (CGFloat)repScale);
        NSUInteger padTop    = (NSUInteger)lround(margins.top * (CGFloat)repScale);
        NSUInteger padRight  = (NSUInteger)lround(margins.right * (CGFloat)repScale);
        NSUInteger padBottom = (NSUInteger)lround(margins.bottom * (CGFloat)repScale);

        CGImageRef source = (__bridge CGImageRef)images[index];
        NSUInteger framesInImage = layout.isSheet ? frameCount : 1;

        NSMutableArray *shadowedFrames = [NSMutableArray arrayWithCapacity:framesInImage];
        BOOL allFramesBuilt = YES;

        for (NSUInteger i = 0; i < framesInImage; i++) {
            CGImageRef sourceFrame = NULL;
            if (layout.isSheet) {
                sourceFrame = CGImageCreateWithImageInRect(source,
                    CGRectMake(0,
                               i * layout.sourceFrameHeight,
                               layout.sourceWidth,
                               layout.sourceFrameHeight));
            } else {
                sourceFrame = CGImageRetain(source);
            }

            if (!sourceFrame) {
                allFramesBuilt = NO;
                break;
            }

            CGImageRef shadowed = MACShadowCreateFrame(sourceFrame,
                                                       layout.sourceWidth,
                                                       layout.sourceFrameHeight,
                                                       padLeft,
                                                       padTop,
                                                       padRight,
                                                       padBottom,
                                                       repScale,
                                                       params);
            CGImageRelease(sourceFrame);

            if (!shadowed) {
                allFramesBuilt = NO;
                break;
            }

            [shadowedFrames addObject:(__bridge_transfer id)shadowed];
        }

        if (!allFramesBuilt) {
            return nil;
        }

        if (layout.isSheet) {
            NSUInteger outWidth = layout.sourceWidth + padLeft + padRight;
            NSUInteger outFrameHeight = layout.sourceFrameHeight + padTop + padBottom;
            CGImageRef sheet = MACShadowCreateSheet(shadowedFrames, outWidth, outFrameHeight);
            if (!sheet) {
                return nil;
            }
            [output addObject:(__bridge_transfer id)sheet];
        } else {
            [output addObject:shadowedFrames[0]];
        }
    }

    if (outMargins) {
        *outMargins = margins;
    }

    return output;
}
