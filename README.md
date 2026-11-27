# Your yasb setup: the top bar (v26: the overview zooms and stays open)

A drop-in copy of your config folder for yasb's `feat/qtquick-migration` branch (checked against `aeac013`). Only files in the config folder changed, nothing in yasb's
source.

## What changed from v25

- **The overview stays open** while other windows take the focus, so closing or moving windows from it no longer
  shuts it; it takes the keyboard back afterwards. Esc, `` Alt+Shift+` ``, its button or a click beside the cards
  closes it.
- **It zooms.** Opening, the workspace on screen shrinks from full size, its windows exactly over the real ones,
  into its card, while the other cards glide in. Going somewhere, that card grows back to full screen over the
  real workspace as GlazeWM switches underneath; closing without picking zooms back into the one you're on. Windows
  slide into place when one moves, closes or arrives. `openDuration`, `closeDuration` and `glideDuration` at the
  top of `widgets/Overview/Overview.qml`.

## What changed from v24

- **Overview** (`widgets/Overview/Overview.qml`), the button next to the workspaces, or `` Alt+Shift+` ``. Every
  GlazeWM workspace on this monitor, side by side over a dimmed, blurred screen, each a small screen with its windows
  where GlazeWM put them, live. Click a window to go to it, click a workspace to go there, drag a window onto
  another workspace to move it, middle click to close. Arrows, Tab and Enter pick a workspace; 1 to 9 go straight
  to one; Esc or a click beside the cards closes. Minimized windows sit as icons under their workspace; click one
  to restore it.
  - The pictures are Windows' own live window previews (DWM thumbnails, as in Alt+Tab and the taskbar's hover
    previews), through yasb's `WindowThumbnail`. Nothing is captured, saved or polled, and it does nothing while
    closed. This replaces the panorama overview from the `florensm/yasb` fork, which needed a Python service of its
    own and took a screenshot every 5 seconds.
  - Settings at the top of the file: `hotkey`, `allMonitors`, `showEmptyWorkspaces`, `livePreviews: false` (icons
    and titles only), `showWallpaper`, `maxColumns`.
  - If GlazeWM hides windows with `hide_method: hide` instead of cloaking, the other workspaces' windows show their
    icon and title instead of a picture.

## What changed from v23

- **GlazeWM's windows in Search.** Press `` Alt+` `` (or type `ws` and a space in Search) and the results become
  your GlazeWM workspaces with their windows under them, in GlazeWM's order. The window you used before the current
  one is selected, so `` Alt+` `` then Enter takes you back to it. Typing searches window titles, apps and workspace
  names, best match first; several words must all match (`code 3`). Floating, minimized and fullscreen windows are
  marked; while searching, each window shows its workspace.
  - **Enter**: go there. GlazeWM switches to the window's workspace and focuses it (a minimized one is restored).
    On a workspace row, switches to that workspace (empty ones are listed too).
  - **Shift+Enter**: bring the window to the workspace you were on. On a workspace row: send the window you were
    on to that workspace.
  - **Ctrl+W** or middle click: close the window. **Esc** or Backspace past the `ws` chip: back to normal search.
  - Windows GlazeWM doesn't manage come last, under "Other windows", and are brought up through Windows. If GlazeWM
    isn't running, the list is every window, from Windows.
  - Settings at the top of `widgets/QuickLaunch/QuickLaunch.qml`: `walkerPrefix`, `walkerHotkey` (`""` for none),
    `glazewmUri`. The logic is in `widgets/QuickLaunch/GlazeWalker.qml`, the rows in `WalkerList.qml`. yasb's own
    `win` provider is still there (off); it knows nothing about workspaces, so it would pull windows out from under
    GlazeWM.
- **The workspace bubble beside every island.** Switching workspaces no longer replaces what the island shows: the
  music, the window title, a notification or a call stay, and the workspace's number and name spring out beside it
  for a moment; flicking on to the next one pops the number. Only when the island is empty does the workspace take
  its place. `workspaceChange: "replace"` at the top of `widgets/Island/Island.qml` brings the old behaviour back
  (except during calls); `bubbleSide` still picks the side.
- **Fits the current `feat/qtquick-migration`** (checked against `aeac013`). Only `widgets/Power/Power.qml` needed a
  change: yasb's PowerMenu now keeps its options in `settings`. Power isn't on your bar, so nothing changes visibly.
- Hotkeys show as symbols: Search is `Alt+/` instead of `Alt+Slash`.

To install, follow the steps below; if you're coming from v23, copying the `panel`, `widgets` folders and
`README.md` over is enough. Restart yasb once.

## Install

1. Back up your config folder (usually `%USERPROFILE%\.config\yasb`), for example by copying it to `yasb-backup`.
2. In the config folder, **delete** the `layouts`, `themes`, `panel` and `widgets` folders. Then copy everything in
   this folder into it. Your `theme.ini` stays where it is, so your last wallpaper colours are kept. (`notes.ini`
   stays too, but nothing reads it any more.)
3. Replace the `gaps` section in GlazeWM's config with the one in `glazewm-gaps.yaml`: every outer gap is now
   20px, because the bar reserves its own space (see below).
4. Restart yasb once: new layout, theme and font files are only read at start.

To undo: copy your backup back, and put back your old `gaps`.

## What changed from v21

- **A top bar** in place of the left strip. It is 32 px tall, full width, and holds every widget. The frame
  around the screen is off. To bring it back (4 px, with rounded inner corners), see the comment above the frame
  bars in `config.yaml`.
- **The bar acts like Windows' taskbar**: it has `reserve_space: true`, so Windows takes its space out of the
  screen's work area. GlazeWM tiles below it and re-tiles when it changes, maximized windows stop at the bar
  instead of going under it, and GlazeWM's outer gaps are 20px: windows sit 52px from the top and 20px from the
  other edges. While GlazeWM switches workspaces, the sliding windows are cut off at the bar's edge rather than
  passing under it, which looks the same since the bar is solid.
- **A rounded font**: M PLUS Rounded 1c, in `fonts/`. The theme loads it from there, so nothing needs installing.
  Licence: SIL Open Font License (`fonts/OFL.txt`).
- **Panels float under the bar** as rounded, blurred cards, right under the button you clicked, in the same style
  and with the same gap as the calendar and the power menu, instead of sliding out of the side. Each widget opens
  its own; there's no Tab switching between them any more.
- **New widgets**: `Island` (the middle), `Divider` (the dim `//`), `Keyboard` (the layout, such as `EN`).
- **Removed**: `Overview` and `Notes`, and their hotkeys.
- **Changed for a text-first bar**: workspaces are rings, Performance shows `CPU 15%  RAM 50%`, Weather shows the
  sky and `12°`, Sound shows the speaker and `27%` (what's playing moved to the island), and the clock reads
  `Fri 6 Nov  20:43`. Every button shares one hover pill (`panel/BarButton.qml`).

## The bar

From left to right:

- `GlazewmWorkspaces`: a ring per workspace. Empty: thin and dim. With windows: thicker. Shown on another monitor:
  a dot inside. Focused: filled in the accent. Always rings, whatever names the workspaces have in GlazeWM
  (`ringNames: true` in the file shows those names instead). Scroll over it to switch workspaces. `style: "numbers"` or `"dots"`
  in the file brings back the other looks.
- `//`, then `Performance`: `CPU 15%  RAM 50%`. Click for the Performance panel.
- **The island**, in the middle. It shows one thing at a time and springs to fit it:
  - a new notification, for 5 seconds, with a glow. Click to open Notifications.
  - what's playing: the cover, title and artist, and a thin line along the bottom for the position. Hover for
    previous, play/pause and next. Click to open the Sound panel under the island; middle click to play or pause.
  - otherwise the focused window's icon and title.
- `QuickLaunch` (search), `Weather`, `Wallpapers`, `Sound`, `Notifications` (bell, with a count), the tray, `//`,
  the clock (click for the calendar, right click for the other format), `//`, `Keyboard` (click for the next
  layout; lights up while Caps Lock is on), `Power`.

Order and grouping are in `config.yaml`. `Taskbar` (window icons) is still in `widgets/` if you want it back: add
`"Taskbar"` after `"Divider"` in `left`.

## The panel

Search, Performance, Weather, Wallpapers, Sound and Notifications each open their own panel: a floating card under
the button that opened it, staying inside the screen. One shows at a time, so opening another closes the first.
Each panel's size is set in `panel/PanelBus.qml` (`panels`), and so are the open and close durations and the bar's
sizes. The open panel's button is lit; clicking it again, Esc or a click outside closes it. The hotkeys are unchanged: Notifications `Ctrl+Alt+B`, Performance
`Ctrl+Alt+P`, Search `Alt+/`, Wallpapers `Ctrl+Alt+W`, Sound `Ctrl+Alt+M`.

## Settings worth knowing

- Bar height, and the frame's width and corners: `layouts/frame.qml`. If you change them, change `PanelBus.qml`
  (same names) and the bar's `thickness` in `config.yaml` to match. The reserved space follows `thickness` by itself, so
  GlazeWM's gaps need no change.
- Font and its size: `themes/wallpaper.qml` (`bar.font`). Any font file dropped into `fonts/` can be loaded the same
  way.
- Island: `maxWidth`, `notifyDuration`, `showWindow`, `showCalls` at the top of `widgets/Island/Island.qml`.
- Clock: `dateFormat` and `timeFormat` in `widgets/Clock/Clock.qml` (`"hh:mm AP"` for 12-hour).

## Teams calls in the island

While you're in a Microsoft Teams call or meeting, the island shows it, ahead of what's playing:

`● Sam Graveland, Thijs Mulder 12:38 [mic] [hang up]`

- **How it knows:** Teams opens a window of its own for a call, titled after the people in it or the meeting
  (`Sam Graveland, Thijs Mulder | SPS | you@sps.nl | Microsoft Teams`), while its main window's title starts with the
  page it shows (`Chat | ...`, `Agenda | ...`). Such a call window means you're in a call, and its first part is the
  name in the pill. Nothing needs turning on in Teams, and nothing is run.
- **The clock** starts when the call window appears (for a meeting, that's the join screen). Teams doesn't say when
  a call began, so after restarting yasb during a call it counts from the restart.
- **The dot** is green while your microphone is live, dim while it's muted.
- **Mic button** (or middle click anywhere on the island): mutes your microphone in Windows. Nobody in the call hears
  you, but Teams' own mute button doesn't change. It mutes Windows' default microphone, so Teams should use that
  one ("Default" in Teams' device settings).
- **Hang-up button**: the first click turns it into a red "Hang up?", and a second click within 3 seconds hangs up
  by closing the call's window, as its own close button does. No keys are pressed and nothing is run.
- **A click on the island** brings the call's window to the front: the island asks GlazeWM which workspace it's on,
  switches there, focuses it, and then Windows gives it the keyboard. yasb's log says `Island: to workspace ...`,
  or that GlazeWM doesn't manage the window (then it's brought up through Windows only).
- **Switching workspaces during a call** shows the workspace (its number and name) in a small bubble of its own
  beside the island for a moment, while the call stays as it is. `bubbleSide` at the top of
  `widgets/Island/Island.qml` puts it on the `"right"` (default) or the `"left"`.

A notification or a volume change still shows for a moment, then the call comes back. When Teams lets go of the
window, the island goes back to music or the window. Whenever Teams' window titles change, yasb's log gets a line
starting with `Island: Teams windows:` with every Teams window's title and whether it counted as a call. If a call
is missed, or a chat counts as a call, send me that line. Other Teams windows that aren't calls (an
app or a SharePoint page opened in Teams, such as "Intranet") go in `ignore` at the top of
`widgets/Island/TeamsCall.qml`: any Teams window whose title contains one of those words is never a call.

To keep calls out of the island, set `showCalls: false` in
`widgets/Island/Island.qml`. The detection is in `widgets/Island/TeamsCall.qml`.

## Colours from your wallpaper

Unchanged from v21: the bar, the panel and every accent take their colours from the wallpaper. The
switch "Bar colours follow wallpaper" on the Wallpapers page turns it off.

## How this was tested

Not on Windows. Everything was loaded on Linux with Qt 6.12 offscreen, with yasb's own QML from the branch (`Bar`,
`Common`, `Themes`, `PowerMenu`) and its Windows services (media, audio, notifications, workspaces and so on)
replaced by stand-ins. Checked there: the bar renders with the font, the island switches between window,
media and notification, and the panel opens under its button and switches pages, with no QML warnings. Not
tested: anything Windows really does (DWM, hotkeys, the tray, real notifications) and how smooth it feels. If
something doesn't show up, yasb logs a line such as `Widget "Island" failed to load from ...` with the reason. Send
me that line.

The Teams part was tested with stand-in windows titled like yours: the chat window doesn't count, the call window
does and gives the name, the mic button and middle click mute, hanging up needs two clicks and goes to the call
window, and music comes back when it closes. Not tested on Windows.
