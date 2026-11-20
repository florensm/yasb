from PyQt6.QtCore import QObject, pyqtSignal

from core.events.win32 import WinEvent
from core.utils.win32.event_listener import win_event


class ForegroundWatch(QObject):
    """Tells QML when a window of another program comes to the front, such as after a click on it. Windows often
    keeps a popup opened from the bar from taking the focus, and a popup that never had it is never told it lost it,
    so popups close on this too. YASB's own windows are left out: the shared hook skips its own process."""

    activated = pyqtSignal()

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        win_event(WinEvent.EventSystemForeground).connect(self._on_foreground)

    def _on_foreground(self, _hwnd: int, _event: WinEvent) -> None:
        self.activated.emit()
