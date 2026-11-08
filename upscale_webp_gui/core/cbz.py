"""按 cbz.py 的规则，将目录中的文件夹打包为 .cbz。

规则：
- 目录下没有子文件夹：整个目录打包为同名的 .cbz；
- 目录下只有 1 个子文件夹：把子文件夹的内容打包为同名的 .cbz；
- 目录下有多个子文件夹：每个子文件夹分别打包为同名的 .cbz。

打包成功后可选择是否删除原始文件夹。
"""

import os
import shutil
import zipfile
from typing import Callable, List, Optional

LogCallback = Optional[Callable[[str], None]]
CancelFlag = Optional[list]


class _Cancelled(Exception):
    pass


def _log(callback: LogCallback, msg: str) -> None:
    if callback:
        callback(msg)


def _subdirs(path: str) -> List[str]:
    try:
        names = sorted(os.listdir(path))
    except OSError:
        return []
    return [
        os.path.join(path, name)
        for name in names
        if os.path.isdir(os.path.join(path, name))
    ]


def _has_files(path: str) -> bool:
    for _root, _dirs, files in os.walk(path):
        if files:
            return True
    return False


def zip_folder(folder_path: str, zip_base: str,
               remove_source: bool = True,
               log_callback: LogCallback = None,
               cancel_flag: CancelFlag = None) -> Optional[str]:
    """将 folder_path 的内容打包为 zip_base + ".cbz"。

    remove_source 为 True 时，打包成功后删除 folder_path。
    取消或失败时不会删除源文件夹。
    """
    folder_path = os.path.abspath(folder_path)
    zip_path = os.path.abspath(zip_base + ".cbz")
    tmp_path = zip_path + ".part"

    if not os.path.isdir(folder_path):
        raise NotADirectoryError(folder_path)

    _log(log_callback, f"打包: {folder_path} -> {zip_path}")

    file_count = 0
    try:
        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(folder_path):
                dirs.sort()
                for name in sorted(files):
                    if cancel_flag and cancel_flag[0]:
                        raise _Cancelled

                    file_path = os.path.join(root, name)
                    # 避免把临时压缩包本身打进压缩包
                    if os.path.abspath(file_path) == tmp_path:
                        continue

                    arcname = os.path.relpath(file_path, folder_path)
                    zipf.write(file_path, arcname)
                    file_count += 1
    except _Cancelled:
        _safe_remove(tmp_path)
        _log(log_callback, "打包已取消")
        return None
    except Exception:
        _safe_remove(tmp_path)
        raise

    os.replace(tmp_path, zip_path)
    _log(log_callback, f"已生成: {zip_path} ({file_count} 个文件)")

    if remove_source:
        try:
            shutil.rmtree(folder_path)
            _log(log_callback, f"已删除原文件夹: {folder_path}")
        except OSError as e:
            _log(log_callback, f"警告: 删除原文件夹失败: {folder_path} ({e})")

    return zip_path


def _safe_remove(path: str) -> None:
    try:
        if os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


def _pack_child(dir_path: str, remove_source: bool,
                log_callback: LogCallback,
                cancel_flag: CancelFlag) -> List[str]:
    """对应 cbz.py 中的 pro_dir()。"""
    subdirs = _subdirs(dir_path)
    created: List[str] = []

    if not subdirs:
        if not _has_files(dir_path):
            _log(log_callback, f"空目录，跳过: {dir_path}")
            return created
        out = zip_folder(dir_path, dir_path, remove_source,
                         log_callback, cancel_flag)
        if out:
            created.append(out)
        return created

    if len(subdirs) == 1:
        only = subdirs[0]
        loose_files = [
            name for name in os.listdir(dir_path)
            if os.path.isfile(os.path.join(dir_path, name))
        ]
        if not loose_files and not _has_files(only):
            _log(log_callback, f"空目录，跳过: {dir_path}")
            return created
        if loose_files:
            # 原脚本会连同散图一起删除，这里改为整体打包，避免丢文件
            _log(log_callback,
                 f"该目录只有 1 个子目录但还有 {len(loose_files)} 个散图，"
                 f"将整体打包: {dir_path}")
            out = zip_folder(dir_path, dir_path, remove_source,
                             log_callback, cancel_flag)
            if out:
                created.append(out)
        else:
            out = zip_folder(only, dir_path, remove_source,
                             log_callback, cancel_flag)
            if out:
                created.append(out)
                if remove_source:
                    try:
                        os.rmdir(dir_path)
                    except OSError as e:
                        _log(log_callback,
                             f"警告: 删除空文件夹失败: {dir_path} ({e})")
        return created

    for sub in subdirs:
        if cancel_flag and cancel_flag[0]:
            _log(log_callback, "打包已取消")
            return created
        if not _has_files(sub):
            _log(log_callback, f"空目录，跳过: {sub}")
            continue
        out = zip_folder(sub, sub, remove_source, log_callback, cancel_flag)
        if out:
            created.append(out)
    return created


def pack_directory(dir_path: str, remove_source: bool = True,
                   log_callback: LogCallback = None,
                   cancel_flag: CancelFlag = None) -> List[str]:
    """对应 cbz.py 中的 for_dir()，返回生成的 .cbz 路径列表。"""
    dir_path = os.path.abspath(dir_path)
    if not os.path.isdir(dir_path):
        raise NotADirectoryError(dir_path)

    subdirs = _subdirs(dir_path)
    created: List[str] = []

    if not subdirs:
        if not _has_files(dir_path):
            _log(log_callback, f"空目录，跳过: {dir_path}")
            return created
        out = zip_folder(dir_path, dir_path, remove_source,
                         log_callback, cancel_flag)
        if out:
            created.append(out)
        return created

    for sub in subdirs:
        if cancel_flag and cancel_flag[0]:
            _log(log_callback, "打包已取消")
            break
        created.extend(_pack_child(sub, remove_source,
                                   log_callback, cancel_flag))

    loose_files = [
        name for name in os.listdir(dir_path)
        if os.path.isfile(os.path.join(dir_path, name))
    ]
    if loose_files:
        _log(log_callback,
             f"注意: 根目录下的 {len(loose_files)} 个文件未打包（与 cbz.py 一致）")

    return created
