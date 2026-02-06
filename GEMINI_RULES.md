# Gemini CLI Rules for Hanabi Download Manager X

This file defines the operational rules, coding standards, and architectural context for the Gemini CLI agent working on the **Hanabi Download Manager X** project.

## 1. Core Interaction Guidelines (核心交互准则)

- **Language:** **ALWAYS** communicate in **Chinese (Simplified)**. (必须使用简体中文进行回复和解释).
- **Tone:** Professional, helpful, and technically precise.
- **Proactiveness:** Fix the root cause, not just the symptom. Always verify changes.

## 2. Tech Stack & Architecture

- **Framework:** Flutter (Windows Desktop).
- **UI Library:** `fluent_ui` (Microsoft Fluent Design). **Do NOT** use Material widgets unless absolutely necessary or wrapped/hidden.
- **State Management:** `provider` (MultiProvider pattern).
  - Use `context.read<T>()` for logic/actions.
  - Use `context.watch<T>()`, `Consumer<T>`, or `selector<T>` for UI rebuilding.
- **Backend (Hybrid Kernel):**
  - **NSFX Kernel:** Dart-based, runs in-process.
  - **Legacy Kernel:** Python/Exe-based, runs as a separate process (Port 9710).
- **Communication:** HTTP REST API.

## 3. Coding Standards (代码规范)

### UI & Theming
- **Theme:** Always use `AppTheme` (in `lib/theme/app_theme.dart`) for colors and styles. Avoid hardcoded generic colors (e.g., `Colors.red`).
- **Icons:** Use `CustomIcons.FluentIcons` (mapped in `lib/utils/fluent_icons.dart`).
- **Windowing:** Use `bitsdojo_window` for custom title bars.
- **Feedback:**
  - **FORBIDDEN:** Do `displayInfoBar`.
  - **REQUIRED:** Use `NotificationManager.of(context)?.showSuccess/Error/Info(...)` for user feedback.

### Directory Structure
- `lib/screens/`: UI Pages and specific widgets.
- `lib/widgets/`: Reusable, generic UI components.
- `lib/services/`: Business logic, state holders, and backend communication.
- `lib/models/`: Data classes (JsonSerializable).

### Services
- Services should extend `ChangeNotifier` if they manage state.
- Initialize services in `main.dart` before `runApp`.
- Dispose logic must be robust (see Section 4).

## 4. Platform Specifics (Windows Development)

- **Hot Restart Safety:**
  - Cleanup logic (in `dispose` or `main.dart`) must **NOT** perform blocking synchronous native calls (like `Process.runSync` or long `await`s) that stall the UI thread. Use "fire-and-forget" for process killing during teardown.
  - Internal servers (HttpServer) must use `shared: true` to allow port reuse during hot restart.
- **Process Management:**
  - When parsing command output (e.g., `netstat`, `tasklist`), handle localized strings (e.g., "LISTENING" vs "监听").
- **File System:**
  - Use `path` package for cross-platform path joining.
  - Handle Windows-style backslashes correctly.

## 5. Workflow
1.  **Analyze:** Understand the existing code patterns (Fluent UI, Provider) before writing.
2.  **Implement:** Write idiomatic Flutter code matching the project style.
3.  **Verify:** Check for "Hot Restart" stability and memory leaks.
4.  **Log:** Use `AppLoggerService` for debugging, not `print()`.

---
*Reference this file to maintain consistency across sessions.*