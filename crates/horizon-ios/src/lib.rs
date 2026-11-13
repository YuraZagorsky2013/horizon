//! iOS/iPadOS entry point for Horizon.
//!
//! UIKit owns the process entry point. The small Objective-C main shim calls
//! this function; winit then creates and runs its UIKit event loop.

use std::ffi::{CStr, c_char};
use std::path::PathBuf;

#[path = "../../horizon-client/src/android_setup.rs"]
mod android_setup;

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
    let temp = cache.join("tmp");
    std::fs::create_dir_all(&temp)
        .expect("could not create Horizon's temporary directory");

    for directory in ["resources", "saves", "resourcepacks", "mods", "shaderpacks"] {
        std::fs::create_dir_all(game_home.join(directory))
            .unwrap_or_else(|error| panic!("could not create Horizon/{directory}: {error}"));
    }

    // Configure the same paths the desktop and Android client already consume.
    // This runs on the main thread before the game starts its worker threads.
    unsafe {
        std::env::set_var("HORIZON_HOME", &game_home);
        std::env::set_var("HOME", &game_home);
        std::env::set_var("TMPDIR", &temp);
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


/// Returns whether the app's Minecraft resources are fully prepared.
#[unsafe(no_mangle)]
pub extern "C" fn horizon_setup_ready() -> bool {
    let home = std::env::var_os("HORIZON_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|path| PathBuf::from(path).join("Documents").join("Horizon")));
    home.is_some_and(|home| android_setup::ready(&home.join("resources")))
}

/// Begin or resume the same verified first-run downloader used by Android.
/// Pass an empty URL to use Documents/Horizon/horizon-derived.zip.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn horizon_setup_start(derived_url: *const c_char) {
    let derived = if derived_url.is_null() {
        String::new()
    } else {
        // SAFETY: the caller must pass a valid NUL-terminated UTF-8 C string.
        unsafe { CStr::from_ptr(derived_url) }.to_string_lossy().into_owned()
    };
    let home = std::env::var_os("HORIZON_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|path| PathBuf::from(path).join("Documents").join("Horizon")))
        .expect("iOS application container HOME is unavailable");
    android_setup::start(home, derived);
}

/// Copy the tab-separated setup status into a caller-owned UTF-8 buffer.
/// Returns the full required byte length excluding the NUL terminator.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn horizon_setup_status(buffer: *mut c_char, capacity: usize) -> usize {
    let status = android_setup::status_text();
    let bytes = status.as_bytes();
    if !buffer.is_null() && capacity > 0 {
        let count = bytes.len().min(capacity - 1);
        // SAFETY: the caller guarantees that buffer points to capacity writable bytes.
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), buffer.cast::<u8>(), count);
            *buffer.add(count) = 0;
        }
    }
    bytes.len()
}
