import QtQuick
import qs.Common

/*
 * StockSparkline.qml - Draws a mini trend chart based on price history
 * The X-axis grows with the timestamp of the latest data point.
 */

Item {
    id: root
    property var history: []
    property color lineColor: Theme.primary
    property real prevClose: 0
    property real priceRangeRatio: 0
    readonly property var chartPoints: calculatePoints()

    width: 40; height: 16
    opacity: history && history.length > 1 ? 0.2 : 0

    Canvas {
        id: chartCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Threaded
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var points = root.chartPoints;
            if (points.length < 2) return;
            var bottom = root.height - 2;

            ctx.beginPath();
            ctx.moveTo(points[0].x, bottom);
            for (var i = 0; i < points.length; i++) ctx.lineTo(points[i].x, points[i].y);
            ctx.lineTo(points[points.length - 1].x, bottom);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.25).toString();
            ctx.fill();

            ctx.beginPath();
            for (var j = 0; j < points.length; j++) {
                if (j === 0) ctx.moveTo(points[j].x, points[j].y);
                else ctx.lineTo(points[j].x, points[j].y);
            }
            ctx.strokeStyle = root.lineColor.toString();
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }

    onChartPointsChanged: chartCanvas.requestPaint()
    onLineColorChanged: chartCanvas.requestPaint()

    function calculatePoints() {
        if (!root.history || root.history.length < 2) return [];

        // Convert to JS array if needed (handle QList/ListModel types)
        var data = root.history;
        if (!Array.isArray(data)) {
            data = Array.from(data);
        }

        var prices = data.map(function(d) {
            return (d && typeof d === 'object') ? d.price : d;
        });

        var min = root.prevClose > 0 && root.priceRangeRatio > 0
                ? root.prevClose * (1 - root.priceRangeRatio)
                : Math.min.apply(null, prices);
        var max = root.prevClose > 0 && root.priceRangeRatio > 0
                ? root.prevClose * (1 + root.priceRangeRatio)
                : Math.max.apply(null, prices);
        var range = max - min;
        if (range === 0) range = 1;

        var padding = 2;
        var drawWidth = Math.max(0, root.width - padding * 2) * dataProgress(data);

        var stepX = drawWidth / (data.length - 1);
        var bucketCount = Math.min(data.length, Math.max(1, Math.floor(drawWidth)));
        var pointIndexes = [];

        for (var bucket = 0; bucket < bucketCount; bucket++) {
            var start = Math.floor(bucket * data.length / bucketCount);
            var end = Math.max(start + 1, Math.floor((bucket + 1) * data.length / bucketCount));
            var minIndex = start;
            var maxIndex = start;
            for (var i = start + 1; i < end; i++) {
                if (prices[i] < prices[minIndex]) minIndex = i;
                if (prices[i] > prices[maxIndex]) maxIndex = i;
            }
            if (minIndex < maxIndex) {
                pointIndexes.push(minIndex, maxIndex);
            } else if (maxIndex < minIndex) {
                pointIndexes.push(maxIndex, minIndex);
            } else {
                pointIndexes.push(minIndex);
            }
        }

        var points = [];
        for (var j = 0; j < pointIndexes.length; j++) {
            var index = pointIndexes[j];
            var x = padding + index * stepX;
            var y = padding + (1 - (prices[index] - min) / range) * Math.max(0, root.height - padding * 2);
            points.push(Qt.point(x, y));
        }
        return points;
    }

    function dataProgress(data) {
        var lastItem = data[data.length - 1];
        if (!lastItem || typeof lastItem !== "object" || !lastItem.time) return 1;

        var today = Qt.formatDateTime(new Date(), "yyyy-MM-dd");
        if (lastItem.date && lastItem.date !== today) return 1;

        var parts = lastItem.time.split(":");
        if (parts.length < 2) return 1;
        var minutes = parseInt(parts[0]) * 60 + parseInt(parts[1]);
        if (minutes <= 570) return 0;
        if (minutes <= 690) return (minutes - 570) / 240;
        if (minutes < 780) return 0.5;
        if (minutes <= 900) return (120 + minutes - 780) / 240;
        return 1;
    }
}
