pragma ComponentBehavior: Bound

import QtQuick
import QtWebSockets
import Yasb

// GlazeWM's workspaces and windows for Search's `ws` prefix (QuickLaunch.qml), read from GlazeWM's IPC server, and
// what Enter, Shift+Enter and Ctrl+W do with them. WalkerList.qml draws the rows.
//
// With nothing typed the rows are grouped by workspace, in GlazeWM's order, with the window you used before this one
// selected, so the hotkey and Enter take you back to it. Typing searches the windows' titles and apps and the
// workspaces' names, best match first; several words must all match ("code 3" is a Code window on workspace 3).
// Windows GlazeWM doesn't manage (ones its config ignores, or all of them while GlazeWM isn't running) come last,
// under "Other windows", and are brought up through Windows instead.
Item {
    id: walker

    property string serverUri: "ws://localhost:6123"
    // While Search shows these rows: data is only asked of GlazeWM then
    property bool open: false
    // Workspaces without windows, to jump to them; GlazeWM only keeps the ones it is told to keep alive
    property bool showEmptyWorkspaces: true
    // Windows GlazeWM doesn't manage, under "Other windows"
    property bool showUnmanaged: true
    // Apps to leave out, by process name with or without .exe, such as ["Spotify"]
    property var ignoreProcesses: []

    readonly property bool connected: socket.status === WebSocket.Open

    // GlazeWM's last answer: [{ name, label, focused, displayed, monitor, windows: [row] }], in order
    property var workspaces: []
    property int monitorCount: 1
    // The workspace and the window that had GlazeWM's focus when the walker opened
    property string focusedWorkspace: ""
    property string focusedWindow: ""
    // The rows the list shows, and the selected one
    property var rows: []
    property int current: -1
    readonly property var selected: rows[current] ?? null
    property string query: ""
    // Each window's place front to back when the walker opened, by hwnd: recently used first
    property var zOrder: ({})
    // Events while closed only mark the data stale; it is asked for again on opening
    property bool stale: true
    // The window GlazeWM was asked to focus, which then gets the keyboard from Windows too
    property real pendingKeyboard: 0
    // Whether you have typed or moved since opening: until then GlazeWM's fresh answer picks the selection again
    property bool touched: false

    // Each window's icon by hwnd, from yasb's window list; the provider's URL for one it doesn't track
    readonly property var icons: {
        const map = {}
        for (const window of windowList.windows ?? [])
            map[window.hwnd] = window.icon
        return map
    }
    function iconOf(hwnd: real): string {
        return hwnd ? (icons[hwnd] ?? `image://icon/window/${hwnd}/0`) : ""
    }

    // Search closes after Enter
    signal closeRequested

    // Called as Search starts showing the rows: the z-order now is "recently used"
    function start() {
        const order = {}
        ;(windowList.windows ?? []).forEach((window, index) => order[window.hwnd] = index)
        zOrder = order
        touched = false
        rebuild(false)
        if (connected)
            send("query monitors")
    }

    function search(text: string) {
        touched = touched || text !== ""
        query = text
        rebuild(false)
    }

    // A YASB window that opened from a hotkey needs Windows to give it the keyboard
    function takeFocus(window: var) {
        windowList.takeFocus(window)
    }

    function send(message: string) {
        if (connected)
            socket.sendTextMessage(message)
    }

    // ---- GlazeWM's tree into rows

    function naturalKey(name: string): var {
        return String(name).split(/(\d+)/).map(part => /^\d+$/.test(part) ? Number(part) : part.toLowerCase())
    }
    function naturalCompare(a: string, b: string): int {
        const left = naturalKey(a)
        const right = naturalKey(b)
        for (let i = 0; i < Math.min(left.length, right.length); i++) {
            if (left[i] === right[i])
                continue
            if (typeof left[i] === typeof right[i])
                return left[i] < right[i] ? -1 : 1
            return typeof left[i] === "number" ? -1 : 1
        }
        return left.length - right.length
    }

    function processName(name: string): string {
        return String(name ?? "").replace(/\.exe$/i, "")
    }
    function ignored(process: string): bool {
        const name = processName(process).toLowerCase()
        return (ignoreProcesses ?? []).some(entry => processName(entry).toLowerCase() === name)
    }

    function collect(container: var, into: var): var {
        for (const child of container?.children ?? []) {
            if (child.type === "window")
                into.push(child)
            else
                collect(child, into)
        }
        return into
    }

    function readMonitors(monitors: var) {
        // Numbered left to right, then top to bottom
        const sorted = monitors.slice().sort((a, b) => (a.x ?? 0) - (b.x ?? 0) || (a.y ?? 0) - (b.y ?? 0))
        const list = []
        let focusWorkspace = ""
        let focusWindow = ""
        sorted.forEach((monitor, monitorIndex) => {
            for (const workspace of monitor.children ?? []) {
                if (workspace.type !== "workspace")
                    continue
                const name = String(workspace.name ?? "")
                const label = workspace.displayName && workspace.displayName !== name ? String(workspace.displayName) : ""
                if (workspace.hasFocus)
                    focusWorkspace = name
                const windows = []
                for (const window of collect(workspace, [])) {
                    if (window.hasFocus)
                        focusWindow = window.id
                    if (ignored(window.processName))
                        continue
                    windows.push({
                        kind: "window",
                        key: window.id,
                        id: window.id,
                        hwnd: window.handle ?? 0,
                        title: window.title || processName(window.processName) || qsTr("Untitled"),
                        process: processName(window.processName),
                        state: window.state?.type ?? "tiling",
                        focused: window.hasFocus === true,
                        workspace: name,
                        workspaceLabel: label,
                        managed: true
                    })
                }
                list.push({
                    name: name,
                    label: label,
                    focused: workspace.hasFocus === true,
                    displayed: workspace.isDisplayed === true,
                    monitor: monitorIndex + 1,
                    windows: windows
                })
            }
        })
        list.sort((a, b) => naturalCompare(a.name, b.name))
        workspaces = list
        monitorCount = Math.max(1, sorted.length)
        // yasb's own windows aren't GlazeWM's, so while the walker is open this is still the window you were on
        focusedWorkspace = focusWorkspace
        focusedWindow = focusWindow
        stale = false
        rebuild(touched)
    }

    function workspaceRow(workspace: var): var {
        return {
            kind: "workspace",
            key: "workspace:" + workspace.name,
            name: workspace.name,
            label: workspace.label,
            focused: workspace.focused,
            displayed: workspace.displayed,
            monitor: workspace.monitor,
            count: workspace.windows.length
        }
    }

    // Windows yasb knows of that GlazeWM doesn't manage: all of them while GlazeWM isn't running
    function unmanagedRows(): var {
        if (connected && !showUnmanaged)
            return []
        const managed = new Set()
        for (const workspace of workspaces)
            for (const window of workspace.windows)
                managed.add(window.hwnd)
        return (windowList.windows ?? [])
            .filter(window => !managed.has(window.hwnd) && !ignored(window.process))
            .map(window => ({
                kind: "window",
                key: "hwnd:" + window.hwnd,
                id: "",
                hwnd: window.hwnd,
                title: window.title || processName(window.process),
                process: processName(window.process),
                state: window.minimized ? "minimized" : "",
                focused: false,
                workspace: "",
                workspaceLabel: "",
                managed: false
            }))
    }

    function grouped(): var {
        const out = []
        if (connected) {
            for (const workspace of workspaces) {
                if (!showEmptyWorkspaces && workspace.windows.length === 0 && !workspace.focused)
                    continue
                out.push(workspaceRow(workspace))
                out.push(...workspace.windows)
            }
        }
        const others = unmanagedRows()
        if (others.length > 0) {
            if (connected)
                out.push({ kind: "heading", key: "heading:other", title: qsTr("Other windows") })
            out.push(...others)
        }
        return out
    }

    // How well `needle` (lower case) matches `text`: 0 for not at all. A run of it in the text scores best, more so
    // at a word's start; otherwise its letters in order, more for letters next to each other or starting words
    function score(text: string, needle: string): real {
        const haystack = String(text ?? "").toLowerCase()
        if (!needle || !haystack)
            return 0
        const wordStart = at => at === 0 || /[\s\-_.|:\/\\(\[]/.test(haystack[at - 1])
        const at = haystack.indexOf(needle)
        if (at >= 0)
            return 100 + (wordStart(at) ? 40 : 0) + (at === 0 ? 20 : 0) + (haystack === needle ? 40 : 0) - Math.min(at, 30) * 0.5
        let from = 0
        let total = 0
        let run = 0
        for (const letter of needle) {
            const found = haystack.indexOf(letter, from)
            if (found < 0)
                return 0
            run = found === from && from > 0 ? run + 1 : 0
            total += 2 + run * 3 + (wordStart(found) ? 4 : 0) - Math.min(found - from, 8) * 0.25
            from = found + 1
        }
        return Math.max(1, total * 60 / (needle.length * 10))
    }

    function ranked(text: string): var {
        const terms = text.toLowerCase().split(/\s+/).filter(term => term !== "")
        const matches = []
        const consider = (row, fields) => {
            let total = 0
            for (const term of terms) {
                let best = 0
                for (const [value, weight] of fields)
                    best = Math.max(best, score(value, term) * weight)
                if (best <= 0)
                    return
                total += best
            }
            matches.push({ row: row, score: total })
        }
        if (connected) {
            for (const workspace of workspaces) {
                consider(workspaceRow(workspace), [[workspace.name, 1.2], [workspace.label, 1.0], ["workspace", 0.3]])
                for (const window of workspace.windows)
                    consider(window, [[window.title, 1.0], [window.process, 0.9], [window.workspace, 0.6],
                                      [window.workspaceLabel, 0.6]])
            }
        }
        for (const window of unmanagedRows())
            consider(window, [[window.title, 1.0], [window.process, 0.9]])
        const rank = row => row.kind === "window" ? (zOrder[row.hwnd] ?? 9999) : 9999
        matches.sort((a, b) => b.score - a.score || rank(a.row) - rank(b.row))
        return matches.map(match => match.row)
    }

    // With nothing typed: the window used before the current one, as Alt+Tab would pick
    function defaultIndex(list: var): int {
        let best = -1
        let bestRank = Infinity
        let focused = -1
        list.forEach((row, index) => {
            if (row.kind !== "window")
                return
            if (row.focused || (focusedWindow !== "" && row.id === focusedWindow)) {
                focused = index
                return
            }
            const rank = zOrder[row.hwnd]
            if (rank !== undefined && rank < bestRank) {
                best = index
                bestRank = rank
            }
        })
        if (best >= 0)
            return best
        if (focused >= 0)
            return focused
        return list.findIndex(row => row.kind !== "heading")
    }

    // keep: stay on the selected row when it's still there, as when GlazeWM's data changes while the walker is open
    function rebuild(keep: bool) {
        const key = keep ? (selected?.key ?? "") : ""
        const searching = query.trim() !== ""
        const list = searching ? ranked(query) : grouped()
        rows = list
        let index = key ? list.findIndex(row => row.key === key) : -1
        if (index < 0)
            index = searching ? (list.length > 0 ? 0 : -1) : defaultIndex(list)
        current = index
    }

    function select(step: int) {
        if (rows.length === 0)
            return
        let index = current
        for (let i = 0; i < rows.length; i++) {
            index = Math.max(0, Math.min(rows.length - 1, index + step))
            if (rows[index].kind !== "heading")
                break
        }
        if (rows[index].kind !== "heading") {
            current = index
            touched = true
        }
    }

    // ---- What a row does

    function activate(row: var) {
        if (!row || row.kind === "heading")
            return
        closeRequested()
        if (row.kind === "workspace") {
            send(`command focus --workspace ${row.name}`)
            return
        }
        if (!row.managed || !connected) {
            windowList.switchTo(row.hwnd)
            return
        }
        if (row.state === "minimized")
            send(`command --id ${row.id} toggle-minimized`)
        // GlazeWM switches to the window's workspace first, as focusing a window alone can leave the old one showing
        if (row.workspace !== focusedWorkspace)
            send(`command focus --workspace ${row.workspace}`)
        send(`command focus --container-id ${row.id}`)
        giveKeyboard(row.hwnd)
    }

    function bringHere(row: var) {
        if (!row || row.kind === "heading" || !connected)
            return
        if (row.kind === "workspace") {
            // The window you were on goes to that workspace; you stay where you are
            if (focusedWindow === "" || row.name === focusedWorkspace)
                return
            closeRequested()
            send(`command --id ${focusedWindow} move --workspace ${row.name}`)
            return
        }
        if (!row.managed) {
            activate(row)
            return
        }
        closeRequested()
        if (row.state === "minimized")
            send(`command --id ${row.id} toggle-minimized`)
        if (focusedWorkspace !== "" && row.workspace !== focusedWorkspace)
            send(`command --id ${row.id} move --workspace ${focusedWorkspace}`)
        send(`command focus --container-id ${row.id}`)
        giveKeyboard(row.hwnd)
    }

    function closeWindow(row: var) {
        if (row?.kind !== "window")
            return
        // The walker stays open; the window leaves the list once GlazeWM or Windows says it has gone
        if (row.managed && connected)
            send(`command --id ${row.id} close`)
        else
            windowList.close(row.hwnd)
    }

    // GlazeWM shows and focuses the window, but Windows may leave the keyboard where it was
    function giveKeyboard(hwnd: real) {
        pendingKeyboard = hwnd
        keyboardFocus.restart()
    }

    // ---- Services

    WindowList {
        id: windowList
    }

    // The windows yasb tracks change while open (one closes, a title changes): those without GlazeWM are rows too
    Connections {
        target: windowList
        enabled: walker.open

        function onWindowsChanged() {
            refresh.restart()
        }
    }

    WebSocket {
        id: socket

        url: walker.serverUri
        active: true
        onStatusChanged: {
            if (socket.status === WebSocket.Open) {
                socket.sendTextMessage("sub -e all")
                walker.stale = true
                if (walker.open)
                    refresh.restart()
            } else if (socket.status === WebSocket.Closed || socket.status === WebSocket.Error) {
                walker.workspaces = []
                if (walker.open)
                    walker.rebuild(true)
                reconnect.start()
            }
        }
        onTextMessageReceived: message => {
            let response
            try {
                response = JSON.parse(message)
            } catch (error) {
                return
            }
            if (response.messageType === "event_subscription") {
                walker.stale = true
                if (walker.open)
                    refresh.restart()
                return
            }
            if (response.messageType !== "client_response")
                return
            if (response.success === false) {
                console.warn(`WindowWalker: GlazeWM said no to "${response.clientMessage}": ${response.error}`)
                return
            }
            if (response.clientMessage === "query monitors")
                walker.readMonitors(response.data?.monitors ?? [])
        }
    }

    // One query for a burst of events, as GlazeWM sends several for one change
    Timer {
        id: refresh

        interval: 40
        onTriggered: {
            if (walker.connected)
                walker.send("query monitors")
            else
                walker.rebuild(true)
        }
    }

    // GlazeWM may start after yasb, or restart
    Timer {
        id: reconnect

        interval: 3000
        onTriggered: {
            socket.active = false
            socket.active = true
        }
    }

    Timer {
        id: keyboardFocus

        interval: 350
        onTriggered: {
            const hwnd = walker.pendingKeyboard
            walker.pendingKeyboard = 0
            if (hwnd && !windowList.inFront(hwnd))
                windowList.switchTo(hwnd)
        }
    }
}
