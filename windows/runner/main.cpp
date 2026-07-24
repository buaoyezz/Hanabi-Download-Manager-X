#include <algorithm>

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "crash_reporter.h"
#include "flutter_window.h"
#include "single_instance_manager.h"
#include "utils.h"

namespace {

DWORD g_main_thread_id = 0;

BOOL WINAPI ConsoleControlHandler(DWORD control_type) {
  switch (control_type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
      if (g_main_thread_id != 0) {
        ::PostThreadMessageW(g_main_thread_id, WM_QUIT, 0, 0);
        return TRUE;
      }
      return FALSE;
    default:
      return FALSE;
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  g_main_thread_id = ::GetCurrentThreadId();
  crash_reporter::Install();

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool launch_hidden =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--autostart") != command_line_arguments.end();

  // Check if another instance is already running
  HANDLE hMutex = single_instance::AcquireMutexHandle();
  if (hMutex == NULL) {
    return EXIT_FAILURE;
  }
  const DWORD mutex_status = ::GetLastError();

  bool owns_mutex = mutex_status != ERROR_ALREADY_EXISTS;
  if (!owns_mutex) {
    HWND existingWnd = nullptr;
    constexpr int kExistingWindowPollAttempts = 40;
    for (int attempt = 0; attempt < kExistingWindowPollAttempts; ++attempt) {
      const DWORD wait_result = ::WaitForSingleObject(hMutex, 0);
      if (wait_result == WAIT_OBJECT_0 || wait_result == WAIT_ABANDONED) {
        owns_mutex = true;
        break;
      }
      if (wait_result == WAIT_FAILED) {
        ::CloseHandle(hMutex);
        return EXIT_FAILURE;
      }

      existingWnd = ::FindWindowW(nullptr, single_instance::kWindowTitle);
      if (existingWnd != nullptr) {
        break;
      }
      ::Sleep(50);
    }
    if (!owns_mutex && existingWnd != nullptr) {
      bool existing_is_exiting =
          single_instance::IsWindowExiting(existingWnd);
      if (!existing_is_exiting) {
        if (!launch_hidden) {
          single_instance::RequestExistingWindowActivation(existingWnd);
        }
        // Catch an exit that began concurrently with the activation request.
        existing_is_exiting = single_instance::IsWindowExiting(existingWnd);
        if (!existing_is_exiting) {
          ::CloseHandle(hMutex);
          return EXIT_SUCCESS;
        }
      }
    }

    if (!owns_mutex) {
      // Normal shutdown can spend up to three seconds stopping the kernel,
      // followed by the native close fallback. Wait long enough to inherit the
      // mutex instead of allowing both the old and new process to disappear.
      const DWORD handoff_result = ::WaitForSingleObject(hMutex, 7000);
      owns_mutex = handoff_result == WAIT_OBJECT_0 ||
                   handoff_result == WAIT_ABANDONED;
      if (handoff_result == WAIT_FAILED) {
        ::CloseHandle(hMutex);
        return EXIT_FAILURE;
      }
    }

    if (!owns_mutex) {
      ::CloseHandle(hMutex);
      return EXIT_SUCCESS;
    }
  }
  single_instance::SetMutexHandle(hMutex);

  ::AttachConsole(ATTACH_PARENT_PROCESS);
  ::SetConsoleCtrlHandler(ConsoleControlHandler, TRUE);
  MSG queue_init_msg = {};
  ::PeekMessageW(&queue_init_msg, nullptr, WM_USER, WM_USER, PM_NOREMOVE);

  const HRESULT com_init_hr =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, FlutterWindow::WindowKind::kMain, launch_hidden);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 800);
  if (!window.Create(L"Hanabi Download ManagerX", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  crash_reporter::Install();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::SetConsoleCtrlHandler(ConsoleControlHandler, FALSE);

  // Release mutex
  single_instance::ReleaseMutexHandle();

  if (SUCCEEDED(com_init_hr)) {
    ::CoUninitialize();
  }

  return EXIT_SUCCESS;
}
