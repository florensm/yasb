# GlazeWM Overview Widget

A full screen overview of your GlazeWM workspaces with live window previews. Workspaces sit in a carousel, with the focused one in the middle, or all together in a grid. From the overview you can switch workspaces, jump to a window, search windows by title, close windows, and move windows between workspaces by dragging them or with the keyboard.

Window previews are live DWM thumbnails, so windows on hidden workspaces stay live too.

| Option               | Type    | Default                 | Description                                                                 |
|----------------------|---------|-------------------------|-----------------------------------------------------------------------------|
| `label`              | string  | `''`                    | Label shown on the bar.                                                     |
| `glazewm_server_uri` | string  | `'ws://localhost:6123'` | Optional GlazeWM server uri.                                                |
| `monitor_exclusive`  | boolean | `true`                  | Show only the workspaces of the monitor the overview opens on.              |
| `grid_columns`       | integer | `5`                     | Number of columns in the grid layout.                                       |
| `close_delay`        | integer | `0`                     | How long in ms the overview stays up after picking a workspace or window.   |
| `colors`             | dict    | see below               | Colors of the overview.                                                     |
| `popup`              | dict    | `{'blur': True, 'dark_mode': True}` | Popup window settings.                                          |
| `callbacks`          | dict    | `{'on_left': 'toggle_overview'}` | Callbacks for mouse events on the bar label.                      |
| `keybindings`        | list    | `[]`                    | Global keybindings, see below.                                              |

## Example Configuration

```yaml
glazewm_overview:
  type: "glazewm.overview.GlazewmOverviewWidget"
  options:
    label: "\uf2d2"
    monitor_exclusive: true
    grid_columns: 5
    close_delay: 0
    popup:
      blur: true
      dark_mode: true
    callbacks:
      on_left: "toggle_overview"
    keybindings:
      - keys: "alt+w"
        action: "toggle_overview"
        screen: active
      - keys: "alt+q"
        action: "toggle_overview_grid"
        screen: active
```

## Description of Options
- **label:** Label shown on the bar.
- **glazewm_server_uri:** Optional GlazeWM server uri if it ever changes on GlazeWM side.
- **monitor_exclusive:** If enabled (default), the overview shows only the workspaces of the monitor it opens on. If disabled, it shows the workspaces of all monitors.
- **grid_columns:** Number of columns in the grid layout.
- **close_delay:** How long in ms the overview stays up after you pick a workspace or window. Set it to GlazeWM's `workspace_switch` animation duration to let that animation finish behind the overview.
- **colors:** Colors of the overview:
  - **accent:** Selection and highlight color. Empty uses the Windows accent color.
  - **base:** Darkest background color, used for captions.
  - **bg:** Card background.
  - **surface:** Window tile background and hovered card background.
  - **text:** Main text color.
  - **subtext:** Secondary text color.
  - **blue:** Border color of search matches.
  - **scrim:** Color of the dim layer behind the cards, as `#AARRGGBB`. The alpha sets how dark it gets (default `#99000000`, 60% black).
- **popup:** Popup window settings:
  - **blur:** Enable blur behind the overview.
  - **dark_mode:** Use the dark blur style.
- **callbacks:** Callbacks for mouse events on the bar label. Available callbacks: `toggle_overview`, `toggle_overview_grid`.
- **keybindings:** Global keybindings. Available actions:
  - `toggle_overview`: open the overview as a carousel, or close it.
  - `toggle_overview_grid`: open the overview as a grid, or close it.

  `screen` sets which monitor the overview opens on: `active`, `cursor` or `primary`.

## Using the Overview

The overview has three steps: browsing workspaces, picking a window in a workspace, and carrying a window to another workspace. A hint line under the cards always shows the keys for the current step.

### Keyboard
| Key                  | Action                                                                  |
|----------------------|-------------------------------------------------------------------------|
| `←` `→` / `h` `l`    | Select the previous or next workspace. Inside a workspace, select a window. |
| `↑` `↓` / `k` `j`    | Move a row in the grid. Inside a workspace, select a window.             |
| `Home` / `End`       | Select the first or last workspace.                                     |
| `1`-`9`, `0`         | Switch to that workspace (`0` is the 10th). While carrying a window, select it instead. |
| `Enter`              | Switch to the selected workspace, or jump to the selected window.       |
| `Space`              | Look inside the selected workspace, pick up the selected window, or drop the carried window on the selected workspace. |
| `Backspace`          | Go one step back.                                                       |
| `Tab`                | Switch between carousel and grid.                                       |
| `/`                  | Search windows by title or process name.                                |
| `n` / `N`            | Jump to the next or previous search match.                              |
| `x`                  | Close the selected window (inside a workspace).                          |
| `Esc`                | Close the overview.                                                     |

### Mouse
- **Click a workspace:** switch to it.
- **Click a window:** jump to it.
- **Drag a window onto a workspace:** move it there. Hold it near the screen edge to scroll the carousel.
- **Middle click a window:** close it.
- **Scroll:** select the previous or next workspace.
- **Click the background:** close the overview.

## Style
```css
.glazewm-overview-widget {} /* Style for the widget on the bar. */
.glazewm-overview-widget .widget-container {} /* Style for the widget container. */
.glazewm-overview-widget .label {} /* Style for the label. */
.glazewm-overview {} /* The overview itself. Only font-family is used, for all its text. */
```

The overview is painted by the widget, so apart from its font it is styled through the `colors` option, not CSS.

## Example CSS
```css
.glazewm-overview {
    font-family: "JetBrainsMono NFP";
}

.glazewm-overview-widget .label {
    font-size: 14px;
    padding: 0 6px;
    color: #cdd6f4;
}
```
