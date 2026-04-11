#include "flutter_window.h"

#include <optional>
#include <cstdio>
#include <cstddef>
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

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWA_MICA_EFFECT
#define DWMWA_MICA_EFFECT 1029
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

static void LogA(const char* s) {
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
    effect_mode_ = 0;
  }
}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  LogA("FlutterWindow::OnCreate begin");

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  if (kind_ == WindowKind::kMain) {
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
      } else {
        this->Show();
      }
    } else {
      LogA("NextFrameCallback: skipping native show for auto-start launch");
    }
    ApplyWindowEffect(hwnd);
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
  LogA("=== FlutterWindow::OnDestroy START ===");
  LogA("=== FlutterWindow::OnDestroy END ===");

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_DWMCOMPOSITIONCHANGED:
    case WM_THEMECHANGED:
    case WM_SETTINGCHANGE:
    case WM_DPICHANGED:
    case WM_DISPLAYCHANGE:
    {
      // Re-apply effect on system-level changes
      ApplyWindowEffect(hwnd);
      break;
    }
    case WM_SIZE:
    {
      // Update rounded corners on Win10 when window size changes
      DWORD buildNumber = GetWindowsBuildNumber();
      if (buildNumber < 22000) {
        // Use timer to debounce rapid size changes
        SetTimer(hwnd, 2, 50, NULL);
      }
      break;
    }
    // Win10: use opaque tinted gradient during drag (no blur cost, no transparency)
    case WM_ENTERSIZEMOVE:
    {
      if (GetWindowsBuildNumber() < 22000 && drag_suspend_ && effect_mode_ > 0 && !is_suspended_) {
        if (pSetWindowCompositionAttribute) {
          ACCENT_POLICY policy{};
          policy.AccentState = ACCENT_ENABLE_TRANSPARENTGRADIENT;
          policy.AccentFlags = 2;
          // Near-opaque dark fill matching typical dark theme background
          // 0xF0 alpha + 0x202020 RGB = dark gray, visually close to acrylic
          policy.GradientColor = 0xF0202020;
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
      if (GetWindowsBuildNumber() < 22000 && is_suspended_) {
        is_suspended_ = false;
        ApplyWindowEffect(hwnd);
      }
      break;
    }
    case WM_TIMER:
    {
      if (wparam == 1) {
        KillTimer(hwnd, 1);
        ApplyWindowEffect(hwnd);
      } else if (wparam == 2) {
        KillTimer(hwnd, 2);
        ApplyWindowEffect(hwnd);
      }
      break;
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
      CloseCurrentWindow();
      return 0;
    case kPopupMinimizeMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Popup minimize message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      MinimizeCurrentWindow();
      return 0;
    case kPopupStartDragMessage:
      {
        char buffer[256];
        sprintf_s(buffer, "Popup drag message received hwnd=%p", hwnd);
        LogA(buffer);
      }
      StartWindowDrag();
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

                result->Success(
                    flutter::EncodableValue(
                        CreatePopupWindow(*payload, window_title)));
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
          CloseCurrentWindow();
          return;
        } else if (call.method_name() == "minimizeWindow") {
          const HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(hwnd != nullptr));
          MinimizeCurrentWindow();
          return;
        } else if (call.method_name() == "startWindowDrag") {
          const HWND hwnd = GetHandle();
          result->Success(flutter::EncodableValue(hwnd != nullptr));
          StartWindowDrag();
          return;
        } else if (call.method_name() == "setWindowEffect") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto itMode = arguments->find(flutter::EncodableValue("mode"));
            auto itAlpha = arguments->find(flutter::EncodableValue("alpha"));
            auto itRoundedCorners =
                arguments->find(flutter::EncodableValue("roundedCornersEnabled"));
            auto itCornerRadius =
                arguments->find(flutter::EncodableValue("cornerRadius"));
            if (itMode != arguments->end()) {
              if (const std::string* s = std::get_if<std::string>(&itMode->second)) {
                if (*s == "none") effect_mode_ = 0;
                else if (*s == "blur") effect_mode_ = 1;
                else if (*s == "acrylic") effect_mode_ = 2;
                else if (*s == "mica_main") effect_mode_ = 3;
                else if (*s == "mica_transient") effect_mode_ = 4;
              }
            }
            if (itAlpha != arguments->end()) {
              if (const int32_t* a = std::get_if<int32_t>(&itAlpha->second)) {
                effect_alpha_ = std::max(0, std::min(255, *a));
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
            ApplyWindowEffect(GetHandle());
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
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::BringWindowToFront() {
  HWND hwnd = GetHandle();
  if (hwnd) {
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
    PostMessage(hwnd, WM_CLOSE, 0, 0);
  }
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

bool FlutterWindow::CreatePopupWindow(const std::string& payload_json,
                                      const std::wstring& window_title) {
  CleanupPopupWindows();

  flutter::DartProject popup_project(L"data");
  popup_project.set_dart_entrypoint("popupMain");
  popup_project.set_dart_entrypoint_arguments(
      std::vector<std::string>{payload_json});

  auto popup_window = std::make_unique<FlutterWindow>(
      popup_project, WindowKind::kPopup);

  Win32Window::Point origin(120, 120);
  Win32Window::Size size(745, 396);
  if (!popup_window->Create(window_title, origin, size)) {
    return false;
  }

  popup_window->SetQuitOnClose(false);
  CenterWindowOnWorkArea(popup_window->GetHandle());
  popup_window->BringWindowToFront();
  LogA("CreatePopupWindow immediate activation requested");
  g_popup_windows.push_back(std::move(popup_window));
  return true;
}

void FlutterWindow::CleanupPopupWindows() {
  CleanupClosedPopupWindows();
}


void FlutterWindow::ApplyWindowEffect(HWND hwnd) {
  if (!hwnd) return;

  // Debounce: avoid repeated calls in short time
  static DWORD lastApplyTime = 0;
  static int lastEffectMode = -1;
  static bool lastRoundedCornersEnabled = true;
  static int lastCornerRadius = 14;
  static RECT lastWindowRect = {0, 0, 0, 0};
  DWORD currentTime = GetTickCount();

  // Get current window size for Win10 rounded corners
  RECT windowRect;
  GetWindowRect(hwnd, &windowRect);
  int width = windowRect.right - windowRect.left;
  int height = windowRect.bottom - windowRect.top;

  // Allow immediate update if effect mode changed or window size changed
  bool modeChanged = (lastEffectMode != effect_mode_);
  bool cornerSettingChanged =
      (lastRoundedCornersEnabled != rounded_corners_enabled_) ||
      (lastCornerRadius != corner_radius_);
  bool sizeChanged = (width != (lastWindowRect.right - lastWindowRect.left) ||
                      height != (lastWindowRect.bottom - lastWindowRect.top));
  if (!modeChanged && !sizeChanged && !cornerSettingChanged &&
      (currentTime - lastApplyTime < 100)) {
    return;
  }
  lastApplyTime = currentTime;
  lastEffectMode = effect_mode_;
  lastRoundedCornersEnabled = rounded_corners_enabled_;
  lastCornerRadius = corner_radius_;
  lastWindowRect = windowRect;

  if (kind_ == WindowKind::kPopup) {
    BOOL dark = TRUE;
    DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                          sizeof(dark));
    ApplyRoundedCorners(hwnd, GetWindowsBuildNumber(), width, height);
    return;
  }

  DWORD buildNumber = GetWindowsBuildNumber();
  char logBuf[256];
  sprintf_s(logBuf, "ApplyWindowEffect: mode=%d, build=%lu, changed=%d, size=%dx%d", 
            effect_mode_, buildNumber, modeChanged, width, height);
  LogA(logBuf);

  // Load SetWindowCompositionAttribute
  if (!pSetWindowCompositionAttribute) {
    HMODULE user32 = LoadLibraryA("user32.dll");
    if (user32) {
      pSetWindowCompositionAttribute = reinterpret_cast<BOOL (WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBUTEDATA*)>(GetProcAddress(user32, "SetWindowCompositionAttribute"));
    }
  }

  // Set dark mode
  BOOL dark = TRUE;
  DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));

  // STEP 1: Always reset all effects first when mode changes
  if (modeChanged) {
    LogA("Resetting all effects...");

    // Reset Mica/Backdrop
    if (buildNumber >= 22523) {
      INT backdropType = 0;  // DWMSBT_AUTO (disable)
      DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdropType, sizeof(backdropType));
    } else if (buildNumber >= 22000) {
      BOOL mica = FALSE;
      DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
    }

    // Reset SetWindowCompositionAttribute
    if (pSetWindowCompositionAttribute) {
      ACCENT_POLICY policy{};
      policy.AccentState = ACCENT_DISABLED;
      policy.AccentFlags = 0;
      policy.GradientColor = 0;
      policy.AnimationId = 0;
      WINDOWCOMPOSITIONATTRIBUTEDATA data{};
      data.Attribute = 19;
      data.Data = &policy;
      data.SizeOfData = sizeof(policy);
      pSetWindowCompositionAttribute(hwnd, &data);
    }

    // Small delay to let the reset take effect
    Sleep(50);
  }

  // STEP 2: Extend frame into client area (needed for acrylic/blur effects)
  MARGINS margins = {-1, -1, -1, -1};
  HRESULT hrExtend = DwmExtendFrameIntoClientArea(hwnd, &margins);
  sprintf_s(logBuf, "DwmExtendFrameIntoClientArea hr=0x%08lX", hrExtend);
  LogA(logBuf);

  // STEP 3: Apply the new effect
  // Win11 22H2+ (build 22621+): Use DWMWA_SYSTEMBACKDROP_TYPE for all effects
  // Win11 21H2 (build 22000-22620): Use DWMWA_MICA_EFFECT for Mica, SetWindowCompositionAttribute for Acrylic
  // Win10: Use SetWindowCompositionAttribute for Acrylic/Blur
  
  if (buildNumber >= 22621) {
    // Windows 11 22H2+: Use modern backdrop API for everything
    INT backdropType = 1;  // DWMSBT_MAINWINDOW (default)
    
    if (effect_mode_ == 0) {
      backdropType = 1;  // DWMSBT_MAINWINDOW - no effect, solid
    } else if (effect_mode_ == 1 || effect_mode_ == 2) {
      // Blur or Acrylic - use Acrylic backdrop on Win11
      backdropType = 3;  // DWMSBT_TRANSIENTWINDOW (Acrylic)
    } else if (effect_mode_ == 3) {
      backdropType = 2;  // DWMSBT_MAINWINDOW (Mica)
    } else if (effect_mode_ == 4) {
      backdropType = 4;  // DWMSBT_TABBEDWINDOW (Mica Alt)
    }
    
    HRESULT hrBackdrop = DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdropType, sizeof(backdropType));
    sprintf_s(logBuf, "Win11 22H2+: SYSTEMBACKDROP_TYPE=%d hr=0x%08lX", backdropType, hrBackdrop);
    LogA(logBuf);
    
  } else if (buildNumber >= 22000) {
    // Windows 11 21H2: Mixed approach
    if (effect_mode_ == 3 || effect_mode_ == 4) {
      // Mica - use DWMWA_MICA_EFFECT
      BOOL mica = TRUE;
      HRESULT hrMica = DwmSetWindowAttribute(hwnd, DWMWA_MICA_EFFECT, &mica, sizeof(mica));
      sprintf_s(logBuf, "Win11 21H2: MICA_EFFECT hr=0x%08lX", hrMica);
      LogA(logBuf);
    } else if (effect_mode_ > 0 && pSetWindowCompositionAttribute) {
      // Acrylic/Blur - use SetWindowCompositionAttribute
      ACCENT_POLICY policy{};
      if (effect_mode_ == 1) {
        policy.AccentState = ACCENT_ENABLE_BLURBEHIND;
        policy.AccentFlags = 2;
      } else {
        policy.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND;
        policy.AccentFlags = 2;
        unsigned int a = static_cast<unsigned int>(effect_alpha_ & 0xFF);
        policy.GradientColor = (a << 24) | 0x000000;
      }
      WINDOWCOMPOSITIONATTRIBUTEDATA data{};
      data.Attribute = 19;
      data.Data = &policy;
      data.SizeOfData = sizeof(policy);
      pSetWindowCompositionAttribute(hwnd, &data);
      LogA("Win11 21H2: Using SetWindowCompositionAttribute for Acrylic");
    }
  } else {
    // Windows 10: Use SetWindowCompositionAttribute
    if (effect_mode_ > 0 && pSetWindowCompositionAttribute) {
      ACCENT_POLICY policy{};
      if (effect_mode_ == 1) {
        policy.AccentState = ACCENT_ENABLE_BLURBEHIND;
        policy.AccentFlags = 2;
        policy.GradientColor = 0;
      } else {
        // Acrylic or Mica fallback
        policy.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND;
        policy.AccentFlags = 2;
        unsigned int a = static_cast<unsigned int>(effect_alpha_ & 0xFF);
        policy.GradientColor = (a << 24) | 0x000000;
      }
      policy.AnimationId = 0;

      WINDOWCOMPOSITIONATTRIBUTEDATA data{};
      data.Attribute = 19;
      data.Data = &policy;
      data.SizeOfData = sizeof(policy);
      BOOL ok = pSetWindowCompositionAttribute(hwnd, &data);
      sprintf_s(logBuf, "Win10: SetWindowCompositionAttribute AccentState=%d ok=%d", policy.AccentState, ok);
      LogA(logBuf);
    }
  }

  ApplyRoundedCorners(hwnd, buildNumber, width, height);

  // Force window redraw
  if (modeChanged || cornerSettingChanged) {
    RedrawWindow(hwnd, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW | RDW_FRAME);
  }
}

DWORD FlutterWindow::WindowStyle() const {
  if (kind_ == WindowKind::kPopup) {
    return WS_POPUP | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX;
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
  return kind_ != WindowKind::kPopup;
}

void FlutterWindow::ApplyRoundedCorners(HWND hwnd,
                                        DWORD buildNumber,
                                        int width,
                                        int height) {
  if (!hwnd || width <= 0 || height <= 0) return;

  WINDOWPLACEMENT wp;
  wp.length = sizeof(WINDOWPLACEMENT);
  GetWindowPlacement(hwnd, &wp);
  const bool isMaximized = wp.showCmd == SW_MAXIMIZE;
  const bool useCustomRegionOnWin11 =
      buildNumber >= 22000 && (effect_mode_ == 1 || effect_mode_ == 2);

  if (buildNumber >= 22000 && !useCustomRegionOnWin11) {
    SetWindowRgn(hwnd, NULL, TRUE);
    DWORD corner = rounded_corners_enabled_ && !isMaximized ? 2 : 1;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                          sizeof(corner));
    return;
  }

  if (!rounded_corners_enabled_ || isMaximized) {
    SetWindowRgn(hwnd, NULL, TRUE);
    if (buildNumber >= 22000) {
      DWORD corner = 1;
      DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                            sizeof(corner));
    }
    return;
  }

  const int radius = std::max(4, corner_radius_);
  const int diameter = radius * 2;
  HRGN hRgn =
      CreateRoundRectRgn(0, 0, width + 1, height + 1, diameter, diameter);
  if (hRgn) {
    SetWindowRgn(hwnd, hRgn, TRUE);
  }
  if (buildNumber >= 22000) {
    DWORD corner = 1;
    DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &corner,
                          sizeof(corner));
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
