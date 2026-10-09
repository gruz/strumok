# strumok

Stream a single window (or a cropped region of it) to RTMP(S) on
GNOME/Wayland, using the xdg-desktop-portal ScreenCast API and GStreamer.

## Requirements

- GNOME on Wayland with xdg-desktop-portal
- Nix package manager (`nix-shell` is used to pull all dependencies)
- Optional: Argos GNOME extension (tray start/stop menu)

## Install

One command — downloads the script and runs it once, which triggers the
self-install (first run also downloads all dependencies via nix-shell,
so it takes a while):

```sh
curl -L --create-dirs -o ~/.local/bin/stream-window \
  https://raw.githubusercontent.com/gruz/strumok/master/stream-window \
  && chmod +x ~/.local/bin/stream-window \
  && ~/.local/bin/stream-window --list
```

Self-installed into `~/.local/bin` and `~/.config`:
`profiles.ini` (profile config), `stream-profiles-edit` (GTK editor),
`stream-reset`, and — only if the Argos extension is installed —
`~/.config/argos/stream.r.2s.sh` (tray widget).

## Configure

```sh
stream-window --edit        # GUI editor
```

or edit `~/.config/stream-window/profiles.ini` by hand — one `[section]`
per profile, each needs a `url` key. `[DEFAULT]` values apply to all
profiles.

Defaults follow the server doc: 24 fps, GOP = 2*fps, B-frames off,
rtmp2sink, a trailing '/' is appended to RTMP URLs automatically
(`trailing_slash = 0` or `RTMP_TRAILING_SLASH=0` disables). Output is
scaled to fit 1280x720 at 1800 kbps — tune `scale`, `fps`, `bitrate`
per profile (`scale = off` disables scaling).

## Run

```sh
stream-window <profile>                       # stream a configured profile
stream-window --list                          # show profiles
stream-window --edit                          # profile editor
stream-window rtmps://host/app/key [x y w h] [kbps]   # ad-hoc stream
```

First run: the portal picker dialog appears once — select the window,
tick **Remember this selection**, click Share. The choice is persisted
(`~/.local/share/stream-window.token`) and later runs skip the dialog.

Stop a running stream:

```sh
kill $(cat $XDG_RUNTIME_DIR/stream-window.pid)
```

## Reset / uninstall

```sh
stream-reset          # forget window selection + runtime state
stream-reset --all    # also remove installed files (full uninstall)
```
