//! iOS/iPadOS entry point for Horizon.
//!
//! UIKit owns the process entry point. The small Objective-C main shim calls
//! this function; winit then creates and runs its UIKit event loop.

use std::path::PathBuf;

/// Start Horizon from the iOS application entry point.
///
/// The game data lives in the app's Documents/Horizon directory so the Files
/// app and Finder file sharing can expose user-managed worlds and resources.
#[unsafe(no_mangle)]
pub extern "C" fn horizon_start() {
    let container = std::env::var_os("HOME")
        .map(PathBuf::from)
        .expect("iOS did not provide the application container HOME directory");

    let game_home = container.join("Documents").join("Horizon");
    let cache = container.join("Library").join("Caches").join("Horizon");

    std::fs::create_dir_all(&game_home)
        .expect("could not create Horizon's Documents directory");
    std::fs::create_dir_all(&cache)
        .expect("could not create Horizon's cache directory");

    for directory in ["resources", "saves", "resourcepacks", "mods", "shaderpacks"] {
        std::fs::create_dir_all(game_home.join(directory))
            .unwrap_or_else(|error| panic!("could not create Horizon/{directory}: {error}"));
    }

    // Configure the same paths the desktop and Android client already consume.
    // This runs on the main thread before the game starts its worker threads.
    unsafe {
        std::env::set_var("HORIZON_HOME", &game_home);
        std::env::set_var("HORIZON_RESOURCES", game_home.join("resources"));
        std::env::set_var("HORIZON_CACHE", &cache);
    }

    std::env::set_current_dir(&game_home)
        .expect("could not set Horizon's working directory");

    // This is the existing Rust client entry point. The renderer, world/chunk
    // pipeline, LOD, and worker implementation remain in their shared crates.
    // winit's iOS run_app path calls UIApplicationMain itself.
    horizon_client::entry::main();
}
