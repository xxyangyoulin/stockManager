import QtQuick
import qs.Widgets
import qs.Common
import "./StockUtils.js" as Utils

/*
 * StockTableHeader.qml - Table header component for stock list
 * Clickable column headers for sorting
 */

Rectangle {
    id: root
    
    // Properties
    property var translationFunc: function(key) { return key; }
    property var onSort: function(key) {}
    
    // Size
    width: parent ? parent.width : 440
    height: Utils.UI.HEADER_HEIGHT
    radius: 4
    color: Theme.surfaceVariant
    
    // Header column definition
    Row {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 5
        
        // Name column
        HeaderCell {
            width: Utils.COLUMN_WIDTH.NAME
            height: parent.height
            text: root.translationFunc("header_name")
            horizontalAlignment: Text.AlignLeft
            sortKey: "name"
            onClicked: root.onSort(sortKey)
        }
        
        // Code column
        HeaderCell {
            width: Utils.COLUMN_WIDTH.CODE
            height: parent.height
            text: root.translationFunc("header_code")
            horizontalAlignment: Text.AlignRight
            sortKey: "code"
            onClicked: root.onSort(sortKey)
        }
        
        // Price column
        HeaderCell {
            width: Utils.COLUMN_WIDTH.PRICE
            height: parent.height
            text: root.translationFunc("header_price")
            horizontalAlignment: Text.AlignRight
            sortKey: "price"
            onClicked: root.onSort(sortKey)
        }
        
        // Change column
        HeaderCell {
            width: Utils.COLUMN_WIDTH.CHANGE
            height: parent.height
            text: root.translationFunc("header_change")
            horizontalAlignment: Text.AlignRight
            sortKey: "change"
            onClicked: root.onSort(sortKey)
        }
        
        // Percent column
        HeaderCell {
            width: Utils.COLUMN_WIDTH.PERCENT
            height: parent.height
            text: root.translationFunc("header_percent")
            horizontalAlignment: Text.AlignRight
            sortKey: "percent"
            onClicked: root.onSort(sortKey)
        }
    }
    
    // Header cell component
    component HeaderCell: Rectangle {
        property string text: ""
        property int horizontalAlignment: Text.AlignLeft
        property string sortKey: ""
        signal clicked()
        
        color: "transparent"
        
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
        
        StyledText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: parent.horizontalAlignment
            text: parent.text
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
            color: Theme.primary
        }
    }
}
