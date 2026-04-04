#include "single_instance_manager.h"

namespace single_instance {
namespace {

HANDLE g_mutex_handle = nullptr;
HWND g_existing_window = nullptr;
bool g_has_startup_conflict = false;

bool IsWindowHandleUsable(HWND window_handle) {
  return window_handle != nullptr && ::IsWindow(window_handle) != FALSE;
}

}  // namespace

HANDLE AcquireMutexHandle() {
  return ::CreateMutexW(nullptr, TRUE, kMutexName);
}

void SetMutexHandle(HANDLE mutex_handle) {
  g_mutex_handle = mutex_handle;
}

bool HasStartupConflict() {
  return g_has_startup_conflict;
}

void MarkStartupConflict(HWND existing_window) {
  g_existing_window = existing_window;
  g_has_startup_conflict = true;
}

bool FocusExistingWindow() {
  if (!IsWindowHandleUsable(g_existing_window)) {
    return false;
  }

  if (::IsIconic(g_existing_window)) {
    ::ShowWindow(g_existing_window, SW_RESTORE);
  } else {
    ::ShowWindow(g_existing_window, SW_SHOW);
  }

  ::SetForegroundWindow(g_existing_window);
  ::BringWindowToTop(g_existing_window);
  return true;
}

bool CloseExistingInstanceAndAcquireLock() {
  if (!g_has_startup_conflict) {
    return true;
  }

  DWORD process_id = 0;
  if (IsWindowHandleUsable(g_existing_window)) {
    ::GetWindowThreadProcessId(g_existing_window, &process_id);
  }

  HANDLE process_handle = nullptr;
  if (process_id != 0) {
    process_handle =
        ::OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, process_id);
  }

  if (IsWindowHandleUsable(g_existing_window)) {
    DWORD_PTR result = 0;
    ::SendMessageTimeoutW(g_existing_window, WM_CLOSE, 0, 0,
                          SMTO_ABORTIFHUNG | SMTO_BLOCK, 3000, &result);
  }

  bool exited = false;
  if (process_handle != nullptr) {
    DWORD wait_result = ::WaitForSingleObject(process_handle, 5000);
    if (wait_result == WAIT_OBJECT_0) {
      exited = true;
    } else if (::TerminateProcess(process_handle, 0)) {
      wait_result = ::WaitForSingleObject(process_handle, 3000);
      exited = wait_result == WAIT_OBJECT_0;
    }
    ::CloseHandle(process_handle);
  } else {
    ::Sleep(500);
    exited = !IsWindowHandleUsable(g_existing_window);
  }

  if (!exited || g_mutex_handle == nullptr) {
    return false;
  }

  const DWORD wait_result = ::WaitForSingleObject(g_mutex_handle, 5000);
  if (wait_result != WAIT_OBJECT_0 && wait_result != WAIT_ABANDONED) {
    return false;
  }

  g_existing_window = nullptr;
  g_has_startup_conflict = false;
  return true;
}

void ReleaseMutexHandle() {
  g_existing_window = nullptr;
  g_has_startup_conflict = false;

  if (g_mutex_handle != nullptr) {
    ::ReleaseMutex(g_mutex_handle);
    ::CloseHandle(g_mutex_handle);
    g_mutex_handle = nullptr;
  }
}

}  // namespace single_instance
