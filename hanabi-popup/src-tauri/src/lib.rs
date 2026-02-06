use serde::{Deserialize, Serialize};
use std::sync::Mutex;
use tauri::{Manager, State};

#[cfg(target_os = "windows")]
use window_vibrancy::apply_mica;

// App state to store CLI arguments
pub struct AppState {
    pub initial_url: Mutex<Option<String>>,
    pub initial_filename: Mutex<Option<String>>,
    pub initial_path: Mutex<Option<String>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DownloadRequest {
    pub url: String,
    pub filename: String,
    pub save_path: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct InitialData {
    pub url: Option<String>,
    pub filename: Option<String>,
    pub path: Option<String>,
}

// Get initial data from CLI arguments
#[tauri::command]
fn get_initial_data(state: State<AppState>) -> InitialData {
    InitialData {
        url: state.initial_url.lock().unwrap().clone(),
        filename: state.initial_filename.lock().unwrap().clone(),
        path: state.initial_path.lock().unwrap().clone(),
    }
}

// Send download request to main app via named pipe
#[tauri::command]
async fn send_download_request(request: DownloadRequest) -> Result<String, String> {
    #[cfg(target_os = "windows")]
    {
        use std::fs::OpenOptions;
        use std::io::Write;
        use std::thread;
        use std::time::Duration;

        let pipe_name = r"\\.\pipe\hanabi-download";

        // Try to connect to the named pipe with retries
        let max_retries = 5;
        let mut last_error = String::new();

        for attempt in 0..max_retries {
            if attempt > 0 {
                // Wait before retry (pipe might be busy)
                thread::sleep(Duration::from_millis(200));
            }

            match OpenOptions::new().write(true).open(pipe_name) {
                Ok(mut pipe) => {
                    let json = serde_json::to_string(&request)
                        .map_err(|e| format!("Failed to serialize request: {}", e))?;

                    pipe.write_all(json.as_bytes())
                        .map_err(|e| format!("Failed to write to pipe: {}", e))?;

                    pipe.write_all(b"\n")
                        .map_err(|e| format!("Failed to write newline: {}", e))?;

                    return Ok("Download request sent successfully".to_string());
                }
                Err(e) => {
                    last_error = format!("{}", e);
                    // Error 231 = ERROR_PIPE_BUSY, retry
                    if e.raw_os_error() == Some(231) {
                        continue;
                    }
                    // Other errors, try HTTP fallback
                    break;
                }
            }
        }

        // If pipe failed, try HTTP fallback
        send_via_http(&request).await
            .map_err(|http_err| format!("Pipe error: {}. HTTP fallback also failed: {}", last_error, http_err))
    }

    #[cfg(not(target_os = "windows"))]
    {
        send_via_http(&request).await
    }
}

// HTTP fallback for sending download request
async fn send_via_http(request: &DownloadRequest) -> Result<String, String> {
    // Try localhost HTTP API as fallback (same port as progress service)
    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:19998/api/download")
        .json(request)
        .send()
        .await
        .map_err(|e| format!("HTTP request failed: {}", e))?;

    if response.status().is_success() {
        Ok("Download request sent via HTTP".to_string())
    } else {
        Err(format!("HTTP request failed with status: {}", response.status()))
    }
}

// Close the window
#[tauri::command]
fn close_window(window: tauri::Window) {
    window.close().unwrap();
}

// Minimize the window
#[tauri::command]
fn minimize_window(window: tauri::Window) {
    window.minimize().unwrap();
}

// Resize the window
#[tauri::command]
fn resize_window(window: tauri::Window, width: f64, height: f64) {
    let _ = window.set_size(tauri::Size::Logical(tauri::LogicalSize { width, height }));
}

// Open main application
#[tauri::command]
fn open_main_app() -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        use std::path::PathBuf;

        // 尝试多个可能的路径
        let mut possible_paths: Vec<PathBuf> = vec![];

        // 与 popup 同目录
        if let Ok(exe_path) = std::env::current_exe() {
            if let Some(parent) = exe_path.parent() {
                // 正确的文件名（大写，Flutter 编译后的名称）
                possible_paths.push(parent.join("HanabiDownloadManagerX.exe"));
                // 备用文件名
                possible_paths.push(parent.join("hanabi_download_managerx.exe"));
                possible_paths.push(parent.join("hanabi_download_manager.exe"));

                // 上级目录（popup 在 data/zzbuaoye_assets 下）
                if let Some(grandparent) = parent.parent() {
                    possible_paths.push(grandparent.join("HanabiDownloadManagerX.exe"));
                    // 上上级目录（data 目录的上级就是主程序目录）
                    if let Some(great_grandparent) = grandparent.parent() {
                        possible_paths.push(great_grandparent.join("HanabiDownloadManagerX.exe"));
                    }
                }

                // 开发模式：从 hanabi-popup/src-tauri/target/debug 向上找到项目根目录
                // 然后查找 build/windows/x64/runner/Release 或 Debug
                if let Some(target_dir) = parent.parent() {  // target
                    if let Some(src_tauri_dir) = target_dir.parent() {  // src-tauri
                        if let Some(popup_dir) = src_tauri_dir.parent() {  // hanabi-popup
                            if let Some(project_root) = popup_dir.parent() {  // 项目根目录
                                // Release 版本
                                possible_paths.push(project_root.join("build/windows/x64/runner/Release/HanabiDownloadManagerX.exe"));
                                // Debug 版本
                                possible_paths.push(project_root.join("build/windows/x64/runner/Debug/HanabiDownloadManagerX.exe"));
                                // Profile 版本
                                possible_paths.push(project_root.join("build/windows/x64/runner/Profile/HanabiDownloadManagerX.exe"));
                            }
                        }
                    }
                }
            }
        }

        // 常见安装路径
        possible_paths.push(PathBuf::from(r"C:\Program Files\Hanabi Download ManagerX\HanabiDownloadManagerX.exe"));
        possible_paths.push(PathBuf::from(r"C:\Program Files\Hanabi Download ManagerX\hanabi_download_managerx.exe"));
        possible_paths.push(PathBuf::from(r"C:\Program Files (x86)\Hanabi Download ManagerX\HanabiDownloadManagerX.exe"));

        // 用户目录下的安装路径
        if let Some(local_app_data) = dirs::data_local_dir() {
            possible_paths.push(local_app_data.join("Hanabi Download ManagerX").join("HanabiDownloadManagerX.exe"));
            possible_paths.push(local_app_data.join("Hanabi Download ManagerX").join("hanabi_download_managerx.exe"));
        }

        for path in &possible_paths {
            if path.exists() {
                std::process::Command::new(path)
                    .spawn()
                    .map_err(|e| format!("Failed to open main app: {}", e))?;
                return Ok(());
            }
        }

        // 如果找不到，返回错误提示用户
        return Err(format!("找不到主程序，请确保 Hanabi Download ManagerX 已正确安装"));
    }

    #[cfg(not(target_os = "windows"))]
    {
        Err("此功能仅支持 Windows".to_string())
    }
}

// Parse filename from URL
#[tauri::command]
fn parse_filename_from_url(url: String) -> Option<String> {
    url.split('/')
        .last()
        .and_then(|s| s.split('?').next())
        .filter(|s| !s.is_empty() && s.contains('.'))
        .map(|s| urlencoding::decode(s).unwrap_or_else(|_| s.into()).to_string())
}

// Get default download path
#[tauri::command]
fn get_default_download_path() -> String {
    dirs::download_dir()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| {
            dirs::home_dir()
                .map(|p| p.join("Downloads").to_string_lossy().to_string())
                .unwrap_or_else(|| "C:\\Downloads".to_string())
        })
}

// Open file with default application
#[tauri::command]
fn open_file(path: String) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("cmd")
            .args(["/C", "start", "", &path])
            .spawn()
            .map_err(|e| format!("Failed to open file: {}", e))?;
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&path)
            .spawn()
            .map_err(|e| format!("Failed to open file: {}", e))?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(&path)
            .spawn()
            .map_err(|e| format!("Failed to open file: {}", e))?;
    }
    Ok(())
}

// Open folder in file explorer
#[tauri::command]
fn open_folder(path: String) -> Result<(), String> {
    #[cfg(target_os = "windows")]
    {
        std::process::Command::new("explorer")
            .arg(&path)
            .spawn()
            .map_err(|e| format!("Failed to open folder: {}", e))?;
    }
    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg(&path)
            .spawn()
            .map_err(|e| format!("Failed to open folder: {}", e))?;
    }
    #[cfg(target_os = "linux")]
    {
        std::process::Command::new("xdg-open")
            .arg(&path)
            .spawn()
            .map_err(|e| format!("Failed to open folder: {}", e))?;
    }
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run(initial_url: Option<String>, initial_filename: Option<String>, initial_path: Option<String>) {
    let app_state = AppState {
        initial_url: Mutex::new(initial_url),
        initial_filename: Mutex::new(initial_filename),
        initial_path: Mutex::new(initial_path),
    };

    tauri::Builder::default()
        .manage(app_state)
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .setup(|app| {
            let window = app.get_webview_window("main").unwrap();

            // Apply Mica effect on Windows 11
            #[cfg(target_os = "windows")]
            {
                let _ = apply_mica(&window, Some(true)); // true = dark mode
            }

            // Enable devtools in debug mode
            #[cfg(debug_assertions)]
            {
                window.open_devtools();
            }

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            get_initial_data,
            send_download_request,
            close_window,
            minimize_window,
            resize_window,
            open_main_app,
            parse_filename_from_url,
            get_default_download_path,
            open_file,
            open_folder,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
