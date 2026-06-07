///|
test "platform mode and source internals" {
  inspect(
    normalized_source(Linux, "/tmp/hero.png"),
    content="file:///tmp/hero.png",
  )
  inspect(
    normalized_source(Linux, "file:///tmp/hero.png"),
    content="file:///tmp/hero.png",
  )
  inspect(
    normalized_source(Windows, "C:/Pictures/hero.png"),
    content="C:/Pictures/hero.png",
  )
  inspect(
    normalized_source(MacOS, "/Users/me/Pictures/hero.png"),
    content="/Users/me/Pictures/hero.png",
  )
}

///|
test "abi platform code mappings" {
  inspect(platform_code(Windows), content="0")
  inspect(platform_code(MacOS), content="1")
  inspect(platform_code(Linux), content="2")
  inspect(platform_code(UnknownOs), content="3")
}

///|
test "abi mode code mappings" {
  inspect(mode_code(Fill), content="0")
  inspect(mode_code(Fit), content="1")
  inspect(mode_code(Stretch), content="2")
  inspect(mode_code(Center), content="3")
  inspect(mode_code(Span), content="4")
}

///|
test "abi status code mappings" {
  inspect(status_from_code(0), content="Applied")
  inspect(status_from_code(1), content="UnsupportedPlatform")
  inspect(status_from_code(2), content="UnsupportedDesktop")
  inspect(status_from_code(3), content="InvalidSource")
  inspect(status_from_code(4), content="NativeFailure")
  inspect(status_from_code(99), content="NativeFailure")
}
