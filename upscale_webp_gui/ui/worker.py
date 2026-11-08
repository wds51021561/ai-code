from PySide6.QtCore import QObject, Signal, Slot

from core.cbz import pack_directory
from core.config import AppConfig
from core.processor import process
from core.models.realesrgan import RealESRGAN
from core.converters.webp import ensure_cwebp


class DownloadWorker(QObject):
    progress = Signal(int, str)
    finished = Signal(str, str)
    error = Signal(str)

    @Slot()
    def run(self):
        try:
            def cb(pct, msg):
                self.progress.emit(pct, msg)

            exe_path = RealESRGAN.ensure_downloaded(progress_callback=cb)
            if not exe_path:
                self.error.emit("下载失败：无法找到超分引擎可执行文件")
                return

            cwebp_path = ensure_cwebp(progress_callback=cb)
            if not cwebp_path:
                self.error.emit("下载失败：无法找到 cwebp")
                return

            self.finished.emit("success", f"{exe_path}\n{cwebp_path}")
        except Exception as e:
            self.error.emit(f"下载失败: {e}")


class PackWorker(QObject):
    log = Signal(str)
    finished = Signal(list)
    error = Signal(str)

    def __init__(self, dir_path: str, remove_source: bool):
        super().__init__()
        self.dir_path = dir_path
        self.remove_source = remove_source
        self._cancel = [False]

    def cancel(self):
        self._cancel[0] = True

    @Slot()
    def run(self):
        try:
            created = pack_directory(
                self.dir_path,
                remove_source=self.remove_source,
                log_callback=lambda msg: self.log.emit(msg),
                cancel_flag=self._cancel,
            )
            self.finished.emit(created)
        except Exception as e:
            self.error.emit(f"打包错误: {e}")


class ProcessWorker(QObject):
    progress = Signal(int, int, str)
    log = Signal(str)
    finished = Signal()
    error = Signal(str)

    def __init__(self, config: AppConfig):
        super().__init__()
        self.config = config
        self._cancel = [False]
        self._current_proc = [[]]

    def cancel(self):
        self._cancel[0] = True
        for proc in list(self._current_proc[0]):
            try:
                proc.kill()
            except Exception:
                pass

    @Slot()
    def run(self):
        try:
            self.log.emit("开始处理...")
            process(
                self.config,
                progress_callback=lambda cur, total, name:
                    self.progress.emit(cur, total, name),
                log_callback=lambda msg: self.log.emit(msg),
                cancel_flag=self._cancel,
                current_proc=self._current_proc,
            )
            if not self._cancel[0]:
                self.log.emit("处理完成")
            self.finished.emit()
        except Exception as e:
            self.error.emit(f"处理错误: {e}")
