// Ask the system to draw our widget without its glass container.
//
// The extension cannot reach the host's layers, but it does hand Chrono one
// descriptor per widget, and the host renders from that descriptor. Flipping its
// private flags — background removable, transparent, clear style — is the only
// channel from inside the extension that changes how the Home Screen draws the
// container. That container is what still shows as a rounded rim.
//
// PRIVATE API. Internal TestFlight only: App Store review rejects this under
// guideline 2.5.1, and the descriptor class names are not covered by any contract,
// so they can change in any iOS release.
//
// Everything this file does is written to <App Group>/WidgetSimple/hook.log, which
// the app shows under Diagnostics. Without that the extension is a black box: a
// missing class and a flag the system ignores look exactly the same from outside.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// The private descriptor API, declared locally so the calls type-check.
@interface NSObject (WidgetDescriptorFlags)
- (NSArray *)widgetDescriptors;
- (void)setBackgroundRemovable:(BOOL)removable;
- (void)setTransparent:(BOOL)transparent;
- (void)setPreferredBackgroundStyle:(NSUInteger)style;
@end

typedef void (^DescriptorsCompletion)(id result);
typedef void (*GetAllDescriptorsIMP)(id self, SEL _cmd, DescriptorsCompletion completion);

static GetAllDescriptorsIMP OriginalGetAllDescriptors;
static BOOL DidDumpDescriptorShape;

/// Clear. The values are guesses from the reference app's behaviour; 0 is the
/// default style, so only a non-zero value can change anything.
static const NSUInteger kClearBackgroundStyle = 1;

#pragma mark - Log

/// Appends one line to the App Group log the app reads. Silently does nothing
/// when the App Group is unavailable.
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

#pragma mark - Descriptor shape

/// The descriptor's own properties that could matter, so the log says what this
/// iOS version actually offers instead of what the reference app used.
static NSString *DescribeDescriptor(id descriptor)
{
    Class cls = object_getClass(descriptor);
    NSMutableArray<NSString *> *interesting = [NSMutableArray array];

    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = @(property_getName(properties[i]));
        NSArray<NSString *> *needles = @[@"background", @"transparent", @"style", @"glass", @"corner", @"vibran"];
        for (NSString *needle in needles) {
            if ([name rangeOfString:needle options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [interesting addObject:name];
                break;
            }
        }
    }
    free(properties);

    return [NSString stringWithFormat:@"%s %@", class_getName(cls),
            interesting.count ? [interesting componentsJoinedByString:@","] : @"(no matching properties)"];
}

static void ApplyTransparentFlags(NSArray *descriptors)
{
    for (id descriptor in descriptors) {
        if (!DidDumpDescriptorShape) {
            DidDumpDescriptorShape = YES;
            HookLog(@"descriptor shape: %@", DescribeDescriptor(descriptor));
            HookLog(@"responds background=%@ transparent=%@ style=%@",
                    [descriptor respondsToSelector:@selector(setBackgroundRemovable:)] ? @"yes" : @"no",
                    [descriptor respondsToSelector:@selector(setTransparent:)] ? @"yes" : @"no",
                    [descriptor respondsToSelector:@selector(setPreferredBackgroundStyle:)] ? @"yes" : @"no");
        }

        @try {
            if ([descriptor respondsToSelector:@selector(setBackgroundRemovable:)]) {
                [descriptor setBackgroundRemovable:YES];
            }
            if ([descriptor respondsToSelector:@selector(setTransparent:)]) {
                [descriptor setTransparent:YES];
            }
            if ([descriptor respondsToSelector:@selector(setPreferredBackgroundStyle:)]) {
                [descriptor setPreferredBackgroundStyle:kClearBackgroundStyle];
            }
        } @catch (NSException *exception) {
            HookLog(@"mutation threw: %@", exception.reason);
        }
    }
}

static void HookedGetAllDescriptors(id self, SEL _cmd, DescriptorsCompletion completion)
{
    HookLog(@"descriptor fetch called");
    OriginalGetAllDescriptors(self, _cmd, ^(id result) {
        @try {
            NSArray *descriptors = nil;
            if ([result respondsToSelector:@selector(widgetDescriptors)]) {
                descriptors = [result widgetDescriptors];
            } else {
                descriptors = [result valueForKey:@"widgetDescriptors"];
            }
            HookLog(@"fetch returned %lu descriptor(s)", (unsigned long)descriptors.count);
            ApplyTransparentFlags(descriptors);
        } @catch (NSException *exception) {
            HookLog(@"fetch inspection threw: %@", exception.reason);
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
        HookLog(@"install: %s not found on %s", sel_getName(selector), class_getName(server));
        return;
    }

    OriginalGetAllDescriptors = (GetAllDescriptorsIMP)method_getImplementation(method);
    if (OriginalGetAllDescriptors == NULL) {
        HookLog(@"install: original implementation was NULL");
        return;
    }
    method_setImplementation(method, (IMP)HookedGetAllDescriptors);
    HookLog(@"install: hooked %s", class_getName(server));
}
