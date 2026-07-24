#include "win32_window.h"

#include <algorithm>
#include <dwmapi.h>
#include <cstdio>
#include <flutter_windows.h>
#include <windowsx.h>

#include "resource.h"

#pragma comment(lib, "dwmapi.lib")

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;
#ifdef _DEBUG
static bool g_native_render_logging_enabled = true;
#else
static bool g_native_render_logging_enabled = false;
#endif

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

int ScaleForWindowDpi(HWND hwnd, int logical_pixels) {
  if (!hwnd || logical_pixels <= 0) {
    return logical_pixels;
  }
  const UINT dpi = GetDpiForWindow(hwnd);
  return std::max(1, MulDiv(logical_pixels, dpi == 0 ? 96 : dpi, 96));
}

void LogRenderA(const char* s) {
  if (!g_native_render_logging_enabled) {
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

  static bool initialized_for_process = false;
  char exe_path[MAX_PATH] = {0};
  GetModuleFileNameA(NULL, exe_path, MAX_PATH);
  char* slash = strrchr(exe_path, '\\');
  if (slash) {
    *(slash + 1) = '\0';
  }
  strcat_s(exe_path, MAX_PATH, "window_render.log");

  FILE* fp = nullptr;
  fopen_s(&fp, exe_path, initialized_for_process ? "a" : "w");
  if (fp) {
    fprintf(fp, "%s\n", formatted);
    fclose(fp);
    initialized_for_process = true;
  }
}

void LogWindowStyles(const char* prefix, HWND hwnd) {
  if (!hwnd) {
    return;
  }

  RECT window_rect{};
  RECT client_rect{};
  GetWindowRect(hwnd, &window_rect);
  GetClientRect(hwnd, &client_rect);

  char buffer[512];
  const auto style = static_cast<unsigned long long>(
      GetWindowLongPtr(hwnd, GWL_STYLE));
  const auto ex_style = static_cast<unsigned long long>(
      GetWindowLongPtr(hwnd, GWL_EXSTYLE));
  const BOOL enabled = IsWindowEnabled(hwnd);
  const BOOL visible = IsWindowVisible(hwnd);
  sprintf_s(
      buffer, sizeof(buffer),
      "%s hwnd=%p style=0x%llX exStyle=0x%llX enabled=%d visible=%d "
      "window=%dx%d client=%dx%d dpi=%u",
      prefix, hwnd, style, ex_style, enabled, visible,
      window_rect.right - window_rect.left, window_rect.bottom - window_rect.top,
      client_rect.right - client_rect.left,
      client_rect.bottom - client_rect.top, GetDpiForWindow(hwnd));
  LogRenderA(buffer);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

void SetNativeRenderLoggingEnabled(bool enabled) {
  g_native_render_logging_enabled = enabled;
}

bool IsNativeRenderLoggingEnabled() {
  return g_native_render_logging_enabled;
}

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindowEx(
      WindowExStyle(),
      window_class, title.c_str(), 
      WindowStyle(),
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  // CreateWindowEx can normalize an overlapped style by adding WS_CAPTION
  // back even when the caller deliberately omitted it. Normalize the style
  // once while the window is still hidden and before Flutter creates its
  // child surface. Repeating this after Flutter starts would force unnecessary
  // non-client recalculations and can invalidate the transparent swap chain.
  if (HasCustomFrame()) {
    const LONG_PTR style = GetWindowLongPtr(window, GWL_STYLE);
    if ((style & WS_CAPTION) != 0) {
      SetWindowLongPtr(window, GWL_STYLE, style & ~WS_CAPTION);
      SetWindowPos(window, nullptr, 0, 0, 0, 0,
                   SWP_FRAMECHANGED | SWP_NOACTIVATE | SWP_NOMOVE |
                       SWP_NOOWNERZORDER | SWP_NOSIZE | SWP_NOZORDER);
      LogWindowStyles("Normalized custom frame", window);
    }
  }

  // Custom-frame visuals are configured by WindowBackdropController after the
  // HWND exists. Native-frame windows keep the Flutter template theme path.
  if (!HasCustomFrame()) {
    UpdateTheme(window);
  }

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_CLOSE:
      LogRenderA("=== WM_CLOSE ===");
      break;
      
    case WM_DESTROY:
      OnDestroy();
      window_handle_ = nullptr;
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_GETMINMAXINFO: {
      if (HasCustomFrame()) {
        auto minmax_info = reinterpret_cast<MINMAXINFO*>(lparam);
        MONITORINFO monitor_info{};
        monitor_info.cbSize = sizeof(monitor_info);
        HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
        if (GetMonitorInfo(monitor, &monitor_info)) {
          const RECT& work_area = monitor_info.rcWork;
          const RECT& monitor_area = monitor_info.rcMonitor;
          minmax_info->ptMaxPosition.x = work_area.left - monitor_area.left;
          minmax_info->ptMaxPosition.y = work_area.top - monitor_area.top;
          minmax_info->ptMaxSize.x = work_area.right - work_area.left;
          minmax_info->ptMaxSize.y = work_area.bottom - work_area.top;
        }
        return 0;
      }
      break;
    }
    case WM_SIZE: {
      LogRenderA("Win32Window WM_SIZE");
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      LogRenderA("Win32Window WM_ACTIVATE");
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_SETFOCUS:
      LogRenderA("Win32Window WM_SETFOCUS");
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_MOUSEACTIVATE:
      {
        char buffer[256];
        sprintf_s(
            buffer, sizeof(buffer),
            "Win32Window WM_MOUSEACTIVATE hwnd=%p foreground=%p active=%p child=%p",
            hwnd, GetForegroundWindow(), GetActiveWindow(), child_content_);
        LogRenderA(buffer);
      }
      break;

    case WM_LBUTTONDOWN:
      LogRenderA("Win32Window WM_LBUTTONDOWN");
      break;

    case WM_LBUTTONUP:
      LogRenderA("Win32Window WM_LBUTTONUP");
      break;

    case WM_NCACTIVATE:
      if (HasCustomFrame()) {
        char buffer[128];
        sprintf_s(buffer, sizeof(buffer), "Win32Window WM_NCACTIVATE active=%d",
                  wparam != FALSE);
        LogRenderA(buffer);
        // Preserve DWM activation state without asking it to repaint a classic
        // caption over the client-owned title bar.
        return DefWindowProc(hwnd, message, wparam, -1);
      }
      break;

    case WM_NCPAINT:
      if (HasCustomFrame()) {
        LogRenderA("Win32Window WM_NCPAINT");
        return DefWindowProc(hwnd, message, wparam, lparam);
      }
      break;

    case WM_NCCALCSIZE:
      if (HasCustomFrame()) {
        // Let the Flutter client area fill the entire top-level window. This
        // must cover both NCCALCSIZE forms; DefWindowProc otherwise keeps an
        // 8px non-client resize frame around WS_POPUP windows after style
        // changes from window_manager/titlebar setup.
        return 0;
      }
      break;

    case WM_NCHITTEST: {
      // Handle hit testing for borderless window resizing
      LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
      if (!HasCustomFrame()) {
        return hit;
      }
      if (!CanResize()) {
        return HTCLIENT;
      }
      if (hit == HTCLIENT && CanResize()) {
        POINT pt = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
        ScreenToClient(hwnd, &pt);
        RECT rect;
        GetClientRect(hwnd, &rect);
        
        // Define resize border width
        const int border_width = ScaleForWindowDpi(hwnd, 5);
        
        // Check if in resize borders
        if (pt.y < border_width) {
          if (pt.x < border_width) return HTTOPLEFT;
          if (pt.x > rect.right - border_width) return HTTOPRIGHT;
          return HTTOP;
        }
        if (pt.y > rect.bottom - border_width) {
          if (pt.x < border_width) return HTBOTTOMLEFT;
          if (pt.x > rect.right - border_width) return HTBOTTOMRIGHT;
          return HTBOTTOM;
        }
        if (pt.x < border_width) return HTLEFT;
        if (pt.x > rect.right - border_width) return HTRIGHT;
      }
      return hit;
    }

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      if (!HasCustomFrame()) {
        UpdateTheme(hwnd);
      }
      return 0;
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}

void Win32Window::Destroy() {
  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  LogWindowStyles("SetChildContent before reparent", child_content_);
  SetParent(content, window_handle_);

  auto style = static_cast<LONG_PTR>(GetWindowLongPtr(content, GWL_STYLE));
  style &= ~static_cast<LONG_PTR>(WS_POPUP);
  style &= ~static_cast<LONG_PTR>(WS_DISABLED);
  style |= static_cast<LONG_PTR>(WS_CHILD | WS_VISIBLE);
  SetWindowLongPtr(content, GWL_STYLE, style);

  auto ex_style = static_cast<LONG_PTR>(GetWindowLongPtr(content, GWL_EXSTYLE));
  ex_style &= ~static_cast<LONG_PTR>(WS_EX_APPWINDOW | WS_EX_NOACTIVATE);
  SetWindowLongPtr(content, GWL_EXSTYLE, ex_style);

  RECT frame = GetClientArea();

  SetWindowPos(content, nullptr, frame.left, frame.top,
               frame.right - frame.left, frame.bottom - frame.top,
               SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_FRAMECHANGED |
                   SWP_SHOWWINDOW);

  EnableWindow(child_content_, TRUE);
  ShowWindow(child_content_, SW_SHOW);
  SetFocus(child_content_);
  LogWindowStyles("SetChildContent after reparent", child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

DWORD Win32Window::WindowStyle() const {
  return WS_OVERLAPPEDWINDOW;
}

DWORD Win32Window::WindowExStyle() const {
  return WS_EX_APPWINDOW;
}

bool Win32Window::HasCustomFrame() const {
  return true;
}

bool Win32Window::CanResize() const {
  return (WindowStyle() & WS_THICKFRAME) != 0;
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
