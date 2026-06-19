#import "MACLibraryController.h"
#import "MACCursorActions.h"

@interface MACLibraryController ()
@property (nonatomic, readwrite, strong) NSUndoManager *undoManager;
@property (nonatomic, retain) NSMutableSet *themes;
@property (readwrite, copy) NSURL *libraryURL;
- (void)loadLibrary;
- (void)willSaveNotification:(NSNotification *)note;
@end

@implementation MACLibraryController

- (NSString *)sanitizedFilenameFromName:(NSString *)name {
    NSString *sanitized = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
    sanitized = [sanitized stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    sanitized = [sanitized stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    sanitized = [sanitized stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (sanitized.length == 0) sanitized = @"Unnamed";
    return sanitized;
}

- (NSURL *)URLForTheme:(MACCursorLibrary *)theme {
    NSString *baseName = [self sanitizedFilenameFromName:theme.name];

    if (theme.fileURL &&
        [[theme.fileURL URLByDeletingLastPathComponent].standardizedURL isEqual:self.libraryURL.standardizedURL] &&
        [[NSFileManager defaultManager] fileExistsAtPath:theme.fileURL.path] &&
        [[[theme.fileURL lastPathComponent] stringByDeletingPathExtension] isEqualToString:baseName]) {
        return theme.fileURL;
    }

    NSURL *candidate = [self.libraryURL URLByAppendingPathComponent:[baseName stringByAppendingPathExtension:@"cursor"]];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSInteger suffix = 2;
    while ([fm fileExistsAtPath:candidate.path]) {
        NSString *numberedName = [NSString stringWithFormat:@"%@-%ld", baseName, (long)suffix];
        candidate = [self.libraryURL URLByAppendingPathComponent:[numberedName stringByAppendingPathExtension:@"cursor"]];
        suffix++;
    }

    return candidate;
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [self init])) {
        self.libraryURL = url;
        self.undoManager = [[NSUndoManager alloc] init];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willSaveNotification:) name:MACLibraryWillSaveNotificationName object:nil];
        [self loadLibrary];
    }

    return self;
}

- (void)loadLibrary {
    [self.undoManager disableUndoRegistration];

    self.themes = [NSMutableSet set];
    NSString *themesPath = self.libraryURL.path;
    NSArray  *contents  = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:themesPath error:NULL];
    NSString *applied   = MACDefault(MACPreferencesAppliedCursorKey);

    for (NSString *filename in contents) {
        if ([filename hasPrefix:@"."])
            continue;

        NSURL *fileURL = [NSURL fileURLWithPathComponents:@[ themesPath, filename ]];
        MACCursorLibrary *library = [MACCursorLibrary cursorLibraryWithContentsOfURL:fileURL];

        if ([library.identifier isEqualToString:applied]) {
            self.appliedTheme = library;
        }

        [self addTheme:library];
    }

    [self.undoManager enableUndoRegistration];
}

- (void)importThemeAtURL:(NSURL *)url {
    [self importTheme:[MACCursorLibrary cursorLibraryWithContentsOfURL:url]];
}

- (void)importTheme:(MACCursorLibrary *)lib {
    lib.identifier = [MACCursorLibrary sanitizeName:lib.name];

    NSSet *existingIds = [self.themes valueForKeyPath:@"identifier"];
    if ([existingIds containsObject:lib.identifier]) {
        NSString *baseName = lib.name;
        NSString *baseId = lib.identifier;
        NSInteger suffix = 2;
        NSString *candidateId = [NSString stringWithFormat:@"%@-%ld", baseId, (long)suffix];
        while ([existingIds containsObject:candidateId]) {
            suffix++;
            candidateId = [NSString stringWithFormat:@"%@-%ld", baseId, (long)suffix];
        }
        lib.name = [NSString stringWithFormat:@"%@-%ld", baseName, (long)suffix];
        lib.identifier = candidateId;
    }

    lib.fileURL = [self URLForTheme:lib];
    [lib writeToFile:lib.fileURL.path atomically:NO];

    [self addTheme:lib];
}

- (void)addTheme:(MACCursorLibrary *)theme {
    if (!theme) {
        NSLog(@"Cannot add nil cursor theme");
        return;
    }

    if ([self.themes containsObject:theme] || [[self.themes valueForKeyPath:@"identifier"] containsObject:theme.identifier]) {
        NSLog(@"Not adding %@ to the library because an object with that identifier already exists", theme.identifier);
        return;
    }

    NSSet *change = [NSSet setWithObject:theme];
    [self willChangeValueForKey:@"themes" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];

    theme.library = self;
    [self.themes addObject:theme];

    [[self.undoManager prepareWithInvocationTarget:self] removeTheme:theme];
    if (!self.undoManager.isUndoing) {
        [self.undoManager setActionName:[@"Add " stringByAppendingString:theme.name ?: @"Theme"]];
    }

    [self didChangeValueForKey:@"themes" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];

    [theme.undoManager removeAllActions];
}

- (void)removeTheme:(MACCursorLibrary *)theme {
    NSSet *change = [NSSet setWithObject:theme];

    [self willChangeValueForKey:@"themes" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
    if (theme == self.appliedTheme)
        [self restoreTheme];

    if (theme.library == self)
        theme.library = nil;

    [self.themes removeObject:theme];

    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *destinationURL = [NSURL fileURLWithPath:[[@"~/.Trash" stringByExpandingTildeInPath] stringByAppendingPathComponent:theme.fileURL.lastPathComponent] isDirectory:NO];

    [manager removeItemAtURL:destinationURL error:NULL];
    [manager moveItemAtURL:theme.fileURL toURL:destinationURL error:NULL];

    [[self.undoManager prepareWithInvocationTarget:self] importThemeAtURL:destinationURL];
    if (!self.undoManager.isUndoing) {
        [self.undoManager setActionName:[@"Remove " stringByAppendingString:theme.name ?: @"Theme"]];
    }

    [self didChangeValueForKey:@"themes" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
}

- (void)applyTheme:(MACCursorLibrary *)theme {
    if (applyThemeAtPath(theme.fileURL.path)) {
        self.appliedTheme = theme;
    }
}

- (void)restoreTheme {
    resetAllCursors(NULL);
    self.appliedTheme = nil;
}

- (NSSet *)themesWithIdentifier:(NSString *)identifier {
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
    return [self.themes filteredSetUsingPredicate:pred];
}

- (void)willSaveNotification:(NSNotification *)note {
    MACCursorLibrary *theme = note.object;
    NSURL *oldURL = theme.fileURL;
    [theme setFileURL:[self URLForTheme:theme]];
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:oldURL error:&error];

    if (error) {
        NSLog(@"error removing cursor theme after rename: %@", error);
    }

}

- (BOOL)dumpCursorsWithProgressBlock:(BOOL (^)(NSUInteger current, NSUInteger total))block {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat: @"%@ (%f).cursor",
                       NSLocalizedString(@"MaCursor Dump", @"MaCursor dump cursor file name"),
                       NSDate.date.timeIntervalSince1970]];
    if (dumpCursorsToFile(path, block)) {
        __weak MACLibraryController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf importThemeAtURL:[NSURL fileURLWithPath:path]];
        });
        return YES;
    }

    return NO;
}

@end
