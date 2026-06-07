///|
/// Writes a Debug representation through a Show logger.
fn[T : Debug] write_debug_show(value : T, logger : &Logger) -> Unit {
  logger.write_string(value.to_repr().to_string())
}

///|
/// Render a wallpaper layout mode using the same spelling as its enum constructor.
///
/// The output is intended for diagnostics and examples. Platform-specific
/// tokens such as Windows registry values or GNOME `picture-options` strings
/// remain private implementation details and are not exposed through `Show`.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.WallpaperMode::Fill.to_string(), content="Fill")
/// }
/// ```
pub impl Show for WallpaperMode with fn output(self, logger : &Logger) -> Unit {
  write_debug_show(self, logger)
}

///|
/// Render a wallpaper request with all public fields visible.
///
/// This is useful while debugging application flows because it includes the
/// requested platform, source string, and layout mode in one value. The format
/// follows the derived `Debug` representation and should be treated as
/// diagnostic text rather than a serialization format.
///
/// # Example
/// ```mbt check
/// test {
///   let request : @wallpaper.WallpaperRequest = {
///     platform: Linux,
///     source: "/tmp/wallpaper.jpg",
///     mode: Fit,
///   }
///   inspect(
///     request.to_string(),
///     content="{ platform: Linux, source: \"/tmp/wallpaper.jpg\", mode: Fit }",
///   )
/// }
/// ```
pub impl Show for WallpaperRequest with fn output(self, logger : &Logger) -> Unit {
  write_debug_show(self, logger)
}

///|
/// Render a wallpaper status using the same spelling as its enum constructor.
///
/// The output is useful for logs and user-facing fallback messages when native
/// APIs are unavailable or reject an update. Use `WallpaperStatus::is_success`
/// when code needs a boolean success branch.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(
///     @wallpaper.WallpaperStatus::UnsupportedPlatform.to_string(),
///     content="UnsupportedPlatform",
///   )
/// }
/// ```
pub impl Show for WallpaperStatus with fn output(self, logger : &Logger) -> Unit {
  write_debug_show(self, logger)
}
