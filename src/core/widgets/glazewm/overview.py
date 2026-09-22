import ctypes
import logging
import math
import time
from ctypes import wintypes

import win32api
from PIL import Image, ImageQt
from PyQt6.QtCore import QPoint, QPointF, QRectF, Qt, QThreadPool, QTimer, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QColor, QFont, QFontMetrics, QPainter, QPainterPath, QPen, QPixmap, QTransform
from PyQt6.QtWidgets import QApplication, QVBoxLayout, QWidget

from core.utils.qobject import is_valid_qobject
from core.utils.utilities import PopupWidget
from core.utils.win32.app_icons import get_icon_for_aumid, get_process_icon, get_window_icon
from core.utils.win32.aumid import get_aumid_for_window
from core.utils.win32.bindings.dwmapi import (
    DwmQueryThumbnailSourceSize,
    DwmRegisterThumbnail,
    DwmUnregisterThumbnail,
    DwmUpdateThumbnailProperties,
)
from core.utils.win32.constants import (
    DWM_TNP_OPACITY,
    DWM_TNP_RECTDESTINATION,
    DWM_TNP_RECTSOURCE,
    DWM_TNP_VISIBLE,
)
from core.utils.win32.structs import DWM_THUMBNAIL_PROPERTIES, RECT, SIZE
from core.utils.win32.utils import get_process_info
from core.utils.win32.window_actions import close_application, force_foreground_focus
from core.validation.widgets.glazewm.overview import GlazewmOverviewConfig
from core.widgets.base import BaseWidget
from core.widgets.glazewm.workspaces import natural_sort_key
from core.widgets.services.glazewm.client import GlazewmClient, Monitor, Window, Workspace

logger = logging.getLogger("glazewm_overview")

_user32 = ctypes.windll.user32


class _LiveThumbnails:
    """Live DWM thumbnails of windows, composited by DWM straight onto the overlay
    window - no capture, no copy, and a window on a hidden workspace is still live
    since GlazeWM only cloaks it.

    DWM draws a thumbnail above everything Qt paints in that window, so the canvas
    leaves each one a hole (borders and captions go around it, never over it) and
    places them all again on every frame it paints. They stack in the order they
    were registered, which is why the one that has to stay on top is registered
    again whenever something else registered after it."""

    def __init__(self):
        self._dest = 0
        # (source hwnd, slot) -> thumbnail handle
        self._thumbs: dict[tuple[int, str], wintypes.HANDLE] = {}
        self._shown: set[tuple[int, str]] = set()
        self._placed: set[tuple[int, str]] = set()
        self._registered = False

    def begin(self, dest_hwnd: int):
        self._dest = dest_hwnd
        self._placed = set()
        self._registered = False

    def place(self, hwnd: int, slot: str, dest: QRectF, opacity: float, on_top: bool = False) -> bool:
        """Show hwnd filling dest (physical pixels in the overlay), cropped rather
        than stretched. False if DWM will not give us that window."""
        if dest.width() < 1 or dest.height() < 1:
            return False
        key = (hwnd, slot)
        if on_top and self._registered:
            self._drop(key)
        thumb = self._thumbs.get(key)
        if thumb is None:
            thumb = wintypes.HANDLE()
            if DwmRegisterThumbnail(self._dest, hwnd, ctypes.byref(thumb)) != 0:
                return False
            self._registered = True
            self._thumbs[key] = thumb

        # the source size is the visible window, invisible resize borders already
        # left out; asked every frame because the window can be resized under us
        size = SIZE()
        if DwmQueryThumbnailSourceSize(thumb, ctypes.byref(size)) != 0 or size.cx <= 0 or size.cy <= 0:
            self._drop(key)
            return False

        # crop the overhang so the picture fills the tile at its own aspect
        scale = max(dest.width() / size.cx, dest.height() / size.cy)
        cw, ch = dest.width() / scale, dest.height() / scale
        cl, ct = (size.cx - cw) / 2, (size.cy - ch) / 2

        props = DWM_THUMBNAIL_PROPERTIES()
        props.dwFlags = DWM_TNP_RECTDESTINATION | DWM_TNP_RECTSOURCE | DWM_TNP_OPACITY | DWM_TNP_VISIBLE
        props.rcDestination = RECT(round(dest.left()), round(dest.top()), round(dest.right()), round(dest.bottom()))
        props.rcSource = RECT(round(cl), round(ct), round(cl + cw), round(ct + ch))
        props.opacity = max(0, min(255, round(opacity * 255)))
        props.fVisible = True
        if DwmUpdateThumbnailProperties(thumb, ctypes.byref(props)) != 0:
            self._drop(key)
            return False
        self._placed.add(key)
        self._shown.add(key)
        return True

    def end(self):
        """Hide whatever was not placed this frame: off screen, closed, dragged away."""
        for key in self._shown - self._placed:
            thumb = self._thumbs.get(key)
            if thumb is not None:
                props = DWM_THUMBNAIL_PROPERTIES()
                props.dwFlags = DWM_TNP_VISIBLE
                props.fVisible = False
                DwmUpdateThumbnailProperties(thumb, ctypes.byref(props))
        self._shown = set(self._placed)

    def _drop(self, key: tuple[int, str]):
        thumb = self._thumbs.pop(key, None)
        if thumb is not None:
            DwmUnregisterThumbnail(thumb)
        self._shown.discard(key)

    def clear(self):
        for key in list(self._thumbs):
            self._drop(key)
        self._shown.clear()
        self._placed.clear()
        self._dest = 0


def _fetch_app_icon_image(handle: int, physical_size: int) -> Image.Image | None:
    """AUMID -> process -> window icon fallback chain, already resized. Pure
    PIL/win32 work with no Qt objects, so it's safe to run off the GUI thread."""
    try:
        img = None
        aumid = get_aumid_for_window(handle)
        if aumid:
            img = get_icon_for_aumid(aumid, size=physical_size)
        if not img:
            pid = get_process_info(handle).get("pid")
            if pid:
                img = get_process_icon(pid)
        if not img:
            img = get_window_icon(handle)
        if img:
            return img.resize((physical_size, physical_size), Image.Resampling.LANCZOS).convert("RGBA")
    except Exception:
        logger.debug("Failed to resolve icon for window %s", handle, exc_info=True)
    return None


def _to_pixmap(img: Image.Image, dpr: float) -> QPixmap:
    pixmap = ImageQt.toqpixmap(img)
    pixmap.setDevicePixelRatio(dpr)
    return pixmap


class _Spring:
    """A number that eases toward its target instead of jumping to it. Every
    animated value on the canvas is one of these, stepped from a single frame
    timer - far cheaper than a QPropertyAnimation per card per property, and a
    retarget mid-flight carries its velocity instead of restarting the curve.
    ratio 1 settles without overshoot (OutCubic-ish); below 1 it swings past the
    target first (OutBack-ish)."""

    __slots__ = ("value", "target", "velocity", "stiffness", "damping", "eps")

    def __init__(self, value: float, settle_ms: float = 260, ratio: float = 1.0, eps: float = 0.25):
        self.value = self.target = value
        self.velocity = 0.0
        omega = 4.6 / (settle_ms / 1000)
        self.stiffness = omega * omega
        self.damping = 2 * ratio * omega
        self.eps = eps

    def snap(self, value: float):
        self.value = self.target = value
        self.velocity = 0.0

    def step(self, dt: float) -> bool:
        if self.value == self.target and self.velocity == 0.0:
            return False
        accel = (self.target - self.value) * self.stiffness - self.velocity * self.damping
        self.velocity += accel * dt
        self.value += self.velocity * dt
        if abs(self.target - self.value) < self.eps and abs(self.velocity) < self.eps * 4:
            self.snap(self.target)
        return True


def _frame_interval_ms() -> int:
    """One frame at the fastest connected screen's refresh rate, in whole ms."""
    rate = max((s.refreshRate() for s in QApplication.screens()), default=60.0)
    return max(1, int(1000 / max(rate, 1.0)))


def _alpha(color: QColor, a: float) -> QColor:
    c = QColor(color)
    c.setAlphaF(a)
    return c


class OverviewCanvas(QWidget):
    """The whole overview, painted: a carousel of workspace cards with the focused
    one parked in the middle at full size and its neighbours sat back, zooming in
    when you look inside one. A port of the quickshell WorkspaceOverview.qml.

    Painted by hand rather than built from child widgets because every card scales
    continuously - Qt widgets can move and resize but not scale, and resizing a
    card full of thumbnail labels on every animation frame is what that would take."""

    SPACING = 10
    SLOP = 6
    GHOST_W, GHOST_H = 200, 124

    def __init__(self, overview: GlazewmOverviewWidget, parent: QWidget):
        super().__init__(parent)
        self.ov = overview
        cfg = overview.config
        # the font comes from the stylesheet: .glazewm-overview { font-family: ... }
        self.setProperty("class", "glazewm-overview")
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        c = cfg.colors
        system_accent = QApplication.palette().highlight().color()
        self.accent = QColor(c.accent) if c.accent else system_accent
        self.base = QColor(c.base)
        self.bg = _alpha(QColor(c.bg), 0.9)
        self.surface = QColor(c.surface)
        self.text = QColor(c.text)
        self.subtext = QColor(c.subtext)
        self.blue = QColor(c.blue)
        self.scrim = QColor(c.scrim)

        self.workspaces: list[Workspace] = []
        self.selected_name: str | None = None
        # "carousel" - one workspace at a time, quickshell style
        # "grid"     - every workspace at once, for shuffling windows with the mouse
        self.layout_mode = "carousel"

        # Keyboard flow, one space bar at a time:
        #   spaces   - browsing the carousel
        #   windows  - zoomed into one workspace, picking a window out of it
        #   carrying - holding a window, waiting for a workspace to put it on
        # Windows are held by GlazeWM id, never by object: every event rebuilds them.
        self.mode = "spaces"
        self.selected_win_id: str | None = None
        self.carried_id: str | None = None

        # "/" opens a window search across every workspace, vim style: type to
        # filter, n / N walk the hits, enter jumps to the best one
        self.searching = False
        self.query = ""
        self.match_index = 0

        # mouse drag. nothing moves but a ghost that follows the cursor; the drop
        # target is hit tested against the cards as they are drawn right now
        self.drag_id: str | None = None
        self.drop_name: str | None = None
        self.hover_name: str | None = None
        self._press: QPointF | None = None
        self._press_hit: tuple[str | None, str | None] = (None, None)

        # animation state
        self._card_cx: dict[str, _Spring] = {}
        self._card_cy: dict[str, _Spring] = {}
        self._card_scale: dict[str, _Spring] = {}
        # the selection border fades between cards instead of jumping
        self._card_sel: dict[str, _Spring] = {}
        # workspace name -> (everything the picture depends on, the picture)
        self._card_cache: dict[str, tuple[tuple, QPixmap]] = {}
        self._hint_y = _Spring(0)
        self._pane_scale = _Spring(1, settle_ms=240, ratio=0.75, eps=0.001)
        self._ghost_x = _Spring(0, settle_ms=280)
        self._ghost_y = _Spring(0, settle_ms=340, ratio=0.6)
        self._laid_out = False
        self.live = _LiveThumbnails()

        self._frame = QTimer(self)
        # one step per display refresh; a fixed 8ms beat against 144/175Hz panels
        self._frame.setInterval(_frame_interval_ms())
        # the default coarse timer snaps to Windows' ~15.6ms tick, so frames came
        # at uneven intervals - visible as judder in a slide
        self._frame.setTimerType(Qt.TimerType.PreciseTimer)
        self._frame.timeout.connect(self._tick)  # type: ignore
        self._last_tick = time.monotonic()
        self._last_rect = QRectF()

    # ── geometry ──

    @property
    def aspect(self) -> float:
        ws = next((w for w in self.workspaces if w.width > 0 and w.height > 0), None)
        if ws:
            return ws.width / ws.height
        return self.width() / max(self.height(), 1)

    @property
    def card_w(self) -> float:
        # quickshell uses 900 on a 3440 ultrawide; keep that proportion elsewhere
        return max(380.0, min(900.0, self.width() * 0.26))

    @property
    def card_h(self) -> float:
        return 28 + (self.card_w - 18) / self.aspect + 9

    def _tile_area(self) -> QRectF:
        w = self.card_w - 18
        return QRectF(9, 28, w, w / self.aspect)

    def _index_of(self, name: str | None) -> int:
        for i, ws in enumerate(self.workspaces):
            if ws.name == name:
                return i
        return -1

    @property
    def selected_index(self) -> int:
        return max(0, self._index_of(self.selected_name))

    def selected_ws(self) -> Workspace | None:
        i = self._index_of(self.selected_name)
        return self.workspaces[i] if i >= 0 else None

    def _shrink(self, sel: bool) -> float:
        if sel:
            return 1.5 if self.mode == "windows" else 1.0
        return 0.66 if self.mode == "spaces" else 0.32

    def _is_target(self, name: str, sel: bool) -> bool:
        if self.drag_id:
            return self.drop_name == name
        return self.mode == "carrying" and sel

    def _pane_transform(self) -> QTransform:
        c = QPointF(self.width() / 2, self.height() / 2)
        s = self._pane_scale.value
        return QTransform().translate(c.x(), c.y()).scale(s, s).translate(-c.x(), -c.y())

    @property
    def grid_columns(self) -> int:
        return max(1, min(self.ov.config.grid_columns, len(self.workspaces)))

    def _carousel_targets(self) -> tuple[list[tuple[float, float, float]], float]:
        card_w = self.card_w
        sel_i = self.selected_index
        widths = [card_w * self._shrink(i == sel_i) for i in range(len(self.workspaces))]
        starts, x = [], 0.0
        for w in widths:
            starts.append(x)
            x += w + self.SPACING
        # carousel: the selected card is always parked in the middle
        offset = self.width() / 2 - (starts[sel_i] + widths[sel_i] / 2)
        # the row grows with the zoom, so a busy workspace gets the room it needs
        row_h = self.card_h * (1.5 if self.mode == "windows" else 1.02)
        top = (self.height() - row_h - 30) / 2
        targets = [
            (starts[i] + widths[i] / 2 + offset, top + row_h / 2, self._shrink(i == sel_i))
            for i in range(len(self.workspaces))
        ]
        return targets, top + row_h + 16

    def _grid_targets(self) -> tuple[list[tuple[float, float, float]], float]:
        n = len(self.workspaces)
        cols = self.grid_columns
        rows = (n + cols - 1) // cols
        gap = 14
        # leave room for the hint line and a carried window parked at the bottom
        avail_w = self.width() - 120
        avail_h = self.height() - 320
        scale = min(
            (avail_w - gap * (cols - 1)) / (cols * self.card_w),
            (avail_h - gap * (rows - 1)) / (rows * self.card_h),
            1.0,
        )
        cw, ch = self.card_w * scale, self.card_h * scale
        total_w = cols * cw + (cols - 1) * gap
        total_h = rows * ch + (rows - 1) * gap
        left = (self.width() - total_w) / 2
        top = (self.height() - total_h - 30) / 2
        targets = []
        for i in range(n):
            r, c = divmod(i, cols)
            # a short last row is centred rather than hanging off the left
            row_len = min(cols, n - r * cols)
            row_left = left + (cols - row_len) * (cw + gap) / 2
            targets.append((row_left + c * (cw + gap) + cw / 2, top + r * (ch + gap) + ch / 2, scale))
        return targets, top + total_h + 16

    def _retarget(self):
        """Work out where every card should be and how big, and point the springs
        at it. Positions and scales glide, so switching layout flies the cards
        from the row into the grid and back."""
        if not self.workspaces or self.width() <= 0:
            return
        targets, hint_y = self._grid_targets() if self.layout_mode == "grid" else self._carousel_targets()
        sel_i = self.selected_index
        for i, (ws, (cx, cy, scale)) in enumerate(zip(self.workspaces, targets)):
            scale *= 1.06 if self._is_target(ws.name, i == sel_i) else 1.0
            glow = 1.0 if i == sel_i else 0.0
            if ws.name not in self._card_cx or not self._laid_out:
                self._card_cx[ws.name] = _Spring(cx)
                self._card_cy[ws.name] = _Spring(cy)
                self._card_scale[ws.name] = _Spring(scale, eps=0.001)
                self._card_sel[ws.name] = _Spring(glow, settle_ms=220, eps=0.005)
            else:
                self._card_cx[ws.name].target = cx
                self._card_cy[ws.name].target = cy
                self._card_scale[ws.name].target = scale
                self._card_sel[ws.name].target = glow

        self._hint_y.target = hint_y
        if not self._laid_out:
            self._hint_y.snap(hint_y)
        self._laid_out = True

        if self.floating_id() and not self.drag_id:
            # parked at the bottom of the screen while carrying
            self._ghost_x.target = (self.width() - self.GHOST_W) / 2
            self._ghost_y.target = self.height() - self.GHOST_H - 80
        self._kick()

    def _moving_rect(self) -> QRectF:
        """Everything an animation frame can change: the cards, the hint line under
        them and a dragged or carried window."""
        rect = QRectF(0, self._hint_y.value, self.width(), 14)
        for name, cx in self._card_cx.items():
            s = self._card_scale[name].value
            w, h = self.card_w * s, self.card_h * s
            rect = rect.united(QRectF(cx.value - w / 2, self._card_cy[name].value - h / 2, w, h))
        rect = self._pane_transform().mapRect(rect)
        if self.floating_id():
            rect = rect.united(QRectF(self._ghost_x.value, self._ghost_y.value, self.GHOST_W, self.GHOST_H))
        # room for anti-aliased borders
        return rect.adjusted(-6, -6, 6, 6)

    def _kick(self):
        self.update()
        if not self._frame.isActive():
            self._last_tick = time.monotonic()
            self._frame.start()

    def _tick(self):
        now = time.monotonic()
        dt = min(now - self._last_tick, 1 / 30)
        self._last_tick = now
        moving = False
        springs = [self._hint_y, self._pane_scale, self._ghost_x, self._ghost_y]
        springs += self._card_cx.values()
        springs += self._card_cy.values()
        springs += self._card_scale.values()
        springs += self._card_sel.values()
        for s in springs:
            moving |= s.step(dt)
        # only the part that moves is repainted, where it is now and where it was
        # last frame (or it would leave a trail); the dim around it stays as it is
        rect = self._moving_rect()
        self.update(rect.united(self._last_rect).toAlignedRect())
        self._last_rect = rect
        # the live thumbnails take their opacity from the popup's fade, so keep
        # placing them until it is done even when nothing on the canvas moves
        if not moving and (self.window().windowOpacity() >= 1.0 or not self.window().isVisible()):
            self._frame.stop()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._laid_out = False
        self._retarget()

    # ── state ──

    def open(self, workspaces: list[Workspace], layout_mode: str = "carousel"):
        self.layout_mode = layout_mode
        self.workspaces = workspaces
        focused = next((w for w in workspaces if w.focus), None)
        self.selected_name = (focused or workspaces[0]).name if workspaces else None
        self._pane_scale.snap(0.94)
        self._pane_scale.target = 1.0
        self._retarget()

    def set_workspaces(self, workspaces: list[Workspace]):
        self.workspaces = workspaces
        if self._index_of(self.selected_name) < 0 and workspaces:
            focused = next((w for w in workspaces if w.focus), None)
            self.selected_name = (focused or workspaces[0]).name
        for name in list(self._card_cx):
            if self._index_of(name) < 0:
                del self._card_cx[name], self._card_cy[name], self._card_scale[name], self._card_sel[name]
                self._card_cache.pop(name, None)
        self._retarget()

    def set_layout(self, layout_mode: str):
        self.layout_mode = layout_mode
        self._retarget()

    def floating_id(self) -> str | None:
        return self.drag_id or self.carried_id

    def find_window(self, window_id: str | None) -> tuple[Workspace, Window] | tuple[None, None]:
        if window_id:
            for ws in self.workspaces:
                for w in ws.windows:
                    if w.id == window_id:
                        return ws, w
        return None, None

    def _select(self, name: str | None):
        if name is None or name == self.selected_name:
            return
        self.selected_name = name
        # the window cursor belongs to one workspace
        self.selected_win_id = None
        self._retarget()

    def step(self, d: int):
        if not self.workspaces:
            return
        i = max(0, min(len(self.workspaces) - 1, self.selected_index + d))
        self._select(self.workspaces[i].name)

    @staticmethod
    def ordered(ws: Workspace, axis: int) -> list[Window]:
        """Tiled windows in on-screen order: axis 0 across (x, then y), 1 down."""
        key = (lambda w: (w.x, w.y)) if axis == 0 else (lambda w: (w.y, w.x))
        return sorted((w for w in ws.windows if not w.minimized and w.width > 0), key=key)

    def _step_win(self, axis: int, d: int):
        ws = self.selected_ws()
        ids = [w.id for w in self.ordered(ws, axis)] if ws else []
        if not ids:
            return
        if self.selected_win_id not in ids:
            self.selected_win_id = ids[0]
        else:
            i = ids.index(self.selected_win_id)
            self.selected_win_id = ids[max(0, min(len(ids) - 1, i + d))]
        self.update()

    def match_score(self, w: Window) -> int | None:
        """Where the query sits in the title or process name, lower is better;
        None when it is in neither."""
        if not self.query:
            return None
        q = self.query.lower()
        found = [i for text in (w.title, w.process_name) if text and (i := text.lower().find(q)) >= 0]
        return min(found, default=None)

    def is_hit(self, w: Window) -> bool:
        return self.match_score(w) is not None

    def matches(self) -> list[tuple[Workspace, Window]]:
        # best match first, so enter lands on it and n walks down the ranking;
        # equal scores keep carousel order, left to right across the row
        out = []
        for ws in self.workspaces:
            wins = self.ordered(ws, 0) + [w for w in ws.windows if w.minimized or w.width <= 0]
            out.extend((ws, w) for w in wins if self.is_hit(w))
        return sorted(out, key=lambda hit: self.match_score(hit[1]))

    def goto_match(self, d: int):
        hits = self.matches()
        if not hits:
            return
        self.match_index = (self.match_index + d) % len(hits)
        ws, w = hits[self.match_index]
        self._select(ws.name)
        # While carrying, a search is how you aim: it moves the carousel to the
        # hit's workspace and nothing else. Selecting the hit here would make space
        # pick that window up instead of dropping the one already in hand.
        if self.mode != "carrying":
            self.mode = "windows"
            self.selected_win_id = w.id
        self._retarget()

    def _drop_carried(self):
        src, win = self.find_window(self.carried_id)
        dest = self.selected_ws()
        if win and dest and src is not dest:
            self.ov.move_window(win.id, dest.name)
        self.mode = "spaces"
        self.carried_id = None
        self.selected_win_id = None
        self.searching = False
        self.query = ""
        self._retarget()

    # ── keys ──

    def keyPressEvent(self, event):
        key = event.key()
        text = event.text()
        shift = bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier)

        # typing a query swallows everything, otherwise "n" and "/" could not be
        # part of a window title
        if self.searching:
            if key == Qt.Key.Key_Escape:
                self.searching = False
                self.query = ""
            elif key == Qt.Key.Key_Backspace:
                if self.query:
                    self.query = self.query[:-1]
                else:
                    self.searching = False
            elif key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                self.searching = False
                self.match_index = -1
                self.goto_match(1)
            elif text and text.isprintable():
                self.query += text
            else:
                return super().keyPressEvent(event)
            self.update()
            return

        # matched on text, not key code: "/" sits on a shifted key on many layouts
        if key == Qt.Key.Key_Escape:
            self.ov.close_popup()
        elif text == "/":
            self.searching = True
            self.query = ""
            self.match_index = 0
        elif text in ("n", "N"):
            # the hits stay live after the search closes, so n keeps working
            self.goto_match(-1 if shift else 1)
        elif text in ("x", "X"):
            # close the window you are pointing at, so tidying up does not mean
            # visiting every workspace
            _, win = self.find_window(self.selected_win_id)
            if self.mode == "windows" and win:
                self.ov.close_window(win)
                self.selected_win_id = None
        elif key in (Qt.Key.Key_Tab, Qt.Key.Key_Backtab):
            self.layout_mode = "carousel" if self.layout_mode == "grid" else "grid"
        elif key == Qt.Key.Key_Space:
            ws = self.selected_ws()
            if self.mode == "spaces":
                # nothing to pick from on an empty workspace
                wins = self.ordered(ws, 0) if ws else []
                if wins:
                    # picking a window is a zoomed-in thing; the grid is too small
                    # to aim at one, so looking inside always goes to the carousel
                    self.layout_mode = "carousel"
                    self.mode = "windows"
                    self.selected_win_id = wins[0].id
            elif self.mode == "windows":
                if self.find_window(self.selected_win_id)[1]:
                    self.carried_id = self.selected_win_id
                    self.mode = "carrying"
                    # start it up in the row so it visibly drops to the bottom
                    self._ghost_x.snap((self.width() - self.GHOST_W) / 2)
                    self._ghost_y.snap(self.height() / 2 - self.GHOST_H / 2)
            else:
                self._drop_carried()
        elif key == Qt.Key.Key_Backspace:
            # one step back up the flow; escape closes the whole overlay
            if self.mode == "carrying":
                self.carried_id = None
                self.mode = "windows"
            elif self.mode == "windows":
                self.mode = "spaces"
                self.selected_win_id = None
        elif key in (Qt.Key.Key_Right, Qt.Key.Key_L, Qt.Key.Key_Left, Qt.Key.Key_H):
            d = 1 if key in (Qt.Key.Key_Right, Qt.Key.Key_L) else -1
            # zoomed in, the arrows walk the windows: they are laid out side by
            # side exactly as they are on screen
            if self.mode == "windows":
                self._step_win(0, d)
            else:
                self.step(d)
        elif key in (Qt.Key.Key_Down, Qt.Key.Key_J, Qt.Key.Key_Up, Qt.Key.Key_K):
            d = 1 if key in (Qt.Key.Key_Down, Qt.Key.Key_J) else -1
            if self.mode == "windows":
                self._step_win(1, d)
            elif self.layout_mode == "grid":
                self.step(d * self.grid_columns)
        elif key == Qt.Key.Key_Home and self.workspaces:
            self._select(self.workspaces[0].name)
        elif key == Qt.Key.Key_End and self.workspaces:
            self._select(self.workspaces[-1].name)
        elif key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            _, win = self.find_window(self.selected_win_id)
            if self.mode == "carrying":
                self._drop_carried()
            elif self.mode == "windows" and win:
                self.ov.focus_window(win, self.selected_name)
            elif self.selected_name:
                self.ov.activate_workspace(self.selected_name)
        elif Qt.Key.Key_1 <= key <= Qt.Key.Key_9 or key == Qt.Key.Key_0:
            # 1-9 jump straight to that position in the row, 0 to the 10th
            i = 9 if key == Qt.Key.Key_0 else key - Qt.Key.Key_1
            if i < len(self.workspaces):
                if self.mode == "carrying":
                    self._select(self.workspaces[i].name)
                else:
                    self.ov.activate_workspace(self.workspaces[i].name)
        else:
            return super().keyPressEvent(event)
        self._retarget()

    # ── mouse ──

    def _card_local(self, name: str, pos: QPointF) -> QPointF | None:
        """pos (canvas coords) in the unscaled coordinates of a card, or None if it
        is not over that card."""
        cx, s = self._card_cx.get(name), self._card_scale.get(name)
        if cx is None or s is None or s.value <= 0:
            return None
        p, _ = self._pane_transform().inverted()
        p = p.map(pos)
        cy = self._card_cy[name].value
        local = QPointF((p.x() - cx.value) / s.value + self.card_w / 2, (p.y() - cy) / s.value + self.card_h / 2)
        if 0 <= local.x() <= self.card_w and 0 <= local.y() <= self.card_h:
            return local
        return None

    def _hit(self, pos: QPointF) -> tuple[str | None, str | None]:
        """(workspace name, window id) under pos; either can be None."""
        # the selected card is drawn last, so it wins where cards overlap
        order = sorted(self.workspaces, key=lambda ws: ws.name == self.selected_name, reverse=True)
        for ws in order:
            local = self._card_local(ws.name, pos)
            if local is None:
                continue
            for w, rect in reversed(self._tile_rects(ws)):
                if rect.contains(local):
                    return ws.name, w.id
            return ws.name, None
        return None, None

    def mousePressEvent(self, event):
        pos = event.position()
        name, win_id = self._hit(pos)
        if event.button() == Qt.MouseButton.MiddleButton and win_id:
            _, win = self.find_window(win_id)
            if win:
                self.ov.close_window(win)
        elif event.button() == Qt.MouseButton.LeftButton:
            self._press = pos
            self._press_hit = (name, win_id)
        event.accept()

    def mouseMoveEvent(self, event):
        pos = event.position()
        name, _ = self._hit(pos)
        if name != self.hover_name:
            self.hover_name = name
            self.update()
        self.setCursor(
            Qt.CursorShape.ClosedHandCursor
            if self.drag_id
            else Qt.CursorShape.PointingHandCursor
            if name
            else Qt.CursorShape.ArrowCursor
        )

        pressed_win = self._press_hit[1]
        if self._press is None or not pressed_win or not (event.buttons() & Qt.MouseButton.LeftButton):
            return
        # a few pixels of slop, so a click stays a click
        if not self.drag_id:
            if (pos - self._press).manhattanLength() < self.SLOP:
                return
            self.drag_id = pressed_win
        self._ghost_x.snap(pos.x() - self.GHOST_W / 2)
        self._ghost_y.snap(pos.y() - self.GHOST_H / 2)
        if name != self.drop_name:
            self.drop_name = name
            self._retarget()
        self.update()

    def mouseReleaseEvent(self, event):
        if event.button() != Qt.MouseButton.LeftButton or self._press is None:
            return
        name, win_id = self._press_hit
        self._press = None
        self._press_hit = (None, None)

        if self.drag_id:
            src, win = self.find_window(self.drag_id)
            to = self.drop_name
            self.drag_id = None
            self.drop_name = None
            # dropped on its own card, or on nothing: no move
            if win and to and (src is None or to != src.name):
                self.ov.move_window(win.id, to)
            self._retarget()
            return

        if win_id:
            # never moved: treat it as a click and go there
            ws, win = self.find_window(win_id)
            if win:
                self.ov.focus_window(win, ws.name)
        elif name:
            self.selected_name = name
            self.ov.activate_workspace(name)
        else:
            # the dim behind everything closes, like clicking off any overlay
            self.ov.close_popup()

    def wheelEvent(self, event):
        self.step(1 if event.angleDelta().y() < 0 else -1)

    def leaveEvent(self, event):
        self.hover_name = None
        self.update()

    # ── painting ──

    def _font(self, px: float, bold: bool = False) -> QFont:
        f = QFont(self.font())
        f.setPixelSize(max(1, round(px)))
        f.setBold(bold)
        return f

    def _tile_rects(self, ws: Workspace) -> list[tuple[Window, QRectF]]:
        """Every window where it actually sits, scaled onto the card; a tiled pair
        reads as a tiled pair. Floating windows last, since they are on top."""
        area = self._tile_area()
        if ws.width <= 0 or ws.height <= 0:
            return []
        sx, sy = area.width() / ws.width, area.height() / ws.height
        out = []
        for w in sorted(ws.windows, key=lambda w: w.is_floating):
            # minimized, or no geometry yet: stay out of the way rather than pile
            # up as a stub in the corner
            if w.minimized or w.width <= 0 or w.height <= 0:
                continue
            rect = QRectF(
                area.x() + (w.x - ws.x) * sx,
                area.y() + (w.y - ws.y) * sy,
                max(8.0, w.width * sx),
                max(8.0, w.height * sy),
            )
            out.append((w, rect.intersected(area)))
        return out

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHints(
            QPainter.RenderHint.Antialiasing
            | QPainter.RenderHint.SmoothPixmapTransform
            | QPainter.RenderHint.TextAntialiasing
        )
        p.fillRect(self.rect(), self.scrim)
        drawn: list[tuple[Workspace, bool, float, float, float]] = []
        if not self.workspaces:
            self._place_live(drawn)
            return

        p.setTransform(self._pane_transform())
        sel_i = self.selected_index
        order = [i for i in range(len(self.workspaces)) if i != sel_i] + [sel_i]
        for i in order:
            ws = self.workspaces[i]
            if ws.name not in self._card_cx:
                continue
            cx, cy, s = self._card_cx[ws.name], self._card_cy[ws.name], self._card_scale[ws.name]
            half = self.card_w * s.value / 2
            if cx.value + half < -self.width() * 0.1 or cx.value - half > self.width() * 1.1:
                continue
            self._paint_card(p, ws, i == sel_i, cx.value, cy.value, s.value)
            drawn.append((ws, i == sel_i, cx.value, cy.value, s.value))

        self._paint_hint(p, self._hint_y.value)
        p.resetTransform()
        if self.floating_id():
            self._paint_ghost(p)
        self._place_live(drawn)

    def hideEvent(self, event):
        self.live.clear()
        super().hideEvent(event)

    def _place_live(self, drawn: list[tuple[Workspace, bool, float, float, float]]):
        """Put a live DWM thumbnail in every tile just painted, through the same
        transform that placed its card, so it lands in the hole the card left for
        it. DWM cannot be painted over, so this runs after all the Qt painting, and
        the ghost goes last to stack on top."""
        popup = self.window()
        if not popup.isVisible() or getattr(popup, "_is_closing", False):
            self.live.clear()
            return
        self.live.begin(int(popup.winId()))
        dpr = self.devicePixelRatioF()
        origin = QPointF(self.mapTo(popup, QPoint(0, 0)))
        to_device = QTransform.fromTranslate(origin.x(), origin.y()) * QTransform.fromScale(dpr, dpr)
        fade = popup.windowOpacity()

        pane = self._pane_transform()
        for ws, sel, cx, cy, scale in drawn:
            card = (
                QTransform.fromTranslate(-self.card_w / 2, -self.card_h / 2)
                * QTransform.fromScale(scale, scale)
                * QTransform.fromTranslate(cx, cy)
                * pane
                * to_device
            )
            for w, rect in self._tile_rects(ws):
                opacity, border_w, _ = self._tile_style(w, sel)
                live_rect = self._live_rect(rect, border_w, self.TILE_CAPTION[0])
                self.live.place(w.handle, "tile", card.mapRect(live_rect), opacity * fade)

        _, w = self.find_window(self.floating_id())
        if w:
            rect = QRectF(self._ghost_x.value, self._ghost_y.value, self.GHOST_W, self.GHOST_H)
            live_rect = self._live_rect(rect, 2, self.GHOST_CAPTION[0])
            self.live.place(w.handle, "ghost", to_device.mapRect(live_rect), 0.9 * fade, on_top=True)
        self.live.end()

    # room around a cached card for the border's anti-aliasing to spill into
    CARD_PAD = 3

    def _paint_card(self, p: QPainter, ws: Workspace, sel: bool, cx: float, cy: float, scale: float):
        """Place a card's cached picture. Nothing on a card changes while it slides
        or scales - only where it is and how big - so it is drawn once into a
        pixmap and every animation frame just blits it, instead of redoing every
        rounded rect, thumbnail scale and text layout at 60fps."""
        # render at the biggest size the card is heading for in this mode, so it is
        # scaled down (crisp) rather than up (soft) while it animates
        rs = 1.5 if sel and self.mode == "windows" and self.layout_mode == "carousel" else 1.0
        pixmap = self._card_pixmap(ws, sel, rs)
        pad = self.CARD_PAD
        p.save()
        p.translate(cx, cy)
        p.scale(scale / rs, scale / rs)
        p.drawPixmap(QPointF(-self.card_w * rs / 2 - pad, -self.card_h * rs / 2 - pad), pixmap)
        # drawn over the picture rather than into it, so moving the selection
        # re-renders nothing and the border can fade across
        glow = self._card_sel[ws.name].value
        if glow > 0.01:
            p.scale(rs, rs)
            p.setPen(QPen(_alpha(self.accent, 0.9 * glow), 2))
            p.setBrush(Qt.BrushStyle.NoBrush)
            rect = QRectF(-self.card_w / 2, -self.card_h / 2, self.card_w, self.card_h)
            p.drawRoundedRect(rect.adjusted(1, 1, -1, -1), 14, 14)
        p.restore()

    def _card_key(self, ws: Workspace, sel: bool, rs: float, dpr: float) -> tuple:
        """Everything a card's picture depends on. Cheap next to painting it."""
        wins = []
        for w in ws.windows:
            icon = self.ov.app_icon(w)
            wins.append(
                (
                    w.id, w.title, w.x, w.y, w.width, w.height, w.minimized, w.is_floating,
                    icon.cacheKey() if icon is not None else 0,
                    self.is_hit(w),
                )
            )  # fmt: skip
        return (
            rs, dpr, self.card_w, self.aspect,
            ws.x, ws.y, ws.width, ws.height, ws.focus, ws.display_name,
            # the selection itself is not in the picture, only the window cursor
            self.hover_name == ws.name, self._is_target(ws.name, sel), self.mode,
            self.selected_win_id if sel else None, self.floating_id(), bool(self.query),
            tuple(wins),
        )  # fmt: skip

    def _card_pixmap(self, ws: Workspace, sel: bool, rs: float) -> QPixmap:
        dpr = self.devicePixelRatioF()
        key = self._card_key(ws, sel, rs, dpr)
        cached = self._card_cache.get(ws.name)
        if cached is not None and cached[0] == key:
            return cached[1]
        pad = self.CARD_PAD
        pixmap = QPixmap(
            math.ceil((self.card_w * rs + 2 * pad) * dpr),
            math.ceil((self.card_h * rs + 2 * pad) * dpr),
        )
        pixmap.setDevicePixelRatio(dpr)
        pixmap.fill(Qt.GlobalColor.transparent)
        cp = QPainter(pixmap)
        cp.setRenderHints(
            QPainter.RenderHint.Antialiasing
            | QPainter.RenderHint.SmoothPixmapTransform
            | QPainter.RenderHint.TextAntialiasing
        )
        cp.translate(pad, pad)
        cp.scale(rs, rs)
        self._draw_card(cp, ws, sel)
        cp.end()
        self._card_cache[ws.name] = (key, pixmap)
        return pixmap

    def _draw_card(self, p: QPainter, ws: Workspace, sel: bool):
        """Draw a card at its natural size with its top-left at the origin."""
        card_w, card_h = self.card_w, self.card_h
        target = self._is_target(ws.name, sel)
        here = ws.focus

        p.save()

        fill = (
            _alpha(self.accent, 0.22)
            if target
            else _alpha(self.accent, 0.12)
            if here
            else self.surface
            if self.hover_name == ws.name
            else self.bg
        )
        # the selection border is not drawn here: _paint_card fades it in on top
        border_w = 2 if target else 1
        border = self.accent if target else _alpha(self.accent, 0.45) if here else _alpha(self.accent, 0.2)
        p.setPen(QPen(border, border_w))
        p.setBrush(fill)
        p.drawRoundedRect(QRectF(0, 0, card_w, card_h).adjusted(0.5, 0.5, -0.5, -0.5), 14, 14)

        # header: number on the left, window count on the right, minimized apps
        # (no geometry to draw) as small icons beside the count
        p.setFont(self._font(12, bold=here))
        p.setPen(self.accent if here else self.subtext)
        p.drawText(QRectF(12, 0, card_w / 2, 28), Qt.AlignmentFlag.AlignVCenter, ws.display_name or ws.name)
        if ws.windows:
            p.setFont(self._font(10))
            p.setPen(_alpha(self.subtext, 0.6))
            count_rect = QRectF(card_w / 2, 0, card_w / 2 - 12, 28)
            p.drawText(count_rect, Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignRight, str(len(ws.windows)))
            x = card_w - 12 - QFontMetrics(p.font()).horizontalAdvance(str(len(ws.windows))) - 6
            for w in [w for w in ws.windows if w.minimized]:
                icon = self.ov.app_icon(w)
                x -= 16
                if icon:
                    p.setOpacity(0.6)
                    p.drawPixmap(QRectF(x, 7, 14, 14), icon, QRectF(icon.rect()))
                    p.setOpacity(1)

        for w, rect in self._tile_rects(ws):
            self._paint_tile(p, w, rect, sel)
        p.restore()

    # (height, font px) of the title strip under a window
    TILE_CAPTION = (16, 9)
    GHOST_CAPTION = (18, 9)

    @staticmethod
    def _has_caption(rect: QRectF, caption_h: float) -> bool:
        # a sliver of a window has no room for a caption
        return rect.height() > caption_h * 2.4 and rect.width() > 60

    def _live_rect(self, rect: QRectF, border_w: float, caption_h: float) -> QRectF:
        """The part of a tile its live thumbnail gets: inside the border and above
        the caption, since DWM would draw straight over both. A pixel past the
        border too, or the square thumbnail pokes out of the rounded corners."""
        inset = border_w + 1
        live = rect.adjusted(inset, inset, -inset, -inset)
        if self._has_caption(rect, caption_h):
            live.setBottom(rect.bottom() - caption_h)
        return live

    def _tile_style(self, w: Window, card_sel: bool) -> tuple[float, int, QColor]:
        """(opacity, border width, border color) of a tile."""
        picked = self.floating_id() == w.id
        cursor = card_sel and self.selected_win_id == w.id
        hit = self.is_hit(w)
        marked = cursor and self.mode == "windows"
        # dragged away it goes translucent, so you can see it has left without the
        # tile vanishing; during a search the misses step back so the hits read
        opacity = 0.35 if picked else 0.3 if self.query and not hit else 1.0
        border_w = 3 if marked or hit else 2 if picked or cursor else 1
        border = (
            self.blue
            if hit
            else self.accent
            if marked
            else _alpha(self.accent, 0.9 if picked else 0.6)
            if picked or cursor
            else _alpha(self.base, 0.6)
        )
        return opacity, border_w, border

    def _paint_tile(self, p: QPainter, w: Window, rect: QRectF, card_sel: bool):
        opacity, border_w, border = self._tile_style(w, card_sel)
        p.save()
        p.setOpacity(opacity)
        path = QPainterPath()
        path.addRoundedRect(rect, 4, 4)
        p.setClipPath(path)
        p.fillRect(rect, self.surface)
        self._paint_window_content(p, w, rect, *self.TILE_CAPTION)
        p.setClipping(False)

        p.setPen(QPen(border, border_w))
        p.setBrush(Qt.BrushStyle.NoBrush)
        inset = border_w / 2
        p.drawRoundedRect(rect.adjusted(inset, inset, -inset, -inset), 4, 4)
        p.restore()

    def _paint_window_content(self, p: QPainter, w: Window, rect: QRectF, caption_h: float, caption_px: float):
        # the live thumbnail is composited over this by DWM; the icon only shows
        # for a window DWM will not give us
        icon = self.ov.app_icon(w)
        if icon:
            size = min(36.0, rect.height() / 2, rect.width() / 2)
            p.save()
            p.setOpacity(p.opacity() * 0.5)
            p.drawPixmap(
                QRectF(rect.center().x() - size / 2, rect.center().y() - size / 2, size, size),
                icon,
                QRectF(icon.rect()),
            )
            p.restore()

        if self._has_caption(rect, caption_h):
            bar = QRectF(rect.left(), rect.bottom() - caption_h, rect.width(), caption_h)
            p.fillRect(bar, _alpha(self.base, 0.78))
            p.setFont(self._font(caption_px))
            p.setPen(self.text)
            text_rect = bar.adjusted(4, 0, -4, 0)
            title = QFontMetrics(p.font()).elidedText(
                w.title or w.process_name or "", Qt.TextElideMode.ElideRight, int(text_rect.width())
            )
            p.drawText(text_rect, Qt.AlignmentFlag.AlignVCenter, title)

    def _paint_hint(self, p: QPainter, y: float):
        _, carried = self.find_window(self.carried_id)
        _, dragged = self.find_window(self.drag_id)
        if self.searching or self.query:
            n = len(self.matches())
            text = f"/{self.query}{'▏' if self.searching else ''}   {n} {'hit' if n == 1 else 'hits'}"
            if n:
                text += "   ·   ⏎ best match   ·   n / N to walk them"
            if carried:
                text += f'   ·   space drops "{carried.title}" here'
            color, opacity = self.blue, 0.6
        elif dragged:
            text = f'drop "{dragged.title}" on a workspace'
            color, opacity = self.accent, 0.9
        elif self.mode == "carrying":
            title = carried.title if carried else ""
            text = f'carrying "{title}"   ·   ←→ or / to pick a workspace   ·   space to drop   ·   ⌫ back'
            color, opacity = self.accent, 0.9
        elif self.mode == "windows":
            text = (
                "←→ pick a window   ·   space to lift it   ·   ⏎ jump to it   ·   x close   ·   ⌫ back   ·   esc close"
            )
            color, opacity = self.subtext, 0.6
        else:
            text = (
                "arrows workspaces   ·   drag windows between them   ·   / search   ·   ⏎ go there   ·   tab carousel   ·   esc close"
                if self.layout_mode == "grid"
                else "←→ workspaces   ·   space to look inside   ·   / search   ·   ⏎ go there   ·   tab all workspaces   ·   esc close"
            )
            color, opacity = self.subtext, 0.6
        p.setFont(self._font(10))
        p.setPen(_alpha(color, opacity))
        p.drawText(QRectF(0, y, self.width(), 14), Qt.AlignmentFlag.AlignCenter, text)

    def _paint_ghost(self, p: QPainter):
        """The thing that follows the cursor: under it while dragging, parked at the
        bottom of the screen while carrying - the drop between the two is what sells
        "picked up"."""
        _, w = self.find_window(self.floating_id())
        if not w:
            return
        rect = QRectF(0, 0, self.GHOST_W, self.GHOST_H)
        p.save()
        # no tilt: DWM can only place a thumbnail upright
        p.translate(self._ghost_x.value, self._ghost_y.value)
        p.setOpacity(0.9)
        path = QPainterPath()
        path.addRoundedRect(rect, 8, 8)
        p.setClipPath(path)
        p.fillRect(rect, self.surface)
        self._paint_window_content(p, w, rect, *self.GHOST_CAPTION)
        p.setClipping(False)
        p.setPen(QPen(self.accent, 2))
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(rect.adjusted(1, 1, -1, -1), 8, 8)
        p.restore()


class GlazewmOverviewWidget(BaseWidget):
    validation_schema = GlazewmOverviewConfig

    _ICON_SIZE = 36
    _icon_ready = pyqtSignal(int, float, object)
    FADE_MS = 180

    def __init__(self, config: GlazewmOverviewConfig):
        super().__init__(class_name="glazewm-overview-widget")
        self.config = config

        self._init_container()
        self.build_widget_label(self.config.label)
        self.register_callback("toggle_overview", lambda: self._toggle_overview("carousel"))
        # same overview, opened straight into the grid of every workspace
        self.register_callback("toggle_overview_grid", lambda: self._toggle_overview("grid"))

        self.callback_left = self.config.callbacks.on_left
        self.callback_right = self.config.callbacks.on_right
        self.callback_middle = self.config.callbacks.on_middle

        self._popup: PopupWidget | None = None
        self._canvas: OverviewCanvas | None = None
        self._current_screen = None
        self._monitors: list[Monitor] = []

        self._icon_ready.connect(self._on_icon_ready)  # type: ignore
        # None for a window whose icon could not be resolved, so it is not asked again
        self._icon_cache: dict[int, QPixmap | None] = {}
        self._icon_pending: set[int] = set()

        self.glazewm_client = GlazewmClient(
            self.config.glazewm_server_uri,
            [
                "sub -e workspace_activated workspace_deactivated workspace_updated "
                "focus_changed focused_container_moved window_managed window_unmanaged",
                "query monitors",
            ],
        )
        self.glazewm_client.workspaces_data_processed.connect(self._update_monitors)  # type: ignore

    def showEvent(self, event):
        super().showEvent(event)
        self.glazewm_client.connect()

    @pyqtSlot(list)
    def _update_monitors(self, monitors: list[Monitor]):
        self._monitors = monitors
        # Warm the icon cache continuously in the background, whether or not the
        # overview is open, so it never opens onto blank tiles waiting on AUMID/COM
        # lookups (measured ~540ms cold vs ~40ms warm).
        for mon in monitors:
            for ws in mon.workspaces:
                for window in ws.windows:
                    self._request_icon(window)
        if self._popup_is_open() and self._canvas is not None:
            self._canvas.set_workspaces(self._workspaces_for_screen(self._current_screen))
            self._reclaim_focus()

    def _reclaim_focus(self):
        """GlazeWM focuses a window when it moves it, which takes the keyboard away
        from the overlay while it is still up - search and enter then go to that
        window instead. Nothing else can legitimately be in front of a full screen
        overlay, so any GlazeWM event that finds it not foreground takes it back."""
        if not self._popup_is_open() or self._popup._is_closing:
            return
        hwnd = int(self._popup.winId())
        if _user32.GetForegroundWindow() != hwnd:
            force_foreground_focus(hwnd)
        if self._canvas is not None and is_valid_qobject(self._canvas):
            self._canvas.setFocus()

    def _popup_is_open(self) -> bool:
        return bool(self._popup and is_valid_qobject(self._popup) and self._popup.isVisible())

    def _toggle_overview(self, layout_mode: str = "carousel"):
        if self._popup_is_open() and self._canvas is not None:
            # the other layout's hotkey while open switches over instead of closing
            if self._canvas.layout_mode != layout_mode:
                self._canvas.set_layout(layout_mode)
            else:
                self.close_popup()
            return
        self._show_popup(layout_mode)

    def _workspaces_for_screen(self, screen) -> list[Workspace]:
        if not self.config.monitor_exclusive or screen is None:
            workspaces = [ws for mon in self._monitors for ws in mon.workspaces]
        else:
            geo = screen.geometry()
            try:
                target_hwnd = int(win32api.MonitorFromRect((geo.left(), geo.top(), geo.right(), geo.bottom())))
            except Exception:
                target_hwnd = None
            mon = next((m for m in self._monitors if m.hwnd == target_hwnd), None)
            # fall back to whichever monitor GlazeWM reports first, rather than nothing
            mon = mon or (self._monitors[0] if self._monitors else None)
            workspaces = mon.workspaces if mon else []
        return sorted(workspaces, key=lambda w: natural_sort_key(w.name))

    def _show_popup(self, layout_mode: str = "carousel"):
        screen = self.screen() or QApplication.primaryScreen()
        workspaces = self._workspaces_for_screen(screen)
        if not workspaces:
            return

        if self._popup and is_valid_qobject(self._popup):
            self._popup.deleteLater()
        self._current_screen = screen

        popup_cfg = self.config.popup
        # full screen, like a layer-shell overlay: the dim and the blur cover
        # everything, and the carousel has the whole width to slide along
        self._popup = PopupWidget(self, popup_cfg.blur, False, "normal", "None", popup_cfg.dark_mode, pinnable=True)
        self._popup.setProperty("class", "glazewm-overview-popup")

        layout = QVBoxLayout(self._popup)
        layout.setContentsMargins(0, 0, 0, 0)
        self._canvas = OverviewCanvas(self, self._popup)
        layout.addWidget(self._canvas)

        self._popup.setGeometry(screen.geometry())
        self._canvas.resize(screen.geometry().size())
        self._canvas.open(workspaces, layout_mode)

        self._popup._fade_animation.setDuration(self.FADE_MS)
        self._popup.show()
        # PopupWidget.showEvent()'s activateWindow() can lose the Windows
        # foreground-lock race, so a key typed right after the hotkey would still
        # land in the previously focused app. Force it.
        force_foreground_focus(int(self._popup.winId()))
        self._canvas.setFocus()
        # Stay open regardless of OS focus changes - GlazeWM re-focusing a window
        # you just moved would otherwise deactivate and dismiss the overlay. It
        # closes explicitly instead: a click, Escape, or the hotkey.
        self._popup.set_pinned(True)

    def close_popup(self):
        if self._canvas is not None and is_valid_qobject(self._canvas):
            # DWM does not fade them with the popup, so they go first rather than
            # hang at full opacity over a fading overlay
            self._canvas.live.clear()
        if self._popup and is_valid_qobject(self._popup):
            self._popup.hide_animated()

    def _go_and_close(self, go):
        """Run a GlazeWM switch now, close the overlay, and run it once more when
        the overlay is gone. Hiding the overlay makes Windows hand the foreground
        back to whatever had it before - a window on the workspace you just left -
        and GlazeWM follows the foreground, so without the second go it could
        switch straight back.
        With close_delay the overlay stays up that long first, so the window
        manager's own switch animation plays out behind it."""
        go()
        popup = self._popup

        def close():
            if popup is self._popup and popup and is_valid_qobject(popup) and not popup._is_closing:
                popup._fade_animation.finished.connect(go)  # type: ignore
                self.close_popup()

        if self.config.close_delay > 0:
            QTimer.singleShot(self.config.close_delay, close)
        else:
            close()

    # ── actions ──

    def focus_window(self, window: Window, workspace_name: str | None):
        logger.info("Focusing window %s (id=%s) on workspace %s", window.title, window.id, workspace_name)

        def go():
            # activate the workspace first: a bare window-level focus doesn't always
            # switch the displayed workspace on its own
            if workspace_name:
                self.glazewm_client.activate_workspace(workspace_name)
            self.glazewm_client.focus_window(window.id)

        self._go_and_close(go)

    def close_window(self, window: Window):
        logger.info("Closing window %s (id=%s)", window.title, window.id)
        close_application(window.handle)

    def activate_workspace(self, workspace_name: str):
        logger.info("Activating workspace %s", workspace_name)
        self._go_and_close(lambda: self.glazewm_client.activate_workspace(workspace_name))

    def move_window(self, window_id: str, workspace_name: str):
        self.glazewm_client.move_window_to_workspace(window_id, workspace_name)
        QTimer.singleShot(120, self.glazewm_client.refresh_workspaces)
        # belt and braces for when the focus change lands after the last event
        QTimer.singleShot(300, self._reclaim_focus)

    # ── images: all fetched off the GUI thread, painted once they land ──

    def _repaint(self):
        if self._canvas is not None and is_valid_qobject(self._canvas):
            self._canvas.update()

    def _dpr(self) -> float:
        screen = self._current_screen or QApplication.primaryScreen()
        return screen.devicePixelRatio() if screen else 1.0

    def app_icon(self, window: Window) -> QPixmap | None:
        self._request_icon(window)
        return self._icon_cache.get(window.handle)

    def _request_icon(self, window: Window):
        handle = window.handle
        if handle in self._icon_cache or handle in self._icon_pending:
            return
        self._icon_pending.add(handle)
        dpr = self._dpr()
        size = round(self._ICON_SIZE * dpr)
        # off the GUI thread; the signal carries the result back
        QThreadPool.globalInstance().start(
            lambda: self._icon_ready.emit(handle, dpr, _fetch_app_icon_image(handle, size))
        )

    @pyqtSlot(int, float, object)
    def _on_icon_ready(self, handle: int, dpr: float, img: Image.Image | None):
        self._icon_pending.discard(handle)
        self._icon_cache[handle] = _to_pixmap(img, dpr) if img is not None else None
        if len(self._icon_cache) > 80:
            self._icon_cache.pop(next(iter(self._icon_cache)))
        if img is not None:
            self._repaint()
