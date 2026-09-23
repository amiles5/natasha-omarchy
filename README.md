# natasha Omarchy config

Omarchy/Hyprland config for `natasha` (MacBookPro15,1, T2 chip, dual GPU:
Intel Coffee Lake iGPU + AMD Polaris11 dGPU). Tracks `hypr/` and `omarchy/`
only — see `.gitignore`.

## Logitech mouse/keyboard battery

`omarchy/bar/scripts/logitech-battery.py` — another plain `omarchy.bar`
command module, ported from
[amiles5/ayana-omarchy](https://github.com/amiles5/ayana-omarchy) (same
Bolt receiver, actually — the MX Mechanical Mini keyboard and MX Master 3S
mouse are paired to both machines as separate hosts on the one receiver).
Shows both devices' battery % on the bar, click opens `solaar` (the GUI).

Reads `solaar show all`'s plain text output (matched by each device's
"Kind" — mouse/keyboard — rather than name, so a device swap doesn't need
a code change; no machine-readable output mode exists). Each invocation
re-walks the full HID++ feature set live over the radio — ~12s for both
devices on this machine — which is why the poll interval is 120s, not the
5s the Sonos widgets use.

## Random wallpaper rotation

Desktop background rotates to a random image from `~/Pictures/wallpapers/`
every 5 minutes, via a systemd user timer rather than any Omarchy-specific
mechanism — Omarchy's own `theme bg next` only cycles backgrounds within
the *current theme's* set, which isn't what "random from an arbitrary
folder" needs. `theme bg set <path>` does take an arbitrary path though,
so that's the actual integration point.

- `~/.local/bin/omarchy-random-wallpaper` (not tracked here — lives
  outside `~/.config`, same convention as the other `.local/bin` scripts)
  — picks a random `.jpg`/`.jpeg`/`.png`/`.gif`/`.bmp`/`.webp` from that
  folder and applies it with `omarchy theme bg set`. No-ops quietly
  (exit 0, one line to stderr) if the folder's empty — never errors or
  spams retries.
- `systemd/user/random-wallpaper.{service,timer}` — `Type=oneshot` service
  triggered by a timer: first run 30s after the timer starts (i.e.
  ~login), then every 5 minutes (`OnUnitActiveSec=5min`). Enabled and
  persists across reboots (`systemctl --user enable --now
  random-wallpaper.timer`).

Check it's running: `systemctl --user status random-wallpaper.timer`.
Trigger one rotation immediately without waiting for the timer: run
`omarchy-random-wallpaper` directly.

## Apple Studio Display

### The problem

The Studio Display's native resolution is `5120x2880@60`. Driving that
without DSC (Display Stream Compression) needs more bandwidth than a single
DP link without DSC actually has. This machine's dGPU is a Polaris11 part
(DCE 11.2, ~2016-era Radeon) — DSC support in `amdgpu` didn't arrive until
much newer display hardware (DCN), so this GPU can't do it.

Symptoms when Hyprland is left to auto-negotiate the native mode:
- Cold boot: the display sometimes fails to sync at all (blank).
- Live: the display flickers/darkens repeatedly as it loses and re-acquires
  sync — the link can't sustain the native mode's bandwidth without DSC.

### The fix

`hypr/monitors.lua` forces the Studio Display (`DP-4`) to `3840x2160@60`,
which fits the link without DSC:

```lua
hl.monitor({ output = "DP-4", mode = "3840x2160@60", position = "auto", scale = 3 })
```

Scale 3 is an exact clean divisor of that mode (1280x720 logical), so no
fractional-scaling blur. Do not switch this to `preferred`/auto or to the
native `5120x2880` mode — it will reintroduce the flicker/no-sync issue.

### The widget gotcha

Omarchy's built-in Display bar widget (`omarchy.monitor`) re-enables a
monitor with the bare `hyprctl keyword monitor NAME,preferred,auto,auto` —
that forces native resolution, silently overriding the forced mode above,
and reintroduces the flicker. Toggling the Studio Display off/on from that
widget used to crash `quickshell` outright (a race in the idle/lock
service's monitor-stabilize logic — see `journalctl` around
`FATAL: Tried to show lockscreen surfaces without active lock` if it
recurs).

Fixed by cloning the widget to `omarchy/plugins/milesj.monitor/` and
patching `toggleDisplay()`: re-enabling now runs
`hyprctl keyword monitor DP-4,preferred,auto,auto && hyprctl reload` — the
`hyprctl reload` immediately after reasserts `monitors.lua`'s forced mode.

## Hybrid graphics (iGPU/dGPU toggle) — tried, reverted

Tried following [wiki.t2linux.org/guides/hybrid-graphics](https://wiki.t2linux.org/guides/hybrid-graphics/)
(this exact model, `MacBookPro15,1`, is explicitly listed) to run iGPU-only
for power savings: `/etc/modprobe.d/apple-gmux.conf` (`force_igd=y`,
apple_gmux's real hardware mux) + `/etc/systemd/system/amdgpu-off.service`
(a `oneshot` unit writing `OFF` to `vgaswitcheroo/switch`, fully powering
the AMD dGPU down — confirmed via its `hwmon` power sensor going from a
live reading to `Device or resource busy`, i.e. genuinely gone, not idle).
Both confirmed working exactly as the wiki describes, boot-time only (also
independently confirmed by our own `vga_switcheroo` "refused switch"
testing during the GPU-power-widget incident history, now removed, in
earlier commits).

**Settled the open question this was for**: the Studio Display does need
the dGPU. With `force_igd=y` active and the AMD GPU fully off, plugging in
the Studio Display brought up its USB side completely normally (hub,
camera, HID, even a device plugged into its own hub) but the video path
specifically failed:
```
thunderbolt 0000:06:00.0: 0:6 <-> 3:10 (DP): not active, tearing down
```
The Thunderbolt DisplayPort tunnel never activates without the AMD GPU
available to claim it, even though the iGPU works fine for the internal
panel. So: power savings *or* the Studio Display, not both, on this
hardware.

**Reverted** (2026-09-23) once that was confirmed — both files removed,
the bash aliases (`dgpu-off`/`dgpu-on`/`dgpu-status`) taken back out of
`.bashrc`, machine rebooted back onto the AMD GPU. Only this writeup
remains, since the actual finding is worth keeping even with the setup
itself undone.

## Sonos bar widget + auto-duck

Ported from [amiles5/ayana-omarchy](https://github.com/amiles5/ayana-omarchy)
(same physical household speakers), replacing an earlier custom QML plugin
(`milesj.sonos`) with the same simpler split that machine uses: a plain
Omarchy `"type": "command"` bar module for the widget, and a standalone
`systemd --user` service for ducking — decoupled from each other and from
the bar's own process lifecycle.

- `hypr/scripts/sonos_lib.py` — shared UPnP/SOAP helpers (SOAP POST,
  transport state, play/pause, group-coordinator discovery). Used by both
  pieces below; not duplicated between them.
- `omarchy/bar/scripts/sonos-status.py` / `sonos-toggle.py` — the bar
  widget itself (`omarchy/shell.json`'s `"sonos"` command module, polled
  every 5s). Status icon shows whether any group is playing; click is a
  house-wide play/pause-all toggle. No room picker or volume control (a
  real feature reduction from the old QML widget) — this matches
  `ayana-omarchy`'s intentionally minimal version, not an oversight.
- `hypr/scripts/sonos-ducking.sh` (a Python script despite the name, kept
  for parity with `ayana-omarchy`) + `systemd/user/sonos-ducking.service`
  — pauses every currently-playing group when the Studio Display's own
  speakers start making sound, resumes only the groups it auto-paused once
  the host goes quiet again.

### Why coordinator discovery, not a static room table

The old `milesj.sonos` plugin (and the `ayana-cachyos` original it was
ported from) tracked one hardcoded `ROOMS` table of name/IP/RINCON. Two
real problems with that: a speaker renamed in the Sonos app makes the
hardcoded name go stale, and — discovered testing on this household's
actual speakers (2026-09-21) — when speakers are grouped, only the
*group's coordinator* accepts `Pause`/`Play`; other members reject it with
an HTTP 500. `sonos_lib.discover_coordinators()` resolves the current
topology live via `ZoneGroupTopology`'s `GetZoneGroupState` on every
check instead, and only ever sends transport commands to a coordinator's
own IP. Bootstrap IPs are still hardcoded (one of Bedroom/Dining/Kitchen/
Living Room needs to be reachable to ask for the topology at all), but
names and coordinator status are always read live, never assumed.

### Ducking specifics

Watches one specific sink — this Mac's Studio Display speakers
(`alsa_output.usb-Apple_Inc._Studio_Display_...`) — not "any sink," unlike
an earlier version of this ducking logic. Checked every 5s
(`POLL_INTERVAL_SECONDS` in `sonos-ducking.sh`). On the sink going
`RUNNING`, pauses every coordinator currently `PLAYING`. On it going quiet
again, resumes only those same coordinators, and only if each is still
`PAUSED_PLAYBACK` or `STOPPED` — if something else already changed a
group's transport while the host was making noise, that group is left
alone rather than force-resumed.

Check it's running: `systemctl --user status sonos-ducking.service`.

### Sonos web app

`SUPER + SHIFT + U` also opens the Sonos web app (`play.sonos.com`) as its
own window, separate from the bar widget above — installed as a real
Firefox PWA via `firefoxpwa` (matching how `ayana-cachyos` does WhatsApp
and Sonos: `firefoxpwa site install <manifest-url>`, no hand-written
manifest needed since the site publishes a real one). Pinned to
workspace 6, same as `ayana-cachyos`.

```bash
firefoxpwa site install "https://play.sonos.com/manifest.webmanifest"
firefoxpwa runtime install   # one-time, needed before any PWA will actually launch
```

The install generates a random site ID (`FFPWA-<ID>`) baked into both the
keybinding (`hypr/bindings.lua`) and the workspace rule
(`hypr/hyprland.lua`) — reinstalling the PWA generates a *different* ID,
so both need updating to match if that ever happens.

## Windows VM (`omarchy-windows-vm`)

### The recurring `~/Windows` permission bug

Every time the VM actually runs — even after a perfectly clean
`omarchy-windows-vm stop` — its own shared-folder setup leaves `~/Windows`
(the shared-folder bind-mount source) at mode `2777` with a setgid bit.
`chmod` cannot clear that setgid bit once it's been set (confirmed by
testing outside the container too — it's a filesystem/directory-level
quirk, not something Docker-specific). The packaged script's own
`assert_mounts_safe` check then refuses the *next* `launch`/`remove` until
that directory is back to exactly `700`, failing with either "failed to
start" or (on `remove`) `Windows VM removal stopped before user-side
cleanup`.

Manual fix, when it recurs and the directory is confirmed empty:

```bash
mountpoint -q /var/lib/omarchy/windows/mounts/users/$(id -u)/shared &&
  pkexec umount /var/lib/omarchy/windows/mounts/users/$(id -u)/shared
rmdir ~/Windows && mkdir -m 0700 ~/Windows
```

### The self-healing wrapper

`~/.local/bin/omarchy-windows-vm-safe` (not tracked in this repo — lives
outside `~/.config`) wraps the packaged binary: before delegating, it
checks whether `~/Windows` needs fixing and, if so and it's safe to
(VM not currently up, directory confirmed empty first — it will never
delete real files), does the rmdir/mkdir dance above automatically.

The "is the VM up" check is a plain TCP probe against port 3389, not
`docker inspect` — this wrapper runs from a non-interactive desktop
launcher as often as a terminal, and a privileged call that stalls on an
unanswerable password/polkit prompt must never hang the launch.

Wired into every real invocation path:
- `~/.local/share/applications/windows-vm.desktop`'s `Exec=` points at the
  wrapper (this file is regenerated if `omarchy-windows-vm install` is
  ever rerun after being removed — repoint it again if so).
- `~/.bashrc` defines an `omarchy-windows-vm` shell function that calls the
  wrapper, shadowing the packaged binary for interactive/CLI use (`.bashrc`
  is not tracked in this repo either).
- `omarchy/extensions/omarchy-menu.jsonc` overrides the `install.windows`
  and `remove.windows` menu actions to call the wrapper directly. **Gap
  found and fixed 2026-09-22**: those two menu actions run via
  `omarchy-launch-floating-terminal-with-presentation`, which execs
  `bash -c "..."` — a non-interactive shell that never sources `.bashrc`,
  so the function-shadow trick above doesn't reach this path. Hit the
  `~/Windows` setgid bug through exactly this gap once, confirming it
  wasn't just theoretical.

### Verified lifecycle (2026-09-11)

Startup (resumes the existing disk, no reinstall), clean `stop`, and RDP
login (`xfreerdp3`, full session with graphics/input/sound channels) all
confirmed working end-to-end. One caveat worth remembering: interrupting
Windows Setup mid-install (e.g. killing the launch process before it
finishes) forces the *next* launch to rebuild the ~64GB disk from scratch
rather than resuming — let a fresh install run to completion (15-30+ min)
before stopping it.

## Syncing settings to another machine (`omarchy-sync-settings`)

`~/.local/bin/omarchy-sync-settings` (not tracked here — lives outside
`~/.config`) copies the current live state of `hypr/`, `omarchy/`, and the
wallpaper-rotation systemd units to another machine over SSH/rsync —
deliberately the exact same scope this repo tracks (see `.gitignore`), so
there's one consistent definition of "Omarchy settings" rather than two
that can drift apart.

```bash
omarchy-sync-settings <user@host-or-tailscale-name>              # additive/overwrite, safe default
omarchy-sync-settings <user@host> --dry-run                      # preview only
omarchy-sync-settings <user@host> --mirror                       # exact mirror, deletes target-only files
```

This repo is still the durable source of truth (commit/push here for a
permanent record); the script is for actually propagating current state
to a second machine over the network. It deliberately does **not** copy
`~/.bashrc`, `omarchy-windows-vm-safe`, `omarchy-random-wallpaper`, or
`windows-vm.desktop` — those are machine-specific enough (existing
`.bashrc` content, whether the target even runs the Windows VM feature)
that blindly overwriting them could do more harm than good; the script
prints a reminder about these at the end.
