# iOS and iPadOS Porting Plan

## Goal

Bring Horizon to iOS and iPadOS while preserving the existing Rust game engine, world processing, chunk pipeline, worker architecture, LOD logic, and renderer wherever the platform permits. This is a platform port, not a rewrite of the rendering or world-generation systems.

## Non-negotiable architecture rule

Do not replace or simplify the existing world/chunk processing or rendering implementation merely to make an iOS shell easier to build. First identify platform-specific boundaries, then adapt only the host/platform integration around the shared Rust code.

## Repository audit

The first source inspection confirms a clean separation worth preserving:

- `horizon-client` owns the gameplay library and the shared `game::run_with()` startup path.
- `horizon-client-render` owns the renderer and rendering systems.
- `horizon-world` and `horizon-threads` own world systems and thread support.
- `horizon-android` is a thin Android `cdylib` crate whose library path points directly at `crates/horizon-client/src/android_main.rs`.
- That Android entry point is explicitly guarded by `cfg(target_os = "android")` and depends on Android's `AndroidApp`, NativeActivity lifecycle, JNI bridge, and Android-specific storage APIs.
- The Android crate already enables wgpu's `metal` feature alongside its Android graphics features. This is not proof that an iOS surface or app target is configured; the iOS host and target feature set still need to be implemented and built.

**Important consequence:** do not try to compile `android_main.rs` as the iOS entry point. Add a separate iOS host that calls into the shared client/game code, leaving the Android host untouched.

The current shared client manifest has Android-specific `winit` NativeActivity and JNI dependencies behind `cfg(target_os = "android")`, while macOS-specific Objective-C dependencies are behind `cfg(target_os = "macos")`. iOS needs its own dependency and host audit; macOS is not an interchangeable target for iOS.

The following areas should remain shared unless a concrete iOS incompatibility is demonstrated:

- world and chunk processing
- worker/thread scheduling and chunk streaming
- LOD and distant-chunk handling
- rendering algorithms, shaders, and render graph
- shared game/client logic
- resource and asset formats

## Implementation status

### Initial host scaffold added

The `horizon-ios` workspace crate now builds as a Rust static library and exports `horizon_start()`. The Objective-C `main.m` shim calls that function on the process main thread. The shared client entry point then starts the existing winit iOS event loop; the vendored winit iOS backend calls `UIApplicationMain` itself.

The host prepares these app-sandbox locations:

- `Documents/Horizon` for game data and worlds
- `Documents/Horizon/resources` for prepared game resources
- `Library/Caches/Horizon` for disposable cache data

The XcodeGen specification targets iPhone and iPad and selects the Rust target for physical devices and simulators. A macOS GitHub Actions workflow cross-compiles the Rust static library for device and Apple Silicon simulator targets, then generates and builds the simulator app with Xcode. Winit's default Wayland/X11 feature set has been removed from Apple builds and scoped to Linux; the shared UIKit/Metal backend remains the iOS path.

### Shared resource setup backend added

The existing Android resource-preparation implementation in
`horizon-client/src/android_setup.rs` now exposes platform-neutral
`start()` and `status_text()` APIs. Its JNI adapter is compiled only on
Android, while the iOS host includes the same Rust implementation and exposes
a small C bridge for readiness, start, and progress polling.

This reuses the pinned Mojang manifest/client verification, SHA-1 checked
downloads, resumable partial files, parallel asset fetching, and safe derived
pack extraction. A native UIKit onboarding screen is now included in the Xcode target. It imports the derived ZIP via the Files document picker, starts the shared setup routine, and polls progress/errors after winit's one UIKit launch sequence. When resources become ready, it asks the user to relaunch Horizon because the existing game entry point has already entered its no-resources screen.

### Not yet implemented or validated

- The onboarding overlay still needs validation on a simulator and physical device; it is presented after the winit launch notification.
- Microsoft account sign-in and token refresh UI have not yet been ported.
- Files document-picker import for the derived ZIP is implemented in the onboarding screen; general world/resource-pack import and export workflows remain pending.
- The vendored winit iOS backend already translates UIKit touch/gesture events and basic text input into winit events, and observes active/background/foreground/memory-warning notifications. The game-level control mapping, external keyboard behavior, and controller support still need device verification.
- The client renderer uses optional cpal output with Symphonia Vorbis decoding; the iOS Core Audio backend and audio-session behavior have not been validated.
- wgpu enables its Metal feature and winit's iOS window backend provides the UIKit/Metal presentation path, but the actual Horizon renderer surface creation and GPU pipeline have not yet passed an iOS build or device test.
- Android Microsoft sign-in is implemented in Java (`Msa`, `MsaLoginActivity`, `ProfileActivity`) and publishes a private session JSON consumed by `android_msa.rs`. The WebView login UI and Android JNI refresh callback are not portable. The iOS port needs an external-browser OAuth flow such as `ASWebAuthenticationSession` plus secure Keychain token storage; do not copy the Android WebView credential flow.
- The Rust targets and Xcode project have not yet completed a successful Apple-toolchain build in this environment. No IPA or working device build is claimed.

The next milestone is a successful device/simulator cross-compile, followed by resource onboarding and platform input/lifecycle validation.

## iOS/iPadOS work areas

### 1. Native application host

Add an iOS application target and a minimal native host that initializes the existing Rust client. Use the iOS application lifecycle and UIKit integration rather than Android NativeActivity. Keep the host thin and avoid moving game logic into Swift.

### 2. Graphics surface

Audit the current wgpu version and enabled features for iOS. Establish a Metal-backed surface using the supported iOS integration path. Reuse the existing renderer and shaders. Any required surface or presentation changes must be isolated to platform initialization and presentation code.

### 3. Input

Implement iOS/iPadOS touch input and map it into the existing shared input abstraction. Preserve support for external keyboards and game controllers where the current input layer allows it. Add platform-specific text-input handling without changing gameplay semantics.

### 4. Files and permissions

The first-run screen uses `UIDocumentPickerViewController` to import the required derived ZIP into `Documents/Horizon/horizon-derived.zip`. General world, resource-pack, mod, and shader-pack import/export workflows still need dedicated picker flows. Keep world saves, resource packs, configuration, and downloaded game assets in the existing shared formats. Make import/export explicit and user-controlled.

### 5. Audio

Audit the current audio backend for iOS support and select a compatible native backend if needed. Keep the shared audio interface and game audio behavior unchanged.

### 6. Conditional compilation and dependencies

Review every Android-only dependency and every `cfg(target_os = "android")` / non-Android assumption. Introduce narrowly scoped iOS implementations or feature gates. Do not globally disable shared functionality to make compilation pass.

### 7. Threading and performance validation

Verify iOS thread and memory constraints against the existing worker architecture. Preserve parallel chunk processing. If iOS requires limits or scheduling adjustments, make them configurable and platform-specific rather than rewriting the pipeline. Validate memory pressure, thermal behavior, backgrounding, and resume.

## Suggested implementation sequence

1. Inventory platform-specific code and Cargo features.
2. Confirm the Rust target and dependency support for iOS device and simulator.
3. Add the smallest possible iOS host and application project.
4. Bring up a Metal surface with the existing renderer.
5. Wire lifecycle, input, text input, audio, and sandbox file access.
6. Build and run on a physical iPhone/iPad.
7. Validate world loading, chunk workers, distant chunks, saves, and long-session stability.
8. Document signing, build, and release steps.

## Acceptance criteria

- Existing shared Rust renderer remains in use.
- Existing world/chunk processing and worker architecture remain in use.
- iOS/iPadOS app launches and presents the game through Metal.
- Touch, keyboard, and supported controllers work.
- Worlds and configuration can be imported, saved, and exported through supported iOS workflows.
- App handles background/foreground transitions and memory pressure without corrupting worlds.
- Device build and runtime behavior are verified; a successful desktop or simulator compile alone is not considered a completed port.

## Build environment note

A signed iOS application build and device deployment require macOS with a compatible Xcode toolchain and signing configuration. Repository changes can be prepared independently, but an IPA must not be claimed until it has actually been built and tested.
