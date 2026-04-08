#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>
#include <dlfcn.h>   // ✅ FIXED

// ── Configuration ──────────────────────────────────────────
#define TARGET_FOV 90.0f
#define TARGET_FAR_CLIP 200.0f
// ───────────────────────────────────────────────────────────

// Unity Camera methods
static void (*orig_Camera_set_fieldOfView)(void *camera, float fov, void *method);
static void (*orig_Camera_set_farClipPlane)(void *camera, float distance, void *method);

// Hook: FOV
static void hook_Camera_set_fieldOfView(void *camera, float fov, void *method) {
    if (orig_Camera_set_fieldOfView) {
        orig_Camera_set_fieldOfView(camera, TARGET_FOV, method);
    }
}

// Hook: far clip
static void hook_Camera_set_farClipPlane(void *camera, float distance, void *method) {
    if (orig_Camera_set_farClipPlane) {
        float newDistance = distance < TARGET_FAR_CLIP ? TARGET_FAR_CLIP : distance;
        orig_Camera_set_farClipPlane(camera, newDistance, method);
    }
}

// ── Symbol resolver ────────────────────────────────────────
static void *findSymbol(const char *image, const char *symbol) {
    void *handle = dlopen(image, RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        NSLog(@"[SmashKartsFOV] ❌ dlopen failed");
        return NULL;
    }

    void *sym = dlsym(handle, symbol);
    dlclose(handle);

    if (!sym) {
        NSLog(@"[SmashKartsFOV] ❌ dlsym failed for %s", symbol);
    }

    return sym;
}

// ── Entry ─────────────────────────────────────────────────
__attribute__((constructor))
static void initialize() {
    NSLog(@"[SmashKartsFOV] 🚀 Loaded | Target FOV: %.1f", (float)TARGET_FOV);

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworkPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
    
    const char *binaryPath = [frameworkPath fileSystemRepresentation];

    void *set_fov_ptr = findSymbol(binaryPath, "Camera_set_fieldOfView_m");
    void *set_far_ptr = findSymbol(binaryPath, "Camera_set_farClipPlane_m");

    if (set_fov_ptr) {
        MSHookFunction(set_fov_ptr, (void *)hook_Camera_set_fieldOfView, (void **)&orig_Camera_set_fieldOfView);
        NSLog(@"[SmashKartsFOV] ✅ Hooked FOV");
    } else {
        NSLog(@"[SmashKartsFOV] ❌ FOV symbol not found");
    }

    if (set_far_ptr) {
        MSHookFunction(set_far_ptr, (void *)hook_Camera_set_farClipPlane, (void **)&orig_Camera_set_farClipPlane);
        NSLog(@"[SmashKartsFOV] ✅ Hooked FarClip");
    } else {
        NSLog(@"[SmashKartsFOV] ❌ FarClip symbol not found");
    }
}
