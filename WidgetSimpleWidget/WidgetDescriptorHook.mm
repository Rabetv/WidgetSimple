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
// Shape of the hook, and why:
//   * The descriptors are mutated in place inside the completion, so nothing is
//     archived or rebuilt. Re-encoding a Swift `DescriptorFetchResult` and
//     recreating it from the archive needs that class to be NSCoding-compatible
//     with the exact same keys, which is the fragile part of the obvious version.
//   * Every selector is probed first and every mutation is inside @try: a missing
//     selector would otherwise throw inside the descriptor fetch and the widget
//     would fail to load — worse than a rim.
//   * If the class or the method is missing, nothing is installed and the widget
//     behaves exactly as before.

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

/// Clear. The values are guesses from the reference app's behaviour; 0 is the
/// default style, so only a non-zero value can change anything.
static const NSUInteger kClearBackgroundStyle = 1;

static void ApplyTransparentFlags(NSArray *descriptors)
{
    for (id descriptor in descriptors) {
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
            // Immutable descriptor, or a selector that changed meaning: keep it.
        }
    }
}

static void HookedGetAllDescriptors(id self, SEL _cmd, DescriptorsCompletion completion)
{
    OriginalGetAllDescriptors(self, _cmd, ^(id result) {
        @try {
            if ([result respondsToSelector:@selector(widgetDescriptors)]) {
                ApplyTransparentFlags([result widgetDescriptors]);
            } else {
                ApplyTransparentFlags([result valueForKey:@"widgetDescriptors"]);
            }
        } @catch (NSException *exception) {
            // Leave the descriptors untouched.
        }
        completion(result);
    });
}

__attribute__((constructor)) static void InstallWidgetDescriptorHook(void)
{
    Class server = NSClassFromString(@"_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
    if (server == Nil) { return; }

    SEL selector = NSSelectorFromString(@"getAllCurrentDescriptorsWithCompletion:");
    Method method = class_getInstanceMethod(server, selector);
    if (method == NULL) { return; }

    OriginalGetAllDescriptors = (GetAllDescriptorsIMP)method_getImplementation(method);
    if (OriginalGetAllDescriptors == NULL) { return; }
    method_setImplementation(method, (IMP)HookedGetAllDescriptors);
}
