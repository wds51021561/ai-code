import subprocess
import sys
from pathlib import Path
import shutil


def find_pyside6_dir():
    import PySide6
    return Path(PySide6.__file__).parent


def main():
    base = Path(__file__).resolve().parent

    print("=" * 50)
    print("  超分转 WebP 工具 - Nuitka 打包脚本")
    print("=" * 50)

    # 清理旧构建
    for d in [base / "dist", base / "main.build", base / "main.dist"]:
        if d.exists():
            print(f"清理 {d.name}/...")
            try:
                shutil.rmtree(d)
            except PermissionError:
                print(f"  跳过（文件被占用）")

    pyside6_dir = find_pyside6_dir()
    plugins_src = pyside6_dir / "plugins"
    models_src = base / "models"

    print(f"PySide6: {pyside6_dir}")
    print(f"Models:  {models_src}")

    # ── 图标转换：assets/icon.png → assets/icon.ico ──
    icon_png = base / "assets" / "icon.png"
    icon_ico = base / "assets" / "icon.ico"
    if icon_png.exists():
        try:
            from PIL import Image
            img = Image.open(icon_png).convert("RGBA")
            icon_ico.parent.mkdir(parents=True, exist_ok=True)
            img.save(str(icon_ico), format="ICO",
                      sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
            print(f"图标已生成: {icon_ico} ({icon_ico.stat().st_size // 1024} KB)")
        except Exception as e:
            print(f"图标转换失败（跳过）: {e}")
            icon_ico = None
    else:
        icon_ico = None

    has_icon = icon_ico is not None and icon_ico.exists()
    if has_icon:
        print(f"图标: {icon_ico}")

    # 构建 Nuitka 命令（不打包 models，编译后手动复制）
    cmd = [
        sys.executable, "-m", "nuitka",
        "--standalone",
        "--enable-plugin=pyside6",
        "--windows-console-mode=disable",
        "--output-filename=UpscaleWebP",
        "--assume-yes-for-downloads",
        "--include-package=core",
        "--include-package=ui",
    ]

    if has_icon:
        cmd.append(f"--windows-icon-from-ico={icon_ico}")

    cmd.append(str(base / "main.py"))

    print()
    print("编译中（首次约5-10分钟）...")
    result = subprocess.run(cmd, cwd=str(base))

    if result.returncode != 0:
        print("\n编译失败！")
        return 1

    app_dir = base / "main.dist"
    if not app_dir.exists():
        print(f"输出目录不存在: {app_dir}")
        return 1

    # ── 手动复制 models ──
    dst_models = app_dir / "models"
    print(f"\n复制 models 到 {dst_models}...")
    if dst_models.exists():
        shutil.rmtree(dst_models)
    shutil.copytree(models_src, dst_models)

    # ncnn-vulkan 需要模型文件在 models/models/ 子目录下
    # 检查源 models/ 下是否有直接散落的 .param/.bin 文件
    src_root = models_src
    dst_nn = dst_models / "models"
    loose_files = list(src_root.glob("*.param")) + list(src_root.glob("*.bin"))
    if loose_files:
        dst_nn.mkdir(exist_ok=True)
        for f in loose_files:
            shutil.copy2(f, dst_nn / f.name)
            print(f"  移动 {f.name} -> models/models/")

    # 验证关键文件
    exe1 = dst_models / "realesrgan-ncnn-vulkan.exe"
    exe2 = dst_models / "cwebp.exe"
    exe3 = dst_models / "waifu2x" / "waifu2x-ncnn-vulkan.exe"
    nn = dst_models / "models"
    anime_sharp = nn / "4x-AnimeSharp-fp16.bin"
    print(f"  realesrgan-ncnn-vulkan.exe: {'OK' if exe1.exists() else 'MISSING'}")
    print(f"  cwebp.exe: {'OK' if exe2.exists() else 'MISSING'}")
    print(f"  waifu2x-ncnn-vulkan.exe: {'OK' if exe3.exists() else 'MISSING'}")
    print(f"  4x-AnimeSharp-fp16.bin: {'OK' if anime_sharp.exists() else 'MISSING'}")
    print(f"  models/models/: {'OK' if nn.exists() else 'MISSING'}")

    # ── Qt 平台插件（pyside6 插件可能已自动处理，缺失则手动补） ──
    dst_platforms = app_dir / "platforms"
    if not dst_platforms.exists() and plugins_src.exists():
        src_platforms = plugins_src / "platforms"
        if src_platforms.exists():
            print(f"复制 Qt 平台插件到 {dst_platforms}...")
            shutil.copytree(src_platforms, dst_platforms)

    print(f"\n输出目录: {app_dir}")
    print(f"可执行文件: {app_dir / 'UpscaleWebP.exe'}")
    print("\n打包完成！")
    return 0


if __name__ == "__main__":
    sys.exit(main())
