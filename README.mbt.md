# moonbit_native/wallpaper

Native-only MoonBit bindings for desktop wallpaper platform APIs. No shell commands are used.

```mbt nocheck
let status = @wallpaper.apply_current(
  "/home/alice/Pictures/wallpaper.jpg",
  @wallpaper.WallpaperMode::Fill,
)
```
