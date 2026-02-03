#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Single instance mutex name
#define MUTEX_NAME L"Global\\HanabiDownloadManagerX_SingleInstance"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Check if another instance is already running
  HANDLE hMutex = ::CreateMutexW(NULL, TRUE, MUTEX_NAME);
  if (hMutex == NULL || ::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is running, try to activate existing window
    HWND existingWnd = ::FindWindowW(NULL, L"Hanabi Download ManagerX");
    if (existingWnd != NULL) {
      // If window is minimized, restore it
      if (::IsIconic(existingWnd)) {
        ::ShowWindow(existingWnd, SW_RESTORE);
      }
      // Bring window to foreground
      ::SetForegroundWindow(existingWnd);
      ::BringWindowToTop(existingWnd);
    }
    if (hMutex != NULL) {
      ::CloseHandle(hMutex);
    }
    return EXIT_SUCCESS;
  }

  ::AttachConsole(ATTACH_PARENT_PROCESS);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Hanabi Download ManagerX", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Release mutex
  if (hMutex != NULL) {
    ::ReleaseMutex(hMutex);
    ::CloseHandle(hMutex);
  }

  return EXIT_SUCCESS;
}
