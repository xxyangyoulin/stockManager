import QtQuick
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    
    pluginId: "stockManager"
    layerNamespacePlugin: "stockManager"

    property var stocks: []
    property bool isLoading: false
    property string outputBuffer: ""
    property bool popoutVisible: false
    property string lastUpdateTime: "从未"
    property int refreshInterval: 30000  // Refresh every 30 seconds
    
    // SH index data (for bar display)
    property var shIndex: ({
        "currentPrice": 0,
        "changeAmount": 0,
        "changePercent": 0
    })

    // Periodically refresh data
    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: true  // Always running to update bar display
        repeat: true
        onTriggered: root.fetchStockData()
    }

    // Preset some A-share stocks
    Component.onCompleted: {
        // Add some main A-share indices as examples
        addStock("sh000001", "上证指数", 0)
        addStock("usAAPL", "Apple", 0)
        addStock("sz000559", "万向钱潮", 0)
        addStock("sz002195", "岩山科技", 0)
        addStock("sz002050", "三花智控", 0)
        // Fetch data immediately
        fetchStockData()
    }

    function addStock(code, name, costPrice) {
        var newStock = {
            "code": code,
            "name": name,
            "costPrice": costPrice,
            "currentPrice": 0,
            "prevClose": 0,
            "changeAmount": 0,
            "changePercent": 0,
            "profit": 0,
            "profitPercent": 0
        }
        stocks.push(newStock)
    }

    function fetchStockData() {
        if (stocks.length === 0) return
        
        isLoading = true
        var codes = []
        for (var i = 0; i < stocks.length; i++) {
            codes.push(stocks[i].code)
        }
        var apiUrl = "https://qt.gtimg.cn/q=" + codes.join(",")

        console.log("stockManager: Fetching stock data for:", codes.join(","))
        Proc.runCommand("stockManager:fetch", ["sh", "-c", `curl -s "${apiUrl}" | iconv -f GBK -t UTF-8`], (output, exitCode) => {
            if (exitCode === 0 && output) {
                parseStockData(output)
            }
            isLoading = false
        })
    }

    function parseStockData(data) {
        try {
            var lines = data.trim().split('\n')
            var stocksUpdated = []
            for (var j = 0; j < lines.length; j++) {
                var line = lines[j]
                var match = line.match(/v_.*="(.*)"/)
                if (!match || match.length < 2) continue

                var parts = match[1].split('~')
                if (parts.length < 33) continue  // Need at least 33 elements to get change percent (index 32)

                var code = match[0].split('=')[0].replace('v_', '').replace('s_', '')
                
                // Find the corresponding stock
                for (var i = 0; i < stocks.length; i++) {
                    // Handle matching of different stock code formats
                    var stockCode = stocks[i].code;
                    // If the API returns a different code format, try to match it
                    var matches = (stocks[i].code === code) || 
                                  (stocks[i].code === code.replace(/^s_/, '')) ||
                                  ('s_' + stocks[i].code === code);
                    
                    if (matches) {
                        var stock = stocks[i]
                        
                        stock.name = parts[1] || stock.name
                        var newCurrentPrice = parseFloat(parts[3]) || 0
                        var newPrevClose = parseFloat(parts[4]) || 0  // Previous close at index 4
                        var newChangeAmountStr = parts[31] || '0'  // Change amount at index 31
                        var newChangeAmount = parseFloat(newChangeAmountStr) || 0
                        
                        var newChangePercentStr = parts[32] || '0'  // Change percent at index 32
                        var newChangePercent = parseFloat(newChangePercentStr) || 0
                        
                        if (newCurrentPrice > 0) {
                            stock.currentPrice = newCurrentPrice
                            stock.prevClose = newPrevClose
                            stock.changeAmount = newChangeAmount
                            stock.changePercent = newChangePercent

                            if (stock.costPrice > 0) {
                                stock.profit = newCurrentPrice - stock.costPrice
                                stock.profitPercent = (stock.profit / stock.costPrice) * 100
                            }
                            
                            // Update SH index data (for bar display)
                            if (stock.code === "sh000001") {
                                shIndex = {
                                    "currentPrice": newCurrentPrice,
                                    "changeAmount": newChangeAmount,
                                    "changePercent": newChangePercent
                                }
                                console.log("stockManager: Updated shIndex:", shIndex.currentPrice, shIndex.changePercent + "%")
                            }
                            
                            stocksUpdated.push(stock)
                        }
                        break
                    }
                }
            }
            
            // Trigger UI update
            stocks = stocks.slice()

            // Update last update time
            var now = new Date()
            lastUpdateTime = now.getHours().toString().padStart(2, '0') + ':' + 
                           now.getMinutes().toString().padStart(2, '0') + ':' + 
                           now.getSeconds().toString().padStart(2, '0')
        } catch (e) {
            console.warn("stockManager: Failed to parse stock data", e)
        }
    }

    function getChangeColor(changeAmount) {
        if (changeAmount > 0) return "#ff4d4f"  // Red when price is up
        if (changeAmount < 0) return "#52c41a"  // Green when price is down
        return "#888888"  // Gray when no change
    }

    function getProfitColor(profit) {
        if (profit > 0) return "#ff4d4f"  // Red when in profit
        if (profit < 0) return "#52c41a"  // Green when in loss
        return "#ffffff"  // White when break-even
    }

    // --- Layout ---
    popoutWidth: 440
    popoutHeight: {
        var calculated = 140 + (stocks.length * 32)
        if (calculated < 320) return 320
        if (calculated > 750) return 750
        return calculated
    }

    // --- Bar Icons ---
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shIndex.changeAmount !== 0 ? 
                      (root.shIndex.changeAmount >= 0 ? "+" : "") + root.shIndex.changeAmount.toFixed(2) : "--"
                font.pixelSize: Theme.fontSizeSmall
                color: root.getChangeColor(root.shIndex.changeAmount)
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS
            
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shIndex.changeAmount !== 0 ? 
                      (root.shIndex.changeAmount >= 0 ? "+" : "") + root.shIndex.changeAmount.toFixed(2) : "--"
                font.pixelSize: Theme.fontSizeSmall
                color: root.getChangeColor(root.shIndex.changeAmount)
            }
        }
    }

    // --- Popout Content ---
    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: "Stock Manager"
            detailsText: ""
            showCloseButton: true

            Component.onCompleted: { root.popoutVisible = true; }
            Component.onDestruction: { root.popoutVisible = false; }

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popoutComp.headerHeight - popoutComp.detailsHeight - Theme.spacingXL - 20

                // Main Container
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5

                    // Table Header
                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 4
                        color: Theme.surfaceVariant

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingXS
                            anchors.rightMargin: Theme.spacingXS
                            spacing: 0  // Remove spacing so columns are tight

                            Repeater {
                                model: ["名字", "最新", "涨跌", "涨幅"]

                                StyledText {
                                    width: index === 0 ? 120 : 80
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignRight
                                    text: modelData
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }
                        }
                    }

                    // Stock List
                    ScrollView {
                        width: parent.width
                        height: parent.height - 80  // Leave space for bottom info bar
                        clip: true

                        ListView {
                            id: stockList
                            width: parent.width
                            height: parent.height
                            model: root.stocks
                            spacing: 2

                            delegate: Rectangle {
                                width: stockList.width
                                height: 32
                                radius: 4
                                color: index % 2 === 0 ? "transparent" : Theme.surfaceVariant
                                opacity: 0.9

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingXS
                                    anchors.rightMargin: Theme.spacingXS
                                    spacing: 0  // Remove spacing so columns are tight

                                    // Name
                                    StyledText {
                                        width: 120
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignLeft
                                        text: modelData.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }

                                    // Last price
                                    StyledText {
                                        width: 80
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.currentPrice > 0 ? modelData.currentPrice.toFixed(2) : "--"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }

                                    // Change amount
                                    StyledText {
                                        width: 80
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.changeAmount !== 0 ? 
                                              (modelData.changeAmount >= 0 ? "+" : "") + modelData.changeAmount.toFixed(2) : "--"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.getChangeColor(modelData.changeAmount)
                                    }

                                    // Change percent
                                    StyledText {
                                        width: 80
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignRight
                                        text: modelData.changePercent !== 0 ? 
                                              (modelData.changePercent >= 0 ? "+" : "") + modelData.changePercent.toFixed(2) + "%" : "--"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.bold: true
                                        color: root.getChangeColor(modelData.changeAmount)
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        width: parent.width
                        height: 10
                    }

                    // Bottom Info Bar
                    Item {
                        width: parent.width
                        height: 28

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS

                            // Stock Count - Left
                            StyledText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.isLoading ? "加载中..." : `${root.stocks.length} 只股票`
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.primary
                            }

                            // Last Update Time - Center
                            StyledText {
                                anchors.centerIn: parent
                                text: "最后更新: " + root.lastUpdateTime
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.secondary
                            }

                            // Refresh Button - Right
                            DankIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                name: "refresh"
                                size: 20
                                color: root.isLoading ? Theme.primary : Theme.surfaceVariantText

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -5
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.fetchStockData()
                                }
                                RotationAnimator on rotation {
                                    running: root.isLoading
                                    from: 0; to: 360; loops: Animation.Infinite; duration: 1000
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}