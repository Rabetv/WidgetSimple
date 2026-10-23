// Compiled into every build, App Store included. That is a deliberate choice:
// the private selectors are plainly present in the binary, and App Review can
// reject this under guideline 2.5.1. Scripts/audit-appstore.sh reports it.

// Ask the system to draw our widget without its glass container.
//
// The extension cannot reach the host's layers, but it hands Chrono one descriptor
// per widget, and the host renders from that descriptor. Flipping its private flags
// — background removable, transparent, clear style — is the only channel from
// inside the extension that changes how the Home Screen draws the container.
//
// PRIVATE API. Internal TestFlight only. App Store review rejects this under
// guideline 2.5.1, and none of these class names are covered by a contract.
//
// What the earlier builds established:
//   * the swizzle installs and the descriptor fetch runs;
//   * `DescriptorFetchResult` has no Objective-C accessor and no KVC, only Swift
//     stored properties `widgetDescriptors`, `controlDescriptors`,
//     `activityDescriptors` with empty type encodings;
//   * so the arrays can be reached neither by selector nor by KVC, and poking the
//     ivar of a Swift array is a raw storage pointer, not an NSArray.
//
// Hence the archive round-trip: encode the result, decode it into a plain shim,
// mutate the descriptors as ordinary Objective-C objects there, encode the shim and
// let `DescriptorFetchResult.init(coder:)` rebuild itself from those bytes. Any
// failure falls back to the original object, so the widget can only ever be as
// broken as before — never worse.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// The private descriptor API, declared locally so calls type-check where it exists.
@interface NSObject (WidgetDescriptorFlags)
- (void)setBackgroundRemovable:(BOOL)removable;
- (void)setTransparent:(BOOL)transparent;
- (void)setPreferredBackgroundStyle:(NSUInteger)style;
- (BOOL)backgroundRemovable;
- (BOOL)transparent;
- (NSUInteger)preferredBackgroundStyle;
@end

typedef void (^DescriptorsCompletion)(id result);
typedef void (*GetAllDescriptorsIMP)(id self, SEL _cmd, DescriptorsCompletion completion);

static GetAllDescriptorsIMP OriginalGetAllDescriptors;
static BOOL DidRewrite;

/// Clear. 0 is the default style, so only a non-zero value can change anything.
static const NSUInteger kClearBackgroundStyle = 1;

#pragma mark - Log

static void HookLog(NSString *format, ...)
{
    NSString *group = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppGroupID"];
    if (group.length == 0 || [group containsString:@"$("]) { return; }
    NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:group];
    if (container == nil) { return; }

    NSURL *directory = [container URLByAppendingPathComponent:@"WidgetSimple" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:directory
                             withIntermediateDirectories:YES
                                              attributes:nil
                                                   error:nil];
    NSURL *file = [directory URLByAppendingPathComponent:@"hook.log"];

    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);

    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"HH:mm:ss.SSS";
    });
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:[NSDate date]], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:file.path];
    if (handle == nil) {
        [data writeToURL:file atomically:YES];
    } else {
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
        } @finally {
            [handle closeFile];
        }
    }
}

#pragma mark - Shim

/// Everything a descriptor can contain while it is being decoded. A missing class
/// here makes the unarchive throw, so the list is deliberately generous.
static NSSet *AllowedClasses(void)
{
    NSMutableSet *classes = [NSMutableSet setWithObjects:
        [NSArray class], [NSMutableDictionary class], [NSDictionary class],
        [NSString class], [NSNumber class], [NSData class], [NSDate class],
        [NSUUID class], [NSNull class], nil];
    NSArray<NSString *> *names = @[
        @"CHSBaseDescriptor", @"CHSWidgetDescriptor", @"CHSControlDescriptor",
        @"CHSActivityDescriptor", @"CHSWidget", @"CHSWidgetConfiguration",
        @"CHSExtensionIdentity", @"CHSIntentReference", @"CHSWidgetMetrics",
        @"CHSWidgetRenderScheme", @"CHSWidgetVisibility", @"INIntent",
    ];
    for (NSString *name in names) {
        Class cls = objc_lookUpClass(name.UTF8String);
        if (cls) { [classes addObject:cls]; }
    }
    return classes;
}

/// A plain Objective-C stand-in for the Swift result object.
@interface WSDescriptorShim : NSObject <NSSecureCoding>
@property (nonatomic, strong) NSArray *widgetDescriptors;
@property (nonatomic, strong) NSArray *controlDescriptors;
@property (nonatomic, strong) NSArray *activityDescriptors;
@end

@implementation WSDescriptorShim

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSSet *allowed = AllowedClasses();
        _widgetDescriptors = [coder decodeObjectOfClasses:allowed forKey:@"widgetDescriptors"];
        _controlDescriptors = [coder decodeObjectOfClasses:allowed forKey:@"controlDescriptors"];
        _activityDescriptors = [coder decodeObjectOfClasses:allowed forKey:@"activityDescriptors"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_widgetDescriptors forKey:@"widgetDescriptors"];
    [coder encodeObject:_controlDescriptors forKey:@"controlDescriptors"];
    [coder encodeObject:_activityDescriptors forKey:@"activityDescriptors"];
}

@end

#pragma mark - Flags

static BOOL DidDumpDescriptorShape;

/// Properties, ivars and setters of the descriptor that could control the container.
static void DumpDescriptorShape(id descriptor)
{
    Class cls = object_getClass(descriptor);

    NSMutableArray<NSString *> *properties = [NSMutableArray array];
    unsigned int propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(cls, &propertyCount);
    for (unsigned int i = 0; i < propertyCount; i++) {
        [properties addObject:@(property_getName(propertyList[i]))];
    }
    free(propertyList);

    NSMutableArray<NSString *> *ivars = [NSMutableArray array];
    unsigned int ivarCount = 0;
    Ivar *ivarList = class_copyIvarList(cls, &ivarCount);
    for (unsigned int i = 0; i < ivarCount; i++) {
        const char *name = ivar_getName(ivarList[i]);
        if (name) { [ivars addObject:@(name)]; }
    }
    free(ivarList);

    NSMutableArray<NSString *> *methods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(cls, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        NSString *name = NSStringFromSelector(method_getName(methodList[i]));
        NSArray *needles = @[@"ackground", @"ransparent", @"tyle", @"lass", @"order", @"ontainer"];
        for (NSString *needle in needles) {
            if ([name rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [methods addObject:name];
                break;
            }
        }
    }
    free(methodList);

    HookLog(@"shape %s", class_getName(cls));
    HookLog(@"  properties: %@", properties.count ? [properties componentsJoinedByString:@","] : @"(none)");
    HookLog(@"  ivars: %@", ivars.count ? [ivars componentsJoinedByString:@","] : @"(none)");
    HookLog(@"  methods: %@", methods.count ? [methods componentsJoinedByString:@" "] : @"(none)");
}

static NSArray *DescriptorsWithFlags(NSArray *descriptors)
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:descriptors.count];
    for (id descriptor in descriptors) {
        id target = descriptor;
        @try {
            if ([descriptor respondsToSelector:@selector(mutableCopyWithZone:)]) {
                id copy = [descriptor mutableCopy];
                if (copy) { target = copy; }
            }
        } @catch (NSException *exception) {
            HookLog(@"mutableCopy threw: %@", exception.reason);
        }

        if (!DidDumpDescriptorShape) {
            DidDumpDescriptorShape = YES;
            DumpDescriptorShape(target);
        }

        BOOL background = [target respondsToSelector:@selector(setBackgroundRemovable:)];
        BOOL transparent = [target respondsToSelector:@selector(setTransparent:)];
        BOOL style = [target respondsToSelector:@selector(setPreferredBackgroundStyle:)];
        HookLog(@"descriptor %s bg=%@ tr=%@ st=%@",
                object_getClassName(target),
                background ? @"y" : @"n", transparent ? @"y" : @"n", style ? @"y" : @"n");

        @try {
            if (background) { [target setBackgroundRemovable:YES]; }
            if (transparent) { [target setTransparent:YES]; }
            if (style) { [target setPreferredBackgroundStyle:kClearBackgroundStyle]; }
        } @catch (NSException *exception) {
            HookLog(@"mutation threw: %@", exception.reason);
        }

        // Did the setters take? A setter that answers but ignores the value is the
        // difference between "flag ignored by the host" and "nothing was written".
        @try {
            if (background && [target respondsToSelector:@selector(backgroundRemovable)]) {
                HookLog(@"  readback bg=%d", (int)[target backgroundRemovable]);
            }
            if (transparent && [target respondsToSelector:@selector(transparent)]) {
                HookLog(@"  readback tr=%d", (int)[target transparent]);
            }
            if (style && [target respondsToSelector:@selector(preferredBackgroundStyle)]) {
                HookLog(@"  readback st=%lu", (unsigned long)[target preferredBackgroundStyle]);
            }
        } @catch (NSException *exception) {
            HookLog(@"readback threw: %@", exception.reason);
        }
        [result addObject:target];
    }
    return result;
}

#pragma mark - Round-trip

static id RewrittenResult(id original)
{
    if (![original respondsToSelector:@selector(encodeWithCoder:)]) {
        HookLog(@"result does not encode");
        return nil;
    }

    NSData *data = nil;
    @try {
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [original encodeWithCoder:archiver];
        [archiver finishEncoding];
        data = archiver.encodedData;
    } @catch (NSException *exception) {
        HookLog(@"encode threw: %@", exception.reason);
        return nil;
    }
    if (data.length == 0) {
        HookLog(@"encode produced no data");
        return nil;
    }

    WSDescriptorShim *shim = nil;
    @try {
        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
        if (unarchiver == nil) {
            HookLog(@"unarchive setup failed: %@", error.localizedDescription);
            return nil;
        }
        unarchiver.requiresSecureCoding = NO;
        shim = [[WSDescriptorShim alloc] initWithCoder:unarchiver];
        [unarchiver finishDecoding];
    } @catch (NSException *exception) {
        HookLog(@"decode threw: %@", exception.reason);
        return nil;
    }

    HookLog(@"decoded widgets=%lu controls=%lu activities=%lu",
            (unsigned long)shim.widgetDescriptors.count,
            (unsigned long)shim.controlDescriptors.count,
            (unsigned long)shim.activityDescriptors.count);
    if (shim.widgetDescriptors.count == 0) {
        return nil;
    }

    shim.widgetDescriptors = DescriptorsWithFlags(shim.widgetDescriptors);

    Class resultClass = NSClassFromString(@"WidgetKit.DescriptorFetchResult")
        ?: NSClassFromString(@"_TtC9WidgetKit21DescriptorFetchResult");
    if (resultClass == Nil) {
        HookLog(@"result class not found by name");
        return nil;
    }

    @try {
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        [shim encodeWithCoder:archiver];
        [archiver finishEncoding];

        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:&error];
        if (unarchiver == nil) {
            HookLog(@"rebuild setup failed: %@", error.localizedDescription);
            return nil;
        }
        unarchiver.requiresSecureCoding = NO;
        id rebuilt = [[resultClass alloc] initWithCoder:unarchiver];
        [unarchiver finishDecoding];
        HookLog(@"rebuilt result: %@", rebuilt ? NSStringFromClass([rebuilt class]) : @"nil");
        return rebuilt;
    } @catch (NSException *exception) {
        HookLog(@"rebuild threw: %@", exception.reason);
        return nil;
    }
}

static void HookedGetAllDescriptors(id self, SEL _cmd, DescriptorsCompletion completion)
{
    OriginalGetAllDescriptors(self, _cmd, ^(id result) {
        id replacement = result;
        if (!DidRewrite) {
            DidRewrite = YES;
            @try {
                id rewritten = RewrittenResult(result);
                if (rewritten) { replacement = rewritten; }
            } @catch (NSException *exception) {
                HookLog(@"rewrite threw: %@", exception.reason);
            }
        }
        completion(replacement);
    });
}

__attribute__((constructor)) static void InstallWidgetDescriptorHook(void)
{
    Class server = NSClassFromString(@"_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
    if (server == Nil) {
        HookLog(@"install: XPC server class not found");
        return;
    }
    SEL selector = NSSelectorFromString(@"getAllCurrentDescriptorsWithCompletion:");
    Method method = class_getInstanceMethod(server, selector);
    if (method == NULL) {
        HookLog(@"install: selector not found");
        return;
    }
    OriginalGetAllDescriptors = (GetAllDescriptorsIMP)method_getImplementation(method);
    if (OriginalGetAllDescriptors == NULL) {
        HookLog(@"install: original implementation was NULL");
        return;
    }
    method_setImplementation(method, (IMP)HookedGetAllDescriptors);
    HookLog(@"install: hooked");
}