#import "MACCursorDefs.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

NSString *defaultCursors[] = {
    @"com.apple.coregraphics.Arrow",
    @"com.apple.coregraphics.IBeam",
    @"com.apple.coregraphics.IBeamXOR",
    @"com.apple.coregraphics.Alias",
    @"com.apple.coregraphics.Copy",
    @"com.apple.coregraphics.Move",
    @"com.apple.coregraphics.ArrowCtx",
    @"com.apple.coregraphics.Wait",
    @"com.apple.coregraphics.Empty",
    @"com.apple.coregraphics.ArrowS",
    @"com.apple.coregraphics.IBeamS",
    nil };

NSString *MACErrorDomain = @"com.writronic.macursor.error";

NSString * const MACCursorDictionaryCursorsKey         = @"Cursors";
NSString * const MACCursorDictionaryCreatorKey         = @"Creator";
NSString * const MACCursorDictionaryHiDPIKey           = @"HiDPI";
NSString * const MACCursorDictionaryIdentifierKey      = @"Identifier";
NSString * const MACCursorDictionaryThemeNameKey        = @"ThemeName";
NSString * const MACCursorDictionaryThemeVersionKey     = @"ThemeVersion";
NSString * const MACCursorDictionaryUUIDKey             = @"UUID";

NSString * const MACCursorDictionaryFrameCountKey      = @"FrameCount";
NSString * const MACCursorDictionaryFrameDurationKey   = @"FrameDuration";
NSString * const MACCursorDictionaryHotSpotXKey        = @"HotSpotX";
NSString * const MACCursorDictionaryHotSpotYKey        = @"HotSpotY";
NSString * const MACCursorDictionaryPointsWideKey      = @"PointsWide";
NSString * const MACCursorDictionaryPointsHighKey      = @"PointsHigh";
NSString * const MACCursorDictionaryRepresentationsKey = @"Representations";

NSString *UUID(void) {
    return [[NSUUID UUID] UUIDString];
}

NSString *MMGet(NSString *prompt) {
    MMOut("%s: ", prompt.UTF8String);
    NSFileHandle *input = [NSFileHandle fileHandleWithStandardInput];
    NSData *data = [input availableData];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

NSData *pngDataForImage(id image) {
    if ([image isKindOfClass:[NSBitmapImageRep class]]) {
        return [(NSBitmapImageRep *)image representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }
    
    CFTypeID typeID = CFGetTypeID((__bridge CFTypeRef)image);
    if (typeID == CGImageGetTypeID()) {
        CGImageRef obj = (__bridge CGImageRef)image;
        CFMutableDataRef mutableData = CFDataCreateMutable(kCFAllocatorDefault, 0);
        CGImageDestinationRef dest = CGImageDestinationCreateWithData(mutableData, (__bridge CFStringRef)UTTypePNG.identifier, 1, NULL);
        CGImageDestinationAddImage(dest, obj, NULL);
        CGImageDestinationFinalize(dest);
        
        CFRelease(dest);
        
        return CFBridgingRelease(mutableData);
    }
    
    MMLog("pngDataForImage: unsupported type");
    return nil;
}

NSDictionary *cursorThemeWithIdentifier(NSString *identifier) {
    
    NSUInteger frameCount;
    CGFloat frameDuration;
    CGPoint hotSpot;
    CGSize size;
    CFArrayRef representations;
    bool registered = false;
    
    MACIsCursorRegistered(CGSMainConnectionID(), (char *)identifier.UTF8String, &registered);
    if (!registered)
        return nil;

    CGError error = 0;
    if (![identifier hasPrefix:@"com.apple.cursor"]) {
        error = CGSCopyRegisteredCursorImages(CGSMainConnectionID(), (char*)identifier.UTF8String, &size, &hotSpot, &frameCount, &frameDuration, &representations);
    } else {
        error = CoreCursorCopyImages(CGSMainConnectionID(), [[identifier pathExtension] intValue], &representations, &size, &hotSpot, &frameCount, &frameDuration);
    }
    
    if (error || !representations || !CFArrayGetCount(representations))
        return nil;
    
    NSDictionary *dict = @{MACCursorDictionaryFrameCountKey: @(frameCount), MACCursorDictionaryFrameDurationKey: @(frameDuration), MACCursorDictionaryHotSpotXKey: @(hotSpot.x), MACCursorDictionaryHotSpotYKey: @(hotSpot.y), MACCursorDictionaryPointsWideKey: @(size.width), MACCursorDictionaryPointsHighKey: @(size.height), MACCursorDictionaryRepresentationsKey: CFBridgingRelease(representations)};
    
    return dict;
}

NSDictionary *cursorMap(void) {
    static NSDictionary *cursorNameMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cursorNameMap = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"Arrow", @"com.apple.cursor.0",
                           @"IBeam", @"com.apple.cursor.1",
                           @"Resize N-S", @"com.apple.cursor.23",
                          @"Camera 2", @"com.apple.cursor.9",
                          @"IBeam H.", @"com.apple.cursor.26",
                          @"Window NE", @"com.apple.cursor.29",
                          @"Busy", @"com.apple.cursor.4",
                          @"Ctx Arrow", @"com.apple.coregraphics.ArrowCtx",
                          @"Open", @"com.apple.cursor.12",
                          @"Window N-S", @"com.apple.cursor.32",
                          @"Window SE", @"com.apple.cursor.35",
                          @"Counting Down", @"com.apple.cursor.15",
                          @"Window W", @"com.apple.cursor.38",
                          @"Resize E", @"com.apple.cursor.18",
                          @"Cell", @"com.apple.cursor.41",
                          @"Resize N", @"com.apple.cursor.21",
                          @"Copy Drag", @"com.apple.cursor.5",
                          @"Ctx Menu", @"com.apple.cursor.24",
                          @"Window E", @"com.apple.cursor.27",
                          @"Window NE-SW", @"com.apple.cursor.30",
                          @"Camera", @"com.apple.cursor.10",
                          @"Window NW", @"com.apple.cursor.33",
                          @"Pointing", @"com.apple.cursor.13",
                          @"IBeamXOR", @"com.apple.coregraphics.IBeamXOR",
                          @"Copy", @"com.apple.coregraphics.Copy",
                          @"Arrow", @"com.apple.coregraphics.Arrow",
                          @"Counting Up/Down", @"com.apple.cursor.16",
                          @"Window S", @"com.apple.cursor.36",
                          @"Resize Square", @"com.apple.cursor.39",
                          @"Resize W-E", @"com.apple.cursor.19",
                          @"Zoom In", @"com.apple.cursor.42",
                          @"Resize S", @"com.apple.cursor.22",
                          @"IBeam", @"com.apple.coregraphics.IBeam",
                          @"Move", @"com.apple.coregraphics.Move",
                          @"Crosshair", @"com.apple.cursor.7",
                          @"Poof", @"com.apple.cursor.25",
                          @"Wait", @"com.apple.coregraphics.Wait",
                          @"Link", @"com.apple.cursor.2",
                          @"Window E-W", @"com.apple.cursor.28",
                          @"Window N", @"com.apple.cursor.31",
                          @"Closed", @"com.apple.cursor.11",
                          @"Alias", @"com.apple.coregraphics.Alias",
                          @"Empty", @"com.apple.coregraphics.Empty",
                          @"Counting Up", @"com.apple.cursor.14",
                          @"Window NW-SE", @"com.apple.cursor.34",
                          @"Crosshair 2", @"com.apple.cursor.8",
                          @"Window SW", @"com.apple.cursor.37",
                          @"Resize W", @"com.apple.cursor.17",
                          @"Help", @"com.apple.cursor.40",
                          @"Forbidden", @"com.apple.cursor.3",
                          @"Cell XOR", @"com.apple.cursor.20",
                          @"Zoom Out", @"com.apple.cursor.43",
                          @"Arrow (Tahoe)", @"com.apple.coregraphics.ArrowS",
                          @"IBeam (Tahoe)", @"com.apple.coregraphics.IBeamS",
                          nil];
    });
    
    return cursorNameMap;
}

NSString *nameForCursorIdentifier(NSString *identifier) {
    NSString *name = cursorMap()[identifier];
    return name ?: @"Unknown";
}

NSString *cursorIdentifierForName(NSString *name) {
    NSArray *keys = [cursorMap() allKeysForObject:name];
    if (keys.count)
        return keys[0];
    return UUID();
}

CGError MACIsCursorRegistered(CGSConnectionID cid, char *cursorName, bool *registered) {
    
    size_t size = 0;
    CGError err = 0;
    err = CGSGetRegisteredCursorDataSize(cid, cursorName, &size);
    
    *registered = !((BOOL)err) && size > 0;
    
    return err;
}

static NSString *safeFirstKeyForObject(NSDictionary *dict, NSString *object) {
    NSArray *keys = [dict allKeysForObject:object];
    return keys.count > 0 ? keys[0] : nil;
}

BOOL MACCursorIsPointer(NSString *identifier) {
    static NSArray *pointers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *c = cursorMap();
        NSArray *candidates = @[
            safeFirstKeyForObject(c, @"Alias") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Arrow") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Busy") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Closed") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Copy Drag") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Counting Down") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Counting Up") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Counting Up/Down") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Ctx Menu") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Forbidden") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Link") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Move") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Open") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Pointing") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Poof") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Wait") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Zoom In") ?: [NSNull null],
            safeFirstKeyForObject(c, @"Zoom Out") ?: [NSNull null],
        ];
        NSMutableArray *filtered = [NSMutableArray arrayWithCapacity:candidates.count];
        for (id obj in candidates) {
            if (obj != [NSNull null]) {
                [filtered addObject:obj];
            }
        }
        pointers = [filtered copy];
    });

    return [pointers containsObject:identifier];
}

BOOL MACIsTahoeOrLater(void) {
    static BOOL checked = NO;
    static BOOL isTahoe = NO;
    if (!checked) {
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        isTahoe = (version.majorVersion >= 26);
        checked = YES;
    }
    return isTahoe;
}

NSArray *MACTahoeCursorAliasesForIdentifier(NSString *identifier) {
    if (!MACIsTahoeOrLater()) return nil;

    static NSDictionary *aliasMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        aliasMap = @{
            @"com.apple.coregraphics.Arrow": @[ @"com.apple.coregraphics.ArrowS" ],
            @"com.apple.coregraphics.IBeam": @[ @"com.apple.coregraphics.IBeamS" ],
            @"com.apple.coregraphics.ArrowS": @[ @"com.apple.coregraphics.Arrow" ],
            @"com.apple.coregraphics.IBeamS": @[ @"com.apple.coregraphics.IBeam" ],
        };
    });

    return aliasMap[identifier];
}

static NSString *const kHIServicesCursorsPath =
    @"/System/Library/Frameworks/ApplicationServices.framework"
    @"/Versions/A/Frameworks/HIServices.framework"
    @"/Versions/A/Resources/cursors";

static NSDictionary<NSString *, NSString *> *MACCoreCursorToHIServicesMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"com.apple.cursor.2":  @"pointinghand",
            @"com.apple.cursor.3":  @"notallowed",
            @"com.apple.cursor.4":  @"busybutclickable",
            @"com.apple.cursor.5":  @"copy",
            @"com.apple.cursor.7":  @"cross",
            @"com.apple.cursor.8":  @"cross",
            @"com.apple.cursor.9":  @"screenshotwindow",
            @"com.apple.cursor.10": @"screenshotselection",
            @"com.apple.cursor.11": @"closedhand",
            @"com.apple.cursor.12": @"openhand",
            @"com.apple.cursor.13": @"pointinghand",
            @"com.apple.cursor.14": @"countinguphand",
            @"com.apple.cursor.15": @"countingdownhand",
            @"com.apple.cursor.16": @"countingupandownhand",
            @"com.apple.cursor.17": @"resizeleft",
            @"com.apple.cursor.18": @"resizeright",
            @"com.apple.cursor.19": @"resizeleftright",
            @"com.apple.cursor.20": @"cross",
            @"com.apple.cursor.21": @"resizeup",
            @"com.apple.cursor.22": @"resizedown",
            @"com.apple.cursor.23": @"resizeupdown",
            @"com.apple.cursor.24": @"contextualmenu",
            @"com.apple.cursor.25": @"poof",
            @"com.apple.cursor.26": @"ibeamhorizontal",
            @"com.apple.cursor.27": @"resizeeast",
            @"com.apple.cursor.28": @"resizeeastwest",
            @"com.apple.cursor.29": @"resizenortheast",
            @"com.apple.cursor.30": @"resizenortheastsouthwest",
            @"com.apple.cursor.31": @"resizenorth",
            @"com.apple.cursor.32": @"resizenorthsouth",
            @"com.apple.cursor.33": @"resizenorthwest",
            @"com.apple.cursor.34": @"resizenorthwestsoutheast",
            @"com.apple.cursor.35": @"resizesoutheast",
            @"com.apple.cursor.36": @"resizesouth",
            @"com.apple.cursor.37": @"resizesouthwest",
            @"com.apple.cursor.38": @"resizewest",
            @"com.apple.cursor.39": @"cross",
            @"com.apple.cursor.40": @"help",
            @"com.apple.cursor.41": @"cell",
            @"com.apple.cursor.42": @"zoomin",
            @"com.apple.cursor.43": @"zoomout",
        };
    });
    return map;
}

static NSDictionary<NSString *, NSString *> *MACNamedCursorToHIServicesMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @"com.apple.coregraphics.Alias":    @"makealias",
            @"com.apple.coregraphics.Copy":     @"copy",
            @"com.apple.coregraphics.ArrowCtx": @"contextualmenu",
            @"com.apple.coregraphics.Move":     @"move",
            @"com.apple.coregraphics.IBeam":    @"ibeamvertical",
            @"com.apple.coregraphics.IBeamXOR": @"ibeamvertical",

        };
    });
    return map;
}

static BOOL MACIsRedPlaceholder(CGImageRef image) {
    if (!image) return YES;

    size_t w = CGImageGetWidth(image);
    size_t h = CGImageGetHeight(image);

    if (w > 32 || h > 32) return NO;

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    size_t bpr = w * 4;
    uint8_t *buf = calloc(h, bpr);
    CGContextRef ctx = CGBitmapContextCreate(buf, w, h, 8, bpr, cs,
                                             (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);

    BOOL allRed = YES;
    for (size_t i = 0; i < w * h && allRed; i++) {
        uint8_t r = buf[i * 4 + 0];
        uint8_t g = buf[i * 4 + 1];
        uint8_t b = buf[i * 4 + 2];
        uint8_t a = buf[i * 4 + 3];
        if (!(r == 255 && g == 0 && b == 0 && a == 255)) {
            allRed = NO;
        }
    }

    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    free(buf);
    return allRed;
}

static NSDictionary *MACCursorThemeFromHIServicesPDF(NSString *folderName) {
    NSString *cursorDir = [kHIServicesCursorsPath stringByAppendingPathComponent:folderName];
    NSString *pdfPath = [cursorDir stringByAppendingPathComponent:@"cursor.pdf"];
    NSString *infoPath = [cursorDir stringByAppendingPathComponent:@"info.plist"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:pdfPath]) return nil;

    NSData *infoData = [NSData dataWithContentsOfFile:infoPath];
    if (!infoData) return nil;
    NSError *plistErr = nil;
    NSDictionary *info = [NSPropertyListSerialization propertyListWithData:infoData
                                                                  options:NSPropertyListImmutable
                                                                   format:NULL
                                                                    error:&plistErr];
    if (!info || ![info isKindOfClass:[NSDictionary class]]) return nil;

    CGFloat hotX = [info[@"hotx"] doubleValue];
    CGFloat hotY = [info[@"hoty"] doubleValue];
    NSInteger frames = [info[@"frames"] integerValue];
    if (frames < 1) frames = 1;
    CGFloat delay = [info[@"delay"] doubleValue];

    CGDataProviderRef provider = CGDataProviderCreateWithFilename(pdfPath.UTF8String);
    if (!provider) return nil;

    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (!pdf) return nil;

    size_t pageCount = CGPDFDocumentGetNumberOfPages(pdf);
    if (pageCount == 0) {
        CGPDFDocumentRelease(pdf);
        return nil;
    }

    CGPDFPageRef page1 = CGPDFDocumentGetPage(pdf, 1);
    CGRect mediaBox = CGPDFPageGetBoxRect(page1, kCGPDFMediaBox);
    CGFloat pointsWide = mediaBox.size.width;
    CGFloat pointsHigh = mediaBox.size.height;

    if (frames > 1 && pageCount == 1) {
        pointsHigh = pointsHigh / frames;
    }

    int scales[] = { 1, 2 };
    int scaleCount = 2;
    NSMutableArray *pngReps = [NSMutableArray array];

    for (int s = 0; s < scaleCount; s++) {
        int scale = scales[s];
        NSUInteger imgW = (NSUInteger)(pointsWide * scale);
        NSUInteger totalH;

        if (frames > 1 && (NSInteger)pageCount >= frames) {
            totalH = (NSUInteger)(pointsHigh * scale * frames);
        } else if (frames > 1 && pageCount == 1) {
            totalH = (NSUInteger)(mediaBox.size.height * scale);
        } else {
            totalH = (NSUInteger)(pointsHigh * scale);
        }

        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef ctx = CGBitmapContextCreate(NULL, imgW, totalH, 8,
                                                  imgW * 4, cs,
                                                  (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(cs);
        if (!ctx) continue;

        CGContextClearRect(ctx, CGRectMake(0, 0, imgW, totalH));

        if (frames > 1 && (NSInteger)pageCount >= frames) {
            for (NSInteger f = 0; f < frames && f < (NSInteger)pageCount; f++) {
                CGPDFPageRef page = CGPDFDocumentGetPage(pdf, f + 1);
                if (!page) continue;
                CGContextSaveGState(ctx);
                CGFloat yOffset = (frames - 1 - f) * pointsHigh * scale;
                CGContextTranslateCTM(ctx, 0, yOffset);
                CGContextScaleCTM(ctx, scale, scale);
                CGContextDrawPDFPage(ctx, page);
                CGContextRestoreGState(ctx);
            }
        } else {
            CGContextScaleCTM(ctx, scale, scale);
            CGContextDrawPDFPage(ctx, page1);
        }

        CGImageRef rendered = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);

        if (rendered) {
            NSData *png = pngDataForImage((__bridge id)rendered);
            CGImageRelease(rendered);
            if (png) [pngReps addObject:png];
        }
    }

    CGPDFDocumentRelease(pdf);

    if (pngReps.count == 0) return nil;

    return @{
        MACCursorDictionaryFrameCountKey:      @(frames),
        MACCursorDictionaryFrameDurationKey:    @(delay),
        MACCursorDictionaryHotSpotXKey:         @(hotX),
        MACCursorDictionaryHotSpotYKey:         @(hotY),
        MACCursorDictionaryPointsWideKey:       @(pointsWide),
        MACCursorDictionaryPointsHighKey:       @(pointsHigh),
        MACCursorDictionaryRepresentationsKey:  pngReps,
    };
}

static NSBitmapImageRep *MACEnsureSRGB(NSBitmapImageRep *rep) {
    NSColorSpace *targetSpace = [NSColorSpace sRGBColorSpace];
    if (rep.colorSpace != nil && rep.colorSpace.numberOfColorComponents == 1) {
        targetSpace = [NSColorSpace genericGamma22GrayColorSpace];
    }
    NSBitmapImageRep *converted = [rep bitmapImageRepByConvertingToColorSpace:targetSpace
                                                              renderingIntent:NSColorRenderingIntentDefault];
    return converted ?: rep;
}

static NSDictionary *MACCaptureCursorTheme(CGSConnectionID cid, NSString *identifier) {
    NSUInteger frameCount = 0;
    CGFloat frameDuration = 0.0;
    CGPoint hotSpot = CGPointZero;
    CGSize size = CGSizeZero;
    CFArrayRef representations = NULL;
    CGError error;

    if (![identifier hasPrefix:@"com.apple.cursor."]) {
        bool registered = false;
        MACIsCursorRegistered(cid, (char *)identifier.UTF8String, &registered);
        if (!registered) return nil;
        error = CGSCopyRegisteredCursorImages(cid,
            (char *)identifier.UTF8String,
            &size, &hotSpot, &frameCount, &frameDuration, &representations);
    } else {
        int cursorID = [[identifier pathExtension] intValue];
        error = CoreCursorCopyImages(cid, cursorID,
            &representations, &size, &hotSpot, &frameCount, &frameDuration);
    }

    if (error != kCGErrorSuccess || !representations || CFArrayGetCount(representations) == 0) {
        if (representations) CFRelease(representations);
        return nil;
    }

    NSArray *cgImages = CFBridgingRelease(representations);
    CGImageRef firstImg = (__bridge CGImageRef)cgImages[0];

    BOOL isBadData = MACIsRedPlaceholder(firstImg);

    if (!isBadData) {
        size_t imgW = CGImageGetWidth(firstImg);
        size_t imgH = CGImageGetHeight(firstImg);
        CGFloat expectedMinH = size.height;
        if (imgH < (size_t)expectedMinH || imgW < (size_t)size.width) {
            isBadData = YES;
            MMLog("  Degenerate image for %s: %zux%zu (expected >= %.0fx%.0f)",
                  identifier.UTF8String, imgW, imgH, size.width, size.height);
        }
    }

    if (isBadData) {
        float currentScale;
        CGSGetCursorScale(cid, &currentScale);
        if (currentScale > 1.0f) {
            MMLog("  Bad data for %s at %.0fx, retrying at 1x...",
                  identifier.UTF8String, currentScale);
            CGSSetCursorScale(cid, 1.0f);

            NSUInteger retryFC = 0;
            CGFloat retryDur = 0.0;
            CGPoint retryHot = CGPointZero;
            CGSize retrySize = CGSizeZero;
            CFArrayRef retryReps = NULL;
            CGError retryErr;

            if (![identifier hasPrefix:@"com.apple.cursor."]) {
                retryErr = CGSCopyRegisteredCursorImages(cid,
                    (char *)identifier.UTF8String,
                    &retrySize, &retryHot, &retryFC, &retryDur, &retryReps);
            } else {
                int cursorID = [[identifier pathExtension] intValue];
                retryErr = CoreCursorCopyImages(cid, cursorID,
                    &retryReps, &retrySize, &retryHot, &retryFC, &retryDur);
            }

            CGSSetCursorScale(cid, currentScale);

            if (retryErr == kCGErrorSuccess && retryReps && CFArrayGetCount(retryReps) > 0) {
                NSArray *retryImages = CFBridgingRelease(retryReps);
                CGImageRef retryFirst = (__bridge CGImageRef)retryImages[0];

                if (!MACIsRedPlaceholder(retryFirst)) {
                    size_t rw = CGImageGetWidth(retryFirst);
                    size_t rh = CGImageGetHeight(retryFirst);
                    if (rh >= (size_t)retrySize.height && rw >= (size_t)retrySize.width) {
                        MMLog("  1x retry succeeded for %s (%zux%zu, %lu frames)",
                              identifier.UTF8String, rw, rh, (unsigned long)retryFC);
                        NSMutableArray *retryPngs = [NSMutableArray arrayWithCapacity:retryImages.count];
                        for (id img in retryImages) {
                            CGImageRef cgImg = (__bridge CGImageRef)img;
                            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
                            NSBitmapImageRep *srgbRep = MACEnsureSRGB(rep);
                            CGImageRef srgbImg = [srgbRep CGImage];
                            NSData *png = pngDataForImage((__bridge id)srgbImg);
                            if (png) [retryPngs addObject:png];
                        }
                        if (retryPngs.count > 0) {
                            return @{
                                MACCursorDictionaryFrameCountKey:      @(retryFC),
                                MACCursorDictionaryFrameDurationKey:    @(retryDur),
                                MACCursorDictionaryHotSpotXKey:         @(retryHot.x),
                                MACCursorDictionaryHotSpotYKey:         @(retryHot.y),
                                MACCursorDictionaryPointsWideKey:       @(retrySize.width),
                                MACCursorDictionaryPointsHighKey:       @(retrySize.height),
                                MACCursorDictionaryRepresentationsKey:  retryPngs,
                            };
                        }
                    }
                }
            } else {
                if (retryReps) CFRelease(retryReps);
            }
        }

        NSString *hiName = nil;
        if ([identifier hasPrefix:@"com.apple.cursor."]) {
            hiName = MACCoreCursorToHIServicesMap()[identifier];
        } else {
            hiName = MACNamedCursorToHIServicesMap()[identifier];
        }
        if (hiName) {
            MMLog("  Falling back to HIServices/%s for %s",
                  hiName.UTF8String, identifier.UTF8String);
            NSDictionary *hiTheme = MACCursorThemeFromHIServicesPDF(hiName);
            if (hiTheme) return hiTheme;
        }
    }

    NSMutableArray *pngReps = [NSMutableArray arrayWithCapacity:cgImages.count];
    for (id image in cgImages) {
        CGImageRef cgImg = (__bridge CGImageRef)image;
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:cgImg];
        NSBitmapImageRep *srgbRep = MACEnsureSRGB(rep);
        CGImageRef srgbImg = [srgbRep CGImage];
        NSData *png = pngDataForImage((__bridge id)srgbImg);
        if (png) [pngReps addObject:png];
    }

    if (pngReps.count == 0) return nil;

    return @{
        MACCursorDictionaryFrameCountKey:      @(frameCount),
        MACCursorDictionaryFrameDurationKey:    @(frameDuration),
        MACCursorDictionaryHotSpotXKey:         @(hotSpot.x),
        MACCursorDictionaryHotSpotYKey:         @(hotSpot.y),
        MACCursorDictionaryPointsWideKey:       @(size.width),
        MACCursorDictionaryPointsHighKey:       @(size.height),
        MACCursorDictionaryRepresentationsKey:  pngReps,
    };
}

NSString *MACSystemDefaultCursorPath(void) {
    NSURL *appSupportURL = [[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask].firstObject;
    return [appSupportURL.path stringByAppendingPathComponent:@"MaCursor/SystemDefault.cursor"];
}

BOOL MACPerformCursorCapture(NSString *outputPath) {
    @autoreleasepool {
        CGSConnectionID cid = CGSMainConnectionID();
        if (cid == 0) {
            MMLog(BOLD RED "MACCaptureSystemDefaults: Could not connect to window server" RESET);
            return NO;
        }

        MMLog("Capturing system default cursors...");

        float originalScale = 1.0f;
        CGSGetCursorScale(cid, &originalScale);
        CGSSetCursorScale(cid, MACDumpCursorScale);
        CGSHideCursor(cid);

        NSMutableDictionary *cursors = [NSMutableDictionary dictionary];
        NSUInteger totalFound = 0;

        NSSet *namedSkipSet = [NSSet setWithArray:@[
            @"com.apple.coregraphics.IBeamXOR",
            @"com.apple.coregraphics.Empty",
        ]];
        NSSet *coreSkipSet = [NSSet setWithArray:@[
            @"com.apple.cursor.0",
            @"com.apple.cursor.1",
            @"com.apple.cursor.8",
        ]];

        NSUInteger i = 0;
        NSString *key = nil;
        while ((key = defaultCursors[i]) != nil) {
            if (![namedSkipSet containsObject:key]) {
                NSDictionary *theme = MACCaptureCursorTheme(cid, key);
                if (theme) {
                    cursors[key] = theme;
                    totalFound++;
                    MMLog("  Captured: %s", key.UTF8String);
                } else {
                    MMLog(BOLD YELLOW "  Missing:  %s" RESET, key.UTF8String);
                }
            }
            i++;
        }

        for (int x = 0; x <= MC_MAX_CORE_CURSOR_ID; x++) {
            NSString *cursorKey = [NSString stringWithFormat:@"com.apple.cursor.%d", x];
            if ([coreSkipSet containsObject:cursorKey]) continue;

            CoreCursorSet(cid, x);

            NSDictionary *theme = MACCaptureCursorTheme(cid, cursorKey);
            if (theme) {
                cursors[cursorKey] = theme;
                totalFound++;
                MMLog("  Captured: %s", cursorKey.UTF8String);
            } else {
                MMLog(BOLD YELLOW "  Missing:  %s" RESET, cursorKey.UTF8String);
            }
        }

        CGSShowCursor(cid);
        CGSSetCursorScale(cid, originalScale);

        NSOperatingSystemVersion osVer = [[NSProcessInfo processInfo] operatingSystemVersion];
        NSString *osString = [NSString stringWithFormat:@"macOS %ld.%ld.%ld",
                              (long)osVer.majorVersion, (long)osVer.minorVersion, (long)osVer.patchVersion];

        NSDictionary *theme = @{
            MACCursorDictionaryCreatorKey:        @"Apple, Inc.",
            MACCursorDictionaryThemeNameKey:      [NSString stringWithFormat:@"System Default (%@)", osString],
            MACCursorDictionaryThemeVersionKey:   @1.0,
            MACCursorDictionaryCursorsKey:        cursors,
            MACCursorDictionaryHiDPIKey:          @YES,
            MACCursorDictionaryIdentifierKey:     @"com.writronic.macursor.systemdefault",
            MACCursorDictionaryUUIDKey:           [[NSUUID UUID] UUIDString],
        };

        NSError *writeError = nil;
        NSData *plistData = [NSPropertyListSerialization
            dataWithPropertyList:theme
                          format:NSPropertyListBinaryFormat_v1_0
                         options:0
                           error:&writeError];
        if (!plistData) {
            MMLog(BOLD RED "MACCaptureSystemDefaults: Serialization failed: %s" RESET,
                  writeError.localizedDescription.UTF8String);
            return NO;
        }

        NSString *parentDir = [outputPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:parentDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        if (![plistData writeToFile:outputPath options:NSDataWritingAtomic error:&writeError]) {
            MMLog(BOLD RED "MACCaptureSystemDefaults: Write failed: %s" RESET,
                  writeError.localizedDescription.UTF8String);
            return NO;
        }

        MMLog(BOLD GREEN "Captured %lu cursors to %s (%.1f KB)" RESET,
              (unsigned long)totalFound, outputPath.UTF8String,
              plistData.length / 1024.0);
        return YES;
    }
}

BOOL MACCaptureSystemDefaults(NSString *outputPath) {
    return MACPerformCursorCapture(outputPath);
}

NSString *MACPreferencesAppliedCursorKey          = @"MACAppliedCursor";
NSString *MACPreferencesAppliedClickActionKey     = @"MACLibraryClickAction";
NSString *MACPreferencesCursorScaleKey            = @"MACCursorScale";
NSString *MACPreferencesDoubleActionKey           = @"MACDoubleAction";
NSString *MACPreferencesHandednessKey             = @"MACHandedness";
NSString *MACSuppressDeleteLibraryConfirmationKey = @"MACSuppressDeleteLibraryConfirmationKey";
NSString *MACSuppressDeleteCursorConfirmationKey  = @"MACSuppressDeleteCursorConfirmationKey";
id MACDefaultFor(NSString *key, NSString *user, NSString *host) {
    NSString *value = (__bridge_transfer NSString *)CFPreferencesCopyValue((CFStringRef)key, (CFStringRef)kMACDomain, (CFStringRef)user, (CFStringRef)host);
    return value;
}

id MACDefault(NSString *key) {
    return (__bridge_transfer id)CFPreferencesCopyAppValue((CFStringRef)key, (CFStringRef)kMACDomain);
}

void MACSetDefaultFor(id value, NSString *key, NSString *user, NSString *host) {
    CFPreferencesSetValue((CFStringRef)key, (CFPropertyListRef)value, (CFStringRef)kMACDomain, (CFStringRef)user, (CFStringRef)host);
    CFPreferencesSynchronize((CFStringRef)kMACDomain, (CFStringRef)user, (CFStringRef)host);
}

@implementation NSBitmapImageRep (ColorSpace)

- (NSBitmapImageRep *)ensuredSRGBSpace {
    NSColorSpace *targetSpace = [NSColorSpace sRGBColorSpace];
    if (self.colorSpace != NULL) {
        if (self.colorSpace.numberOfColorComponents == 1) {
            targetSpace = [NSColorSpace genericGamma22GrayColorSpace];
        }
    }
    return [self bitmapImageRepByConvertingToColorSpace:targetSpace
                                        renderingIntent:NSColorRenderingIntentDefault];
}

- (NSBitmapImageRep *)retaggedSRGBSpace {
    NSColorSpace *targetSpace = [NSColorSpace sRGBColorSpace];
    if (self.colorSpace != NULL) {
        if (self.colorSpace.numberOfColorComponents == 1) {
            targetSpace = [NSColorSpace genericGamma22GrayColorSpace];
        }
    }
    return [self bitmapImageRepByRetaggingWithColorSpace:targetSpace];
}

@end
