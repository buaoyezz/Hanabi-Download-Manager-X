#ifndef RUNNER_SINGLE_INSTANCE_MANAGER_H_
#define RUNNER_SINGLE_INSTANCE_MANAGER_H_

#include <windows.h>

namespace single_instance {

constexpr wchar_t kMutexName[] = L"Global\\HanabiDownloadManagerX_SingleInstance";
constexpr wchar_t kWindowTitle[] = L"Hanabi Download ManagerX";

HANDLE AcquireMutexHandle();
void SetMutexHandle(HANDLE mutex_handle);
bool HasStartupConflict();
void MarkStartupConflict(HWND existing_window);
bool FocusExistingWindow();
bool CloseExistingInstanceAndAcquireLock();
void ReleaseMutexHandle();

}  // namespace single_instance

#endif  // RUNNER_SINGLE_INSTANCE_MANAGER_H_
