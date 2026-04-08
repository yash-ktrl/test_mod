#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <substrate.h>

// ── Configuration ──────────────────────────────────────────
#define TARGET_FOV 90.0f        // Change this to your desired FOV
#define TARGET_FAR_CLIP 200.0f  // Draw distance (original was 36)
// ───────────────────────────────────────────────────────────

// Unity's Camera class methods (IL2CPP resolved at runtime)
static void (*orig_Camera_set_fieldOfView)(void *camera, float fov, void *method);
static void (*orig_Camera_set_farClipPlane)(void *camera, float distance, void *method);
static float (*orig_Camera_get_fieldOfView)(void *camera, void *method);

// Hook: intercept every time the game sets FOV
static void hook_Camera_set_fieldOfView(void *camera, float fov, void *method) {
    // Override with our FOV instead
    orig_Camera_set_fieldOfView(camera, TARGET_FOV, method);
}

// Hook: intercept far clip plane being set
static void hook_Camera_set_farClipPlane(void *camera, float distance, void *method) {
    // Only increase, never decrease
    float newDistance = distance < TARGET_FAR_CLIP ? TARGET_FAR_CLIP : distance;
    orig_Camera_set_farClipPlane(camera, newDistance, method);
}

// ── Il2Cpp symbol resolver helper ──────────────────────────
static void *findSymbol(const char *image, const char *symbol) {
    void *handle = dlopen(image, RTLD_NOW | RTLD_NOLOAD);
    if (!handle) return NULL;
    void *sym = dlsym(handle, symbol);
    dlclose(handle);
    return sym;
}

// ── Constructor: runs when dylib is loaded ─────────────────
__attribute__((constructor))
static void initialize() {
    NSLog(@"[SmashKartsFOV] Tweak loaded! Targeting FOV: %.1f", (float)TARGET_FOV);

    // Path to the IL2CPP game binary inside the .app bundle
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *frameworkPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
    
    const char *binaryPath = [frameworkPath fileSystemRepresentation];

    // Resolve Camera::set_fieldOfView from the Unity IL2CPP binary
    // These symbol names follow Unity IL2CPP naming convention
    void *set_fov_ptr = findSymbol(binaryPath, "Camera_set_fieldOfView_m");
    void *set_far_ptr = findSymbol(binaryPath, "Camera_set_farClipPlane_m");

    if (set_fov_ptr) {
        MSHookFunction(set_fov_ptr, (void *)hook_Camera_set_fieldOfView, (void **)&orig_Camera_set_fieldOfView);
        NSLog(@"[SmashKartsFOV] ✅ Hooked Camera.fieldOfView setter");
    } else {
        NSLog(@"[SmashKartsFOV] ❌ Could not find fieldOfView symbol — try Il2CppDumper to find exact name");
    }

    if (set_far_ptr) {
        MSHookFunction(set_far_ptr, (void *)hook_Camera_set_farClipPlane, (void **)&orig_Camera_set_farClipPlane);
        NSLog(@"[SmashKartsFOV] ✅ Hooked Camera.farClipPlane setter");
    } else {
        NSLog(@"[SmashKartsFOV] ❌ Could not find farClipPlane symbol");
    }
}
