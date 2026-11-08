import os
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Callable, Optional

from .config import AppConfig
from .models.catalog import ensure_model_ready, get_engine
from .converters.webp import convert_with_cwebp


def collect_images(input_dir: str, extensions: list) -> list:
    result = []
    for root, _dirs, files in os.walk(input_dir):
        for f in sorted(files):
            ext = os.path.splitext(f)[1].lower()
            if ext in extensions:
                full_path = os.path.join(root, f)
                rel_path = os.path.relpath(full_path, input_dir)
                result.append((full_path, rel_path))
    return result


def _process_one(src_path: str, dst_path: str, rel_path: str,
                 config: AppConfig, tmp_dir: str, idx: int, total: int,
                 cancel_flag: list, procs: list,
                 log_callback: Optional[Callable] = None) -> None:
    if cancel_flag[0]:
        return

    if log_callback:
        log_callback(f"[{idx+1}/{total}] 超分: {rel_path}")

    model = get_engine(config.model_name)
    temp_png = os.path.join(tmp_dir, f"{idx}.png")
    model.process_image(
        src_path, temp_png,
        scale=config.upscale.scale,
        model_key=config.model_name,
        tile_size=config.upscale.tile_size,
        tta=config.upscale.tta,
        gpu_id=config.upscale.gpu_id,
        current_proc=procs,
    )

    if cancel_flag[0]:
        return

    webp_name = Path(rel_path).with_suffix(".webp").name
    if log_callback:
        log_callback(f"[{idx+1}/{total}] 转码 WebP: {webp_name}")

    convert_with_cwebp(temp_png, dst_path, config.webp,
                       current_proc=procs)


def process(config: AppConfig,
            progress_callback: Optional[Callable] = None,
            log_callback: Optional[Callable] = None,
            cancel_flag: Optional[list] = None,
            current_proc: Optional[list] = None) -> None:

    if cancel_flag is None:
        cancel_flag = [False]

    image_list = collect_images(config.input_dir, config.IMAGE_EXTENSIONS)
    total = len(image_list)

    if total == 0:
        if log_callback:
            log_callback("未找到任何图片文件")
        return

    if log_callback:
        log_callback(f"检查模型: {config.model_name}")

    last_dl_pct = [-1]

    def _download_log(pct: int, msg: str):
        if not log_callback:
            return
        # 下载进度只每 10% 记一行，避免刷爆日志
        if "%" in msg:
            if pct - last_dl_pct[0] < 10 and pct < 100:
                return
            last_dl_pct[0] = pct
        else:
            # 新文件开始/切换下载源时重置进度
            last_dl_pct[0] = -1
        log_callback(msg)

    ready = ensure_model_ready(config.model_name, progress_callback=_download_log)
    if not ready:
        raise RuntimeError(f"模型未就绪: {config.model_name}")

    worker_count = max(1, config.max_workers)
    if log_callback:
        log_callback(f"共 {total} 张图片，使用 {worker_count} 个线程")

    with tempfile.TemporaryDirectory(prefix="upscale_webp_") as tmp_dir:
        with ThreadPoolExecutor(max_workers=worker_count) as executor:
            futures = {}
            for idx, (src_path, rel_path) in enumerate(image_list):
                if cancel_flag[0]:
                    break

                out_rel = Path(rel_path).with_suffix(".webp")
                dst_path = os.path.join(config.output_dir, out_rel)
                os.makedirs(os.path.dirname(dst_path), exist_ok=True)

                future = executor.submit(
                    _process_one, src_path, dst_path, rel_path,
                    config, tmp_dir, idx, total,
                    cancel_flag, current_proc, log_callback,
                )
                futures[future] = (idx, rel_path)

            for future in as_completed(futures):
                if cancel_flag[0]:
                    for f in futures:
                        if not f.done():
                            f.cancel()
                    if log_callback:
                        log_callback("用户取消")
                    break

                idx, rel_path = futures[future]
                try:
                    future.result()
                    if progress_callback:
                        progress_callback(idx + 1, total, rel_path)
                except Exception as e:
                    if log_callback:
                        log_callback(f"[{idx+1}/{total}] 失败: {rel_path} - {e}")
                    if progress_callback:
                        progress_callback(idx + 1, total, rel_path)