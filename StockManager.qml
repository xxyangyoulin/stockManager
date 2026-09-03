import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./services/StockUtils.js" as Utils
import "./services"
import "./components"
import "."

/*
 * StockManager.qml - Main plugin component
 * Refactored to use StockService singleton
 */

PluginComponent {
    id: pluginRoot

    pluginId: "stockManager"
    layerNamespacePlugin: "stockManager"

    // UI State
    property string lastKey: "" // For sequence keys like 'gg'

    function t(key) {
        let val = Utils.t(key);
        return val !== null ? val : I18n.tr(key);
    }

    Timer {
        id: sequenceTimer
        interval: 500; repeat: false
        onTriggered: pluginRoot.lastKey = ""
    }

    Timer {
        interval: StockService.refreshInterval
        running: true; repeat: true
        onTriggered: if (Utils.isTradingTime()) StockService.fetchStockData()
    }

    popoutWidth: 460
    popoutHeight: StockService.getPopoutHeight()

    horizontalBarPill: StockStatusBar {
        orientation: Qt.Horizontal
        pinnedStocks: StockService.pinnedStocks
        barThickness: pluginRoot.barThickness
        config: pluginRoot.barConfig
        maxCount: StockService.statusBarMaxCount
        scrollable: StockService.statusBarScrollable
    }

    verticalBarPill: StockStatusBar {
        orientation: Qt.Vertical
        pinnedStocks: StockService.pinnedStocks
        barThickness: pluginRoot.barThickness
        config: pluginRoot.barConfig
        maxCount: StockService.statusBarMaxCount
        scrollable: StockService.statusBarScrollable
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: pluginRoot.t("Stock Manager")
            detailsText: `${StockService.displayStocks.length}${pluginRoot.t("Stocks")}`
            showCloseButton: true
            focus: true
            property bool modelReady: false

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXS

                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: refreshHeaderMouse.containsMouse ? Theme.surfaceVariant : "transparent"

                        DankIcon {
                            anchors.centerIn: parent
                            name: "refresh"
                            size: Theme.iconSize - 4
                            color: Theme.surfaceText
                        }

                        MouseArea {
                            id: refreshHeaderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !StockService.isLoading
                            cursorShape: Qt.PointingHandCursor
                            onClicked: StockService.fetchStockData()
                        }
                    }
                }
            }

            ListModel {
                id: stockListModel
            }

            function syncStockList() {
                var source = StockService.displayStocks || [];
                var count = source.length;

                // Structural check: Rebuild if length differs significantly or IDs mismatch completely
                var needRebuild = false;
                if (stockListModel.count !== count) {
                    needRebuild = true;
                } else {
                    for (var i = 0; i < count; i++) {
                        if (stockListModel.get(i).code !== source[i].code) {
                            needRebuild = true;
                            break;
                        }
                    }
                }

                if (needRebuild) {
                    // 1. Capture selection state
                    var oldIndex = stockList.currentIndex;
                    var oldSelectedCode = null;
                    if (oldIndex >= 0 && oldIndex < stockListModel.count) {
                        oldSelectedCode = stockListModel.get(oldIndex).code;
                    }

                    // 2. Rebuild model
                    stockListModel.clear();
                    for (var j = 0; j < count; j++) {
                        stockListModel.append(source[j]);
                    }

                    // 3. Restore selection
                    if (oldSelectedCode) {
                        var newIndex = -1;
                        // Try to find the moved stock
                        for (var k = 0; k < stockListModel.count; k++) {
                            if (stockListModel.get(k).code === oldSelectedCode) {
                                newIndex = k;
                                break;
                            }
                        }

                        if (newIndex >= 0) {
                            // Stock still exists (moved or same place)
                            stockList.currentIndex = newIndex;
                        } else {
                            // Stock was deleted, select closest index
                            var targetIndex = Math.min(oldIndex, stockListModel.count - 1);
                            stockList.currentIndex = targetIndex;
                        }
                    } else {
                        // Nothing was selected, or list is empty
                        stockList.currentIndex = -1;
                    }
                    return;
                }

                // Update values in place
                for (var m = 0; m < count; m++) {
                    stockListModel.set(m, source[m]);
                }
            }

            function openAddDialog(x, y, width, height) {
                addDialogLoader.active = true;
                Qt.callLater(function () {
                    addDialogLoader.item.open(x, y, width, height);
                });
            }

            Connections {
                target: StockService

                function onDisplayStocksChanged() {
                    syncStockList();
                }
            }

            Component.onCompleted: {
                syncStockList(); // Initial sync
                modelReady = true;
                popoutComp.forceActiveFocus();
            }

            Keys.onPressed: (event) => {
                // If dialog is open, let it handle keys
                if (addDialogLoader.item && addDialogLoader.item.state === "expanded") return;

                if (event.key === Qt.Key_R) {
                    StockService.fetchStockData();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (stockList.currentIndex !== -1) {
                        let stock = StockService.displayStocks[stockList.currentIndex];
                        if (stock) StockService.togglePin(stock.code);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                    if (stockList.currentIndex !== -1) {
                        let stock = StockService.displayStocks[stockList.currentIndex];
                        if (stock) StockService.removeStock(stock.code);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        if (stockList.currentIndex > 0) {
                            let oldIdx = stockList.currentIndex;
                            StockService.moveStock(oldIdx, -1);
                            // currentIndex will be updated by the model change, but let's be explicit
                            Qt.callLater(() => stockList.currentIndex = oldIdx - 1);
                        }
                    } else {
                        if (stockList.currentIndex > 0) stockList.currentIndex--;
                        else if (stockList.currentIndex === -1 && stockList.count > 0) stockList.currentIndex = 0;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        if (stockList.currentIndex !== -1 && stockList.currentIndex < stockList.count - 1) {
                            let oldIdx = stockList.currentIndex;
                            StockService.moveStock(oldIdx, 1);
                            Qt.callLater(() => stockList.currentIndex = oldIdx + 1);
                        }
                    } else {
                        if (stockList.currentIndex < stockList.count - 1) stockList.currentIndex++;
                        else if (stockList.currentIndex === -1 && stockList.count > 0) stockList.currentIndex = 0;
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_G) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        // Shift + G -> End
                        stockList.currentIndex = stockList.count - 1;
                    } else {
                        // Double G -> Home
                        if (pluginRoot.lastKey === "g") {
                            stockList.currentIndex = 0;
                            pluginRoot.lastKey = "";
                        } else {
                            pluginRoot.lastKey = "g";
                            sequenceTimer.start();
                        }
                    }
                    event.accepted = true;
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                    const keys = ["name", "code", "price", "change", "percent"];
                    StockService.sortStocks(keys[event.key - Qt.Key_1]);
                    event.accepted = true;
                }
            }

            // Monitor visibility to close states when hidden
            onVisibleChanged: {
                if (!visible) {
                    addDialogLoader.active = false;
                    if (detailPopup.state === "expanded") detailPopup.closeRequest();
                } else {
                    popoutComp.forceActiveFocus();
                }
            }

            Item {
                width: parent.width
                implicitHeight: pluginRoot.popoutHeight - popoutComp.headerHeight - popoutComp.detailsHeight - 36

                ListView {
                    id: stockList
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: stockListModel.count > 0
                    clip: true
                    model: stockListModel
                    spacing: Utils.UI.ROW_SPACING
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: -1
                    highlightFollowsCurrentItem: true

                    onCurrentIndexChanged: {
                        if (currentIndex !== -1) positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    delegate: StockListItem {
                        stockData: (StockService.displayStocks && StockService.displayStocks[index]) ? StockService.displayStocks[index] : null
                        itemIndex: index
                        isPinned: stockData ? StockService.isPinned(stockData.code) : false
                        showSparklines: StockService.showSparklines
                        isLoading: StockService.isLoading
                        lastUpdateDate: StockService.lastUpdateDate
                        onDelete: (code) => StockService.removeStock(code)
                        onPin: (code) => StockService.togglePin(code)
                        onMoveToTop: (code) => StockService.moveStockToTop(code)
                        onRefresh: () => StockService.fetchStockData()
                        onShowDetail: (stock, x, y, w, h) => {
                            var pos = stockList.mapToItem(popoutComp, x, y);
                            detailPopup.open(pos.x, pos.y, w, h, stock);
                        }
                    }
                }

                Rectangle {
                    id: scrollIndicator
                    visible: stockList.contentHeight > stockList.height
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    width: 3
                    color: "transparent"

                    Rectangle {
                        width: parent.width
                        radius: width / 2
                        color: Theme.outlineVariant
                        opacity: stockList.moving ? 0.9 : 0.35
                        height: Math.max(24, parent.height * Math.min(1, stockList.height / stockList.contentHeight))
                        y: stockList.contentHeight > stockList.height
                           ? (stockList.contentY / (stockList.contentHeight - stockList.height)) * (parent.height - height)
                           : 0

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }

                Rectangle {
                    id: addButton
                    visible: popoutComp.modelReady && stockListModel.count > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: 36; height: 36; radius: 18
                    color: Theme.primaryContainer
                    z: 20

                    DankIcon {
                        anchors.centerIn: parent
                        name: "add"
                        size: 18
                        color: Theme.primary
                    }

                    MouseArea {
                        id: addButtonMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property bool armed: false
                        onPressed: armed = true
                        onCanceled: armed = false
                        onReleased: mouse => {
                            if (armed && containsMouse) {
                                var pos = addButton.mapToItem(popoutComp, 0, 0);
                                popoutComp.openAddDialog(pos.x, pos.y, addButton.width, addButton.height);
                            }
                            armed = false;
                        }
                    }
                }

                StockEmptyState {
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: popoutComp.modelReady && stockListModel.count === 0
                    translationFunc: pluginRoot.t
                    onAddClicked: function () {
                        popoutComp.openAddDialog(popoutComp.width / 2 - 16, popoutComp.height / 2 - 16, 32, 32);
                    }
                }

                Loader {
                    id: addDialogLoader
                    anchors.fill: parent
                    active: false
                    z: 100

                    sourceComponent: Component {
                        AddStockDialog {
                            translationFunc: pluginRoot.t
                            onConfirm: (code, name) => {
                                StockService.addStock(code, name);
                                popoutComp.forceActiveFocus();
                            }
                            onCancel: popoutComp.forceActiveFocus()
                        }
                    }
                }

                StockDetailPopup {
                    id: detailPopup
                }
            }
        }
    }
}
