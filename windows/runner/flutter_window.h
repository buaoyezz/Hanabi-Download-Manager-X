#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_result.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  enum class WindowKind {
    kMain,
    kPopup,
  };

  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project,
                         WindowKind kind = WindowKind::kMain,
                         bool launch_hidden = false);
  virtual ~FlutterWindow();

 protected:
  DWORD WindowStyle() const override;
  DWORD WindowExStyle() const override;
  bool HasCustomFrame() const override;
  bool CanResize() const override;

  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  void SetupMethodChannel();
  void BringWindowToFront();
  void SetAlwaysOnTop(bool alwaysOnTop);
  void FlashWindowAttention();
  void CloseCurrentWindow();
  void MinimizeCurrentWindow();
  void StartWindowDrag();
  void ApplyWindowEffect(HWND hwnd);
  void ApplyRoundedCorners(HWND hwnd, DWORD buildNumber, int width, int height);
  std::string PickFolder();
  bool CreatePopupWindow(const std::string& payload_json,
                         const std::wstring& window_title);
  static void CleanupPopupWindows();
  struct CloseExistingInstanceRequest;
  static constexpr UINT kCloseExistingInstanceCompleteMessage = WM_APP + 1;
  static constexpr UINT kPopupCloseMessage = WM_APP + 2;
  static constexpr UINT kPopupMinimizeMessage = WM_APP + 3;
  static constexpr UINT kPopupStartDragMessage = WM_APP + 4;
  int effect_mode_ = 2;
  int effect_alpha_ = 160;
  bool rounded_corners_enabled_ = true;
  int corner_radius_ = 6;
  // Win10 drag: disable effect during drag for smooth movement
  bool drag_suspend_ = true;
  bool is_suspended_ = false;
  bool launch_hidden_ = false;
  WindowKind kind_ = WindowKind::kMain;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
