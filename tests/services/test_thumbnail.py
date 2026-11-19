"""WindowThumbnail and its placer: placements reach DWM once their frame is presented, and only when they change."""

from ctypes import POINTER, cast
from dataclasses import dataclass, field
from typing import Any

import pytest
from PyQt6 import sip
from PyQt6.QtCore import QSizeF
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQuick import QQuickItem, QQuickWindow

import core.services.taskbar.thumbnail as thumbnail_module
from core.services.taskbar.thumbnail import SOURCE_SIZE_INTERVAL, WindowThumbnail, _Placer
from core.utils.win32.structs import DWM_THUMBNAIL_PROPERTIES


@dataclass
class Dwm:
    """DWM as the thumbnail sees it: what it was asked, and the size of the window shown."""

    source: tuple[int, int] = (1920, 1080)
    now: float = 1000.0
    queries: int = 0
    updates: list[tuple[int, int, int, int]] = field(default_factory=list)
    released: list[int] = field(default_factory=list)


@pytest.fixture
def dwm(monkeypatch: pytest.MonkeyPatch) -> Dwm:
    fake = Dwm()

    def register(_destination: int, _source: int, handle: Any) -> int:
        handle._obj.value = 7
        return 0

    def query(_handle: Any, size: Any) -> int:
        fake.queries += 1
        size._obj.cx, size._obj.cy = fake.source
        return 0

    def update(_handle: Any, properties: Any) -> int:
        shown = cast(properties, POINTER(DWM_THUMBNAIL_PROPERTIES)).contents.rcDestination
        fake.updates.append((shown.left, shown.top, shown.right, shown.bottom))
        return 0

    def unregister(handle: Any) -> int:
        fake.released.append(handle.value)
        return 0

    monkeypatch.setattr(thumbnail_module, "DwmRegisterThumbnail", register)
    monkeypatch.setattr(thumbnail_module, "DwmQueryThumbnailSourceSize", query)
    monkeypatch.setattr(thumbnail_module, "DwmUpdateThumbnailProperties", update)
    monkeypatch.setattr(thumbnail_module, "DwmUnregisterThumbnail", unregister)
    monkeypatch.setattr(thumbnail_module, "IsWindow", lambda _hwnd: True)
    monkeypatch.setattr(thumbnail_module.time, "monotonic", lambda: fake.now)
    return fake


@dataclass
class Scene:
    window: QQuickWindow
    holder: QQuickItem
    thumbnail: WindowThumbnail
    placer: _Placer

    def frame(self) -> None:
        """One frame: measured as Qt prepares it, handed over once it is presented."""
        self.placer._measure()
        self.placer._apply()


@pytest.fixture
def scene(qapp: QGuiApplication, dwm: Dwm) -> Scene:
    window = QQuickWindow()
    window.resize(800, 600)
    holder = QQuickItem()
    holder.setParentItem(window.contentItem())
    thumbnail = WindowThumbnail()
    thumbnail.setParentItem(holder)
    thumbnail.setSize(QSizeF(200, 100))
    thumbnail.setProperty("hwnd", 42)
    return Scene(window, holder, thumbnail, _Placer.of(window))


def test_a_placement_reaches_dwm_once_its_frame_is_presented(scene: Scene, dwm: Dwm):
    assert dwm.updates == []
    scene.placer._apply()
    assert dwm.updates == [(0, 0, 200, 100)]

    # A parent moving says nothing to the thumbnail: it is found as the frame is prepared, and handed over after
    scene.holder.setX(50)
    scene.placer._measure()
    assert dwm.updates == [(0, 0, 200, 100)]
    scene.placer._apply()
    assert dwm.updates[-1] == (50, 0, 250, 100)


def test_a_thumbnail_standing_still_costs_dwm_nothing_per_frame(scene: Scene, dwm: Dwm):
    scene.frame()
    queries, updates = dwm.queries, len(dwm.updates)
    for _ in range(100):
        scene.frame()
    assert (dwm.queries, len(dwm.updates)) == (queries, updates)


def test_a_moving_thumbnail_asks_dwm_its_source_size_now_and_then_not_each_frame(scene: Scene, dwm: Dwm):
    queries = dwm.queries
    for step in range(60):
        scene.holder.setX(step)
        scene.frame()
    assert dwm.queries == queries
    assert len(dwm.updates) == 60

    # Resized while shown: seen at the next check
    dwm.source = (1280, 720)
    dwm.now += SOURCE_SIZE_INTERVAL
    scene.frame()
    assert dwm.queries == queries + 1
    assert (scene.thumbnail.property("sourceWidth"), scene.thumbnail.property("sourceHeight")) == (1280, 720)


def test_a_placement_for_a_thumbnail_let_go_of_meanwhile_is_dropped(scene: Scene, dwm: Dwm):
    scene.holder.setX(30)
    scene.placer._measure()
    scene.thumbnail.setProperty("hwnd", 0)
    assert dwm.released == [7]
    scene.placer._apply()
    assert (30, 0, 230, 100) not in dwm.updates


def test_a_thumbnail_qml_deleted_is_left_out(scene: Scene, dwm: Dwm):
    sip.delete(scene.thumbnail)
    scene.frame()
    assert scene.placer._thumbnails == []
