"""Tests for lib/osd-watch.py. The OSD, playerctl, dconf and the lock LEDs are
all fakes: no player, no swaync, no keyboard is touched."""


def test_media_shows_play_and_pause_but_leaves_a_skip_alone(osd_watch):
    seen = []
    media = osd_watch.Media(emit=lambda *a: seen.append(a))
    media.line("spotify\tPlaying\t100\tSong\tArtist\n")    # on start: not shown
    media.line("spotify\tPaused\t100\tSong\tArtist\n")     # pause: shown
    media.line("spotify\tPaused\t200\tOther\tBand\n")      # a skip while paused
    media.line("spotify\tPlaying\t200\tOther\tBand\n")     # play: shown
    assert seen == [
        (osd_watch.GLYPH["pause"], "Song", "Artist", -1),
        (osd_watch.GLYPH["play"], "Other", "Band", -1),
    ]


def test_media_without_a_title_still_says_something(osd_watch):
    seen = []
    media = osd_watch.Media(emit=lambda *a: seen.append(a))
    media.line("mpv\tPaused\t100\t\t\n")
    media.line("mpv\tPlaying\t100\t\t\n")
    assert seen == [(osd_watch.GLYPH["play"], "Media", "", -1)]


def test_a_notification_sound_in_another_player_is_ignored(osd_watch):
    seen = []
    media = osd_watch.Media(emit=lambda *a: seen.append(a))
    media.line("spotify\tPlaying\t100\tSong\tArtist\n")
    media.line("firefox\tPlaying\t\t(3) WhatsApp\t\n")     # no length
    media.line("firefox\tPaused\t\t(3) WhatsApp\t\n")
    media.line("spotify\tPlaying\t100\tSong\tArtist\n")    # back: same state
    assert seen == []


def test_switching_players_is_not_play_or_pause(osd_watch):
    seen = []
    media = osd_watch.Media(emit=lambda *a: seen.append(a))
    media.line("spotify\tPaused\t100\tSong\tArtist\n")
    media.line("firefox\tPlaying\t300\tVideo\t\n")         # its first line
    assert seen == []


def test_dnd_shows_on_and_off_but_not_its_path_lines(osd_watch):
    seen = []
    dnd = osd_watch.Dnd(emit=lambda *a: seen.append(a))
    dnd.line("/org/erikreider/swaync/dnd-state\n")   # dconf watch's path line
    dnd.line("  true\n")
    dnd.line("\n")
    dnd.line("  false\n")
    assert seen == [
        (osd_watch.GLYPH["bell_off"], "Do not disturb", "On", -1),
        (osd_watch.GLYPH["bell"], "Do not disturb", "Off", -1),
    ]


def test_the_lock_that_moved_shows_and_nothing_else(osd_watch):
    states = iter([(False, False), (True, False), (True, True), (False, False)])
    seen = []
    locks = osd_watch.Locks(read=lambda: next(states), emit=lambda *a: seen.append(a))
    for _ in range(4):
        locks.check()
    assert seen == [
        (osd_watch.GLYPH["caps"], "Caps Lock", "On", -1),
        (osd_watch.GLYPH["numeric"], "Num Lock", "On", -1),
        (osd_watch.GLYPH["caps"], "Caps Lock", "Off", -1),
        (osd_watch.GLYPH["numeric"], "Num Lock", "Off", -1),   # the last look turned both off
    ]


def test_a_lock_on_at_the_first_look_is_quiet(osd_watch):
    seen = []
    locks = osd_watch.Locks(read=lambda: (True, True), emit=lambda *a: seen.append(a))
    locks.check()
    locks.check()
    assert seen == []


def test_read_locks_looks_at_the_leds(osd_watch, tmp_path, monkeypatch):
    monkeypatch.setattr(osd_watch, "LEDS", tmp_path)
    for name, lit in [("input3::capslock", "1"), ("input5::capslock", "0"),
                      ("input3::numlock", "0")]:
        (tmp_path / name).mkdir()
        (tmp_path / name / "brightness").write_text(lit + "\n")
    assert osd_watch.read_locks() == (True, False)


def test_a_player_that_stops_or_closes_is_not_shown_as_play(osd_watch):
    seen = []
    media = osd_watch.Media(emit=lambda *a: seen.append(a))
    media.line("spotify\tPlaying\t100\tSong\tArtist\n")
    media.line("\n")                                          # a player closed
    media.line("spotify\tStopped\t100\tSong\tArtist\n")
    media.line("spotify\tPlaying\t100\tSong\tArtist\n")    # starts over
    assert seen == []
