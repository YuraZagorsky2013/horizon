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
- The shared renderer enables wgpu's Metal feature, but that alone does not prove an iOS app can create and present a working Metal surface.

**Important consequence:** do not try to compile `android_main.rs` as the iOS entry point. The separate iOS host calls into the shared client/game code and leaves the Android host intact.

The shared client uses Android-specific winit NativeActivity and JNI dependencies behind `cfg(target_os = "android")`, while macOS-specific Objective-C dependencies are behind `cfg(target_os = "macos")`. iOS is handled as its own target, not as interchangeable macOS or Android.

The following areas remain shared:

- world and chunk processing
- worker/thread scheduling and chunk streaming
- LOD and distant-chunk handling
- rendering algorithms, shaders, and render graph
- shared game/client logic
- resource and asset formats

## Implementation status

### Native iOS/iPadOS host

The `horizon-ios` workspace crate builds as a Rust static library and exports `horizon_start()`. The Objective-C `main.m` shim registers the onboarding overlay and calls that function on the process main thread. The shared client entry point starts the existing winit iOS event loop; the vendored winit iOS backend owns the single `UIApplicationMain` sequence.

The host prepares these app-sandbox locations:

- `Documents/Horizon` for game data and worlds
- `Documents/Horizon/resources` for prepared game resources
- `Library/Caches/Horizon` for disposable cache data

The XcodeGen specification targets iPhone and iPad. Its build phase selects the Rust target for physical devices and simulator architectures. Apple builds avoid desktop Wayland/X11 dependencies; the iOS path uses UIKit and wgpu's Metal backend.

### Native onboarding and shared resource setup

The existing Android resource-preparation implementation in
`horizon-client/src/android_setup.rs` exposes platform-neutral
`start()` and `status_text()` APIs. Its JNI adapter remains Android-only.
The iOS host includes the same Rust implementation and exports a C bridge for
readiness, starting setup, and polling progress.

The native UIKit onboarding screen is included in the Xcode target. It:

- appears when the resource marker says the game is not ready;
- imports `horizon-derived.zip` with `UIDocumentPickerViewController` into
  `Documents/Horizon/horizon-derived.zip`;
- accepts a direct archive URL as an alternative;
- starts the shared downloader/extractor and polls its stage, file/byte counts,
  and errors;
- allows retry after failure.

The shared setup keeps the pinned Mojang manifest/client checks, SHA-1
verification, resumable partial downloads, parallel asset fetching, and safe
derived-pack extraction. Once setup finishes, the overlay asks the player to
close and reopen Horizon because this launch has already entered the existing
no-resources screen. Background downloading and an in-process game restart are
not implemented.

### Build validation

CI has successfully cross-compiled the Rust static library for
`aarch64-apple-ios` and `aarch64-apple-ios-sim`. XcodeGen also successfully
generated the Xcode project.

The first Xcode simulator-app build failed in the custom Rust build phase:
Xcode supplied `CURRENT_ARCH=undefined_arch` for the generic simulator
destination, while the script only accepted concrete `arm64` or `x86_64`.
The build phase now resolves the generic destination from `ARCHS`, and the CI
simulator build is constrained to `arm64`, matching the already-built Rust
simulator target. This correction is committed to `android-port`; the new
CI result is still pending.

A successful Rust static-library cross-compile is not the same as a successful
Xcode app build or runtime validation. No simulator launch, physical-device
launch, signed IPA, or App Store-ready build is claimed.

## Not yet implemented or validated

- **Microsoft account sign-in:** not ported. Android's Java/WebView login,
  JNI refresh callback, and private session-file handoff are Android-specific.
  iOS needs its own browser-based OAuth flow, such as
  `ASWebAuthenticationSession`, and secure Keychain token storage.
- **Files workflows:** derived ZIP import is implemented. General world,
  resource-pack, mod, and shader-pack import/export flows remain pending.
- **Touch:** the shared in-game touch controls are now enabled for iOS, and
  vendored winit translates UIKit touch and gesture events. The actual game
  controls still need simulator/device interaction testing.
- **Keyboard and text input:** the winit iOS view implements UIKit
  `UIKeyInput`, can become first responder, and maps committed text/backspace
  into winit events. Its IME cursor-area API is currently ignored. Software
  keyboard composition, focus, external hardware-keyboard input, and shortcuts
  have not been validated in Horizon on a device.
- **Audio:** the client uses optional cpal output with Symphonia Vorbis
  decoding. The Rust iOS build compiles the Core Audio dependency path, but
  playback, audio-session configuration, interruptions, and route changes
  remain unverified.
- **Metal:** wgpu enables Metal, and the vendored iOS winit window uses a
  `CAMetalLayer` presentation path. The Rust renderer compiles for iOS, but
  the Xcode app build and actual GPU surface/pipeline execution still need
  confirmation.
- **Lifecycle:** winit observes launch, active/inactive, foreground/background,
  termination, and memory-warning notifications and emits the corresponding
  events. Game pause/resume, background resource-download interruption, and
  restoration still require runtime validation.
- **Controllers:** the iOS host currently disables the optional gilrs backend
  until an iOS-native controller path is wired and tested.
- **Runtime and packaging:** no simulator launch, physical iPhone/iPad test,
  signed IPA, or distribution build has been verified.

## iOS/iPadOS work areas

### 1. Native application host

Keep the iOS application host thin and initialize the existing Rust client through UIKit/winit. Do not start a second application lifecycle or move game logic into Swift.

### 2. Graphics surface

Use the existing wgpu Metal backend and the iOS winit surface path. Reuse the existing renderer and shaders. Any required surface or presentation changes must be isolated to platform initialization and presentation code.

### 3. Input

Preserve shared touch controls and map UIKit touch events into the existing input abstraction. Complete and validate software text input, external keyboards, and supported game controllers without changing gameplay semantics.

### 4. Files and permissions

Use `UIDocumentPickerViewController` for explicit user-controlled import/export. The first-run screen currently imports the required derived ZIP; general world, resource-pack, mod, and shader-pack workflows still need dedicated picker flows.

### 5. Audio

Verify the iOS Core Audio path, session category, interruptions, and output routing. Keep the shared audio interface and game audio behavior unchanged.

### 6. Conditional compilation and dependencies

Review every Android-only dependency and every `cfg(target_os = "android")` assumption. Introduce narrowly scoped iOS implementations or feature gates. Do not globally disable shared functionality to make compilation pass.

### 7. Threading and performance validation

Verify iOS thread and memory constraints against the existing worker architecture. Preserve parallel chunk processing. If iOS requires limits or scheduling adjustments, make them configurable and platform-specific rather than rewriting the pipeline. Validate memory pressure, thermal behavior, backgrounding, and resume.

## Suggested implementation sequence

1. Complete the Xcode simulator-app build after the generic-architecture fix.
2. Launch the app in an iOS simulator and validate the onboarding and Files import.
3. Validate Metal presentation, touch, text input, audio, and lifecycle behavior.
4. Port Microsoft sign-in and general Files workflows.
5. Build, sign, and run on a physical iPhone/iPad.
6. Validate world loading, chunk workers, distant chunks, saves, and long-session stability.
7. Document signing, build, and release steps.

## Acceptance criteria

- Existing shared Rust renderer remains in use.
- Existing world/chunk processing and worker architecture remain in use.
- iOS/iPadOS app launches and presents the game through Metal.
- Touch, text input, and supported controllers work.
- Worlds and configuration can be imported, saved, and exported through supported iOS workflows.
- App handles background/foreground transitions and memory pressure without corrupting worlds.
- Device build and runtime behavior are verified; a successful desktop or simulator compile alone is not considered a completed port.

## Build environment note

A signed iOS application build and device deployment require macOS with a compatible Xcode toolchain and signing configuration. Repository source changes can be prepared independently, but an IPA must not be claimed until it has actually been built and tested.
