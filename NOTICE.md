# Changes this fork carries

This fork (`florensm/yasb`) runs yasb's own `feat/qtquick-migration` with a few changes on top. Each is listed here
with how to tell whether yasb already has it, so nothing is sent as a pull request that yasb no longer needs.

Before opening a pull request, or after a new yasb release, go through the list: check the release (or yasb's latest
`feat/qtquick-migration`) as described under each change. If yasb has it, or has replaced the code it touches (e.g.
in its move to C++), drop the change from the fork instead of sending it.

| Change | Branch | Based on yasb | In yasb? | Pull request |
|---|---|---|---|---|
| [Live window pictures placed in step with the frame](#live-window-pictures-placed-in-step-with-the-frame) | `perf/window-thumbnail` | `3a71a9c` (18 Nov 2026) | No, as of `3a71a9c` | None yet |

## Live window pictures placed in step with the frame

**File:** `src/core/services/taskbar/thumbnail.py` (`WindowThumbnail`), with its test in
`tests/services/test_thumbnail.py`. Its QML interface (`hwnd`, `sourceWidth`, `sourceHeight`) is unchanged.

**What it changes:** `WindowThumbnail` shows another window live through a DWM thumbnail. Before, every thumbnail,
on every frame of any animation in its window:

1. asked DWM for the size of the window it shows (a round trip to DWM, though the size rarely changes),
2. had its own handler called for the frame, and
3. handed DWM its new place as Qt *started* the frame, so DWM showed it about a frame before Qt's drawing around it
   reached the screen: pictures ran a frame ahead of everything else while they moved.

Now one placer per window measures all its thumbnails as Qt prepares a frame and hands DWM only the ones that
changed, once Qt has presented that frame (`frameSwapped`). The source size is checked at most every half second.
A thumbnail standing still costs DWM nothing per frame; a moving one, one call instead of two.

**Who gains:** everything that animates live window pictures: the Window Switcher's previews, the taskbar's hover
previews, and widgets built on `WindowThumbnail` in a config (e.g. an overview zooming between the desktop and its
windows). Still pictures look the same.

**How to tell whether yasb has it:** open `src/core/services/taskbar/thumbnail.py` in the release or branch.

- Still the old code: each `WindowThumbnail` connects `afterAnimating` to its own `_place`, and `_place` calls
  `DwmQueryThumbnailSourceSize` every time.
- Has it, or the same idea: thumbnails are placed together per window, after the frame is presented
  (`frameSwapped` or an equivalent), and the source size isn't asked every frame.
- Replaced: the file is gone or rewritten (e.g. in C++). Check that thumbnails still move in step with QML while
  animating before dropping the change.

```bash
git fetch origin feat/qtquick-migration
git log --oneline origin/feat/qtquick-migration -- src/core/services/taskbar/thumbnail.py
git diff origin/feat/qtquick-migration perf/window-thumbnail -- src/core/services/taskbar/thumbnail.py
```

(`origin` being `amnweb/yasb`.) The last command shows what the fork's version still adds.
