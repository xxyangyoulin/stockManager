import QtQuick
import qs.Widgets
import qs.Common
import "./StockUtils.js" as Utils

/*
 * StockListItem.qml - Individual stock row component
 * Supports swipe-to-delete functionality
 */

Item {
    id: root
    
    // Required properties
    property var stockData: null
    property int itemIndex: 0
    property bool isAlternate: false
    
    // Callbacks
    property var onDelete: function(code) {}
    property var onSwipeOpen: function(index) {}
    property var onSwipeClose: function() {}
    
    // Internal state
    property bool isOpen: false
    
    // Size
    width: parent ? parent.width : 440
    height: Utils.UI.ROW_HEIGHT
    clip: true
    
    // Delete button background (visible when swiped)
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Utils.UI.DELETE_BUTTON_WIDTH
        color: Utils.COLORS.DELETE
        radius: 4
        visible: itemContent.x < -5
        opacity: Math.min(1.0, Math.abs(itemContent.x) / 70)
        
        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }
        
        StyledText {
            anchors.centerIn: parent
            text: "删除"
            font.pixelSize: Theme.fontSizeSmall
            color: "white"
        }
    }
    
    // Main content container (draggable)
    Rectangle {
        id: itemContent
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width
        x: 0
        radius: 4
        color: root.isAlternate ? Theme.surfaceVariant : "transparent"
        opacity: 0.9
        
        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }
        
        // Data row
        Row {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 5
            
            // Name with country emoji
            Row {
                width: Utils.COLUMN_WIDTH.NAME
                height: parent.height
                spacing: 3
                
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Utils.getCountryEmoji(root.stockData ? root.stockData.code : "")
                    font.pixelSize: Theme.fontSizeMedium
                }
                
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20
                    text: root.stockData ? root.stockData.name : ""
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.primary
                    elide: Text.ElideRight
                }
            }
            
            // Stock code
            StyledText {
                width: Utils.COLUMN_WIDTH.CODE
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.stockData ? Utils.getPureCode(root.stockData.code) : "--"
                font.pixelSize: Theme.fontSizeMedium
                font.family: "monospace"
                color: Theme.secondary
            }
            
            // Current price
            StyledText {
                width: Utils.COLUMN_WIDTH.PRICE
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.stockData ? Utils.formatNumber(root.stockData.currentPrice) : "--"
                font.pixelSize: Theme.fontSizeMedium
                font.family: "monospace"
                color: Theme.primary
            }
            
            // Change amount
            StyledText {
                width: Utils.COLUMN_WIDTH.CHANGE
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.stockData ? Utils.formatChange(root.stockData.changeAmount) : "--"
                font.pixelSize: Theme.fontSizeMedium
                font.family: "monospace"
                color: root.stockData ? Utils.getChangeColor(root.stockData.changeAmount) : Utils.COLORS.NEUTRAL
            }
            
            // Change percent
            StyledText {
                width: Utils.COLUMN_WIDTH.PERCENT
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.stockData ? Utils.formatPercent(root.stockData.changePercent) : "--"
                font.pixelSize: Theme.fontSizeMedium
                font.family: "monospace"
                font.bold: true
                color: root.stockData ? Utils.getChangeColor(root.stockData.changeAmount) : Utils.COLORS.NEUTRAL
            }
        }
        
        // Swipe gesture handler
        MouseArea {
            id: swipeArea
            anchors.fill: parent
            property real startX: 0
            property bool isDragging: false
            
            onPressed: function(mouse) {
                startX = mouse.x;
                isDragging = true;
                // Notify parent to close other items
                if (!root.isOpen) {
                    root.onSwipeOpen(root.itemIndex);
                }
            }
            
            onPositionChanged: function(mouse) {
                if (!isDragging) return;
                
                var deltaX = mouse.x - startX;
                if (deltaX < 0) {
                    // Swiping left - open
                    itemContent.x = Math.max(deltaX, Utils.UI.DELETE_MAX_DRAG);
                } else if (itemContent.x < 0) {
                    // Swiping right - close
                    itemContent.x = Math.min(0, itemContent.x + deltaX);
                }
            }
            
            onReleased: {
                isDragging = false;
                finalizeSwipe();
            }
            
            onCanceled: {
                isDragging = false;
                finalizeSwipe();
            }
            
            function finalizeSwipe() {
                if (itemContent.x < Utils.UI.DELETE_THRESHOLD) {
                    itemContent.x = Utils.UI.DELETE_MAX_DRAG;
                    root.isOpen = true;
                } else {
                    itemContent.x = 0;
                    root.isOpen = false;
                    root.onSwipeClose();
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
        width: Utils.UI.DELETE_BUTTON_WIDTH
        enabled: itemContent.x <= Utils.UI.DELETE_THRESHOLD
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.stockData) {
                root.onDelete(root.stockData.code);
            }
        }
    }
    
    // Public method to close swipe
    function closeSwipe() {
        itemContent.x = 0;
        isOpen = false;
    }
}
