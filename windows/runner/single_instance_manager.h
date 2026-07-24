#ifndef RUNNER_SINGLE_INSTANCE_MANAGER_H_
#define RUNNER_SINGLE_INSTANCE_MANAGER_H_

#include <windows.h>

namespace single_instance {

constexpr wchar_t kMutexName[] = L"Global\\HanabiDownloadManagerX_SingleInstance";
constexpr wchar_t kWindowTitle[] = L"Hanabi Download ManagerX";
constexpr UINT kActivateExistingWindowMessage = WM_APP + 0x30;

HANDLE AcquireMutexHandle();
void SetMutexHandle(HANDLE mutex_handle);
bool HasStartupConflict();
void MarkStartupConflict(HWND existing_window);
bool RequestExistingWindowActivation(HWND existing_window);
bool MarkWindowExiting(HWND window_handle);
bool IsWindowExiting(HWND window_handle);
bool FocusExistingWindow();
bool CloseExistingInstanceAndAcquireLock();
void ReleaseMutexHandle();

}  // namespace single_instance

#endif  // RUNNER_SINGLE_INSTANCE_MANAGER_H_
