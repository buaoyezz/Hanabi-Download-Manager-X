import { useState, useEffect, useCallback, useRef } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { open } from '@tauri-apps/plugin-dialog';
import './App.css';
import logoImg from './assets/logo.png';

// ============================================
// Types for Progress Data
// ============================================
interface SegmentProgressData {
  index: number;
  progress: number;
  status: string;
}

interface ProgressData {
  task_id: string;
  filename: string;
  status: string;
  progress: number;
  downloaded_size: number;
  total_size: number;
  speed: number;
  remaining_seconds: number;
  segments: SegmentProgressData[];
  error?: string;
}

type ViewState = 'form' | 'downloading' | 'completed' | 'error';

// ============================================
// Utility Functions
// ============================================
const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

const formatSpeed = (bytesPerSecond: number): string => {
  return formatBytes(bytesPerSecond) + '/s';
};

const formatTime = (seconds: number): string => {
  if (seconds <= 0) return '--:--';
  if (seconds >= 3600) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
};

// ============================================
// Fluent 2 Design Icons
// ============================================
const Icons = {
  download: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  ),
  folder: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
    </svg>
  ),
  minimize: (
    <svg viewBox="0 0 12 12">
      <rect fill="currentColor" width="10" height="1" x="1" y="6" />
    </svg>
  ),
  close: (
    <svg viewBox="0 0 12 12">
      <path fill="currentColor" d="M6.707 6l3.146-3.146a.5.5 0 0 0-.707-.708L6 5.293 2.854 2.146a.5.5 0 1 0-.708.708L5.293 6l-3.147 3.146a.5.5 0 0 0 .708.708L6 6.707l3.146 3.147a.5.5 0 0 0 .708-.708L6.707 6z" />
    </svg>
  ),
  spinner: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83" />
    </svg>
  ),
  // File type icons
  fileGeneric: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
    </svg>
  ),
  fileVideo: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <polygon points="10 11 10 17 15 14 10 11" fill="currentColor" stroke="none" />
    </svg>
  ),
  fileAudio: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <circle cx="10" cy="15" r="2" />
      <path d="M12 15V11l3-1" />
    </svg>
  ),
  fileImage: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <circle cx="10" cy="13" r="2" />
      <path d="M18 18l-4-4-6 6" />
    </svg>
  ),
  fileArchive: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <rect x="10" y="11" width="4" height="2" rx="0.5" />
      <rect x="10" y="14" width="4" height="2" rx="0.5" />
      <rect x="10" y="17" width="4" height="2" rx="0.5" />
    </svg>
  ),
  fileDocument: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="8" y1="13" x2="16" y2="13" />
      <line x1="8" y1="17" x2="14" y2="17" />
    </svg>
  ),
  fileCode: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <polyline points="9 15 7 13 9 11" />
      <polyline points="15 11 17 13 15 15" />
    </svg>
  ),
  fileExe: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <rect x="8" y="12" width="8" height="6" rx="1" />
      <circle cx="12" cy="15" r="1.5" fill="currentColor" />
    </svg>
  ),
  // App logo - Hanabi (firework) inspired
  logo: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" fill="currentColor" opacity="0.3" />
      <path d="M12 2v4" />
      <path d="M12 18v4" />
      <path d="M4.93 4.93l2.83 2.83" />
      <path d="M16.24 16.24l2.83 2.83" />
      <path d="M2 12h4" />
      <path d="M18 12h4" />
      <path d="M4.93 19.07l2.83-2.83" />
      <path d="M16.24 7.76l2.83-2.83" />
    </svg>
  ),
  // Additional icons for progress view
  check: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  ),
  pause: (
    <svg viewBox="0 0 24 24" fill="currentColor">
      <rect x="6" y="4" width="4" height="16" rx="1" />
      <rect x="14" y="4" width="4" height="16" rx="1" />
    </svg>
  ),
  play: (
    <svg viewBox="0 0 24 24" fill="currentColor">
      <polygon points="5 3 19 12 5 21 5 3" />
    </svg>
  ),
  openFolder: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
      <line x1="12" y1="11" x2="12" y2="17" />
      <polyline points="9 14 12 11 15 14" />
    </svg>
  ),
  openFile: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
      <polyline points="14 2 14 8 20 8" />
      <line x1="12" y1="18" x2="12" y2="12" />
      <polyline points="9 15 12 12 15 15" />
    </svg>
  ),
  error: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
      <line x1="15" y1="9" x2="9" y2="15" />
      <line x1="9" y1="9" x2="15" y2="15" />
    </svg>
  ),
  retry: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 4 23 10 17 10" />
      <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
    </svg>
  ),
};

// File type detection with Fluent 2 colors
const getFileIcon = (filename: string) => {
  const ext = filename.split('.').pop()?.toLowerCase() || '';

  if (['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', 'mpeg', 'mpg', '3gp', 'ts'].includes(ext)) {
    return { icon: Icons.fileVideo, color: '#ff6b9d', bg: 'rgba(255, 107, 157, 0.12)' };
  }
  if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma', 'm4a', 'opus', 'aiff'].includes(ext)) {
    return { icon: Icons.fileAudio, color: '#a78bfa', bg: 'rgba(167, 139, 250, 0.12)' };
  }
  if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg', 'ico', 'tiff', 'psd', 'raw'].includes(ext)) {
    return { icon: Icons.fileImage, color: '#34d399', bg: 'rgba(52, 211, 153, 0.12)' };
  }
  if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'dmg'].includes(ext)) {
    return { icon: Icons.fileArchive, color: '#fbbf24', bg: 'rgba(251, 191, 36, 0.12)' };
  }
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'rtf', 'odt', 'csv'].includes(ext)) {
    return { icon: Icons.fileDocument, color: '#60a5fa', bg: 'rgba(96, 165, 250, 0.12)' };
  }
  if (['js', 'ts', 'jsx', 'tsx', 'html', 'css', 'json', 'xml', 'py', 'java', 'cpp', 'c', 'h', 'rs', 'go', 'php', 'rb', 'swift', 'kt'].includes(ext)) {
    return { icon: Icons.fileCode, color: '#22d3ee', bg: 'rgba(34, 211, 238, 0.12)' };
  }
  if (['exe', 'msi', 'app', 'deb', 'rpm', 'apk', 'bat', 'sh', 'cmd'].includes(ext)) {
    return { icon: Icons.fileExe, color: '#f87171', bg: 'rgba(248, 113, 113, 0.12)' };
  }
  return { icon: Icons.fileGeneric, color: '#60cdff', bg: 'rgba(96, 205, 255, 0.12)' };
};

interface InitialData {
  url: string | null;
  filename: string | null;
  path: string | null;
}

// WebSocket progress service URL
const PROGRESS_WS_URL = 'ws://localhost:19998/ws/progress';
const PROGRESS_API_URL = 'http://localhost:19998';

function App() {
  // Form state
  const [url, setUrl] = useState('');
  const [filename, setFilename] = useState('');
  const [savePath, setSavePath] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Progress state
  const [viewState, setViewState] = useState<ViewState>('form');
  const [taskId, setTaskId] = useState<string | null>(null);
  const [progressData, setProgressData] = useState<ProgressData | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | null>(null);

  // 初始化：从命令行参数获取数据
  useEffect(() => {
    (async () => {
      try {
        const data = await invoke<InitialData>('get_initial_data');
        if (data.url) setUrl(data.url);
        if (data.filename) setFilename(data.filename);
        if (data.path) {
          setSavePath(data.path);
        } else {
          const defaultPath = await invoke<string>('get_default_download_path');
          setSavePath(defaultPath);
        }
      } catch (e) {
        console.error('Failed to get initial data:', e);
        setSavePath('C:\\Downloads');
      }
    })();
  }, []);

  // 自动解析文件名
  useEffect(() => {
    if (!url || filename) return;
    const timer = setTimeout(async () => {
      try {
        const parsed = await invoke<string | null>('parse_filename_from_url', { url });
        if (parsed) setFilename(parsed);
      } catch { /* ignore */ }
    }, 300);
    return () => clearTimeout(timer);
  }, [url, filename]);

  // WebSocket 连接管理
  const connectWebSocket = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    console.log('[WebSocket] Connecting to progress service...');
    const ws = new WebSocket(PROGRESS_WS_URL);

    ws.onopen = () => {
      console.log('[WebSocket] Connected');
      // 订阅当前任务的进度
      if (taskId) {
        ws.send(JSON.stringify({ type: 'subscribe', task_id: taskId }));
      }
    };

    ws.onmessage = (event) => {
      try {
        const message = JSON.parse(event.data);
        if (message.type === 'progress' && message.data) {
          const data = message.data as ProgressData;
          setProgressData(data);

          // 根据状态更新视图
          if (data.status === 'completed') {
            setViewState('completed');
          } else if (data.status === 'failed' || data.error) {
            setViewState('error');
            setError(data.error || '下载失败');
          } else if (data.status === 'downloading' || data.status === 'pending') {
            setViewState('downloading');
          }
        }
      } catch (e) {
        console.error('[WebSocket] Failed to parse message:', e);
      }
    };

    ws.onclose = () => {
      console.log('[WebSocket] Disconnected');
      wsRef.current = null;
      // 如果还在下载视图，尝试重连
      if (viewState === 'downloading') {
        reconnectTimeoutRef.current = window.setTimeout(() => {
          connectWebSocket();
        }, 2000);
      }
    };

    ws.onerror = (error) => {
      console.error('[WebSocket] Error:', error);
    };

    wsRef.current = ws;
  }, [taskId, viewState]);

  // 当进入下载视图时连接 WebSocket
  useEffect(() => {
    if (viewState === 'downloading') {
      connectWebSocket();

      // 如果有 taskId，订阅特定任务；否则服务会自动返回最新任务
      if (taskId) {
        fetch(`${PROGRESS_API_URL}/api/subscribe`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ task_id: taskId }),
        }).catch(console.error);
      }
    }

    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, [viewState, taskId, connectWebSocket]);

  // 组件卸载时清理 WebSocket
  useEffect(() => {
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
    };
  }, []);

  // 视图状态变化时调整窗口大小
  useEffect(() => {
    const adjustWindowSize = async () => {
      try {
        if (viewState === 'downloading') {
          await invoke('resize_window', { width: 500, height: 334 });
        } else if (viewState === 'completed') {
          await invoke('resize_window', { width: 494, height: 229 });
        } else if (viewState === 'form') {
          await invoke('resize_window', { width: 500, height: 380 });
        }
      } catch { /* ignore */ }
    };
    adjustWindowSize();
  }, [viewState]);

  // 关闭窗口
  const handleClose = useCallback(async () => {
    try {
      await invoke('close_window');
    } catch { /* ignore */ }
  }, []);

  // 最小化窗口
  const handleMinimize = useCallback(async () => {
    try {
      await invoke('minimize_window');
    } catch { /* ignore */ }
  }, []);

  // 打开主程序
  const handleOpenMainApp = useCallback(async () => {
    try {
      await invoke('open_main_app');
    } catch (e) {
      console.error('Failed to open main app:', e);
    }
  }, []);

  // 开始下载
  const handleStart = useCallback(async () => {
    if (!url.trim() || !filename.trim() || isSubmitting) return;

    setIsSubmitting(true);
    setError(null);

    try {
      // 发送下载请求到主程序
      await invoke('send_download_request', {
        request: {
          url: url.trim(),
          filename: filename.trim(),
          save_path: savePath.trim(),
        },
      });

      // 请求发送成功，切换到进度视图
      // 不需要设置 taskId，服务会自动返回最新添加的任务
      setViewState('downloading');
      setIsSubmitting(false);
    } catch (e) {
      console.error('Failed to send download request:', e);
      setError(typeof e === 'string' ? e : '无法连接到主程序，请确保 Hanabi 下载管理器正在运行');
      setIsSubmitting(false);
    }
  }, [url, filename, savePath, isSubmitting]);

  // 选择保存路径
  const handleSelectFolder = useCallback(async () => {
    try {
      const selected = await open({
        directory: true,
        multiple: false,
        defaultPath: savePath || undefined,
        title: '选择保存位置',
      });
      if (selected && typeof selected === 'string') {
        setSavePath(selected);
      }
    } catch (e) {
      console.error('Failed to select folder:', e);
    }
  }, [savePath]);

  // 打开文件
  const handleOpenFile = useCallback(async () => {
    if (!savePath || !filename) return;
    try {
      const filePath = `${savePath}\\${progressData?.filename || filename}`;
      await invoke('open_file', { path: filePath });
      // 执行后关闭窗口
      await invoke('close_window');
    } catch (e) {
      console.error('Failed to open file:', e);
    }
  }, [savePath, filename, progressData]);

  // 打开文件夹
  const handleOpenFolder = useCallback(async () => {
    if (!savePath) return;
    try {
      await invoke('open_folder', { path: savePath });
      // 执行后关闭窗口
      await invoke('close_window');
    } catch (e) {
      console.error('Failed to open folder:', e);
    }
  }, [savePath]);

  // 重试下载
  const handleRetry = useCallback(() => {
    setViewState('form');
    setError(null);
    setProgressData(null);
    setTaskId(null);
  }, []);

  // 暂停下载
  const handlePause = useCallback(async () => {
    try {
      const currentTaskId = progressData?.task_id || taskId;
      await fetch(`${PROGRESS_API_URL}/api/pause`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ task_id: currentTaskId }),
      });
    } catch (e) {
      console.error('Failed to pause download:', e);
    }
  }, [progressData, taskId]);

  // 继续下载
  const handleResume = useCallback(async () => {
    try {
      const currentTaskId = progressData?.task_id || taskId;
      await fetch(`${PROGRESS_API_URL}/api/resume`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ task_id: currentTaskId }),
      });
    } catch (e) {
      console.error('Failed to resume download:', e);
    }
  }, [progressData, taskId]);

  // 判断是否暂停状态
  const isPaused = progressData?.status === 'paused';

  const fileIconData = getFileIcon(progressData?.filename || filename);
  const canSubmit = url.trim() && filename.trim() && !isSubmitting;

  // 计算进度显示数据
  const displayProgress = progressData?.progress ?? 0;
  const displaySpeed = progressData?.speed ?? 0;
  const displayDownloaded = progressData?.downloaded_size ?? 0;
  const displayTotal = progressData?.total_size ?? 0;
  const displayRemaining = progressData?.remaining_seconds ?? 0;
  const displaySegments = progressData?.segments ?? [];

  // 渲染表单视图
  const renderFormView = () => (
    <div className="form-view">
      {/* 文件预览 */}
      {filename && (
        <div className="file-preview">
          <div className="file-icon" style={{ background: fileIconData.bg, color: fileIconData.color }}>
            {fileIconData.icon}
          </div>
          <div className="file-preview-info">
            <div className="file-name">{filename}</div>
            <div className="file-url selectable">
              {url.length > 60 ? url.slice(0, 60) + '...' : url}
            </div>
          </div>
        </div>
      )}

      {/* 下载链接 */}
      <div className="input-group">
        <label className="input-label">下载链接</label>
        <input
          className="input"
          placeholder="输入或粘贴下载链接..."
          value={url}
          onChange={e => {
            setUrl(e.target.value);
            setError(null);
          }}
          autoFocus
          disabled={isSubmitting}
        />
      </div>

      {/* 文件名 */}
      <div className="input-group">
        <label className="input-label">文件名</label>
        <input
          className="input"
          placeholder="文件名将自动解析..."
          value={filename}
          onChange={e => {
            setFilename(e.target.value);
            setError(null);
          }}
          disabled={isSubmitting}
        />
      </div>

      {/* 保存路径 */}
      <div className="input-group">
        <label className="input-label">保存到</label>
        <div className="input-row">
          <input
            className="input"
            value={savePath}
            onChange={e => setSavePath(e.target.value)}
            disabled={isSubmitting}
          />
          <button
            className="icon-btn"
            onClick={handleSelectFolder}
            aria-label="选择文件夹"
            disabled={isSubmitting}
          >
            {Icons.folder}
          </button>
        </div>
      </div>

      {/* 错误提示 */}
      {error && (
        <div className="error-message">
          {error}
        </div>
      )}

      {/* 操作按钮 */}
      <div className="actions">
        <button
          className="btn btn-ghost"
          onClick={handleClose}
          disabled={isSubmitting}
        >
          取消
        </button>
        <button
          className="btn btn-primary"
          onClick={handleStart}
          disabled={!canSubmit}
        >
          {isSubmitting ? (
            <>
              <span className="btn-spinner">{Icons.spinner}</span>
              <span>发送中...</span>
            </>
          ) : (
            <>
              {Icons.download}
              <span>开始下载</span>
            </>
          )}
        </button>
      </div>
    </div>
  );

  // 渲染下载进度视图
  const renderDownloadingView = () => (
    <div className="download-view">
      {/* 文件信息 */}
      <div className="file-info">
        <div className="file-icon" style={{ background: fileIconData.bg, color: fileIconData.color }}>
          {fileIconData.icon}
        </div>
        <div className="file-details">
          <div className="file-name">{progressData?.filename || filename}</div>
          <div className="file-url selectable">
            {url.length > 50 ? url.slice(0, 50) + '...' : url}
          </div>
        </div>
      </div>

      {/* 统计信息 */}
      <div className="stats-row">
        <div className="stat-box">
          <div className="stat-value highlight">{formatSpeed(displaySpeed)}</div>
          <div className="stat-label">速度</div>
        </div>
        <div className="stat-box">
          <div className="stat-value">{formatBytes(displayDownloaded)}</div>
          <div className="stat-label">已下载</div>
        </div>
        <div className="stat-box">
          <div className="stat-value">{formatBytes(displayTotal)}</div>
          <div className="stat-label">总大小</div>
        </div>
        <div className="stat-box">
          <div className="stat-value">{formatTime(displayRemaining)}</div>
          <div className="stat-label">剩余</div>
        </div>
      </div>

      {/* 进度条 */}
      <div className="progress-section">
        <div className="progress-header">
          <div className="progress-status">
            <span className={`status-dot ${isPaused ? 'paused' : 'downloading'}`}></span>
            <span>{isPaused ? '已暂停' : '下载中...'}</span>
          </div>
          <span className="progress-percent">{(displayProgress * 100).toFixed(1)}%</span>
        </div>
        <div className="progress-bar-wrap">
          <div
            className="progress-bar-fill"
            style={{ width: `${displayProgress * 100}%` }}
          ></div>
        </div>
      </div>

      {/* 分段进度 */}
      {displaySegments.length > 0 && (
        <div className="progress-section">
          <div className="segment-bar">
            {displaySegments.map((seg, idx) => (
              <div
                key={idx}
                className={`segment ${seg.status}`}
                title={`分段 ${idx + 1}: ${(seg.progress * 100).toFixed(0)}%`}
              >
                <div
                  className="segment-fill"
                  style={{ width: `${seg.progress * 100}%` }}
                ></div>
              </div>
            ))}
          </div>
          <div className="segment-info">
            <span className="segment-text">{displaySegments.length} 个分段</span>
            <span className="segment-text">
              {displaySegments.filter(s => s.status === 'completed').length} 已完成
            </span>
          </div>
        </div>
      )}

      {/* 操作按钮 */}
      <div className="actions">
        <button className="btn btn-ghost" onClick={handleOpenMainApp}>
          {Icons.openFolder}
          <span>打开主程序</span>
        </button>
        <button className="btn btn-ghost" onClick={handleClose}>
          后台下载
        </button>
        {isPaused ? (
          <button className="btn btn-primary" onClick={handleResume}>
            {Icons.play}
            <span>继续</span>
          </button>
        ) : (
          <button className="btn btn-ghost" onClick={handlePause}>
            {Icons.pause}
            <span>暂停</span>
          </button>
        )}
      </div>
    </div>
  );

  // 渲染完成视图
  const renderCompletedView = () => (
    <div className="completed-view">
      {/* 完成信息 */}
      <div className="completed-header">
        <div
          className="completed-icon-wrap"
          style={{ background: fileIconData.bg, color: fileIconData.color }}
        >
          {fileIconData.icon}
        </div>
        <div className="completed-info">
          <div className="completed-title-row">
            <span className="completed-check">{Icons.check}</span>
            <span className="completed-title">下载完成</span>
          </div>
          <div className="completed-filename">{progressData?.filename || filename}</div>
        </div>
      </div>

      {/* 完成统计 */}
      <div className="completed-stats">
        <div className="completed-stat">
          <div className="completed-stat-value">{formatBytes(displayTotal)}</div>
          <div className="completed-stat-label">文件大小</div>
        </div>
        <div className="completed-stat">
          <div className="completed-stat-value">{savePath}</div>
          <div className="completed-stat-label">保存位置</div>
        </div>
      </div>

      {/* 操作按钮 */}
      <div className="actions">
        <button className="btn btn-ghost" onClick={handleClose}>
          关闭
        </button>
        <button className="btn btn-ghost" onClick={handleOpenFolder}>
          {Icons.openFolder}
          <span>打开文件夹</span>
        </button>
        <button className="btn btn-success" onClick={handleOpenFile}>
          {Icons.openFile}
          <span>打开文件</span>
        </button>
      </div>
    </div>
  );

  // 渲染错误视图
  const renderErrorView = () => (
    <div className="download-view">
      {/* 文件信息 */}
      <div className="file-info">
        <div className="file-icon" style={{ background: 'rgba(248, 113, 113, 0.12)', color: '#f87171' }}>
          {Icons.error}
        </div>
        <div className="file-details">
          <div className="file-name">{progressData?.filename || filename}</div>
          <div className="file-url" style={{ color: 'var(--system-fill-critical)' }}>
            下载失败
          </div>
        </div>
      </div>

      {/* 错误信息 */}
      <div className="error-message">
        {error || progressData?.error || '未知错误'}
      </div>

      {/* 操作按钮 */}
      <div className="actions">
        <button className="btn btn-ghost" onClick={handleClose}>
          关闭
        </button>
        <button className="btn btn-primary" onClick={handleRetry}>
          {Icons.retry}
          <span>重试</span>
        </button>
      </div>
    </div>
  );

  // 生成标题栏文字
  const getTitleText = () => {
    if (viewState === 'form') {
      return 'Hanabi Download Pop';
    }
    if (viewState === 'downloading' || viewState === 'error') {
      const name = progressData?.filename || filename;
      const shortName = name.length > 20 ? name.slice(0, 18) + '...' : name;
      const speed = formatSpeed(displaySpeed);
      const percent = `${(displayProgress * 100).toFixed(0)}%`;
      return `${shortName} | ${speed} | ${percent}`;
    }
    if (viewState === 'completed') {
      return '下载完成';
    }
    return 'Hanabi Download Pop';
  };

  return (
    <div className="app">
      {/* Titlebar */}
      <div className="titlebar">
        <div className="titlebar-left">
          <img src={logoImg} alt="logo" className="titlebar-icon" style={{ width: 16, height: 16 }} />
          <span className="titlebar-text">{getTitleText()}</span>
        </div>
        <div className="titlebar-btns">
          <button className="titlebar-btn" onClick={handleMinimize} aria-label="最小化">
            {Icons.minimize}
          </button>
          <button className="titlebar-btn close" onClick={handleClose} aria-label="关闭">
            {Icons.close}
          </button>
        </div>
      </div>

      {/* Content */}
      <div className="content">
        {viewState === 'form' && renderFormView()}
        {viewState === 'downloading' && renderDownloadingView()}
        {viewState === 'completed' && renderCompletedView()}
        {viewState === 'error' && renderErrorView()}
      </div>
    </div>
  );
}

export default App;
