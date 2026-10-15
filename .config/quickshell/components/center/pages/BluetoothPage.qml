import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

Item {
    id: page

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        Item {
            width: parent.width
            height: Config.pageHeaderHeight

            PageHeader {
                anchors.fill: parent
                title: "Bluetooth"
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                glyph: Icons.refresh
                glyphSize: 12
                enabled: Bluetooth.powered && !Bluetooth.busy
                onClicked: Bluetooth.startScan()
            }
        }

        ListRow {
            width: parent.width
            glyph: Icons.bluetooth
            label: "Bluetooth"
            sublabel: Bluetooth.powered ? "Adapter is on" : "Adapter is off"
            selected: Bluetooth.powered
            trailingText: Bluetooth.powered ? "On" : "Off"
            enabled: !Bluetooth.busy
            onActivated: Bluetooth.togglePower()
        }

        Text {
            text: "Devices"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Item {
            id: deviceViewport
            width: parent.width
            height: 196

            Text {
                anchors.fill: parent
                visible: !Bluetooth.powered
                text: "Turn Bluetooth on to browse devices."
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 12
                verticalAlignment: Text.AlignVCenter
            }

            Flickable {
                id: deviceFlick
                anchors.left: parent.left
                anchors.right: rail.left
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: Bluetooth.powered
                clip: true
                contentHeight: deviceColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: deviceColumn
                    width: deviceFlick.width
                    spacing: 6

                    Repeater {
                        model: Bluetooth.devices
                        delegate: ListRow {
                            required property var modelData
                            width: deviceColumn.width
                            glyph: Icons.bluetooth
                            label: modelData.name
                            sublabel: modelData.connected ? "Connected" + (modelData.battery !== null ? " · " + modelData.battery + "% battery" : "") : modelData.paired ? "Paired" + (modelData.battery !== null ? " · " + modelData.battery + "% battery" : "") : "Not paired · " + modelData.address
                            selected: modelData.connected
                            trailingText: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
                            enabled: Bluetooth.powered && !Bluetooth.busy
                            onActivated: Bluetooth.toggleDevice(modelData)
                        }
                    }

                    Text {
                        width: deviceColumn.width
                        height: Bluetooth.devices.length === 0 ? 54 : 0
                        visible: Bluetooth.devices.length === 0
                        text: Bluetooth.scanning ? "Scanning for devices..." : "No devices found. Scan to discover nearby devices."
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            ScrollRail {
                id: rail
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: Bluetooth.powered
                flickable: deviceFlick
            }
        }

        Text {
            width: parent.width
            visible: Bluetooth.message.length > 0
            text: Bluetooth.message
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}