#ifndef OSX_OVERLAY_COCOA_BRIDGE_H
#define OSX_OVERLAY_COCOA_BRIDGE_H

#include <string>
#include <objc/objc.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <CoreGraphics/CGGeometry.h>

namespace cocoa {

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

    CGRect createFrame(double x, double y, double width, double height);
    id createTransparentWindow(double x, double y, double width, double height, const std::string& title);

}




#endif //OSX_OVERLAY_COCOA_BRIDGE_H
