# Horizon for iOS and iPadOS

This directory is the first native iOS application-host milestone. It deliberately
reuses the existing `horizon-client` crate; it does not contain a second renderer,
world implementation, chunk loader, or LOD system.

## Architecture

- `crates/horizon-ios` builds a Rust static library named `libhorizon_ios.a`.
- `main.m` calls the exported `horizon_start()` function.
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

## Game resources

The existing Android first-run downloader and derived-pack extractor are now
shared with the iOS crate. Its verified Mojang downloads, SHA-1 checks, parallel
asset downloads, resumable partial files, and derived-pack validation are reused
without changing the renderer or world pipeline.

The iOS static library exposes a small C bridge in `horizon_ios.h`:
`horizon_setup_ready()`, `horizon_setup_start()`, and
`horizon_setup_status()`. A native onboarding screen still needs to call this
bridge and present progress/errors. Until that UI is connected, place a prepared
Horizon `resources` directory in the app's `Documents/Horizon` folder.
File Sharing is enabled in the app's Info.plist so the folder can be managed
through Files or Finder.

Microsoft account UI and iOS document-picker import/export are still pending.

Worlds, resource packs, mods, and shader packs use the existing folder names
under `Documents/Horizon`. The next platform milestone is connecting the setup bridge to a native iOS onboarding screen and adding file-import/export, followed by device validation.

## Current validation status

The repository changes are source scaffolding only. They have not yet been
compiled with an Apple toolchain, launched in an iOS simulator, or tested on a
physical device. A working IPA is not claimed.
