#include "cocoa_bridge.h"

CGRect cocoa::createFrame(double x, double y, double width, double height)
{
    return {{x, y}, {width, height}};
}

id cocoa::createTransparentWindow(double x, double y, double width, double height, const std::string& windowTitle)
{
    CGRect frame = createFrame(x,y,width,height);

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

    // [window setTitle:@"Example Title"]
    id title = msg(reinterpret_cast<id>(cls("NSString")),
                   sel_registerName("stringWithUTF8String:"), windowTitle);
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

    return window;
}
