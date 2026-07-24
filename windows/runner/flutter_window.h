#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_result.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"
#include "window_backdrop_controller.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  enum class WindowKind {
    kMain,
    kPopup,
    kTrayMenu,
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
  void DestroyPopupWindow();
  void MinimizeCurrentWindow();
  void StartWindowDrag();
  void SetClipboardListenerEnabled(bool enabled);
  void DispatchClipboardChanged();
  void RestorePreviousForegroundWindow();
  void FinishInteractiveMoveResize();
  bool RefreshFlutterSurface();
  void RefreshWindowEffectState();
  void NotifyWindowEffectStateChanged(
      const WindowBackdropApplyResult& apply_result);
  const char* WindowKindName() const;
  WindowBackdropApplyResult ApplyWindowEffect(HWND hwnd, bool force = false);
  void ApplyTrayMenuWindowRegion(HWND hwnd);
  void SendPopupPayloadToFlutter(const std::string& payload_json);
  void SendTrayMenuPayloadToFlutter(const std::string& payload_json);
  std::string PickFolder();
  struct WindowEffectSnapshot {
    int effect_mode = 0;
    int effect_alpha = 255;
    bool dark_mode = true;
    bool rounded_corners_enabled = true;
    int corner_radius = 6;
    bool drag_suspend = true;
  };
  bool CreatePopupWindow(const std::string& payload_json,
                         const std::wstring& window_title,
                         const WindowEffectSnapshot* effect_override = nullptr);
  bool CreateTrayMenuWindow(const std::string& payload_json,
                            const std::wstring& window_title,
                            bool show_immediately = true);
  static void CleanupPopupWindows();
  struct CloseExistingInstanceRequest;
  static constexpr UINT kCloseExistingInstanceCompleteMessage = WM_APP + 1;
  static constexpr UINT kPopupCloseMessage = WM_APP + 2;
  static constexpr UINT kPopupMinimizeMessage = WM_APP + 3;
  static constexpr UINT kPopupStartDragMessage = WM_APP + 4;
  static constexpr UINT kTrayMenuCloseMessage = WM_APP + 5;
  struct TrayMenuRegionRect {
    double x = 0;
    double y = 0;
    double width = 0;
    double height = 0;
  };
  int effect_mode_ = 2;
  int effect_alpha_ = 160;
  bool dark_mode_ = true;
  bool rounded_corners_enabled_ = true;
  int corner_radius_ = 6;
  int tray_menu_region_radius_ = 14;
  std::vector<TrayMenuRegionRect> tray_menu_region_rects_;
  bool drag_suspend_ = true;
  bool launch_hidden_ = false;
  bool is_interactive_resize_ = false;
  bool interactive_resize_observed_ = false;
  bool flutter_surface_refresh_pending_ = true;
  bool first_frame_rendered_ = false;
  std::string pending_tray_payload_json_;
  WPARAM last_window_size_state_ = SIZE_RESTORED;
  bool clipboard_listener_registered_ = false;
  bool effect_configured_ = false;
  std::unique_ptr<WindowBackdropController> backdrop_controller_;
  WindowKind kind_ = WindowKind::kMain;
  HWND previous_foreground_window_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
