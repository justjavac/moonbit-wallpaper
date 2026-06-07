///|
fn main {
  let platform = @platform.os()
  let supported = @wallpaper.supports_platform(platform)
  let status = @wallpaper.apply_current("", Fill)
  println("current platform: \{platform}")
  println("native api supported: \{supported}")
  println("empty source status: \{status}")
}
