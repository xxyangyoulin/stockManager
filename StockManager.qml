import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./StockUtils.js" as Utils

/*
 * StockManager.qml - Main plugin component
 * A-share stock price display widget for DankMaterialShell
 */

PluginComponent {
    id: root
    
    pluginId: "stockManager"
    layerNamespacePlugin: "stockManager"
    
    // Data manager
    StockDataManager {
        id: dataManager
        
        onDataLoaded: console.log("StockManager: Data loaded successfully")
        onDataSaved: console.log("StockManager: Data saved successfully")
        onDataError: function(error) { console.warn("StockManager Error:", error) }
        onStockDataUpdated: {
            // Close any open swipe items when data updates
            root.closeAllDeleteButtons();
        }
    }
    
    // UI State
    property bool popoutVisible: false
    property int currentOpenIndex: -1
    property var stockListRef: null
    property var addDialogRef: null
    
    // i18n Configuration
    property string currentLanguage: {
        var locale = Qt.locale().name;
        return locale.startsWith("zh") ? "zh_CN" : "en_US";
    }
    
    property var i18n: ({
        "zh_CN": {
            "header_name": "名字",
            "header_code": "编码",
            "header_price": "最新",
            "header_change": "涨跌",
            "header_percent": "涨幅",
            "loading": "加载中...",
            "stocks_count": "只股票",
            "last_update": "最后更新: ",
            "never": "从未",
            "stock_manager": "Stock Manager",
            "add_stock": "添加股票",
            "stock_code": "股票代码",
            "stock_name": "股票名称",
            "confirm": "确认",
            "cancel": "取消",
            "code_placeholder": "例如: 600000",
            "name_placeholder": "例如: 浦发银行",
            "delete": "删除"
        },
        "en_US": {
            "header_name": "Name",
            "header_code": "Code",
            "header_price": "Price",
            "header_change": "Change",
            "header_percent": "Percent",
            "loading": "Loading...",
            "stocks_count": " Stocks",
            "last_update": "Updated: ",
            "never": "Never",
            "stock_manager": "Stock Manager",
            "add_stock": "Add Stock",
            "stock_code": "Stock Code",
            "stock_name": "Stock Name",
            "confirm": "Confirm",
            "cancel": "Cancel",
            "code_placeholder": "e.g., 600000",
            "name_placeholder": "e.g., Bank Name",
            "delete": "Delete"
        }
    })
    
    // Translation helper
    function t(key) {
        return i18n[currentLanguage][key] || key;
    }
    
    // Initialization
    Component.onCompleted: {
        dataManager.loadStockData();
    }
    
    // Refresh timer
    Timer {
        id: refreshTimer
        interval: Utils.UI.REFRESH_INTERVAL
        running: true
        repeat: true
        onTriggered: dataManager.fetchStockData()
    }
    
    // UI Helper functions
    function closeAllDeleteButtons() {
        if (currentOpenIndex !== -1 && stockListRef) {
            var item = stockListRef.itemAtIndex(currentOpenIndex);
            if (item && item.closeSwipe) {
                item.closeSwipe();
            }
            currentOpenIndex = -1;
        }
    }
    
    function onItemSwipeOpen(index) {
        if (currentOpenIndex !== -1 && currentOpenIndex !== index && stockListRef) {
            var prevItem = stockListRef.itemAtIndex(currentOpenIndex);
            if (prevItem && prevItem.closeSwipe) {
                prevItem.closeSwipe();
            }
        }
        currentOpenIndex = index;
    }
    
    function onItemSwipeClose() {
        currentOpenIndex = -1;
    }
    
    // Add stock dialog preview handling
    function updatePreview(code) {
        if (!addDialogRef || !popoutVisible) return;
        if (!code) {
            try { addDialogRef.previewStock = null; } catch(e) {}
            return;
        }
        dataManager.previewStock(code, function(result) {
            // Double-check references are still valid in callback
            if (addDialogRef && popoutVisible) {
                try { addDialogRef.previewStock = result; } catch(e) {}
            }
        });
    }
    
    // Layout dimensions
    popoutWidth: 440
    popoutHeight: dataManager && dataManager.stocks ? dataManager.getPopoutHeight() : Utils.UI.POPOUT_MIN_HEIGHT
    
    // Bar display components
    horizontalBarPill: Component {
        Row {
            spacing: 4
            
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: dataManager.shIndex.changeAmount !== 0 
                    ? Utils.formatNumber(dataManager.shIndex.changeAmount) 
                    : "--"
                font.pixelSize: Theme.barTextSize(
                    root.barThickness, 
                    root.barConfig && root.barConfig.fontScale ? root.barConfig.fontScale : 1.0
                )
                color: Utils.getChangeColor(dataManager.shIndex.changeAmount)
            }
        }
    }
    
    verticalBarPill: Component {
        Column {
            spacing: 2
            
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dataManager.shIndex.changeAmount !== 0 
                    ? Utils.formatNumber(dataManager.shIndex.changeAmount) 
                    : "--"
                font.pixelSize: Theme.barTextSize(
                    root.barThickness,
                    root.barConfig && root.barConfig.fontScale ? root.barConfig.fontScale : 1.0
                )
                color: Utils.getChangeColor(dataManager.shIndex.changeAmount)
            }
        }
    }
    
    // Popout content
    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: root.t("stock_manager")
            detailsText: ""
            showCloseButton: true
            
            Component.onCompleted: { 
                root.popoutVisible = true; 
                // Store references
                root.stockListRef = stockList;
                root.addDialogRef = addDialog;
            }
            Component.onDestruction: { 
                root.popoutVisible = false;
                if (addDialog) addDialog.close();
                root.closeAllDeleteButtons();
                root.stockListRef = null;
                root.addDialogRef = null;
            }
            
            onActiveFocusChanged: {
                if (!activeFocus) {
                    root.closeAllDeleteButtons();
                }
            }
            
            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutComp.headerHeight - popoutComp.detailsHeight - 16 - 20
                
                // Main content
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5
                    
                    // Table header
                    StockTableHeader {
                        translationFunc: root.t
                        onSort: function(key) { dataManager.sortStocks(key); }
                    }
                    
                    // Stock list
                    ScrollView {
                        width: parent.width
                        height: parent.height - 65
                        clip: true
                        
                        ListView {
                            id: stockList
                            width: parent.width
                            height: parent.height
                            model: dataManager.getDisplayStocks()
                            spacing: Utils.UI.ROW_SPACING
                            
                            displaced: Transition {
                                NumberAnimation { 
                                    properties: "y"
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                            
                            delegate: StockListItem {
                                stockData: modelData
                                itemIndex: index
                                isAlternate: index % 2 === 1
                                onDelete: function(code) {
                                    dataManager.removeStock(code);
                                    root.currentOpenIndex = -1;
                                }
                                onSwipeOpen: root.onItemSwipeOpen
                                onSwipeClose: root.onItemSwipeClose
                            }
                        }
                    }
                    
                    // Spacer
                    Item {
                        width: parent.width
                        height: 6
                    }
                    
                    // Bottom bar
                    Rectangle {
                        width: parent.width
                        height: 28
                        color: "transparent"
                        
                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            
                            // Stock count (clickable)
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: stockCountText.width + 4
                                height: stockCountText.height + 2
                                radius: 2
                                color: stockCountMouseArea.containsMouse ? Theme.primary : "transparent"
                                
                                StyledText {
                                    id: stockCountText
                                    anchors.centerIn: parent
                                    text: dataManager.isLoading 
                                        ? root.t("loading") 
                                        : `${dataManager.getDisplayStocks().length}${root.t("stocks_count")}`
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: stockCountMouseArea.containsMouse ? Theme.surface : Theme.primary
                                }
                                
                                MouseArea {
                                    id: stockCountMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: addDialog.open()
                                }
                            }
                            
                            // Last update time
                            StyledText {
                                anchors.centerIn: parent
                                text: root.t("last_update") + dataManager.lastUpdateTime
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.secondary
                            }
                            
                            // Refresh button
                            DankIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                name: "refresh"
                                size: 17
                                color: dataManager.isLoading ? Theme.primary : Theme.surfaceVariantText
                                
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dataManager.fetchStockData()
                                }
                                
                                RotationAnimator on rotation {
                                    running: dataManager.isLoading
                                    from: 0
                                    to: 360
                                    loops: Animation.Infinite
                                    duration: 1000
                                }
                            }
                        }
                    }
                }
                
                // Add stock dialog
                AddStockDialog {
                    id: addDialog
                    translationFunc: root.t
                    onConfirm: function(code, name) {
                        dataManager.addStock(code, name, 0);
                        dataManager.fetchStockData();
                    }
                    onCancel: function() {}
                    onCodeChanged: root.updatePreview
                }
            }
        }
    }
}
