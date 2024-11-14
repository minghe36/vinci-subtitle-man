import os
import platform
import subprocess
import sys
import zipfile
import shutil

def install_package(*packages):
    """安装Python包"""
    subprocess.check_call([sys.executable, "-m", "pip", "install", *packages])

# 安装rich用于美化输出
install_package("rich")
from rich.console import Console
from rich.panel import Panel

console = Console()

def check_gpu():
    """检查是否有NVIDIA GPU"""
    try:
        subprocess.run(['nvidia-smi'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def check_python_version():
    """检查Python版本"""
    console.print(Panel("🔍 检查Python版本...", style="bold yellow"))
    if sys.version_info < (3, 7):
        console.print(Panel("❌ 错误: 需要Python 3.7或更高版本", style="bold red"))
        return False
    console.print(f"✅ Python版本: {sys.version}", style="green")
    return True

def check_pip():
    """检查pip是否安装"""
    console.print(Panel("🔍 检查pip...", style="bold yellow"))
    try:
        subprocess.run([sys.executable, "-m", "pip", "--version"], check=True)
        console.print("✅ pip已安装", style="green")
        return True
    except subprocess.CalledProcessError:
        console.print(Panel("❌ 错误: pip未安装", style="bold red"))
        return False

def download_and_install_ffmpeg():
    """下载并安装FFmpeg"""
    console.print(Panel("📥 安装FFmpeg...", style="bold yellow"))
    system = platform.system()
    
    # 检查FFmpeg是否已安装
    try:
        subprocess.run(["ffmpeg", "-version"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        console.print("✅ FFmpeg已安装", style="green")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    if system == "Windows":
        url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
        ffmpeg_exe = "ffmpeg.exe"
    elif system == "Darwin":
        try:
            subprocess.run(["brew", "install", "ffmpeg"], check=True)
            console.print("✅ FFmpeg已通过Homebrew安装", style="green")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            console.print("❌ 请先安装Homebrew: https://brew.sh/", style="red")
            return False
    elif system == "Linux":
        try:
            if os.path.exists("/etc/debian_version"):
                subprocess.run(["sudo", "apt", "update"], check=True)
                subprocess.run(["sudo", "apt", "install", "-y", "ffmpeg"], check=True)
            elif os.path.exists("/etc/fedora-release"):
                subprocess.run(["sudo", "dnf", "install", "-y", "ffmpeg"], check=True)
            elif os.path.exists("/etc/arch-release"):
                subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "ffmpeg"], check=True)
            console.print("✅ FFmpeg已安装", style="green")
            return True
        except subprocess.CalledProcessError:
            console.print("❌ FFmpeg安装失败", style="red")
            return False
    
    return True

def install_pytorch():
    """安装PyTorch"""
    console.print(Panel("📦 安装PyTorch...", style="bold yellow"))
    system = platform.system()
    
    if system == "Darwin" and platform.machine() == "arm64":
        console.print("🍎 检测到M1/M2 Mac，安装CPU版本PyTorch", style="cyan")
        cmd = [sys.executable, "-m", "pip", "install", "torch", "torchvision", "torchaudio"]
    else:
        has_gpu = check_gpu()
        if has_gpu:
            console.print("🎮 检测到NVIDIA GPU，安装CUDA版本PyTorch", style="cyan")
            cmd = [sys.executable, "-m", "pip", "install", "torch", "torchvision", "torchaudio", 
                   "--index-url", "https://download.pytorch.org/whl/cu118"]
        else:
            console.print("💻 未检测到NVIDIA GPU，安装CPU版本PyTorch（转录速度会较慢）", style="cyan")
            cmd = [sys.executable, "-m", "pip", "install", "torch", "torchvision", "torchaudio"]
    
    try:
        subprocess.run(cmd, check=True)
        console.print("✅ PyTorch安装成功", style="green")
        return True
    except subprocess.CalledProcessError:
        console.print("❌ PyTorch安装失败", style="red")
        return False

def install_stable_ts():
    """安装stable-ts"""
    console.print(Panel("📦 安装stable-ts...", style="bold yellow"))
    try:
        subprocess.run([sys.executable, "-m", "pip", "install", "-U", 
                       "git+https://github.com/jianfch/stable-ts.git"], check=True)
        console.print("✅ stable-ts安装成功", style="green")
        return True
    except subprocess.CalledProcessError:
        console.print("❌ stable-ts安装失败", style="red")
        return False

def main():
    console.print(Panel.fit("🚀 开始安装依赖", style="bold magenta"))
    
    # 检查Python版本
    if not check_python_version():
        return
    
    # 检查pip
    if not check_pip():
        return
    
    # 安装FFmpeg
    if not download_and_install_ffmpeg():
        return
    
    # 安装PyTorch
    if not install_pytorch():
        return
    
    # 安装stable-ts
    if not install_stable_ts():
        return
    
    console.print(Panel.fit("✨ 所有依赖安装完成！", style="bold green"))
    
    # 验证安装
    console.print(Panel("🔍 验证安装...", style="bold yellow"))
    try:
        subprocess.run(["stable-ts", "--version"], check=True)
        console.print("✅ stable-ts 安装验证成功！", style="green")
    except subprocess.CalledProcessError:
        console.print("⚠️ stable-ts 安装可能有问题，请检查错误信息", style="yellow")

if __name__ == "__main__":
    main()
