from abc import ABC, abstractmethod
from typing import Optional


class BaseModel(ABC):
    @abstractmethod
    def process_image(self, input_path: str, output_path: str,
                      scale: int, **kwargs) -> None:
        ...

    @abstractmethod
    def name(self) -> str:
        ...

    @staticmethod
    def ensure_downloaded(progress_callback=None) -> Optional[str]:
        ...


_model_registry: dict = {}


def register_model(cls):
    _model_registry[cls.name()] = cls
    return cls


def get_model(model_name: str) -> BaseModel:
    cls = _model_registry.get(model_name)
    if cls is None:
        raise ValueError(f"Unknown model: {model_name}, available: {list(_model_registry.keys())}")
    return cls()


def list_models() -> list:
    return list(_model_registry.keys())
