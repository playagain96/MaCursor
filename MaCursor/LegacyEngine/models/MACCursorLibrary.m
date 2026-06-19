#import "MACCursorLibrary.h"

NSString *const MACLibraryWillSaveNotificationName = @"MACLibraryWillSave";
NSString *const MACLibraryDidSaveNotificationName = @"MACLibraryDidSave";

@interface MACCursorLibrary ()
@property (nonatomic, strong) NSUndoManager *undoManager;
@property (nonatomic, readwrite, strong) NSMutableSet *cursors;
@property (nonatomic, assign) NSUInteger changeCount;
@property (nonatomic, assign) NSUInteger lastChangeCount;
@property (nonatomic, strong) NSArray *observers;
@property (nonatomic, copy) NSString *oldIdentifier;

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary;
- (void)addCursorsFromDictionary:(NSDictionary *)cursorDicts;

- (void)startObservingProperties;
- (void)stopObservingProperties;

- (void)startObservingCursor:(MACCursor *)cursor;
- (void)stopObservingCursor:(MACCursor *)cursor;

+ (NSDictionary<NSString *, NSString *> *)cursorUndoProperties;
+ (NSDictionary<NSString *, NSString *> *)undoProperties;
@end

@implementation MACCursorLibrary
@dynamic dirty;

+ (NSDictionary<NSString *, NSString *> *)undoProperties {
    return @{
        @"identifier": NSLocalizedString(@"identifier", @"Undo change cursor theme identifier suffix"),
        @"name":       NSLocalizedString(@"name", @"Undo change cursor theme name suffix"),
        @"creator":     NSLocalizedString(@"creator", @"Undo change cursor theme creator suffix"),
        @"hiDPI":      NSLocalizedString(@"hiDPI", @"Undo change cursor theme hidpi suffix"),
        @"version":    NSLocalizedString(@"version", @"Undo change cursor theme version suffix")
    };
}

+ (NSDictionary<NSString *, NSString *> *)cursorUndoProperties {
    return @{
        @"identifier"   : NSLocalizedString(@"cursor type", @"Undo change cursor type suffix"),
        @"frameDuration": NSLocalizedString(@"frame duration", @"Undo change cursor frame duraiton suffix"),
        @"frameCount"   : NSLocalizedString(@"frame count", @"Undo change cursor frame count suffix"),
        @"size"         : NSLocalizedString(@"dimensions", @"Undo change cursor image dimensions suffix"),
        @"hotSpot"      : NSLocalizedString(@"hotspot", @"Undo change cursor hotspot suffix"),
        @"cursorRep100" : NSLocalizedString(@"1x Representation", @"Undo change cursor 1x rep suffix"),
        @"cursorRep200" : NSLocalizedString(@"2x Rep", "Undo change cursor 2x rep suffix"),
        @"cursorRep500" : NSLocalizedString(@"2x Rep", "Undo change cursor 5x rep suffix"),
        @"cursorRep1000": NSLocalizedString(@"2x Rep", "Undo change cursor 10x rep suffix")
    };
}

+ (MACCursorLibrary *)cursorLibraryWithContentsOfFile:(NSString *)path {
    return [[MACCursorLibrary alloc] initWithContentsOfFile:path];
}

+ (MACCursorLibrary *)cursorLibraryWithContentsOfURL:(NSURL *)URL {
    return [[MACCursorLibrary alloc] initWithContentsOfURL:URL];
}

+ (MACCursorLibrary *)cursorLibraryWithDictionary:(NSDictionary *)dictionary {
    return [[MACCursorLibrary alloc] initWithDictionary:dictionary];
}

+ (MACCursorLibrary *)cursorLibraryWithCursors:(NSSet *)cursors {
    return [[MACCursorLibrary alloc] initWithCursors:cursors];
}

+ (NSString *)sanitizeName:(NSString *)name {
    NSString *sanitized = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
    sanitized = [sanitized stringByReplacingOccurrencesOfString:@"/" withString:@""];
    sanitized = [sanitized stringByReplacingOccurrencesOfString:@":" withString:@""];
    if (sanitized.length == 0) sanitized = @"Unnamed";
    return sanitized;
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    return [self initWithContentsOfURL:[NSURL fileURLWithPath:path]];
}

- (instancetype)initWithContentsOfURL:(NSURL *)URL {
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:URL];
    if ((self = [self initWithDictionary:dictionary]))
        self.fileURL = URL;
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [self init])) {
        if (![self _readFromDictionary:dictionary]) {
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithCursors:(NSSet *)cursors {
    if ((self = [self init])) {
        self.cursors = cursors.mutableCopy;
    }

    return self;
}

- (instancetype)init {
    if ((self = [super init])) {
        self.undoManager = [[NSUndoManager alloc] init];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        __weak typeof(self) weakSelf = self;
        id ob1 = [center addObserverForName:NSUndoManagerDidCloseUndoGroupNotification object:self.undoManager queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf updateChangeCount:NSChangeDone];
        }];

        id ob2 = [center addObserverForName:NSUndoManagerDidUndoChangeNotification object:self.undoManager queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf updateChangeCount:NSChangeUndone];
        }];

        id ob3 = [center addObserverForName:NSUndoManagerDidRedoChangeNotification object:self.undoManager queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf updateChangeCount:NSChangeRedone];
        }];

        self.observers = @[ob1, ob2, ob3];

        self.name           = NSLocalizedString(@"Unnamed", "Default New Cursor Theme Name");
        self.creator         = NSUserName();
        self.hiDPI          = NO;
        self.identifier     = [MACCursorLibrary sanitizeName:self.name];
        self.version        = @1.0;
        self.uuid           = [[NSUUID UUID] UUIDString];
        self.cursors        = [NSMutableSet set];
        self.changeCount    = 0;
        self.lastChangeCount = 0;
        [self startObservingProperties];
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
    MACCursorLibrary *lib = [[MACCursorLibrary allocWithZone:zone] initWithCursors:self.cursors];

    [lib.undoManager disableUndoRegistration];
    lib.name             = self.name;
    lib.creator           = self.creator;
    lib.hiDPI            = self.hiDPI;
    lib.version          = self.version;
    lib.identifier       = [MACCursorLibrary sanitizeName:self.name];
    lib.uuid             = [[NSUUID UUID] UUIDString];
    [lib.undoManager enableUndoRegistration];

    return lib;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"dirty"]) {
        keyPaths = [keyPaths setByAddingObjectsFromArray: @[@"changeCount", @"lastChangeCount"]];
    }
    return keyPaths;
}

- (BOOL)_readFromDictionary:(NSDictionary *)dictionary {
    if (!dictionary || !dictionary.count) {
        NSLog(@"cannot make library from empty dicitonary");
        return NO;
    }
    for (MACCursor *cursor in self.cursors) {
        [self stopObservingCursor:cursor];
    }

    self.cursors = [NSMutableSet set];
    [self.undoManager disableUndoRegistration];

    NSDictionary *cursorDicts = dictionary[MACCursorDictionaryCursorsKey];
    NSString *creator          = dictionary[MACCursorDictionaryCreatorKey];
    NSNumber *hiDPI           = dictionary[MACCursorDictionaryHiDPIKey];
    NSString *identifier      = dictionary[MACCursorDictionaryIdentifierKey];
    NSString *themeName        = dictionary[MACCursorDictionaryThemeNameKey];
    NSNumber *themeVersion     = dictionary[MACCursorDictionaryThemeVersionKey];
    NSString *uuidStr          = dictionary[MACCursorDictionaryUUIDKey];

    self.name       = themeName;
    self.version    = themeVersion;
    self.creator     = creator;
    self.identifier = identifier;
    self.hiDPI      = hiDPI.boolValue;

    if (!self.identifier) {
        [self.undoManager enableUndoRegistration];
        NSLog(@"cannot make library from dictionary with no identifier");
        return NO;
    }

    if (!uuidStr.length) {
        [self.undoManager enableUndoRegistration];
        NSLog(@"cannot make library from dictionary with no UUID");
        return NO;
    }

    self.uuid = uuidStr;

    [self.cursors removeAllObjects];
    [self addCursorsFromDictionary:cursorDicts];

    [self.undoManager enableUndoRegistration];
    return YES;
}

- (void)dealloc {
    [self stopObservingProperties];
    for (MACCursor *cursor in self.cursors) {
        [self stopObservingCursor:cursor];
    }

    for (id observer in self.observers) {
        [NSNotificationCenter.defaultCenter removeObserver:observer];
    }
}

const char MACCursorLibraryPropertiesContext;
- (void)startObservingProperties {
    for (NSString *key in self.class.undoProperties) {
        [self addObserver:self forKeyPath:key options:NSKeyValueObservingOptionOld context:(void*)&MACCursorLibraryPropertiesContext];
    }
}

- (void)stopObservingProperties {
    for (NSString *key in self.class.undoProperties) {
        [self removeObserver:self forKeyPath:key context:(void *)&MACCursorLibraryPropertiesContext];
    }
}

const char MACCursorPropertiesContext;
- (void)startObservingCursor:(MACCursor *)cursor {
    for (NSString *key in self.class.cursorUndoProperties) {
        [cursor addObserver:self forKeyPath:key options:NSKeyValueObservingOptionOld context:(void *)&MACCursorPropertiesContext];
    }
}

- (void)stopObservingCursor:(MACCursor *)cursor {
    for (NSString *key in self.class.cursorUndoProperties) {
        [cursor removeObserver:self forKeyPath:key context:(void *)&MACCursorPropertiesContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == &MACCursorLibraryPropertiesContext || context == &MACCursorPropertiesContext) {
        NSString *decamelized = NULL;
        if (context == &MACCursorLibraryPropertiesContext) {
            decamelized = [self.class undoProperties][keyPath];
        } else {
            decamelized = [self.class cursorUndoProperties][keyPath];
        }

        id oldValue = change[NSKeyValueChangeOldKey];
        if ([oldValue isKindOfClass:[NSNull class]])
            oldValue = nil;

        [[self.undoManager prepareWithInvocationTarget: object] setValue:oldValue forKeyPath:keyPath];

        if (!self.undoManager.isUndoing) {
            [self.undoManager setActionName:[[NSLocalizedString(@"Change ", "Undo Change Prefix") stringByAppendingString:decamelized] capitalizedString]];
        }

        if ([keyPath isEqualToString:@"identifier"]) {
            self.oldIdentifier = oldValue;
        }
    }
}

- (void)addCursorsFromDictionary:(NSDictionary *)cursorDicts {
    for (NSString *key in cursorDicts.allKeys) {
        NSDictionary *cursorDictionary = [cursorDicts objectForKey:key];
        MACCursor *cursor = [MACCursor cursorWithDictionary:cursorDictionary];
        if (!cursor)
            continue;
        cursor.identifier = key;
        [self addCursor: cursor];
    }
}

- (NSSet *)cursorsWithIdentifier:(NSString *)identifier {
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
    return [self.cursors filteredSetUsingPredicate:filter];
}

- (void)addCursor:(MACCursor *)cursor {
    if ([self.cursors containsObject:cursor]) {
        return;
    }

    NSSet *change = [NSSet setWithObject:cursor];

    [[self.undoManager prepareWithInvocationTarget:self] removeCursor:cursor];
    if (!self.undoManager.isUndoing) {
        [self.undoManager setActionName:NSLocalizedString(@"Add Cursor", "Add Cursor Undo Title")];
    }

    [self willChangeValueForKey:@"cursors" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];
    [self.cursors addObject:cursor];
    [self startObservingCursor:cursor];
    [self didChangeValueForKey:@"cursors" withSetMutation:NSKeyValueUnionSetMutation usingObjects:change];
}

- (void)removeCursor:(MACCursor *)cursor {
    NSSet *change = [NSSet setWithObject:cursor];

    [[self.undoManager prepareWithInvocationTarget:self] addCursor:cursor];
    if (!self.undoManager.isUndoing) {
        [self.undoManager setActionName:NSLocalizedString(@"Remove Cursor", @"Remove Cursor Undo Title")];
    }

    [self willChangeValueForKey:@"cursors" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
    [self.cursors removeObject:cursor];
    [self stopObservingCursor:cursor];
    [self didChangeValueForKey:@"cursors" withSetMutation:NSKeyValueMinusSetMutation usingObjects:change];
}

- (void)removeCursorsWithIdentifier:(NSString *)identifier {
  for (MACCursor *cursor in [self cursorsWithIdentifier:identifier])
      [self removeCursor: cursor];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *drep = [NSMutableDictionary dictionary];

    drep[MACCursorDictionaryThemeNameKey]       = self.name;
    drep[MACCursorDictionaryThemeVersionKey]    = self.version;
    drep[MACCursorDictionaryCreatorKey]         = self.creator;
    drep[MACCursorDictionaryHiDPIKey]          = @(self.isHiDPI);
    drep[MACCursorDictionaryIdentifierKey]     = self.identifier;
    drep[MACCursorDictionaryUUIDKey]           = self.uuid;

    NSMutableDictionary *cursors = [NSMutableDictionary dictionary];
    for (MACCursor *cursor in self.cursors) {
        cursors[cursor.identifier] = [cursor dictionaryRepresentation];
    }

    drep[MACCursorDictionaryCursorsKey] = cursors;

    return drep;
}

- (BOOL)writeToFile:(NSString *)file atomically:(BOOL)atomically {
    return [self.dictionaryRepresentation writeToFile:file atomically:atomically];
}

- (NSError *)save {
    NSCountedSet *count  = [[NSCountedSet alloc] initWithArray:[self.cursors.allObjects valueForKey:@"identifier"]];
    NSMutableSet *duplicates = [NSMutableSet set];

    for (NSString *identifier in count) {
        if ([duplicates containsObject:identifier])
            continue;

        NSUInteger amount = [count countForObject:identifier];
        if (amount > 1)
            [duplicates addObject:nameForCursorIdentifier(identifier)];
    }

    if (duplicates.count > 0) {
        return [NSError errorWithDomain:MACErrorDomain code:MACErrorMultipleCursorIdentifiersCode userInfo:@{
                                                                                                           NSLocalizedDescriptionKey: NSLocalizedString(@"Save failed", @"New Cursor Theme Failure Title"),
                                                                                                           NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Multiple cursors with the name(s): %@ exist.", @"New Cursor Theme Failure Duplicate cursor name error"), duplicates] }];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:MACLibraryWillSaveNotificationName object:self];

    BOOL success = [self writeToFile:self.fileURL.path atomically:NO];
    if (success) {
        [self updateChangeCount:NSChangeCleared];
        [[NSNotificationCenter defaultCenter] postNotificationName:MACLibraryDidSaveNotificationName object:self];
        return nil;
    }
    return [NSError errorWithDomain:MACErrorDomain code:MACErrorWriteFailCode userInfo:@{
                                                                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Save failed", @"New Cursor Theme Failure Title"),
                                                                                       NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Error writing cursor theme to disk.", @"New Cursor Theme Failure Filesystem Error") }];
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    if (change == NSChangeDone || change == NSChangeRedone) {
        self.changeCount = self.changeCount + 1;
    } else if (change == NSChangeUndone && self.changeCount > 0) {
        self.changeCount = self.changeCount - 1;
    } else if (change == NSChangeCleared || change == NSChangeAutosaved) {
        self.lastChangeCount = self.changeCount;
    }
}

- (void)revertToSaved {
    while (self.isDirty) {
        [self.undoManager undo];
    }

    [self updateChangeCount:NSChangeCleared];
    [self.undoManager removeAllActions];
}

- (BOOL)isDirty {
    return (self.changeCount != self.lastChangeCount);
}

- (BOOL)isEqualTo:(MACCursorLibrary *)object {
    if (![object isKindOfClass:self.class]) {
        return NO;
    }

    return ([object.name isEqualToString:self.name] &&
            [object.creator isEqualToString:self.creator] &&
            [object.identifier isEqualToString:self.identifier] &&
            [object.version isEqualToNumber:self.version] &&
            object.isHiDPI == self.isHiDPI &&
            [object.cursors isEqualToSet:self.cursors]);
}

- (BOOL)isEqual:(id)object {
    return [self isEqualTo:object];
}

@end
