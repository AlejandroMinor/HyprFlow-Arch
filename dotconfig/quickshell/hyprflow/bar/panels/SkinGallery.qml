// Every skin at once, bigger than in the cog, in its groups, with the
// picked one's options underneath. Opened from the cog's skin tab
// (MediaSkin.galleryOwner); the bar's drawer closes behind it, so it hangs
// off the Media module instead. Esc or a click elsewhere closes it.
import QtQuick
import QtQuick.Layouts
import qs
import qs.bar.widgets
import qs.bar.services

Overlay {
    id: gallery

    property var media  // the Media module: player, art, look
    readonly property int columns: 8
    readonly property int faceSize: 100

    name: "hyprflow-skins"
    open: MediaSkin.galleryOwner === media && media !== null
    cardWidth: columns * (faceSize + 8) + (columns - 1) * 8 + 32
    cardHeight: body.implicitHeight + 32
    onDismissed: MediaSkin.galleryOwner = null
    onOpenChanged: if (open) body.forceActiveFocus()

    ColumnLayout {
        id: body
        x: 16
        y: 16
        width: gallery.cardWidth - 32
        spacing: 8
        Keys.onEscapePressed: MediaSkin.galleryOwner = null

        Text {
            text: "Player style"
            color: Colors.foreground
            font { family: gallery.media?.look.font ?? ""; pixelSize: 13; bold: true }
        }

        Repeater {
            model: MediaSkin.groups
            delegate: ColumnLayout {
                id: group
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Text {
                    Layout.topMargin: 4
                    text: group.modelData.label
                    color: Colors.fg(0.5)
                    font { family: gallery.media?.look.font ?? ""; pixelSize: 11; bold: true }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        // Built only while open: every tile is a live skin.
                        model: gallery.open ? MediaSkin.skins.filter(s => s.group === group.modelData.name) : []
                        delegate: SkinTile {
                            required property var modelData
                            entry: modelData
                            media: gallery.media
                            faceSize: gallery.faceSize
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            implicitHeight: 1
            color: Colors.fg(0.08)
        }
        SkinFace {
            id: sampleFace
            visible: false
            skin: gallery.open ? MediaSkin.skin : "cover"
        }
        SkinOptions {
            Layout.fillWidth: true
            sample: sampleFace.item
            fontFamily: gallery.media?.look.font ?? ""
        }
    }
}
