from dataclasses import dataclass
from enum import Enum
from typing import Optional, Dict, Any

class TaskStatus(Enum):
    PENDING = "pending"
    DOWNLOADING = "downloading"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"

@dataclass
class Task:
    id: str
    url: str
    filename: str
    filepath: str
    status: TaskStatus
    progress: float = 0.0
    speed: float = 0.0
    totalSize: int = 0
    downloadedSize: int = 0
    eta: int = 0
    createdTime: float = 0.0
    errorMessage: Optional[str] = None
    segments: Optional[list] = None

    def to_dict(self) -> Dict[str, Any]:
        def _fmt_size(n: int) -> str:
            try:
                v = int(n or 0)
            except Exception:
                v = 0
            units = ["B", "KB", "MB", "GB", "TB"]
            size = float(v)
            idx = 0
            while size >= 1024 and idx < len(units) - 1:
                size /= 1024.0
                idx += 1
            if idx == 0:
                return f"{int(size)} B"
            return f"{size:.1f} {units[idx]}"
        def _fmt_speed(n: float) -> str:
            try:
                v = float(n or 0.0)
            except Exception:
                v = 0.0
            units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
            spd = float(v)
            idx = 0
            while spd >= 1024 and idx < len(units) - 1:
                spd /= 1024.0
                idx += 1
            if idx == 0:
                return f"{int(spd)} B/s"
            return f"{spd:.1f} {units[idx]}"
        result = {
            "id": self.id,
            "url": self.url,
            "fileName": self.filename,
            "filename": self.filename,
            "filepath": self.filepath,
            "status": self.status.value,
            "progress": self.progress,
            "speed": self.speed,
            "speedFormatted": _fmt_speed(self.speed),
            "downloaded": _fmt_size(self.downloadedSize) if self.downloadedSize > 0 else "0 B",
            "downloadedSize": self.downloadedSize,
            "size": _fmt_size(self.totalSize) if self.totalSize > 0 else "未知",
            "totalSize": self.totalSize,
            "timeRemaining": f"{self.eta}s" if self.eta > 0 else "",
            "eta": self.eta,
            "createdTime": self.createdTime,
            "errorMessage": self.errorMessage,
        }
        
        if self.segments:
            result["segments"] = self.segments
        
        return result
