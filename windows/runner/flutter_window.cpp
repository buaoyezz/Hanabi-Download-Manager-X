#include "flutter_window.h"

#include <optional>
#include <dwmapi.h>
#include <windows.h>
#include <tlhelp32.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

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

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  SetupMethodChannel();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  {
    HMODULE user32 = LoadLibraryA("user32.dll");
    if (user32) {
      pSetWindowCompositionAttribute = reinterpret_cast<BOOL (WINAPI*)(HWND, WINDOWCOMPOSITIONATTRIBUTEDATA*)>(GetProcAddress(user32, "SetWindowCompositionAttribute"));
      if (pSetWindowCompositionAttribute) {
        HWND hwnd = GetHandle();
        ACCENT_POLICY policy{};
        policy.AccentState = ACCENT_ENABLE_ACRYLICBLURBEHIND;
        policy.AccentFlags = 0;
        policy.GradientColor = 0x00000000;
        policy.AnimationId = 0;
        WINDOWCOMPOSITIONATTRIBUTEDATA data{};
        data.Attribute = 19;
        data.Data = &policy;
        data.SizeOfData = sizeof(policy);
        pSetWindowCompositionAttribute(hwnd, &data);
        int backdrop = 2;
        DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));
      }
      FreeLibrary(user32);
    }
  }

  {
    HWND hwnd = GetHandle();
    DWM_BLURBEHIND bb{};
    bb.dwFlags = 0x00000001 | 0x00000002;
    bb.fEnable = TRUE;
    HRGN rgn = CreateRectRgn(0, 0, -1, -1);
    bb.hRgnBlur = rgn;
    DwmEnableBlurBehindWindow(hwnd, &bb);
    DeleteObject(rgn);
  }

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  // Clean up kernel process (using WinAPI, no CMD window)
  OutputDebugStringA("=== FlutterWindow::OnDestroy START ===");
  
  // Use Windows API to kill process - no CMD flash!
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot != INVALID_HANDLE_VALUE) {
    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32W);
    
    if (Process32FirstW(snapshot, &pe32)) {
      do {
        if (_wcsicmp(pe32.szExeFile, L"soda_kernel.exe") == 0) {
          HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pe32.th32ProcessID);
          if (hProcess) {
            TerminateProcess(hProcess, 0);
            CloseHandle(hProcess);
            OutputDebugStringA("Terminated soda_kernel.exe");
          }
        }
      } while (Process32NextW(snapshot, &pe32));
    }
    CloseHandle(snapshot);
  }
  
  OutputDebugStringA("=== FlutterWindow::OnDestroy END ===");
  
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
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::BringWindowToFront() {
  HWND hwnd = GetHandle();
  if (hwnd) {
    // Show window
    ShowWindow(hwnd, SW_SHOW);
    // Restore window if minimized
    ShowWindow(hwnd, SW_RESTORE);
    // Set as foreground window
    SetForegroundWindow(hwnd);
    // Activate window
    SetActiveWindow(hwnd);
    // Set focus
    SetFocus(hwnd);
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
