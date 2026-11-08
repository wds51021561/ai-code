import subprocess
import os
from pathlib import Path
from typing import Optional, Callable

from PIL import Image

from ..config import WebpConfig
from ..download_utils import download_tool
from utils import get_models_dir

MODELS_DIR = get_models_dir()
CWEBP_EXE = MODELS_DIR / "cwebp.exe"
# Older version: libwebp-1.6.0-windows-x64.zip
CWEBP_URL = (
    "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/"
    "libwebp-1.6.0-windows-x64.zip"
)


def ensure_cwebp(progress_callback: Optional[Callable] = None) -> Optional[str]:
    return download_tool(
        name="libwebp",
        url=CWEBP_URL,
        dest_dir=MODELS_DIR,
        exe_name="cwebp.exe",
        subfolder_prefix="libwebp",
        extra_files=["libsharpyuv.dll"],
        progress_callback=progress_callback,
    )


WEBP_MAX_DIM = 16383


def _ensure_valid_dimensions(path: str) -> str:
    with Image.open(path) as img:
        w, h = img.size
        if w <= WEBP_MAX_DIM and h <= WEBP_MAX_DIM:
            return path
        scale = min(WEBP_MAX_DIM / w, WEBP_MAX_DIM / h)
        new_w, new_h = int(w * scale), int(h * scale)
        img = img.resize((new_w, new_h), Image.LANCZOS)
        dir_name = os.path.dirname(path)
        base = os.path.splitext(os.path.basename(path))[0]
        resized = os.path.join(dir_name, f"{base}_resized.png")
        img.save(resized, "PNG")
    return resized


def convert_with_cwebp(input_path: str, output_path: str,
                       config: WebpConfig,
                       current_proc: Optional[list] = None) -> None:
    original_path = input_path
    input_path = _ensure_valid_dimensions(input_path)
    try:
        cmd = [
            str(CWEBP_EXE),
            "-q", str(config.quality),
            "-m", str(config.method),
            "-alpha_q", str(config.alpha_quality),
            "-f", str(config.filter_strength),
            "-sharpness", str(config.filter_sharpness),
        ]

        if config.lossless:
            cmd.append("-lossless")

        if config.use_sharp_yuv:
            cmd.append("-sharp_yuv")

        if config.target_filesize_kb > 0:
            cmd.extend(["-size", str(config.target_filesize_kb * 1024)])

        cmd.extend(["-metadata", "none"])
        cmd.extend(["-o", output_path, input_path])

        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, errors='replace',
                                creationflags=subprocess.CREATE_NO_WINDOW)
        if current_proc is not None:
            current_proc[0].append(proc)

        try:
            stdout, stderr = proc.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            raise RuntimeError("cwebp 转码超时")

        if current_proc is not None:
            current_proc[0].remove(proc)

        if proc.returncode != 0 and proc.returncode != -15:
            err = (stderr or "").strip() or "未知错误"
            raise RuntimeError(f"cwebp 转码失败: {err}")
    finally:
        if input_path != original_path:
            try:
                os.remove(input_path)
            except OSError:
                pass
