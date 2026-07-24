#ifndef RUNNER_WINDOW_BACKDROP_CONTROLLER_H_
#define RUNNER_WINDOW_BACKDROP_CONTROLLER_H_

#include <windows.h>

enum class WindowBackdropKind {
  kNone = 0,
  kBlur = 1,
  kAcrylic = 2,
  kMica = 3,
  kMicaAlt = 4,
};

enum class WindowBackdropRole {
  kMain,
  kPopup,
  kTrayMenu,
};

struct WindowBackdropCapabilities {
  DWORD windows_build = 0;
  bool is_windows_11 = false;
  bool supports_system_backdrop = false;
  bool composition_enabled = false;
  bool transparency_enabled = false;
  bool high_contrast = false;
};

struct WindowBackdropConfig {
  WindowBackdropKind kind = WindowBackdropKind::kNone;
  int alpha = 255;
  bool dark_mode = true;
  bool rounded_corners_enabled = true;
  int corner_radius = 8;
};

struct WindowBackdropApplyResult {
  WindowBackdropKind requested_kind = WindowBackdropKind::kNone;
  WindowBackdropKind applied_kind = WindowBackdropKind::kNone;
  HRESULT hresult = S_OK;
  bool used_fallback = false;
};

// Owns all DWM and legacy Accent state for one top-level window. Keeping these
// operations in one controller prevents independent callers from resetting a
// material that another caller just applied.
class WindowBackdropController {
 public:
  WindowBackdropController(HWND window, WindowBackdropRole role);
  ~WindowBackdropController();

  WindowBackdropController(const WindowBackdropController&) = delete;
  WindowBackdropController& operator=(const WindowBackdropController&) = delete;

  HRESULT PrepareTransparentHost();
  WindowBackdropApplyResult Apply(const WindowBackdropConfig& config,
                                  bool force = false);
  WindowBackdropApplyResult Refresh();
  void UpdateWindowGeometry();
  bool SuspendLegacyEffectForMove();
  void ResumeLegacyEffectAfterMove();

  const WindowBackdropCapabilities& capabilities() const {
    return capabilities_;
  }

  static WindowBackdropCapabilities DetectCapabilities();
  static const char* KindName(WindowBackdropKind kind);

 private:
  WindowBackdropKind ResolveKind(WindowBackdropKind requested) const;
  HRESULT ApplySystemBackdrop(WindowBackdropKind kind);
  HRESULT ApplyLegacyAccent(WindowBackdropKind kind,
                            int alpha,
                            bool dark_mode);
  HRESULT DisableLegacyAccent();
  HRESULT ResetSystemBackdrop();
  HRESULT ExtendFrame(bool transparent);
  void ConfigureFrame(bool dark_mode);
  void ApplyCorners(const WindowBackdropConfig& config);
  bool HasSameConfig(const WindowBackdropConfig& config) const;

  HWND window_ = nullptr;
  WindowBackdropRole role_ = WindowBackdropRole::kMain;
  WindowBackdropCapabilities capabilities_;
  WindowBackdropConfig last_config_;
  WindowBackdropApplyResult last_result_;
  bool has_last_config_ = false;
  bool legacy_effect_suspended_ = false;
};

#endif  // RUNNER_WINDOW_BACKDROP_CONTROLLER_H_
