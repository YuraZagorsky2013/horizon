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

This bootstrap does not yet include the Android first-run downloader, Microsoft
account UI, or iOS document-picker import flow. Until those are ported, place a
prepared Horizon `resources` directory in the app's `Documents/Horizon`
folder. File Sharing is enabled in the app's Info.plist so the folder can be
managed through Files or Finder.

Worlds, resource packs, mods, and shader packs use the existing folder names
under `Documents/Horizon`. The next platform milestone is the iOS onboarding
and file-import experience, followed by device validation.

## Current validation status

The repository changes are source scaffolding only. They have not yet been
compiled with an Apple toolchain, launched in an iOS simulator, or tested on a
physical device. A working IPA is not claimed.
