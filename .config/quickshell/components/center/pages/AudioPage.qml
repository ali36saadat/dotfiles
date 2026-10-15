import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Audio drill-down: output and input levels, then device selection.
Item {
    id: page
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Audio"
        }

        SliderRow {
            width: parent.width
            glyph: Audio.volume > 0.5 ? Icons.volumeHigh : Icons.volumeLow
            glyphOff: Icons.volumeMute
            value: Audio.volume
            off: Audio.muted
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }

        SliderRow {
            width: parent.width
            glyph: Icons.mic
            glyphOff: Icons.micMute
            value: Audio.micVolume
            off: Audio.micMuted
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
        }

        Text {
            text: "Output"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: Audio.sinks
                delegate: ListRow {
                    required property var modelData
                    width: col.width
                    glyph: Icons.headphones
                    label: Audio.nodeLabel(modelData)
                    selected: modelData === Audio.currentSink
                    onActivated: Audio.setSink(modelData)
                }
            }
        }

        Text {
            text: "Input"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: Audio.sources
                delegate: ListRow {
                    required property var modelData
                    width: col.width
                    glyph: Icons.mic
                    label: Audio.nodeLabel(modelData)
                    selected: modelData === Audio.currentSource
                    onActivated: Audio.setSource(modelData)
                }
            }
        }

        Text {
            visible: Audio.appStreams.length > 0
            text: "Applications"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Item {
            width: parent.width
            height: Math.min(appList.implicitHeight, 144)
            visible: Audio.appStreams.length > 0

            Flickable {
                id: appFlick
                anchors.left: parent.left
                anchors.right: appRail.left
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                clip: true
                contentHeight: appList.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: appList
                    width: appFlick.width
                    spacing: 8

                    Repeater {
                        model: Audio.appStreams
                        delegate: Row {
                            required property var modelData
                            width: appList.width
                            height: 20
                            spacing: 8

                            Text {
                                width: 104
                                height: parent.height
                                text: Audio.appLabel(modelData)
                                color: Theme.textSecondary
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                verticalAlignment: Text.AlignVCenter
                            }

                            SliderRow {
                                width: parent.width - 112
                                glyph: ""
                                glyphOff: ""
                                value: Audio.appVolume(modelData)
                                valueText: Math.round(Config.clamp(value, 0, 1) * 100) + "%"
                                off: !modelData.audio || modelData.audio.muted || Audio.muted || Audio.volume <= 0
                                iconToggles: false
                                showIcon: false
                                compact: true
                                onMoved: v => Audio.setAppVolume(modelData, v)
                            }
                        }
                    }
                }
            }

            ScrollRail {
                id: appRail
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                flickable: appFlick
            }
        }
    }
}
