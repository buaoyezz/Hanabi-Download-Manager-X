import os
import shutil
from datetime import datetime

def clean_pycache(path='.'):
    count = 0
    total_size = 0
    
    print(f"开始清理 Python 缓存文件...")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"扫描目录: {os.path.abspath(path)}")
    print("-" * 50)
    
    for root, dirs, files in os.walk(path):
        if '__pycache__' in dirs:
            cache_dir = os.path.join(root, '__pycache__')
            try:
                size = sum(os.path.getsize(os.path.join(dirpath, filename)) 
                          for dirpath, _, filenames in os.walk(cache_dir)
                          for filename in filenames)
                total_size += size
                shutil.rmtree(cache_dir)
                count += 1
                print(f"已清理: {cache_dir} ({size / 1024:.1f} KB)")
            except Exception as e:
                print(f"清理失败: {cache_dir} - {str(e)}")
        
        # 清理.pyc文件
        for file in files:
            if file.endswith('.pyc'):
                pyc_file = os.path.join(root, file)
                try:
                    size = os.path.getsize(pyc_file)
                    total_size += size
                    os.remove(pyc_file)
                    print(f"已清理: {pyc_file} ({size / 1024:.1f} KB)")
                except Exception as e:
                    print(f"清理失败: {pyc_file} - {str(e)}")
    
    print("-" * 50)
    print(f"清理完成!")
    print(f"清理目录数: {count}")
    print(f"总清理空间: {total_size / 1024 / 1024:.2f} MB")
    print(f"结束时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="清理Python缓存文件工具")
    parser.add_argument("--path", default=".", help="要清理的目录路径，默认为当前目录")
    args = parser.parse_args()
    
    clean_pycache(args.path) 