import sys
from pathlib import Path


def get_app_dir() -> Path:
    if getattr(sys, 'frozen', False):
        return Path(sys.executable).parent
    return Path(__file__).resolve().parent


def get_models_dir() -> Path:
    return get_app_dir() / "models"
