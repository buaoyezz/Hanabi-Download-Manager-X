#include <algorithm>

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "single_instance_manager.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Check if another instance is already running
  HANDLE hMutex = single_instance::AcquireMutexHandle();
  if (hMutex == NULL) {
    return EXIT_FAILURE;
  }
  single_instance::SetMutexHandle(hMutex);

  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existingWnd = ::FindWindowW(nullptr, single_instance::kWindowTitle);
    single_instance::MarkStartupConflict(existingWnd);
  }

  ::AttachConsole(ATTACH_PARENT_PROCESS);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool launch_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--autostart") != command_line_arguments.end();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, launch_hidden);
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
  single_instance::ReleaseMutexHandle();

  return EXIT_SUCCESS;
}
