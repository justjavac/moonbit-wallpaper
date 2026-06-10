name = "justjavac/wallpaper"

version = "0.1.3"

import {
  "justjavac/ffi@0.2.3",
  "justjavac/platform@0.1.2",
}

readme = "README.mbt.md"

repository = "https://github.com/justjavac/moonbit-wallpaper"

license = "MIT"

keywords = [ "moonbit", "native", "wallpaper" ]

description = "Native wallpaper platform API bindings for desktop apps."

preferred_target = "native"

options(
  source: "src",
)
