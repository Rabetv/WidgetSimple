// Ask the system to draw our widget without its glass container.
//
// The extension cannot reach the host's layers, but it hands Chrono one descriptor
// per widget, and the host renders from that descriptor. Flipping its private flags
// — background removable, transparent, clear style — is the only channel from
// inside the extension that changes how the Home Screen draws the container.
//
// PRIVATE API. Internal TestFlight only: App Store review rejects this under
// guideline 2.5.1, and the descriptor class names are not covered by any contract.
//
// What build 13 established: the swizzle installs and the fetch runs, but
// `DescriptorFetchResult` is a Swift class with no Objective-C `widgetDescriptors`,
// so KVC throws. The descriptors therefore have to be read from the instance
// variable directly, which is what this version does, and it logs the shape it
// finds so the next step is chosen from data instead of guesswork.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// The private descriptor API, declared locally so calls type-check where it exists.
@interface NSObject (WidgetDescriptorFlags)
- (void)setBackgroundRemovable:(BOOL)removable;
- (void)setTransparent:(BOOL)transparent;
- (void)setPreferredBackgroundStyle:(NSUInteger)style;
@end

typedef void (^DescriptorsCompletion)(id result);
typedef void (*GetAllDescriptorsIMP)(id self, SEL _cmd, DescriptorsCompletion completion);

static GetAllDescriptorsIMP OriginalGetAllDescriptors;
static BOOL DidDumpShape;

/// Clear. 0 is the default style, so only a non-zero value can change anything.
static const NSUInteger kClearBackgroundStyle = 1;

#pragma mark - Log

/// Appends one line to the App Group log the app reads.
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

#pragma mark - Shape

static NSString *DescribeIvars(Class cls)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = ivar_getName(ivars[i]);
        if (name) { [names addObject:@(name)]; }
    }
    free(ivars);
    return names.count ? [names componentsJoinedByString:@","] : @"(none)";
}

static NSString *DescribeDescriptorsAPI(Class cls)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromSelector(method_getName(methods[i]));
        if ([name rangeOfString:@"descriptor" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [names addObject:name];
        }
    }
    free(methods);
    return names.count ? [names componentsJoinedByString:@" "] : @"(none)";
}

/// True only when the class really descends from NSArray. Checked through the C
/// runtime: messaging an ivar that turns out to be Swift storage would crash.
static BOOL IsNSArrayClass(Class cls)
{
    Class array = (Class)objc_getClass("NSArray");
    for (Class current = cls; current != Nil; current = class_getSuperclass(current)) {
        if (current == array) { return YES; }
    }
    return NO;
}

/// The widget descriptors, read from whichever object-type ivar carries them.
/// Inspection only: nothing is messaged unless the class check says it is safe.
static NSArray *DescriptorsFromResult(id result)
{
    Class cls = object_getClass(result);
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList(cls, &count);
    NSArray *found = nil;
    for (unsigned int i = 0; i < count; i++) {
        const char *rawName = ivar_getName(ivars[i]);
        const char *type = ivar_getTypeEncoding(ivars[i]);
        if (rawName == NULL || type == NULL) { continue; }

        id value = (type[0] == '@') ? object_getIvar(result, ivars[i]) : nil;
        const char *valueClass = value ? object_getClassName(value) : "nil";
        HookLog(@"ivar %s type=%s value=%s", rawName, type, valueClass);

        NSString *name = @(rawName);
        if (value != nil &&
            [name rangeOfString:@"widget" options:NSCaseInsensitiveSearch].location != NSNotFound &&
            IsNSArrayClass(object_getClass(value))) {
            found = value;
        }
    }
    free(ivars);
    return found;
}

static void ApplyTransparentFlags(NSArray *descriptors)
{
    HookLog(@"applying to %lu descriptor(s)", (unsigned long)descriptors.count);
    for (id descriptor in descriptors) {
        Class cls = object_getClass(descriptor);
        BOOL background = [descriptor respondsToSelector:@selector(setBackgroundRemovable:)];
        BOOL transparent = [descriptor respondsToSelector:@selector(setTransparent:)];
        BOOL style = [descriptor respondsToSelector:@selector(setPreferredBackgroundStyle:)];
        HookLog(@"descriptor %s background=%@ transparent=%@ style=%@",
                class_getName(cls),
                background ? @"y" : @"n", transparent ? @"y" : @"n", style ? @"y" : @"n");

        @try {
            if (background) { [descriptor setBackgroundRemovable:YES]; }
            if (transparent) { [descriptor setTransparent:YES]; }
            if (style) { [descriptor setPreferredBackgroundStyle:kClearBackgroundStyle]; }
        } @catch (NSException *exception) {
            HookLog(@"mutation threw: %@", exception.reason);
        }
    }
}

static void HookedGetAllDescriptors(id self, SEL _cmd, DescriptorsCompletion completion)
{
    OriginalGetAllDescriptors(self, _cmd, ^(id result) {
        @try {
            Class cls = object_getClass(result);
            if (!DidDumpShape) {
                DidDumpShape = YES;
                HookLog(@"result class %s", class_getName(cls));
                HookLog(@"result ivars: %@", DescribeIvars(cls));
                HookLog(@"result descriptor API: %@", DescribeDescriptorsAPI(cls));
            }
            NSArray *descriptors = DescriptorsFromResult(result);
            if (descriptors.count == 0) {
                HookLog(@"no widget descriptors found");
            } else {
                ApplyTransparentFlags(descriptors);
            }
        } @catch (NSException *exception) {
            HookLog(@"inspection threw: %@", exception.reason);
        }
        completion(result);
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
