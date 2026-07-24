#include "flutter_window.h"

#include <algorithm>
#include <optional>
#include <cstdio>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <thread>
#include <utility>
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

constexpr int kEffectNone = static_cast<int>(WindowBackdropKind::kNone);
constexpr int kEffectBlur = static_cast<int>(WindowBackdropKind::kBlur);
constexpr int kEffectAcrylic = static_cast<int>(WindowBackdropKind::kAcrylic);
constexpr int kEffectMica = static_cast<int>(WindowBackdropKind::kMica);
constexpr int kEffectMicaAlt = static_cast<int>(WindowBackdropKind::kMicaAlt);

static int ScaleForWindowDpi(HWND hwnd, int logical_pixels) {
  if (!hwnd || logical_pixels <= 0) {
    return logical_pixels;
  }
  const UINT dpi = ::GetDpiForWindow(hwnd);
  return std::max(1, ::MulDiv(logical_pixels, dpi == 0 ? 96 : dpi, 96));
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

flutter::EncodableMap BuildWindowEffectPayload(
    const WindowBackdropApplyResult& apply_result,
    const WindowBackdropCapabilities& capabilities) {
  flutter::EncodableMap payload;
  payload[flutter::EncodableValue("requestedMode")] =
      flutter::EncodableValue(
          WindowBackdropController::KindName(apply_result.requested_kind));
  payload[flutter::EncodableValue("appliedMode")] =
      flutter::EncodableValue(
          WindowBackdropController::KindName(apply_result.applied_kind));
  payload[flutter::EncodableValue("usedFallback")] =
      flutter::EncodableValue(apply_result.used_fallback);
  payload[flutter::EncodableValue("hresult")] = flutter::EncodableValue(
      static_cast<int64_t>(apply_result.hresult));
  payload[flutter::EncodableValue("windowsBuild")] = flutter::EncodableValue(
      static_cast<int32_t>(capabilities.windows_build));
  payload[flutter::EncodableValue("isWindows11")] =
      flutter::EncodableValue(capabilities.is_windows_11);
  payload[flutter::EncodableValue("supportsSystemBackdrop")] =
      flutter::EncodableValue(capabilities.supports_system_backdrop);
  payload[flutter::EncodableValue("compositionEnabled")] =
      flutter::EncodableValue(capabilities.composition_enabled);
  payload[flutter::EncodableValue("transparencyEnabled")] =
      flutter::EncodableValue(capabilities.transparency_enabled);
  payload[flutter::EncodableValue("highContrast")] =
      flutter::EncodableValue(capabilities.high_contrast);
  return payload;
}

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

void PositionTrayMenuWindow(HWND hwnd, double target_x, double target_y) {
  if (!hwnd) {
    return;
  }

  RECT menu_rect{};
  GetWindowRect(hwnd, &menu_rect);
  const int menu_width = menu_rect.right - menu_rect.left;
  const int menu_height = menu_rect.bottom - menu_rect.top;

  POINT anchor{static_cast<LONG>(std::lround(target_x)),
               static_cast<LONG>(std::lround(target_y))};
  if (anchor.x == 0 && anchor.y == 0) {
    GetCursorPos(&anchor);
  }
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  const HMONITOR monitor =
      MonitorFromPoint(anchor, MONITOR_DEFAULTTONEAREST);
  if (!GetMonitorInfo(monitor, &monitor_info)) {
    return;
  }

  const RECT& work_area = monitor_info.rcWork;
  const int gap = ScaleForWindowDpi(hwnd, 6);
  const int edge_margin = ScaleForWindowDpi(hwnd, 2);
  int pos_x = anchor.x - (menu_width / 2);
  const int position_above = anchor.y - menu_height - gap;
  const int position_below = anchor.y + gap;
  int pos_y = position_above >= work_area.top + edge_margin
                  ? position_above
                  : position_below;

  if (pos_x + menu_width > work_area.right - edge_margin) {
    pos_x = work_area.right - edge_margin - menu_width;
  }
  if (pos_x < work_area.left + edge_margin) {
    pos_x = work_area.left + edge_margin;
  }
  if (pos_y + menu_height > work_area.bottom - edge_margin) {
    pos_y = work_area.bottom - edge_margin - menu_height;
  }
  if (pos_y < work_area.top + edge_margin) {
    pos_y = work_area.top + edge_margin;
  }

  SetWindowPos(hwnd, HWND_TOPMOST, pos_x, pos_y, 0, 0,
               SWP_NOSIZE | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
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
  const WindowBackdropRole backdrop_role =
      kind_ == WindowKind::kMain
          ? WindowBackdropRole::kMain
          : (kind_ == WindowKind::kPopup ? WindowBackdropRole::kPopup
                                         : WindowBackdropRole::kTrayMenu);
  backdrop_controller_ = std::make_unique<WindowBackdropController>(
      GetHandle(), backdrop_role);

  const HRESULT prepare_surface_result =
      backdrop_controller_->PrepareTransparentHost();
  char surface_log[128];
  sprintf_s(surface_log, "PrepareTransparentHost kind=%s hr=0x%08lX",
            WindowKindName(), prepare_surface_result);
  LogA(surface_log);

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

  // Secondary windows receive their material snapshot before Create(). The
  // main window is configured once by Dart after window_manager finishes its
  // size/title-bar setup.
  if (kind_ != WindowKind::kMain) {
    ApplyWindowEffect(GetHandle(), true);
  }

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    LogA("NextFrameCallback begin");
    first_frame_rendered_ = true;
    if (!launch_hidden_) {
      if (kind_ == WindowKind::kPopup) {
        BringWindowToFront();
      } else if (kind_ == WindowKind::kTrayMenu) {
        this->Show();
        const HWND hwnd = GetHandle();
        if (hwnd) {
          SetForegroundWindow(hwnd);
          SetFocus(hwnd);
        }
      }
    } else {
      LogA("NextFrameCallback: skipping native show for auto-start launch");
    }
    if (kind_ == WindowKind::kTrayMenu &&
        !pending_tray_payload_json_.empty()) {
      std::string pending_payload = std::move(pending_tray_payload_json_);
      pending_tray_payload_json_.clear();
      SendTrayMenuPayloadToFlutter(pending_payload);
    }
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
  backdrop_controller_.reset();

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
      // window_manager consumes WM_GETMINMAXINFO after applying its configured
      // track limits. Let the runner merge in the monitor work-area bounds for
      // the custom frame before returning the plugin result.
      if (message == WM_GETMINMAXINFO) {
        Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      } else if (message == WM_EXITSIZEMOVE) {
        // window_manager returns an engaged LRESULT for this message after
        // emitting its resize/move events. Complete the native material and
        // Flutter-surface transition before returning that plugin result.
        FinishInteractiveMoveResize();
      }
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
    case single_instance::kActivateExistingWindowMessage:
      if (kind_ == WindowKind::kMain) {
        BringWindowToFront();
      }
      return 0;
    case WM_ACTIVATE:
      if (kind_ == WindowKind::kTrayMenu && LOWORD(wparam) == WA_INACTIVE) {
        ShowWindow(hwnd, SW_HIDE);
        return 0;
      }
      break;
    case WM_SHOWWINDOW:
      if (wparam == TRUE) {
        RefreshWindowEffectState();
        if (flutter_controller_) {
          flutter_controller_->ForceRedraw();
        }
      }
      break;
    case WM_DWMCOMPOSITIONCHANGED:
    case WM_DWMCOLORIZATIONCOLORCHANGED:
    case WM_THEMECHANGED:
    case WM_SETTINGCHANGE:
    case WM_DPICHANGED:
    case WM_DISPLAYCHANGE:
    {
      RefreshWindowEffectState();
      break;
    }
    case WM_SIZE:
    {
      const LRESULT resize_result =
          Win32Window::MessageHandler(hwnd, message, wparam, lparam);
      if (backdrop_controller_) {
        backdrop_controller_->UpdateWindowGeometry();
      }
      const bool placement_transition =
          (wparam == SIZE_MAXIMIZED &&
           last_window_size_state_ != SIZE_MAXIMIZED) ||
          (wparam == SIZE_RESTORED &&
           (last_window_size_state_ == SIZE_MAXIMIZED ||
            last_window_size_state_ == SIZE_MINIMIZED));
      last_window_size_state_ = wparam;

      // A same-size child HWND update is only needed for the first
      // programmatic layout and placement-state transitions. Applying the
      // width nudge to every WM_SIZE doubles resize traffic and can visibly
      // stutter around responsive-layout breakpoints.
      if (flutter_controller_ && wparam != SIZE_MINIMIZED &&
          !is_interactive_resize_ &&
          (flutter_surface_refresh_pending_ || placement_transition)) {
        RefreshFlutterSurface();
        flutter_surface_refresh_pending_ = false;
      }
      return resize_result;
    }
    case WM_ENTERSIZEMOVE:
    {
      is_interactive_resize_ = true;
      interactive_resize_observed_ = false;
      if (drag_suspend_ && backdrop_controller_) {
        backdrop_controller_->SuspendLegacyEffectForMove();
      }
      break;
    }
    case WM_SIZING:
      interactive_resize_observed_ = true;
      break;
    case WM_EXITSIZEMOVE:
      FinishInteractiveMoveResize();
      break;
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
        } else if (call.method_name() == "getWindowPlacement") {
          const HWND hwnd = GetHandle();
          WINDOWPLACEMENT placement{};
          placement.length = sizeof(placement);
          if (hwnd == nullptr ||
              ::GetWindowPlacement(hwnd, &placement) == FALSE) {
            result->Error("FAILED", "GetWindowPlacement failed");
            return;
          }

          RECT normal_rect = placement.rcNormalPosition;
          int normal_width = normal_rect.right - normal_rect.left;
          int normal_height = normal_rect.bottom - normal_rect.top;
          if (normal_width <= 0 || normal_height <= 0) {
            RECT current_rect{};
            if (::GetWindowRect(hwnd, &current_rect) == FALSE) {
              result->Error("FAILED", "GetWindowRect failed");
              return;
            }
            normal_width = current_rect.right - current_rect.left;
            normal_height = current_rect.bottom - current_rect.top;
          }

          const UINT dpi = ::GetDpiForWindow(hwnd);
          const double scale =
              static_cast<double>(dpi == 0 ? USER_DEFAULT_SCREEN_DPI : dpi) /
              USER_DEFAULT_SCREEN_DPI;
          flutter::EncodableMap payload;
          payload[flutter::EncodableValue("normalWidth")] =
              flutter::EncodableValue(normal_width / scale);
          payload[flutter::EncodableValue("normalHeight")] =
              flutter::EncodableValue(normal_height / scale);
          payload[flutter::EncodableValue("isMaximized")] =
              flutter::EncodableValue(::IsZoomed(hwnd) != FALSE);
          payload[flutter::EncodableValue("isMinimized")] =
              flutter::EncodableValue(::IsIconic(hwnd) != FALSE);
          payload[flutter::EncodableValue("isVisible")] =
              flutter::EncodableValue(::IsWindowVisible(hwnd) != FALSE);
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
          const int target_width = kind_ == WindowKind::kTrayMenu
                                       ? ScaleForWindowDpi(hwnd, safe_width)
                                       : safe_width;
          const int target_height = kind_ == WindowKind::kTrayMenu
                                        ? ScaleForWindowDpi(hwnd, safe_height)
                                        : safe_height;

          const bool suspended_here = backdrop_controller_ &&
                                      backdrop_controller_
                                          ->SuspendLegacyEffectForMove();

          const BOOL ok = SetWindowPos(
              hwnd, nullptr, 0, 0, target_width, target_height,
              SWP_NOMOVE | SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOZORDER);

          if (suspended_here) {
            backdrop_controller_->ResumeLegacyEffectAfterMove();
          }
          if (backdrop_controller_) {
            backdrop_controller_->UpdateWindowGeometry();
          }

          result->Success(flutter::EncodableValue(ok != FALSE));
          return;
        } else if (call.method_name() == "getWindowCapabilities") {
          const WindowBackdropCapabilities capabilities =
              backdrop_controller_
                  ? backdrop_controller_->capabilities()
                  : WindowBackdropController::DetectCapabilities();
          flutter::EncodableMap response;
          response[flutter::EncodableValue("windowsBuild")] =
              flutter::EncodableValue(
                  static_cast<int32_t>(capabilities.windows_build));
          response[flutter::EncodableValue("isWindows11")] =
              flutter::EncodableValue(capabilities.is_windows_11);
          response[flutter::EncodableValue("supportsSystemBackdrop")] =
              flutter::EncodableValue(capabilities.supports_system_backdrop);
          response[flutter::EncodableValue("compositionEnabled")] =
              flutter::EncodableValue(capabilities.composition_enabled);
          response[flutter::EncodableValue("transparencyEnabled")] =
              flutter::EncodableValue(capabilities.transparency_enabled);
          response[flutter::EncodableValue("highContrast")] =
              flutter::EncodableValue(capabilities.high_contrast);
          result->Success(flutter::EncodableValue(response));
          return;
        } else if (call.method_name() == "setWindowEffect") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            const bool first_effect_configuration = !effect_configured_;
            auto itMode = arguments->find(flutter::EncodableValue("mode"));
            auto itAlpha = arguments->find(flutter::EncodableValue("alpha"));
            auto itRoundedCorners =
                arguments->find(flutter::EncodableValue("roundedCornersEnabled"));
            auto itCornerRadius =
                arguments->find(flutter::EncodableValue("cornerRadius"));
            auto itDarkMode =
                arguments->find(flutter::EncodableValue("darkMode"));
            auto itForce =
                arguments->find(flutter::EncodableValue("force"));
            bool force = false;
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
            if (itForce != arguments->end()) {
              if (const bool* requested_force =
                      std::get_if<bool>(&itForce->second)) {
                force = *requested_force;
              }
            }
            effect_configured_ = true;
            const WindowBackdropApplyResult apply_result =
                ApplyWindowEffect(GetHandle(), force);
            // Dart applies the initial material only after window_manager has
            // committed the launch size. Refreshing here avoids consuming the
            // one-shot surface correction on an earlier bootstrap WM_SIZE.
            if (kind_ == WindowKind::kMain && flutter_controller_ &&
                (force || first_effect_configuration)) {
              RefreshFlutterSurface();
              flutter_surface_refresh_pending_ = false;
            }
            const WindowBackdropCapabilities capabilities =
                backdrop_controller_->capabilities();
            flutter::EncodableMap response =
                BuildWindowEffectPayload(apply_result, capabilities);
            result->Success(flutter::EncodableValue(response));
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
        } else if (call.method_name() == "beginApplicationExit") {
          result->Success(flutter::EncodableValue(
              single_instance::MarkWindowExiting(g_main_window_handle)));
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
                ::ShowWindow(hwnd, SW_SHOWNORMAL);
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
          if (g_main_flutter_window != nullptr) {
            g_main_flutter_window->BringWindowToFront();
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

          const bool should_show_main = action != "exit_application";
          if (should_show_main && g_main_flutter_window != nullptr) {
            g_main_flutter_window->BringWindowToFront();
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
        } else if (call.method_name() == "setNativeRenderLoggingEnabled") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("INVALID_ARGUMENT", "Missing map");
            return;
          }

          const auto enabled_it =
              arguments->find(flutter::EncodableValue("enabled"));
          if (enabled_it == arguments->end()) {
            result->Error("INVALID_ARGUMENT", "Missing enabled parameter");
            return;
          }

          const bool* enabled = std::get_if<bool>(&enabled_it->second);
          if (enabled == nullptr) {
            result->Error("INVALID_ARGUMENT", "Enabled must be bool");
            return;
          }

          SetNativeRenderLoggingEnabled(*enabled);
          result->Success(
              flutter::EncodableValue(IsNativeRenderLoggingEnabled()));
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

    // Preserve maximized placement; restoring is only valid for an iconified
    // window. Calling SW_RESTORE unconditionally turns a hidden maximized main
    // window back into a normal window.
    const bool was_visible = IsWindowVisible(hwnd) != FALSE;
    const bool was_iconic = IsIconic(hwnd) != FALSE;
    ShowWindow(hwnd, was_iconic ? SW_RESTORE : SW_SHOW);
    // Hidden windows refresh synchronously from WM_SHOWWINDOW. Minimized or
    // already-visible windows do not, so refresh them explicitly here.
    if (was_visible || was_iconic) {
      RefreshWindowEffectState();
    }
    // A hidden transparent host can accept child WM_SIZE messages without DWM
    // committing the new Flutter swapchain. Refresh once the parent is visible
    // so cold-start and tray-restore frames use the current client bounds.
    if (kind_ == WindowKind::kMain && flutter_controller_) {
      RefreshFlutterSurface();
      flutter_surface_refresh_pending_ = false;
    }
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

bool FlutterWindow::RefreshFlutterSurface() {
  if (!flutter_controller_) {
    return false;
  }

  if (kind_ != WindowKind::kMain) {
    flutter_controller_->ForceRedraw();
    return true;
  }

  const HWND host = GetHandle();
  const HWND view = flutter_controller_->view()->GetNativeWindow();
  RECT client{};
  if (!host || !view || !::GetClientRect(host, &client)) {
    return false;
  }

  const int width = client.right - client.left;
  const int height = client.bottom - client.top;
  if (width <= 0 || height <= 0 || ::IsIconic(host)) {
    return false;
  }

  constexpr UINT flags = SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOOWNERZORDER |
                         SWP_NOZORDER | SWP_FRAMECHANGED;
  const BOOL expanded =
      ::SetWindowPos(view, nullptr, 0, 0, width + 1, height, flags);
  const BOOL restored =
      ::SetWindowPos(view, nullptr, 0, 0, width, height, flags);
  flutter_controller_->ForceRedraw();

  char buffer[192];
  sprintf_s(buffer, sizeof(buffer),
            "RefreshFlutterSurface size=%dx%d expanded=%d restored=%d", width,
            height, expanded != FALSE, restored != FALSE);
  LogA(buffer);
  return expanded != FALSE && restored != FALSE;
}

void FlutterWindow::RefreshWindowEffectState() {
  if (!backdrop_controller_ ||
      (kind_ == WindowKind::kMain && !effect_configured_)) {
    return;
  }

  const WindowBackdropApplyResult apply_result =
      ApplyWindowEffect(GetHandle(), true);
  NotifyWindowEffectStateChanged(apply_result);
}

void FlutterWindow::NotifyWindowEffectStateChanged(
    const WindowBackdropApplyResult& apply_result) {
  if (kind_ == WindowKind::kTrayMenu || !flutter_controller_ ||
      !flutter_controller_->engine()) {
    return;
  }

  flutter::MethodChannel<> channel(
      flutter_controller_->engine()->messenger(),
      "com.hanabi.download/window",
      &flutter::StandardMethodCodec::GetInstance());
  const WindowBackdropCapabilities capabilities =
      backdrop_controller_->capabilities();
  channel.InvokeMethod(
      "windowEffectStateChanged",
      std::make_unique<flutter::EncodableValue>(
          BuildWindowEffectPayload(apply_result, capabilities)));
}

void FlutterWindow::FinishInteractiveMoveResize() {
  const bool resized = interactive_resize_observed_;
  is_interactive_resize_ = false;
  interactive_resize_observed_ = false;

  if (backdrop_controller_) {
    backdrop_controller_->ResumeLegacyEffectAfterMove();
    backdrop_controller_->UpdateWindowGeometry();
  }
  if (resized && flutter_controller_) {
    RefreshFlutterSurface();
    flutter_surface_refresh_pending_ = false;
  }
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
  if (!first_frame_rendered_) {
    // The main engine can request the prewarmed menu before the secondary Dart
    // isolate has registered its channel handler. Keep only the latest request;
    // it contains the newest cursor position, theme, and task snapshot.
    pending_tray_payload_json_ = payload_json;
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
  LogA("CreatePopupWindow waiting for first Flutter frame before showing");
  g_popup_windows.push_back(std::move(popup_window));
  return true;
}

bool FlutterWindow::CreateTrayMenuWindow(const std::string& payload_json,
                                         const std::wstring& window_title,
                                         bool show_immediately) {
  CleanupClosedPopupWindows();

  if (g_tray_menu_window && g_tray_menu_window->GetHandle()) {
    const HWND existing_hwnd = g_tray_menu_window->GetHandle();
    if (show_immediately) {
      // Do not expose the previous payload while Flutter is rebuilding and
      // measuring the new flyout. Dart shows the window atomically through
      // positionTrayMenu once the final size is known.
      ::ShowWindow(existing_hwnd, SW_HIDE);
    }
    g_tray_menu_window->SendTrayMenuPayloadToFlutter(payload_json);
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
  g_tray_menu_window = std::move(tray_window);
  return true;
}

void FlutterWindow::CleanupPopupWindows() {
  CleanupClosedPopupWindows();
}

WindowBackdropApplyResult FlutterWindow::ApplyWindowEffect(HWND hwnd,
                                                           bool force) {
  if (!hwnd || !backdrop_controller_ ||
      (kind_ == WindowKind::kMain && !effect_configured_)) {
    return {WindowBackdropKind::kNone, WindowBackdropKind::kNone, S_FALSE,
            false};
  }

  WindowBackdropConfig config;
  config.kind = static_cast<WindowBackdropKind>(effect_mode_);
  config.alpha = effect_alpha_;
  config.dark_mode = dark_mode_;
  config.rounded_corners_enabled = rounded_corners_enabled_;
  config.corner_radius = corner_radius_;

  const WindowBackdropApplyResult apply_result =
      backdrop_controller_->Apply(config, force);
  const WindowBackdropCapabilities capabilities =
      backdrop_controller_->capabilities();

  char log_buffer[320];
  sprintf_s(
      log_buffer,
      "WindowBackdrop apply kind=%s requested=%s applied=%s build=%lu "
      "hr=0x%08lX fallback=%d transparency=%d",
      WindowKindName(),
      WindowBackdropController::KindName(apply_result.requested_kind),
      WindowBackdropController::KindName(apply_result.applied_kind),
      capabilities.windows_build, apply_result.hresult,
      apply_result.used_fallback ? 1 : 0,
      capabilities.transparency_enabled ? 1 : 0);
  LogA(log_buffer);

  if (kind_ == WindowKind::kTrayMenu) {
    ApplyTrayMenuWindowRegion(hwnd);
  }
  return apply_result;
}

DWORD FlutterWindow::WindowStyle() const {
  if (kind_ == WindowKind::kMain) {
    // Retain the resize frame, system menu, and min/max capabilities needed by
    // Snap Layouts while leaving the caption entirely client-owned.
    return (WS_OVERLAPPEDWINDOW & ~WS_CAPTION) | WS_CLIPCHILDREN |
           WS_CLIPSIBLINGS;
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
  if (kind_ == WindowKind::kTrayMenu) {
    // Tray flyouts should never create a taskbar button or Alt+Tab entry, but
    // they must remain activatable so focus loss can dismiss them reliably.
    return WS_EX_TOOLWINDOW;
  }
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
