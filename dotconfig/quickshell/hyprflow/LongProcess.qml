// A command that keeps running (a watcher, a stream): it dies with
// Quickshell. Killing qs leaves a plain Process's child behind, and every
// restart added one more (pw-metadata, swaync-client piled up by the dozen).
//   argv   the command, as Process's command
import Quickshell.Io

Process {
    property var argv: []
    command: ["setpriv", "--pdeathsig", "TERM", "--"].concat(argv)
}
