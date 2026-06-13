#include "flutter_window.h"

#include <algorithm>
#include <optional>
#include <cstdio>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <thread>
#include <vector>
#include <stdio.h>
#include <string.h>
#include <dwmapi.h>
#include <windows.h>
#include <shobjidl.h>
#include <shlobj.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "single_instance_manager.h"

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

#ifndef DWMWA_NCRENDERING_POLICY
#define DWMWA_NCRENDERING_POLICY 2
#endif

#ifndef DWMWA_ALLOW_NCPAINT
#define DWMWA_ALLOW_NCPAINT 4
#endif

#ifndef DWMNCRP_DISABLED
#define DWMNCRP_DISABLED 2
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_MICA_EFFECT
#define DWMWA_MICA_EFFECT 1029
#endif

#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif

#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif

#ifndef DWMWA_COLOR_NONE
#define DWMWA_COLOR_NONE 0xFFFFFFFE
#endif

// Windows version detection
typedef LONG NTSTATUS;
#define STATUS_SUCCESS ((NTSTATUS)0x00000000L)
typedef NTSTATUS(WINAPI* RtlGetVersionPtr)(PRTL_OSVERSIONINFOW);

static DWORD GetWindowsBuildNumber() {
  static DWORD buildNumber = 0;
  if (buildNumber == 0) {
    HMODULE hmodule = ::GetModuleHandleW(L"ntdll.dll");
    if (hmodule) {
      RtlGetVersionPtr rtl_get_version = (RtlGetVersionPtr)::GetProcAddress(hmodule, "RtlGetVersion");
      if (rtl_get_version) {
        RTL_OSVERSIONINFOW rovi = {0};
        rovi.dwOSVersionInfoSize = sizeof(rovi);
        if (STATUS_SUCCESS == rtl_get_version(&rovi)) {
          buildNumber = rovi.dwBuildNumber;
        }
      }
    }
  }
  return buildNumber;
}

typedef enum ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_ENABLE_HOSTBACKDROP = 5
} ACCENT_STATE;

typedef struct ACCENT_POLICY {
  int AccentState;
  int AccentFlags;
  int GradientColor;
  int AnimationId;
} ACCENT_POLICY;

typedef struct WINDOWCOMPOSITIONATTRIBUTEDATA {
  int Attribute;
  void* Data;
  size_t SizeOfData;
} WINDOWCOMPOSITIONATTRIBUTEDATA;

static BOOL (WINAPI* pSetWindowCompositionAttribute)(HWND, WINDOWCOMPOSITIONATTRIBUTEDATA*) = nullptr;

constexpr int kEffectNone = 0;
constexpr int kEffectBlur = 1;
constexpr int kEffectAcrylic = 2;
constexpr int kEffectMica = 3;
constexpr int kEffectMicaAlt = 4;

constexpr DWORD kWin11Build = 22000;
constexpr DWORD kSystemBackdropBuild = 22621;

constexpr INT kDwmSystemBackdropNone = 1;
constexpr INT kDwmSystemBackdropMainWindow = 2;
constexpr INT kDwmSystemBackdropTransientWindow = 3;
constexpr INT kDwmSystemBackdropTabbedWindow = 4;

constexpr DWORD kDwmCornerDoNotRound = 1;
constexpr DWORD kDwmCornerRound = 2;

constexpr COLORREF kDwmColorNone = 0xFFFFFFFE;
constexpr COLORREF kDwmBorderFallbackColor = RGB(0, 0, 0);

static bool LoadAccentPolicyApi() {
  if (pSetWindowCompositionAttribute) {
    return true;
  }

  HMODULE user32 = ::GetModuleHandleA("user32.dll");
  if (!user32) {
    user32 = ::LoadLibraryA("user32.dll");
  }
  if (!user32) {
    return false;
  }

  pSetWindowCompositionAttribute =
      reinterpret_cast<BOOL(WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBUTEDATA*)>(
          ::GetProcAddress(user32, "SetWindowCompositionAttribute"));
  return pSetWindowCompositionAttribute != nullptr;
}

static BOOL DisableAccentPolicy(HWND hwnd) {
  if (!LoadAccentPolicyApi()) {
    return FALSE;
  }
  ACCENT_POLICY policy{};
  policy.AccentState = ACCENT_DISABLED;
  policy.AccentFlags = 0;
  policy.GradientColor = 0;
  policy.AnimationId = 0;
  WINDOWCOMPOSITIONATTRIBUTEDATA data{};
  data.Attribute = 19;
  data.Data = &policy;
  data.SizeOfData = sizeof(policy);
  return pSetWindowCompositionAttribute(hwnd, &data);
}

static DWORD MakeAccentGradientColor(unsigned int alpha, COLORREF rgb) {
  const unsigned int r = GetRValue(rgb);
  const unsigned int g = GetGValue(rgb);
  const unsigned int b = GetBValue(rgb);
  return ((alpha & 0xFF) << 24) | (b << 16) | (g << 8) | r;
}

static COLORREF EffectTintColor(bool dark_mode) {
  return dark_mode ? RGB(32, 32, 32) : RGB(243, 248, 252);
}

static INT DwmBackdropForEffect(int effect_mode) {
  switch (effect_mode) {
    case kEffectAcrylic:
      return kDwmSystemBackdropTransientWindow;
    case kEffectMica:
      return kDwmSystemBackdropMainWindow;
    case kEffectMicaAlt:
      return kDwmSystemBackdropTabbedWindow;
    default:
      return kDwmSystemBackdropNone;
  }
}

static bool IsDwmBackdropEffect(int effect_mode) {
  return effect_mode == kEffectMica || effect_mode == kEffectMicaAlt;
}

static bool IsAccentEffect(int effect_mode) {
  return effect_mode == kEffectBlur || effect_mode == kEffectAcrylic;
}

static int ScaleForWindowDpi(HWND hwnd, int logical_pixels) {
  if (!hwnd || logical_pixels <= 0) {
    return logical_pixels;
  }
  const UINT dpi = ::GetDpiForWindow(hwnd);
  return std::max(1, ::MulDiv(logical_pixels, dpi == 0 ? 96 : dpi, 96));
}

static void ExtendFrameForEffect(HWND hwnd, bool transparent_frame) {
  if (!hwnd) {
    return;
  }

  MARGINS margins = transparent_frame ? MARGINS{-1, -1, -1, -1}
                                      : MARGINS{0, 0, 1, 0};
  ::DwmExtendFrameIntoClientArea(hwnd, &margins);
}

static void ResetDwmBackdrop(HWND hwnd, DWORD buildNumber) {
  if (!hwnd) {
    return;
  }

  if (buildNumber >= kSystemBackdropBuild) {
    INT backdropType = kDwmSystemBackdropNone;
    ::DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdropType,
                            sizeof(backdropType));
  }
  if (buildNumber >= kWin11Build) {
    BOOL mica = FALSE;
    ::DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
  }
}

static void ConfigureDwmFrame(HWND hwnd, bool dark_mode) {
  if (!hwnd) {
    return;
  }

  BOOL dark = dark_mode ? TRUE : FALSE;
  ::DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                          sizeof(dark));
  ::DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, &kDwmColorNone,
                          sizeof(kDwmColorNone));
  COLORREF borderColor = kDwmBorderFallbackColor;
  ::DwmSetWindowAttribute(hwnd, DWMWA_BORDER_COLOR, &borderColor,
                          sizeof(borderColor));
}

static void PaintNativeFrameStrips(HWND hwnd) {
  if (!hwnd) {
    return;
  }

  RECT windowRect{};
  RECT clientRect{};
  if (!GetWindowRect(hwnd, &windowRect) || !GetClientRect(hwnd, &clientRect)) {
    return;
  }

  POINT clientOrigin{clientRect.left, clientRect.top};
  ClientToScreen(hwnd, &clientOrigin);

  const int windowWidth = windowRect.right - windowRect.left;
  const int windowHeight = windowRect.bottom - windowRect.top;
  const int clientLeft = clientOrigin.x - windowRect.left;
  const int clientTop = clientOrigin.y - windowRect.top;
  const int clientRight = clientLeft + (clientRect.right - clientRect.left);
  const int clientBottom = clientTop + (clientRect.bottom - clientRect.top);

  HDC dc = GetWindowDC(hwnd);
  if (!dc) {
    return;
  }

  HBRUSH brush = CreateSolidBrush(RGB(0, 0, 0));
  if (!brush) {
    ReleaseDC(hwnd, dc);
    return;
  }

  auto fill = [&](int left, int top, int right, int bottom) {
    if (right <= left || bottom <= top) {
      return;
    }
    RECT rect{left, top, right, bottom};
    FillRect(dc, &rect, brush);
  };

  fill(0, 0, clientLeft, windowHeight);
  fill(clientRight, 0, windowWidth, windowHeight);
  fill(clientLeft, 0, clientRight, clientTop);
  fill(clientLeft, clientBottom, clientRight, windowHeight);

  DeleteObject(brush);
  ReleaseDC(hwnd, dc);
}

static bool ApplyAccentEffect(HWND hwnd,
                              int effect_mode,
                              int effect_alpha,
                              bool dark_mode,
                              bool limit_popup_alpha) {
  if (!hwnd || !LoadAccentPolicyApi() || !IsAccentEffect(effect_mode)) {
    return false;
  }

  ACCENT_POLICY policy{};
  policy.AccentState = effect_mode == kEffectBlur
                           ? ACCENT_ENABLE_BLURBEHIND
                           : ACCENT_ENABLE_ACRYLICBLURBEHIND;
  policy.AccentFlags = 2;
  unsigned int alpha =
      static_cast<unsigned int>(std::max(0, std::min(effect_alpha, 255)));
  if (limit_popup_alpha) {
    alpha = std::min(alpha, 120u);
  }
  if (effect_mode == kEffectBlur) {
    alpha = std::max(32u, std::min(alpha, 140u));
  } else if (effect_mode == kEffectAcrylic && limit_popup_alpha) {
    alpha = std::max(48u, alpha);
  }
  policy.GradientColor =
      MakeAccentGradientColor(alpha, EffectTintColor(dark_mode));
  policy.AnimationId = 0;

  WINDOWCOMPOSITIONATTRIBUTEDATA data{};
  data.Attribute = 19;
  data.Data = &policy;
  data.SizeOfData = sizeof(policy);
  return pSetWindowCompositionAttribute(hwnd, &data) != FALSE;
}

static void LogA(const char* s) {
  if (!IsNativeRenderLoggingEnabled()) {
    return;
  }

  SYSTEMTIME local_time;
  GetLocalTime(&local_time);

  char formatted[4096];
  sprintf_s(
      formatted, sizeof(formatted),
      "[%04d-%02d-%02dT%02d:%02d:%02d.%03d] [INFO] [Render] %s",
      local_time.wYear, local_time.wMonth, local_time.wDay,
      local_time.wHour, local_time.wMinute, local_time.wSecond,
      local_time.wMilliseconds, s);

  OutputDebugStringA(formatted);
  OutputDebugStringA("\n");

  // Write to log file (open, write, close each time to avoid locking)
  static bool initialized_for_process = false;
  char exePath[MAX_PATH] = {0};
  GetModuleFileNameA(NULL, exePath, MAX_PATH);
  char* slash = strrchr(exePath, '\\');
  if (slash) *(slash + 1) = '\0';
  strcat_s(exePath, MAX_PATH, "window_render.log");

  FILE* fp = nullptr;
  fopen_s(&fp, exePath, initialized_for_process ? "a" : "w");
  if (fp) {
    fprintf(fp, "%s\n", formatted);
    fclose(fp);
    initialized_for_process = true;
  }
}

namespace {

std::vector<std::unique_ptr<FlutterWindow>> g_popup_windows;
std::unique_ptr<FlutterWindow> g_tray_menu_window;
HWND g_main_window_handle = nullptr;
FlutterWindow* g_main_flutter_window = nullptr;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size_needed = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  if (size_needed <= 0) {
    return std::wstring(value.begin(), value.end());
  }

  std::wstring result(static_cast<size_t>(size_needed), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size_needed);
  return result;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }

  const int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  if (size_needed <= 0) {
    return std::string();
  }

  std::string result(static_cast<size_t>(size_needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size_needed, nullptr, nullptr);
  return result;
}

std::wstring GetWindowTitle(HWND hwnd) {
  if (!hwnd) {
    return L"";
  }

  const int length = GetWindowTextLengthW(hwnd);
  if (length <= 0) {
    return L"";
  }

  std::wstring title(static_cast<size_t>(length) + 1, L'\0');
  GetWindowTextW(hwnd, title.data(), length + 1);
  title.resize(static_cast<size_t>(length));
  return title;
}

void CleanupClosedPopupWindows() {
  g_popup_windows.erase(
      std::remove_if(
          g_popup_windows.begin(), g_popup_windows.end(),
          [](const std::unique_ptr<FlutterWindow>& window) {
            return window == nullptr || window->GetHandle() == nullptr;
          }),
      g_popup_windows.end());
}

bool TryExtractPayloadDouble(const std::string& payload_json,
                             const char* key,
                             double& out_value) {
  const std::string search = std::string("\"") + key + "\":";
  size_t pos = payload_json.find(search);
  if (pos == std::string::npos) {
    return false;
  }

  pos += search.size();
  while (pos < payload_json.size() &&
         (payload_json[pos] == ' ' || payload_json[pos] == '\t')) {
    pos++;
  }
  if (pos >= payload_json.size()) {
    return false;
  }

  const size_t end = payload_json.find_first_of(",} \t\n\r", pos);
  const std::string value = payload_json.substr(pos, end - pos);
  char* endptr = nullptr;
  const double parsed = std::strtod(value.c_str(), &endptr);
  if (endptr == value.c_str()) {
    return false;
  }

  out_value = parsed;
  return true;
}

void PositionTrayMenuWindow(HWND hwnd, double target_x, double target_y) {
  if (!hwnd) {
    return;
  }

  RECT menu_rect{};
  GetWindowRect(hwnd, &menu_rect);
  const int menu_width = menu_rect.right - menu_rect.left;
  const int menu_height = menu_rect.bottom - menu_rect.top;

  int pos_x = static_cast<int>(target_x) - (menu_width / 2);
  int pos_y = static_cast<int>(target_y) - menu_height + 8;

  RECT work_area{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
  if (pos_x + menu_width > work_area.right) {
    pos_x = work_area.right - menu_width;
  }
  if (pos_x < work_area.left) {
    pos_x = work_area.left;
  }
  if (pos_y + menu_height > work_area.bottom) {
    pos_y = work_area.bottom - menu_height;
  }
  if (pos_y < work_area.top) {
    pos_y = work_area.top;
  }

  SetWindowPos(hwnd, HWND_TOPMOST, pos_x, pos_y, 0, 0,
               SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

void CenterWindowOnWorkArea(HWND hwnd) {
  if (!hwnd) {
    return;
  }

  RECT window_rect;
  if (!GetWindowRect(hwnd, &window_rect)) {
    return;
  }

  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  const HMONITOR monitor =
      MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const RECT& work_area = monitor_info.rcWork;
  const int width = window_rect.right - window_rect.left;
  const int height = window_rect.bottom - window_rect.top;
  const int x = work_area.left + ((work_area.right - work_area.left) - width) / 2;
  const int y = work_area.top + ((work_area.bottom - work_area.top) - height) / 2;

  SetWindowPos(hwnd, nullptr, x, y, 0, 0,
               SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOSIZE | SWP_NOZORDER);
}

}  // namespace

struct FlutterWindow::CloseExistingInstanceRequest {
  std::unique_ptr<flutter::MethodResult<>> result;
  bool success = false;
};

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             WindowKind kind,
                             bool launch_hidden)
    : project_(project), launch_hidden_(launch_hidden), kind_(kind) {
  if (kind_ == WindowKind::kPopup) {
    effect_mode_ = kEffectNone;
  }
  if (kind_ == WindowKind::kTrayMenu) {
    effect_mode_ = kEffectNone;
  }
}

FlutterWindow::~FlutterWindow() {}

const char* FlutterWindow::WindowKindName() const {
  switch (kind_) {
    case WindowKind::kPopup:
      return "popup";
    case WindowKind::kTrayMenu:
      return "tray";
    case WindowKind::kMain:
    default:
      return "main";
  }
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  char create_log[128];
  sprintf_s(create_log, "FlutterWindow::OnCreate begin kind=%s hwnd=%p",
            WindowKindName(), GetHandle());
  LogA(create_log);

  RECT frame = GetClientArea();

  // Call DwmExtendFrameIntoClientArea BEFORE creating FlutterViewController
  // This tells the Flutter 3.x engine on Windows to natively use a transparent
  // swapchain without needing the toxic WS_EX_LAYERED attribute!
  ExtendFrameForEffect(GetHandle(), true);

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  if (kind_ == WindowKind::kMain) {
    g_main_window_handle = GetHandle();
    g_main_flutter_window = this;
    RegisterPlugins(flutter_controller_->engine());
  }
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupMethodChannel();
  LogA("SetupMethodChannel done");

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    LogA("NextFrameCallback begin");
    HWND hwnd = GetHandle();
    if (!launch_hidden_) {
      if (kind_ == WindowKind::kPopup) {
        BringWindowToFront();
      } else if (kind_ == WindowKind::kTrayMenu) {
        this->Show();
      }
    } else {
      LogA("NextFrameCallback: skipping native show for auto-start launch");
    }
    ApplyWindowEffect(hwnd, true);
    ScheduleWindowEffectRefresh(hwnd);
    LogA("NextFrameCallback end");
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();
  LogA("ForceRedraw called");

  return true;
}

void FlutterWindow::OnDestroy() {
  char destroy_log[128];
  sprintf_s(destroy_log, "=== FlutterWindow::OnDestroy START kind=%s hwnd=%p ===",
            WindowKindName(), GetHandle());
  LogA(destroy_log);

  KillTimer(GetHandle(), kPopupInitialEffectTimer);
  KillTimer(GetHandle(), kWindowResizeEffectTimer);
  KillTimer(GetHandle(), kWindowEffectShowTimer);
  KillTimer(GetHandle(), kWindowEffectActivateTimer);
  KillTimer(GetHandle(), kWindowEffectSettledTimer);
  KillTimer(GetHandle(), kWindowFramePaintTimer);
  KillTimer(GetHandle(), kWindowFramePaintSettledTimer);

  if (pSetWindowCompositionAttribute) {
    ACCENT_POLICY policy{};
    policy.AccentState = 0; // ACCENT_DISABLED
    policy.AccentFlags = 0;
    policy.GradientColor = 0;
    policy.AnimationId = 0;
    WINDOWCOMPOSITIONATTRIBUTEDATA data{};
    data.Attribute = 19; // WCA_ACCENT_POLICY
    data.Data = &policy;
    data.SizeOfData = sizeof(policy);
    pSetWindowCompositionAttribute(GetHandle(), &data);
  }

  if (kind_ == WindowKind::kPopup) {
    RestorePreviousForegroundWindow();
  }
  if (clipboard_listener_registered_) {
    RemoveClipboardFormatListener(GetHandle());
    clipboard_listener_registered_ = false;
  }
  if (kind_ == WindowKind::kMain && g_main_flutter_window == this) {
    g_main_flutter_window = nullptr;
    g_main_window_handle = nullptr;
  }
  sprintf_s(destroy_log, "=== FlutterWindow::OnDestroy END kind=%s ===",
            WindowKindName());
  LogA(destroy_log);

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Intercept WM_CLOSE for popup windows to prevent Flutter from
  // triggering a global application exit when a secondary engine is closed.
  if (message == WM_CLOSE && kind_ == WindowKind::kPopup) {
    LogA("Intercepted WM_CLOSE for Popup, hiding window to avoid abort().");
    ShowWindow(hwnd, SW_HIDE);
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      {
        char buffer[128];
        sprintf_s(buffer, "FlutterWindow WM_CLOSE kind=%s hwnd=%p",
                  WindowKindName(), hwnd);
        LogA(buffer);
      }
      break;
    case WM_FONTCHANGE:
      if (flutter_controller_ && flutter_controller_->engine()) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
    case WM_SHOWWINDOW:
      if (wparam == TRUE) {
        ScheduleWindowEffectRefresh(hwnd);
      }
      break;
    case WM_ACTIVATE:
      if (kind_ == WindowKind::kTrayMenu && LOWORD(wparam) == WA_INACTIVE) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      if (LOWORD(wparam) != WA_INACTIVE) {
        ScheduleWindowEffectRefresh(hwnd);
      }
      break;
    case WM_DWMCOMPOSITIONCHANGED:
    case WM_THEMECHANGED:
    case WM_SETTINGCHANGE:
    case WM_DPICHANGED:
    case WM_DISPLAYCHANGE:
    {
      // Re-apply effect on system-level changes
      ApplyWindowEffect(hwnd, true);
      ScheduleWindowEffectRefresh(hwnd);
      break;
    }
    case WM_SIZE:
    {
      // Debounce rapid size changes before refreshing corners/effects.
      SetTimer(hwnd, kWindowResizeEffectTimer, 50, NULL);
      break;
    }
    // Win10: use opaque tinted gradient during drag (no blur cost, no transparency)
    case WM_ENTERSIZEMOVE:
    {
      if (GetWindowsBuildNumber() < kWin11Build && drag_suspend_ &&
          IsAccentEffect(effect_mode_) && !is_suspended_) {
        if (LoadAccentPolicyApi()) {
          ACCENT_POLICY policy{};
          policy.AccentState = ACCENT_ENABLE_TRANSPARENTGRADIENT;
          policy.AccentFlags = 2;
          policy.GradientColor =
              MakeAccentGradientColor(0xF0, EffectTintColor(dark_mode_));
          policy.AnimationId = 0;
          WINDOWCOMPOSITIONATTRIBUTEDATA data{};
          data.Attribute = 19;
          data.Data = &policy;
          data.SizeOfData = sizeof(policy);
          pSetWindowCompositionAttribute(hwnd, &data);
          is_suspended_ = true;
        }
      }
      break;
    }
    case WM_EXITSIZEMOVE:
    {
      if (GetWindowsBuildNumber() < kWin11Build && is_suspended_) {
        is_suspended_ = false;
        ApplyWindowEffect(hwnd, true);
      }
      break;
    }
    case WM_TIMER:
    {
      if (wparam == kPopupInitialEffectTimer ||
          wparam == kWindowResizeEffectTimer ||
          wparam == kWindowEffectShowTimer ||
          wparam == kWindowEffectActivateTimer ||
          wparam == kWindowEffectSettledTimer) {
        KillTimer(hwnd, static_cast<UINT_PTR>(wparam));
        ApplyWindowEffect(hwnd, true);
      } else if (wparam == kWindowFramePaintTimer) {
        KillTimer(hwnd, kWindowFramePaintTimer);
        PaintNativeFrameStrips(hwnd);
      } else if (wparam == kWindowFramePaintSettledTimer) {
        KillTimer(hwnd, kWindowFramePaintSettledTimer);
        PaintNativeFrameStrips(hwnd);
      }
      break;
    }
    case WM_CLIPBOARDUPDATE:
    {
      if (clipboard_listener_registered_) {
        DispatchClipboardChanged();
      }
      return 0;
    }
    case kCloseExistingInstanceCompleteMessage:
    {
      auto* request =
          reinterpret_cast<CloseExistingInstanceRequest*>(lparam);
      if (request != nullptr && request->result != nullptr) {
        request->result->Success(flutter::EncodableValue(request->success));
      }
      delete request;
      return 0;
    }
    case kPopupCloseMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Popup close message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      if (kind_ != WindowKind::kPopup) {
        LogA("Popup close message ignored by non-popup window");
        return 0;
      }
      CloseCurrentWindow();
      return 0;
    case kPopupMinimizeMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Popup minimize message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      if (kind_ != WindowKind::kPopup) {
        LogA("Popup minimize message ignored by non-popup window");
        return 0;
      }
      MinimizeCurrentWindow();
      return 0;
    case kPopupStartDragMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Popup drag message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      if (kind_ != WindowKind::kPopup) {
        LogA("Popup drag message ignored by non-popup window");
        return 0;
      }
      StartWindowDrag();
      return 0;
    case kTrayMenuCloseMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Tray menu close message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      if (g_tray_menu_window && g_tray_menu_window->GetHandle() == hwnd) {
        g_tray_menu_window.reset();
      }
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::SetupMethodChannel() {
  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/window",
      &flutter::StandardMethodCodec::GetInstance());

  channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        OutputDebugStringA((std::string("Method call: ") + call.method_name()).c_str());
        if (call.method_name() == "bringToFront") {
          BringWindowToFront();
          OutputDebugStringA("bringToFront executed");
          result->Success();
        } else if (call.method_name() == "showPopupWindow") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto payload_it = arguments->find(flutter::EncodableValue("payload"));
            if (payload_it != arguments->end()) {
              if (const std::string* payload =
                      std::get_if<std::string>(&payload_it->second)) {
                std::wstring window_title = L"Hanabi Download Pop";
                auto title_it = arguments->find(flutter::EncodableValue("title"));
                if (title_it != arguments->end()) {
                  if (const std::string* title =
                          std::get_if<std::string>(&title_it->second)) {
                    std::wstring parsed_title = Utf8ToWide(*title);
                    if (!parsed_title.empty()) {
                      window_title = parsed_title;
                    }
                  }
                }

                WindowEffectSnapshot popup_effect;
                bool has_popup_effect = false;
                auto effect_it =
                    arguments->find(flutter::EncodableValue("windowEffect"));
                if (effect_it != arguments->end()) {
                  if (const auto* effect_map =
                          std::get_if<flutter::EncodableMap>(&effect_it->second)) {
                    has_popup_effect = true;
                    popup_effect.effect_mode = effect_mode_;
                    popup_effect.effect_alpha = effect_alpha_;
                    popup_effect.dark_mode = dark_mode_;
                    popup_effect.rounded_corners_enabled =
                        rounded_corners_enabled_;
                    popup_effect.corner_radius = corner_radius_;
                    popup_effect.drag_suspend = drag_suspend_;

                    auto enabled_it =
                        effect_map->find(flutter::EncodableValue("enabled"));
                    bool effect_enabled = true;
                    if (enabled_it != effect_map->end()) {
                      if (const bool* enabled =
                              std::get_if<bool>(&enabled_it->second)) {
                        effect_enabled = *enabled;
                      }
                    }

                    auto mode_it =
                        effect_map->find(flutter::EncodableValue("mode"));
                    if (mode_it != effect_map->end()) {
                      if (const std::string* mode =
                              std::get_if<std::string>(&mode_it->second)) {
                        if (!effect_enabled || *mode == "none") {
                          popup_effect.effect_mode = kEffectNone;
                        } else if (*mode == "blur") {
                          popup_effect.effect_mode = kEffectBlur;
                        } else if (*mode == "acrylic") {
                          popup_effect.effect_mode = kEffectAcrylic;
                        } else if (*mode == "mica_main") {
                          popup_effect.effect_mode = kEffectMica;
                        } else if (*mode == "mica_transient") {
                          popup_effect.effect_mode = kEffectMicaAlt;
                        }
                      }
                    }

                    auto alpha_it =
                        effect_map->find(flutter::EncodableValue("alpha"));
                    if (alpha_it != effect_map->end()) {
                      if (const int32_t* alpha32 =
                              std::get_if<int32_t>(&alpha_it->second)) {
                        popup_effect.effect_alpha =
                            std::max(0, std::min(255, *alpha32));
                      } else if (const int64_t* alpha64 =
                                     std::get_if<int64_t>(&alpha_it->second)) {
                        popup_effect.effect_alpha = std::max(
                            0, std::min(255, static_cast<int>(*alpha64)));
                      }
                    }

                    auto dark_it =
                        effect_map->find(flutter::EncodableValue("dark_mode"));
                    if (dark_it != effect_map->end()) {
                      if (const bool* dark =
                              std::get_if<bool>(&dark_it->second)) {
                        popup_effect.dark_mode = *dark;
                      }
                    }

                    auto rounded_it = effect_map->find(
                        flutter::EncodableValue("rounded_corners_enabled"));
                    if (rounded_it != effect_map->end()) {
                      if (const bool* rounded =
                              std::get_if<bool>(&rounded_it->second)) {
                        popup_effect.rounded_corners_enabled = *rounded;
                      }
                    }

                    auto radius_it = effect_map->find(
                        flutter::EncodableValue("corner_radius"));
                    if (radius_it != effect_map->end()) {
                      if (const int32_t* radius32 =
                              std::get_if<int32_t>(&radius_it->second)) {
                        popup_effect.corner_radius =
                            std::max(0, std::min(32, *radius32));
                      } else if (const int64_t* radius64 =
                                     std::get_if<int64_t>(&radius_it->second)) {
                        popup_effect.corner_radius = std::max(
                            0, std::min(32, static_cast<int>(*radius64)));
                      }
                    }

                    auto drag_it = effect_map->find(
                        flutter::EncodableValue("drag_suspend"));
                    if (drag_it != effect_map->end()) {
                      if (const bool* drag =
                              std::get_if<bool>(&drag_it->second)) {
                        popup_effect.drag_suspend = *drag;
                      }
                    }
                  }
                }

                result->Success(
                    flutter::EncodableValue(
                        CreatePopupWindow(
                            *payload, window_title,
                            has_popup_effect ? &popup_effect : nullptr)));
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing payload parameter");
        } else if (call.method_name() == "showTrayMenu") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto payload_it = arguments->find(flutter::EncodableValue("payload"));
            if (payload_it != arguments->end()) {
              if (const std::string* payload =
                      std::get_if<std::string>(&payload_it->second)) {
                std::wstring window_title = L"Hanabi Tray Menu";

                result->Success(
                    flutter::EncodableValue(
                        CreateTrayMenuWindow(*payload, window_title)));
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing payload parameter");
        } else if (call.method_name() == "prepareTrayMenu") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto payload_it = arguments->find(flutter::EncodableValue("payload"));
            if (payload_it != arguments->end()) {
              if (const std::string* payload =
                      std::get_if<std::string>(&payload_it->second)) {
                std::wstring window_title = L"Hanabi Tray Menu";
                result->Success(
                    flutter::EncodableValue(
                        CreateTrayMenuWindow(*payload, window_title, false)));
                return;
              }
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing payload parameter");
        } else if (call.method_name() == "setAlwaysOnTop") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto it = arguments->find(flutter::EncodableValue("alwaysOnTop"));
            if (it != arguments->end()) {
              bool alwaysOnTop = std::get<bool>(it->second);
              SetAlwaysOnTop(alwaysOnTop);
              OutputDebugStringA("setAlwaysOnTop executed");
              result->Success();
              return;
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing alwaysOnTop parameter");
        } else if (call.method_name() == "flashWindow") {
          FlashWindowAttention();
          OutputDebugStringA("flashWindow executed");
          result->Success();
        } else if (call.method_name() == "getCursorPos") {
          POINT cursor;
          if (GetCursorPos(&cursor)) {
            flutter::EncodableMap payload;
            payload[flutter::EncodableValue("x")] =
                flutter::EncodableValue(static_cast<double>(cursor.x));
            payload[flutter::EncodableValue("y")] =
                flutter::EncodableValue(static_cast<double>(cursor.y));
            result->Success(flutter::EncodableValue(payload));
          } else {
            result->Error("FAILED", "GetCursorPos failed");
          }
          return;
        } else if (call.method_name() == "getWindowDebugInfo") {
          const HWND hwnd = GetHandle();
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("hwnd")] =
              flutter::EncodableValue(
                  static_cast<int64_t>(reinterpret_cast<intptr_t>(hwnd)));
          payload[flutter::EncodableValue("kind")] =
              flutter::EncodableValue(
                  kind_ == WindowKind::kPopup ? "popup" : "main");
          payload[flutter::EncodableValue("title")] =
              flutter::EncodableValue(WideToUtf8(GetWindowTitle(hwnd)));
          result->Success(flutter::EncodableValue(payload));
          return;
        } else if (call.method_name() == "closeWindow") {
          const HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(hwnd != nullptr));
          if (kind_ == WindowKind::kTrayMenu && hwnd) {
            ::ShowWindow(hwnd, SW_HIDE);
          } else if (kind_ == WindowKind::kPopup) {
            CloseCurrentWindow();
          } else {
            CloseCurrentWindow();
          }
          return;
        } else if (call.method_name() == "minimizeWindow") {
          const HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(hwnd != nullptr));
          MinimizeCurrentWindow();
          return;
        } else if (call.method_name() == "startWindowDrag") {
          const HWND hwnd = GetHandle();
          const bool can_drag = hwnd != nullptr && kind_ == WindowKind::kPopup;
          result->Success(flutter::EncodableValue(can_drag));
          if (can_drag) {
            PostMessage(hwnd, kPopupStartDragMessage, 0, 0);
          }
          return;
        } else if (call.method_name() == "resizeWindow") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("INVALID_ARGUMENT", "Missing map");
            return;
          }

          auto height_it = arguments->find(flutter::EncodableValue("height"));
          if (height_it == arguments->end()) {
            result->Error("INVALID_ARGUMENT", "Missing height");
            return;
          }

          int height = 0;
          if (const int32_t* int32_value =
                  std::get_if<int32_t>(&height_it->second)) {
            height = *int32_value;
          } else if (const int64_t* int64_value =
                         std::get_if<int64_t>(&height_it->second)) {
            height = static_cast<int>(*int64_value);
          } else {
            result->Error("INVALID_ARGUMENT", "Height must be int");
            return;
          }

          const HWND hwnd = GetHandle();
          if (hwnd == nullptr) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          RECT rect{};
          GetWindowRect(hwnd, &rect);
          const int current_width = rect.right - rect.left;
          int width = current_width;

          auto width_it = arguments->find(flutter::EncodableValue("width"));
          if (width_it != arguments->end()) {
            if (const int32_t* int32_value =
                    std::get_if<int32_t>(&width_it->second)) {
              width = *int32_value;
            } else if (const int64_t* int64_value =
                           std::get_if<int64_t>(&width_it->second)) {
              width = static_cast<int>(*int64_value);
            } else {
              result->Error("INVALID_ARGUMENT", "Width must be int");
              return;
            }
          }

          const int min_width = kind_ == WindowKind::kTrayMenu
                                    ? 172
                                    : kind_ == WindowKind::kPopup ? 520
                                                                  : current_width;
          const int max_width = kind_ == WindowKind::kTrayMenu
                                    ? 420
                                    : kind_ == WindowKind::kPopup ? 720
                                                                  : current_width;
          const int min_height =
              kind_ == WindowKind::kTrayMenu ? 120 : 220;
          const int max_height =
              kind_ == WindowKind::kTrayMenu ? 600 : 900;
          const int safe_width = std::max(min_width, std::min(max_width, width));
          const int safe_height = std::max(min_height, std::min(max_height, height));

          bool suspended_here = false;
          if (IsAccentEffect(effect_mode_) && !is_suspended_) {
            if (LoadAccentPolicyApi()) {
              ACCENT_POLICY policy{};
              policy.AccentState = ACCENT_ENABLE_TRANSPARENTGRADIENT;
              policy.AccentFlags = 2;
              policy.GradientColor =
                  MakeAccentGradientColor(0xF0, EffectTintColor(dark_mode_));
              policy.AnimationId = 0;
              WINDOWCOMPOSITIONATTRIBUTEDATA data{};
              data.Attribute = 19;
              data.Data = &policy;
              data.SizeOfData = sizeof(policy);
              pSetWindowCompositionAttribute(hwnd, &data);
              suspended_here = true;
            }
          }

          const BOOL ok = SetWindowPos(
              hwnd, nullptr, 0, 0, safe_width, safe_height,
              SWP_NOMOVE | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOZORDER);

          if (suspended_here) {
            ApplyWindowEffect(hwnd, true);
          }

          result->Success(flutter::EncodableValue(ok != FALSE));
          return;
        } else if (call.method_name() == "setWindowEffect") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            const bool was_effect_configured = effect_configured_;
            const int previous_effect_mode = effect_mode_;
            const int previous_effect_alpha = effect_alpha_;
            const bool previous_dark_mode = dark_mode_;
            const bool previous_rounded_corners_enabled =
                rounded_corners_enabled_;
            const int previous_corner_radius = corner_radius_;

            auto itMode = arguments->find(flutter::EncodableValue("mode"));
            auto itAlpha = arguments->find(flutter::EncodableValue("alpha"));
            auto itRoundedCorners =
                arguments->find(flutter::EncodableValue("roundedCornersEnabled"));
            auto itCornerRadius =
                arguments->find(flutter::EncodableValue("cornerRadius"));
            auto itDarkMode =
                arguments->find(flutter::EncodableValue("darkMode"));
            if (itMode != arguments->end()) {
              if (const std::string* s = std::get_if<std::string>(&itMode->second)) {
                if (*s == "none") effect_mode_ = kEffectNone;
                else if (*s == "blur") effect_mode_ = kEffectBlur;
                else if (*s == "acrylic") effect_mode_ = kEffectAcrylic;
                else if (*s == "mica_main") effect_mode_ = kEffectMica;
                else if (*s == "mica_transient") effect_mode_ = kEffectMicaAlt;
              }
            }
            if (itAlpha != arguments->end()) {
              if (const int32_t* a = std::get_if<int32_t>(&itAlpha->second)) {
                effect_alpha_ = std::max(0, std::min(255, *a));
              } else if (const int64_t* alpha64 =
                             std::get_if<int64_t>(&itAlpha->second)) {
                effect_alpha_ =
                    std::max(0, std::min(255, static_cast<int>(*alpha64)));
              }
            }
            if (itDarkMode != arguments->end()) {
              if (const bool* dark = std::get_if<bool>(&itDarkMode->second)) {
                dark_mode_ = *dark;
              }
            }
            if (itRoundedCorners != arguments->end()) {
              if (const bool* enabled = std::get_if<bool>(&itRoundedCorners->second)) {
                rounded_corners_enabled_ = *enabled;
              }
            }
            if (itCornerRadius != arguments->end()) {
              if (const int32_t* radius = std::get_if<int32_t>(&itCornerRadius->second)) {
                corner_radius_ = std::max(0, std::min(32, *radius));
              }
            }
            effect_configured_ = true;
            const bool only_alpha_changed =
                was_effect_configured &&
                previous_effect_mode == effect_mode_ &&
                previous_effect_alpha != effect_alpha_ &&
                previous_dark_mode == dark_mode_ &&
                previous_rounded_corners_enabled ==
                    rounded_corners_enabled_ &&
                previous_corner_radius == corner_radius_;
            ApplyWindowEffect(GetHandle(), !only_alpha_changed);
            if (!only_alpha_changed) {
              ScheduleWindowEffectRefresh(GetHandle());
            }
            result->Success();
          } else {
            result->Error("INVALID_ARGUMENT", "Missing map");
          }
        } else if (call.method_name() == "setDragSuspend") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto it = arguments->find(flutter::EncodableValue("enabled"));
            if (it != arguments->end()) {
              drag_suspend_ = std::get<bool>(it->second);
              OutputDebugStringA(drag_suspend_ ? "dragSuspend: ON" : "dragSuspend: OFF");
              result->Success();
              return;
            }
          }
          result->Error("INVALID_ARGUMENT", "Missing enabled parameter");
        } else if (call.method_name() == "pickFolder") {
          std::string folder = PickFolder();
          if (!folder.empty()) {
            result->Success(flutter::EncodableValue(folder));
          } else {
            result->Success(); // User cancelled
          }
        } else if (call.method_name() == "getStartupConflictState") {
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("hasExistingInstance")] =
              flutter::EncodableValue(single_instance::HasStartupConflict());
          result->Success(flutter::EncodableValue(payload));
        } else if (call.method_name() == "focusExistingInstance") {
          result->Success(
              flutter::EncodableValue(single_instance::FocusExistingWindow()));
        } else if (call.method_name() ==
                   "closeExistingInstanceAndAcquireLock") {
          auto request = std::make_unique<CloseExistingInstanceRequest>();
          request->result = std::move(result);

          const HWND hwnd = GetHandle();
          auto* request_ptr = request.release();

          std::thread([hwnd, request_ptr]() {
            request_ptr->success =
                single_instance::CloseExistingInstanceAndAcquireLock();

            if (::IsWindow(hwnd) &&
                ::PostMessage(hwnd, kCloseExistingInstanceCompleteMessage, 0,
                              reinterpret_cast<LPARAM>(request_ptr)) != FALSE) {
              return;
            }

            delete request_ptr;
          }).detach();
          return;
        } else if (call.method_name() == "quitApplication") {
          const HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(hwnd != nullptr));

          std::thread([hwnd]() {
            if (::IsWindow(hwnd)) {
              ::PostMessage(hwnd, WM_CLOSE, 0, 0);
            }

            ::Sleep(1000);
            ::ExitProcess(0);
          }).detach();
          return;
        } else if (call.method_name() == "positionTrayMenu") {
          const HWND hwnd = GetHandle();
          if (kind_ == WindowKind::kTrayMenu && hwnd) {
            const auto* arguments =
                std::get_if<flutter::EncodableMap>(call.arguments());
            if (arguments) {
              auto x_it = arguments->find(flutter::EncodableValue("x"));
              auto y_it = arguments->find(flutter::EncodableValue("y"));
              if (x_it != arguments->end() && y_it != arguments->end()) {
                double target_x = std::get<double>(x_it->second);
                double target_y = std::get<double>(y_it->second);
                PositionTrayMenuWindow(hwnd, target_x, target_y);
                SetForegroundWindow(hwnd);
                SetFocus(hwnd);
              }
            }
          }
          result->Success();
          return;
        } else if (call.method_name() == "setTrayMenuRegion") {
          const HWND hwnd = GetHandle();
          if (kind_ != WindowKind::kTrayMenu || hwnd == nullptr) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (!arguments) {
            result->Error("INVALID_ARGUMENT", "Missing map");
            return;
          }

          auto radius_it = arguments->find(flutter::EncodableValue("radius"));
          if (radius_it != arguments->end()) {
            if (const int32_t* radius32 =
                    std::get_if<int32_t>(&radius_it->second)) {
              tray_menu_region_radius_ = std::max(0, std::min(32, *radius32));
            } else if (const int64_t* radius64 =
                           std::get_if<int64_t>(&radius_it->second)) {
              tray_menu_region_radius_ =
                  std::max(0, std::min(32, static_cast<int>(*radius64)));
            }
          }

          tray_menu_region_rects_.clear();
          auto rects_it = arguments->find(flutter::EncodableValue("rects"));
          if (rects_it != arguments->end()) {
            if (const auto* rects =
                    std::get_if<flutter::EncodableList>(&rects_it->second)) {
              for (const auto& rect_value : *rects) {
                const auto* rect_map =
                    std::get_if<flutter::EncodableMap>(&rect_value);
                if (!rect_map) {
                  continue;
                }

                auto read_double = [&](const char* key, double* out) -> bool {
                  auto it = rect_map->find(flutter::EncodableValue(key));
                  if (it == rect_map->end()) {
                    return false;
                  }
                  if (const double* value = std::get_if<double>(&it->second)) {
                    *out = *value;
                    return true;
                  }
                  if (const int32_t* value =
                          std::get_if<int32_t>(&it->second)) {
                    *out = static_cast<double>(*value);
                    return true;
                  }
                  if (const int64_t* value =
                          std::get_if<int64_t>(&it->second)) {
                    *out = static_cast<double>(*value);
                    return true;
                  }
                  return false;
                };

                TrayMenuRegionRect rect{};
                if (!read_double("x", &rect.x) ||
                    !read_double("y", &rect.y) ||
                    !read_double("width", &rect.width) ||
                    !read_double("height", &rect.height) ||
                    rect.width <= 0 || rect.height <= 0) {
                  continue;
                }

                tray_menu_region_rects_.push_back(rect);
              }
            }
          }

          ApplyTrayMenuWindowRegion(hwnd);
          result->Success(flutter::EncodableValue(true));
          return;
        } else if (call.method_name() == "showMainWindow") {
          if (g_main_window_handle && ::IsWindow(g_main_window_handle)) {
            ::ShowWindow(g_main_window_handle, SW_RESTORE);
            ::SetForegroundWindow(g_main_window_handle);
            if (g_main_flutter_window != nullptr) {
              g_main_flutter_window->ApplyWindowEffect(g_main_window_handle,
                                                       true);
              g_main_flutter_window->ScheduleWindowEffectRefresh(
                  g_main_window_handle);
            }
          }
          result->Success();
          return;
        } else if (call.method_name() == "showMainWindowWithAction") {
          std::string action;
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto action_it =
                arguments->find(flutter::EncodableValue("action"));
            if (action_it != arguments->end()) {
              if (const std::string* parsed_action =
                      std::get_if<std::string>(&action_it->second)) {
                action = *parsed_action;
              }
            }
          }

          if (g_main_window_handle && ::IsWindow(g_main_window_handle)) {
            ::ShowWindow(g_main_window_handle, SW_RESTORE);
            ::SetForegroundWindow(g_main_window_handle);
            if (g_main_flutter_window != nullptr) {
              g_main_flutter_window->ApplyWindowEffect(g_main_window_handle,
                                                       true);
              g_main_flutter_window->ScheduleWindowEffectRefresh(
                  g_main_window_handle);
            }
          }

          if (!action.empty() && g_main_flutter_window != nullptr &&
              g_main_flutter_window->flutter_controller_ &&
              g_main_flutter_window->flutter_controller_->engine()) {
            flutter::MethodChannel<> main_channel(
                g_main_flutter_window->flutter_controller_->engine()->messenger(),
                "com.hanabi.download/window",
                &flutter::StandardMethodCodec::GetInstance());
            flutter::EncodableMap payload;
            payload[flutter::EncodableValue("action")] =
                flutter::EncodableValue(action);
            main_channel.InvokeMethod(
                "handleMainWindowAction",
                std::make_unique<flutter::EncodableValue>(payload));
          }

          result->Success();
          return;
        } else if (call.method_name() == "exitApp") {
          if (g_main_window_handle && ::IsWindow(g_main_window_handle)) {
            ::PostMessage(g_main_window_handle, WM_CLOSE, 0, 0);
          }
          result->Success();
          return;
          } else {
            result->NotImplemented();
          }
      });

  flutter::MethodChannel<> clipboard_channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/clipboard",
      &flutter::StandardMethodCodec::GetInstance());

  clipboard_channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<>& call,
             std::unique_ptr<flutter::MethodResult<>> result) {
        if (call.method_name() == "setListenerEnabled") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          bool enabled = false;
          if (arguments) {
            auto enabled_it =
                arguments->find(flutter::EncodableValue("enabled"));
            if (enabled_it != arguments->end()) {
              if (const bool* parsed =
                      std::get_if<bool>(&enabled_it->second)) {
                enabled = *parsed;
              }
            }
          }

          SetClipboardListenerEnabled(enabled);
          result->Success(
              flutter::EncodableValue(clipboard_listener_registered_));
          return;
        }

        result->NotImplemented();
      });
}

void FlutterWindow::BringWindowToFront() {
  HWND hwnd = GetHandle();
  if (hwnd) {
    const DWORD current_thread = GetCurrentThreadId();
    const HWND foreground_before = GetForegroundWindow();
    if (kind_ == WindowKind::kPopup && foreground_before != hwnd) {
      previous_foreground_window_ = foreground_before;
    }
    const DWORD foreground_thread = foreground_before != nullptr
        ? GetWindowThreadProcessId(foreground_before, nullptr)
        : 0;
    const DWORD target_thread = GetWindowThreadProcessId(hwnd, nullptr);
    const bool attached_foreground =
        foreground_thread != 0 && foreground_thread != current_thread &&
        AttachThreadInput(current_thread, foreground_thread, TRUE) != FALSE;
    const bool attached_target =
        target_thread != 0 && target_thread != current_thread &&
        AttachThreadInput(current_thread, target_thread, TRUE) != FALSE;

    // Show window
    ShowWindow(hwnd, SW_SHOW);
    // Restore window if minimized
    ShowWindow(hwnd, SW_RESTORE);
    SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    BringWindowToTop(hwnd);
    // Set as foreground window
    const BOOL foreground_result = SetForegroundWindow(hwnd);
    // Activate window
    const HWND active_result = SetActiveWindow(hwnd);
    // Set focus
    const HWND focus_result = SetFocus(hwnd);
    ApplyWindowEffect(hwnd, true);
    ScheduleWindowEffectRefresh(hwnd);

    if (attached_target) {
      AttachThreadInput(current_thread, target_thread, FALSE);
    }
    if (attached_foreground) {
      AttachThreadInput(current_thread, foreground_thread, FALSE);
    }

    char buffer[512];
    sprintf_s(
        buffer, sizeof(buffer),
        "BringWindowToFront hwnd=%p currentThread=%lu targetThread=%lu foregroundBefore=%p foregroundThread=%lu attachedForeground=%d attachedTarget=%d foregroundResult=%d activeResult=%p focusResult=%p foregroundNow=%p activeNow=%p",
        hwnd, current_thread, target_thread, foreground_before,
        foreground_thread, attached_foreground, attached_target,
        foreground_result, active_result, focus_result, GetForegroundWindow(),
        GetActiveWindow());
    LogA(buffer);
  }
}

void FlutterWindow::RestorePreviousForegroundWindow() {
  const HWND hwnd = previous_foreground_window_;
  previous_foreground_window_ = nullptr;
  if (hwnd == nullptr || !::IsWindow(hwnd)) {
    return;
  }
  if (g_main_window_handle != nullptr && hwnd == g_main_window_handle) {
    LogA("RestorePreviousForegroundWindow skipped main window target");
    return;
  }

  const DWORD current_thread = GetCurrentThreadId();
  const HWND foreground_before = GetForegroundWindow();
  const DWORD foreground_thread = foreground_before != nullptr
      ? GetWindowThreadProcessId(foreground_before, nullptr)
      : 0;
  const DWORD target_thread = GetWindowThreadProcessId(hwnd, nullptr);
  const bool attached_foreground =
      foreground_thread != 0 && foreground_thread != current_thread &&
      AttachThreadInput(current_thread, foreground_thread, TRUE) != FALSE;
  const bool attached_target =
      target_thread != 0 && target_thread != current_thread &&
      AttachThreadInput(current_thread, target_thread, TRUE) != FALSE;

  AllowSetForegroundWindow(ASFW_ANY);
  BringWindowToTop(hwnd);
  const BOOL foreground_result = SetForegroundWindow(hwnd);
  const HWND active_result = SetActiveWindow(hwnd);
  const HWND focus_result = SetFocus(hwnd);

  if (attached_target) {
    AttachThreadInput(current_thread, target_thread, FALSE);
  }
  if (attached_foreground) {
    AttachThreadInput(current_thread, foreground_thread, FALSE);
  }

  char buffer[512];
  sprintf_s(
      buffer, sizeof(buffer),
      "RestorePreviousForegroundWindow target=%p foregroundBefore=%p targetThread=%lu foregroundThread=%lu foregroundResult=%d activeResult=%p focusResult=%p foregroundNow=%p activeNow=%p",
      hwnd, foreground_before, target_thread, foreground_thread,
      foreground_result, active_result, focus_result, GetForegroundWindow(),
      GetActiveWindow());
  LogA(buffer);
}

void FlutterWindow::SetAlwaysOnTop(bool alwaysOnTop) {
  HWND hwnd = GetHandle();
  if (hwnd) {
    SetWindowPos(hwnd, alwaysOnTop ? HWND_TOPMOST : HWND_NOTOPMOST,
                 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
  }
}

void FlutterWindow::FlashWindowAttention() {
  HWND hwnd = GetHandle();
  if (hwnd) {
    FLASHWINFO fwi;
    fwi.cbSize = sizeof(FLASHWINFO);
    fwi.hwnd = hwnd;
    fwi.dwFlags = FLASHW_ALL | FLASHW_TIMERNOFG;
    fwi.uCount = 3;
    fwi.dwTimeout = 0;
    FlashWindowEx(&fwi);
  }
}

void FlutterWindow::CloseCurrentWindow() {
  const HWND hwnd = GetHandle();
  if (hwnd) {
    char buffer[128];
    sprintf_s(buffer, "CloseCurrentWindow kind=%s hwnd=%p", WindowKindName(),
              hwnd);
    LogA(buffer);
    PostMessage(hwnd, WM_CLOSE, 0, 0);
  }
}

void FlutterWindow::DestroyPopupWindow() {
  const HWND hwnd = GetHandle();
  if (!hwnd) {
    return;
  }

  PostMessage(hwnd, WM_CLOSE, 0, 0);
}

void FlutterWindow::MinimizeCurrentWindow() {
  const HWND hwnd = GetHandle();
  if (hwnd) {
    ShowWindow(hwnd, SW_MINIMIZE);
  }
}

void FlutterWindow::StartWindowDrag() {
  const HWND hwnd = GetHandle();
  if (!hwnd || !HasCustomFrame()) {
    return;
  }

  ReleaseCapture();
  SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void FlutterWindow::SendTrayMenuPayloadToFlutter(
    const std::string& payload_json) {
  if (kind_ != WindowKind::kTrayMenu || payload_json.empty() ||
      !flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  flutter::MethodChannel<> tray_channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/window",
      &flutter::StandardMethodCodec::GetInstance());
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("payload")] =
      flutter::EncodableValue(payload_json);
  tray_channel.InvokeMethod(
      "updateTrayMenuPayload",
      std::make_unique<flutter::EncodableValue>(payload));
}

void FlutterWindow::SendPopupPayloadToFlutter(
    const std::string& payload_json) {
  if (kind_ != WindowKind::kPopup || payload_json.empty() ||
      !flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  flutter::MethodChannel<> popup_channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/window",
      &flutter::StandardMethodCodec::GetInstance());
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("payload")] =
      flutter::EncodableValue(payload_json);
  popup_channel.InvokeMethod(
      "updatePopupPayload",
      std::make_unique<flutter::EncodableValue>(payload));
}

bool FlutterWindow::CreatePopupWindow(
    const std::string& payload_json,
    const std::wstring& window_title,
    const FlutterWindow::WindowEffectSnapshot* effect_override) {
  CleanupPopupWindows();

  if (!g_popup_windows.empty()) {
    auto& popup_window = g_popup_windows.front();
    const HWND existing_hwnd =
        popup_window ? popup_window->GetHandle() : nullptr;
    if (existing_hwnd) {
      if (effect_override != nullptr) {
        popup_window->effect_mode_ = effect_override->effect_mode;
        popup_window->effect_alpha_ = effect_override->effect_alpha;
        popup_window->dark_mode_ = effect_override->dark_mode;
        popup_window->rounded_corners_enabled_ =
            effect_override->rounded_corners_enabled;
        popup_window->corner_radius_ = effect_override->corner_radius;
        popup_window->drag_suspend_ = effect_override->drag_suspend;
      } else {
        popup_window->effect_mode_ = effect_mode_;
        popup_window->effect_alpha_ = effect_alpha_;
        popup_window->dark_mode_ = dark_mode_;
        popup_window->rounded_corners_enabled_ = rounded_corners_enabled_;
        popup_window->corner_radius_ = corner_radius_;
        popup_window->drag_suspend_ = drag_suspend_;
      }

      SetWindowTextW(existing_hwnd, window_title.c_str());
      popup_window->SendPopupPayloadToFlutter(payload_json);
      CenterWindowOnWorkArea(existing_hwnd);
      popup_window->ApplyWindowEffect(existing_hwnd, true);
      popup_window->ScheduleWindowEffectRefresh(existing_hwnd);
      InvalidateRect(existing_hwnd, nullptr, TRUE);
      ::ShowWindow(existing_hwnd, SW_SHOW);
      SetForegroundWindow(existing_hwnd);
      SetFocus(existing_hwnd);
      LogA("Reused existing popup window");
      return true;
    }
  }

  flutter::DartProject popup_project(L"data");
  popup_project.set_dart_entrypoint("popupMain");
  popup_project.set_dart_entrypoint_arguments(
      std::vector<std::string>{payload_json});

  auto popup_window = std::make_unique<FlutterWindow>(
      popup_project, WindowKind::kPopup);
  if (effect_override != nullptr) {
    popup_window->effect_mode_ = effect_override->effect_mode;
    popup_window->effect_alpha_ = effect_override->effect_alpha;
    popup_window->dark_mode_ = effect_override->dark_mode;
    popup_window->rounded_corners_enabled_ =
        effect_override->rounded_corners_enabled;
    popup_window->corner_radius_ = effect_override->corner_radius;
    popup_window->drag_suspend_ = effect_override->drag_suspend;
  } else {
    popup_window->effect_mode_ = effect_mode_;
    popup_window->effect_alpha_ = effect_alpha_;
    popup_window->dark_mode_ = dark_mode_;
    popup_window->rounded_corners_enabled_ = rounded_corners_enabled_;
    popup_window->corner_radius_ = corner_radius_;
    popup_window->drag_suspend_ = drag_suspend_;
  }

  Win32Window::Point origin(120, 120);
  Win32Window::Size size(565, 388);
  if (!popup_window->Create(window_title, origin, size)) {
    return false;
  }

  popup_window->SetQuitOnClose(false);
  CenterWindowOnWorkArea(popup_window->GetHandle());
  if (popup_window->GetHandle()) {
    SetTimer(popup_window->GetHandle(), kPopupInitialEffectTimer, 180, NULL);
  }
  LogA("CreatePopupWindow waiting for first Flutter frame before showing");
  g_popup_windows.push_back(std::move(popup_window));
  return true;
}

bool FlutterWindow::CreateTrayMenuWindow(const std::string& payload_json,
                                         const std::wstring& window_title,
                                         bool show_immediately) {
  CleanupClosedPopupWindows();

  double target_x = 0.0;
  double target_y = 0.0;
  TryExtractPayloadDouble(payload_json, "mouse_x", target_x);
  TryExtractPayloadDouble(payload_json, "mouse_y", target_y);

  if (g_tray_menu_window && g_tray_menu_window->GetHandle()) {
    g_tray_menu_window->SendTrayMenuPayloadToFlutter(payload_json);
    if (show_immediately) {
      const HWND existing_hwnd = g_tray_menu_window->GetHandle();
      PositionTrayMenuWindow(existing_hwnd, target_x, target_y);
      ::ShowWindow(existing_hwnd, SW_SHOW);
      SetForegroundWindow(existing_hwnd);
      SetFocus(existing_hwnd);
    }
    return true;
  }

  flutter::DartProject tray_project(L"data");
  tray_project.set_dart_entrypoint("trayMenuMain");
  tray_project.set_dart_entrypoint_arguments(
      std::vector<std::string>{payload_json});

  auto tray_window = std::make_unique<FlutterWindow>(
      tray_project, WindowKind::kTrayMenu, true);

  Win32Window::Point origin(0, 0);
  Win32Window::Size size(184, 320);
  if (!tray_window->Create(window_title, origin, size)) {
    return false;
  }

  tray_window->SetQuitOnClose(false);
  HWND hwnd = tray_window->GetHandle();
  g_tray_menu_window = std::move(tray_window);
  if (show_immediately && hwnd) {
    PositionTrayMenuWindow(hwnd, target_x, target_y);
    ::ShowWindow(hwnd, SW_SHOW);
    SetForegroundWindow(hwnd);
    SetFocus(hwnd);
  }
  return true;
}

void FlutterWindow::CleanupPopupWindows() {
  CleanupClosedPopupWindows();
}

void FlutterWindow::ScheduleWindowEffectRefresh(HWND hwnd) {
  if (!hwnd || kind_ == WindowKind::kTrayMenu) {
    return;
  }

  SetTimer(hwnd, kWindowEffectShowTimer, 120, NULL);
  SetTimer(hwnd, kWindowEffectActivateTimer, 360, NULL);
  SetTimer(hwnd, kWindowEffectSettledTimer, 900, NULL);
}

void FlutterWindow::ApplyWindowEffect(HWND hwnd, bool force) {
  if (!hwnd) return;
  if (kind_ == WindowKind::kMain && !effect_configured_) return;

  // Debounce per window: popup windows may be created in quick succession and
  // must not inherit the last apply state from the main window or another popup.
  DWORD currentTime = GetTickCount();

  // Get current window size for Win10 rounded corners
  RECT windowRect;
  GetWindowRect(hwnd, &windowRect);
  int width = windowRect.right - windowRect.left;
  int height = windowRect.bottom - windowRect.top;

  // Allow immediate update if effect mode, tint alpha, theme, or window size
  // changed. Alpha-only updates should not tear down the current Accent/DWM
  // state, otherwise DWM can present a fully transparent intermediate frame.
  bool effectModeChanged = last_effect_mode_ != effect_mode_;
  bool alphaChanged = last_effect_alpha_ != effect_alpha_;
  bool modeChanged = effectModeChanged || (last_dark_mode_ != dark_mode_);
  bool cornerSettingChanged =
      (last_rounded_corners_enabled_ != rounded_corners_enabled_) ||
      (last_corner_radius_ != corner_radius_);
  bool sizeChanged = (width != (last_window_rect_.right - last_window_rect_.left) ||
                      height != (last_window_rect_.bottom - last_window_rect_.top));
  if (!force && !modeChanged && !alphaChanged && !sizeChanged &&
      !cornerSettingChanged &&
      (currentTime - last_apply_time_ < 100)) {
    return;
  }
  last_apply_time_ = currentTime;
  last_effect_mode_ = effect_mode_;
  last_effect_alpha_ = effect_alpha_;
  last_dark_mode_ = dark_mode_;
  last_rounded_corners_enabled_ = rounded_corners_enabled_;
  last_corner_radius_ = corner_radius_;
  last_window_rect_ = windowRect;

  if (kind_ == WindowKind::kTrayMenu) {
    ConfigureDwmFrame(hwnd, true);

    // Tray menu windows must NOT use any DWM backdrop effects.
    // The menu panels are entirely Flutter-painted; DWM acrylic/mica
    // would bleed through and cause visual artifacts.
    const DWORD buildNumber = GetWindowsBuildNumber();
    ResetDwmBackdrop(hwnd, buildNumber);
    DisableAccentPolicy(hwnd);
    ExtendFrameForEffect(hwnd, false);

    // Use region clipping instead of DWM rounded corners
    ApplyTrayMenuWindowRegion(hwnd);
    return;
  }

  DWORD buildNumber = GetWindowsBuildNumber();
  char logBuf[256];
  const char* kindName = WindowKindName();
  sprintf_s(logBuf,
            "ApplyWindowEffect: kind=%s mode=%d alpha=%d build=%lu changed=%d alphaChanged=%d force=%d size=%dx%d",
            kindName, effect_mode_, effect_alpha_, buildNumber, modeChanged,
            alphaChanged, force, width, height);
  LogA(logBuf);

  const bool supportsSystemBackdrop = buildNumber >= kSystemBackdropBuild;
  const bool useDwmAcrylicBackdrop =
      kind_ == WindowKind::kPopup && effect_mode_ == kEffectAcrylic;
  const bool useDwmBackdrop =
      supportsSystemBackdrop &&
      (IsDwmBackdropEffect(effect_mode_) || useDwmAcrylicBackdrop);
  const bool useLegacyMica =
      !supportsSystemBackdrop && buildNumber >= kWin11Build &&
      (effect_mode_ == kEffectMica || effect_mode_ == kEffectMicaAlt);
  const bool useAccent =
      !useDwmBackdrop && !useLegacyMica && IsAccentEffect(effect_mode_);
  const bool needsTransparentFrame =
      effect_mode_ != kEffectNone || kind_ == WindowKind::kPopup;

  const bool alphaOnlyChanged =
      !force && alphaChanged && !modeChanged && !sizeChanged &&
      !cornerSettingChanged;
  if (alphaOnlyChanged) {
    if (useAccent) {
      const bool ok = ApplyAccentEffect(hwnd, effect_mode_, effect_alpha_,
                                        dark_mode_,
                                        kind_ == WindowKind::kPopup);
      sprintf_s(logBuf,
                "Accent alpha-only update mode=%d ok=%d alpha=%d build=%lu",
                effect_mode_, ok ? 1 : 0, effect_alpha_, buildNumber);
      LogA(logBuf);
    }
    return;
  }

  ConfigureDwmFrame(hwnd, dark_mode_);

  if (effectModeChanged) {
    ResetDwmBackdrop(hwnd, buildNumber);
    DisableAccentPolicy(hwnd);
  }

  ExtendFrameForEffect(hwnd, needsTransparentFrame);

  if (useDwmBackdrop) {
    const INT backdropType = DwmBackdropForEffect(effect_mode_);
    const HRESULT hrBackdrop =
        DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdropType,
                              sizeof(backdropType));
    sprintf_s(logBuf,
              "DWM system backdrop=%d hr=0x%08lX build=%lu",
              backdropType, hrBackdrop, buildNumber);
    LogA(logBuf);
  } else if (useLegacyMica) {
    BOOL mica = TRUE;
    const HRESULT hrMica =
        DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
    sprintf_s(logBuf, "Legacy MICA_EFFECT hr=0x%08lX build=%lu", hrMica,
              buildNumber);
    LogA(logBuf);
  } else if (useAccent) {
    const bool ok = ApplyAccentEffect(hwnd, effect_mode_, effect_alpha_,
                                      dark_mode_,
                                      kind_ == WindowKind::kPopup);
    sprintf_s(logBuf,
              "Accent effect mode=%d ok=%d alpha=%d build=%lu",
              effect_mode_, ok ? 1 : 0, effect_alpha_, buildNumber);
    LogA(logBuf);
  }

  ApplyRoundedCorners(hwnd, buildNumber, width, height);

  // Force window redraw
  if (modeChanged || cornerSettingChanged || force) {
    SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW | RDW_FRAME);
    PaintNativeFrameStrips(hwnd);
    SetTimer(hwnd, kWindowFramePaintTimer, 120, NULL);
    SetTimer(hwnd, kWindowFramePaintSettledTimer, 900, NULL);
  }
}

DWORD FlutterWindow::WindowStyle() const {
  if (kind_ == WindowKind::kMain) {
    return WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  }
  if (kind_ == WindowKind::kPopup) {
    return WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;
  }
  if (kind_ == WindowKind::kTrayMenu) {
    return WS_POPUP;
  }
  return Win32Window::WindowStyle();
}

DWORD FlutterWindow::WindowExStyle() const {
  return Win32Window::WindowExStyle();
}

bool FlutterWindow::HasCustomFrame() const {
  return true;
}

bool FlutterWindow::CanResize() const {
  return kind_ != WindowKind::kPopup && kind_ != WindowKind::kTrayMenu;
}

void FlutterWindow::ApplyTrayMenuWindowRegion(HWND hwnd) {
  if (kind_ != WindowKind::kTrayMenu || !hwnd) {
    return;
  }

  if (tray_menu_region_rects_.empty()) {
    SetWindowRgn(hwnd, NULL, TRUE);
    return;
  }

  HRGN combined = CreateRectRgn(0, 0, 0, 0);
  if (!combined) {
    return;
  }

  const int radius =
      tray_menu_region_radius_ > 0
          ? ScaleForWindowDpi(hwnd, tray_menu_region_radius_)
          : 0;
  const int diameter = radius * 2;
  bool has_region = false;

  for (const auto& rect : tray_menu_region_rects_) {
    const int left = static_cast<int>(std::floor(rect.x));
    const int top = static_cast<int>(std::floor(rect.y));
    const int right = static_cast<int>(std::ceil(rect.x + rect.width));
    const int bottom = static_cast<int>(std::ceil(rect.y + rect.height));
    if (right <= left || bottom <= top) {
      continue;
    }

    HRGN part = radius > 0
                    ? CreateRoundRectRgn(left, top, right + 1, bottom + 1,
                                         diameter, diameter)
                    : CreateRectRgn(left, top, right, bottom);
    if (!part) {
      continue;
    }

    if (!has_region) {
      CombineRgn(combined, part, NULL, RGN_COPY);
      has_region = true;
    } else {
      CombineRgn(combined, combined, part, RGN_OR);
    }
    DeleteObject(part);
  }

  if (!has_region) {
    DeleteObject(combined);
    SetWindowRgn(hwnd, NULL, TRUE);
    return;
  }

  SetWindowRgn(hwnd, combined, TRUE);
}

void FlutterWindow::ApplyRoundedCorners(HWND hwnd,
                                        DWORD buildNumber,
                                        int width,
                                        int height) {
  if (!hwnd || width <= 0 || height <= 0) return;

  if (kind_ == WindowKind::kTrayMenu) {
    ApplyTrayMenuWindowRegion(hwnd);
    return;
  }

  WINDOWPLACEMENT wp;
  wp.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(hwnd, &wp);
  const bool isMaximized = wp.showCmd == SW_MAXIMIZE;

  // Windows 11 (build 22000+) native rounded corners
  if (buildNumber >= kWin11Build) {
    SetWindowRgn(hwnd, NULL, TRUE);
    DWORD corner =
        rounded_corners_enabled_ && !isMaximized ? kDwmCornerRound
                                                 : kDwmCornerDoNotRound;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                          sizeof(corner));
    return;
  }

  // Windows 10 (build < 22000)
  if (!rounded_corners_enabled_ || isMaximized) {
    SetWindowRgn(hwnd, NULL, TRUE);
    return;
  }

  const int radius = ScaleForWindowDpi(hwnd, std::max(4, corner_radius_));
  const int diameter = radius * 2;
  HRGN hRgn =
      CreateRoundRectRgn(0, 0, width + 1, height + 1, diameter, diameter);
  if (hRgn) {
    SetWindowRgn(hwnd, hRgn, TRUE);
  }
}

std::string FlutterWindow::PickFolder() {
  std::string result;
  HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

  if (SUCCEEDED(hr)) {
    IFileOpenDialog* pFileOpen = nullptr;
    hr = CoCreateInstance(CLSID_FileOpenDialog, NULL, CLSCTX_ALL,
                         IID_IFileOpenDialog, reinterpret_cast<void**>(&pFileOpen));

    if (SUCCEEDED(hr)) {
      // Set options to pick folders
      DWORD dwOptions;
      if (SUCCEEDED(pFileOpen->GetOptions(&dwOptions))) {
        pFileOpen->SetOptions(dwOptions | FOS_PICKFOLDERS);
      }

      // Show the dialog
      hr = pFileOpen->Show(GetHandle());

      if (SUCCEEDED(hr)) {
        IShellItem* pItem = nullptr;
        hr = pFileOpen->GetResult(&pItem);

        if (SUCCEEDED(hr)) {
          PWSTR pszFilePath = nullptr;
          hr = pItem->GetDisplayName(SIGDN_FILESYSPATH, &pszFilePath);

          if (SUCCEEDED(hr)) {
            // Convert wide string to UTF-8
            int size_needed = WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, NULL, 0, NULL, NULL);
            if (size_needed > 0) {
              std::vector<char> buffer(size_needed);
              WideCharToMultiByte(CP_UTF8, 0, pszFilePath, -1, buffer.data(), size_needed, NULL, NULL);
              result = buffer.data();
            }
            CoTaskMemFree(pszFilePath);
          }
          pItem->Release();
        }
      }
      pFileOpen->Release();
    }
    CoUninitialize();
  }

  return result;
}

void FlutterWindow::SetClipboardListenerEnabled(bool enabled) {
  if (clipboard_listener_registered_ == enabled) {
    return;
  }
  
  clipboard_listener_registered_ = enabled;
  if (enabled) {
    AddClipboardFormatListener(GetHandle());
  } else {
    RemoveClipboardFormatListener(GetHandle());
  }
}

void FlutterWindow::DispatchClipboardChanged() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }
  flutter::MethodChannel<> clipboard_channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/clipboard",
      &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel.InvokeMethod("onClipboardChanged", nullptr);
}
