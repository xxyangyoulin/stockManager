import QtQuick
import qs.Common
import qs.Widgets
import "."
import "../services"
import "../services/StockUtils.js" as Utils

Item {
    id: root

    property var stockData: null
    property int itemIndex: 0
    property bool isPinned: false
    property bool showSparklines: true
    property bool isLoading: false
    property var lastUpdateDate: null
    property var onDelete: function (code) {}
    property var onPin: function (code) {}
    property var onMoveToTop: function (code) {}
    property var onRefresh: function () {}

    signal showDetail(var stock, real x, real y, real w, real h)

    width: parent ? parent.width : 440
    height: Utils.UI.ROW_HEIGHT

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.nestedSurface
        border.color: Theme.outlineMedium
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.ListView.view.currentIndex = root.itemIndex
    }

    Column {
        id: nameColumn
        width: 112
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        StyledText {
            width: parent.width
            text: root.stockData ? root.stockData.name : "—"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.surfaceText
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        StyledText {
            width: parent.width
            text: root.stockData
                  ? Utils.getPureCode(root.stockData.code)
                  : ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }

        StyledText {
            width: parent.width
            text: root.lastUpdateDate ? Utils.formatSmartTime(new Date(root.lastUpdateDate)) : ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    Column {
        id: priceColumn
        width: 86
        anchors.left: nameColumn.right
        anchors.leftMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            text: root.stockData ? Utils.formatPercent(root.stockData.changePercent) : ""
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: root.stockData ? StockService.getChangeColor(root.stockData.changeAmount) : Theme.surfaceVariantText
        }

        StyledText {
            text: root.stockData ? Utils.formatNumber(root.stockData.currentPrice) : "—"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: root.stockData ? Utils.formatChange(root.stockData.changeAmount) : ""
            font.pixelSize: Theme.fontSizeSmall
            color: root.stockData ? StockService.getChangeColor(root.stockData.changeAmount) : Theme.surfaceVariantText
        }
    }

    Item {
        id: chartArea
        anchors.left: priceColumn.right
        anchors.leftMargin: Theme.spacingS
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingS
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingS

        StockSparkline {
            id: sparkline
            anchors.fill: parent
            visible: root.showSparklines
            history: root.stockData ? root.stockData.history : []
            lineColor: root.stockData ? StockService.getChangeColor(root.stockData.changeAmount) : Theme.primary
            prevClose: root.stockData ? root.stockData.prevClose : 0
            priceRangeRatio: Utils.getPriceRangeRatio(root.stockData)
        }

        MouseArea {
            id: chartMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.showSparklines
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.ListView.view.currentIndex = root.itemIndex;
                if (root.stockData) {
                    var p = sparkline.mapToItem(root.ListView.view, 0, 0);
                    root.showDetail(root.stockData, p.x, p.y, sparkline.width, sparkline.height);
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 4
            visible: chartMouseArea.containsMouse
                     || refreshMouse.containsMouse
                     || topMouse.containsMouse
                     || pinMouse.containsMouse
                     || removeMouse.containsMouse
            z: 2

            Rectangle {
                width: 24; height: 24; radius: 12
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.isLoading
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.onRefresh()
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 14
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                width: 24; height: 24; radius: 12
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)

                MouseArea {
                    id: topMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.stockData) root.onMoveToTop(root.stockData.code)
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "vertical_align_top"
                    size: 14
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                width: 24; height: 24; radius: 12
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)

                MouseArea {
                    id: pinMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.stockData) root.onPin(root.stockData.code)
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "push_pin"
                    size: 14
                    color: root.isPinned ? Theme.primary : Theme.surfaceVariantText
                    rotation: root.isPinned ? 0 : -45
                }
            }

            Rectangle {
                width: 24; height: 24; radius: 12
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)

                MouseArea {
                    id: removeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.stockData) root.onDelete(root.stockData.code)
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 12
                    color: removeMouse.containsMouse ? Theme.error : Theme.surfaceVariantText
                }
            }
        }
    }
}
