#include <objc/objc.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <CoreGraphics/CGGeometry.h>

// Convenience: cast objc_getClass result to Class.
static inline Class cls(const char *name) {
    return reinterpret_cast<Class>(objc_getClass(name));
}

// Convenience wrapper around objc_msgSend with the correct cast.
// objc_msgSend is a variadic trampoline — it must be cast to the
// exact function-pointer type matching the selector's signature.
template <typename Ret = id, typename... Args>
Ret msg(id obj, SEL sel, Args... args) {
    return reinterpret_cast<Ret (*)(id, SEL, Args...)>(objc_msgSend)(obj, sel, args...);
}

// ── AppDelegate callback implementations ────────────────────────────

static void appDidFinishLaunching(id self, SEL, id /*notification*/) {
    id window = nullptr;
    object_getInstanceVariable(self, "window", reinterpret_cast<void **>(&window));

    // [window makeKeyAndOrderFront:nil]
    msg(window, sel_registerName("makeKeyAndOrderFront:"), static_cast<id>(nullptr));
}

static BOOL appShouldTerminateAfterLastWindowClosed(id, SEL, id) {
    return YES;
}

// ── Helpers ─────────────────────────────────────────────────────────

static Class registerAppDelegateClass() {
    Class delegateCls = objc_allocateClassPair(cls("NSObject"), "AppDelegate", 0);

    class_addIvar(delegateCls, "window", sizeof(id), alignof(id), "@");

    class_addMethod(delegateCls, sel_registerName("applicationDidFinishLaunching:"),
                    reinterpret_cast<IMP>(appDidFinishLaunching), "v@:@");

    class_addMethod(delegateCls, sel_registerName("applicationShouldTerminateAfterLastWindowClosed:"),
                    reinterpret_cast<IMP>(appShouldTerminateAfterLastWindowClosed), "B@:@");

    objc_registerClassPair(delegateCls);
    return delegateCls;
}

static id createWindow() {
    CGRect frame = {{200, 200}, {800, 600}};

    // NSWindowStyleMask flags
    unsigned long styleMask = (1 << 0)   // titled
                            | (1 << 1)   // closable
                            | (1 << 2)   // miniaturizable
                            | (1 << 3);  // resizable

    // [[NSWindow alloc] initWithContentRect:frame
    //                             styleMask:styleMask
    //                               backing:NSBackingStoreBuffered (2)
    //                                 defer:NO]
    id window = msg(reinterpret_cast<id>(cls("NSWindow")), sel_registerName("alloc"));
    window = reinterpret_cast<id (*)(id, SEL, CGRect, unsigned long, unsigned long, BOOL)>(
        objc_msgSend)(window, sel_registerName("initWithContentRect:styleMask:backing:defer:"),
                      frame, styleMask, 2UL /* buffered */, NO);

    // [window setTitle:@"OSX Overlay"]
    id title = msg(reinterpret_cast<id>(cls("NSString")),
                   sel_registerName("stringWithUTF8String:"), "OSX Overlay C++");
    msg(window, sel_registerName("setTitle:"), title);

    return window;
}

// ── main ────────────────────────────────────────────────────────────

int main() {
    // [NSApplication sharedApplication]
    id app = msg(reinterpret_cast<id>(cls("NSApplication")),
                 sel_registerName("sharedApplication"));

    // [app setActivationPolicy:NSApplicationActivationPolicyRegular (0)]
    msg<void>(app, sel_registerName("setActivationPolicy:"), 0L);

    // Create AppDelegate, instantiate it, attach window
    Class delegateCls = registerAppDelegateClass();
    id delegate = msg(reinterpret_cast<id>(delegateCls), sel_registerName("new"));

    id window = createWindow();
    object_setInstanceVariable(delegate, "window", window);

    // [app setDelegate:delegate]
    msg(app, sel_registerName("setDelegate:"), delegate);

    // [app run]
    msg(app, sel_registerName("run"));

    return 0;
}
