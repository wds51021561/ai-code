"""模型目录：把不同超分引擎的模型统一成一个列表给 UI 使用。"""

from typing import Callable, Optional

from .base import get_model
# 导入即触发 @register_model 注册
from .realesrgan import RealESRGAN  # noqa: F401
from .waifu2x import Waifu2x  # noqa: F401

# (配置里保存的 key, 界面显示名)
MODEL_CHOICES = [
    ("realesrgan-x4plus", "realesrgan-x4plus（画质优先）"),
    ("realesrgan-x4plus-anime", "realesrgan-x4plus-anime（漫画）"),
    ("realesr-animevideov3", "realesr-animevideov3（轻量）"),
    ("4x-AnimeSharp", "4x-AnimeSharp（4x，文字较稳）"),
    ("waifu2x", "waifu2x（文字优先，2x）"),
]

MODEL_HINTS = {
    "realesrgan-x4plus": "画面最锐，但中文小字容易被重画，出现粘连、弯曲。",
    "realesrgan-x4plus-anime": "动漫/漫画模型，画面较干净，但文字仍可能被重画。",
    "realesr-animevideov3": "轻量模型，原生 2x，较温和。适合先做 2x 对比。",
    "4x-AnimeSharp": "4x 模型，文字比 x4plus 稍稳，但极小字仍可能粘连或出现黑点（CC BY-NC-SA，仅限非商业）。",
    "waifu2x": "文字优先：原生 2x、noise=-1，笔画基本不会被重画，画面会偏软。",
}


def list_model_choices() -> list:
    return list(MODEL_CHOICES)


def model_hint(model_key: str) -> str:
    return MODEL_HINTS.get(model_key, "")


def get_engine(model_key: str):
    """根据模型 key 返回对应的引擎实例。"""
    if model_key == "waifu2x":
        return get_model("waifu2x")
    return get_model("realesrgan")


def supported_scales_for_key(model_key: str) -> list:
    return get_engine(model_key).supported_scales(model_key)


def ensure_model_ready(model_key: str,
                       progress_callback: Optional[Callable] = None) -> Optional[str]:
    """处理前确保对应引擎/模型文件已经下载。"""
    engine = get_engine(model_key)
    if hasattr(engine, "ensure_model"):
        return engine.ensure_model(model_key, progress_callback)
    return engine.ensure_downloaded(progress_callback)
