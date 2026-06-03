#import "MACCursor.h"
#import "MACCursorDefs.h"
MACCursorScale cursorScaleForScale(CGFloat scale) {
    if (scale < 0.0)
        return MACCursorScaleNone;
    
    return (MACCursorScale)((NSInteger)scale * 100);
}

@interface MACCursor ()
@property (readwrite, strong) NSMutableDictionary<NSString *, NSBitmapImageRep *> *representations;
- (NSInteger)framesForScale:(MACCursorScale)scale;
- (BOOL)_readFromDictionary:(NSDictionary *)dictionary;
@end

@implementation MACCursor
@dynamic name;

+ (MACCursor *)cursorWithDictionary:(NSDictionary *)dict {
    return [[self alloc] initWithCursorDictionary:dict];
}

- (id)init {
    if ((self = [super init])) {
        self.frameCount      = 1;
        self.frameDuration   = 1.0;
        self.size            = NSZeroSize;
        self.hotSpot         = NSZeroPoint;
        self.identifier      = [UUID() stringByReplacingOccurrencesOfString:@"-" withString:@""];
        self.representations = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id)initWithCursorDictionary:(NSDictionary *)dict {
    if ((self = [self init])) {
        
        if (![self _readFromDictionary:dict])
            return nil;
        
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    MACCursor *cursor = [[MACCursor allocWithZone:zone] init];
    
    cursor.frameCount      = self.frameCount;
    cursor.frameDuration   = self.frameDuration;
    cursor.size            = self.size;
    cursor.representations = self.representations.mutableCopy;
    cursor.hotSpot         = self.hotSpot;
    cursor.identifier      = self.identifier;
    
    return cursor;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {    
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    
    if ([key isEqualToString:@"imageWithAllReps"]) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:@[ @"representations" ]];
    } else if ([key isEqualToString:@"name"]) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:@[ @"identifier" ]];
    } else if ([key hasPrefix:@"cursorImage"]) {
        keyPaths = [keyPaths setByAddingObjectsFromArray:@[ [key stringByReplacingCharactersInRange:NSMakeRange(6, 5) withString:@"Rep"] ]];
    }
    
    return keyPaths;
}

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || !dictionary.count)
        return NO;
    
    NSNumber *frameCount    = [dictionary objectForKey:MACCursorDictionaryFrameCountKey];
    NSNumber *frameDuration = [dictionary objectForKey:MACCursorDictionaryFrameDurationKey];
    NSNumber *hotSpotX      = [dictionary objectForKey:MACCursorDictionaryHotSpotXKey];
    NSNumber *hotSpotY      = [dictionary objectForKey:MACCursorDictionaryHotSpotYKey];
    NSNumber *pointsWide    = [dictionary objectForKey:MACCursorDictionaryPointsWideKey];
    NSNumber *pointsHigh    = [dictionary objectForKey:MACCursorDictionaryPointsHighKey];
    NSArray *reps           = [dictionary objectForKey:MACCursorDictionaryRepresentationsKey];
    
    if (frameCount && frameDuration && hotSpotX && hotSpotY && pointsWide && pointsHigh) {
        
        self.frameCount    = frameCount.unsignedIntegerValue;
        self.frameDuration = frameDuration.doubleValue;
        self.hotSpot       = NSMakePoint(hotSpotX.doubleValue, hotSpotY.doubleValue);
        
        self.size           = NSMakeSize(pointsWide.doubleValue, pointsHigh.doubleValue);
        
        for (NSData *data in reps) {
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:data];
            rep.size = NSMakeSize(self.size.width, self.size.height * self.frameCount);

            [self setRepresentation:rep.retaggedSRGBSpace forScale:cursorScaleForScale(rep.pixelsWide / pointsWide.doubleValue)];
        }

        return YES;
    }

    return NO;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *drep = [NSMutableDictionary dictionary];
    drep[MACCursorDictionaryFrameCountKey]    = @(self.frameCount);
    drep[MACCursorDictionaryFrameDurationKey] = @(self.frameDuration);
    drep[MACCursorDictionaryHotSpotXKey]      = @(self.hotSpot.x);
    drep[MACCursorDictionaryHotSpotYKey]      = @(self.hotSpot.y);
    drep[MACCursorDictionaryPointsWideKey]    = @(self.size.width);
    drep[MACCursorDictionaryPointsHighKey]    = @(self.size.height);
    
    NSMutableArray *pngs = [NSMutableArray array];
    for (NSString *key in self.representations) {
        NSBitmapImageRep *rep = self.representations[key];
        pngs[pngs.count] = [rep.ensuredSRGBSpace representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    }
    
    drep[MACCursorDictionaryRepresentationsKey] = pngs;
    
    return drep;
}

- (id)valueForUndefinedKey:(NSString *)key {
    if ([key hasPrefix:@"cursorRep"] || [key hasPrefix:@"cursorImage"]) {
        NSString *prefix = [key hasPrefix:@"cursorRep"] ? @"cursorRep" : @"cursorImage";

        NSString *scaleString = [key substringFromIndex:prefix.length];
        CGFloat scale = [scaleString doubleValue] / 100;
        
        if ([key hasPrefix:@"cursorRep"])
            return [self representationForScale:cursorScaleForScale(scale)];
        else {
            NSImageRep *rep = [self representationForScale:cursorScaleForScale(scale)];
            if (rep) {
                NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(rep.pixelsWide / scale, rep.pixelsHigh / scale)];
                [image addRepresentation:rep];
                return image;
            }
            return nil;
        }
    }
    
    return [super valueForUndefinedKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    if ([key hasPrefix:@"cursorRep"] || [key hasPrefix:@"cursorImage"]) {
        NSString *prefix = [key hasPrefix:@"cursorRep"] ? @"cursorRep" : @"cursorImage";
        NSString *scaleString = [key substringFromIndex:prefix.length];
        CGFloat scale = [scaleString doubleValue] / 100;
        
        if ([key hasPrefix:@"cursorImage"]) {
            value = [(NSImage *)value representations][0];
        }
        
        [self setRepresentation:value forScale:cursorScaleForScale(scale)];
        return;
    }
    
    [super setValue:value forUndefinedKey:key];
}

- (void)setRepresentation:(NSBitmapImageRep *)imageRep forScale:(MACCursorScale)scale {
    [self willChangeValueForKey:@"representations"];
    
    NSString *key = [@"cursorRep" stringByAppendingFormat:@"%lu", scale];
    [self willChangeValueForKey:key];
    if (imageRep)
        [self.representations setObject:imageRep forKey:[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];
    else
        [self.representations removeObjectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];

    if (self.representations.count == 1) {
        NSSize size = NSMakeSize((double)imageRep.pixelsWide / (scale / 100.0), (double)imageRep.pixelsHigh / self.frameCount / (scale / 100.0));
        if (!NSEqualSizes(size, NSZeroSize)) {
            self.size = size;
        }
    }

    [self didChangeValueForKey:key];
    [self didChangeValueForKey:@"representations"];
}

- (void)addFrame:(NSImageRep *)frame forScale:(MACCursorScale)scale {
    NSImageRep *rep = [self representationForScale:scale];
    NSImageRep *newRep = [self.class composeRepresentationWithFrames:@[ rep, frame ]];

    NSInteger frames = newRep.pixelsHigh / self.size.height;

    if (self.frameCount < frames) {
        self.frameCount = frames;
    }

    [self setRepresentation:newRep forScale:scale];
}

+ (NSBitmapImageRep *)composeRepresentationWithFrames:(NSArray<NSBitmapImageRep *> *)frames {
    if (frames.count == 0)
        return nil;
    if (frames.count == 1)
        return frames.firstObject;

    NSUInteger height = [[frames valueForKeyPath:@"@sum.pixelsHigh"] unsignedIntegerValue];
    NSUInteger width = [(NSImageRep *)frames[0] pixelsWide];

    CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height,
                                              8, 0, cs,
                                              (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    CGColorSpaceRelease(cs);
    if (!ctx) return nil;

    NSUInteger currentY = 0;
    for (NSInteger idx = frames.count - 1; idx >= 0; idx--) {
        NSBitmapImageRep *rep = frames[idx];
        if (rep.pixelsWide != width) {
            NSLog(@"Can't create representation from images of different widths");
            CGContextRelease(ctx);
            return nil;
        }

        CGImageRef frameImg = [rep CGImage];
        CGContextDrawImage(ctx,
                           CGRectMake(0, currentY, rep.pixelsWide, rep.pixelsHigh),
                           frameImg);
        currentY += rep.pixelsHigh;
    }

    CGImageRef composedImg = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    if (!composedImg) return nil;

    NSBitmapImageRep *result = [[NSBitmapImageRep alloc] initWithCGImage:composedImg];
    CGImageRelease(composedImg);
    return result;
}

- (NSInteger)framesForScale:(MACCursorScale)scale {
    return [self representationForScale:scale].pixelsHigh / self.size.height;
}

- (void)removeRepresentationForScale:(MACCursorScale)scale {
    [self setRepresentation:nil forScale:scale];
}

- (NSImageRep *)representationForScale:(MACCursorScale)scale {
    return self.representations[[NSString stringWithFormat:@"%lu", (unsigned long)scale, nil]];
}

- (NSImageRep *)representationWithScale:(CGFloat)scale {
    return [self representationForScale:cursorScaleForScale(scale)];
}

- (NSImage *)imageWithAllReps {
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(self.size.width, self.size.height * self.frameCount)];
    [image addRepresentations:self.representations.allValues];
    return image;
}

- (NSString *)name {
    return nameForCursorIdentifier(self.identifier);
}

- (BOOL)isEqualTo:(MACCursor *)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }
    
    BOOL props =  (object.frameCount == self.frameCount &&
                   object.frameDuration == self.frameDuration &&
                   NSEqualSizes(object.size, self.size) &&
                   NSEqualPoints(object.hotSpot, self.hotSpot) &&
                   [object.identifier isEqualToString:self.identifier]);

    
    return props;
}

- (BOOL)isEqual:(id)object {
    return [self isEqualTo:object];
}

- (NSUInteger)hash {
    NSUInteger h = self.identifier.hash;
    h ^= (NSUInteger)self.frameCount * 31;
    h ^= (NSUInteger)(self.frameDuration * 1000) * 37;
    h ^= (NSUInteger)self.size.width * 41 ^ (NSUInteger)self.size.height * 43;
    h ^= (NSUInteger)self.hotSpot.x * 47 ^ (NSUInteger)self.hotSpot.y * 53;
    return h;
}

@end
