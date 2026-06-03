#import <Foundation/Foundation.h>
#import "MACCursorLibrary.h"

@interface MACLibraryController : NSObject
@property (readwrite, weak) MACCursorLibrary *appliedTheme;
@property (nonatomic, readonly) NSUndoManager *undoManager;
@property (readonly, copy) NSURL *libraryURL;

- (instancetype)initWithURL:(NSURL *)url;

- (void)importThemeAtURL:(NSURL *)url;
- (void)importTheme:(MACCursorLibrary *)theme;

- (void)addTheme:(MACCursorLibrary *)theme;
- (void)removeTheme:(MACCursorLibrary *)theme;

- (void)applyTheme:(MACCursorLibrary *)theme;
- (void)restoreTheme;

- (NSURL *)URLForTheme:(MACCursorLibrary *)theme;

- (NSSet *)themesWithIdentifier:(NSString *)identifier;
- (BOOL)dumpCursorsWithProgressBlock:(BOOL (^)(NSUInteger current, NSUInteger total))block;

@end

@interface MACLibraryController (Themes)
@property (nonatomic, readonly) NSSet *themes;
@end
