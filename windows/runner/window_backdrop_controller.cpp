#include "window_backdrop_controller.h"

#include <algorithm>
#include <dwmapi.h>

#pragma comment(lib, "dwmapi.lib")

namespace {

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

constexpr DWORD kWindows11Build = 22000;
constexpr DWORD kSystemBackdropBuild = 22621;
constexpr DWORD kDwmColorDefault = 0xFFFFFFFF;
constexpr DWORD kDwmColorNone = 0xFFFFFFFE;
constexpr int kDwmBackdropNone = 1;
constexpr int kDwmBackdropMainWindow = 2;
constexpr int kDwmBackdropTransientWindow = 3;
constexpr int kDwmBackdropTabbedWindow = 4;
constexpr DWORD kDwmCornerDoNotRound = 1;
constexpr DWORD kDwmCornerRound = 2;

enum AccentState {
  kAccentDisabled = 0,
  kAccentEnableGradient = 1,
  kAccentEnableTransparentGradient = 2,
  kAccentEnableBlurBehind = 3,
  kAccentEnableAcrylicBlurBehind = 4,
};

struct AccentPolicy {
  int state;
  int flags;
  DWORD gradient_color;
  int animation_id;
};

enum WindowCompositionAttribute {
  kWindowCompositionAttributeAccentPolicy = 19,
};

struct WindowCompositionAttributeData {
  WindowCompositionAttribute attribute;
  void* data;
  SIZE_T size_of_data;
};

using SetWindowCompositionAttributeFn = BOOL(WINAPI*)(
    HWND, WindowCompositionAttributeData*);

SetWindowCompositionAttributeFn GetAccentPolicyApi() {
  static const auto function = reinterpret_cast<SetWindowCompositionAttributeFn>(
      ::GetProcAddress(::GetModuleHandleW(L"user32.dll"),
                       "SetWindowCompositionAttribute"));
  return function;
}

DWORD DetectWindowsBuild() {
  using RtlGetVersionFn = LONG(WINAPI*)(OSVERSIONINFOW*);
  const auto rtl_get_version = reinterpret_cast<RtlGetVersionFn>(
      ::GetProcAddress(::GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
  if (!rtl_get_version) {
    return 0;
  }

  OSVERSIONINFOW version{};
  version.dwOSVersionInfoSize = sizeof(version);
  return rtl_get_version(&version) == 0 ? version.dwBuildNumber : 0;
}

bool IsTransparencyEnabled() {
  DWORD value = 1;
  DWORD value_size = sizeof(value);
  const LSTATUS status = ::RegGetValueW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"EnableTransparency", RRF_RT_REG_DWORD, nullptr, &value, &value_size);
  return status != ERROR_SUCCESS || value != 0;
}

bool IsHighContrastEnabled() {
  HIGHCONTRASTW high_contrast{};
  high_contrast.cbSize = sizeof(high_contrast);
  return ::SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(high_contrast),
                                 &high_contrast, 0) != FALSE &&
         (high_contrast.dwFlags & HCF_HIGHCONTRASTON) != 0;
}

DWORD MakeGradientColor(int alpha, bool dark_mode) {
  const BYTE clamped_alpha =
      static_cast<BYTE>(std::clamp(alpha, 0, 255));
  const COLORREF tint = dark_mode ? RGB(32, 32, 32) : RGB(243, 243, 243);
  return (static_cast<DWORD>(clamped_alpha) << 24) |
         (static_cast<DWORD>(GetBValue(tint)) << 16) |
         (static_cast<DWORD>(GetGValue(tint)) << 8) |
         static_cast<DWORD>(GetRValue(tint));
}

HRESULT BoolResultToHresult(BOOL result) {
  if (result != FALSE) {
    return S_OK;
  }
  const DWORD error = ::GetLastError();
  return error == ERROR_SUCCESS ? E_FAIL : HRESULT_FROM_WIN32(error);
}

bool IsSystemMaterial(WindowBackdropKind kind) {
  return kind == WindowBackdropKind::kAcrylic ||
         kind == WindowBackdropKind::kMica ||
         kind == WindowBackdropKind::kMicaAlt;
}

}  // namespace

WindowBackdropController::WindowBackdropController(HWND window,
                                                   WindowBackdropRole role)
    : window_(window), role_(role), capabilities_(DetectCapabilities()) {}

WindowBackdropController::~WindowBackdropController() {
  if (!window_ || !::IsWindow(window_)) {
    return;
  }
  DisableLegacyAccent();
  ResetSystemBackdrop();
}

WindowBackdropCapabilities WindowBackdropController::DetectCapabilities() {
  WindowBackdropCapabilities capabilities;
  capabilities.windows_build = DetectWindowsBuild();
  capabilities.is_windows_11 =
      capabilities.windows_build >= kWindows11Build;
  capabilities.supports_system_backdrop =
      capabilities.windows_build >= kSystemBackdropBuild;

  BOOL composition_enabled = FALSE;
  capabilities.composition_enabled =
      SUCCEEDED(::DwmIsCompositionEnabled(&composition_enabled)) &&
      composition_enabled != FALSE;
  capabilities.transparency_enabled = IsTransparencyEnabled();
  capabilities.high_contrast = IsHighContrastEnabled();
  return capabilities;
}

const char* WindowBackdropController::KindName(WindowBackdropKind kind) {
  switch (kind) {
    case WindowBackdropKind::kBlur:
      return "blur";
    case WindowBackdropKind::kAcrylic:
      return "acrylic";
    case WindowBackdropKind::kMica:
      return "mica_main";
    case WindowBackdropKind::kMicaAlt:
      return "mica_transient";
    case WindowBackdropKind::kNone:
    default:
      return "none";
  }
}

HRESULT WindowBackdropController::PrepareTransparentHost() {
  if (!window_ || !::IsWindow(window_)) {
    return E_HANDLE;
  }

  // Establish the full-client DWM frame before the first Flutter scene. Apply
  // replaces this neutral host state with the configured material later.
  return ExtendFrame(true);
}

WindowBackdropKind WindowBackdropController::ResolveKind(
    WindowBackdropKind requested) const {
  if (role_ == WindowBackdropRole::kTrayMenu ||
      !capabilities_.composition_enabled ||
      !capabilities_.transparency_enabled || capabilities_.high_contrast) {
    return WindowBackdropKind::kNone;
  }

  if ((requested == WindowBackdropKind::kMica ||
       requested == WindowBackdropKind::kMicaAlt) &&
      !capabilities_.supports_system_backdrop) {
    return WindowBackdropKind::kAcrylic;
  }
  return requested;
}

WindowBackdropApplyResult WindowBackdropController::Apply(
    const WindowBackdropConfig& config, bool force) {
  if (!window_ || !::IsWindow(window_)) {
    return {config.kind, WindowBackdropKind::kNone, E_HANDLE, true};
  }

  if (force) {
    capabilities_ = DetectCapabilities();
  }
  if (!force && HasSameConfig(config)) {
    WindowBackdropApplyResult cached = last_result_;
    cached.hresult = S_FALSE;
    return cached;
  }

  const WindowBackdropKind requested = config.kind;
  WindowBackdropKind applied = ResolveKind(requested);
  bool used_fallback = applied != requested;

  ConfigureFrame(config.dark_mode);

  const bool can_reassert_system_material =
      capabilities_.supports_system_backdrop && has_last_config_ &&
      IsSystemMaterial(applied) &&
      IsSystemMaterial(last_result_.applied_kind);

  HRESULT result = S_OK;
  if (can_reassert_system_material) {
    // Reapplying a documented DWM system material is idempotent. Avoid
    // clearing a valid backdrop first: a transient Set failure after Reset
    // would otherwise leave a visible window permanently on None.
    result = ExtendFrame(true);
    if (SUCCEEDED(result)) {
      result = ApplySystemBackdrop(applied);
    }
  } else {
    // SetWindowCompositionAttribute can clear a DWM material even when every
    // API call reports success. Only cross-family transitions need a reset.
    DisableLegacyAccent();
    const HRESULT reset_result = ResetSystemBackdrop();
    // The tray menu has no native material, but its Flutter scene still uses
    // per-pixel alpha for the panels and shadows. Collapsing the DWM frame for
    // a `None` tray backdrop turns those transparent pixels into an opaque
    // black host rectangle.
    const bool needs_transparent_host =
        role_ == WindowBackdropRole::kTrayMenu ||
        applied != WindowBackdropKind::kNone;
    result = ExtendFrame(needs_transparent_host);

    if (SUCCEEDED(result) && capabilities_.supports_system_backdrop &&
        IsSystemMaterial(applied)) {
      result = ApplySystemBackdrop(applied);
    } else if (SUCCEEDED(result) &&
               (applied == WindowBackdropKind::kBlur ||
                applied == WindowBackdropKind::kAcrylic)) {
      result = ApplyLegacyAccent(applied, config.alpha, config.dark_mode);
    } else if (applied == WindowBackdropKind::kNone) {
      result = FAILED(reset_result) ? reset_result : result;
    }
  }

  if (FAILED(result) && applied != WindowBackdropKind::kNone) {
    used_fallback = true;
    applied = WindowBackdropKind::kNone;
    DisableLegacyAccent();
    ResetSystemBackdrop();
    ExtendFrame(role_ == WindowBackdropRole::kTrayMenu);
  }

  ApplyCorners(config);

  last_config_ = config;
  last_result_ = {requested, applied, result, used_fallback};
  has_last_config_ = true;
  legacy_effect_suspended_ = false;
  return last_result_;
}

WindowBackdropApplyResult WindowBackdropController::Refresh() {
  if (has_last_config_) {
    return Apply(last_config_, true);
  }
  return last_result_;
}

void WindowBackdropController::UpdateWindowGeometry() {
  if (has_last_config_) {
    ApplyCorners(last_config_);
  }
}

bool WindowBackdropController::SuspendLegacyEffectForMove() {
  if (!has_last_config_ || legacy_effect_suspended_ ||
      capabilities_.supports_system_backdrop ||
      (last_result_.applied_kind != WindowBackdropKind::kBlur &&
       last_result_.applied_kind != WindowBackdropKind::kAcrylic)) {
    return false;
  }

  const auto set_accent = GetAccentPolicyApi();
  if (!set_accent) {
    return false;
  }

  AccentPolicy policy{};
  policy.state = kAccentEnableTransparentGradient;
  policy.flags = 2;
  policy.gradient_color = MakeGradientColor(240, last_config_.dark_mode);
  WindowCompositionAttributeData data{
      kWindowCompositionAttributeAccentPolicy, &policy, sizeof(policy)};
  legacy_effect_suspended_ = set_accent(window_, &data) != FALSE;
  return legacy_effect_suspended_;
}

void WindowBackdropController::ResumeLegacyEffectAfterMove() {
  if (!legacy_effect_suspended_) {
    return;
  }
  legacy_effect_suspended_ = false;
  Apply(last_config_, true);
}

HRESULT WindowBackdropController::ApplySystemBackdrop(
    WindowBackdropKind kind) {
  int backdrop = kDwmBackdropNone;
  switch (kind) {
    case WindowBackdropKind::kMica:
      backdrop = kDwmBackdropMainWindow;
      break;
    case WindowBackdropKind::kAcrylic:
      backdrop = kDwmBackdropTransientWindow;
      break;
    case WindowBackdropKind::kMicaAlt:
      backdrop = kDwmBackdropTabbedWindow;
      break;
    default:
      break;
  }
  return ::DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(DWMWA_SYSTEMBACKDROP_TYPE),
      &backdrop, sizeof(backdrop));
}

HRESULT WindowBackdropController::ApplyLegacyAccent(WindowBackdropKind kind,
                                                    int alpha,
                                                    bool dark_mode) {
  const auto set_accent = GetAccentPolicyApi();
  if (!set_accent) {
    return E_NOTIMPL;
  }

  AccentPolicy policy{};
  policy.state = kind == WindowBackdropKind::kAcrylic
                     ? kAccentEnableAcrylicBlurBehind
                     : kAccentEnableBlurBehind;
  policy.flags = 2;
  policy.gradient_color = MakeGradientColor(alpha, dark_mode);
  WindowCompositionAttributeData data{
      kWindowCompositionAttributeAccentPolicy, &policy, sizeof(policy)};
  return BoolResultToHresult(set_accent(window_, &data));
}

HRESULT WindowBackdropController::DisableLegacyAccent() {
  const auto set_accent = GetAccentPolicyApi();
  if (!set_accent) {
    return S_FALSE;
  }

  AccentPolicy policy{};
  policy.state = kAccentDisabled;
  WindowCompositionAttributeData data{
      kWindowCompositionAttributeAccentPolicy, &policy, sizeof(policy)};
  return BoolResultToHresult(set_accent(window_, &data));
}

HRESULT WindowBackdropController::ResetSystemBackdrop() {
  if (!capabilities_.supports_system_backdrop) {
    return S_FALSE;
  }
  int backdrop = kDwmBackdropNone;
  return ::DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(DWMWA_SYSTEMBACKDROP_TYPE),
      &backdrop, sizeof(backdrop));
}

HRESULT WindowBackdropController::ExtendFrame(bool transparent) {
  const MARGINS margins =
      transparent ? MARGINS{-1, -1, -1, -1} : MARGINS{0, 0, 0, 0};
  return ::DwmExtendFrameIntoClientArea(window_, &margins);
}

void WindowBackdropController::ConfigureFrame(bool dark_mode) {
  const BOOL dark = dark_mode ? TRUE : FALSE;
  ::DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(DWMWA_USE_IMMERSIVE_DARK_MODE),
      &dark, sizeof(dark));

  const DWORD caption_color = kDwmColorNone;
  ::DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(DWMWA_CAPTION_COLOR),
      &caption_color, sizeof(caption_color));

  const DWORD border_color = capabilities_.high_contrast
                                 ? kDwmColorDefault
                                 : kDwmColorNone;
  ::DwmSetWindowAttribute(
      window_, static_cast<DWMWINDOWATTRIBUTE>(DWMWA_BORDER_COLOR),
      &border_color, sizeof(border_color));
}

void WindowBackdropController::ApplyCorners(
    const WindowBackdropConfig& config) {
  if (role_ == WindowBackdropRole::kTrayMenu) {
    // Flutter owns the disjoint main/submenu silhouettes. Native rounding or
    // regions would clip the antialiased panel shadows to the rectangular HWND.
    ::SetWindowRgn(window_, nullptr, TRUE);
    if (capabilities_.is_windows_11) {
      const DWORD preference = kDwmCornerDoNotRound;
      ::DwmSetWindowAttribute(
          window_,
          static_cast<DWMWINDOWATTRIBUTE>(DWMWA_WINDOW_CORNER_PREFERENCE),
          &preference, sizeof(preference));
    }
    return;
  }

  RECT rect{};
  if (!::GetWindowRect(window_, &rect)) {
    return;
  }
  const int width = rect.right - rect.left;
  const int height = rect.bottom - rect.top;
  if (width <= 0 || height <= 0) {
    return;
  }

  WINDOWPLACEMENT placement{};
  placement.length = sizeof(placement);
  ::GetWindowPlacement(window_, &placement);
  const bool maximized = placement.showCmd == SW_MAXIMIZE;

  if (capabilities_.is_windows_11) {
    const DWORD preference = config.rounded_corners_enabled && !maximized
                                 ? kDwmCornerRound
                                 : kDwmCornerDoNotRound;
    ::DwmSetWindowAttribute(
        window_,
        static_cast<DWMWINDOWATTRIBUTE>(DWMWA_WINDOW_CORNER_PREFERENCE),
        &preference, sizeof(preference));
    return;
  }

  if (!config.rounded_corners_enabled || maximized) {
    ::SetWindowRgn(window_, nullptr, TRUE);
    return;
  }

  const UINT dpi = ::GetDpiForWindow(window_);
  const int radius = std::max(
      1, ::MulDiv(std::max(4, config.corner_radius), dpi == 0 ? 96 : dpi, 96));
  HRGN region =
      ::CreateRoundRectRgn(0, 0, width + 1, height + 1, radius * 2, radius * 2);
  if (region) {
    ::SetWindowRgn(window_, region, TRUE);
  }
}

bool WindowBackdropController::HasSameConfig(
    const WindowBackdropConfig& config) const {
  return has_last_config_ && last_config_.kind == config.kind &&
         last_config_.alpha == config.alpha &&
         last_config_.dark_mode == config.dark_mode &&
         last_config_.rounded_corners_enabled ==
             config.rounded_corners_enabled &&
         last_config_.corner_radius == config.corner_radius;
}
