import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

Item {
    id: page

    implicitHeight: col.implicitHeight
    property var expandedProfiles: []

    function isExpanded(profileId) {
        return expandedProfiles.indexOf(profileId) !== -1;
    }

    function toggleProfile(profileId) {
        var next = expandedProfiles.slice();
        var index = next.indexOf(profileId);
        if (index === -1)
            next.push(profileId);
        else
            next.splice(index, 1);
        expandedProfiles = next;
    }

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Karing"
        }

        ListRow {
            width: parent.width
            glyph: Icons.vpn
            label: Karing.connected ? "Connected" : "Disconnected"
            sublabel: Karing.activeProfile.length ? Karing.activeProfile : Karing.available ? "Karing is ready" : "Karing is not running"
            selected: Karing.connected
            trailingText: Karing.pinging ? "Testing" : Karing.busy ? "..." : Karing.connected ? "Disconnect" : "Connect"
            enabled: Karing.available && !Karing.busy
            onActivated: Karing.toggle()
        }

        Text {
            text: "Profiles"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Text {
            width: parent.width
            visible: Karing.pinging
            text: "Testing server latency..."
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
        }

        Item {
            id: profileViewport
            width: parent.width
            height: Math.min(profileList.implicitHeight, 190)

            Text {
                anchors.fill: parent
                visible: Karing.profiles.length === 0
                text: !Karing.available ? "Start Karing to load saved profiles." : "No saved profiles found."
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
            }

            Flickable {
                id: profileFlick
                anchors.left: parent.left
                anchors.right: profileRail.left
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: Karing.profiles.length > 0
                clip: true
                contentHeight: profileList.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: profileList
                    width: profileFlick.width
                    spacing: 8

                    Repeater {
                        model: Karing.profiles
                        delegate: Column {
                            id: profileItem
                            required property var modelData
                            width: profileList.width
                            spacing: 4

                            Row {
                                width: parent.width
                                height: 50
                                spacing: 4

                                ListRow {
                                    id: profileHeader
                                    width: parent.width - pingAllButton.width - parent.spacing
                                    label: profileItem.modelData.name
                                    sublabel: profileItem.modelData.options.length + " servers"
                                    trailingText: page.isExpanded(profileItem.modelData.id) ? "Hide" : "Show"
                                    enabled: true
                                    onActivated: page.toggleProfile(profileItem.modelData.id)
                                }

                                IconButton {
                                    id: pingAllButton
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    glyph: Icons.refresh
                                    glyphSize: 11
                                    enabled: Karing.apiAvailable && !Karing.busy
                                    onClicked: Karing.pingAll(profileItem.modelData.id)
                                }
                            }

                            Repeater {
                                model: page.isExpanded(profileItem.modelData.id) ? profileItem.modelData.options : []
                                delegate: Row {
                                    id: optionRow
                                    required property var modelData
                                    width: profileItem.width
                                    height: 50
                                    spacing: 4

                                    ListRow {
                                        width: optionRow.width - pingButton.width - optionRow.spacing
                                        glyph: ""
                                        label: optionRow.modelData.name
                                        sublabel: {
                                            var result = Karing.pingResults[optionRow.modelData.name];
                                            var latency = result !== undefined ? (typeof result === "number" ? result + " ms" : result) : optionRow.modelData.latency;
                                            return optionRow.modelData.selected ? "Selected" + (latency ? " · " + latency : "") : latency;
                                        }
                                        selected: optionRow.modelData.selected
                                        enabled: !Karing.busy && !optionRow.modelData.selected
                                        onActivated: Karing.selectProfile(profileItem.modelData.id, optionRow.modelData.name)
                                    }

                                    IconButton {
                                        id: pingButton
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitWidth: 34
                                        implicitHeight: 34
                                        glyph: Icons.refresh
                                        glyphSize: 11
                                        enabled: Karing.apiAvailable && !Karing.busy
                                        onClicked: Karing.pingProfile(optionRow.modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ScrollRail {
                id: profileRail
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: profileFlick.visible
                flickable: profileFlick
            }
        }

        Text {
            width: parent.width
            visible: !Karing.apiAvailable && Karing.profiles.length > 0
            text: "Connect Karing to ping or apply a server."
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            visible: Karing.message.length > 0
            text: Karing.message
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}