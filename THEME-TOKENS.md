# This setup's design

Everything here lives in the config folder and works on YASB as it is (feat/qtquick-migration upstream), with no
changes to YASB itself. Widgets work as before; a theme file only styles them.

## Themes and tokens

- A theme file is YASB's `Theme` (colours, bar, popup, menu) plus this setup's own `tokens` object for the shapes
  YASB has no place for. A theme without them keeps the usual look.
- `panel/PanelBus.qml` reads the tokens, each with a fallback: `radiusScale` (fixed radii are multiplied by it: 0 is
  square), `pill`, `borderWidth`, `cardBorderWidth`, `cardShadowOffset`, `selectedBorderWidth`, `dividerWidth`,
  `shadowOffset` and `shadowColor` (a hard shadow), `headerBackground`, `headerText`, `selectedText`,
  `headingCapitalization`, `openScale`, `openEasing`, `closeEasing`, and for sliders and switches `trackHeight`,
  `handleSize`, `controlBorderWidth` and `controlShadowOffset`.
- `fonts/SpaceGrotesk.ttf` (SIL Open Font License, `fonts/OFL-SpaceGrotesk.txt`): the neobrutalism theme loads it
  from there, so nothing needs installing.

## Shared parts in panel/

- `PanelSurface` (the panels' card), `PopupFace` (the calendar's and the island card's face), `PanelSlider`,
  `PanelSwitch`: all shaped by the tokens.
- `Icon`: this setup's line icons on a 16 px grid with a 1 px line, drawn as SVG so they look the same in every window
  and at the screen's scaling. `BarButton` draws a glyph that has one (`PanelBus.glyphIcons`) as that icon.
- `PanelHost`: Search and Wallpapers open in the middle of the screen (`centered: true` in `PanelBus.panels`), the
  other panels under their button; a title band in the theme's header colours.
- Another program coming to the front closes the open panel, the calendar and the island's card
  (`PanelBus.otherAppActivated`, from YASB's `ActiveWindowTracker`).

## Widgets

- `Island`: the dynamic island. Folded it shows a volume or GlazeWM workspace change for a moment, a new
  notification, what's playing, or the focused window. Hovering, or clicking, unfolds a card under the bar where you
  seek, set the volume, skip, or dismiss or open a notification. The card never takes the keyboard from the app in
  use. Switching between what it shows is a quick fade out, then a soft fade and grow in, while the width springs.
- `Weather` shows a line icon for the sky on the bar; its panel keeps its pictures.
- `Power` shows the power line icon. `Keyboard` is off the bar in `config.yaml` (its file is still here).

## Control center

- `widgets/ControlCenter` replaces Power on the bar (`config.yaml`), and opens with its button or Ctrl+Alt+C.
- Tiles: Dark (Windows' light or dark mode), Do not disturb, Night light (Windows has no API for it, so the tile opens
  its settings page), Wi-Fi, Bluetooth, Mute.
- Brightness for each display YASB can control, and the volume (click the speaker to mute).
- Style: every theme file in `themes/` (names starting with `_` are left out). Picking one writes `theme:` in `config.yaml`
  with PowerShell, and YASB reloads with it.
- Colours: a colour scheme over whichever style is on (`panel/ColorSchemes.qml`): Theme (the style's own colours),
  Wallpaper (built from the wallpaper by `panel/WallpaperColors.qml`), Slate, Ember, Moss, Mono, Catppuccin, Nord,
  Gruvbox, Tokyo Night and Rosé Pine, each in a dark and a light version that follows Windows. A scheme sets the base
  colours (background, text, accent); the style keeps its shape and outlines. Remembered in `control-center.ini`.
- Bar: Full (across the screen), Floating (one card clear of its edges) or Islands (a card around each group of
  widgets), drawn by `layouts/frame.qml`; set at once and remembered in `control-center.ini`.
- Bar accent: Off (icons in the text colour), Icons (the bar's icons and the clock's time in the accent) or Tinted
  (also a light accent fill behind each button). Remembered in `control-center.ini`; Icons is the default.
- Corners: Theme (the theme's own), Square, Sharp, Soft or Round, on top of whichever theme is on. Set at once and
  remembered in `control-center.ini` in the config folder.
- Power: Lock, Sleep, Sign out, Restart, Shut down. The last three turn red and ask for a second click.

## Themes

`themes/` has fluent, minimal, tonal, material, ios, terminal and neobrutalism. Each is a plain YASB
theme with its own `tokens`; copy one to start your own.

## Wallpapers

- `widgets/Wallpapers/Wallpapers.qml` opens in the middle of the screen (Ctrl+Alt+W, or its bar button; right click
  sets a random wallpaper). A large view shows the wallpaper under the pointer, or the one on your desktop, with the
  colours it gives. Search by name, Shuffle, and a grid of every wallpaper in your folders, the current one marked.
  A click or Enter sets it, and the panel stays open to try another; arrow keys move, Escape closes.
- Transition: Circle, Slide, Diamond, Split or None, YASB's own desktop transitions; remembered in
  `control-center.ini`. "Theme takes its colours" turns the Wallpaper colour scheme on or off.
- The old wheel version is gone; `Wallpapers2.qml` is your earlier copy and is not on the bar.

## Calendar (Clock)

- `widgets/Clock` opens a calendar: the month with arrows, the selected day and its week number, a dot under each day
  for every calendar with something on it, the selected day's events (click a day to see its own), and the time to
  the second. Names are English unless the widget's `locale` says otherwise.
- Calendars come from iCal links (`.ics`), fetched by the popup itself every 15 minutes and on opening: no account,
  no script. Add them with the calendar button at the bottom of the popup; they are kept in `control-center.ini`
  (`[calendars]`), so treat that file as private: a secret iCal link lets anyone who has it read the calendar.
  - Google Calendar: Settings, your calendar, Integrate calendar, "Secret address in iCal format" (a work account's
    admin can turn this off).
  - Outlook: Settings, Calendar, Shared calendars, Publish a calendar, the ICS link.
  - Samsung Calendar has no link of its own: sync it with a Google or Microsoft account on the phone and add that one.
- Read only. Times with a time zone (TZID) are taken as your local time, which is right for calendars in your own zone.
  `widgets/Clock/ics.js` reads the feed.

## Sound

- `widgets/Sound` opens a panel with what's playing (cover, track, position, shuffle, previous, play, next, repeat),
  the output device (click it to list the others; switching asks once more), the master volume, every app's volume
  (a click on an app's icon mutes it; the playing app has an accent bar) and Windows' sound settings.

## Colours for other apps (GlazeWM)

`panel/PanelBus.qml` writes the colours in use to `yasb_colors.css` in the config folder whenever they change (a
theme, a colour scheme, light or dark, the wallpaper's colours), as CSS variables: `--yasb-background`, `-surface`,
`-raised`, `-border`, `-divider`, `-hover`, `-selected`, `-text`, `-text-dim`, `-text-faint`, `-accent`,
`-on-accent`, `-success`, `-warning`, `-critical`. GlazeWM reads one with
`color: { file: "C:/Users/<you>/.config/yasb/yasb_colors.css", key: "--yasb-accent" }`.
