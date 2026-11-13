# iOS and iPadOS Porting Plan

## Goal

Bring Horizon to iOS and iPadOS while preserving the existing Rust game engine, world processing, chunk pipeline, worker architecture, LOD logic, and renderer wherever the platform permits. This is a platform port, not a rewrite of the rendering or world-generation systems.

## Non-negotiable architecture rule

Do not replace or simplify the existing world/chunk processing or rendering implementation merely to make an iOS shell easier to build. First identify platform-specific boundaries, then adapt only the host/platform integration around the shared Rust code.

## Existing Android architecture to preserve

The Android build uses a native Rust application path. The Android-specific crate and entry point host the shared Horizon client, while the client and renderer crates contain the game implementation. The project uses wgpu with platform graphics backends and has Android-specific lifecycle, input, text input, storage, and download integration.

The following areas should remain shared unless a concrete iOS incompatibility is demonstrated:

- world and chunk processing
- worker/thread scheduling and chunk streaming
- LOD and distant-chunk handling
- rendering algorithms, shaders, and render graph
- shared game/client logic
- resource and asset formats

## iOS/iPadOS work areas

### 1. Native application host

Add an iOS application target and a minimal native host that initializes the existing Rust client. Use the iOS application lifecycle and UIKit integration rather than Android NativeActivity. Keep the host thin and avoid moving game logic into Swift.

### 2. Graphics surface

Audit the current wgpu version and enabled features for iOS. Establish a Metal-backed surface using the supported iOS integration path. Reuse the existing renderer and shaders. Any required surface or presentation changes must be isolated to platform initialization and presentation code.

### 3. Input

Implement iOS/iPadOS touch input and map it into the existing shared input abstraction. Preserve support for external keyboards and game controllers where the current input layer allows it. Add platform-specific text-input handling without changing gameplay semantics.

### 4. Files and permissions

Replace Android-specific storage assumptions with the iOS app sandbox and document-picker workflows. Keep world saves, resource packs, configuration, and downloaded game assets in the existing shared formats. Make import/export explicit and user-controlled.

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
