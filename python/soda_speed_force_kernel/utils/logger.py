import logging
import sys
import os
from pathlib import Path

# 创建日志目录
log_dir = Path.home() / "Downloads" / "soda_logs"
log_dir.mkdir(parents=True, exist_ok=True)
log_file = log_dir / "downloader.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(log_file, encoding='utf-8')
    ]
)

logger = logging.getLogger('SodaSpeedForce')
logger.info(f"日志文件位置: {log_file}")
