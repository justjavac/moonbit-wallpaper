///|
/// How the wallpaper should be fitted to the desktop.
///
/// Windows maps these values to `WallpaperStyle` and `TileWallpaper`, and Linux
/// maps them to GNOME `picture-options`. macOS currently applies the image
/// source only because AppKit does not expose a matching cross-version layout
/// mode in the API used by this package.
///
/// Choose the mode that best matches the desktop behavior you want. `Fill` is
/// the package default for examples because it maps to common "cover the
/// screen" behavior on Windows and GNOME. `Fit` preserves the whole image,
/// `Stretch` may distort it, `Center` leaves the image at its natural size, and
/// `Span` is intended for multi-monitor layouts where the platform supports
/// that concept.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.WallpaperMode::Fill.to_string(), content="Fill")
///   inspect(@wallpaper.WallpaperMode::Span.to_string(), content="Span")
/// }
/// ```
pub(all) enum WallpaperMode {
  Fill
  Fit
  Stretch
  Center
  Span
} derive(Debug, Eq)

///|
/// A request to apply a wallpaper through a specific platform API.
///
/// `platform` uses `justjavac/platform` directly. `Windows`, `MacOS`, and
/// `Linux` select the corresponding native implementation, while `UnknownOs`
/// returns `UnsupportedPlatform`.
///
/// `source` is expected to be an absolute local file path for Windows and
/// macOS. For Linux the binding accepts either an absolute path or an existing
/// `file://` URI and normalizes plain paths to the URI form expected by GNOME
/// GSettings.
///
/// Construct a request when you already know which platform branch you want to
/// exercise, such as in a desktop app that stores a target OS in configuration
/// or in tests that need deterministic status handling. Most applications can
/// use `apply_current` instead, which fills `platform` from `@platform.os()`.
///
/// # Example
/// ```mbt check
/// test {
///   let request : @wallpaper.WallpaperRequest = {
///     platform: UnknownOs,
///     source: "/tmp/wallpaper.jpg",
///     mode: Fit,
///   }
///   inspect(@wallpaper.apply(request), content="UnsupportedPlatform")
/// }
/// ```
pub(all) struct WallpaperRequest {
  platform : @platform.Os
  source : String
  mode : WallpaperMode
} derive(Debug, Eq)

///|
/// Result of applying a wallpaper request through the platform API.
///
/// `Applied` means the platform API accepted the request. `UnsupportedPlatform`
/// is returned for `UnknownOs` or an operating system without an implementation.
/// `UnsupportedDesktop` is used when the OS is supported but the expected
/// desktop service is unavailable, such as GNOME GSettings on Linux.
/// `InvalidSource` means the source path was empty. `NativeFailure` means the
/// platform API was present but rejected the update.
///
/// Match on the status when callers need distinct fallback behavior, or use
/// `WallpaperStatus::is_success` when a boolean branch is enough. The function
/// APIs return statuses instead of raising so UI code can decide whether to
/// retry, show a platform-specific message, or ignore unsupported desktops.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.WallpaperStatus::Applied.is_success(), content="true")
///   inspect(
///     @wallpaper.WallpaperStatus::UnsupportedDesktop.is_success(),
///     content="false",
///   )
/// }
/// ```
pub(all) enum WallpaperStatus {
  Applied
  UnsupportedPlatform
  UnsupportedDesktop
  InvalidSource
  NativeFailure
} derive(Debug, Eq)
