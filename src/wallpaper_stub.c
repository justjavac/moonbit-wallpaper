#include <moonbit.h>

#include <stdint.h>

/* Status values must stay in sync with WallpaperStatus in MoonBit. */
#define WALLPAPER_STATUS_APPLIED 0
#define WALLPAPER_STATUS_UNSUPPORTED_PLATFORM 1
#define WALLPAPER_STATUS_UNSUPPORTED_DESKTOP 2
#define WALLPAPER_STATUS_INVALID_SOURCE 3
#define WALLPAPER_STATUS_NATIVE_FAILURE 4

/* Platform values must stay in sync with Platform in MoonBit. */
#define WALLPAPER_PLATFORM_WINDOWS 0
#define WALLPAPER_PLATFORM_MACOS 1
#define WALLPAPER_PLATFORM_LINUX 2
#define WALLPAPER_PLATFORM_UNKNOWN 3

/* Mode values must stay in sync with Mode in MoonBit. */
#define WALLPAPER_MODE_FILL 0
#define WALLPAPER_MODE_FIT 1
#define WALLPAPER_MODE_STRETCH 2
#define WALLPAPER_MODE_CENTER 3
#define WALLPAPER_MODE_SPAN 4

#if defined(_WIN32)

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <wchar.h>

#if defined(_MSC_VER)
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "user32.lib")
#endif

/* Windows stores wallpaper placement as numeric strings in the registry. */
static const wchar_t *wallpaper_windows_style(int32_t mode) {
  switch (mode) {
  case WALLPAPER_MODE_FILL:
    return L"10";
  case WALLPAPER_MODE_FIT:
    return L"6";
  case WALLPAPER_MODE_STRETCH:
    return L"2";
  case WALLPAPER_MODE_CENTER:
    return L"0";
  case WALLPAPER_MODE_SPAN:
    return L"22";
  default:
    return L"10";
  }
}

static int wallpaper_windows_set_string(
    HKEY key,
    const wchar_t *name,
    const wchar_t *value) {
  DWORD bytes = (DWORD)((wcslen(value) + 1) * sizeof(wchar_t));
  LSTATUS status = RegSetValueExW(
      key,
      name,
      0,
      REG_SZ,
      (const BYTE *)value,
      bytes);
  return status == ERROR_SUCCESS;
}

static int32_t wallpaper_apply_windows(const wchar_t *source, int32_t mode) {
  if (source == NULL || source[0] == L'\0') {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  HKEY key = NULL;
  LSTATUS open_status = RegCreateKeyExW(
      HKEY_CURRENT_USER,
      L"Control Panel\\Desktop",
      0,
      NULL,
      0,
      KEY_SET_VALUE,
      NULL,
      &key,
      NULL);
  if (open_status != ERROR_SUCCESS) {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  /* Set the placement first, then ask the shell to apply and broadcast it. */
  int ok =
      wallpaper_windows_set_string(
          key, L"WallpaperStyle", wallpaper_windows_style(mode)) &&
      wallpaper_windows_set_string(key, L"TileWallpaper", L"0");
  RegCloseKey(key);
  if (!ok) {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  BOOL applied = SystemParametersInfoW(
      SPI_SETDESKWALLPAPER,
      0,
      (void *)source,
      SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
  return applied ? WALLPAPER_STATUS_APPLIED : WALLPAPER_STATUS_NATIVE_FAILURE;
}

#endif /* defined(_WIN32) */

#if defined(__APPLE__) && defined(__MACH__)

#include <dlfcn.h>

typedef void *wallpaper_id;
typedef void *wallpaper_class;
typedef void *wallpaper_sel;
typedef signed char wallpaper_bool;
typedef unsigned long wallpaper_ulong;

/* AppKit is loaded lazily so the native stub links without a macOS SDK step. */
static int32_t wallpaper_apply_macos(const char *source, int32_t mode) {
  (void)mode;

  void *foundation = dlopen(
      "/System/Library/Frameworks/Foundation.framework/Foundation",
      RTLD_LAZY | RTLD_GLOBAL);
  void *appkit = dlopen(
      "/System/Library/Frameworks/AppKit.framework/AppKit",
      RTLD_LAZY | RTLD_GLOBAL);
  void *objc = dlopen("/usr/lib/libobjc.A.dylib", RTLD_LAZY | RTLD_GLOBAL);
  if (foundation == NULL || appkit == NULL || objc == NULL) {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  /* Resolve just the Objective-C runtime entry points this bridge needs. */
  wallpaper_class (*objc_getClass_fn)(const char *) =
      (wallpaper_class(*)(const char *))dlsym(objc, "objc_getClass");
  wallpaper_sel (*sel_registerName_fn)(const char *) =
      (wallpaper_sel(*)(const char *))dlsym(objc, "sel_registerName");
  void *msg = dlsym(objc, "objc_msgSend");
  if (objc_getClass_fn == NULL || sel_registerName_fn == NULL || msg == NULL) {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  /* Give objc_msgSend typed call shapes for the selectors used below. */
  wallpaper_id (*msg_class_id)(wallpaper_class, wallpaper_sel) =
      (wallpaper_id(*)(wallpaper_class, wallpaper_sel))msg;
  wallpaper_id (*msg_class_cstr)(wallpaper_class, wallpaper_sel, const char *) =
      (wallpaper_id(*)(wallpaper_class, wallpaper_sel, const char *))msg;
  wallpaper_id (*msg_class_id_arg)(
      wallpaper_class, wallpaper_sel, wallpaper_id) =
      (wallpaper_id(*)(wallpaper_class, wallpaper_sel, wallpaper_id))msg;
  wallpaper_ulong (*msg_count)(wallpaper_id, wallpaper_sel) =
      (wallpaper_ulong(*)(wallpaper_id, wallpaper_sel))msg;
  wallpaper_id (*msg_object_at_index)(
      wallpaper_id, wallpaper_sel, wallpaper_ulong) =
      (wallpaper_id(*)(wallpaper_id, wallpaper_sel, wallpaper_ulong))msg;
  wallpaper_bool (*msg_set_desktop)(
      wallpaper_id,
      wallpaper_sel,
      wallpaper_id,
      wallpaper_id,
      wallpaper_id,
      wallpaper_id *) =
      (wallpaper_bool(*)(
          wallpaper_id,
          wallpaper_sel,
          wallpaper_id,
          wallpaper_id,
          wallpaper_id,
          wallpaper_id *))msg;
  void (*msg_void)(wallpaper_id, wallpaper_sel) =
      (void(*)(wallpaper_id, wallpaper_sel))msg;

  /* Mirror the small Objective-C call chain used by NSWorkspace. */
  wallpaper_class pool_class = objc_getClass_fn("NSAutoreleasePool");
  wallpaper_class string_class = objc_getClass_fn("NSString");
  wallpaper_class url_class = objc_getClass_fn("NSURL");
  wallpaper_class workspace_class = objc_getClass_fn("NSWorkspace");
  wallpaper_class screen_class = objc_getClass_fn("NSScreen");
  if (pool_class == NULL ||
      string_class == NULL ||
      url_class == NULL ||
      workspace_class == NULL ||
      screen_class == NULL) {
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  wallpaper_id pool = msg_class_id(pool_class, sel_registerName_fn("new"));
  wallpaper_id path = msg_class_cstr(
      string_class,
      sel_registerName_fn("stringWithUTF8String:"),
      source);
  wallpaper_id url = msg_class_id_arg(
      url_class,
      sel_registerName_fn("fileURLWithPath:"),
      path);
  wallpaper_id workspace = msg_class_id(
      workspace_class,
      sel_registerName_fn("sharedWorkspace"));
  wallpaper_id screens = msg_class_id(
      screen_class,
      sel_registerName_fn("screens"));

  if (path == NULL || url == NULL || workspace == NULL || screens == NULL) {
    if (pool != NULL) {
      msg_void(pool, sel_registerName_fn("drain"));
    }
    return WALLPAPER_STATUS_NATIVE_FAILURE;
  }

  wallpaper_ulong count = msg_count(screens, sel_registerName_fn("count"));
  if (count == 0) {
    if (pool != NULL) {
      msg_void(pool, sel_registerName_fn("drain"));
    }
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }

  wallpaper_sel apply_sel =
      sel_registerName_fn("setDesktopImageURL:forScreen:options:error:");
  int ok = 1;

  for (wallpaper_ulong i = 0; i < count; i++) {
    wallpaper_id screen = msg_object_at_index(
        screens,
        sel_registerName_fn("objectAtIndex:"),
        i);
    wallpaper_id error = NULL;
    wallpaper_bool applied = msg_set_desktop(
        workspace,
        apply_sel,
        url,
        screen,
        NULL,
        &error);
    if (!applied) {
      ok = 0;
      break;
    }
  }

  if (pool != NULL) {
    msg_void(pool, sel_registerName_fn("drain"));
  }
  return ok ? WALLPAPER_STATUS_APPLIED : WALLPAPER_STATUS_NATIVE_FAILURE;
}

#endif /* defined(__APPLE__) && defined(__MACH__) */

#if defined(__linux__)

#include <dlfcn.h>

typedef void *(*wallpaper_g_settings_new_fn)(const char *);
typedef int (*wallpaper_g_settings_set_string_fn)(
    void *,
    const char *,
    const char *);
typedef void (*wallpaper_g_object_unref_fn)(void *);
typedef void *(*wallpaper_schema_source_default_fn)(void);
typedef void *(*wallpaper_schema_source_lookup_fn)(void *, const char *, int);
typedef void (*wallpaper_schema_unref_fn)(void *);

/* GNOME GSettings uses these string tokens for picture-options. */
static const char *wallpaper_linux_mode_token(int32_t mode) {
  switch (mode) {
  case WALLPAPER_MODE_FILL:
    return "zoom";
  case WALLPAPER_MODE_FIT:
    return "scaled";
  case WALLPAPER_MODE_STRETCH:
    return "stretched";
  case WALLPAPER_MODE_CENTER:
    return "centered";
  case WALLPAPER_MODE_SPAN:
    return "spanned";
  default:
    return "zoom";
  }
}

static int32_t wallpaper_apply_linux(const char *source, int32_t mode) {
  /* Load GLib/GIO dynamically so unsupported desktops fail gracefully. */
  void *gio = dlopen("libgio-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
  void *gobject = dlopen("libgobject-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
  if (gio == NULL || gobject == NULL) {
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }

  wallpaper_schema_source_default_fn schema_source_get_default =
      (wallpaper_schema_source_default_fn)dlsym(
          gio,
          "g_settings_schema_source_get_default");
  wallpaper_schema_source_lookup_fn schema_source_lookup =
      (wallpaper_schema_source_lookup_fn)dlsym(
          gio,
          "g_settings_schema_source_lookup");
  wallpaper_schema_unref_fn schema_unref =
      (wallpaper_schema_unref_fn)dlsym(gio, "g_settings_schema_unref");
  wallpaper_g_settings_new_fn settings_new =
      (wallpaper_g_settings_new_fn)dlsym(gio, "g_settings_new");
  wallpaper_g_settings_set_string_fn settings_set_string =
      (wallpaper_g_settings_set_string_fn)dlsym(gio, "g_settings_set_string");
  wallpaper_g_object_unref_fn object_unref =
      (wallpaper_g_object_unref_fn)dlsym(gobject, "g_object_unref");
  if (schema_source_get_default == NULL ||
      schema_source_lookup == NULL ||
      schema_unref == NULL ||
      settings_new == NULL ||
      settings_set_string == NULL ||
      object_unref == NULL) {
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }

  void *schema_source = schema_source_get_default();
  if (schema_source == NULL) {
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }

  /* Presence of the schema is the practical GNOME desktop capability check. */
  void *schema = schema_source_lookup(
      schema_source,
      "org.gnome.desktop.background",
      1);
  if (schema == NULL) {
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }
  schema_unref(schema);

  void *settings = settings_new("org.gnome.desktop.background");
  if (settings == NULL) {
    return WALLPAPER_STATUS_UNSUPPORTED_DESKTOP;
  }

  int ok_uri = settings_set_string(settings, "picture-uri", source);
  int ok_mode = settings_set_string(
      settings,
      "picture-options",
      wallpaper_linux_mode_token(mode));
  object_unref(settings);
  return (ok_uri && ok_mode) ? WALLPAPER_STATUS_APPLIED
                             : WALLPAPER_STATUS_NATIVE_FAILURE;
}

#endif /* defined(__linux__) */

/* Dispatch from the MoonBit-facing ABI to the platform implementation. */
MOONBIT_FFI_EXPORT
int32_t moonbit_wallpaper_apply(
    int32_t platform,
    moonbit_bytes_t source_utf8,
    moonbit_bytes_t source_wide,
    int32_t mode) {
  /* justjavac/ffi passes NUL-terminated byte buffers for C strings. */
  if (Moonbit_array_length(source_utf8) <= 1) {
    return WALLPAPER_STATUS_INVALID_SOURCE;
  }
  const char *source_text = (const char *)source_utf8;

  int32_t status = WALLPAPER_STATUS_UNSUPPORTED_PLATFORM;
  switch (platform) {
  case WALLPAPER_PLATFORM_WINDOWS:
#if defined(_WIN32)
    if (Moonbit_array_length(source_wide) <= 2) {
      status = WALLPAPER_STATUS_INVALID_SOURCE;
    } else {
      status = wallpaper_apply_windows((const wchar_t *)source_wide, mode);
    }
#else
    status = WALLPAPER_STATUS_UNSUPPORTED_PLATFORM;
#endif
    break;
  case WALLPAPER_PLATFORM_MACOS:
#if defined(__APPLE__) && defined(__MACH__)
    status = wallpaper_apply_macos(source_text, mode);
#else
    status = WALLPAPER_STATUS_UNSUPPORTED_PLATFORM;
#endif
    break;
  case WALLPAPER_PLATFORM_LINUX:
#if defined(__linux__)
    status = wallpaper_apply_linux(source_text, mode);
#else
    status = WALLPAPER_STATUS_UNSUPPORTED_PLATFORM;
#endif
    break;
  default:
    status = WALLPAPER_STATUS_UNSUPPORTED_PLATFORM;
    break;
  }

  return status;
}
