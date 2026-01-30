import QtQuick
import QtQuick.Controls 2.15
import qs.Widgets
import qs.Common
import "./StockUtils.js" as Utils

/*
 * AddStockDialog.qml - Dialog for adding new stocks
 * Features code input with auto-complete and preview
 */

Rectangle {
    id: root
    
    // Properties
    property var translationFunc: function(key) { return key; }
    property var previewStock: null
    
    // Callbacks
    property var onConfirm: function(code, name) {}
    property var onCancel: function() {}
    property var onCodeChanged: function(code) {}
    
    // State
    property string inputText: ""
    
    // UI
    anchors.fill: parent
    color: "#80000000"
    visible: false
    
    // Close on outside click
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }
    
    // Dialog content
    Rectangle {
        anchors.centerIn: parent
        width: Utils.UI.DIALOG_WIDTH
        height: Utils.UI.DIALOG_HEIGHT
        radius: 6
        color: Theme.surface
        border.color: Theme.primary
        border.width: 1
        
        // Prevent click-through
        MouseArea {
            anchors.fill: parent
            onClicked: {}
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
                text: root.translationFunc("add_stock")
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                color: Theme.primary
            }
            
            // Stock Code Input
            Column {
                width: parent.width
                spacing: 3
                
                StyledText {
                    text: root.translationFunc("stock_code")
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
                            root.inputText = text;
                            var completeCode = Utils.autoCompleteStockCode(text);
                            root.onCodeChanged(completeCode);
                        }
                        
                        Keys.onPressed: function(event) {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.previewStock) {
                                event.accepted = true;
                                root.confirm();
                            }
                        }
                        
                        Text {
                            visible: !parent.text && !parent.activeFocus
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: root.translationFunc("code_placeholder")
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
                    text: root.previewStock ? Utils.getCountryEmoji(root.previewStock.code) : ""
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
                        text: root.translationFunc("cancel")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.primary
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
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
                        text: root.translationFunc("confirm")
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.previewStock ? Theme.surface : Theme.surfaceVariantText
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.previewStock ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.previewStock !== null
                        onClicked: root.confirm()
                    }
                }
            }
        }
    }
    
    // Public methods
    function open() {
        codeInput.text = "";
        inputText = "";
        previewStock = null;
        visible = true;
        codeInput.forceActiveFocus();
    }
    
    function close() {
        visible = false;
        onCancel();
    }
    
    function confirm() {
        if (previewStock) {
            onConfirm(previewStock.code, previewStock.name);
            close();
        }
    }
}
