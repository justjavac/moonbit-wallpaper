# justjavac/wallpaper

[![coverage](https://img.shields.io/codecov/c/github/justjavac/moonbit-wallpaper/main?label=coverage)](https://codecov.io/gh/justjavac/moonbit-wallpaper)
[![linux](https://img.shields.io/codecov/c/github/justjavac/moonbit-wallpaper/main?flag=linux&label=linux)](https://codecov.io/gh/justjavac/moonbit-wallpaper)
[![macos](https://img.shields.io/codecov/c/github/justjavac/moonbit-wallpaper/main?flag=macos&label=macos)](https://codecov.io/gh/justjavac/moonbit-wallpaper)
[![windows](https://img.shields.io/codecov/c/github/justjavac/moonbit-wallpaper/main?flag=windows&label=windows)](https://codecov.io/gh/justjavac/moonbit-wallpaper)

`justjavac/wallpaper` is a native-only MoonBit package for applying desktop wallpapers through platform APIs. It does not generate shell commands, run scripts, or call command-line tools. The public API is intentionally small: describe a wallpaper request, apply it, and inspect the returned status.

## Design

The package uses `justjavac/platform` directly for operating-system values instead of defining a second `DesktopPlatform` enum. This keeps the API smaller: callers can use `@platform.os()` when they need the current platform and pass `@platform.Os::*` values when they want to target a platform explicitly.

The package deliberately avoids display-only helpers such as `platform_name`; `@platform.Os` already implements `Show`, so callers can print the enum directly. Platform-specific mode tokens, Windows registry values, Linux URI normalization, and native ABI integer codes remain private implementation details. The public API stays focused on applying wallpapers and reporting status.

The implementation uses two small dependencies:

- `justjavac/platform` provides compile-time native operating-system detection.
- `justjavac/ffi` prepares null-terminated UTF-8 buffers for POSIX-style APIs and null-terminated UTF-16LE buffers for Win32 APIs.

The C side borrows those buffers during the call and does not copy or own them.

## Platform APIs

Windows uses Win32 APIs:

- `RegCreateKeyExW` opens `HKCU\Control Panel\Desktop`.
- `RegSetValueExW` updates `WallpaperStyle` and `TileWallpaper`.
- `SystemParametersInfoW(SPI_SETDESKWALLPAPER, ...)` applies the image and broadcasts the desktop update.

Linux uses GNOME GSettings through the GIO C API loaded at runtime:

- `org.gnome.desktop.background picture-uri`
- `org.gnome.desktop.background picture-options`

Linux does not have one universal desktop wallpaper API. This package targets GNOME-compatible GSettings directly. If GIO or the GNOME background schema is unavailable, `apply` returns `UnsupportedDesktop`.

macOS uses AppKit through the Objective-C runtime:

- `NSWorkspace`
- `NSScreen`
- `setDesktopImageURL:forScreen:options:error:`

macOS applies the image source. The `WallpaperMode` argument is accepted for API consistency, but AppKit does not expose a matching cross-version layout setting through this binding.

## Installation

Add the dependency in `moon.mod`:

```moonbit
import {
  "justjavac/wallpaper@0.1.2",
}
```

Import the package from `moon.pkg`:

```moonbit
import {
  "justjavac/platform" @platform,
  "justjavac/wallpaper" @wallpaper,
}
```

`justjavac/platform` is needed when your code wants to inspect or pass explicit platform values. This package supports only the native backend.

## Quick Start

```mbt
fn main {
  let status = @wallpaper.apply_current(
    "/home/alice/Pictures/wallpaper.jpg",
    @wallpaper.WallpaperMode::Fill,
  )
  if status.is_success() {
    println("wallpaper applied")
  } else {
    println("wallpaper failed: \{status}")
  }
}
```

If your application already knows the target platform, call `apply` directly:

```mbt
let request : @wallpaper.WallpaperRequest = {
  platform: @platform.Os::Linux,
  source: "/home/alice/Pictures/wallpaper.jpg",
  mode: @wallpaper.WallpaperMode::Fit,
}
let status = @wallpaper.apply(request)
```

## Public API

Platform selection uses `justjavac/platform`:

```mbt
pub(all) enum Os {
  Windows
  MacOS
  Linux
  UnknownOs
}
```

`WallpaperMode` describes the requested layout:

```mbt
pub(all) enum WallpaperMode {
  Fill
  Fit
  Stretch
  Center
  Span
}
```

`WallpaperRequest` describes one wallpaper update:

```mbt
pub(all) struct WallpaperRequest {
  platform : @platform.Os
  source : String
  mode : WallpaperMode
}
```

`WallpaperStatus` reports the native result:

```mbt
pub(all) enum WallpaperStatus {
  Applied
  UnsupportedPlatform
  UnsupportedDesktop
  InvalidSource
  NativeFailure
}
```

`supports_platform(platform)` returns whether the package has a native implementation for the platform enum value.

`apply(request)` calls the platform API selected by `request.platform`.

`apply_current(source, mode)` uses `@platform.os()` and applies the wallpaper on the current operating system.

`WallpaperStatus::is_success()` returns `true` only for `Applied`.

## Status Handling

`Applied` means the platform API accepted the request.

`UnsupportedPlatform` means the requested platform is `UnknownOs` or does not match an implementation compiled into the current binary.

`UnsupportedDesktop` means the operating system is supported, but the expected desktop service is unavailable. The common case is Linux without GNOME GSettings.

`InvalidSource` means the source string is empty. This is checked before calling platform APIs.

`NativeFailure` means the platform API was available but rejected the update.

## Examples

Example source lives under `src/examples`, keeping MoonBit source inside `src`.

Run the safe basic example. It detects the current platform and validates an empty source without changing your wallpaper:

```bash
moon run src/examples/basic --target native
```

Run the support matrix example:

```bash
moon run src/examples/platform_matrix --target native
```

To actually change a wallpaper, call `apply_current` or `apply` with a real local image path from your application.

## Testing And Coverage

Run local checks:

```bash
moon check --target native
moon test --target native
```

Generate coverage:

```bash
moon test --target native --enable-coverage
moon coverage analyze -p justjavac/wallpaper -- -f cobertura -o coverage.xml
```

CI runs native tests on Linux, macOS, and Windows, then uploads one Cobertura XML report per platform to Codecov with the `linux`, `macos`, or `windows` flag. The README keeps one total coverage badge plus one badge per platform.

## Maintenance Notes

- Keep the public API focused on applying wallpaper and reporting status.
- Use `@platform.Os` directly instead of adding a second platform enum to this package.
- Use `justjavac/ffi` for string ABI conversion instead of hand-written C
  string conversion helpers.
- Keep platform-specific tokens and ABI codes private.
- Keep native side effects behind `apply` and `apply_current`.
- Do not add shell-command fallbacks to the library.
- When adding a platform, update `supports_platform`, the native stub, tests, examples if relevant, and this README.

## License

MIT
