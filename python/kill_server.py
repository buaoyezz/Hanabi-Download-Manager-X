import subprocess
import psutil
import os
print("SodaKernel Killer")
try:
    result = subprocess.run(['netstat', '-ano'], capture_output=True, text=True)
    lines = result.stdout.split('\n')
    found_process = False
    for line in lines:
        if ':9710' in line and 'LISTENING' in line:
            pid = line.strip().split()[-1]
            try:
                os.system(f'taskkill /F /PID {pid}')
                print(f"已关闭端口9710的kenrel PID: {pid}")
                found_process = True
            except:
                pass
    if not found_process:
        print(f"Kernel没有在运行，无需关闭")
except:
    pass

found_soda_process = False
for proc in psutil.process_iter(['pid', 'name']):
    try:
        if proc.info['name'] == 'soda_kernel.exe':
            proc.kill()
            print(f"已退出soda_kernel.exe进程 PID: {proc.info['pid']}")
            found_soda_process = True
    except:
        pass
if not found_soda_process:
    print("以退出和关闭正在运行的Kernel了")
