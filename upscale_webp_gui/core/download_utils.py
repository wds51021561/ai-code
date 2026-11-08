import os
import zipfile
import requests
import shutil
from pathlib import Path
from typing import Callable, Optional


def download_file(url: str, dest_path, progress_callback: Callable = None,
                  timeout: int = 300, label: str = None) -> str:
    """下载单个文件到 dest_path（先写 .part，成功后再替换）。"""
    dest_path = Path(dest_path)
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return str(dest_path)

    dest_path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = dest_path.with_name(dest_path.name + ".part")
    name = label or dest_path.name

    try:
        if progress_callback:
            progress_callback(0, f"正在下载 {name}...")

        with requests.get(url, stream=True, timeout=(15, timeout)) as response:
            response.raise_for_status()
            total = int(response.headers.get("content-length", 0))
            downloaded = 0
            last_pct = -1
            with open(tmp_path, "wb") as f:
                for chunk in response.iter_content(chunk_size=1024 * 64):
                    if not chunk:
                        continue
                    f.write(chunk)
                    downloaded += len(chunk)
                    if progress_callback and total > 0:
                        pct = int(downloaded / total * 100)
                        if pct != last_pct:
                            last_pct = pct
                            progress_callback(pct, f"下载 {name} {pct}%")

        os.replace(tmp_path, dest_path)
        if progress_callback:
            progress_callback(100, f"{name} 下载完成")
        return str(dest_path)
    except Exception:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except OSError:
                pass
        raise


def download_tool(name: str, url: str, dest_dir: Path,
                  exe_name: str = None,
                  subfolder_prefix: str = None,
                  extra_files: list = None,
                  progress_callback: Callable = None) -> Optional[str]:
    if exe_name is None:
        exe_name = name

    exe_path = dest_dir / exe_name
    if exe_path.exists():
        return str(exe_path)

    dest_dir.mkdir(parents=True, exist_ok=True)
    zip_path = dest_dir / f"{name}.zip"

    try:
        if progress_callback:
            progress_callback(0, f"正在下载 {name}...")

        response = requests.get(url, stream=True, timeout=120)
        response.raise_for_status()
        total = int(response.headers.get("content-length", 0))

        downloaded = 0
        chunk_size = 8192
        with open(zip_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=chunk_size):
                f.write(chunk)
                downloaded += len(chunk)
                if progress_callback and total > 0:
                    pct = int(downloaded / total * 100)
                    progress_callback(pct, f"下载 {name} {pct}%")

        if progress_callback:
            progress_callback(50, f"正在解压 {name}...")

        with zipfile.ZipFile(zip_path, "r") as zf:
            zf.extractall(dest_dir)

        zip_path.unlink()

        if subfolder_prefix:
            for item in dest_dir.iterdir():
                if item.is_dir() and item.name.startswith(subfolder_prefix):
                    src = item / exe_name
                    if src.exists():
                        src.rename(exe_path)
                    if extra_files:
                        for fname in extra_files:
                            sf = item / fname
                            if sf.exists():
                                dst = dest_dir / fname
                                if not dst.exists():
                                    sf.rename(dst)
                    try:
                        shutil.rmtree(item)
                    except OSError:
                        pass
                    break

        if exe_path.exists():
            if progress_callback:
                progress_callback(100, f"{name} 下载完成")
            return str(exe_path)

        return None

    except Exception as e:
        if zip_path.exists():
            zip_path.unlink()
        raise RuntimeError(f"下载 {name} 失败: {e}")
