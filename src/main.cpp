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

    // ── Helper: build an NSAttributedString for "Hello world!" ────────
    //
    // Each word gets its own color and font size. We build an
    // NSMutableAttributedString, append "Hello " with one style,
    // then append "world!" with another.

    auto makeFont = [](double size) -> id {
        return reinterpret_cast<id (*)(id, SEL, double)>(objc_msgSend)(
            reinterpret_cast<id>(cls("NSFont")),
            sel_registerName("systemFontOfSize:"), size);
    };

    auto makeStr = [](const char *s) -> id {
        return msg(reinterpret_cast<id>(cls("NSString")),
                   sel_registerName("stringWithUTF8String:"), s);
    };

    // NSAttributedString keys
    id kForeground = makeStr("NSColor");       // NSForegroundColorAttributeName
    id kFont       = makeStr("NSFont");        // NSFontAttributeName

    auto makeAttrStr = [&](const char *text, id color, double fontSize) -> id {
        // Build an NSDictionary with color + font
        id keys[]   = { kForeground, kFont };
        id values[] = { color, makeFont(fontSize) };

        id dict = reinterpret_cast<id (*)(id, SEL, id *, id *, unsigned long)>(objc_msgSend)(
            reinterpret_cast<id>(cls("NSDictionary")),
            sel_registerName("dictionaryWithObjects:forKeys:count:"),
            values, keys, 2UL);

        id str = makeStr(text);

        id attrStr = msg(reinterpret_cast<id>(cls("NSAttributedString")),
                         sel_registerName("alloc"));
        attrStr = msg(attrStr, sel_registerName("initWithString:attributes:"), str, dict);
        return attrStr;
    };

    auto buildLine = [&](id color1, double size1, id color2, double size2) -> id {
        id mutAttrStr = msg(reinterpret_cast<id>(cls("NSMutableAttributedString")),
                            sel_registerName("alloc"));
        mutAttrStr = msg(mutAttrStr, sel_registerName("init"));

        id part1 = makeAttrStr("Hello ", color1, size1);
        id part2 = makeAttrStr("world!", color2, size2);

        msg(mutAttrStr, sel_registerName("appendAttributedString:"), part1);
        msg(mutAttrStr, sel_registerName("appendAttributedString:"), part2);

        return mutAttrStr;
    };

    auto makeLabel = [&](CGRect frame, id attrString) -> id {
        id label = msg(reinterpret_cast<id>(cls("NSTextField")), sel_registerName("alloc"));
        label = reinterpret_cast<id (*)(id, SEL, CGRect)>(objc_msgSend)(
            label, sel_registerName("initWithFrame:"), frame);

        msg<void>(label, sel_registerName("setEditable:"), NO);
        msg<void>(label, sel_registerName("setBezeled:"), NO);
        msg<void>(label, sel_registerName("setDrawsBackground:"), NO);
        msg<void>(label, sel_registerName("setSelectable:"), NO);
        msg(label, sel_registerName("setAttributedStringValue:"), attrString);

        return label;
    };

    // Colors
    id red    = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("redColor"));
    id green  = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("greenColor"));
    id blue   = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("blueColor"));
    id yellow = msg(reinterpret_cast<id>(cls("NSColor")), sel_registerName("yellowColor"));

    // Line 1: "Hello" red 20pt, "world!" green 24pt
    id line1 = buildLine(red, 20.0, green, 24.0);
    CGRect frame1 = {{20, 310}, {760, 40}};
    id label1 = makeLabel(frame1, line1);

    // Line 2: "Hello" blue 28pt, "world!" yellow 32pt
    id line2 = buildLine(blue, 28.0, yellow, 32.0);
    CGRect frame2 = {{20, 260}, {760, 50}};
    id label2 = makeLabel(frame2, line2);

    // Add both labels to window's content view
    id contentView = msg(window, sel_registerName("contentView"));
    msg(contentView, sel_registerName("addSubview:"), label1);
    msg(contentView, sel_registerName("addSubview:"), label2);

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
