import QtQuick
import QtQuick.Controls 2.15
import qs.Widgets
import qs.Common
import qs.Services
import "."
import "../services"
import "../services/StockUtils.js" as Utils

Rectangle {
    id: root

    // Signals
    signal confirm(string code, string name)

    signal cancel()

    // Properties
    property var translationFunc: function (key) {
        return key;
    }
    property var searchResults: []
    property int selectedIndex: -1
    property bool isVerifying: false

    // Geometry for animation
    property real startX: 0
    property real startY: 0
    property real startW: 32
    property real startH: 32

    anchors.fill: parent
    color: "transparent"
    visible: opacity > 0
    opacity: 0
    enabled: state === "expanded"

    Behavior on opacity {
        NumberAnimation {
            duration: 250
        }
    }

    Keys.enabled: state === "expanded"
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        }
    }

    // 1. Dim Background
    Rectangle {
        id: dimBackground
        anchors.fill: parent
        color: "#000000"
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // 2. Main Dialog Container
    Rectangle {
        id: dialogWindow

        // Initial / Target state geometry
        x: startX
        y: startY
        width: startW
        height: startH
        radius: 16

        color: Theme.surface
        border.color: Theme.surfaceVariant
        border.width: 1
        clip: true

        // Prevent click-through to dimBackground
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Content Area (Separated from Container for better performance)
        Column {
            id: contentArea
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: 308 // (340 - 32 padding)
            spacing: 12
            opacity: 0

            // Results List
            Item {
                id: resultsContainer
                width: parent.width
                height: Math.min(maxResultsHeight, root.searchResults.length * 40)
                clip: true
                visible: root.searchResults.length > 0
                readonly property real maxResultsHeight: root.height - 150

                ListView {
                    id: resultsList
                    anchors.fill: parent
                    model: root.searchResults
                    spacing: 4
                    currentIndex: root.selectedIndex
                    delegate: Item {
                        width: resultsList.width
                        height: 36
                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: Theme.primary
                            opacity: root.selectedIndex === index ? 0.15 : (mouseArea.containsMouse ? 0.05 : 0)
                        }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; spacing: 10
                            StyledText {
                                text: Utils.getCountryEmoji(modelData.code); anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: modelData.name; width: 140; anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: Theme.fontSizeMedium; color: modelData.isFallback ? Theme.secondary : Theme.primary; elide: Text.ElideRight
                            }
                            StyledText {
                                text: Utils.getPureCode(modelData.code); anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Theme.fontSizeSmall; color: Theme.secondary; opacity: 0.7
                            }
                        }
                        MouseArea {
                            id:
                                mouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.confirmSelection(modelData); onEntered: root.selectedIndex = index
                        }
                    }
                }
            }

            // Search Input
            Rectangle {
                width: parent.width; height: 44; radius: 12; color: Theme.surfaceVariant
                border.color: searchInput.activeFocus ? Theme.primary : "transparent"; border.width: 2
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; spacing: 8
                    DankIcon {
                        name: root.isVerifying ? "sync" : "search"; size: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter
                        RotationAnimator on rotation {
                            running: root.isVerifying; from: 0;
                            to: 360; loops: Animation.Infinite; duration: 1000
                        }
                    }
                    TextInput {
                        id:
                            searchInput; width: parent.width - 30; height: parent.height; verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Theme.fontSizeMedium; color: Theme.primary; selectByMouse: true
                        onTextChanged: {
                            const trimmed = text.trim();
                            if (trimmed.length >= 1) {
                                // Ensure StockService is available
                                if (typeof StockService !== "undefined") {
                                    StockService.searchStocks(trimmed, results => {
                                        if (trimmed.length >= 2) results.push({
                                            name: root.translationFunc("Use Raw Code: ") + trimmed,
                                            code: trimmed,
                                            isFallback: true
                                        });
                                        root.searchResults = results;
                                        root.selectedIndex = results.length > 0 ? 0 : -1;
                                    });
                                }
                            } else {
                                root.searchResults = [];
                                root.selectedIndex = -1;
                            }
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down && root.searchResults.length) {
                                root.selectedIndex = (root.selectedIndex + 1) % root.searchResults.length;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && root.searchResults.length) {
                                root.selectedIndex = (root.selectedIndex - 1 + root.searchResults.length) % root.searchResults.length;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.selectedIndex >= 0) root.confirmSelection(root.searchResults[root.selectedIndex]);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                root.close();
                                event.accepted = true;
                            }
                        }
                        Text {
                            visible: !parent.text
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: root.translationFunc("Search Name/Code/Pinyin")
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceVariantText
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }

    // States and Transitions
    states: [
        State {
            name: "expanded"
            PropertyChanges {
                target: root; opacity: 1
            }
            PropertyChanges {
                target: dimBackground; opacity: 0.4
            }
            PropertyChanges {
                target: dialogWindow; x: (root.width - 340) / 2; y: root.height - dialogWindow.height - 12; width: 340; height: resultsContainer.visible ? Math.min(root.height - 40, resultsContainer.height + 44 + 32 + 12) : 44 + 32
            }
            PropertyChanges {
                target: contentArea; opacity: 1
            }
        }
    ]

    transitions: [
        Transition {
            from: "";
            to: "expanded"
            ParallelAnimation {
                NumberAnimation {
                    target: root; property: "opacity";
                    duration: 150
                }
                NumberAnimation {
                    target: dimBackground; property: "opacity";
                    duration: 300
                }
                NumberAnimation {
                    target: dialogWindow; properties: "x,y,width,height"; duration: 350; easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation {
                        duration: 150
                    }
                    NumberAnimation {
                        target: contentArea; property: "opacity";
                        duration: 200
                    }
                }
            }
        },
        Transition {
            from: "expanded";
            to: ""
            ParallelAnimation {
                NumberAnimation {
                    target: contentArea; property: "opacity";
                    duration: 100
                }
                NumberAnimation {
                    target: dialogWindow; properties: "x,y,width,height"; duration: 250; easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: dimBackground; property: "opacity";
                    duration: 250
                }
                NumberAnimation {
                    target: root; property: "opacity";
                    duration: 250
                }
            }
        }
    ]

    function confirmSelection(stock) {
        if (stock && !root.isVerifying) {
            if (stock.isFallback) {
                if (typeof StockService !== "undefined") {
                    root.isVerifying = true;
                    StockService.previewStock(stock.code, verified => {
                        root.isVerifying = false;
                        if (verified && verified.name) {
                            root.confirm(verified.code, verified.name);
                            close();
                        } else ToastService.showError(root.translationFunc("Stock not found: ") + stock.code);
                    });
                }
            } else {
                root.confirm(stock.code, stock.name);
                close();
            }
        }
    }

    function open(x, y, w, h) {
        root.startX = x;
        root.startY = y;
        root.startW = w;
        root.startH = h;
        searchInput.text = "";
        searchResults = [];
        selectedIndex = -1;
        isVerifying = false;
        root.state = "expanded";
        Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function close() {
        root.state = "";
        Qt.callLater(() => root.cancel());
    }
}