import os
from pathlib import Path

from PySide6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QGroupBox,
    QLabel, QLineEdit, QPushButton, QComboBox, QSlider,
    QSpinBox, QCheckBox, QProgressBar, QTextEdit, QFileDialog,
    QMessageBox, QDialog, QProgressBar as QProgBarDlg,
    QVBoxLayout as VBoxDlg,
)
from PySide6.QtCore import Qt, QThread, Slot
from PySide6.QtGui import QFont

from core.config import AppConfig, WebpConfig, UpscaleConfig
from core.models.catalog import (
    list_model_choices, model_hint, supported_scales_for_key,
)
from .worker import DownloadWorker, PackWorker, ProcessWorker


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.config = AppConfig.load()
        self.process_thread = None
        self.process_worker = None
        self.pack_thread = None
        self.pack_worker = None
        self.download_thread = None
        self.download_worker = None
        self._setup_ui()
        self._apply_config()
        self._check_download()

    def _setup_ui(self):
        self.setWindowTitle("超分转 WebP 工具")
        self.resize(1200, 640)

        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setSpacing(12)

        left = QVBoxLayout()
        left.setSpacing(12)
        right = QVBoxLayout()
        right.setSpacing(12)

        main_layout.addLayout(left, 1)
        main_layout.addLayout(right, 1)

        # ── 输入/输出 ──
        grp = QGroupBox("输入 / 输出")
        gl = QVBoxLayout(grp)
        self._inp_edit = QLineEdit()
        self._inp_edit.setPlaceholderText("选择输入目录...")
        self._out_edit = QLineEdit()
        self._out_edit.setPlaceholderText("选择输出目录...")
        btn_inp = QPushButton("浏览")
        btn_out = QPushButton("浏览")
        btn_inp.clicked.connect(self._browse_input)
        btn_out.clicked.connect(self._browse_output)

        h = QHBoxLayout()
        h.addWidget(QLabel("输入目录"))
        h.addWidget(self._inp_edit)
        h.addWidget(btn_inp)
        gl.addLayout(h)

        h = QHBoxLayout()
        h.addWidget(QLabel("输出目录"))
        h.addWidget(self._out_edit)
        h.addWidget(btn_out)
        gl.addLayout(h)
        left.addWidget(grp)

        # ── 超分模型 ──
        grp = QGroupBox("超分模型")
        gl = QVBoxLayout(grp)

        self._model_combo = QComboBox()
        for key, label in list_model_choices():
            self._model_combo.addItem(label, key)
        idx = self._model_combo.findData("realesrgan-x4plus")
        if idx >= 0:
            self._model_combo.setCurrentIndex(idx)
        self._model_combo.currentIndexChanged.connect(self._rebuild_scales)
        self._model_combo.currentIndexChanged.connect(self._update_model_hint)

        h = QHBoxLayout()
        h.addWidget(QLabel("模型"))
        h.addWidget(self._model_combo, 1)
        gl.addLayout(h)

        self._model_hint = QLabel("")
        self._model_hint.setWordWrap(True)
        self._model_hint.setStyleSheet("color: #666;")
        gl.addWidget(self._model_hint)
        self._update_model_hint()

        self._scale_combo = QComboBox()
        self._rebuild_scales()

        h = QHBoxLayout()
        h.addWidget(QLabel("放大倍数"))
        h.addWidget(self._scale_combo)
        h.addStretch()
        gl.addLayout(h)

        h = QHBoxLayout()
        h.addWidget(QLabel("分块大小"))
        self._tile_size_spin = QSpinBox()
        self._tile_size_spin.setRange(0, 4096)
        self._tile_size_spin.setValue(0)
        self._tile_size_spin.setSuffix(" (0=自动)")
        self._tile_size_spin.setToolTip("增大分块可减轻格纹，但消耗更多显存")
        self._tile_size_lbl = QLabel("0=自动")
        h.addWidget(self._tile_size_spin)
        h.addStretch()
        gl.addLayout(h)

        self._tta_cb = QCheckBox("TTA 模式 (慢但可减轻格纹)")
        self._tta_cb.setToolTip("测试时增强，通过多方向推理平均来消除接缝")
        gl.addWidget(self._tta_cb)

        h = QHBoxLayout()
        h.addWidget(QLabel("线程数"))
        self._workers_spin = QSpinBox()
        self._workers_spin.setRange(1, 16)
        self._workers_spin.setValue(1)
        self._workers_spin.setToolTip("多线程并行处理图片，GPU 显存不足时请保持 1")
        h.addWidget(self._workers_spin)
        h.addStretch()
        gl.addLayout(h)

        left.addWidget(grp)

        # ── WebP 配置 ──
        grp = QGroupBox("WebP 转码配置")
        gl = QVBoxLayout(grp)

        h = QHBoxLayout()
        h.addWidget(QLabel("品质"))
        self._quality_slider = QSlider(Qt.Horizontal)
        self._quality_slider.setRange(0, 100)
        self._quality_slider.setValue(80)
        self._quality_spin = QSpinBox()
        self._quality_spin.setRange(0, 100)
        self._quality_spin.setValue(80)
        self._quality_slider.valueChanged.connect(self._quality_spin.setValue)
        self._quality_spin.valueChanged.connect(self._quality_slider.setValue)
        h.addWidget(self._quality_slider, 1)
        h.addWidget(self._quality_spin)
        gl.addLayout(h)

        self._lossless_cb = QCheckBox("无损模式")
        gl.addWidget(self._lossless_cb)

        h = QHBoxLayout()
        h.addWidget(QLabel("编码方法"))
        self._method_combo = QComboBox()
        for m in range(7):
            label = f"{m} ({['最快','','','','默认','','最小体积'][m]})"
            self._method_combo.addItem(label, m)
        self._method_combo.setCurrentIndex(4)
        h.addWidget(self._method_combo)
        h.addStretch()
        gl.addLayout(h)

        h = QHBoxLayout()
        h.addWidget(QLabel("Alpha 品质"))
        self._alpha_spin = QSpinBox()
        self._alpha_spin.setRange(0, 100)
        self._alpha_spin.setValue(100)
        h.addWidget(self._alpha_spin)
        h.addStretch()
        gl.addLayout(h)
        h = QHBoxLayout()
        h.addWidget(QLabel("滤镜强度"))
        self._filter_str_slider = QSlider(Qt.Horizontal)
        self._filter_str_slider.setRange(0, 100)
        self._filter_str_slider.setValue(0)
        self._filter_str_spin = QSpinBox()
        self._filter_str_spin.setRange(0, 100)
        self._filter_str_spin.setValue(0)
        self._filter_str_slider.valueChanged.connect(self._filter_str_spin.setValue)
        self._filter_str_spin.valueChanged.connect(self._filter_str_slider.setValue)
        h.addWidget(self._filter_str_slider, 1)
        h.addWidget(self._filter_str_spin)
        gl.addLayout(h)

        h = QHBoxLayout()
        h.addWidget(QLabel("滤镜锐度"))
        self._filter_sharp_combo = QComboBox()
        for s in range(8):
            label = f"{s} ({['最锐利','','','','','','','最柔和'][s]})"
            self._filter_sharp_combo.addItem(label, s)
        self._filter_sharp_combo.setCurrentIndex(0)
        h.addWidget(self._filter_sharp_combo)
        h.addStretch()
        gl.addLayout(h)

        self._sharp_yuv_cb = QCheckBox("使用锐利 RGB→YUV 转换")
        self._sharp_yuv_cb.setChecked(True)
        gl.addWidget(self._sharp_yuv_cb)

        h = QHBoxLayout()
        h.addWidget(QLabel("文件大小(KB)"))
        self._target_size_spin = QSpinBox()
        self._target_size_spin.setRange(0, 999999)
        self._target_size_spin.setValue(0)
        self._target_size_spin.setSuffix(" (0=不限)")
        h.addWidget(self._target_size_spin)
        h.addStretch()
        gl.addLayout(h)

        left.addWidget(grp)

        # ── 进度 ──
        grp = QGroupBox("进度")
        gl = QVBoxLayout(grp)
        self._progress_bar = QProgressBar()
        self._progress_bar.setValue(0)
        gl.addWidget(self._progress_bar)

        self._status_label = QLabel("就绪")
        gl.addWidget(self._status_label)

        left.addWidget(grp)

        # ── 按钮 ──
        btn_layout = QHBoxLayout()
        self._start_btn = QPushButton("开始处理")
        self._start_btn.clicked.connect(self._start_process)
        self._start_btn.setMinimumHeight(36)
        self._stop_btn = QPushButton("停止")
        self._stop_btn.clicked.connect(self._stop_process)
        self._stop_btn.setMinimumHeight(36)
        self._stop_btn.setVisible(False)
        self._pack_btn = QPushButton("打包 CBZ")
        self._pack_btn.clicked.connect(self._start_pack)
        self._pack_btn.setMinimumHeight(36)
        self._pack_btn.setToolTip("按 cbz.py 规则将文件夹打包为 .cbz")
        btn_layout.addWidget(self._start_btn)
        btn_layout.addWidget(self._stop_btn)
        btn_layout.addWidget(self._pack_btn)
        left.addLayout(btn_layout)

        # ── 右侧日志 ──
        log_grp = QGroupBox("日志")
        log_layout = QVBoxLayout(log_grp)
        self._log_box = QTextEdit()
        self._log_box.setReadOnly(True)
        font = QFont("Consolas", 9)
        self._log_box.setFont(font)
        log_layout.addWidget(self._log_box)
        right.addWidget(log_grp)

        # ── 实时保存 ──
        self._inp_edit.editingFinished.connect(self._autosave)
        self._out_edit.editingFinished.connect(self._autosave)
        self._model_combo.currentIndexChanged.connect(self._autosave)
        self._scale_combo.currentIndexChanged.connect(self._autosave)
        self._tile_size_spin.valueChanged.connect(self._autosave)
        self._tta_cb.toggled.connect(self._autosave)
        self._quality_spin.valueChanged.connect(self._autosave)
        self._lossless_cb.toggled.connect(self._autosave)
        self._method_combo.currentIndexChanged.connect(self._autosave)
        self._alpha_spin.valueChanged.connect(self._autosave)
        self._filter_str_spin.valueChanged.connect(self._autosave)
        self._filter_sharp_combo.currentIndexChanged.connect(self._autosave)
        self._sharp_yuv_cb.toggled.connect(self._autosave)
        self._target_size_spin.valueChanged.connect(self._autosave)
        self._workers_spin.valueChanged.connect(self._autosave)

    def _browse_input(self):
        d = QFileDialog.getExistingDirectory(self, "选择输入目录")
        if d:
            self._inp_edit.setText(d)
            self._autosave()

    def _browse_output(self):
        d = QFileDialog.getExistingDirectory(self, "选择输出目录")
        if d:
            self._out_edit.setText(d)
            self._autosave()

    def _check_download(self):
        from utils import get_models_dir
        base = get_models_dir()
        exe = base / "realesrgan-ncnn-vulkan.exe"
        cwebp = base / "cwebp.exe"
        if exe.exists() and cwebp.exists():
            return

        self._start_btn.setEnabled(False)
        self._pack_btn.setEnabled(False)
        self._log("首次使用需要下载所需工具...")

        self.download_thread = QThread()
        self.download_worker = DownloadWorker()
        self.download_worker.moveToThread(self.download_thread)
        self.download_thread.started.connect(self.download_worker.run)
        self.download_worker.progress.connect(self._download_progress)
        self.download_worker.finished.connect(self._download_done)
        self.download_worker.error.connect(self._download_error)
        self.download_worker.finished.connect(self.download_thread.quit)
        self.download_worker.error.connect(self.download_thread.quit)
        self.download_thread.finished.connect(self.download_worker.deleteLater)
        self.download_thread.start()

    def _download_progress(self, pct: int, msg: str):
        self._status_label.setText(msg)
        if pct > 0:
            self._progress_bar.setValue(pct)

    def _download_done(self, status: str, path: str):
        self._log(f"引擎下载完成: {path}")
        self._status_label.setText("就绪")
        self._progress_bar.setValue(100)
        self._start_btn.setEnabled(True)
        self._pack_btn.setEnabled(True)

    def _download_error(self, msg: str):
        self._log(f"下载失败: {msg}")
        self._status_label.setText("下载失败")
        QMessageBox.warning(self, "下载失败",
                            f"引擎自动下载失败，请手动下载后放入 models/ 目录:\n"
                            f"https://github.com/xinntao/Real-ESRGAN/releases\n\n{msg}")
        self._start_btn.setEnabled(True)
        self._pack_btn.setEnabled(True)

    def _start_process(self):
        if self.pack_thread and self.pack_thread.isRunning():
            QMessageBox.warning(self, "提示", "正在打包，请等待打包完成")
            return

        inp = self._inp_edit.text().strip()
        out = self._out_edit.text().strip()

        if not inp or not os.path.isdir(inp):
            QMessageBox.warning(self, "提示", "请选择有效的输入目录")
            return
        if not out:
            QMessageBox.warning(self, "提示", "请选择输出目录")
            return

        self.config.input_dir = inp
        self.config.output_dir = out
        self.config.model_name = self._current_model_key()
        self.config.upscale.scale = self._scale_combo.currentData()
        self.config.upscale.tile_size = self._tile_size_spin.value()
        self.config.upscale.tta = self._tta_cb.isChecked()
        self.config.webp.quality = self._quality_spin.value()
        self.config.webp.lossless = self._lossless_cb.isChecked()
        self.config.webp.method = self._method_combo.currentData()
        self.config.webp.alpha_quality = self._alpha_spin.value()
        self.config.webp.filter_strength = self._filter_str_spin.value()
        self.config.webp.filter_sharpness = self._filter_sharp_combo.currentData()
        self.config.webp.use_sharp_yuv = self._sharp_yuv_cb.isChecked()
        self.config.webp.target_filesize_kb = self._target_size_spin.value()
        self.config.max_workers = self._workers_spin.value()

        self._start_btn.setVisible(False)
        self._pack_btn.setEnabled(False)
        self._stop_btn.setVisible(True)
        self._progress_bar.setValue(0)
        self._log_box.clear()
        self._log("开始处理...")

        self.process_thread = QThread()
        self.process_worker = ProcessWorker(self.config)
        self.process_worker.moveToThread(self.process_thread)
        self.process_thread.started.connect(self.process_worker.run)
        self.process_worker.progress.connect(self._update_progress)
        self.process_worker.log.connect(self._log)
        self.process_worker.finished.connect(self._process_finished)
        self.process_worker.error.connect(self._process_error)
        self.process_worker.finished.connect(self.process_thread.quit)
        self.process_worker.error.connect(self.process_thread.quit)
        self.process_thread.finished.connect(self.process_worker.deleteLater)
        self.process_thread.start()

    def _stop_process(self):
        if self.process_worker:
            self.process_worker.cancel()
        self._log("正在停止...")
        self._stop_btn.setEnabled(False)
        self._stop_btn.setText("停止中...")

    def _start_pack(self):
        if self.process_thread and self.process_thread.isRunning():
            QMessageBox.warning(self, "提示", "正在处理图片，请等待处理完成")
            return
        if self.pack_thread and self.pack_thread.isRunning():
            return

        default_dir = self._out_edit.text().strip()
        if not os.path.isdir(default_dir):
            default_dir = ""

        d = QFileDialog.getExistingDirectory(self, "选择要打包的目录", default_dir)
        if not d:
            return

        box = QMessageBox(self)
        box.setWindowTitle("打包 CBZ")
        box.setIcon(QMessageBox.Question)
        box.setText(
            f"将按 cbz.py 的规则打包目录：\n{d}\n\n"
            "· 没有子文件夹：所选目录打包为同级的 <目录名>.cbz\n"
            "· 只有 1 个子文件夹：子文件夹内容打包为同级的 <目录名>.cbz\n"
            "· 多个子文件夹：每个子文件夹分别打包为各自的 <子目录名>.cbz"
        )
        box.setInformativeText(
            "打包成功后默认会删除原始文件夹。\n"
            "如需保留，请勾选下方选项。"
        )
        keep_cb = QCheckBox("保留原始文件夹（不删除）")
        box.setCheckBox(keep_cb)
        box.setStandardButtons(QMessageBox.Yes | QMessageBox.Cancel)
        box.button(QMessageBox.Yes).setText("开始打包")
        box.button(QMessageBox.Cancel).setText("取消")
        box.setDefaultButton(QMessageBox.Yes)
        if box.exec() != QMessageBox.Yes:
            return

        remove_source = not keep_cb.isChecked()

        self._start_btn.setEnabled(False)
        self._pack_btn.setEnabled(False)
        self._progress_bar.setRange(0, 0)
        self._status_label.setText("正在打包...")
        self._log_box.clear()
        self._log(f"开始打包: {d}")

        self.pack_thread = QThread()
        self.pack_worker = PackWorker(d, remove_source)
        self.pack_worker.moveToThread(self.pack_thread)
        self.pack_thread.started.connect(self.pack_worker.run)
        self.pack_worker.log.connect(self._log)
        self.pack_worker.finished.connect(self._pack_finished)
        self.pack_worker.error.connect(self._pack_error)
        self.pack_worker.finished.connect(self.pack_thread.quit)
        self.pack_worker.error.connect(self.pack_thread.quit)
        self.pack_thread.finished.connect(self.pack_worker.deleteLater)
        self.pack_thread.start()

    def _pack_finished(self, created: list):
        self._progress_bar.setRange(0, 100)
        self._progress_bar.setValue(100)
        self._start_btn.setEnabled(True)
        self._pack_btn.setEnabled(True)

        count = len(created)
        if count == 0:
            self._status_label.setText("打包完成（没有生成文件）")
            self._log("打包完成，但没有生成任何 CBZ 文件")
            return

        self._status_label.setText(f"打包完成（{count} 个 CBZ）")
        self._log(f"打包完成，共生成 {count} 个 CBZ 文件")

        shown = "\n".join(created[:10])
        if count > 10:
            shown += f"\n... 等 {count} 个文件"
        QMessageBox.information(self, "打包完成",
                                f"已生成 {count} 个 CBZ 文件：\n\n{shown}")

    def _pack_error(self, msg: str):
        self._progress_bar.setRange(0, 100)
        self._progress_bar.setValue(0)
        self._start_btn.setEnabled(True)
        self._pack_btn.setEnabled(True)
        self._status_label.setText("打包出错")
        self._log(msg)
        QMessageBox.critical(self, "打包错误", msg)

    def _update_progress(self, cur: int, total: int, name: str):
        self._progress_bar.setMaximum(total)
        self._progress_bar.setValue(cur)
        self._status_label.setText(f"[{cur}/{total}] {name}")

    def _log(self, msg: str):
        self._log_box.append(msg)

    def _reset_buttons(self):
        self._start_btn.setVisible(True)
        self._start_btn.setEnabled(True)
        self._pack_btn.setEnabled(True)
        self._stop_btn.setVisible(False)
        self._stop_btn.setEnabled(True)
        self._stop_btn.setText("停止")

    def _process_finished(self):
        self._reset_buttons()
        self._status_label.setText("处理完成")

    def _process_error(self, msg: str):
        self._reset_buttons()
        self._status_label.setText("处理出错")
        QMessageBox.critical(self, "错误", msg)

    def _autosave(self):
        self._sync_config()
        self.config.save()

    def _sync_config(self):
        self.config.input_dir = self._inp_edit.text().strip()
        self.config.output_dir = self._out_edit.text().strip()
        self.config.model_name = self._current_model_key()
        self.config.upscale.scale = self._scale_combo.currentData()
        self.config.upscale.tile_size = self._tile_size_spin.value()
        self.config.upscale.tta = self._tta_cb.isChecked()
        self.config.webp.quality = self._quality_spin.value()
        self.config.webp.lossless = self._lossless_cb.isChecked()
        self.config.webp.method = self._method_combo.currentData()
        self.config.webp.alpha_quality = self._alpha_spin.value()
        self.config.webp.filter_strength = self._filter_str_spin.value()
        self.config.webp.filter_sharpness = self._filter_sharp_combo.currentData()
        self.config.webp.use_sharp_yuv = self._sharp_yuv_cb.isChecked()
        self.config.webp.target_filesize_kb = self._target_size_spin.value()
        self.config.max_workers = self._workers_spin.value()

    def _apply_config(self):
        for w in [self._inp_edit, self._out_edit, self._model_combo,
                  self._scale_combo, self._tile_size_spin, self._tta_cb,
                  self._workers_spin, self._quality_spin, self._quality_slider,
                  self._lossless_cb, self._method_combo,
                  self._alpha_spin, self._filter_str_spin, self._filter_str_slider,
                  self._filter_sharp_combo, self._sharp_yuv_cb, self._target_size_spin]:
            w.blockSignals(True)

        self._inp_edit.setText(self.config.input_dir)
        self._out_edit.setText(self.config.output_dir)
        idx = self._model_combo.findData(self.config.model_name)
        if idx < 0:
            idx = self._model_combo.findText(self.config.model_name)
        if idx >= 0:
            self._model_combo.setCurrentIndex(idx)
        self._rebuild_scales()
        self._update_model_hint()
        idx = self._scale_combo.findData(self.config.upscale.scale)
        if idx >= 0:
            self._scale_combo.setCurrentIndex(idx)
        self._tile_size_spin.setValue(self.config.upscale.tile_size)
        self._tta_cb.setChecked(self.config.upscale.tta)
        self._quality_spin.setValue(self.config.webp.quality)
        self._quality_slider.setValue(self.config.webp.quality)
        self._lossless_cb.setChecked(self.config.webp.lossless)
        idx = self._method_combo.findData(self.config.webp.method)
        if idx >= 0:
            self._method_combo.setCurrentIndex(idx)
        self._alpha_spin.setValue(self.config.webp.alpha_quality)
        self._filter_str_spin.setValue(self.config.webp.filter_strength)
        self._filter_str_slider.setValue(self.config.webp.filter_strength)
        idx = self._filter_sharp_combo.findData(self.config.webp.filter_sharpness)
        if idx >= 0:
            self._filter_sharp_combo.setCurrentIndex(idx)
        self._sharp_yuv_cb.setChecked(self.config.webp.use_sharp_yuv)
        self._target_size_spin.setValue(self.config.webp.target_filesize_kb)
        self._workers_spin.setValue(self.config.max_workers)

        for w in [self._inp_edit, self._out_edit, self._model_combo,
                  self._scale_combo, self._tile_size_spin, self._tta_cb,
                  self._workers_spin, self._quality_spin, self._quality_slider,
                  self._lossless_cb, self._method_combo,
                  self._alpha_spin, self._filter_str_spin, self._filter_str_slider,
                  self._filter_sharp_combo, self._sharp_yuv_cb, self._target_size_spin]:
            w.blockSignals(False)

    def _current_model_key(self):
        key = self._model_combo.currentData()
        if key:
            return key
        # 兼容旧配置/异常情况
        return self._model_combo.currentText()

    def _update_model_hint(self):
        hint = model_hint(self._current_model_key())
        self._model_hint.setText(hint)
        self._model_combo.setToolTip(hint)

    def _rebuild_scales(self):
        model = self._current_model_key()
        scales = supported_scales_for_key(model)
        current = self._scale_combo.currentData()
        was_blocked = self._scale_combo.blockSignals(True)
        self._scale_combo.clear()
        for s in scales:
            self._scale_combo.addItem(f"{s}x", s)
        idx = self._scale_combo.findData(current)
        if idx < 0:
            idx = 0
        self._scale_combo.setCurrentIndex(idx)
        self._scale_combo.blockSignals(was_blocked)

    def closeEvent(self, event):
        self._autosave()
        if self.process_worker:
            self.process_worker.cancel()
        if self.process_thread and self.process_thread.isRunning():
            self.process_thread.quit()
            self.process_thread.wait(5000)
        if self.pack_worker:
            self.pack_worker.cancel()
        if self.pack_thread and self.pack_thread.isRunning():
            self.pack_thread.quit()
            self.pack_thread.wait(5000)
        event.accept()
