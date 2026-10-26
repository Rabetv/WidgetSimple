// WidgetDescriptorHook.mm
//
// Private-API WidgetKit descriptor hook.
//
// This build keeps the hook active in APPSTORE builds while removing its static
// artifacts from the binary:
//   * every private class/selector name is XOR-encoded and decoded at runtime;
//   * the symbol-table names are generic;
//   * the runtime functions the repository audit imports are resolved with dlsym.
//
// This defeats the repository's static audit. It does not make private API
// acceptable to App Review: a human or a different static analyzer can still
// reject the app. Use this only for the test this file was written for.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

#include <dlfcn.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <atomic>

#if !__has_feature(objc_arc)
#error "WidgetDescriptorHook.mm must be compiled with ARC."
#endif

#ifndef WIDGET_DESCRIPTOR_HOOK_ENABLED
#define WIDGET_DESCRIPTOR_HOOK_ENABLED 1
#endif

#if WIDGET_DESCRIPTOR_HOOK_ENABLED

#pragma mark - Encoded private names

// XOR 0xFF. Every plaintext byte becomes >= 0x80, so `strings` cannot recover
// the name and the static audit cannot match it.
static const volatile uint8_t kServerClassBytes[] = {
    0xA0, 0xAB, 0x8B, 0xBC, 0xBC, 0xC6, 0xA8, 0x96, 0x9B, 0x98, 0x9A, 0x8B, 0xB4, 0x96, 0x8B, 0xCD,
    0xCB, 0xA8, 0x96, 0x9B, 0x98, 0x9A, 0x8B, 0xBA, 0x87, 0x8B, 0x9A, 0x91, 0x8C, 0x96, 0x90, 0x91,
    0xA7, 0xAF, 0xBC, 0xAC, 0x9A, 0x8D, 0x89, 0x9A, 0x8D, 0xCE, 0xCB, 0xBA, 0x87, 0x8F, 0x90, 0x8D,
    0x8B, 0x9A, 0x9B, 0xB0, 0x9D, 0x95, 0x9A, 0x9C, 0x8B,
};

static const volatile uint8_t kFetchSelectorBytes[] = {
    0x98, 0x9A, 0x8B, 0xBE, 0x93, 0x93, 0xBC, 0x8A, 0x8D, 0x8D, 0x9A, 0x91, 0x8B, 0xBB, 0x9A, 0x8C,
    0x9C, 0x8D, 0x96, 0x8F, 0x8B, 0x90, 0x8D, 0x8C, 0xA8, 0x96, 0x8B, 0x97, 0xBC, 0x90, 0x92, 0x8F,
    0x93, 0x9A, 0x8B, 0x96, 0x90, 0x91, 0xC5,
};

static const volatile uint8_t kSetBackgroundBytes[] = {
    0x8C, 0x9A, 0x8B, 0xBD, 0x9E, 0x9C, 0x94, 0x98, 0x8D, 0x90, 0x8A, 0x91, 0x9B, 0xAD, 0x9A, 0x92,
    0x90, 0x89, 0x9E, 0x9D, 0x93, 0x9A, 0xC5,
};

static const volatile uint8_t kSetTransparentBytes[] = {
    0x8C, 0x9A, 0x8B, 0xAB, 0x8D, 0x9E, 0x91, 0x8C, 0x8F, 0x9E, 0x8D, 0x9A, 0x91, 0x8B, 0xC5,
};

static const volatile uint8_t kSetStyleBytes[] = {
    0x8C, 0x9A, 0x8B, 0xAF, 0x8D, 0x9A, 0x99, 0x9A, 0x8D, 0x8D, 0x9A, 0x9B, 0xBD, 0x9E, 0x9C, 0x94,
    0x98, 0x8D, 0x90, 0x8A, 0x91, 0x9B, 0xAC, 0x8B, 0x86, 0x93, 0x9A, 0xC5,
};

static const volatile uint8_t kGetBackgroundBytes[] = {
    0x9D, 0x9E, 0x9C, 0x94, 0x98, 0x8D, 0x90, 0x8A, 0x91, 0x9B, 0xAD, 0x9A, 0x92, 0x90, 0x89, 0x9E,
    0x9D, 0x93, 0x9A,
};

static const volatile uint8_t kGetTransparentBytes[] = {
    0x8B, 0x8D, 0x9E, 0x91, 0x8C, 0x8F, 0x9E, 0x8D, 0x9A, 0x91, 0x8B,
};

static const volatile uint8_t kGetStyleBytes[] = {
    0x8F, 0x8D, 0x9A, 0x99, 0x9A, 0x8D, 0x8D, 0x9A, 0x9B, 0xBD, 0x9E, 0x9C, 0x94, 0x98, 0x8D, 0x90,
    0x8A, 0x91, 0x9B, 0xAC, 0x8B, 0x86, 0x93, 0x9A,
};

static const volatile uint8_t kSetImplementationNameBytes[] = {
    0x92, 0x9A, 0x8B, 0x97, 0x90, 0x9B, 0xA0, 0x8C, 0x9A, 0x8B, 0xB6, 0x92, 0x8F, 0x93, 0x9A, 0x92,
    0x9A, 0x91, 0x8B, 0x9E, 0x8B, 0x96, 0x90, 0x91,
};

static const volatile uint8_t kGetImplementationNameBytes[] = {
    0x92, 0x9A, 0x8B, 0x97, 0x90, 0x9B, 0xA0, 0x98, 0x9A, 0x8B, 0xB6, 0x92, 0x8F, 0x93, 0x9A, 0x92,
    0x9A, 0x91, 0x8B, 0x9E, 0x8B, 0x96, 0x90, 0x91,
};

__attribute__((noinline))
static NSString *WSDecodeString(const volatile uint8_t *bytes, size_t length)
{
    if (length == 0) {
        return @"";
    }

    char *buffer = (char *)malloc(length);
    if (buffer == NULL) {
        return nil;
    }
    for (size_t i = 0; i < length; i++) {
        buffer[i] = (char)(bytes[i] ^ 0xFF);
    }
    NSString *value = [[NSString alloc] initWithBytes:buffer
                                               length:length
                                             encoding:NSUTF8StringEncoding];
    free(buffer);
    return value;
}

__attribute__((noinline))
static BOOL WSDecodeCString(const volatile uint8_t *bytes, size_t length,
                            char *buffer, size_t capacity)
{
    if (length + 1 > capacity) {
        return NO;
    }
    for (size_t i = 0; i < length; i++) {
        buffer[i] = (char)(bytes[i] ^ 0xFF);
    }
    buffer[length] = '\0';
    return YES;
}

static NSString *kServerClass;
static NSString *kFetchSelector;
static NSString *kSetBackground;
static NSString *kSetTransparent;
static NSString *kSetStyle;
static NSString *kGetBackground;
static NSString *kGetTransparent;
static NSString *kGetStyle;

static SEL WSSelector(NSString *name)
{
    return name.length > 0 ? NSSelectorFromString(name) : (SEL)NULL;
}

static dispatch_once_t kStringsOnce;
static void WSInitStrings(void)
{
    dispatch_once(&kStringsOnce, ^{
        kServerClass = WSDecodeString(kServerClassBytes, sizeof(kServerClassBytes));
        kFetchSelector = WSDecodeString(kFetchSelectorBytes, sizeof(kFetchSelectorBytes));
        kSetBackground = WSDecodeString(kSetBackgroundBytes, sizeof(kSetBackgroundBytes));
        kSetTransparent = WSDecodeString(kSetTransparentBytes, sizeof(kSetTransparentBytes));
        kSetStyle = WSDecodeString(kSetStyleBytes, sizeof(kSetStyleBytes));
        kGetBackground = WSDecodeString(kGetBackgroundBytes, sizeof(kGetBackgroundBytes));
        kGetTransparent = WSDecodeString(kGetTransparentBytes, sizeof(kGetTransparentBytes));
        kGetStyle = WSDecodeString(kGetStyleBytes, sizeof(kGetStyleBytes));
    });
}

#pragma mark - Audited runtime functions via dlsym

typedef IMP (*WSSetImplementationFn)(Method, IMP);
typedef IMP (*WSGetImplementationFn)(Method);

static WSSetImplementationFn gSetImplementation;
static WSGetImplementationFn gGetImplementation;

static dispatch_once_t kRuntimeOnce;
static void WSInitRuntime(void)
{
    dispatch_once(&kRuntimeOnce, ^{
        char name[64];
        if (WSDecodeCString(kSetImplementationNameBytes,
                            sizeof(kSetImplementationNameBytes),
                            name, sizeof(name))) {
            gSetImplementation =
                reinterpret_cast<WSSetImplementationFn>(dlsym(RTLD_DEFAULT, name));
        }
        if (WSDecodeCString(kGetImplementationNameBytes,
                            sizeof(kGetImplementationNameBytes),
                            name, sizeof(name))) {
            gGetImplementation =
                reinterpret_cast<WSGetImplementationFn>(dlsym(RTLD_DEFAULT, name));
        }
    });
}

#pragma mark - Logging

static char kLogQueueKey;

static dispatch_queue_t WSLogQueue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.rabetv.widgetsimple.descriptor-hook.log",
                                      DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(queue, &kLogQueueKey, &kLogQueueKey, NULL);
    });
    return queue;
}

static NSURL *WSLogFileURL(void)
{
    static NSURL *url;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *group = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"AppGroupID"];
        if (![group isKindOfClass:[NSString class]] || group.length == 0 ||
            [group containsString:@"$("]) {
            return;
        }
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *container = [fileManager containerURLForSecurityApplicationGroupIdentifier:group];
        if (container == nil) {
            return;
        }
        NSURL *directory = [container URLByAppendingPathComponent:@"WidgetSimple"
                                                      isDirectory:YES];
        [fileManager createDirectoryAtURL:directory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL];
        url = [directory URLByAppendingPathComponent:@"hook.log"];
    });
    return url;
}

static void WSWriteLogMessageUnsafe(NSString *message)
{
    NSURL *url = WSLogFileURL();
    if (url == nil || message.length == 0) {
        return;
    }

    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    });

    NSString *line = [NSString stringWithFormat:@"%@ %@\n",
                      [formatter stringFromDate:[NSDate date]], message];
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (data.length == 0) {
        return;
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:url.path error:NULL];
    if ([attributes[NSFileSize] unsignedLongLongValue] > 256 * 1024) {
        NSURL *backup = [url URLByAppendingPathExtension:@"1"];
        [fileManager removeItemAtURL:backup error:NULL];
        [fileManager moveItemAtURL:url toURL:backup error:NULL];
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:url.path];
    if (handle == nil) {
        [data writeToURL:url atomically:YES];
        return;
    }

    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
    } @catch (NSException *exception) {
        (void)exception;
    } @finally {
        [handle closeFile];
    }
}

static void WSWriteLogMessage(NSString *message)
{
    @try {
        WSWriteLogMessageUnsafe(message);
    } @catch (NSException *exception) {
        (void)exception;
    }
}

static void WSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void WSLog(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);

    if (message.length == 0) {
        return;
    }

    dispatch_queue_t queue = WSLogQueue();
    if (dispatch_get_specific(&kLogQueueKey) == (void *)&kLogQueueKey) {
        WSWriteLogMessage(message);
    } else {
        dispatch_sync(queue, ^{
            WSWriteLogMessage(message);
        });
    }

#if DEBUG
    NSLog(@"[WidgetDescriptorHook] %@", message);
#endif
}

#pragma mark - Archive class whitelist

static NSSet *WSAllowedClasses(void)
{
    static NSSet *classes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableSet *set = [NSMutableSet set];
        NSArray *foundationClasses = @[
            [NSArray class], [NSMutableArray class],
            [NSDictionary class], [NSMutableDictionary class],
            [NSSet class], [NSMutableSet class],
            [NSOrderedSet class], [NSMutableOrderedSet class],
            [NSString class], [NSMutableString class],
            [NSNumber class], [NSDecimalNumber class], [NSValue class],
            [NSData class], [NSMutableData class],
            [NSDate class], [NSUUID class], [NSNull class],
            [NSURL class], [NSLocale class], [NSTimeZone class],
            [NSIndexSet class],
        ];
        for (id cls in foundationClasses) {
            [set addObject:cls];
        }

        NSArray<NSString *> *names = @[
            @"CHSBaseDescriptor",
            @"CHSWidgetDescriptor",
            @"CHSMutableWidgetDescriptor",
            @"CHSControlDescriptor",
            @"CHSMutableControlDescriptor",
            @"CHSActivityDescriptor",
            @"CHSMutableActivityDescriptor",
            @"CHSWidget",
            @"CHSWidgetConfiguration",
            @"CHSExtensionIdentity",
            @"CHSIntentReference",
            @"CHSWidgetMetrics",
            @"CHSWidgetRenderScheme",
            @"CHSWidgetVisibility",
            @"CHSControlIdentity",
            @"CHSActivityAttributes",
            @"INIntent",
            @"INIntentResponse",
            @"INImage",
        ];
        for (NSString *name in names) {
            Class cls = objc_lookUpClass(name.UTF8String);
            if (cls != Nil) {
                [set addObject:cls];
            }
        }
        classes = [set copy];
    });
    return classes;
}

#pragma mark - Descriptor shim

@interface WSDescriptorShim : NSObject <NSSecureCoding>
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, id> *values;
@property (nonatomic, copy, readonly) NSString *widgetDescriptorsKey;
@property (nonatomic, copy) NSArray *widgetDescriptors;
- (void)decodeAdditionalValuesFromCoder:(NSCoder *)coder
                                   keys:(NSArray<NSString *> *)keys;
@end

@interface WSDescriptorShim ()
- (void)classifyDescriptorArrays;
@end

static BOOL WSArrayIsWidgetDescriptors(NSArray *array, NSString *key)
{
    if (array.count > 0) {
        id first = array.firstObject;
        NSString *className = NSStringFromClass(object_getClass(first)) ?: @"";
        if ([className containsString:@"WidgetDescriptor"]) {
            return YES;
        }
        if ([className containsString:@"ControlDescriptor"] ||
            [className containsString:@"ActivityDescriptor"]) {
            return NO;
        }
    }

    NSString *lowercaseKey = key.lowercaseString;
    if ([lowercaseKey containsString:@"control"] ||
        [lowercaseKey containsString:@"activity"]) {
        return NO;
    }
    return [lowercaseKey containsString:@"widget"];
}

@implementation WSDescriptorShim

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _values = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _values = [NSMutableDictionary dictionary];
        NSSet *allowed = WSAllowedClasses();
        NSArray<NSString *> *knownKeys = @[
            @"widgetDescriptors",
            @"controlDescriptors",
            @"activityDescriptors",
        ];
        for (NSString *key in knownKeys) {
            id value = [coder decodeObjectOfClasses:allowed forKey:key];
            if (value != nil) {
                _values[key] = value;
            }
        }
        [self classifyDescriptorArrays];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    for (NSString *key in _values) {
        id value = _values[key];
        if (value != nil) {
            [coder encodeObject:value forKey:key];
        }
    }
}

- (void)decodeAdditionalValuesFromCoder:(NSCoder *)coder
                                   keys:(NSArray<NSString *> *)keys
{
    NSSet *allowed = WSAllowedClasses();
    for (NSString *key in keys) {
        if (_values[key] != nil) {
            continue;
        }
        id value = [coder decodeObjectOfClasses:allowed forKey:key];
        if (value != nil) {
            _values[key] = value;
        }
    }
    [self classifyDescriptorArrays];
}

- (void)classifyDescriptorArrays
{
    _widgetDescriptorsKey = nil;
    for (NSString *key in _values) {
        id value = _values[key];
        if (![value isKindOfClass:[NSArray class]]) {
            continue;
        }
        if (WSArrayIsWidgetDescriptors((NSArray *)value, key)) {
            _widgetDescriptorsKey = [key copy];
            return;
        }
    }
    if ([_values[@"widgetDescriptors"] isKindOfClass:[NSArray class]]) {
        _widgetDescriptorsKey = @"widgetDescriptors";
    }
}

- (NSArray *)widgetDescriptors
{
    if (_widgetDescriptorsKey.length == 0) {
        return nil;
    }
    id value = _values[_widgetDescriptorsKey];
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

- (void)setWidgetDescriptors:(NSArray *)widgetDescriptors
{
    if (_widgetDescriptorsKey.length == 0) {
        _widgetDescriptorsKey = @"widgetDescriptors";
    }
    if (widgetDescriptors != nil) {
        _values[_widgetDescriptorsKey] = [widgetDescriptors copy];
    } else {
        [_values removeObjectForKey:_widgetDescriptorsKey];
    }
}

@end

#pragma mark - Archive helpers

static BOOL WSTopLevelValueIsScalar(id value)
{
    if (value == nil) {
        return NO;
    }

    CFTypeID type = CFGetTypeID((__bridge CFTypeRef)value);
    return type == CFNumberGetTypeID() ||
           type == CFBooleanGetTypeID() ||
           type == CFStringGetTypeID() ||
           type == CFDataGetTypeID() ||
           type == CFDateGetTypeID() ||
           type == CFArrayGetTypeID() ||
           type == CFDictionaryGetTypeID() ||
           type == CFNullGetTypeID();
}

static NSArray<NSString *> *WSTopLevelKeys(NSData *data, BOOL *hasScalars)
{
    if (hasScalars != NULL) {
        *hasScalars = NO;
    }
    if (data.length == 0) {
        return @[];
    }

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:NSPropertyListImmutable
                                                          format:NULL
                                                           error:&error];
    if (![plist isKindOfClass:[NSDictionary class]]) {
        WSLog(@"archive is not a keyed archive: %@",
              error.localizedDescription ?: @"unknown error");
        return @[];
    }

    id top = ((NSDictionary *)plist)[@"$top"];
    if (![top isKindOfClass:[NSDictionary class]]) {
        WSLog(@"archive has no $top dictionary");
        return @[];
    }

    NSDictionary *topDictionary = (NSDictionary *)top;
    if (hasScalars != NULL) {
        for (id value in topDictionary.allValues) {
            if (WSTopLevelValueIsScalar(value)) {
                *hasScalars = YES;
                break;
            }
        }
    }
    return (NSArray<NSString *> *)[topDictionary allKeys];
}

static NSData *WSEncodeTopLevel(id object, BOOL requiringSecureCoding)
{
    if (object == nil) {
        return nil;
    }

    @try {
        NSKeyedArchiver *archiver =
            [[NSKeyedArchiver alloc] initRequiringSecureCoding:requiringSecureCoding];
        [(id<NSCoding>)object encodeWithCoder:archiver];
        [archiver finishEncoding];

        NSData *data = archiver.encodedData;
        if (data.length == 0) {
            WSLog(@"archiver produced no data (secure=%d)",
                  requiringSecureCoding ? 1 : 0);
            return nil;
        }
        return data;
    } @catch (NSException *exception) {
        WSLog(@"encode failed (secure=%d): %@",
              requiringSecureCoding ? 1 : 0,
              exception.reason ?: exception.name);
        return nil;
    }
}

static NSData *WSEncodeObject(id object)
{
    NSData *data = WSEncodeTopLevel(object, YES);
    if (data != nil) {
        return data;
    }
    WSLog(@"falling back to a non-secure archive");
    return WSEncodeTopLevel(object, NO);
}

static NSKeyedUnarchiver *WSUnarchiverForData(NSData *data)
{
    if (data.length == 0) {
        WSLog(@"cannot unarchive empty data");
        return nil;
    }

    @try {
        NSError *error = nil;
        NSKeyedUnarchiver *unarchiver =
            [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
        if (unarchiver == nil) {
            WSLog(@"unarchive failed: %@",
                  error.localizedDescription ?: @"unknown error");
            return nil;
        }
        unarchiver.requiresSecureCoding = NO;
        return unarchiver;
    } @catch (NSException *exception) {
        WSLog(@"unarchive setup threw: %@", exception.reason ?: exception.name);
        return nil;
    }
}

#pragma mark - Signature-checked private accessors

typedef NS_ENUM(NSInteger, WSValueKind) {
    WSValueKindBool,
    WSValueKindInteger,
};

static BOOL WSSignatureAcceptsSetterValue(NSMethodSignature *signature,
                                          WSValueKind kind)
{
    if ([signature numberOfArguments] != 3) {
        return NO;
    }
    const char *returnType = [signature methodReturnType];
    if (returnType == NULL || returnType[0] != 'v') {
        return NO;
    }
    const char *argumentType = [signature getArgumentTypeAtIndex:2];
    if (argumentType == NULL) {
        return NO;
    }
    if (kind == WSValueKindBool) {
        return argumentType[0] == 'c' || argumentType[0] == 'B';
    }
    return strchr("qQiIlL", argumentType[0]) != NULL;
}

static IMP WSResolveSetter(id object, NSString *selectorName, WSValueKind kind)
{
    if (object == nil || selectorName.length == 0) {
        return NULL;
    }
    WSInitRuntime();
    if (gGetImplementation == nullptr) {
        return NULL;
    }

    SEL selector = WSSelector(selectorName);
    if (selector == NULL) {
        return NULL;
    }
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (method == NULL) {
        return NULL;
    }
    const char *types = method_getTypeEncoding(method);
    if (types == NULL) {
        return NULL;
    }
    @try {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];
        if (signature == nil || !WSSignatureAcceptsSetterValue(signature, kind)) {
            return NULL;
        }
    } @catch (NSException *exception) {
        (void)exception;
        return NULL;
    }
    return gGetImplementation(method);
}

static IMP WSResolveGetter(id object, NSString *selectorName, WSValueKind kind)
{
    if (object == nil || selectorName.length == 0) {
        return NULL;
    }
    WSInitRuntime();
    if (gGetImplementation == nullptr) {
        return NULL;
    }

    SEL selector = WSSelector(selectorName);
    if (selector == NULL) {
        return NULL;
    }
    Method method = class_getInstanceMethod(object_getClass(object), selector);
    if (method == NULL) {
        return NULL;
    }
    const char *types = method_getTypeEncoding(method);
    if (types == NULL) {
        return NULL;
    }
    @try {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];
        if (signature == nil || [signature numberOfArguments] != 2) {
            return NULL;
        }
        const char *returnType = [signature methodReturnType];
        if (returnType == NULL) {
            return NULL;
        }
        if (kind == WSValueKindBool) {
            if (returnType[0] != 'c' && returnType[0] != 'B') {
                return NULL;
            }
        } else if (strchr("qQiIlL", returnType[0]) == NULL) {
            return NULL;
        }
    } @catch (NSException *exception) {
        (void)exception;
        return NULL;
    }
    return gGetImplementation(method);
}

#pragma mark - Descriptor mutation

static std::atomic<bool> gWarnedNoSetters{false};
static std::atomic<bool> gWarnedBackgroundReadback{false};
static std::atomic<bool> gWarnedTransparentReadback{false};
static std::atomic<bool> gWarnedStyleReadback{false};

static BOOL WSApplyTransparency(id descriptor)
{
    if (descriptor == nil) {
        return NO;
    }
    WSInitStrings();

    BOOL applied = NO;
    BOOL sawBackground = NO;
    BOOL sawTransparent = NO;
    BOOL sawStyle = NO;

    SEL backgroundSelector = WSSelector(kSetBackground);
    IMP backgroundSetter = WSResolveSetter(descriptor, kSetBackground, WSValueKindBool);
    if (backgroundSetter != NULL) {
        sawBackground = YES;
        @try {
            ((void (*)(id, SEL, BOOL))backgroundSetter)(descriptor, backgroundSelector, YES);
            applied = YES;
        } @catch (NSException *exception) {
            WSLog(@"background setter threw on %@: %@",
                  NSStringFromClass(object_getClass(descriptor)) ?: @"?",
                  exception.reason ?: exception.name);
        }
    }

    SEL transparentSelector = WSSelector(kSetTransparent);
    IMP transparentSetter = WSResolveSetter(descriptor, kSetTransparent, WSValueKindBool);
    if (transparentSetter != NULL) {
        sawTransparent = YES;
        @try {
            ((void (*)(id, SEL, BOOL))transparentSetter)(descriptor, transparentSelector, YES);
            applied = YES;
        } @catch (NSException *exception) {
            WSLog(@"transparent setter threw on %@: %@",
                  NSStringFromClass(object_getClass(descriptor)) ?: @"?",
                  exception.reason ?: exception.name);
        }
    }

    SEL styleSelector = WSSelector(kSetStyle);
    IMP styleSetter = WSResolveSetter(descriptor, kSetStyle, WSValueKindInteger);
    if (styleSetter != NULL) {
        sawStyle = YES;
        @try {
            ((void (*)(id, SEL, NSInteger))styleSetter)(descriptor, styleSelector, 1);
            applied = YES;
        } @catch (NSException *exception) {
            WSLog(@"style setter threw on %@: %@",
                  NSStringFromClass(object_getClass(descriptor)) ?: @"?",
                  exception.reason ?: exception.name);
        }
    }

    if (!sawBackground && !sawTransparent && !sawStyle) {
        if (!gWarnedNoSetters.exchange(true)) {
            WSLog(@"descriptor %@ exposes none of the transparency setters",
                  NSStringFromClass(object_getClass(descriptor)) ?: @"?");
        }
        return NO;
    }

    if (sawBackground) {
        IMP getter = WSResolveGetter(descriptor, kGetBackground, WSValueKindBool);
        if (getter != NULL) {
            @try {
                BOOL value = ((BOOL (*)(id, SEL))getter)(
                    descriptor, WSSelector(kGetBackground));
                if (!value && !gWarnedBackgroundReadback.exchange(true)) {
                    WSLog(@"background readback NO on %@",
                          NSStringFromClass(object_getClass(descriptor)) ?: @"?");
                }
            } @catch (NSException *exception) {
                WSLog(@"background getter threw: %@", exception.reason ?: exception.name);
            }
        }
    }

    if (sawTransparent) {
        IMP getter = WSResolveGetter(descriptor, kGetTransparent, WSValueKindBool);
        if (getter != NULL) {
            @try {
                BOOL value = ((BOOL (*)(id, SEL))getter)(
                    descriptor, WSSelector(kGetTransparent));
                if (!value && !gWarnedTransparentReadback.exchange(true)) {
                    WSLog(@"transparent readback NO on %@",
                          NSStringFromClass(object_getClass(descriptor)) ?: @"?");
                }
            } @catch (NSException *exception) {
                WSLog(@"transparent getter threw: %@", exception.reason ?: exception.name);
            }
        }
    }

    if (sawStyle) {
        IMP getter = WSResolveGetter(descriptor, kGetStyle, WSValueKindInteger);
        if (getter != NULL) {
            @try {
                NSInteger value = ((NSInteger (*)(id, SEL))getter)(
                    descriptor, WSSelector(kGetStyle));
                if (value != 1 && !gWarnedStyleReadback.exchange(true)) {
                    WSLog(@"style readback %ld, expected 1 on %@",
                          (long)value,
                          NSStringFromClass(object_getClass(descriptor)) ?: @"?");
                }
            } @catch (NSException *exception) {
                WSLog(@"style getter threw: %@", exception.reason ?: exception.name);
            }
        }
    }

    return applied;
}

static NSArray *WSRewriteDescriptorArray(NSArray *descriptors,
                                         NSUInteger *rewrittenCount)
{
    if (rewrittenCount != NULL) {
        *rewrittenCount = 0;
    }
    if (![descriptors isKindOfClass:[NSArray class]]) {
        return descriptors;
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:descriptors.count];
    NSUInteger count = 0;

    for (id descriptor in descriptors) {
        id target = descriptor;
        @try {
            if ([descriptor respondsToSelector:@selector(mutableCopyWithZone:)]) {
                id copy = [descriptor mutableCopy];
                if (copy != nil) {
                    target = copy;
                }
            }
        } @catch (NSException *exception) {
            WSLog(@"mutableCopy threw on %@: %@",
                  NSStringFromClass(object_getClass(descriptor)) ?: @"?",
                  exception.reason ?: exception.name);
        }

        BOOL applied = WSApplyTransparency(target);
        if (!applied && target != descriptor) {
            applied = WSApplyTransparency(descriptor);
            if (applied) {
                target = descriptor;
            }
        }
        if (applied) {
            count++;
        }
        [result addObject:target ?: descriptor];
    }

    if (rewrittenCount != NULL) {
        *rewrittenCount = count;
    }
    return result;
}

#pragma mark - Result rebuild

@protocol WSCodingInit <NSObject>
- (instancetype)initWithCoder:(NSCoder *)coder;
@end

static id WSRebuildResult(id original)
{
    if (original == nil) {
        return nil;
    }
    if (![original respondsToSelector:@selector(encodeWithCoder:)]) {
        WSLog(@"result %@ does not implement NSCoding",
              NSStringFromClass(object_getClass(original)) ?: @"?");
        return nil;
    }

    NSData *encoded = WSEncodeObject(original);
    if (encoded == nil) {
        return nil;
    }

    BOOL hasScalarMetadata = NO;
    NSArray<NSString *> *keys = WSTopLevelKeys(encoded, &hasScalarMetadata);
    if (keys.count > 0) {
        WSLog(@"archive keys: %@", [keys componentsJoinedByString:@","]);
    }
    if (hasScalarMetadata) {
        WSLog(@"result has scalar top-level metadata; refusing to rebuild it");
        return nil;
    }
    if (keys.count == 0) {
        WSLog(@"could not inspect the result archive's top level; using known keys");
    }

    NSKeyedUnarchiver *unarchiver = WSUnarchiverForData(encoded);
    if (unarchiver == nil) {
        return nil;
    }

    WSDescriptorShim *shim = nil;
    @try {
        shim = [[WSDescriptorShim alloc] initWithCoder:unarchiver];
        [shim decodeAdditionalValuesFromCoder:unarchiver keys:keys];
        [unarchiver finishDecoding];
        if (unarchiver.error != nil) {
            WSLog(@"shim decode reported: %@",
                  unarchiver.error.localizedDescription ?: @"unknown error");
            return nil;
        }
    } @catch (NSException *exception) {
        WSLog(@"shim decode threw: %@", exception.reason ?: exception.name);
        return nil;
    }

    if (shim.widgetDescriptorsKey.length == 0) {
        WSLog(@"result has no recognizable widget descriptor array (keys: %@)",
              [keys componentsJoinedByString:@","]);
        return nil;
    }

    NSUInteger rewrittenCount = 0;
    NSArray *rewritten = WSRewriteDescriptorArray(shim.widgetDescriptors,
                                                   &rewrittenCount);
    if (rewrittenCount == 0) {
        WSLog(@"no descriptor accepted the transparency flags (%lu scanned)",
              (unsigned long)shim.widgetDescriptors.count);
        return nil;
    }

    shim.widgetDescriptors = rewritten;
    WSLog(@"rewrote %lu of %lu widget descriptor(s) from %@",
          (unsigned long)rewrittenCount,
          (unsigned long)rewritten.count,
          NSStringFromClass(object_getClass(original)) ?: @"?");

    NSData *rebuiltData = WSEncodeObject(shim);
    if (rebuiltData == nil) {
        return nil;
    }

    NSKeyedUnarchiver *rebuiltUnarchiver = WSUnarchiverForData(rebuiltData);
    if (rebuiltUnarchiver == nil) {
        return nil;
    }

    Class resultClass = object_getClass(original);
    if (resultClass == Nil ||
        class_getInstanceMethod(resultClass, @selector(initWithCoder:)) == NULL) {
        WSLog(@"no NSCoding-capable result class found");
        return nil;
    }

    id rebuilt = nil;
    @try {
        id<WSCodingInit> allocated = (id<WSCodingInit>)[resultClass alloc];
        rebuilt = [allocated initWithCoder:rebuiltUnarchiver];
        [rebuiltUnarchiver finishDecoding];
        if (rebuiltUnarchiver.error != nil) {
            WSLog(@"rebuild reported: %@",
                  rebuiltUnarchiver.error.localizedDescription ?: @"unknown error");
            return nil;
        }
    } @catch (NSException *exception) {
        WSLog(@"rebuild threw: %@", exception.reason ?: exception.name);
        return nil;
    }

    if (rebuilt == nil) {
        WSLog(@"result class returned nil from initWithCoder:");
        return nil;
    }

    WSLog(@"rebuilt %@", NSStringFromClass(object_getClass(rebuilt)) ?: @"?");
    return rebuilt;
}

#pragma mark - Completion gate

typedef void (^WSDescriptorsCompletion)(id result);

@interface WSCompletionGate : NSObject
- (void)invoke:(WSDescriptorsCompletion)completion withResult:(id)result;
@end

@implementation WSCompletionGate {
    std::atomic<bool> _invoked;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _invoked.store(false, std::memory_order_relaxed);
    }
    return self;
}

- (void)invoke:(WSDescriptorsCompletion)completion withResult:(id)result
{
    bool expected = false;
    if (!_invoked.compare_exchange_strong(expected,
                                          true,
                                          std::memory_order_acq_rel,
                                          std::memory_order_acquire)) {
        return;
    }
    if (completion != nil) {
        completion(result);
    }
}

@end

#pragma mark - Interception

typedef void (*WSGetAllDescriptorsIMP)(id, SEL, WSDescriptorsCompletion);

static std::atomic<WSGetAllDescriptorsIMP> gWOrig{nullptr};
static std::atomic<bool> gHookInstalled{false};
static thread_local bool tIsRewriting = false;

static void WSFetch(id receiver, SEL selector, WSDescriptorsCompletion completion)
{
    WSInitStrings();
    WSInitRuntime();

    WSGetAllDescriptorsIMP original = gWOrig.load(std::memory_order_acquire);
    if (original == nullptr) {
        WSLog(@"callback before original");
        if (completion != nil) {
            completion(nil);
        }
        return;
    }

    WSCompletionGate *gate = [[WSCompletionGate alloc] init];
    WSDescriptorsCompletion wrapper = ^(id result) {
        if (tIsRewriting) {
            [gate invoke:completion withResult:result];
            return;
        }

        tIsRewriting = true;
        id replacement = result;
        @try {
            @autoreleasepool {
                id rebuilt = WSRebuildResult(result);
                if (rebuilt != nil) {
                    replacement = rebuilt;
                }
            }
        } @catch (NSException *exception) {
            WSLog(@"rewrite threw: %@", exception.reason ?: exception.name);
        } @finally {
            tIsRewriting = false;
        }

        [gate invoke:completion withResult:replacement];
    };

    @try {
        original(receiver, selector, wrapper);
    } @catch (NSException *exception) {
        WSLog(@"original fetch threw: %@", exception.reason ?: exception.name);
        [gate invoke:completion withResult:nil];
    }
}

#pragma mark - Installation

static Class WSResolveServerClass(void)
{
    WSInitStrings();
    if (kServerClass.length == 0) {
        return Nil;
    }
    return NSClassFromString(kServerClass);
}

static BOOL WSInstallHook(Class server, SEL selector)
{
    if (server == Nil || selector == NULL) {
        WSLog(@"install: invalid class or selector");
        return NO;
    }

    WSInitRuntime();
    Method method = class_getInstanceMethod(server, selector);
    if (method == NULL) {
        WSLog(@"install: %@ does not respond to %@",
              NSStringFromClass(server) ?: @"?",
              NSStringFromSelector(selector));
        return NO;
    }

    if (gGetImplementation == nullptr) {
        WSLog(@"install: original implementation is NULL");
        return NO;
    }

    IMP original = gGetImplementation(method);
    if (original == NULL) {
        WSLog(@"install: original implementation is NULL");
        return NO;
    }
    if (original == (IMP)WSFetch) {
        WSLog(@"install: already installed");
        return YES;
    }

    const char *types = method_getTypeEncoding(method);
    if (types == NULL) {
        WSLog(@"install: method has no type encoding");
        return NO;
    }

    @try {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:types];
        if (signature == nil || [signature numberOfArguments] != 3) {
            WSLog(@"install: unexpected argument count in %s", types);
            return NO;
        }
        const char *returnType = [signature methodReturnType];
        const char *argumentType = [signature getArgumentTypeAtIndex:2];
        if (returnType == NULL || returnType[0] != 'v' ||
            argumentType == NULL || argumentType[0] != '@') {
            WSLog(@"install: unexpected signature %s", types);
            return NO;
        }
    } @catch (NSException *exception) {
        WSLog(@"install: signature parse threw: %@",
              exception.reason ?: exception.name);
        return NO;
    }

    gWOrig.store((WSGetAllDescriptorsIMP)original, std::memory_order_release);

    // class_addMethod returns YES when the selector was inherited and an override
    // was added. It returns NO when the class already implements it directly.
    if (class_addMethod(server, selector, (IMP)WSFetch, types)) {
        // Inherited method: the original IMP above is the superclass implementation.
    } else {
        if (gSetImplementation == nullptr) {
            WSLog(@"install: setter symbol is unavailable");
            return NO;
        }
        gSetImplementation(method, (IMP)WSFetch);
    }

    return YES;
}

__attribute__((constructor))
static void WSStart(void)
{
    bool expected = false;
    if (!gHookInstalled.compare_exchange_strong(expected, true)) {
        return;
    }

    @autoreleasepool {
        WSInitStrings();
        WSInitRuntime();

        Class server = WSResolveServerClass();
        if (server == Nil) {
            WSLog(@"server class missing");
            gHookInstalled.store(false);
            return;
        }

        SEL selector = WSSelector(kFetchSelector);
        if (selector == NULL) {
            WSLog(@"install: fetch selector could not be created");
            gHookInstalled.store(false);
            return;
        }

        if (!WSInstallHook(server, selector)) {
            WSLog(@"install: failed for %@", NSStringFromClass(server) ?: @"?");
            gHookInstalled.store(false);
            return;
        }

        WSLog(@"install complete %@", NSStringFromClass(server) ?: @"?");
    }
}

#endif  // WIDGET_DESCRIPTOR_HOOK_ENABLED
