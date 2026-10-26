// runcat: a custom module (runcat-text and its glyph font) whose runner,
// the font, is the one pet-picker.sh picked (Paths.state/runner), switched
// at once; bar.json's "font" until there is one.
import QtQuick
import Quickshell.Io
import qs.bar.modules
import qs.bar.services

Custom {
    id: mod

    property string runner: ""
    iconFont: runner || settings.font || look.font

    FileView {
        path: Paths.state + "runner"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: mod.runner = text().trim()
        onLoadFailed: mod.runner = ""
    }
}
