///|
test "support matrix is explicit" {
  inspect(@wallpaper.supports_platform(Windows), content="true")
  inspect(@wallpaper.supports_platform(MacOS), content="true")
  inspect(@wallpaper.supports_platform(Linux), content="true")
  inspect(@wallpaper.supports_platform(UnknownOs), content="false")
}

///|
test "status success helper only accepts applied" {
  let applied : @wallpaper.WallpaperStatus = Applied
  let unsupported_platform : @wallpaper.WallpaperStatus = UnsupportedPlatform
  let unsupported_desktop : @wallpaper.WallpaperStatus = UnsupportedDesktop
  let invalid_source : @wallpaper.WallpaperStatus = InvalidSource
  let native_failure : @wallpaper.WallpaperStatus = NativeFailure
  inspect(applied.is_success(), content="true")
  inspect(unsupported_platform.is_success(), content="false")
  inspect(unsupported_desktop.is_success(), content="false")
  inspect(invalid_source.is_success(), content="false")
  inspect(native_failure.is_success(), content="false")
}

///|
test "apply returns unsupported for unknown platform without scripts" {
  let status = @wallpaper.apply({
    platform: UnknownOs,
    source: "/tmp/hero.png",
    mode: Fill,
  })
  inspect(status, content="UnsupportedPlatform")
}

///|
test "apply validates empty source before calling platform api" {
  let status = @wallpaper.apply({
    platform: @platform.os(),
    source: "",
    mode: Fill,
  })
  inspect(status, content="InvalidSource")
}

///|
test "apply current validates empty source safely" {
  inspect(@wallpaper.apply_current("", Center), content="InvalidSource")
}

///|
test "show implementations are debug backed" {
  let mode : @wallpaper.WallpaperMode = Fill
  let request : @wallpaper.WallpaperRequest = {
    platform: Linux,
    source: "/tmp/show.png",
    mode: Fill,
  }
  let status : @wallpaper.WallpaperStatus = UnsupportedDesktop
  inspect(mode.to_string(), content="Fill")
  inspect(
    request.to_string(),
    content="{ platform: Linux, source: \"/tmp/show.png\", mode: Fill }",
  )
  inspect(status.to_string(), content="UnsupportedDesktop")
}
