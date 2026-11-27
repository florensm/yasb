import QtQuick
import Yasb.Themes

// Fluent: Windows 11's own look: YASB's default colours and corners, glass with blur. It follows Windows' light and dark mode: a value written as "dark ? A : B" is A in dark mode and B in
// light mode. The `tokens` at the end are this setup's shapes (see panel/PanelBus.qml); YASB itself ignores them.
Theme {
    // Everything as YASB's default theme; only the font is set

    bar {
        font.family: "Segoe UI"
    }
}
