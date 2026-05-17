#include <windows.h>
#include <commctrl.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <filesystem>
#include <regex>

// Explicitly tell MSVC to link the v6 Common Controls manifest,
// which is strictly required for TaskDialog to work on modern Windows.
#pragma comment(linker,"\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

// Helper function to safely convert UTF-8 string literals to UTF-16 wstring
template <typename CharT>
std::wstring Utf8ToWString(const CharT* utf8StrIn) {
    const char* utf8Str = reinterpret_cast<const char*>(utf8StrIn);
    if (!utf8Str || !*utf8Str) return L"";
    int size = MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, NULL, 0);
    if (size <= 0) return L"";
    std::wstring result(size - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8Str, -1, &result[0], size - 1);
    return result;
}

int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    int argc;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);

    if (argc < 3) {
        if (argv) LocalFree(argv);
        return 0; // Not enough arguments
    }

    DWORD targetPid = _wtol(argv[1]);
    std::wstring logDirPath = argv[2];
    std::wstring crashDirPath = (argc > 3) ? argv[3] : L"";
    if (argv) LocalFree(argv);

    if (targetPid == 0) return 0;

    // Open the target process to wait for its termination
    HANDLE hProcess = OpenProcess(SYNCHRONIZE | PROCESS_QUERY_INFORMATION, FALSE, targetPid);
    if (!hProcess) {
        return 0; // Could not open process (maybe already dead or insufficient permissions)
    }

    // Wait infinitely until the target process exits
    WaitForSingleObject(hProcess, INFINITE);

    DWORD exitCode = 0;
    if (GetExitCodeProcess(hProcess, &exitCode)) {
        if (exitCode != 0) {
            std::wstring detailedReason;
            std::wstring detailedAddress;

            // Attempt to read the crash report if the path was provided
            if (!crashDirPath.empty()) {
                std::wstring crashJsonPath = crashDirPath + L"\\last_crash.json";
                std::ifstream file{std::filesystem::path(crashJsonPath)};
                if (file.is_open()) {
                    std::stringstream buffer;
                    buffer << file.rdbuf();
                    std::string content = buffer.str();

                    std::smatch match;
                    if (std::regex_search(content, match, std::regex("\"reason\"\\s*:\\s*\"([^\"]+)\""))) {
                        detailedReason = Utf8ToWString(match[1].str().c_str());
                    }
                    if (std::regex_search(content, match, std::regex("\"exceptionAddress\"\\s*:\\s*\"([^\"]+)\""))) {
                        detailedAddress = Utf8ToWString(match[1].str().c_str());
                    }
                }
            }

            // Fallback for hard crashes (like Dart FFI pointer dereference) where UnhandledExceptionFilter is bypassed
            if (detailedReason.empty()) {
                switch (exitCode) {
                    case 0xC0000005: detailedReason = Utf8ToWString(u8"Access violation (EXCEPTION_ACCESS_VIOLATION)"); break;
                    case 0xC00000FD: detailedReason = Utf8ToWString(u8"Stack overflow (EXCEPTION_STACK_OVERFLOW)"); break;
                    case 0x80000003: detailedReason = Utf8ToWString(u8"Breakpoint encountered (EXCEPTION_BREAKPOINT)"); break;
                    case 0xC000001D: detailedReason = Utf8ToWString(u8"Illegal instruction (EXCEPTION_ILLEGAL_INSTRUCTION)"); break;
                    case 0xC0000094: detailedReason = Utf8ToWString(u8"Array bounds exceeded (EXCEPTION_ARRAY_BOUNDS_EXCEEDED)"); break;
                    case 0xC0000095: detailedReason = Utf8ToWString(u8"Integer division by zero (EXCEPTION_INT_DIVIDE_BY_ZERO)"); break;
                    case 0xE06D7363: detailedReason = Utf8ToWString(u8"Unhandled C++ exception"); break;
                }
            }

            std::wstringstream contentMsg;
            contentMsg << Utf8ToWString(u8"Exit Code: 0x") << std::hex << std::uppercase << exitCode << L"\n";

            if (!detailedReason.empty()) {
                contentMsg << Utf8ToWString(u8"Crash Reason: ") << detailedReason << L"\n";
            }
            if (!detailedAddress.empty()) {
                contentMsg << Utf8ToWString(u8"Fault Address: ") << detailedAddress << L"\n";
            }

            contentMsg << L"\n"
                       << Utf8ToWString(u8"This might be caused by an underlying Native component crash.\n")
                       << Utf8ToWString(u8"非常抱歉,这可能是由于底层的 Native 组件崩溃导致的\n你可以打开日志文件夹查看详细日志或尝试在 GitHub 上提交 issue 以寻求帮助!");

            // Define custom buttons
            const int BTN_OPEN_LOGS = 1001;
            const int BTN_GITHUB_ISSUES = 1002;
            const int BTN_OPEN_WEBSITE = 1003;
            const int BTN_COPY_INFO = 1004;

            std::wstring btnLogsStr = Utf8ToWString(u8"Open Logs");
            std::wstring btnIssuesStr = Utf8ToWString(u8"Report Issue");
            std::wstring btnCopyStr = Utf8ToWString(u8"Copy Error");
            std::wstring btnWebStr = Utf8ToWString(u8"Website");

            TASKDIALOG_BUTTON buttons[] = {
                { BTN_OPEN_LOGS, btnLogsStr.c_str() },
                { BTN_GITHUB_ISSUES, btnIssuesStr.c_str() },
                { BTN_COPY_INFO, btnCopyStr.c_str() },
                { BTN_OPEN_WEBSITE, btnWebStr.c_str() }
            };

            std::wstring titleStr = Utf8ToWString(u8"Hanabi Download ManagerX - Fatal Error | 进程崩溃 发生致命错误");
            std::wstring instructionStr = Utf8ToWString(u8"Hanabi Download ManagerX unexpectedly terminated.\n不好,进程意外终止了!");
            std::wstring contentStr = contentMsg.str();

            TASKDIALOGCONFIG config = { 0 };
            config.cbSize = sizeof(config);
            config.hwndParent = NULL;
            config.hInstance = hInstance;
            // Removed TDF_USE_COMMAND_LINKS to render standard bottom-row buttons
            config.dwFlags = TDF_ALLOW_DIALOG_CANCELLATION | TDF_SIZE_TO_CONTENT;
            config.dwCommonButtons = TDCBF_CLOSE_BUTTON; // Still provide a normal 'Close' button at the bottom
            config.pszMainIcon = TD_ERROR_ICON;
            config.pszWindowTitle = titleStr.c_str();
            config.pszMainInstruction = instructionStr.c_str();
            config.pszContent = contentStr.c_str();
            config.cButtons = ARRAYSIZE(buttons);
            config.pButtons = buttons;

            int nButtonPressed = 0;
            HRESULT hr = TaskDialogIndirect(&config, &nButtonPressed, NULL, NULL);

            if (SUCCEEDED(hr)) {
                if (nButtonPressed == BTN_OPEN_LOGS && !logDirPath.empty()) {
                    ShellExecuteW(NULL, L"open", logDirPath.c_str(), NULL, NULL, SW_SHOWDEFAULT);
                } else if (nButtonPressed == BTN_GITHUB_ISSUES) {
                    ShellExecuteW(NULL, L"open", L"https://github.com/buaoyezz/hanabi-download-manager-x/issues", NULL, NULL, SW_SHOWDEFAULT);
                } else if (nButtonPressed == BTN_OPEN_WEBSITE) {
                    ShellExecuteW(NULL, L"open", L"https://x.zzbuaoye.net/", NULL, NULL, SW_SHOWDEFAULT);
                } else if (nButtonPressed == BTN_COPY_INFO) {
                    if (OpenClipboard(NULL)) {
                        EmptyClipboard();
                        size_t byteSize = (contentStr.size() + 1) * sizeof(wchar_t);
                        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, byteSize);
                        if (hMem) {
                            memcpy(GlobalLock(hMem), contentStr.c_str(), byteSize);
                            GlobalUnlock(hMem);
                            SetClipboardData(CF_UNICODETEXT, hMem);
                        }
                        CloseClipboard();
                    }
                }
            }
        }
    }

    CloseHandle(hProcess);
    return 0;
}
