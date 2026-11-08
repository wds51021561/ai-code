import json
import os
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import List


CONFIG_DIR = Path(os.environ.get("APPDATA", "~")).expanduser() / "upscale_webp_gui"
CONFIG_FILE = CONFIG_DIR / "config.json"


@dataclass
class WebpConfig:
    quality: int = 90
    lossless: bool = False
    method: int = 4
    alpha_quality: int = 100
    filter_strength: int = 0
    filter_sharpness: int = 0
    use_sharp_yuv: bool = True
    target_filesize_kb: int = 0


@dataclass
class UpscaleConfig:
    scale: int = 4
    tile_size: int = 0
    tta: bool = False
    gpu_id: int = -1


@dataclass
class AppConfig:
    input_dir: str = ""
    output_dir: str = ""
    model_name: str = "realesrgan-x4plus"
    max_workers: int = 1
    upscale: UpscaleConfig = field(default_factory=UpscaleConfig)
    webp: WebpConfig = field(default_factory=WebpConfig)

    IMAGE_EXTENSIONS: List[str] = field(default_factory=lambda: [
        ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif"
    ])

    def save(self):
        CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        data = {
            "input_dir": self.input_dir,
            "output_dir": self.output_dir,
            "model_name": self.model_name,
            "max_workers": self.max_workers,
            "upscale": asdict(self.upscale),
            "webp": asdict(self.webp),
        }
        CONFIG_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2))

    @classmethod
    def load(cls) -> "AppConfig":
        cfg = cls()
        if not CONFIG_FILE.exists():
            return cfg
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            cfg.input_dir = data.get("input_dir", cfg.input_dir)
            cfg.output_dir = data.get("output_dir", cfg.output_dir)
            cfg.model_name = data.get("model_name", cfg.model_name)
            cfg.max_workers = data.get("max_workers", cfg.max_workers)
            if "upscale" in data:
                for k, v in data["upscale"].items():
                    if hasattr(cfg.upscale, k):
                        setattr(cfg.upscale, k, v)
            if "webp" in data:
                for k, v in data["webp"].items():
                    if hasattr(cfg.webp, k):
                        setattr(cfg.webp, k, v)
        except Exception as e:
            import traceback
            traceback.print_exc()
        return cfg
