import QtQuick
import QtQuick.Shapes
import "../services/StockUtils.js" as Utils
import "../services"
import ".."
import qs.Common
import qs.Widgets

/*
 * StockDetailPopup.qml - Overlay detail chart for a specific stock
 */

Item {
    id: root
    anchors.fill: parent
    z: 100 // On top of everything

    property var stock: null // The stock data object
    property string chartMode: "intraday"
    property var dailyData: []
    property var dailyCache: ({})
    property string dailyCode: ""
    property bool dailyLoading: false
    readonly property real priceRangeRatio: Utils.getPriceRangeRatio(stock)
    signal close()

    // Geometry for animation
    property real startX: 0
    property real startY: 0
    property real startW: 0
    property real startH: 0

    visible: opacity > 0
    opacity: 0
    enabled: state === "expanded"
    focus: true

    Keys.enabled: state === "expanded"
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequest();
            event.accepted = true;
        }
    }

    // Tooltip properties
    property real tooltipX: 0
    property real tooltipY: 0
    property var tooltipData: null
    property bool isHovering: false

    StockApiService {
        id: chartApi
    }

    // Dimmed background
    Rectangle {
        id: dimBackground
        anchors.fill: parent
        color: "#80000000"
        opacity: 0
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequest()
        }
    }

    // Chart Container
    Rectangle {
        id: chartCard
        // Initial state matches start geometry
        x: startX
        y: startY
        width: startW
        height: startH
        
        color: Theme.surface
        radius: 8
        border.color: Theme.primary
        border.width: 1
        clip: true

        // Consume clicks inside the card
        MouseArea {
            anchors.fill: parent
        }

        // Content Wrapper for Opacity Animation
        Item {
            id: contentWrapper
            anchors.fill: parent
            opacity: 0

            // Title Header
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 10

                    StyledText {
                        text: root.stock ? root.stock.name : ""
                        font.bold: true
                        font.pixelSize: Theme.fontSizeLarge
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.stock ? Utils.getPureCode(root.stock.code) : ""
                        color: Theme.secondary
                        font.pixelSize: Theme.fontSizeMedium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: closeButton.left
                    anchors.rightMargin: 6
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    spacing: 10

                                    StyledText {
                                        text: root.stock ? Utils.formatNumber(root.stock.currentPrice) : ""
                                        font.bold: true
                                        font.pixelSize: Theme.fontSizeLarge
                                        color: root.stock ? StockService.getChangeColor(root.stock.changeAmount) : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    
                                    StyledText {
                                        text: root.stock ? Utils.formatPercent(root.stock.changePercent) : ""
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: root.stock ? StockService.getChangeColor(root.stock.changeAmount) : Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }                }

                Rectangle {
                    id: closeButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    color: closeMouse.containsMouse ? Theme.surfaceVariant : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
                        color: Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequest()
                    }
                }
            }

            Item {
                id: modeBar
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                height: 26

                Row {
                    spacing: 4

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.chartMode === "intraday" ? Theme.primaryContainer : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "分时"
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.chartMode === "intraday" ? Theme.primary : Theme.surfaceVariantText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectChartMode("intraday")
                        }
                    }

                    Rectangle {
                        width: 44; height: 24; radius: 12
                        color: root.chartMode === "daily" ? Theme.primaryContainer : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "日K"
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.chartMode === "daily" ? Theme.primary : Theme.surfaceVariantText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectChartMode("daily")
                        }
                    }
                }
            }

            // Canvas for drawing the chart
            Canvas {
                id: chartCanvas
                anchors.top: modeBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                visible: root.chartMode === "intraday"
                renderStrategy: Canvas.Threaded
                onPaint: root.paintIntradayChart()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Canvas {
                id: hoverCanvas
                anchors.fill: chartCanvas
                visible: root.chartMode === "intraday"
                renderStrategy: Canvas.Threaded
                onPaint: root.paintIntradayHover()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Canvas {
                id: dailyCanvas
                anchors.fill: chartCanvas
                visible: root.chartMode === "daily"
                renderStrategy: Canvas.Threaded
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    var w = width;
                    var h = height;
                    ctx.reset();

                    var data = root.dailyData;
                    if (!data || data.length === 0) return;

                    var top = 4;
                    var chartLeft = 38;
                    var chartWidth = w - chartLeft;
                    var priceBottom = Math.floor(h * 0.72);
                    var volumeTop = priceBottom + 6;
                    var volumeBottom = h - 14;
                    var minPrice = Number.MAX_VALUE;
                    var maxPrice = 0;
                    var maxVolume = 0;

                    for (var i = 0; i < data.length; i++) {
                        minPrice = Math.min(minPrice, data[i].low);
                        maxPrice = Math.max(maxPrice, data[i].high);
                        maxVolume = Math.max(maxVolume, data[i].volume);
                    }

                    var padding = (maxPrice - minPrice) * 0.05;
                    if (padding === 0) padding = maxPrice * 0.005;
                    minPrice -= padding;
                    maxPrice += padding;
                    var priceRange = maxPrice - minPrice;
                    var slot = chartWidth / data.length;
                    var candleWidth = Math.max(2, Math.min(6, slot * 0.62));

                    function priceY(value) {
                        return priceBottom - (value - minPrice) / priceRange * (priceBottom - top);
                    }

                    ctx.lineWidth = 0.5;
                    ctx.strokeStyle = Utils.COLORS.NEUTRAL;
                    ctx.globalAlpha = 0.3;
                    for (var grid = 0; grid < 3; grid++) {
                        var gridY = top + grid * (priceBottom - top) / 2;
                        ctx.beginPath();
                        ctx.moveTo(chartLeft, gridY);
                        ctx.lineTo(w, gridY);
                        ctx.stroke();
                    }
                    ctx.globalAlpha = 1;

                    ctx.font = "10px sans-serif";
                    ctx.fillStyle = Theme.surfaceVariantText.toString();
                    ctx.textBaseline = "middle";
                    for (var label = 0; label < 3; label++) {
                        var labelY = top + label * (priceBottom - top) / 2;
                        var labelPrice = maxPrice - label * (maxPrice - minPrice) / 2;
                        ctx.fillText(labelPrice.toFixed(2), 0, labelY);
                    }

                    for (var index = 0; index < data.length; index++) {
                        var candle = data[index];
                        var x = chartLeft + (index + 0.5) * slot;
                        var color = candle.close >= candle.open ? StockService.upColor : StockService.downColor;
                        var colorString = color.toString();

                        ctx.strokeStyle = colorString;
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.moveTo(x, priceY(candle.high));
                        ctx.lineTo(x, priceY(candle.low));
                        ctx.stroke();

                        var bodyTop = priceY(Math.max(candle.open, candle.close));
                        var bodyBottom = priceY(Math.min(candle.open, candle.close));
                        ctx.fillStyle = colorString;
                        ctx.fillRect(x - candleWidth / 2, bodyTop, candleWidth, Math.max(1, bodyBottom - bodyTop));

                        var volumeHeight = maxVolume > 0
                                ? candle.volume / maxVolume * (volumeBottom - volumeTop)
                                : 0;
                        ctx.globalAlpha = 0.35;
                        ctx.fillRect(x - candleWidth / 2, volumeBottom - volumeHeight, candleWidth, volumeHeight);
                        ctx.globalAlpha = 1;
                    }

                    ctx.textBaseline = "bottom";
                    ctx.fillText(data[0].date.substring(5), chartLeft, h);
                    var lastDate = data[data.length - 1].date.substring(5);
                    var dateWidth = ctx.measureText(lastDate).width;
                    ctx.fillText(lastDate, w - dateWidth, h);
                }
            }

            Canvas {
                id: dailyHoverCanvas
                anchors.fill: chartCanvas
                visible: root.chartMode === "daily"
                renderStrategy: Canvas.Threaded

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    if (!root.isHovering || !root.dailyData || root.dailyData.length === 0) return;

                    var chartLeft = 38;
                    var slot = (width - chartLeft) / root.dailyData.length;
                    var index = Math.max(0, Math.min(root.dailyData.length - 1, Math.floor((root.tooltipX - chartLeft) / slot)));
                    var x = chartLeft + (index + 0.5) * slot;
                    root.tooltipData = root.dailyData[index];

                    ctx.strokeStyle = Theme.primary;
                    ctx.lineWidth = 0.5;
                    ctx.setLineDash([4, 4]);
                    ctx.beginPath();
                    ctx.moveTo(x, 0);
                    ctx.lineTo(x, height);
                    ctx.stroke();
                    ctx.setLineDash([]);
                }
            }

            StyledText {
                anchors.centerIn: chartCanvas
                visible: root.chartMode === "daily" && (root.dailyLoading || root.dailyData.length === 0)
                text: root.dailyLoading ? "加载日K数据…" : "暂无日K数据"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            // Hover MouseArea
            MouseArea {
                id: hoverArea
                anchors.fill: chartCanvas
                hoverEnabled: true
                onClicked: root.closeRequest()
                onPositionChanged: (mouse) => {
                     root.tooltipX = mouse.x;
                     root.tooltipY = mouse.y;
                     root.isHovering = true;
                     if (root.chartMode === "daily") dailyHoverCanvas.requestPaint();
                     else hoverCanvas.requestPaint();
                }
                onExited: {
                    root.isHovering = false;
                    if (root.chartMode === "daily") dailyHoverCanvas.requestPaint();
                    else hoverCanvas.requestPaint();
                }
            }

            // QML Tooltip Overlay
            Rectangle {
                id: tooltip
                width: tooltipRow.width + 16
                height: tooltipRow.height + 12
                radius: 6
                color: Theme.surface
                border.color: Theme.surfaceVariant
                border.width: 1
                
                visible: root.isHovering && root.tooltipData !== null
                opacity: visible ? 1 : 0
                
                // Position logic: floating near point
                x: {
                    var tx = root.tooltipX + 10;
                    if (tx + width > chartCanvas.width) tx = root.tooltipX - width - 10;
                    return Math.max(0, tx) + chartCanvas.x; // Add canvas offset
                }
                y: {
                    return root.tooltipY + chartCanvas.y - height - 10; 
                }

                Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                Behavior on y { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                Row {
                    id: tooltipRow
                    anchors.centerIn: parent
                    spacing: 8
                    
                    StyledText {
                        text: root.tooltipData
                              ? (root.chartMode === "daily" ? root.tooltipData.date : (root.tooltipData.time || "--:--"))
                              : ""
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: {
                            if (!root.tooltipData) return "";
                            if (root.chartMode === "daily") {
                                return "开 " + root.tooltipData.open.toFixed(2) + "  收 " + root.tooltipData.close.toFixed(2);
                            }
                            return typeof root.tooltipData.price === "number" ? root.tooltipData.price.toFixed(2) : "--";
                        }
                        font.bold: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: {
                            if (!root.tooltipData || !root.stock) return Theme.surfaceText;
                            if (root.chartMode === "daily") {
                                return StockService.getChangeColor(root.tooltipData.close - root.tooltipData.open);
                            }
                            return StockService.getChangeColor(root.tooltipData.price - root.stock.prevClose);
                        }
                    }

                    StyledText {
                        text: {
                            if (!root.tooltipData) return "";
                            if (root.chartMode === "daily") {
                                return "高 " + root.tooltipData.high.toFixed(2) + "  低 " + root.tooltipData.low.toFixed(2);
                            }
                            if (typeof root.tooltipData.price !== "number" || !root.stock) return "--%";
                            return ((root.tooltipData.price - root.stock.prevClose) / root.stock.prevClose * 100).toFixed(2) + "%";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.chartMode === "daily" ? Theme.surfaceText : (root.tooltipData && root.stock
                               ? StockService.getChangeColor(root.tooltipData.price - root.stock.prevClose)
                               : Theme.surfaceText)
                    }
                }
            }
        }
    }

    onStockChanged: chartCanvas.requestPaint()

    // Animation States
    states: [
        State {
            name: "expanded"
            PropertyChanges { target: root; opacity: 1 }
            PropertyChanges { target: dimBackground; opacity: 1 }
            // Center the card
            PropertyChanges { 
                target: chartCard
                x: (root.width - Math.min(480, root.width - 24)) / 2
                y: (root.height - Math.min(300, root.height - 24)) / 2
                width: Math.min(480, root.width - 24)
                height: Math.min(300, root.height - 24)
                radius: 16
                border.color: Theme.surfaceVariant
            }
            PropertyChanges { target: contentWrapper; opacity: 1 }
        }
    ]

    transitions: [
        Transition {
            from: ""
            to: "expanded"
            ParallelAnimation {
                NumberAnimation { target: root; property: "opacity"; duration: 150 }
                NumberAnimation { target: dimBackground; property: "opacity"; duration: 250 }
                NumberAnimation { 
                    target: chartCard
                    properties: "x,y,width,height,radius"
                    duration: 350
                    easing.type: Easing.OutCubic
                }
                ColorAnimation { target: chartCard; property: "border.color"; duration: 350 }
                SequentialAnimation {
                    PauseAnimation { duration: 150 }
                    NumberAnimation { target: contentWrapper; property: "opacity"; duration: 200 }
                }
            }
        },
        Transition {
            from: "expanded"
            to: ""
            ParallelAnimation {
                NumberAnimation { target: contentWrapper; property: "opacity"; duration: 100 }
                NumberAnimation { 
                    target: chartCard
                    properties: "x,y,width,height,radius"
                    duration: 250
                    easing.type: Easing.InCubic
                }
                ColorAnimation { target: chartCard; property: "border.color"; duration: 250 }
                NumberAnimation { target: dimBackground; property: "opacity"; duration: 250 }
                NumberAnimation { target: root; property: "opacity"; duration: 250 }
            }
        }
    ]

    function open(x, y, w, h, stockData) {
        root.startX = x;
        root.startY = y;
        root.startW = w;
        root.startH = h;
        root.chartMode = "intraday";
        root.isHovering = false;
        root.tooltipData = null;
        root.dailyCode = stockData.code;
        root.dailyData = root.dailyCache[stockData.code] || [];
        root.dailyLoading = false;
        root.stock = stockData;
        root.state = "expanded";
        Qt.callLater(() => root.forceActiveFocus());
    }

    function selectChartMode(mode) {
        if (root.chartMode === mode) return;

        root.chartMode = mode;
        root.isHovering = false;
        root.tooltipData = null;

        if (mode === "intraday") {
            chartCanvas.requestPaint();
            hoverCanvas.requestPaint();
            return;
        }

        dailyCanvas.requestPaint();
        dailyHoverCanvas.requestPaint();
        if (!root.stock || (root.dailyCode === root.stock.code && (root.dailyLoading || root.dailyData.length > 0))) return;

        var code = root.stock.code;
        root.dailyCode = code;
        root.dailyData = [];
        root.dailyLoading = true;
        chartApi.fetchDaily(code, function (data) {
            if (!root.stock || root.stock.code !== code || root.dailyCode !== code) return;
            var cache = Object.assign({}, root.dailyCache);
            cache[code] = data;
            root.dailyCache = cache;
            root.dailyData = data;
            root.dailyLoading = false;
            dailyCanvas.requestPaint();
        });
    }

    function closeRequest() {
        root.state = "";
        root.close(); // Emit signal
    }

    function paintIntradayChart() {
            var ctx = chartCanvas.getContext("2d");
            var w = chartCanvas.width;
            var h = chartCanvas.height;
            
            // Define margins
            var leftMargin = 38;
            var verticalMargin = 20;
            var chartW = w - leftMargin;
            var drawHeight = h - 2 * verticalMargin;
            
            function toColorStr(c, alpha) {
                // Handle hex strings (e.g. "#ff0000")
                if (typeof c === 'string') return c;
                
                // Handle Qt Color objects
                if (c && c.r !== undefined) {
                    var a = (alpha !== undefined) ? alpha : (c.a !== undefined ? c.a : 1.0);
                    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
                }
                return "black";
            }
            
            ctx.reset();

            if (!root.stock || !root.stock.history || root.stock.history.length === 0) {
                return;
            }

            var data = root.stock.history; 
            var prevClose = root.stock.prevClose;

            // 1. Calculate Range
            var maxPrice = 0;
            var minPrice = Number.MAX_VALUE;
            
            for (var i = 0; i < data.length; i++) {
                var p = (typeof data[i] === 'object') ? data[i].price : data[i];
                if (p > maxPrice) maxPrice = p;
                if (p < minPrice) minPrice = p;
            }

            if (maxPrice === 0) maxPrice = prevClose;
            if (minPrice === Number.MAX_VALUE) minPrice = prevClose;

            var maxDiff = root.priceRangeRatio > 0
                    ? prevClose * root.priceRangeRatio
                    : Math.max(Math.abs(maxPrice - prevClose), Math.abs(minPrice - prevClose));
            if (maxDiff <= 0) maxDiff = prevClose * 0.005;

            var topPrice = prevClose + maxDiff;
            var bottomPrice = prevClose - maxDiff;
            var range = topPrice - bottomPrice;
            
            // Helper for Y mapping
            function getY(val) {
                return (h - verticalMargin) - ((val - bottomPrice) / range * drawHeight);
            }
            
            // Helper: Map time string "HH:mm" to X coordinate
            function getX(timeStr) {
                if (!timeStr) return leftMargin;
                var parts = timeStr.split(":");
                if (parts.length < 2) return leftMargin;
                
                var h = parseInt(parts[0]);
                var m = parseInt(parts[1]);
                var totalMin = h * 60 + m;
                
                var offset = 0;
                if (totalMin < 570) offset = 0;
                else if (totalMin <= 690) offset = totalMin - 570;
                else if (totalMin < 780) offset = 120; 
                else if (totalMin <= 900) offset = 120 + (totalMin - 780);
                else offset = 240;
                
                return leftMargin + (offset / 240.0) * chartW;
            }

            // 2. Draw Grid / Axes
            ctx.lineWidth = 0.5;
            ctx.strokeStyle = toColorStr(Utils.COLORS.NEUTRAL, 0.6);

            var zeroY = getY(prevClose);

            ctx.font = "10px sans-serif";
            ctx.fillStyle = toColorStr(Theme.surfaceVariantText);
            ctx.textBaseline = "middle";
            ctx.fillText(topPrice.toFixed(2), 0, verticalMargin);
            ctx.fillText(prevClose.toFixed(2), 0, zeroY);
            ctx.fillText(bottomPrice.toFixed(2), 0, h - verticalMargin);

            ctx.beginPath();
            ctx.setLineDash([4, 2]);
            ctx.moveTo(leftMargin, zeroY);
            ctx.lineTo(w, zeroY);
            ctx.stroke();
            ctx.setLineDash([]);

            // Limit Lines
            var limitRatio = root.priceRangeRatio > 0 ? root.priceRangeRatio : 0.1;
            var limitUp = prevClose * (1 + limitRatio);
            var limitDown = prevClose * (1 - limitRatio);
            ctx.setLineDash([2, 2]);
            
            if (limitUp <= topPrice && limitUp >= bottomPrice) {
                var luY = getY(limitUp);
                ctx.strokeStyle = Utils.COLORS.UP; 
                ctx.beginPath();
                ctx.moveTo(leftMargin, luY);
                ctx.lineTo(w, luY);
                ctx.stroke();
            }

            if (limitDown <= topPrice && limitDown >= bottomPrice) {
                var ldY = getY(limitDown);
                ctx.strokeStyle = Utils.COLORS.DOWN;
                ctx.beginPath();
                ctx.moveTo(leftMargin, ldY);
                ctx.lineTo(w, ldY);
                ctx.stroke();
            }
            ctx.setLineDash([]);

            // Determine dynamic line color
            var lineColor = Theme.primary;
            if (root.stock) {
                 lineColor = StockService.getChangeColor(root.stock.changeAmount);
            }

            ctx.beginPath();
            ctx.moveTo(getX((typeof data[0] === 'object') ? data[0].time : "09:30"), h - verticalMargin);
            for (var areaIndex = 0; areaIndex < data.length; areaIndex++) {
                var areaItem = data[areaIndex];
                var areaValue = (typeof areaItem === 'object') ? areaItem.price : areaItem;
                var areaTime = (typeof areaItem === 'object') ? areaItem.time : "09:30";
                ctx.lineTo(getX(areaTime), getY(areaValue));
            }
            ctx.lineTo(getX((typeof data[data.length - 1] === 'object') ? data[data.length - 1].time : "09:30"), h - verticalMargin);
            ctx.closePath();
            ctx.fillStyle = toColorStr(lineColor, 0.14);
            ctx.fill();

            // 2.5 Draw Current Price Label & Line (Before Polyline)
            if (data.length > 0) {
                var lastItem = data[data.length - 1];
                var curPrice = (typeof lastItem === 'object') ? lastItem.price : lastItem;
                var curY = getY(curPrice);

                // Label Content - calculate change based on history data point
                var priceChange = curPrice - prevClose;
                var pctVal = priceChange / prevClose * 100;
                var sign = pctVal >= 0 ? "+" : "";
                var txt = sign + pctVal.toFixed(2) + "%";

                // Determine text color based on actual price change
                var priceColor = StockService.getChangeColor(priceChange);

                ctx.font = "bold 11px sans-serif";
                var tm = ctx.measureText(txt);
                var textW = tm.width;

                // Dashed Line (Full width)
                ctx.beginPath();
                ctx.setLineDash([4, 4]);
                ctx.strokeStyle = toColorStr(Theme.primary, 0.8);
                ctx.lineWidth = 0.5;
                ctx.moveTo(leftMargin, curY);
                ctx.lineTo(w, curY);
                ctx.stroke();
                ctx.setLineDash([]);

                // Text (Right side, below line)
                // 重置阴影和透明度属性，确保颜色正确显示
                ctx.shadowColor = "transparent";
                ctx.shadowBlur = 0;
                ctx.shadowOffsetX = 0;
                ctx.shadowOffsetY = 0;
                ctx.globalAlpha = 1.0;
                ctx.save();
                ctx.fillStyle = toColorStr(priceColor);
                ctx.textBaseline = "top";
                ctx.fillText(txt, w - textW, curY + 2);
                ctx.restore();
            }

            // 3. Draw Line
            ctx.beginPath();
            
            ctx.strokeStyle = toColorStr(lineColor);
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";

            for (var j = 0; j < data.length; j++) {
                var item = data[j];
                var val = (typeof item === 'object') ? item.price : item;
                var time = (typeof item === 'object') ? item.time : "09:30";
                
                var x = getX(time);
                var y = getY(val);
                
                if (j === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
            ctx.lineWidth = 1; 

    }

    function paintIntradayHover() {
            var ctx = hoverCanvas.getContext("2d");
            var w = hoverCanvas.width;
            var h = hoverCanvas.height;
            ctx.reset();

            if (!root.isHovering || !root.stock || !root.stock.history || root.stock.history.length === 0) return;

            var data = root.stock.history;
            var prevClose = root.stock.prevClose;
            var maxPrice = 0;
            var minPrice = Number.MAX_VALUE;
            for (var i = 0; i < data.length; i++) {
                var price = (typeof data[i] === 'object') ? data[i].price : data[i];
                if (price > maxPrice) maxPrice = price;
                if (price < minPrice) minPrice = price;
            }

            var maxDiff = root.priceRangeRatio > 0
                    ? prevClose * root.priceRangeRatio
                    : Math.max(Math.abs(maxPrice - prevClose), Math.abs(minPrice - prevClose));
            if (maxDiff <= 0) maxDiff = prevClose * 0.005;
            var bottomPrice = prevClose - maxDiff;
            var range = maxDiff * 2;
            var drawHeight = h - 40;

            function getY(value) {
                return (h - 20) - ((value - bottomPrice) / range * drawHeight);
            }

            function getX(timeStr) {
                var parts = timeStr.split(":");
                var totalMin = parseInt(parts[0]) * 60 + parseInt(parts[1]);
                var offset = 0;
                if (totalMin < 570) offset = 0;
                else if (totalMin <= 690) offset = totalMin - 570;
                else if (totalMin < 780) offset = 120;
                else if (totalMin <= 900) offset = 120 + (totalMin - 780);
                else offset = 240;
                return 38 + (offset / 240.0) * (w - 38);
            }

            var bestDist = Number.MAX_VALUE;
            var bestItem = null;
            var bestX = 0;
            var bestY = 0;
            for (var j = 0; j < data.length; j++) {
                var item = data[j];
                var x = getX((typeof item === 'object') ? item.time : "09:30");
                var dist = Math.abs(x - root.tooltipX);
                if (dist < bestDist) {
                    bestDist = dist;
                    bestItem = item;
                    bestX = x;
                    bestY = getY((typeof item === 'object') ? item.price : item);
                }
            }

            if (!bestItem) return;
            root.tooltipData = bestItem;
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = 0.5;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.moveTo(bestX, 0);
            ctx.lineTo(bestX, h);
            ctx.moveTo(38, bestY);
            ctx.lineTo(w, bestY);
            ctx.stroke();
            ctx.setLineDash([]);
    }
}
