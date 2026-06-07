///|
/// Convert a public platform value to the native stub ABI code.
fn platform_code(platform : @platform.Os) -> Int {
  match platform {
    Windows => 0
    MacOS => 1
    Linux => 2
    UnknownOs => 3
  }
}

///|
/// Convert a public wallpaper mode to the native stub ABI code.
fn mode_code(mode : WallpaperMode) -> Int {
  match mode {
    Fill => 0
    Fit => 1
    Stretch => 2
    Center => 3
    Span => 4
  }
}

///|
/// Convert a native stub status code to a public status value.
fn status_from_code(code : Int) -> WallpaperStatus {
  match code {
    0 => Applied
    1 => UnsupportedPlatform
    2 => UnsupportedDesktop
    3 => InvalidSource
    _ => NativeFailure
  }
}

///|
/// Normalize the image source for the native platform API.
fn normalized_source(platform : @platform.Os, source : String) -> String {
  match platform {
    Linux =>
      if source.has_prefix("file://") {
        source
      } else {
        "file://\{source}"
      }
    _ => source
  }
}

///|
/// Return whether an operating system has a native apply implementation.
///
/// Windows uses Win32 user and registry APIs, macOS uses AppKit through the
/// Objective-C runtime, and Linux uses GNOME GSettings through the GIO C API.
/// `UnknownOs` is always unsupported.
///
/// This checks only whether the package has code for the operating system. It
/// does not verify a specific desktop session, image path, permissions, or
/// user settings service. On Linux, for example, this returns `true` for the OS
/// even though `apply` may later return `UnsupportedDesktop` when GNOME
/// GSettings is unavailable.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.supports_platform(Linux), content="true")
///   inspect(@wallpaper.supports_platform(UnknownOs), content="false")
/// }
/// ```
pub fn supports_platform(platform : @platform.Os) -> Bool {
  match platform {
    Windows | MacOS | Linux => true
    UnknownOs => false
  }
}

///|
/// Return whether a wallpaper status represents a successful update.
///
/// This helper is useful when callers want a boolean branch while still keeping
/// the detailed status available for logging or user messages.
///
/// Only `Applied` is considered successful. Unsupported platforms, unsupported
/// desktops, validation failures, and native API rejections all return `false`
/// so callers can handle every non-applied outcome through one fallback branch
/// when detailed recovery is not needed.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.WallpaperStatus::Applied.is_success(), content="true")
///   inspect(
///     @wallpaper.WallpaperStatus::NativeFailure.is_success(),
///     content="false",
///   )
/// }
/// ```
pub fn WallpaperStatus::is_success(self : WallpaperStatus) -> Bool {
  self is Applied
}

///|
/// Apply a wallpaper request through the target platform API.
///
/// No shell commands or script runners are used. Windows calls Win32 APIs,
/// macOS calls AppKit through the Objective-C runtime, and Linux calls GNOME
/// GSettings through GIO. The function returns a `WallpaperStatus` instead of
/// raising so desktop applications can decide how to surface native failures.
///
/// `source` must be non-empty. Windows and macOS expect a local filesystem path.
/// Linux accepts either a local path or a `file://` URI; plain paths are
/// normalized before entering the GSettings API. A request whose platform is
/// `UnknownOs` never reaches a desktop API and returns `UnsupportedPlatform`.
///
/// # Example
/// ```mbt check
/// test {
///   let request : @wallpaper.WallpaperRequest = {
///     platform: UnknownOs,
///     source: "/tmp/wallpaper.jpg",
///     mode: Fill,
///   }
///   inspect(@wallpaper.apply(request), content="UnsupportedPlatform")
/// }
/// ```
pub fn apply(request : WallpaperRequest) -> WallpaperStatus {
  if request.source == "" {
    return InvalidSource
  }
  let source = normalized_source(request.platform, request.source)
  status_from_code(
    native_apply(
      platform_code(request.platform),
      @ffi.to_cstr(source),
      @ffi.to_wstr(source),
      mode_code(request.mode),
    ),
  )
}

///|
/// Apply a wallpaper source on the current operating system.
///
/// This is a convenience wrapper around `justjavac/platform.os` and `apply`.
/// It has the same side effects as `apply`, so callers should pass a real local
/// image path and be prepared to handle a non-`Applied` status.
///
/// Use this for the common case where the application wants to apply a wallpaper
/// to the machine it is running on. It performs the same empty-source
/// validation as `apply` before any native desktop API is called.
///
/// # Example
/// ```mbt check
/// test {
///   inspect(@wallpaper.apply_current("", Center), content="InvalidSource")
/// }
/// ```
pub fn apply_current(source : String, mode : WallpaperMode) -> WallpaperStatus {
  apply({ platform: @platform.os(), source, mode })
}
