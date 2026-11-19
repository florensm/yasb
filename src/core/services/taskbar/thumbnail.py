"""A live picture of another window, drawn by DWM into a QML item's place."""

import logging
import time
from ctypes import byref, wintypes
from typing import Any

from PyQt6 import sip
from PyQt6.QtCore import QObject, QRectF, Qt, pyqtProperty, pyqtSignal
from PyQt6.QtQuick import QQuickItem, QQuickWindow

from core.utils.qml import qml_property
from core.utils.win32.bindings.dwmapi import (
    DwmQueryThumbnailSourceSize,
    DwmRegisterThumbnail,
    DwmUnregisterThumbnail,
    DwmUpdateThumbnailProperties,
)
from core.utils.win32.bindings.user32 import IsWindow
from core.utils.win32.constants import (
    DWM_TNP_OPACITY,
    DWM_TNP_RECTDESTINATION,
    DWM_TNP_RECTSOURCE,
    DWM_TNP_SOURCECLIENTAREAONLY,
    DWM_TNP_VISIBLE,
)
from core.utils.win32.structs import DWM_THUMBNAIL_PROPERTIES, RECT, SIZE

# How often a thumbnail asks DWM again for the size of the window it shows, which can be resized while shown. Not
# every frame: each ask is a round trip to DWM, and the size rarely changes.
SOURCE_SIZE_INTERVAL = 0.5


class _Handle:
    """The DWM thumbnail an item holds, kept apart from the item so it can be released once the item is gone."""

    def __init__(self) -> None:
        self.value = wintypes.HANDLE(0)

    def release(self, *_args: Any) -> None:
        if self.value.value:
            DwmUnregisterThumbnail(self.value)
            self.value = wintypes.HANDLE(0)


class _Placer(QObject):
    """Places the thumbnails of one window, once per frame and in step with it.

    Where each thumbnail goes is worked out as Qt prepares a frame, and handed to DWM once Qt has presented that
    frame. DWM applies a thumbnail's placement at its next composition, the one that also shows the frame Qt just
    presented, so the pictures move together with what QML draws around them. Handed over any earlier, they ran a
    frame ahead of it."""

    _placers: dict[int, _Placer] = {}

    def __init__(self, window: QQuickWindow) -> None:
        super().__init__(window)
        self._window = window
        self._thumbnails: list[WindowThumbnail] = []
        # Placements worked out for the frame Qt is drawing, by the thumbnail's handle
        self._pending: dict[int, tuple[_Handle, DWM_THUMBNAIL_PROPERTIES]] = {}
        # Whether Qt is preparing a frame, which will be presented and so hand the placements over
        self._measuring = False
        window.afterAnimating.connect(self._measure)
        # Emitted on the render thread once the frame is on its way to the screen; handled here, on this thread
        window.frameSwapped.connect(self._apply, Qt.ConnectionType.QueuedConnection)
        key = self._key(window)
        self.destroyed.connect(lambda *_args: _Placer._placers.pop(key, None))

    @staticmethod
    def _key(window: QQuickWindow) -> int:
        return sip.unwrapinstance(window)

    @classmethod
    def of(cls, window: QQuickWindow) -> _Placer:
        """The placer of `window`, made on first use and gone with the window."""
        key = cls._key(window)
        placer = cls._placers.get(key)
        if placer is None:
            placer = cls._placers[key] = cls(window)
        return placer

    def add(self, thumbnail: WindowThumbnail) -> None:
        if thumbnail not in self._thumbnails:
            self._thumbnails.append(thumbnail)

    def remove(self, thumbnail: WindowThumbnail) -> None:
        if thumbnail in self._thumbnails:
            self._thumbnails.remove(thumbnail)

    def schedule(self, handle: _Handle, properties: DWM_THUMBNAIL_PROPERTIES) -> None:
        """Hands `properties` to DWM once the frame Qt draws next is presented."""
        self._pending[handle.value.value] = (handle, properties)
        # Outside a frame, one has to be drawn for the placement to be handed over, e.g. when only the thumbnail's
        # own item changed
        if not self._measuring:
            self._window.update()

    def _measure(self) -> None:
        # Items QML has deleted since the last frame
        self._thumbnails = [thumbnail for thumbnail in self._thumbnails if not sip.isdeleted(thumbnail)]
        # A parent moving or fading says nothing to its thumbnails, so each is checked every frame
        self._measuring = True
        try:
            for thumbnail in self._thumbnails:
                thumbnail._measure()
        finally:
            self._measuring = False

    def _apply(self) -> None:
        pending, self._pending = self._pending, {}
        for value, (handle, properties) in pending.items():
            # Gone, or registered again, since it was measured
            if handle.value.value == value:
                DwmUpdateThumbnailProperties(handle.value, byref(properties))


class WindowThumbnail(QQuickItem):
    """Shows another window, live, in this item's place. DWM draws it over the QML scene, so nothing in the item's
    place is seen; the item's visibility, opacity and clipping, through all its parents, carry over."""

    hwndChanged = pyqtSignal()
    sourceSizeChanged = pyqtSignal()

    def __init__(self, parent: QQuickItem | None = None) -> None:
        super().__init__(parent)
        self._hwnd = 0
        self._handle = _Handle()
        self._source = (0, 0)
        # When DWM was last asked for the source's size
        self._source_checked = 0.0
        # The properties DWM was last given, so it is told only of changes
        self._shown: tuple[Any, ...] | None = None
        self._window: QQuickWindow | None = None
        self._placer: _Placer | None = None
        self.destroyed.connect(self._handle.release)
        self.windowChanged.connect(self._attach)
        self.visibleChanged.connect(self._measure)

    def _get_hwnd(self) -> int:
        return self._hwnd

    def _set_hwnd(self, hwnd: int) -> None:
        if hwnd == self._hwnd:
            return
        self._hwnd = hwnd
        self.hwndChanged.emit()
        self._register()

    # The window shown
    hwnd = pyqtProperty(int, _get_hwnd, _set_hwnd, notify=hwndChanged)

    # The size of the window shown, in pixels; 0 until it is known
    @qml_property(int, notify=sourceSizeChanged)
    def sourceWidth(self) -> int:
        return self._source[0]

    @qml_property(int, notify=sourceSizeChanged)
    def sourceHeight(self) -> int:
        return self._source[1]

    def _attach(self, window: QQuickWindow | None) -> None:
        if self._placer is not None:
            self._placer.remove(self)
        self._window = window
        self._placer = _Placer.of(window) if window is not None else None
        if self._placer is not None:
            self._placer.add(self)
        self._register()

    def _register(self) -> None:
        self._handle.release()
        self._shown = None
        if self._window is None or not self._hwnd or not IsWindow(self._hwnd):
            self._set_source((0, 0))
            return
        if DwmRegisterThumbnail(int(self._window.winId()), self._hwnd, byref(self._handle.value)) != 0:
            logging.debug("Could not show a thumbnail of window %s", self._hwnd)
            self._handle.value = wintypes.HANDLE(0)
            self._set_source((0, 0))
            return
        self._check_source()
        self._measure()

    def _check_source(self) -> None:
        size = SIZE()
        if DwmQueryThumbnailSourceSize(self._handle.value, byref(size)) == 0:
            self._set_source((size.cx, size.cy))
        self._source_checked = time.monotonic()

    def _set_source(self, source: tuple[int, int]) -> None:
        if source != self._source:
            self._source = source
            self.sourceSizeChanged.emit()

    def geometryChange(self, newGeometry: QRectF, oldGeometry: QRectF) -> None:
        super().geometryChange(newGeometry, oldGeometry)
        self._measure()

    def _opacity(self) -> float:
        opacity = 1.0
        item: QQuickItem | None = self
        while item is not None:
            opacity *= item.opacity()
            item = item.parentItem()
        return opacity

    def _measure(self) -> None:
        """Works out where DWM should draw the picture, and has the placer hand it over if that changed."""
        if not self._handle.value.value or self._window is None or self._placer is None:
            return
        if time.monotonic() - self._source_checked >= SOURCE_SIZE_INTERVAL:
            self._check_source()
        source_width, source_height = self._source
        scale = self._window.devicePixelRatio()
        rect = self.mapRectToScene(QRectF(0, 0, self.width(), self.height()))
        # DWM draws over the scene and knows nothing of clipping, so the picture is cut to every clipping parent here
        shown_rect = rect
        parent = self.parentItem()
        while parent is not None:
            if parent.clip():
                shown_rect = shown_rect.intersected(
                    parent.mapRectToScene(QRectF(0, 0, parent.width(), parent.height()))
                )
            parent = parent.parentItem()
        cut = (0.0, 0.0, 1.0, 1.0)
        if not shown_rect.isEmpty() and rect.width() > 0 and rect.height() > 0:
            cut = (
                (shown_rect.left() - rect.left()) / rect.width(),
                (shown_rect.top() - rect.top()) / rect.height(),
                (shown_rect.right() - rect.left()) / rect.width(),
                (shown_rect.bottom() - rect.top()) / rect.height(),
            )
        shown = (
            round(shown_rect.left() * scale),
            round(shown_rect.top() * scale),
            round(shown_rect.right() * scale),
            round(shown_rect.bottom() * scale),
            round(cut[0] * source_width),
            round(cut[1] * source_height),
            round(cut[2] * source_width),
            round(cut[3] * source_height),
            self.isVisible() and not shown_rect.isEmpty(),
            round(self._opacity() * 255),
        )
        if shown == self._shown:
            return
        self._shown = shown
        properties = DWM_THUMBNAIL_PROPERTIES()
        properties.dwFlags = (
            DWM_TNP_RECTDESTINATION
            | DWM_TNP_RECTSOURCE
            | DWM_TNP_VISIBLE
            | DWM_TNP_OPACITY
            | DWM_TNP_SOURCECLIENTAREAONLY
        )
        properties.rcDestination = RECT(*shown[:4])
        properties.rcSource = RECT(*shown[4:8])
        properties.fVisible = shown[8]
        properties.opacity = shown[9]
        properties.fSourceClientAreaOnly = False
        self._placer.schedule(self._handle, properties)
