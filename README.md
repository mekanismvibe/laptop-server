# laptop-server

One script that turns an old laptop into a well-behaved, always-on server
(Proxmox VE, Debian or Ubuntu Server):

| What | How |
|---|---|
| Closing the lid does nothing | logind drop-in: `HandleLidSwitch=ignore` (+ on power, docked, sleep keys) |
| Never suspends or hibernates | `sleep.conf` drop-in + `sleep/suspend/hibernate/hybrid-sleep` targets masked |
| Screen turns off | console blanks after 1 minute (`setterm`), re-applied at boot |
| Battery stops charging at 80% | `charge_control_end_threshold=80`, resumes below 75% (`start=75`); Dell gets `charge_types=Custom` |
| **Any** wired adapter works | plug in any USB Ethernet adapter, replug it, move ports, swap it: it gets the server's network config |
| Wi-Fi off | Wi-Fi radio switched off so the server only uses the wire (only when a wired adapter is present) |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mekanismvibe/laptop-server/main/install.sh | sudo sh
```

Preview first without changing anything:

```bash
curl -fsSL https://raw.githubusercontent.com/mekanismvibe/laptop-server/main/install.sh | sudo sh -s -- --dry-run
```

The installer puts the script at `/usr/local/sbin/laptop-server` and runs `laptop-server setup`.
Arguments after `--` are passed to setup.

## Commands

```text
laptop-server setup [--dry-run] [--yes] [--charge-start N] [--charge-stop N]
                    [--no-network] [--no-battery] [--no-wifi-off] [--no-screen-off]
laptop-server status        # lid, sleep, battery limit, adapters, bridge, Wi-Fi at a glance
laptop-server revert        # undo the last setup run from its backups
laptop-server wifi on|off   # turn the Wi-Fi radio back on (and keep it on) or off
```

Every file it changes is backed up to `/var/backups/laptop-server/<timestamp>/` first.

## How "any wired adapter" works

USB Ethernet adapters are named after their MAC address (`enx001122334455`), so a config
that names one adapter breaks the moment you plug in a different one. And if the adapter
shows up late or gets replugged, nothing brings the network back. The script fixes that per
network stack:

- **Proxmox VE** (ifupdown2): the bridge's `bridge-ports <one adapter>` becomes
  `bridge-ports regex ^(en|eth|nic).*`. A udev rule asks systemd to run
  `laptop-server-hotplug.service` (`ifreload -a`) whenever a wired adapter appears, and
  that service waits for normal boot networking to finish first.
- **Ubuntu Server** (netplan): the wired entry gets `match: {name: "en*"}`; systemd-networkd
  handles hot-plugging by itself. cloud-init is told not to regenerate the network config.
- **Debian** (ifupdown): the wired stanza moves to a systemd-networkd file with
  `[Match] Name=en* eth*` (DHCP or the same static address).
- **NetworkManager**: already brings up any wired adapter, nothing to change.

Network changes are applied with a safety net: a timer restores the old config after
3 minutes unless the default gateway answers with the new one, so it's safe over SSH.

> Lesson learned: never run `systemd-run` or `ifreload` straight from a udev `RUN+=`.
> At boot that deadlocks with ifupdown2's `udevadm settle`, networking fails, and the
> bridge never comes up. The rule here only tags the device for systemd.

## When the adapter doesn't show up at all after a reboot

Some cheap RTL8153 adapters stay powered through a warm reboot and come back hung: the
kernel never sees them until they're physically replugged. No software setting fixes that
reliably (resetting the USB controller didn't help in testing). Things that do help:

- BIOS: turn off **USB PowerShare** / **USB wake support**, set **Fastboot** to **Thorough**
- Plug it into a different port, or through a **powered USB hub**
- Use an adapter with a different chip (ASIX AX88179A or Realtek RTL8156 are good picks)

With this script installed, replugging is enough: no keyboard or monitor needed.

## Battery limits

Uses the kernel's standard `charge_control_start_threshold` / `charge_control_end_threshold`.
Works on most Dell, Lenovo ThinkPad, ASUS (stop only), Huawei, LG and System76 laptops
with a recent kernel. If yours doesn't expose them, the script tells you and points at the
BIOS setting instead (Dell: Power Management > Primary Battery Charge Configuration >
Custom). Limits are re-applied at every boot by `laptop-server.service`.

## Tested on

- Proxmox VE 9.2 on a Dell Inspiron 5481 with a USB RTL8153 adapter (Realtek r8152)
- Dry runs on Proxmox VE 9.2 (desktop, `nic0`) and Debian 12
- The Ubuntu (netplan) and Debian (ifupdown → networkd) network paths are tested against
  sample configs; try `--dry-run` first on those.

## License

MIT
