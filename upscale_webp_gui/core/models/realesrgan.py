import subprocess
import os
from pathlib import Path
from typing import Optional, Callable

from PIL import Image

from .base import BaseModel, register_model
from ..download_utils import download_file, download_tool
from utils import get_models_dir

MODELS_DIR = get_models_dir()
EXE_NAME = "realesrgan-ncnn-vulkan.exe"
EXE_PATH = MODELS_DIR / EXE_NAME
MODEL_DIR = MODELS_DIR / "models"

RELEASE_URL = (
    "https://github.com/xinntao/Real-ESRGAN/releases/download/"
    "v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip"
)

MODEL_MAP = {
    "realesrgan-x4plus":       "realesrgan-x4plus",
    "realesrgan-x4plus-anime": "realesrgan-x4plus-anime",
    "realesr-animevideov3":    "realesr-animevideov3",
    "4x-AnimeSharp":           "4x-AnimeSharp-fp16",
}

MODEL_SCALES = {
    "realesrgan-x4plus":       [4],
    "realesrgan-x4plus-anime": [4],
    "realesr-animevideov3":    [2],
    "4x-AnimeSharp":           [4],
}

# 4x-AnimeSharp 是单文件模型，首次选用时按需下载。
# 主源 HuggingFace，备用 hf-mirror（国内网络）。
ANIME_SHARP_FILES = {
    "4x-AnimeSharp-fp16.param": [
        "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/NCNN/4x-AnimeSharp-fp16.param",
        "https://hf-mirror.com/Kim2091/AnimeSharp/resolve/main/NCNN/4x-AnimeSharp-fp16.param",
    ],
    "4x-AnimeSharp-fp16.bin": [
        "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/NCNN/4x-AnimeSharp-fp16.bin",
        "https://hf-mirror.com/Kim2091/AnimeSharp/resolve/main/NCNN/4x-AnimeSharp-fp16.bin",
    ],
}


@register_model
class RealESRGAN(BaseModel):

    @staticmethod
    def name() -> str:
        return "realesrgan"

    @staticmethod
    def display_names() -> list:
        return list(MODEL_MAP.keys())

    @staticmethod
    def supported_scales(model_key: str) -> list:
        if model_key == "4x-AnimeSharp":
            return [4]
        return [2, 3, 4]

    @staticmethod
    def native_scale(model_key: str) -> int:
        return (MODEL_SCALES.get(model_key) or [4])[0]

    @staticmethod
    def ensure_downloaded(progress_callback: Optional[Callable] = None) -> Optional[str]:
        return download_tool(
            name="realesrgan-ncnn-vulkan",
            url=RELEASE_URL,
            dest_dir=MODELS_DIR,
            exe_name=EXE_NAME,
            subfolder_prefix="realesrgan-ncnn-vulkan",
            progress_callback=progress_callback,
        )

    @staticmethod
    def ensure_model(model_key: str,
                     progress_callback: Optional[Callable] = None) -> Optional[str]:
        """确保基础引擎和指定模型文件都已就绪。"""
        exe_path = RealESRGAN.ensure_downloaded(progress_callback)
        if not exe_path:
            raise RuntimeError("realesrgan 引擎不可用")

        if model_key != "4x-AnimeSharp":
            return exe_path

        MODEL_DIR.mkdir(parents=True, exist_ok=True)
        errors = []
        for fname, urls in ANIME_SHARP_FILES.items():
            dest = MODEL_DIR / fname
            if dest.exists() and dest.stat().st_size > 0:
                continue

            last_error = None
            for url in urls:
                try:
                    download_file(url, dest, progress_callback=progress_callback,
                                  timeout=600, label=fname)
                    break
                except Exception as e:
                    last_error = e
                    if progress_callback:
                        progress_callback(0, f"{fname} 下载失败，尝试备用源...")

            if not dest.exists() or dest.stat().st_size == 0:
                errors.append(f"{fname}: {last_error}")

        if errors:
            raise RuntimeError(
                "4x-AnimeSharp 模型下载失败，请手动下载后放入 "
                f"{MODEL_DIR}:\n" + "\n".join(errors)
            )
        return str(MODEL_DIR)

    def process_image(self, input_path: str, output_path: str,
                      scale: int = 4, **kwargs) -> None:
        model_key = kwargs.get("model_key", "realesrgan-x4plus")
        tile_size = kwargs.get("tile_size", 0)
        tta = kwargs.get("tta", False)
        gpu_id = kwargs.get("gpu_id", -1)
        current_proc = kwargs.get("current_proc")

        model_name = MODEL_MAP.get(model_key, "realesrgan-x4plus")
        native_s = self.native_scale(model_key)

        cmd = [
            str(EXE_PATH),
            "-i", input_path,
            "-o", output_path,
            "-s", str(native_s),
            "-n", model_name,
            "-m", str(MODEL_DIR),
            "-f", "png",
        ]

        if tile_size > 0:
            cmd.extend(["-t", str(tile_size)])
        if tta:
            cmd.append("-x")
        if gpu_id >= 0:
            cmd.extend(["-g", str(gpu_id)])

        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                text=True, errors='replace',
                                creationflags=subprocess.CREATE_NO_WINDOW)
        if current_proc is not None:
            current_proc[0].append(proc)

        try:
            stdout, stderr = proc.communicate(timeout=300)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            raise RuntimeError("realesrgan 处理超时")

        if current_proc is not None:
            current_proc[0].remove(proc)

        if proc.returncode != 0 and proc.returncode != -15:
            raise RuntimeError(
                f"realesrgan 处理失败 (code={proc.returncode}):\n"
                f"stderr: {stderr}"
            )

        if scale != native_s:
            ratio = scale / native_s
            with Image.open(output_path) as img:
                w, h = img.size
                new_w = int(w * ratio)
                new_h = int(h * ratio)
                img = img.resize((new_w, new_h), Image.LANCZOS)
                img.save(output_path, "PNG")
