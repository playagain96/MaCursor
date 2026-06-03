#import <Foundation/Foundation.h>
#import "MACCursor.h"

extern NSString *const MACLibraryWillSaveNotificationName;
extern NSString *const MACLibraryDidSaveNotificationName;

@class MACLibraryController;
@interface MACCursorLibrary : NSObject <NSCopying>
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, copy)   NSString *creator;
@property (nonatomic, copy)   NSString *identifier;
@property (nonatomic, copy)   NSNumber *version;
@property (nonatomic, copy)   NSString *uuid;
@property (nonatomic, copy)   NSURL    *fileURL;
@property (nonatomic, weak)   MACLibraryController *library;
@property (nonatomic, readonly) NSUndoManager *undoManager;
@property (nonatomic, readonly, getter=isDirty) BOOL dirty;
@property (nonatomic, assign, getter = isHiDPI)   BOOL hiDPI;

+ (MACCursorLibrary *)cursorLibraryWithContentsOfFile:(NSString *)path;
+ (MACCursorLibrary *)cursorLibraryWithContentsOfURL:(NSURL *)URL;
+ (MACCursorLibrary *)cursorLibraryWithDictionary:(NSDictionary *)dictionary;
+ (MACCursorLibrary *)cursorLibraryWithCursors:(NSSet *)cursors;

- (instancetype)initWithContentsOfFile:(NSString *)path;
- (instancetype)initWithContentsOfURL:(NSURL *)URL;
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (instancetype)initWithCursors:(NSSet *)cursors;

- (NSSet *)cursorsWithIdentifier:(NSString *)identifier;
- (void)addCursor:(MACCursor *)cursor;
- (void)removeCursor:(MACCursor *)cursor;
- (void)removeCursorsWithIdentifier:(NSString *)identifier;

- (NSDictionary *)dictionaryRepresentation;
- (BOOL)writeToFile:(NSString *)file atomically:(BOOL)atomically;
- (NSError *)save;

- (void)updateChangeCount:(NSDocumentChangeType)change;
- (void)revertToSaved;

+ (NSString *)sanitizeName:(NSString *)name;

@end

@interface MACCursorLibrary (Properties)
@property (nonatomic, readonly, strong) NSSet *cursors;
@end
