///|
/// Borrow the prepared source buffers while dispatching to the native platform API.
#borrow(source_utf8, source_wide)
extern "c" fn native_apply(
  platform : Int,
  source_utf8 : Bytes,
  source_wide : Bytes,
  mode : Int,
) -> Int = "moonbit_wallpaper_apply"
