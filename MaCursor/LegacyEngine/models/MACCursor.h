#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MACCursorScale) {
    MACCursorScaleNone = 000,
    MACCursorScale100  = 100,
    MACCursorScale200  = 200,
    MACCursorScale500  = 500,
    MACCursorScale1000 = 1000
};

extern MACCursorScale cursorScaleForScale(CGFloat scale);

@interface MACCursor : NSObject <NSCopying>
@property (nonatomic, copy)     NSString          *identifier;
@property (nonatomic, readonly) NSString          *name;
@property (nonatomic, assign)   CGFloat           frameDuration;
@property (nonatomic, assign)   NSUInteger        frameCount;
@property (nonatomic, assign)   NSSize            size;
@property (nonatomic, assign)   NSPoint           hotSpot;

+ (MACCursor *)cursorWithDictionary:(NSDictionary *)dict;
- (id)initWithCursorDictionary:(NSDictionary *)dict;

- (void)setRepresentation:(NSImageRep *)imageRep forScale:(MACCursorScale)scale;
- (void)removeRepresentationForScale:(MACCursorScale)scale;
- (void)addFrame:(NSImageRep *)frame forScale:(MACCursorScale)scale;

- (NSImageRep *)representationForScale:(MACCursorScale)scale;
- (NSImageRep *)representationWithScale:(CGFloat)scale;

- (NSDictionary *)dictionaryRepresentation;
+ (NSImageRep *)composeRepresentationWithFrames:(NSArray *)frames;

- (NSImage *)imageWithAllReps;
@end

@interface MACCursor (Properties)
@property (nonatomic, readonly, strong) NSDictionary *representations;
@end
