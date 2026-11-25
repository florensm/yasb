import QtQuick
import Yasb

// The workspaces GlazeWM shows on the widget's monitor. Pictures are kept under positive numbers, so a workspace's
// key is a hash of its name, above the numbers virtual desktops use: the same name always lands on the same picture.
OverviewSource {
    id: source

    required property string screenName
    property alias serverUri: workspaces.serverUri
    // Each workspace's window count when GlazeWM last sent them, to tell when one out of view changed
    property var lastCounts: ({})

    readonly property var list: workspaces.workspaces

    // FNV-1a of the name, from 2^20 up to the largest int
    function keyOf(name: string): int {
        let hash = 0x811c9dc5
        for (let index = 0; index < name.length; index++)
            hash = Math.imul(hash ^ name.charCodeAt(index), 0x01000193) >>> 0
        return 0x100000 + hash % (0x7fffffff - 0x100000)
    }

    cards: list.map(workspace => ({
        key: keyOf(workspace.name),
        label: workspace.displayName || workspace.name,
        name: "",
        title: qsTr("Workspace %1").arg(workspace.displayName || workspace.name),
        detail: workspace.windowCount === 1 ? qsTr("1 window")
            : workspace.windowCount > 1 ? qsTr("%1 windows").arg(workspace.windowCount) : "",
        populated: workspace.windowCount > 0,
        icons: workspace.icons.map(icon => icon.source),
        workspace: workspace.name
    }))
    // Only this monitor's workspaces are listed, so the one displayed is the one on this screen
    currentKey: {
        const shown = list.find(workspace => workspace.displayed)
        return shown ? keyOf(shown.name) : 0
    }
    // GlazeWM's own animation into the workspace
    switchCover: 250

    onSwitchRequested: card => workspaces.activateWorkspace(card.workspace)

    GlazewmWorkspaceList {
        id: workspaces

        screenName: source.screenName
        monitorExclusive: true
        appIcons: ({
            enabledPopulated: true,
            enabledActive: true,
            enabledFocused: true,
            maxIcons: 4,
            hideDuplicates: true
        })

        onDataChanged: {
            const counts = {}
            const stale = []
            for (const workspace of workspaces.workspaces) {
                counts[workspace.name] = workspace.windowCount
                const last = source.lastCounts[workspace.name]
                // Windows moved on or off it while out of view, which its picture can't show
                if (last !== undefined && last !== workspace.windowCount && !workspace.displayed)
                    stale.push(source.keyOf(workspace.name))
            }
            // Gone, or GlazeWM went away; either way nothing says what it holds when it comes back
            for (const name in source.lastCounts) {
                if (!(name in counts))
                    stale.push(source.keyOf(name))
            }
            source.lastCounts = counts
            if (stale.length > 0)
                source.stale(stale)
        }
    }
}
