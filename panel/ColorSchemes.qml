pragma Singleton

import QtQuick

// Colour schemes the control center lays over whichever theme (style) is on. Each sets the base colours, in a dark
// and a light version: the background, the text and the accent, plus the text on the accent. The theme keeps its
// shape and its own outlines. "wallpaper" builds the colours from the wallpaper (panel/WallpaperColors.qml).
QtObject {
    id: schemes

    // name, label, and for each mode: background, text ("ink"), accent and the text on it
    readonly property var list: [
        { name: "slate", label: "Slate",
          dark: { bg: "#1A1D24", ink: "#E7EAF0", accent: "#8AB4F8", on: "#0E1420" },
          light: { bg: "#EDF0F4", ink: "#18202E", accent: "#2F5BB7", on: "#FFFFFF" } },
        { name: "ember", label: "Ember",
          dark: { bg: "#1D1916", ink: "#F4ECE4", accent: "#F2A65A", on: "#1D1209" },
          light: { bg: "#F5F0EA", ink: "#2A1F17", accent: "#B5531A", on: "#FFFFFF" } },
        { name: "moss", label: "Moss",
          dark: { bg: "#161B18", ink: "#E5EEE8", accent: "#7FCF9E", on: "#0B1A11" },
          light: { bg: "#EDF2EE", ink: "#16241B", accent: "#24774B", on: "#FFFFFF" } },
        { name: "mono", label: "Mono",
          dark: { bg: "#111111", ink: "#F5F5F5", accent: "#F5F5F5", on: "#111111" },
          light: { bg: "#FAFAFA", ink: "#111111", accent: "#111111", on: "#FAFAFA" } },
        { name: "catppuccin", label: "Catppuccin",
          dark: { bg: "#1E1E2E", ink: "#CDD6F4", accent: "#CBA6F7", on: "#1E1E2E" },
          light: { bg: "#EFF1F5", ink: "#4C4F69", accent: "#8839EF", on: "#EFF1F5" } },
        { name: "nord", label: "Nord",
          dark: { bg: "#2E3440", ink: "#ECEFF4", accent: "#88C0D0", on: "#2E3440" },
          light: { bg: "#ECEFF4", ink: "#2E3440", accent: "#5E81AC", on: "#ECEFF4" } },
        { name: "gruvbox", label: "Gruvbox",
          dark: { bg: "#282828", ink: "#EBDBB2", accent: "#FABD2F", on: "#282828" },
          light: { bg: "#FBF1C7", ink: "#3C3836", accent: "#B57614", on: "#FBF1C7" } },
        { name: "tokyonight", label: "Tokyo Night",
          dark: { bg: "#1A1B26", ink: "#C0CAF5", accent: "#7AA2F7", on: "#1A1B26" },
          light: { bg: "#E1E2E7", ink: "#3760BF", accent: "#2E7DE9", on: "#FFFFFF" } },
        { name: "rosepine", label: "Rosé Pine",
          dark: { bg: "#191724", ink: "#E0DEF4", accent: "#EBBCBA", on: "#191724" },
          light: { bg: "#FAF4ED", ink: "#575279", accent: "#D7827E", on: "#FAF4ED" } }
    ]

    function find(name: string): var {
        return list.find(scheme => scheme.name === name) ?? null
    }

    // The theme colours a scheme sets, by name, for dark or light mode; null for "" (the theme's own) or an unknown
    // name. `wallpaper` is panel/WallpaperColors, for the "wallpaper" scheme
    function colours(name: string, dark: bool, wallpaper: var): var {
        if (name === "wallpaper") {
            return {
                background: wallpaper.bar, text: wallpaper.text, textSecondary: wallpaper.textDim,
                textTertiary: Qt.alpha(wallpaper.textDim, 0.75), textDisabled: Qt.alpha(wallpaper.textDim, 0.55),
                accent: wallpaper.accent, textOnAccent: wallpaper.onAccent
            }
        }
        const scheme = find(name)
        if (!scheme)
            return null
        const mode = dark ? scheme.dark : scheme.light
        return {
            background: mode.bg, text: mode.ink,
            textSecondary: Qt.alpha(mode.ink, dark ? 0.77 : 0.66),
            textTertiary: Qt.alpha(mode.ink, dark ? 0.53 : 0.5),
            textDisabled: Qt.alpha(mode.ink, 0.36),
            accent: mode.accent, textOnAccent: mode.on
        }
    }

    // Two colours for a scheme's swatch: its background and its accent
    function swatch(name: string, dark: bool, wallpaper: var): var {
        const c = colours(name, dark, wallpaper)
        return c ? [c.background, c.accent] : null
    }
}
