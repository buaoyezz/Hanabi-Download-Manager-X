#include "crash_reporter.h"

#include <windows.h>

#include <csignal>
#include <cstdint>
#include <cstdlib>
#include <exception>
#include <iomanip>
#include <sstream>
#include <string>

namespace {

LPTOP_LEVEL_EXCEPTION_FILTER g_previous_exception_filter = nullptr;
std::terminate_handler g_previous_terminate_handler = nullptr;
PVOID g_vectored_exception_handler = nullptr;
volatile LONG g_is_writing_report = 0;
volatile LONG g_runtime_handlers_installed = 0;

std::wstring GetEnvironmentValue(const wchar_t* name) {
  wchar_t buffer[32767] = {0};
  const DWORD length = GetEnvironmentVariableW(name, buffer, 32767);
  if (length == 0 || length >= 32767) {
    return L"";
  }
  return std::wstring(buffer, length);
}

std::wstring GetCrashReportDirectory() {
  std::wstring user_profile = GetEnvironmentValue(L"USERPROFILE");
  if (!user_profile.empty()) {
    return user_profile + L"\\.hdmx\\crash_reports";
  }

  wchar_t temp_path[MAX_PATH] = {0};
  const DWORD length = GetTempPathW(MAX_PATH, temp_path);
  if (length > 0 && length < MAX_PATH) {
    return std::wstring(temp_path, length) +
           L"HanabiDownloadManagerX\\crash_reports";
  }

  return L".\\crash_reports";
}

bool CreateDirectoryRecursive(const std::wstring& path) {
  if (path.empty()) {
    return false;
  }

  std::wstring current;
  current.reserve(path.size());

  for (size_t i = 0; i < path.size(); ++i) {
    current.push_back(path[i]);
    const bool is_separator = path[i] == L'\\' || path[i] == L'/';
    const bool is_end = i == path.size() - 1;
    if (!is_separator && !is_end) {
      continue;
    }

    while (!current.empty() &&
           (current.back() == L'\\' || current.back() == L'/')) {
      const bool is_drive_root =
          current.size() == 3 && current[1] == L':' &&
          (current[2] == L'\\' || current[2] == L'/');
      if (is_drive_root) {
        break;
      }
      current.pop_back();
    }

    if (current.empty() || (current.size() == 2 && current[1] == L':') ||
        (current.size() == 3 && current[1] == L':' &&
         (current[2] == L'\\' || current[2] == L'/'))) {
      continue;
    }

    if (!CreateDirectoryW(current.c_str(), nullptr)) {
      const DWORD error = GetLastError();
      if (error != ERROR_ALREADY_EXISTS) {
        return false;
      }
    }
  }

  return true;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }

  const int size_needed = WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0,
      nullptr, nullptr);
  if (size_needed <= 0) {
    return std::string();
  }

  std::string result(static_cast<size_t>(size_needed), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                      static_cast<int>(value.size()), result.data(),
                      size_needed, nullptr, nullptr);
  return result;
}

std::string JsonEscape(const std::string& value) {
  std::ostringstream stream;
  for (const unsigned char ch : value) {
    switch (ch) {
      case '\\':
        stream << "\\\\";
        break;
      case '"':
        stream << "\\\"";
        break;
      case '\b':
        stream << "\\b";
        break;
      case '\f':
        stream << "\\f";
        break;
      case '\n':
        stream << "\\n";
        break;
      case '\r':
        stream << "\\r";
        break;
      case '\t':
        stream << "\\t";
        break;
      default:
        if (ch < 0x20) {
          stream << "\\u" << std::hex << std::setw(4) << std::setfill('0')
                 << static_cast<int>(ch) << std::dec << std::setfill(' ');
        } else {
          stream << ch;
        }
        break;
    }
  }
  return stream.str();
}

std::string Quote(const std::string& value) {
  return "\"" + JsonEscape(value) + "\"";
}

std::string HexValue(unsigned long long value) {
  std::ostringstream stream;
  stream << "0x" << std::uppercase << std::hex << value;
  return stream.str();
}

std::string FormatLocalTimestamp() {
  SYSTEMTIME time;
  GetLocalTime(&time);
  char buffer[64] = {0};
  sprintf_s(buffer, sizeof(buffer), "%04u-%02u-%02uT%02u:%02u:%02u.%03u",
            time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
            time.wSecond, time.wMilliseconds);
  return buffer;
}

std::wstring FormatFileTimestamp() {
  SYSTEMTIME time;
  GetLocalTime(&time);
  wchar_t buffer[64] = {0};
  swprintf_s(buffer, sizeof(buffer) / sizeof(wchar_t),
             L"%04u-%02u-%02u_%02u-%02u-%02u_%03u", time.wYear,
             time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond,
             time.wMilliseconds);
  return buffer;
}

std::wstring GetModulePath() {
  wchar_t buffer[MAX_PATH] = {0};
  const DWORD length = GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return L"";
  }
  return std::wstring(buffer, length);
}

std::string DescribeExceptionCode(DWORD code) {
  switch (code) {
    case EXCEPTION_ACCESS_VIOLATION:
      return "Access violation";
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
      return "Array bounds exceeded";
    case EXCEPTION_BREAKPOINT:
      return "Breakpoint";
    case EXCEPTION_DATATYPE_MISALIGNMENT:
      return "Datatype misalignment";
    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
    case EXCEPTION_INT_DIVIDE_BY_ZERO:
      return "Divide by zero";
    case EXCEPTION_ILLEGAL_INSTRUCTION:
      return "Illegal instruction";
    case EXCEPTION_IN_PAGE_ERROR:
      return "In-page error";
    case EXCEPTION_INVALID_DISPOSITION:
      return "Invalid exception disposition";
    case EXCEPTION_NONCONTINUABLE_EXCEPTION:
      return "Non-continuable exception";
    case EXCEPTION_PRIV_INSTRUCTION:
      return "Privileged instruction";
    case EXCEPTION_STACK_OVERFLOW:
      return "Stack overflow";
    case 0xC0000409:
      return "Stack buffer overrun / fast fail";
    case 0xE06D7363:
      return "Unhandled C++ exception";
    default:
      return "Unhandled native exception";
  }
}

std::string DescribeSignal(int signal_number) {
  switch (signal_number) {
    case SIGABRT:
      return "C runtime abort";
    case SIGFPE:
      return "Floating point exception";
    case SIGILL:
      return "Illegal instruction signal";
    case SIGINT:
      return "Interrupt signal";
    case SIGSEGV:
      return "Segmentation fault";
    case SIGTERM:
      return "Termination signal";
    default:
      return "Native signal";
  }
}

bool ShouldWriteVectoredReport(DWORD code) {
  // Catch fatal exceptions before Dart's SEH swallows them and terminates the process.
  // This ensures last_crash.json is written even if Dart forcefully exits later.
  switch (code) {
    case EXCEPTION_ACCESS_VIOLATION:
    case EXCEPTION_ILLEGAL_INSTRUCTION:
    case EXCEPTION_DATATYPE_MISALIGNMENT:
    case EXCEPTION_ARRAY_BOUNDS_EXCEEDED:
    case EXCEPTION_INT_DIVIDE_BY_ZERO:
    case EXCEPTION_FLT_DIVIDE_BY_ZERO:
    case EXCEPTION_PRIV_INSTRUCTION:
    case EXCEPTION_STACK_OVERFLOW:
    case EXCEPTION_NONCONTINUABLE_EXCEPTION:
    case 0xC0000409: // Fast fail
      return true;
    default:
      return false;
  }
}

bool WriteUtf8File(const std::wstring& path, const std::string& content) {
  HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                            nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }

  DWORD written = 0;
  const BOOL ok = WriteFile(file, content.data(),
                            static_cast<DWORD>(content.size()), &written,
                            nullptr);
  FlushFileBuffers(file);
  CloseHandle(file);
  return ok && written == content.size();
}

void WriteCrashReport(const std::string& kind,
                      const std::string& reason,
                      DWORD exception_code,
                      void* exception_address) {
  if (InterlockedExchange(&g_is_writing_report, 1) != 0) {
    return;
  }

  const std::wstring directory = GetCrashReportDirectory();
  CreateDirectoryRecursive(directory);

  const DWORD process_id = GetCurrentProcessId();
  const DWORD thread_id = GetCurrentThreadId();
  const std::wstring report_path =
      directory + L"\\crash_" + FormatFileTimestamp() + L"_" +
      std::to_wstring(process_id) + L".json";
  const std::wstring last_report_path = directory + L"\\last_crash.json";
  const std::wstring module_path = GetModulePath();

  std::ostringstream json;
  json << "{\n";
  json << "  \"schemaVersion\": 1,\n";
  json << "  \"app\": \"Hanabi Download ManagerX\",\n";
  json << "  \"timestampLocal\": " << Quote(FormatLocalTimestamp()) << ",\n";
  json << "  \"processId\": " << process_id << ",\n";
  json << "  \"threadId\": " << thread_id << ",\n";
  json << "  \"kind\": " << Quote(kind) << ",\n";
  json << "  \"reason\": " << Quote(reason) << ",\n";
  if (exception_code != 0) {
    json << "  \"exceptionCode\": " << Quote(HexValue(exception_code))
         << ",\n";
  }
  if (exception_address != nullptr) {
    json << "  \"exceptionAddress\": "
         << Quote(HexValue(reinterpret_cast<uintptr_t>(exception_address)))
         << ",\n";
  }
  json << "  \"modulePath\": " << Quote(WideToUtf8(module_path)) << ",\n";
  json << "  \"crashDirectory\": " << Quote(WideToUtf8(directory)) << ",\n";
  json << "  \"reportPath\": " << Quote(WideToUtf8(report_path)) << "\n";
  json << "}\n";

  const std::string content = json.str();
  WriteUtf8File(report_path, content);
  WriteUtf8File(last_report_path, content);

  OutputDebugStringA("Hanabi native crash report written\n");
}

LONG WINAPI UnhandledExceptionHandler(EXCEPTION_POINTERS* exception_pointers) {
  DWORD code = 0;
  void* address = nullptr;
  std::string reason = "Unhandled native exception";

  if (exception_pointers != nullptr &&
      exception_pointers->ExceptionRecord != nullptr) {
    code = exception_pointers->ExceptionRecord->ExceptionCode;
    address = exception_pointers->ExceptionRecord->ExceptionAddress;
    reason = DescribeExceptionCode(code) + " (" + HexValue(code) + ")";
  }

  WriteCrashReport("seh", reason, code, address);
  return EXCEPTION_EXECUTE_HANDLER;
}

LONG WINAPI VectoredExceptionHandler(EXCEPTION_POINTERS* exception_pointers) {
  DWORD code = 0;
  void* address = nullptr;
  std::string reason = "Vectored native exception";

  if (exception_pointers != nullptr &&
      exception_pointers->ExceptionRecord != nullptr) {
    code = exception_pointers->ExceptionRecord->ExceptionCode;
    address = exception_pointers->ExceptionRecord->ExceptionAddress;
    reason = DescribeExceptionCode(code) + " (" + HexValue(code) + ")";
  }

  if (!ShouldWriteVectoredReport(code)) {
    return EXCEPTION_CONTINUE_SEARCH;
  }

  WriteCrashReport("veh", reason, code, address);
  return EXCEPTION_CONTINUE_SEARCH;
}

void SignalHandler(int signal_number) {
  std::signal(signal_number, SIG_DFL);
  WriteCrashReport("signal", DescribeSignal(signal_number), 0, nullptr);
  TerminateProcess(GetCurrentProcess(),
                   static_cast<UINT>(128 + signal_number));
}

void TerminateHandler() {
  std::string reason = "std::terminate";
  const std::exception_ptr exception = std::current_exception();
  if (exception) {
    try {
      std::rethrow_exception(exception);
    } catch (const std::exception& error) {
      reason += ": ";
      reason += error.what();
    } catch (...) {
      reason += ": non-standard C++ exception";
    }
  }

  WriteCrashReport("terminate", reason, 0, nullptr);

  if (g_previous_terminate_handler != nullptr &&
      g_previous_terminate_handler != TerminateHandler) {
    g_previous_terminate_handler();
  }

  TerminateProcess(GetCurrentProcess(), 0xE0000001);
}

}  // namespace

namespace crash_reporter {

void Install() {
  if (g_vectored_exception_handler != nullptr) {
    RemoveVectoredExceptionHandler(g_vectored_exception_handler);
    g_vectored_exception_handler = nullptr;
  }

  g_vectored_exception_handler =
      AddVectoredExceptionHandler(1, VectoredExceptionHandler);

  g_previous_exception_filter =
      SetUnhandledExceptionFilter(UnhandledExceptionHandler);
  if (InterlockedExchange(&g_runtime_handlers_installed, 1) == 0) {
    g_previous_terminate_handler = std::set_terminate(TerminateHandler);

    std::signal(SIGABRT, SignalHandler);
    std::signal(SIGFPE, SignalHandler);
    std::signal(SIGILL, SignalHandler);
    std::signal(SIGSEGV, SignalHandler);
    std::signal(SIGTERM, SignalHandler);
  }
}

}  // namespace crash_reporter
