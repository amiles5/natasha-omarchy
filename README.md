# natasha Omarchy config

Omarchy/Hyprland config for `natasha` (MacBookPro15,1, T2 chip, dual GPU:
Intel Coffee Lake iGPU + AMD Polaris11 dGPU). Tracks `hypr/` and `omarchy/`
only — see `.gitignore`.

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

## Sonos bar widget (`milesj.sonos`)

Bar widget + background service for the local Sonos system, controlled
directly over UPnP/SOAP (no cloud, no Sonos app). Ported from
[amiles5/ayana-cachyos](https://github.com/amiles5/ayana-cachyos)'s
Noctalia/Luau `sonos-control` plugin to Omarchy's QML plugin system — same
physical speakers, same IP/RINCON table.

- `omarchy/plugins/milesj.sonos/Service.qml` — headless service, polls all
  rooms every 5s (transport/title/volume/coordinator), owns all speaker
  commands. `BarWidget.qml` never talks to the speakers directly.
- `omarchy/plugins/milesj.sonos/BarWidget.qml` — icon + active room/track on
  the bar. Click = play/pause, scroll = volume, right-click = popup to pick
  the active room and adjust volume.

### Auto-duck

Every 5s the service checks `pactl list sinks short` for any sink in
`RUNNING` state — i.e. any audio actively playing on this host, from any
output. If so, it pauses the active Sonos room; when host audio stops, it
resumes only the room it auto-paused (and only if nothing else changed that
room's transport in the meantime). This is a bit more general than the
`ayana-cachyos` original, which only watched one specific sink (that
machine's Studio Display speakers) — here it watches all sinks, since the
ask was "duck if any other audio is playing."

### Not ported yet

Room grouping and Sonos Favourites, both present in the `ayana-cachyos`
Noctalia panel, aren't in the Omarchy version yet.

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

Wired into both real invocation paths:
- `~/.local/share/applications/windows-vm.desktop`'s `Exec=` points at the
  wrapper (this file is regenerated if `omarchy-windows-vm install` is
  ever rerun after being removed — repoint it again if so).
- `~/.bashrc` defines an `omarchy-windows-vm` shell function that calls the
  wrapper, shadowing the packaged binary for interactive/CLI use (`.bashrc`
  is not tracked in this repo either).

### Verified lifecycle (2026-09-11)

Startup (resumes the existing disk, no reinstall), clean `stop`, and RDP
login (`xfreerdp3`, full session with graphics/input/sound channels) all
confirmed working end-to-end. One caveat worth remembering: interrupting
Windows Setup mid-install (e.g. killing the launch process before it
finishes) forces the *next* launch to rebuild the ~64GB disk from scratch
rather than resuming — let a fresh install run to completion (15-30+ min)
before stopping it.

## GPU power widget (`milesj.gpupower`)

Bar widget showing live power draw from the AMD dGPU's `hwmon` sensor
(`power1_input`), with an adjustable live power cap (`power1_cap`):
scroll on the icon for ±1W, right-click for a popup slider (5-40W). The
`hwmon` number isn't assumed stable across reboots — both the poll and the
write resolve the path fresh each time by scanning `/sys/class/drm/card*`
for vendor `0x1002` (AMD).

Cap changes are deliberately **not persisted** — plain sysfs write, resets
to the 40W hardware default on every reboot.

### GPU switching (Intel vs AMD) — not viable live

The motivation was cutting power/heat by running on the Intel iGPU instead
of the AMD dGPU. `apple_gmux` is loaded and does register with the kernel's
`vga_switcheroo` (`/sys/kernel/debug/vgaswitcheroo/switch` lists both `IGD`
and `DIS`), so the interface is real, not a dead stub. But both the delayed
(`DDIGD`/queued-on-VT-switch) and immediate (`IGD`) switch commands were
refused outright:

```
vga_switcheroo: client 101 refused switch
```

The AMD driver declines to hand off while it holds an active DRM master
(Hyprland is actively rendering through it) — a deliberate safety check,
not a crash. Tested safely: a `chvt 2` / `chvt 1` cycle to try to apply a
queued switch caused no disruption, Hyprland/quickshell survived
throughout. Separately, even if switching worked, the external Studio
Display's DisplayPort is likely wired through the discrete GPU at the
hardware level on this 2018 15" model (only the internal panel is
mux-able) — so a successful switch might not even keep the external
display alive. Given that, the power cap (above) is the actual lever for
less heat/power, not GPU switching.

### Local plugin hot-reload can go stale

Hit while wiring up this widget's interactivity: repeated edits to a local
plugin's `BarWidget.qml` logged `Local plugin changed, reloading: ...`
each time, but the *live* bar widget kept rendering an old version
regardless — confirmed by screenshotting the bar and seeing stale content
after several edits. `omarchy restart shell` (a real restart, new
quickshell PID) fixed it every time; the automatic hot-reload cannot be
trusted as proof that an edit actually took effect. Worth reaching for a
full restart whenever a local plugin change doesn't seem to do anything,
rather than assuming the code itself is wrong.
before stopping it.
