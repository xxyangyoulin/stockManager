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
    property string lastUpdateTime: "Never"
    property int refreshInterval: 30000  // Refresh every 30 seconds
    property bool showAddDialog: false
    property string stockDataPath: Qt.resolvedUrl(".").toString().replace("file://", "") + "StockData.json"
    property var previewStock: null  // Preview stock info
    property int currentOpenIndex: -1  // Track currently open item index
    property string sortKey: ""      // Current sort key: name, code, price, change, percent
    property bool sortAscending: true // Sort order
    
    // Function to close all opened delete buttons
    function closeAllDeleteButtons() {
        if (currentOpenIndex !== -1) {
            var item = stockList.itemAtIndex(currentOpenIndex)
            if (item && item.children[1]) {
                item.children[1].x = 0
            }
            currentOpenIndex = -1
        }
    }
    
    function sortStocksBy(key) {
        // Toggle sort order if clicking the same column
        if (sortKey === key) {
            sortAscending = !sortAscending
        } else {
            sortKey = key
            // Default: name/code ascending, others descending
            if (key === "name" || key === "code") {
                sortAscending = true
            } else {
                sortAscending = false
            }
        }
        
        // Separate index stock and others
        var indexStock = null
        var others = []
        for (var i = 0; i < stocks.length; i++) {
            if (stocks[i].code === "sh000001") {
                indexStock = stocks[i]
            } else {
                others.push(stocks[i])
            }
        }
        
        var dir = sortAscending ? 1 : -1
        others.sort(function(a, b) {
            var av, bv
            if (key === "name") {
                av = a.name || ""
                bv = b.name || ""
            } else if (key === "code") {
                av = getPureCode(a.code)
                bv = getPureCode(b.code)
            } else if (key === "price") {
                av = a.currentPrice || 0
                bv = b.currentPrice || 0
            } else if (key === "change") {
                av = a.changeAmount || 0
                bv = b.changeAmount || 0
            } else if (key === "percent") {
                av = a.changePercent || 0
                bv = b.changePercent || 0
            } else {
                return 0
            }
            if (av === bv) return 0
            return av > bv ? dir : -dir
        })
        
        var newStocks = []
        if (indexStock) newStocks.push(indexStock)
        for (var j = 0; j < others.length; j++) {
            newStocks.push(others[j])
        }
        stocks = newStocks
    }
    
    // Language settings
    property string currentLanguage: {
        var locale = Qt.locale().name  // Get system locale, e.g., "zh_CN", "en_US"
        if (locale.startsWith("zh")) {
            return "zh_CN"
        }
        return "en_US"  // Default to English
    }
    
    // Multi-language text definitions
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
    
    // Translation function
    function t(key) {
        return i18n[currentLanguage][key] || key
    }
    
    // Get country emoji from stock code
    function getCountryEmoji(code) {
        if (code.startsWith("sh") || code.startsWith("sz")) {
            return "🇨🇳"  // China
        }
        if (code.startsWith("us")) {
            return "🇺🇸"  // USA
        }
        if (code.startsWith("hk")) {
            return "🇭🇰"  // Hong Kong
        }
        return "🌐"  // Default
    }
    
    // Get pure stock code without country prefix
    function getPureCode(code) {
        return code.replace(/^(sh|sz|us|hk)/i, "")
    }
    
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

    // Load stock data on startup
    Component.onCompleted: {
        loadStockData()
    }
    
    function addStock(code, name, costPrice) {
        // Check if stock already exists
        for (var i = 0; i < stocks.length; i++) {
            if (stocks[i].code === code) {
                console.warn("stockManager: Stock already exists:", code)
                return
            }
        }
            
        var newStock = {
            "code": code,
            "name": name,
            "costPrice": costPrice || 0,
            "currentPrice": 0,
            "prevClose": 0,
            "changeAmount": 0,
            "changePercent": 0,
            "profit": 0,
            "profitPercent": 0
        }
        stocks.push(newStock)
        stocks = stocks.slice()  // Trigger UI update
        saveStockData()
    }
        
    function removeStock(code) {
        for (var i = 0; i < stocks.length; i++) {
            if (stocks[i].code === code) {
                stocks.splice(i, 1)
                stocks = stocks.slice()  // Trigger UI update
                saveStockData()
                return
            }
        }
    }
        
    function loadStockData() {
        var cmd = `cat "${stockDataPath}" 2>/dev/null || echo "[]"`
        Proc.runCommand("stockManager:loadData", ["sh", "-c", cmd], (output, exitCode) => {
            if (exitCode === 0 && output) {
                try {
                    var data = JSON.parse(output.trim())
                    if (Array.isArray(data) && data.length > 0) {
                        stocks = []
                        for (var i = 0; i < data.length; i++) {
                            var stock = data[i]
                            addStockFromData(stock.code, stock.name, stock.costPrice || 0)
                        }
                        console.log("stockManager: Loaded", stocks.length, "stocks from file")
                    } else {
                        // File is empty or doesn't exist, load defaults
                        console.log("stockManager: No data in file, loading defaults")
                        loadDefaultStocks()
                    }
                } catch (e) {
                    console.warn("stockManager: Failed to parse stock data file:", e)
                    loadDefaultStocks()
                }
            } else {
                loadDefaultStocks()
            }
            // Fetch data after loading
            fetchStockData()
        })
    }
        
    function loadDefaultStocks() {
        stocks = []
        addStockFromData("sh000001", "上证指数", 0)
        addStockFromData("sz000559", "万向钱潮", 0)
        addStockFromData("sz002195", "岩山科技", 0)
        addStockFromData("sz002050", "三花智控", 0)
        addStockFromData("sh601138", "工业富联", 0)
        console.log("stockManager: Loaded", stocks.length, "default stocks")
        saveStockData()
    }
    
    function addStockFromData(code, name, costPrice) {
        var newStock = {
            "code": code,
            "name": name,
            "costPrice": costPrice || 0,
            "currentPrice": 0,
            "prevClose": 0,
            "changeAmount": 0,
            "changePercent": 0,
            "profit": 0,
            "profitPercent": 0
        }
        stocks.push(newStock)
    }
    
    function saveStockData() {
        var data = []
        for (var i = 0; i < stocks.length; i++) {
            data.push({
                "code": stocks[i].code,
                "name": stocks[i].name
            })
        }
        var jsonStr = JSON.stringify(data, null, 2)
        // Use printf to avoid shell escaping issues
        var cmd = `printf '%s' '${jsonStr}' > "${stockDataPath}"`
        Proc.runCommand("stockManager:saveData", ["sh", "-c", cmd], (output, exitCode) => {
            if (exitCode === 0) {
                console.log("stockManager: Saved stock data to file")
            } else {
                console.warn("stockManager: Failed to save stock data")
            }
        })
    }

    function autoCompleteStockCode(input) {
        // Remove all non-digit characters
        var pureNumber = input.replace(/[^0-9]/g, '')
        
        if (pureNumber.length !== 6) {
            return null
        }
        
        // Auto-complete prefix based on Shanghai stock exchange rules
        var firstDigit = pureNumber.charAt(0)
        var prefix = "sh"  // Default to Shanghai
        
        // Shenzhen stocks: 0xxxxx, 3xxxxx
        if (firstDigit === '0' || firstDigit === '3') {
            prefix = "sz"
        }
        // Shanghai stocks: 6xxxxx (and others default to sh)
        
        return prefix + pureNumber
    }

    function previewStockByCode(code) {
        if (!code || code.length < 8) {
            previewStock = null
            return
        }
        
        var apiUrl = "https://qt.gtimg.cn/q=" + code
        console.log("stockManager: Previewing stock:", code)
        
        Proc.runCommand("stockManager:preview", ["sh", "-c", `curl -s "${apiUrl}" | iconv -f GBK -t UTF-8`], (output, exitCode) => {
            if (exitCode === 0 && output) {
                try {
                    var line = output.trim()
                    var match = line.match(/v_.*="(.*)"/)  
                    if (match && match.length > 1) {
                        var parts = match[1].split('~')
                        if (parts.length > 1 && parts[1]) {
                            previewStock = {
                                "code": code,
                                "name": parts[1]
                            }
                            console.log("stockManager: Preview found:", previewStock.name)
                        } else {
                            previewStock = null
                        }
                    } else {
                        previewStock = null
                    }
                } catch (e) {
                    console.warn("stockManager: Failed to preview stock:", e)
                    previewStock = null
                }
            } else {
                previewStock = null
            }
        })
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
            
            // Create map for faster lookup
            var stockMap = {}
            for (var i = 0; i < stocks.length; i++) {
                stockMap[stocks[i].code] = i
            }
            
            for (var j = 0; j < lines.length; j++) {
                var line = lines[j]
                var match = line.match(/v_.*="(.*)"/)
                if (!match || match.length < 2) continue

                var parts = match[1].split('~')
                if (parts.length < 33) continue  // Need at least 33 elements to get change percent (index 32)

                var codePart = match[0].split('=')[0]
                var code = codePart.substring(codePart.indexOf('_') + 1)
                
                // Find the corresponding stock using map
                var stockIndex = stockMap[code]
                if (stockIndex !== undefined) {
                    var stock = stocks[stockIndex]
                        
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
                        
                        stocksUpdated.push(stock.code)
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
        var displayCount = stocks.filter(function(s) { return s.code !== "sh000001" }).length
        var calculated = 140 + (displayCount * 32)
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
                text: root.shIndex.changeAmount !== 0 ? root.shIndex.changeAmount.toFixed(2) : "--"
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig && root.barConfig.fontScale ? root.barConfig.fontScale : 1.0)
                color: root.getChangeColor(root.shIndex.changeAmount)
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS
            
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.shIndex.changeAmount !== 0 ? root.shIndex.changeAmount.toFixed(2) : "--"
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig && root.barConfig.fontScale ? root.barConfig.fontScale : 1.0)
                color: root.getChangeColor(root.shIndex.changeAmount)
            }
        }
    }

    // --- Popout Content ---
    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: root.t("stock_manager")
            detailsText: ""
            showCloseButton: true

            Component.onCompleted: { root.popoutVisible = true; }
            Component.onDestruction: { 
                root.popoutVisible = false;
                root.showAddDialog = false;
                root.closeAllDeleteButtons();
            }
            
            onActiveFocusChanged: {
                if (!activeFocus) {
                    root.closeAllDeleteButtons();
                }
            }

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
                            spacing: 5

                            // Name
                            Rectangle {
                                width: 80
                                height: parent.height
                                color: "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortStocksBy("name")
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignLeft
                                    text: root.t("header_name")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }

                            // Code
                            Rectangle {
                                width: 70
                                height: parent.height
                                color: "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortStocksBy("code")
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: root.t("header_code")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }

                            // Price
                            Rectangle {
                                width: 60
                                height: parent.height
                                color: "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortStocksBy("price")
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: root.t("header_price")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }

                            // Change
                            Rectangle {
                                width: 60
                                height: parent.height
                                color: "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortStocksBy("change")
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: root.t("header_change")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }

                            // Percent
                            Rectangle {
                                width: 70
                                height: parent.height
                                color: "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.sortStocksBy("percent")
                                }

                                StyledText {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignRight
                                    text: root.t("header_percent")
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }
                        }
                    }

                    // Stock List
                    ScrollView {
                        width: parent.width
                        height: parent.height - 65  // Leave space for bottom info bar
                        clip: true

                        ListView {
                            id: stockList
                            width: parent.width
                            height: parent.height
                            model: root.stocks.filter(function(stock) { return stock.code !== "sh000001" })
                            spacing: 2
                            
                            // Enable drag and drop reordering
                            displaced: Transition {
                                NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutQuad }
                            }

                            delegate: Item {
                                width: stockList.width
                                height: 32
                                clip: true
                                
                                // Delete button background
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 18
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 52
                                    color: "#ff4d4f"
                                    radius: 4
                                    visible: itemContent.x < -5
                                    opacity: Math.min(1.0, Math.abs(itemContent.x) / 70)
                                    
                                    Behavior on opacity {
                                        NumberAnimation { duration: 100 }
                                    }
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: root.t("delete")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: "white"
                                    }
                                }
                                
                                // Stock item content
                                Rectangle {
                                    id: itemContent
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    x: 0
                                    radius: 4
                                    color: index % 2 === 0 ? "transparent" : Theme.surfaceVariant
                                    opacity: 0.9
                                    
                                    Behavior on x {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingXS
                                        anchors.rightMargin: Theme.spacingXS
                                        spacing: 5

                                        // Country emoji + Name
                                        Row {
                                            width: 80
                                            height: parent.height
                                            spacing: 3
                                            
                                            StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: root.getCountryEmoji(modelData.code)
                                                font.pixelSize: Theme.fontSizeMedium
                                            }
                                            
                                            StyledText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 20
                                                text: modelData.name
                                                font.pixelSize: Theme.fontSizeMedium
                                                color: Theme.primary
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // Stock Code (without country prefix)
                                        StyledText {
                                            width: 70
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: root.getPureCode(modelData.code) || "--"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.family: "monospace"
                                            color: Theme.secondary
                                        }

                                        // Last price
                                        StyledText {
                                            width: 60
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: modelData.currentPrice > 0 ? modelData.currentPrice.toFixed(2) : "--"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.family: "monospace"
                                            color: Theme.primary
                                        }

                                        // Change amount
                                        StyledText {
                                            width: 60
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: modelData.changeAmount !== 0 ? 
                                                  (modelData.changeAmount >= 0 ? "+" : "") + modelData.changeAmount.toFixed(2) : "--"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.family: "monospace"
                                            color: root.getChangeColor(modelData.changeAmount)
                                        }

                                        // Change percent
                                        StyledText {
                                            width: 70
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            horizontalAlignment: Text.AlignRight
                                            text: modelData.changePercent !== 0 ? 
                                                  (modelData.changePercent >= 0 ? "+" : "") + modelData.changePercent.toFixed(2) + "%" : "--"
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.family: "monospace"
                                            font.bold: true
                                            color: root.getChangeColor(modelData.changeAmount)
                                        }
                                    }
                                    
                                    MouseArea {
                                        id: itemContentMouseArea
                                        anchors.fill: parent
                                        property real startX: 0
                                        property bool isDragging: false
                                        
                                        onPressed: {
                                            startX = mouse.x
                                            isDragging = true
                                            
                                            // Close other opened items
                                            if (root.currentOpenIndex !== -1 && root.currentOpenIndex !== index) {
                                                var previousItem = stockList.itemAtIndex(root.currentOpenIndex)
                                                if (previousItem && previousItem.children[1]) {
                                                    previousItem.children[1].x = 0
                                                }
                                            }
                                        }
                                        
                                        onPositionChanged: {
                                            if (isDragging) {
                                                var deltaX = mouse.x - startX
                                                if (deltaX < 0) {
                                                    itemContent.x = Math.max(deltaX, -70)
                                                } else if (itemContent.x < 0) {
                                                    itemContent.x = Math.min(0, itemContent.x + deltaX)
                                                }
                                            }
                                        }
                                        
                                        onReleased: {
                                            isDragging = false
                                            if (itemContent.x < -35) {
                                                itemContent.x = -70
                                                root.currentOpenIndex = index
                                            } else {
                                                itemContent.x = 0
                                                if (root.currentOpenIndex === index) {
                                                    root.currentOpenIndex = -1
                                                }
                                            }
                                        }
                                        
                                        onCanceled: {
                                            isDragging = false
                                            if (itemContent.x < -35) {
                                                itemContent.x = -70
                                            } else {
                                                itemContent.x = 0
                                            }
                                        }
                                    }
                                }
                                
                                // Delete action area
                                MouseArea {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 18
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 52
                                    enabled: itemContent.x <= -35
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.removeStock(modelData.code)
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        width: parent.width
                        height: 6
                    }

                    // Bottom Info Bar
                    Rectangle {
                        width: parent.width
                        height: 28
                        color: "transparent"

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS

                            // Stock Count - Left (clickable)
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
                                    text: root.isLoading ? root.t("loading") : `${root.stocks.filter(function(s) { return s.code !== "sh000001" }).length}${root.t("stocks_count")}`
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: stockCountMouseArea.containsMouse ? Theme.surface : Theme.primary
                                }
                                
                                MouseArea {
                                    id: stockCountMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        console.log("Stock count clicked, opening add dialog")
                                        root.showAddDialog = true
                                    }
                                }
                            }

                            // Last Update Time - Center
                            StyledText {
                                anchors.centerIn: parent
                                text: root.t("last_update") + root.lastUpdateTime
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.secondary
                            }

                            // Refresh Button - Right
                            DankIcon {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                name: "refresh"
                                size: 17
                                color: root.isLoading ? Theme.primary : Theme.surfaceVariantText

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
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
                
                // Add Stock Dialog
                Rectangle {
                    visible: root.showAddDialog
                    anchors.fill: parent
                    color: "#80000000"
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.showAddDialog = false
                    }
                    
                    Rectangle {
                        anchors.centerIn: parent
                        width: 280
                        height: 160
                        radius: 6
                        color: Theme.surface
                        border.color: Theme.primary
                        border.width: 1
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {} // Prevent click-through
                        }
                        
                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 15
                            spacing: 8
                            
                            // Title
                            StyledText {
                                width: parent.width
                                text: root.t("add_stock")
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                                color: Theme.primary
                            }
                            
                            // Stock Code Input
                            Column {
                                width: parent.width
                                spacing: 3
                                
                                StyledText {
                                    text: root.t("stock_code")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.secondary
                                }
                                
                                Rectangle {
                                    width: parent.width
                                    height: 28
                                    radius: 3
                                    color: Theme.surfaceVariant
                                    border.color: codeInput.activeFocus ? Theme.primary : "transparent"
                                    border.width: 1
                                    
                                    TextInput {
                                        id: codeInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                        selectByMouse: true
                                        maximumLength: 6
                                        
                                        onTextChanged: {
                                            var completeCode = root.autoCompleteStockCode(text)
                                            if (completeCode) {
                                                root.previewStockByCode(completeCode)
                                            } else {
                                                root.previewStock = null
                                            }
                                        }
                                        
                                        Keys.onPressed: {
                                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.previewStock) {
                                                event.accepted = true
                                                root.addStock(root.previewStock.code, root.previewStock.name, 0)
                                                root.showAddDialog = false
                                                codeInput.text = ""
                                                root.previewStock = null
                                            }
                                        }
                                        
                                        Text {
                                            visible: !parent.text && !parent.activeFocus
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: root.t("code_placeholder")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }
                            }
                            
                            // Preview Info
                            Row {
                                width: parent.width
                                height: 22
                                spacing: 4
                                
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.previewStock ? root.getCountryEmoji(root.previewStock.code) : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                                
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20
                                    text: root.previewStock ? `${root.previewStock.code} - ${root.previewStock.name}` : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.primary
                                    elide: Text.ElideRight
                                }
                            }
                            
                            // Button Row
                            Row {
                                width: parent.width
                                spacing: 8
                                
                                // Cancel Button
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 3
                                    color: Theme.surfaceVariant
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: root.t("cancel")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.primary
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showAddDialog = false
                                            codeInput.text = ""
                                            root.previewStock = null
                                        }
                                    }
                                }
                                
                                // Confirm Button
                                Rectangle {
                                    width: (parent.width - 8) / 2
                                    height: 28
                                    radius: 3
                                    color: root.previewStock ? Theme.primary : Theme.surfaceVariant
                                    opacity: root.previewStock ? 1.0 : 0.5
                                    
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: root.t("confirm")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.previewStock ? Theme.surface : Theme.surfaceVariantText
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: root.previewStock ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        enabled: root.previewStock !== null
                                        onClicked: {
                                            if (root.previewStock) {
                                                root.addStock(root.previewStock.code, root.previewStock.name, 0)
                                                root.showAddDialog = false
                                                codeInput.text = ""
                                                root.previewStock = null
                                                root.fetchStockData()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}