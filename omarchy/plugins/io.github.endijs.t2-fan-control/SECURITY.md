# Security

## Privilege boundary

The QML plugin and its bundled status helper run with normal user permissions.
Telemetry is read from sysfs. No privileged background service or passwordless
policy is installed.

An explicit setup step copies the configuration helper from the plugin into
`/usr/local/libexec/omarchy-t2-fan-control` with root ownership and installs a
PolicyKit action that pins that exact path. Saving or restoring launches only
that installed copy through `pkexec`, so a later plugin update or another
same-user process cannot substitute code at the authorization boundary.

PolicyKit asks the user to authenticate each change. The installed helper
validates every argument before writing, backs up `/etc/t2fand.conf`, uses an
atomic temporary file retaining the existing ownership and mode, and restores
the previous configuration if `t2fanrd` cannot restart.

The one-time command `sudo ./contrib/install-helper.sh` trusts the checked-out
source at the moment the user explicitly installs it. Routine Save and Restore
actions do not execute code from that user-writable checkout as root.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository rather
than opening a public issue for exploitable behavior.
