import QtQuick

// What the overview shows and switches between: Windows' virtual desktops or a window manager's workspaces.
// Each card is {key, label, name, title, detail, populated, icons}: key is the positive number its picture is kept
// under, label its short name in big type, name a longer one or "", title what its card says without a picture,
// detail what is open on it, populated whether anything is, and icons the URLs of its apps' icons. A source can
// add fields of its own, which only it reads.
Item {
    property var cards: []
    // The card in view on the widget's screen, or 0 while there is none
    property int currentKey: 0
    // Whether the overview offers to make a new one
    property bool canCreate: false
    // How long the overview stays over the screen after a switch, covering the switch's own animation, in ms
    property int switchCover: 0

    // The overview asks for these
    signal switchRequested(card: var)
    signal createRequested

    // The pictures of keys no longer show what is there
    signal stale(keys: list<int>)
}
