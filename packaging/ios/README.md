# Horizon for iOS and iPadOS

This is the native iOS/iPadOS application host for Horizon. It reuses the
existing `horizon-client` crate; it does not contain a second renderer, world
implementation, chunk loader, LOD system, or worker pool.

## Architecture

- `crates/horizon-ios` builds a Rust static library named `libhorizon_ios.a`.
- `main.m` registers the onboarding overlay and calls the exported
  `horizon_start()` function.
- The Rust entry point prepares app-sandbox paths and calls
  `horizon_client::entry::main()`.
- The existing winit iOS backend owns `UIApplicationMain` and the UIKit event
  loop. Do not wrap this target in a SwiftUI `@main App` or start a second
  `UIApplicationMain`.
- The game renderer, world/chunk processing, LOD, and worker systems remain in
  their existing shared Rust crates.

## Generate the Xcode project

Install Xcode, the Rust toolchain, and XcodeGen, then from this directory run:

```sh
xcodegen generate
open Horizon.xcodeproj
```

The Xcode build phase selects the Rust target for the chosen device or simulator
and builds `horizon-ios` before linking the app. Select an iPhone/iPad device
or an iOS simulator in Xcode, then configure signing with your Apple developer
team.

The Rust targets used are:

- `aarch64-apple-ios` for physical iPhones and iPads
- `aarch64-apple-ios-sim` for Apple Silicon simulators
- `x86_64-apple-ios` for Intel simulators

For a generic simulator destination, the Xcode build phase builds the Rust
static library for each architecture selected by Xcode's `ARCHS` setting.

## First-run resource setup

The iOS app includes a native UIKit onboarding screen. It is registered before
winit starts its single UIKit application lifecycle and presented after the
launch notification when game resources are not ready.

The screen lets the player:

1. Import `horizon-derived.zip` from the Files app using
   `UIDocumentPickerViewController`, or enter a direct URL to the archive.
2. Start the existing shared mobile setup implementation.
3. Follow the current preparation stage, file and byte progress, and errors.
4. Retry after a failed setup.

The picker copies the archive to `Documents/Horizon/horizon-derived.zip`.
The Rust C bridge in `horizon_ios.h` exposes
`horizon_setup_ready()`, `horizon_setup_start()`, and
`horizon_setup_status()`; the iOS host includes the same
`crates/horizon-client/src/android_setup.rs` implementation used by Android.
Mojang downloads are hash-checked, resumable where supported, and fetched by
the existing worker pool. The derived archive is validated before the
incomplete marker is removed.

Keep Horizon in the foreground while preparation runs. Background transfer
has not been implemented. When setup finishes, the screen asks the player to
close and reopen Horizon: the current launch has already entered the shared
no-resources screen, and this host does not yet restart the game in-process.
Once resources are ready, the next launch skips onboarding.

File Sharing is enabled in the app's Info.plist so the app's Documents folder
can be managed through Files or Finder.

## Platform audit and current gaps

- **Microsoft sign-in:** not ported. The existing Android MSA UI, JNI refresh
  bridge, and private session-file handoff are Android-specific. iOS needs its
  own browser-based OAuth flow and Keychain-backed token storage.
- **Files workflows:** importing the derived ZIP is implemented. General
  world, resource-pack, mod, and shader-pack import/export screens are pending.
- **Touch:** shared in-game touch controls are enabled for iOS and UIKit touch
  events are translated by winit. This path still needs simulator/device
  interaction testing.
- **Keyboard and text input:** the vendored winit iOS view implements UIKit
  `UIKeyInput` and text-input traits. Actual software-keyboard composition,
  external-keyboard shortcuts, and focus behavior have not been validated in
  Horizon on a device.
- **Audio:** the client uses optional cpal output and Symphonia decoding. The
  iOS Rust target compiles the audio dependency path, but playback, audio
  session configuration, interruptions, and route changes remain unverified.
- **Metal:** wgpu is built with its Metal feature and the iOS winit backend
  supplies the UIKit presentation path. A successful Rust static-library build
  does not by itself prove that Horizon's renderer creates and presents a
  working Metal surface on a device.
- **Lifecycle:** winit observes launch, active/inactive, foreground/background,
  termination, and memory-warning notifications. Game pause/resume, resource
  download interruption, and restoration still require runtime validation.
- **Controllers:** the iOS host currently disables the optional gilrs controller
  backend until an iOS-native controller path is wired and tested.

## Validation status

A Rust static-library cross-compile has succeeded for physical iOS and Apple
Silicon simulator targets in CI. The Xcode simulator app build is being
validated separately. No physical iPhone/iPad runtime test, signed IPA, or
App Store-ready build is claimed until those steps have actually been
performed and verified.
