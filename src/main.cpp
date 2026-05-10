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

    // [window orderFrontRegardless] — show without taking focus
    msg(window, sel_registerName("orderFrontRegardless"));
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

    // NSWindowStyleMaskBorderless — no title bar or chrome
    unsigned long styleMask = 0;

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
                   sel_registerName("stringWithUTF8String:"), "OSX Overlay");
    msg(window, sel_registerName("setTitle:"), title);

    // ── Make the window fully transparent ───────────────────────────

    // [window setOpaque:NO]
    msg<void>(window, sel_registerName("setOpaque:"), NO);

    // [window setBackgroundColor:[NSColor clearColor]]
    id clearColor = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("clearColor"));
    msg(window, sel_registerName("setBackgroundColor:"), clearColor);

    // ── Always on top, no focus, ignore input ───────────────────────

    // [window setLevel:NSScreenSaverWindowLevel (1000)] — above all normal windows
    msg<void>(window, sel_registerName("setLevel:"), 1000L);

    // [window setIgnoresMouseEvents:YES] — clicks pass through
    msg<void>(window, sel_registerName("setIgnoresMouseEvents:"), YES);

    // Don't let the window become key or main (no keyboard focus)
    // We'll use a borderless-panel approach: setCanBecomeKey/Main overridden below
    msg<void>(window, sel_registerName("setHidesOnDeactivate:"), NO);

    // ── Add a red "Hello world!" label ──────────────────────────────

    // Create NSTextField label
    CGRect labelFrame = {{20, 260}, {760, 40}};
    id label = msg(reinterpret_cast<id>(cls("NSTextField")), sel_registerName("alloc"));
    label = reinterpret_cast<id (*)(id, SEL, CGRect)>(objc_msgSend)(
        label, sel_registerName("initWithFrame:"), labelFrame);

    // Set string value to "Hello world!"
    id text = msg(reinterpret_cast<id>(cls("NSString")),
                  sel_registerName("stringWithUTF8String:"), "Hello world!");
    msg(label, sel_registerName("setStringValue:"), text);

    // Make it a non-editable label
    msg<void>(label, sel_registerName("setEditable:"), NO);
    msg<void>(label, sel_registerName("setBezeled:"), NO);
    msg<void>(label, sel_registerName("setDrawsBackground:"), NO);
    msg<void>(label, sel_registerName("setSelectable:"), NO);

    // Set red text color: [NSColor redColor]
    id redColor = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("redColor"));
    msg(label, sel_registerName("setTextColor:"), redColor);

    // Set font size: [NSFont systemFontOfSize:24]
    id font = reinterpret_cast<id (*)(id, SEL, double)>(objc_msgSend)(
        reinterpret_cast<id>(cls("NSFont")), sel_registerName("systemFontOfSize:"), 24.0);
    msg(label, sel_registerName("setFont:"), font);

    // Add label to window's content view
    id contentView = msg(window, sel_registerName("contentView"));
    msg(contentView, sel_registerName("addSubview:"), label);

    return window;
}

// ── main ────────────────────────────────────────────────────────────

int main() {
    // [NSApplication sharedApplication]
    id app = msg(reinterpret_cast<id>(cls("NSApplication")),
                 sel_registerName("sharedApplication"));

    // [app setActivationPolicy:NSApplicationActivationPolicyAccessory (1)]
    // Accessory app: no Dock icon, no menu bar, does not take focus
    msg<void>(app, sel_registerName("setActivationPolicy:"), 1L);

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
