///|
fn print_summary(platform : @platform.Os) -> Unit {
  let supported = @wallpaper.supports_platform(platform)
  println("\{platform}: supported=\{supported}")
}

///|
fn main {
  print_summary(Windows)
  print_summary(MacOS)
  print_summary(Linux)
  print_summary(UnknownOs)
}
