pragma ComponentBehavior: Bound

import QtQuick
import Yasb

// Whether you're in a Microsoft Teams call, from Teams' windows: nothing to turn on in Teams, nothing to run.
//
// The new Teams names its windows "<what> | <organisation> | <your address> | Microsoft Teams". The main window's
// <what> starts with the page it shows ("Chat | Sam Graveland", "Calendar", "Activiteit", ...); the call's window is
// just the call: the people in it ("Sam Graveland, Thijs Mulder") or the meeting's name. So a Teams window whose
// <what> isn't a page is the call. The clock starts when that window first appears. Every change in Teams' window
// titles is written to YASB's log ("Island: Teams windows"), to see what Teams calls its windows.
Item {
    id: teams

    // false stops looking
    property bool active: true
    // The first part of a title that marks Teams' main window or a page of it, in English and Dutch
    property var pages: ["activity", "activiteit", "chat", "chats", "teams", "calendar", "agenda", "calls", "oproepen",
        "gesprekken", "files", "bestanden", "onedrive", "apps", "help", "settings", "instellingen", "people", "personen",
        "communities", "community", "copilot", "planner", "meet", "vergaderen", "notifications", "meldingen",
        "microsoft teams", "search", "zoeken"]
    // Your own Teams windows that are never a call, such as an app or a page opened in Teams: a window whose title
    // contains one of these (capitals don't matter) is left alone. Add your own, for example "Contact Center"
    property var ignore: ["intranet", "Contact"]

    readonly property var teamsWindows: (windowList.windows ?? []).filter(window => /^(ms-teams|teams)\.exe$/i.test(window.process ?? ""))
    // The call's window, or null
    readonly property var window: teamsWindows.find(window => isCall(window.title ?? "")) ?? null
    // Teams' main window, to bring up when there's no call window
    readonly property var mainWindow: teamsWindows.find(window => window !== teams.window) ?? null
    // The people in the call or the meeting's name, as Teams writes it in the title
    readonly property string name: window ? what(window.title) : ""

    readonly property bool inCall: active && window !== null
    // When the call's window appeared; the epoch while not in a call
    property date since: new Date(0)

    // "<what> | SPS | name@sps.nl | Microsoft Teams" -> "<what>"
    function what(title: string): string {
        const parts = title.split(" | ").map(part => part.trim())
        if (parts.length > 0 && /^microsoft teams$/i.test(parts[parts.length - 1]))
            parts.pop()
        // The account and the organisation before it
        const account = parts.findIndex(part => part.includes("@"))
        if (account > 0)
            parts.splice(account - 1)
        return parts.join(" | ")
    }

    function isCall(title: string): bool {
        if (!/\|\s*Microsoft Teams\s*$/i.test(title))
            return false
        const lower = title.toLowerCase()
        if (ignore.some(part => part !== "" && lower.includes(String(part).toLowerCase())))
            return false
        const first = what(title).split(" | ")[0].toLowerCase()
        return first !== "" && !pages.includes(first)
    }

    WindowList {
        id: windowList
    }

    function switchTo(hwnd: int): void {
        windowList.switchTo(hwnd)
    }

    function inFront(hwnd: int): bool {
        return windowList.inFront(hwnd)
    }

    // Leaves the call as the call window's close button does
    function hangUp(): bool {
        if (!window)
            return false
        windowList.close(window.hwnd)
        return true
    }

    onInCallChanged: since = inCall ? new Date() : new Date(0)
    // The window list fills in a moment after start
    Component.onCompleted: {
        if (inCall)
            since = new Date()
    }

    // To see in YASB's log what Teams calls its windows, should the call go unnoticed
    property string titles: teamsWindows.map(window => window.title).join("  /  ")
    onTitlesChanged: console.info("Island: Teams windows:", titles === "" ? "(none)" : titles, "->",
                                 window ? `call "${name}"` : "no call")
}
