import os
from pathlib import Path

def getDefaultDownloadPath() -> str:
    if os.name == 'nt':
        downloads = Path.home() / 'Downloads'
    else:
        downloads = Path.home() / 'Downloads'
    
    downloads.mkdir(parents=True, exist_ok=True)
    
    return str(downloads)
