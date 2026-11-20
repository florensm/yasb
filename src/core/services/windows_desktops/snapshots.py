"""Pictures of each virtual desktop for the desktop overview.

Windows draws nothing for a desktop that is not in view: its windows are cloaked, so neither a screen grab nor
DWM thumbnails show them. Each desktop's picture is therefore the screen as it last looked while that desktop
was in view, taken on request and kept in memory only, until YASB exits.
"""

import threading
from urllib.parse import quote, unquote

from PyQt6.QtCore import QObject, QPoint, QSize, Qt, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QImage
from PyQt6.QtQuick import QQuickImageProvider

from core.utils.qml import qml_property

DESKTOP_SNAPSHOT_PROVIDER = "desktop-snapshot"

# The widest picture kept, in pixels; enough for a card filling a 4K screen to stay sharp when zoomed in
MAX_WIDTH = 1920

_lock = threading.Lock()
# (screen name, desktop number) -> picture
_snapshots: dict[tuple[str, int], QImage] = {}


class _Revision(QObject):
    """One counter for every DesktopSnapshots, so a picture taken by one widget reaches the others."""

    changed = pyqtSignal()

    def __init__(self) -> None:
        super().__init__()
        self.value = 0

    def bump(self) -> None:
        self.value += 1
        self.changed.emit()


_revision: _Revision | None = None


def _shared_revision() -> _Revision:
    global _revision
    if _revision is None:
        _revision = _Revision()
    return _revision


class DesktopSnapshots(QObject):
    """Takes and hands out the last picture of each virtual desktop on each screen."""

    revisionChanged = pyqtSignal()

    def __init__(self, parent: QObject | None = None):
        super().__init__(parent)
        _shared_revision().changed.connect(self.revisionChanged)

    # Goes up whenever any picture changes; pass it to url() so bindings fetch the new picture
    @qml_property(int, notify=revisionChanged)
    def revision(self) -> int:
        return _shared_revision().value

    @pyqtSlot(int, int, int, result=bool)
    def capture(self, number: int, x: int, y: int) -> bool:
        """Takes the picture of desktop number, which must be the one in view, on the screen at x, y."""
        screen = QGuiApplication.screenAt(QPoint(x, y))
        if screen is None or number <= 0:
            return False
        image = screen.grabWindow(0).toImage()
        if image.isNull():
            return False
        if image.width() > MAX_WIDTH:
            image = image.scaledToWidth(MAX_WIDTH, Qt.TransformationMode.SmoothTransformation)
        with _lock:
            _snapshots[(screen.name(), number)] = image
        _shared_revision().bump()
        return True

    @pyqtSlot(int, int, int, result=bool)
    def has(self, number: int, x: int, y: int) -> bool:
        screen = QGuiApplication.screenAt(QPoint(x, y))
        with _lock:
            return screen is not None and (screen.name(), number) in _snapshots

    @pyqtSlot(int, int, int, int, result=str)
    def url(self, number: int, x: int, y: int, revision: int) -> str:
        """The picture of desktop number on the screen at x, y, or "" when there is none yet."""
        screen = QGuiApplication.screenAt(QPoint(x, y))
        if screen is None:
            return ""
        with _lock:
            if (screen.name(), number) not in _snapshots:
                return ""
        return f"image://{DESKTOP_SNAPSHOT_PROVIDER}/{quote(screen.name(), safe='')}/{number}/{revision}"

    @pyqtSlot()
    def forget(self) -> None:
        """Drops every picture, for when desktops are reordered or deleted."""
        with _lock:
            _snapshots.clear()
        _shared_revision().bump()


class DesktopSnapshotProvider(QQuickImageProvider):
    def __init__(self) -> None:
        super().__init__(QQuickImageProvider.ImageType.Image)

    def requestImage(self, id: str | None, requestedSize: QSize) -> tuple[QImage, QSize]:
        image = QImage()
        parts = (id or "").split("/")
        if len(parts) >= 2 and parts[1].isdigit():
            with _lock:
                image = _snapshots.get((unquote(parts[0]), int(parts[1])), QImage())
        original = image.size()
        if not image.isNull() and (requestedSize.width() > 0 or requestedSize.height() > 0):
            width = requestedSize.width() if requestedSize.width() > 0 else image.width()
            height = requestedSize.height() if requestedSize.height() > 0 else image.height()
            image = image.scaled(
                width, height, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation
            )
        return image, original
