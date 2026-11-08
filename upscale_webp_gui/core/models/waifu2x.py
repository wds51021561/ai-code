import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from typing import Callable, Optional

from .base import BaseModel, register_model
from ..download_utils import download_file
from utils import get_models_dir

MODELS_DIR = get_models_dir()
WAIFU2X_DIR = MODELS_DIR / "waifu2x"
EXE_NAME = "waifu2x-ncnn-vulkan.exe"
EXE_PATH = WAIFU2X_DIR / EXE_NAME
MODEL_DIR = WAIFU2X_DIR / "models-cunet"

RELEASE_URL = (
    "https://github.com/nihui/waifu2x-ncnn-vulkan/releases/download/"
    "20220728/waifu2x-ncnn-vulkan-20220728-windows.zip"
)

# waifu2x 的文字保护逻辑：
# - 只用 2x，避免 4x 过度脑补
# - 默认 noise=-1（不降噪），最大程度保留原始笔画结构
# - 画面会偏软，适合文字优先的页面
NOISE_LEVEL = -1

# noise=-1 实际使用 scale2.0x_model；确认关键文件存在，避免半残目录被误判为已就绪
REQUIRED_FILES = [
    EXE_PATH,
    WAIFU2X_DIR / "vcomp140.dll",
    MODEL_DIR / "scale2.0x_model.bin",
    MODEL_DIR / "scale2.0x_model.param",
]


def _is_ready() -> bool:
    return all(p.exists() and p.stat().st_size > 0 for p in REQUIRED_FILES)


@register_model
class Waifu2x(BaseModel):

    @staticmethod
    def name() -> str:
        return "waifu2x"

    @staticmethod
    def display_names() -> list:
        return ["waifu2x"]

    @staticmethod
    def supported_scales(model_key: str) -> list:
        return [2]

    @staticmethod
    def native_scale(model_key: str) -> int:
        return 2

    @staticmethod
    def ensure_downloaded(progress_callback: Optional[Callable] = None) -> Optional[str]:
        if _is_ready():
            return str(EXE_PATH)

        WAIFU2X_DIR.mkdir(parents=True, exist_ok=True)
        zip_path = WAIFU2X_DIR / "waifu2x.zip"

        try:
            download_file(RELEASE_URL, zip_path,
                          progress_callback=progress_callback,
                          timeout=600, label="waifu2x")

            with tempfile.TemporaryDirectory(prefix="waifu2x_", dir=str(WAIFU2X_DIR)) as tmp:
                with zipfile.ZipFile(zip_path, "r") as zf:
                    zf.extractall(tmp)

                roots = [p for p in Path(tmp).iterdir() if p.is_dir()]
                root = roots[0] if roots else Path(tmp)

                # exe 依赖 vcomp140.dll，必须一起移动
                for item_name in ("waifu2x-ncnn-vulkan.exe", "vcomp140.dll",
                                  "models-cunet", "LICENSE"):
                    src = root / item_name
                    if not src.exists():
                        continue
                    dst = WAIFU2X_DIR / item_name
                    if dst.exists():
                        if dst.is_dir():
                            shutil.rmtree(dst)
                        else:
                            dst.unlink()
                    shutil.move(str(src), str(dst))

            zip_path.unlink(missing_ok=True)
        except Exception as e:
            if zip_path.exists():
                try:
                    zip_path.unlink()
                except OSError:
                    pass
            raise RuntimeError(
                f"下载 waifu2x 失败: {e}\n"
                f"可手动下载: {RELEASE_URL}\n"
                f"解压后把 waifu2x-ncnn-vulkan.exe、vcomp140.dll、models-cunet "
                f"放到: {WAIFU2X_DIR}"
            )

        if _is_ready():
            if progress_callback:
                progress_callback(100, "waifu2x 下载完成")
            return str(EXE_PATH)
        return None

    def process_image(self, input_path: str, output_path: str,
                      scale: int = 2, **kwargs) -> None:
        tile_size = kwargs.get("tile_size", 0)
        tta = kwargs.get("tta", False)
        gpu_id = kwargs.get("gpu_id", -1)
        current_proc = kwargs.get("current_proc")

        # waifu2x 支持 1/2/4/8...，这里只开放 2x；若外部传入其他值则回退 2x
        if scale not in (1, 2, 4, 8, 16, 32):
            scale = 2

        cmd = [
            str(EXE_PATH),
            "-i", input_path,
            "-o", output_path,
            "-n", str(NOISE_LEVEL),
            "-s", str(scale),
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
                                text=True, errors="replace",
                                creationflags=subprocess.CREATE_NO_WINDOW)
        if current_proc is not None:
            current_proc[0].append(proc)

        try:
            stdout, stderr = proc.communicate(timeout=600)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            raise RuntimeError("waifu2x 处理超时")

        if current_proc is not None:
            current_proc[0].remove(proc)

        if proc.returncode != 0 and proc.returncode != -15:
            raise RuntimeError(
                f"waifu2x 处理失败 (code={proc.returncode}):\n"
                f"stderr: {stderr}"
            )
