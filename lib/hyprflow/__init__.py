"""What HyprFlow's scripts share, so each one does not write it again.

    paths     where HyprFlow keeps its config, state and runtime files
    hyprctl   ask Hyprland for JSON and dispatch to it (Facade over hyprctl)
    notify    desktop notifications
    palette   the current wallust palette
    waybar    WaybarModule, the base of the event driven bar modules

Only the waybar module knows about Waybar: the rest is about the desktop, so
it would carry over to another bar or shell as it is.

Scripts in lib/ import it as a package (from hyprflow import hyprctl); they
put their own folder on sys.path first, which is lib/ in the repo.
"""
