# Lockscreen

`hyprlock`, bound to `Super + Alt + L` and the wlogout Lock button: oversized clock, glass
bar with avatar and password field, now-playing card. Track details show only for
dedicated music apps, since a lockscreen is visible to passers-by. Media keys keep working
under the lock.

`hyprlock.conf` holds no coordinates. `dotconfig/hypr/hyprlock/geometry.sh` runs before
each lock and writes them, so the layout follows whatever monitor is attached. Edit
that script, never the generated `hyprlock-geometry.conf`.

Content lands on the monitor holding workspace 1; the rest are blurred. Override with
`HYPRLOCK_MONITOR`. The avatar is `~/.config/hypr/avatar.png`: `install.sh` puts the
skull from `assets/avatar.png` there when you have none. Replace it with any square
image and it's never overwritten. Without the file, the lock draws the Arch glyph.
