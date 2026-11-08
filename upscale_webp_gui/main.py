import sys
import os
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _setup_qt_plugin_path():
    if getattr(sys, 'frozen', False):
        app_dir = Path(sys.executable).parent
        plugin_path = app_dir / "platforms"
        if plugin_path.exists():
            os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = str(plugin_path)


_setup_qt_plugin_path()

from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QIcon
from ui.main_window import MainWindow


def _get_icon_path():
    if getattr(sys, 'frozen', False):
        return Path(sys.executable).parent / "assets" / "icon.ico"
    return Path(__file__).resolve().parent / "assets" / "icon.ico"


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("超分转 WebP")

    icon_path = _get_icon_path()
    if icon_path.exists():
        app.setWindowIcon(QIcon(str(icon_path)))

    w = MainWindow()
    w.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
